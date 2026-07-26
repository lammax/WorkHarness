//
// ExecutionLoopTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

struct ExecutionLoopTests {
    @Test func markdownSourceParsesTargetCommandsAndTasks() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sourceURL = directory.appendingPathComponent("tasks.md")
        let markdown = """
        # Pool
        - Repository: `/tmp/Target`
        - Base branch: `main`
        - Build command: `swift build`
        - Test command: `swift test`

        ### WHM-001 — Fix retry
        - Status: `pending`
        - Category: bug
        - Dependencies: `none`
        - Goal: fix retry state
        - Done when:
          - tests pass

        ### WHM-002 — Document retry
        - Status: `pending`
        - Category: documentation
        - Dependencies: `WHM-001`
        - Goal: document the behavior
        - Done when:
          - README is updated
        """
        try markdown.write(to: sourceURL, atomically: true, encoding: .utf8)

        let pool = try MarkdownExecutionTaskSource().loadTaskPool(at: sourceURL)

        #expect(pool.targetRepositoryPath == "/tmp/Target")
        #expect(pool.baseBranch == "main")
        #expect(pool.buildCommand == "swift build")
        #expect(pool.testCommand == "swift test")
        #expect(pool.tasks.map(\.id) == ["WHM-001", "WHM-002"])
        #expect(pool.tasks[0].category == .bug)
        #expect(pool.tasks[1].dependencies == ["WHM-001"])
        #expect(pool.tasks[1].definition.contains("README is updated"))
    }

    @Test func profileSelectorUsesTaskCategory() {
        let selector = ExecutionProfileSelector()

        #expect(selector.profileId(for: task(category: .bug)) == "bug-fix")
        #expect(selector.profileId(for: task(category: .research)) == "research")
        #expect(selector.profileId(for: task(category: .feature)) == "implementation")
        #expect(selector.profileId(for: task(category: .tests)) == "implementation")
        #expect(selector.profileId(for: task(category: .documentation)) == "implementation")
    }

    @MainActor
    @Test func loopCommandParsesStartPauseResumeStopAndStatus() {
        #expect(
            ExecutionLoopCommand.parse("/loop /tmp/tasks.md") ==
            ExecutionLoopCommand(action: .start(sourcePath: "/tmp/tasks.md"))
        )
        #expect(
            ExecutionLoopCommand.parse("/loop stop") ==
            ExecutionLoopCommand(action: .stop)
        )
        #expect(ExecutionLoopCommand.parse("/loop pause") == .init(action: .pause))
        #expect(ExecutionLoopCommand.parse("/loop resume") == .init(action: .resume))
        #expect(
            ExecutionLoopCommand.parse("/LOOP STATUS") ==
            ExecutionLoopCommand(action: .status)
        )
        #expect(ExecutionLoopCommand.parse("loop") == nil)
        #expect(ExecutionLoopCommand.parse("/loophole") == nil)
    }

    @Test func reportCalculatesCourseMetrics() {
        let start = Date(timeIntervalSince1970: 1_000)
        let attempt = ExecutionLoopAttempt(
            id: UUID(),
            controllerRunId: UUID(),
            sourcePath: "/tmp/tasks.md",
            targetRepositoryPath: "/tmp/repo",
            baseBranch: "main",
            baseCommitSHA: "base",
            executionBranch: "main",
            status: .failed,
            startedAt: start,
            finishedAt: start.addingTimeInterval(45),
            taskResults: [
                result(id: "WHM-001", status: .passed, start: start, duration: 10),
                result(id: "WHM-002", status: .passed, start: start, duration: 20),
                result(id: "WHM-003", status: .failed, start: start, duration: 15)
            ],
            stopReason: "Tests failed."
        )

        #expect(attempt.consecutivePassedTaskCount == 2)
        #expect(attempt.attemptedTaskCount == 3)
        #expect(attempt.passedTaskCount == 2)
        #expect(attempt.averageAttemptedTaskDuration == 15)
        #expect(attempt.averagePassedTaskDuration == 15)
        #expect(abs(attempt.firstPassSuccessRate - (2.0 / 3.0)) < 0.0001)

        let markdown = ExecutionLoopReportWriter(now: { start }).markdown(for: attempt)
        #expect(markdown.contains("Consecutive tasks passed without intervention: 2"))
        #expect(markdown.contains("First-pass success rate: 67%"))
        #expect(markdown.contains("| Agent | Runtime ID | Model |"))
        #expect(markdown.contains("| Cursor ACP | cursor.acp | cursor-small |"))
        #expect(markdown.contains("Tests failed."))
    }

    @MainActor
    @Test func startRequiresSavedAutoApproveSetting() async throws {
        let fixture = try LoopFixture(safetyMode: .askBeforeWrite)
        defer { fixture.cleanup() }

        await #expect(throws: ExecutionLoopServiceError.autoApproveRequired) {
            try await fixture.service.start(sourcePath: fixture.sourceURL.path)
        }
        #expect(fixture.toolService.requests.isEmpty)
    }

    @MainActor
    @Test func savedAutoApproveAllowsCommitAndPushForExplicitTargetRepository() async throws {
        let runRepository = InMemoryRunRepository()
        let run = Run(goal: "Commit and push another project")
        runRepository.insert(run)
        let approvalRepository = InMemoryApprovalRepository()
        let mcpClient = ExecutionLoopMCPClientFake()
        let recorder = RunRecorder(repository: runRepository)
        let service = ToolService(
            registry: ToolRegistry(tools: [GitTool()]),
            mcpClient: mcpClient,
            approvalService: ApprovalService(
                repository: approvalRepository,
                runRepository: runRepository,
                recorder: recorder,
                appSettingsService: InMemoryAppSettingsService(
                    defaultSafetyMode: .autoInsideSandbox
                )
            ),
            recorder: recorder
        )
        let targetPath = "/tmp/ExplicitExecutionTarget"

        let commit = try await service.executeAwaitingApproval(.init(
            runId: run.id,
            toolId: "git.run",
            arguments: ["arguments": "commit -m \"Task\""],
            projectRootPath: targetPath
        ))
        let push = try await service.executeAwaitingApproval(.init(
            runId: run.id,
            toolId: "git.run",
            arguments: ["arguments": "push -u origin day5/run"],
            projectRootPath: targetPath
        ))

        #expect(commit.status == .succeeded)
        #expect(push.status == .succeeded)
        #expect(approvalRepository.requests.count == 2)
        #expect(approvalRepository.requests.allSatisfy { $0.status == .granted })
        #expect(mcpClient.invocations.map(\.projectRootPath) == [targetPath, targetPath])
    }

    @Test func realDay5PoolContainsTwentyOrderedTasks() throws {
        let repositoryURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repositoryURL
            .appendingPathComponent("Documentation/Course/Day5-WorkHarnessMobile-Task-Pool.md")

        let pool = try MarkdownExecutionTaskSource().loadTaskPool(at: sourceURL)

        #expect(pool.tasks.count == 20)
        #expect(pool.tasks.first?.id == "WHM-001")
        #expect(pool.tasks.last?.id == "WHM-020")
        #expect(pool.targetRepositoryPath.hasSuffix("/WorkHarnessMobile"))
        #expect(pool.buildCommand.contains("xcodebuild build"))
        #expect(pool.testCommand.contains("xcodebuild test"))
    }

    @MainActor
    @Test func loopPausesAfterCurrentTaskAndResumesRemainingTasks() async throws {
        let fixture = try LoopFixture(safetyMode: .autoInsideSandbox)
        defer { fixture.cleanup() }
        try fixture.useTwoTaskPool()
        fixture.toolService.statusOutputs = ["", " M README.md\n", "", " M README.md\n"]

        let controllerRunId = try await fixture.service.start(sourcePath: fixture.sourceURL.path)
        fixture.service.pauseAfterCurrentTask()
        for _ in 0..<2_000 {
            if fixture.service.activeAttempt?.status == .paused {
                break
            }
            await Task.yield()
        }

        #expect(fixture.service.activeAttempt?.status == .paused)
        #expect(fixture.service.activeAttempt?.taskResults.map(\.taskId) == ["WHM-001"])
        #expect(fixture.runRepository.run(withId: controllerRunId)?.status == .interrupted)

        fixture.toolService.commitSubjectsOutput = "WHM-001: Add feature\n"
        _ = try await fixture.service.resume()
        for _ in 0..<4_000 {
            if fixture.service.activeAttempt?.finishedAt != nil {
                break
            }
            await Task.yield()
        }

        #expect(fixture.service.activeAttempt?.status == .passed)
        #expect(fixture.service.activeAttempt?.taskResults.map(\.taskId) == ["WHM-001", "WHM-002"])
        let events = fixture.runRepository.run(withId: controllerRunId)?.events ?? []
        #expect(events.contains { $0.type == .runInterrupted })
        #expect(events.contains { $0.type == .runResumed })
    }

    @MainActor
    @Test func loopUsesCurrentBranchValidatesCommitsAndPushesPinnedTargetRepository() async throws {
        let fixture = try LoopFixture(safetyMode: .autoInsideSandbox)
        defer { fixture.cleanup() }

        let controllerRunId = try await fixture.service.start(
            sourcePath: fixture.sourceURL.path
        )
        for _ in 0..<2_000 {
            if fixture.service.activeAttempt?.finishedAt != nil {
                break
            }
            await Task.yield()
        }

        let attempt = try #require(fixture.service.activeAttempt)
        #expect(attempt.status == .passed)
        #expect(attempt.controllerRunId == controllerRunId)
        #expect(attempt.consecutivePassedTaskCount == 1)
        #expect(attempt.taskResults.first?.commitSHA == "commit-sha")
        #expect(attempt.taskResults.first?.pushSucceeded == true)
        #expect(attempt.executionBranch == "main")
        #expect(FileManager.default.fileExists(atPath: try #require(attempt.reportPath)))
        #expect(fixture.projectService.currentProject?.id == fixture.originalProject.id)

        let targetPaths = fixture.toolService.requests.compactMap(\.projectRootPath)
        #expect(!targetPaths.isEmpty)
        #expect(Set(targetPaths) == [fixture.targetURL.path])
        #expect(fixture.toolService.gitArguments.contains("commit -m \"WHM-001: Add feature\""))
        #expect(fixture.toolService.gitArguments.contains("push -u origin HEAD"))
        #expect(!fixture.toolService.gitArguments.contains(where: {
            $0.hasPrefix("switch ") || $0.hasPrefix("checkout ")
        }))
        #expect(fixture.runLauncher.configurations.map(\.profileId) == ["implementation"])
        #expect(fixture.runLauncher.prompts.first?.contains("Do not run git commit") == true)
        #expect(fixture.runLauncher.progressMirrorRunIds == [controllerRunId])
        #expect(fixture.runLauncher.progressMirrorMetadata.first?["taskId"] == "WHM-001")
        #expect(fixture.runRepository.run(withId: controllerRunId)?.executionBackend?.id == "cursor.acp")
        #expect(fixture.runRepository.run(withId: controllerRunId)?.executionBackend?.modelId == "nano")
        let controllerEvents = fixture.runRepository.run(withId: controllerRunId)?.events ?? []
        #expect(controllerEvents.contains {
            $0.type == .agentStarted && $0.message.contains("[WHM-001]")
        })
        #expect(controllerEvents.contains {
            $0.type == .validationStarted && $0.message.contains("[WHM-001]")
        })
        #expect(controllerEvents.contains {
            $0.type == .validationFinished && $0.message.contains("[WHM-001]")
        })
        #expect(controllerEvents.contains {
            $0.type == .finalSummary && $0.message.contains("[WHM-001]")
        })
        #expect(
            fixture.runLauncher.lastRunId.flatMap(fixture.runLauncher.run(withId:))?.status ==
            .completed
        )
    }

    @MainActor
    @Test func loopResumesAfterTasksAlreadyCommittedOnCurrentBranch() async throws {
        let fixture = try LoopFixture(safetyMode: .autoInsideSandbox)
        defer { fixture.cleanup() }
        fixture.toolService.commitSubjectsOutput = "WHM-001: Add feature\n"

        _ = try await fixture.service.start(sourcePath: fixture.sourceURL.path)
        for _ in 0..<2_000 {
            if fixture.service.activeAttempt?.finishedAt != nil {
                break
            }
            await Task.yield()
        }

        let attempt = try #require(fixture.service.activeAttempt)
        #expect(attempt.status == .passed)
        #expect(attempt.taskResults.isEmpty)
        #expect(attempt.executionBranch == "main")
        #expect(fixture.runLauncher.prompts.isEmpty)
        #expect(!fixture.toolService.gitArguments.contains(where: {
            $0.hasPrefix("commit ") || $0.hasPrefix("push ")
        }))
    }

    @MainActor
    @Test func loopSnapshotsChangedRuntimeAndModelForEachNewTask() async throws {
        let fixture = try LoopFixture(safetyMode: .autoInsideSandbox)
        defer { fixture.cleanup() }
        try fixture.useTwoTaskPool()
        fixture.runLauncher.runtimeDescriptors = [
            AgentRuntimeDescriptor(
                id: "cursor.acp",
                displayName: "Cursor ACP",
                transport: .acp,
                modelOptions: [.init(id: "nano", title: "Nano")],
                defaultModelId: "nano"
            ),
            AgentRuntimeDescriptor(
                id: "claude.cli",
                displayName: "Claude Code",
                transport: .cli,
                modelOptions: [.init(id: "haiku", title: "Haiku")],
                defaultModelId: "haiku"
            )
        ]

        _ = try await fixture.service.start(sourcePath: fixture.sourceURL.path)
        for _ in 0..<4_000 {
            if fixture.service.activeAttempt?.finishedAt != nil {
                break
            }
            await Task.yield()
        }

        let attempt = try #require(fixture.service.activeAttempt)
        #expect(attempt.status == .passed)
        #expect(attempt.taskResults.map(\.runtimeName) == ["Cursor ACP", "Claude Code"])
        #expect(attempt.taskResults.map(\.modelId) == ["nano", "haiku"])
        #expect(
            fixture.runRepository.run(withId: attempt.controllerRunId)?
                .executionBackend?.displayName == "Claude Code"
        )

        let reportPath = try #require(attempt.reportPath)
        let report = try String(contentsOfFile: reportPath, encoding: .utf8)
        #expect(report.contains("| Cursor ACP | cursor.acp | nano |"))
        #expect(report.contains("| Claude Code | claude.cli | haiku |"))
    }

    private func task(category: ExecutionTaskCategory) -> ExecutionTask {
        ExecutionTask(
            id: "WHM-001",
            title: "Task",
            category: category,
            dependencies: [],
            goal: "Do work",
            definition: "Definition"
        )
    }

    private func result(
        id: String,
        status: ExecutionTaskResultStatus,
        start: Date,
        duration: TimeInterval
    ) -> ExecutionTaskResult {
        ExecutionTaskResult(
            taskId: id,
            title: id,
            category: .feature,
            status: status,
            profileId: "implementation",
            runtimeId: "cursor.acp",
            runtimeName: "Cursor ACP",
            modelId: "cursor-small",
            startedAt: start,
            finishedAt: start.addingTimeInterval(duration),
            buildPassed: status == .passed,
            testsPassed: status == .passed,
            pushSucceeded: status == .passed,
            failureReason: status == .passed ? nil : "Tests failed."
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ExecutionLoopTests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@MainActor
private final class LoopFixture {
    let rootURL: URL
    let targetURL: URL
    let sourceURL: URL
    let originalProject: Project
    let projectService: ProjectService
    let runLauncher: ExecutionLoopRunLauncherFake
    let toolService: ExecutionLoopToolServiceFake
    let service: ExecutionLoopService
    let runRepository: InMemoryRunRepository

    init(safetyMode: SafetyMode) throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ExecutionLoopFixture-\(UUID().uuidString)",
            isDirectory: true
        )
        targetURL = rootURL.appendingPathComponent("Target", isDirectory: true)
        sourceURL = rootURL.appendingPathComponent("tasks.md")
        try FileManager.default.createDirectory(
            at: targetURL.appendingPathComponent(".git", isDirectory: true),
            withIntermediateDirectories: true
        )
        try """
        # Pool
        - Repository: `\(targetURL.path)`
        - Base branch: `main`
        - Build command: `build command`
        - Test command: `test command`

        ### WHM-001 — Add feature
        - Status: `pending`
        - Category: feature
        - Dependencies: `none`
        - Goal: add a feature
        - Done when:
          - tests pass
        """.write(to: sourceURL, atomically: true, encoding: .utf8)

        let projectRepository = InMemoryProjectRepository()
        projectService = ProjectService(repository: projectRepository)
        originalProject = projectService.addProject(
            name: "Original",
            rootPath: rootURL.appendingPathComponent("Original").path
        )
        try projectService.selectProject(id: originalProject.id)

        runRepository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: runRepository)
        runLauncher = ExecutionLoopRunLauncherFake(
            repository: runRepository,
            projectService: projectService
        )
        toolService = ExecutionLoopToolServiceFake()
        let appSettings = InMemoryAppSettingsService(
            defaultAgentRuntimeId: "cursor.acp",
            defaultSafetyMode: safetyMode
        )
        service = ExecutionLoopService(
            taskSource: MarkdownExecutionTaskSource(),
            profileSelector: ExecutionProfileSelector(),
            runLauncher: runLauncher,
            runRepository: runRepository,
            recorder: recorder,
            toolService: toolService,
            projectService: projectService,
            agentProfileService: AgentProfileService(projectService: projectService),
            appSettingsService: appSettings,
            reportWriter: ExecutionLoopReportWriter(
                reportsRootURL: rootURL.appendingPathComponent("Reports", isDirectory: true)
            )
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func useTwoTaskPool() throws {
        try """
        # Pool
        - Repository: `\(targetURL.path)`
        - Base branch: `main`
        - Build command: `build command`
        - Test command: `test command`

        ### WHM-001 — Add feature
        - Status: `pending`
        - Category: feature
        - Dependencies: `none`
        - Goal: add a feature
        - Done when:
          - tests pass

        ### WHM-002 — Add tests
        - Status: `pending`
        - Category: tests
        - Dependencies: `WHM-001`
        - Goal: add tests
        - Done when:
          - tests pass
        """.write(to: sourceURL, atomically: true, encoding: .utf8)
    }
}

@MainActor
private final class ExecutionLoopRunLauncherFake: ExecutionLoopRunLaunchingProtocol {
    var runtimeDescriptors = [
        AgentRuntimeDescriptor(
            id: "cursor.acp",
            displayName: "Cursor ACP",
            transport: .acp,
            modelOptions: [.init(id: "nano", title: "Nano")],
            defaultModelId: "nano"
        )
    ]
    var selectedAgentRuntimeDescriptor: AgentRuntimeDescriptor? {
        guard !runtimeDescriptors.isEmpty else { return nil }
        return runtimeDescriptors[min(prompts.count, runtimeDescriptors.count - 1)]
    }

    private let repository: RunRepository
    private let projectService: ProjectServiceProtocol
    private(set) var prompts: [String] = []
    private(set) var configurations: [MultiAgentRunConfiguration] = []
    private(set) var progressMirrorRunIds: [UUID] = []
    private(set) var progressMirrorMetadata: [[String: String]] = []
    private(set) var lastRunId: UUID?

    init(repository: RunRepository, projectService: ProjectServiceProtocol) {
        self.repository = repository
        self.projectService = projectService
    }

    func run(withId runId: UUID) -> Run? {
        repository.run(withId: runId)
    }

    func startRun(
        goal: String,
        mode: RunMode,
        configuration: MultiAgentRunConfiguration,
        progressMirrorRunId: UUID,
        progressMirrorMetadata: [String: String]
    ) async -> UUID? {
        prompts.append(goal)
        configurations.append(configuration)
        progressMirrorRunIds.append(progressMirrorRunId)
        self.progressMirrorMetadata.append(progressMirrorMetadata)
        let run = Run(
            projectId: projectService.currentProject?.id,
            goal: goal,
            mode: mode,
            status: .completed,
            multiAgentConfiguration: configuration
        )
        repository.insert(run)
        lastRunId = run.id
        return run.id
    }

    func cancelRun(runId: UUID) async {
        repository.updateRun(runId) { $0.status = .cancelled }
    }
}

@MainActor
private final class ExecutionLoopToolServiceFake: ToolServiceProtocol {
    private struct Payload: Encodable {
        var exitCode: Int32
        var standardOutput: String
        var standardError: String
    }

    nonisolated var service: AppService { .tools }
    var availableTools: [ToolDefinition] { [] }
    private(set) var requests: [ToolExecutionRequest] = []
    private var statusReadCount = 0
    private var currentHead = "base-sha"
    var commitSubjectsOutput = ""
    var statusOutputs: [String]?

    var gitArguments: [String] {
        requests
            .filter { $0.toolId == "git.run" }
            .compactMap { $0.arguments["arguments"] }
    }

    func execute(_ request: ToolExecutionRequest) async throws -> ToolResult {
        try await executeAwaitingApproval(request)
    }

    func executeAwaitingApproval(_ request: ToolExecutionRequest) async throws -> ToolResult {
        requests.append(request)
        var output = ""
        if request.toolId == "git.run" {
            switch request.arguments["arguments"] {
            case "status --porcelain":
                statusReadCount += 1
                if let statusOutputs, statusReadCount <= statusOutputs.count {
                    output = statusOutputs[statusReadCount - 1]
                } else {
                    output = statusReadCount == 1 ? "" : " M README.md\n"
                }
            case "branch --show-current":
                output = "main\n"
            case "log --format=%s":
                output = commitSubjectsOutput
            case "rev-parse HEAD":
                output = "\(currentHead)\n"
            case let arguments? where arguments.hasPrefix("commit -m "):
                currentHead = "commit-sha"
                output = ""
            default:
                output = ""
            }
        }
        let data = try JSONEncoder().encode(Payload(
            exitCode: 0,
            standardOutput: output,
            standardError: ""
        ))
        return ToolResult(
            toolId: request.toolId,
            status: .succeeded,
            output: String(decoding: data, as: UTF8.self)
        )
    }
}

@MainActor
private final class ExecutionLoopMCPClientFake: MCPToolClientProtocol {
    private(set) var invocations: [MCPToolInvocation] = []

    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult {
        invocations.append(invocation)
        return ToolResult(
            toolId: invocation.toolId,
            status: .succeeded,
            output: #"{"exitCode":0,"standardOutput":"","standardError":""}"#
        )
    }
}
