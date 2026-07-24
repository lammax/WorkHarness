//
//  WorkHarnessTests.swift
//  WorkHarnessTests
//
//  Created by Максим Ламанский on 7.07.26.
//

import Testing
import Swinject
import Foundation
import AppKit
@testable import WorkHarness

struct WorkHarnessTests {

    @MainActor
    @Test func timelineDesignUsesAvailableSystemSymbolsForEveryRunEvent() {
        for eventType in RunEventType.allCases {
            let chatIcon = MainScreen.ChatPageDesign.EventRow.icon(for: eventType)
            let runsIcon = MainScreen.RunsPageDesign.EventRow.icon(for: eventType)

            #expect(
                NSImage(systemSymbolName: chatIcon, accessibilityDescription: nil) != nil,
                "Missing Chat SF Symbol: \(chatIcon)"
            )
            #expect(
                NSImage(systemSymbolName: runsIcon, accessibilityDescription: nil) != nil,
                "Missing Runs SF Symbol: \(runsIcon)"
            )
        }
    }

    @MainActor
    @Test func startingRunRecordsInitialEvents() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))

        _ = await engine.startRun(goal: "Create a harness run")

        #expect(repository.runs.count == 1)
        #expect(repository.runs[0].goal == "Create a harness run")
        #expect(repository.runs[0].events.map(\.type).contains(.runCreated))
        #expect(repository.runs[0].events.map(\.type).contains(.userMessage))
        #expect(repository.runs[0].events.map(\.type).contains(.providerStreamDelta))
        #expect(repository.runs[0].events.map(\.type).contains(.assistantMessage))
        #expect(repository.runs[0].events.map(\.type).contains(.runCompleted))
        #expect(repository.runs[0].status == .completed)
    }

    @MainActor
    @Test func providerErrorLeavesRunFailed() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(FailingAIProvider()))

        _ = await engine.startRun(goal: "Exercise failure path")

        let eventTypes = repository.runs[0].events.map(\.type)
        #expect(repository.runs[0].status == .failed)
        #expect(eventTypes.contains(.providerRequestFailed))
        #expect(eventTypes.contains(.runFailed))
        #expect(!eventTypes.contains(.runCompleted))
    }

    @MainActor
    @Test func appLaunchReconcilesPersistedActiveRunsAsInterrupted() throws {
        let repository = InMemoryRunRepository()
        let runningRun = Run(goal: "Running when the app closed", status: .running)
        let approvalRun = Run(goal: "Waiting when the app closed", status: .waitingForApproval)
        let completedRun = Run(goal: "Already complete", status: .completed)
        repository.insert(runningRun)
        repository.insert(approvalRun)
        repository.insert(completedRun)
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider())
        )
        let runService = RunService(repository: repository, harnessEngine: engine)

        runService.reconcileInterruptedRuns()
        runService.reconcileInterruptedRuns()

        #expect(repository.run(withId: runningRun.id)?.status == .interrupted)
        #expect(repository.run(withId: approvalRun.id)?.status == .interrupted)
        #expect(repository.run(withId: completedRun.id)?.status == .completed)
        #expect(repository.run(withId: runningRun.id)?.events.filter { $0.type == .runInterrupted }.count == 1)
        #expect(repository.run(withId: approvalRun.id)?.events.last?.metadata["previousStatus"] == "waitingForApproval")
        #expect(repository.run(withId: completedRun.id)?.events.isEmpty == true)
    }

    @MainActor
    @Test func interruptedRunResumesInNewRuntimeSessionWithRecoveryContext() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let client = FakeACPClient(id: "fake.recovery", displayName: "Recovery Agent")
        let runtime = ACPClientRuntime(client: client)
        let registry = AgentRuntimeRegistry()
        registry.register(runtime)
        let appSettings = InMemoryAppSettingsService(defaultAgentRuntimeId: runtime.id)
        let runId = UUID()
        let run = Run(
            id: runId,
            goal: "Finish the interrupted change",
            mode: .codingLoop,
            status: .interrupted,
            agents: [
                Agent(
                    role: .coder,
                    providerId: "agent-runtime:\(runtime.id)",
                    model: "fake"
                )
            ],
            events: [
                RunEvent(
                    runId: runId,
                    type: .fileChanged,
                    message: "Sources/App.swift"
                )
            ]
        )
        repository.insert(run)
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider()),
            appSettingsService: appSettings,
            agentRuntimeRegistry: registry
        )
        let runService = RunService(repository: repository, harnessEngine: engine)

        let didResume = await runService.resumeRun(runId: run.id)

        #expect(didResume)
        #expect(repository.run(withId: run.id)?.status == .completed)
        #expect(repository.run(withId: run.id)?.events.contains { $0.type == .runResumed } == true)
        #expect(client.tasks.count == 1)
        #expect(client.tasks[0].prompt.contains("Finish the interrupted change"))
        #expect(client.tasks[0].prompt.contains("Sources/App.swift"))
        #expect(client.tasks[0].prompt.contains("do not restart blindly"))
    }

    @MainActor
    @Test func interruptedRunCanBeCancelledWithoutAnActiveRuntimeSession() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Do not resume", status: .interrupted)
        repository.insert(run)
        let runService = makeRunService(repository: repository)

        await runService.cancelRun(runId: run.id)

        #expect(repository.run(withId: run.id)?.status == .cancelled)
        #expect(repository.run(withId: run.id)?.events.last?.type == .runCancelled)
    }

    @MainActor
    @Test func runPersistenceRetainsMultiAgentConfigurationForRestart() throws {
        var configuration = MultiAgentRunConfiguration.default
        configuration.profileId = "bug-fix"
        configuration.roles[1].enabled = false
        let run = Run(
            goal: "Restart the same workflow",
            mode: .multiAgent,
            multiAgentConfiguration: configuration
        )

        let data = try JSONEncoder().encode(run)
        let restored = try JSONDecoder().decode(Run.self, from: data)

        #expect(restored.multiAgentConfiguration == configuration)
    }

    @MainActor
    @Test func chatPageViewModelSubmitsDraftThroughEngine() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
        let runService = RunService(repository: repository, harnessEngine: engine)
        let viewModel = MainScreen.ChatPageViewModel(runService: runService)

        viewModel.draftMessage = "Build the first architecture slice"
        await viewModel.submitDraftAndWait()

        #expect(viewModel.draftMessage.isEmpty)
        #expect(viewModel.selectedRun != nil)
        #expect(viewModel.runs.first?.events.contains { $0.type == .assistantMessage } == true)
    }

    @MainActor
    @Test func chatPageViewModelStartsNewChatWithoutMutatingPreviousRun() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider())
        )
        let viewModel = MainScreen.ChatPageViewModel(
            runService: RunService(repository: repository, harnessEngine: engine)
        )
        viewModel.draftMessage = "First chat"
        await viewModel.submitDraftAndWait()
        let firstRunId = try #require(viewModel.selectedRunId)
        viewModel.draftMessage = "Unsaved follow-up"
        viewModel.draftRunMode = .multiAgent
        viewModel.draftContextAttachments = [
            RunContextAttachment(name: "Context.md", content: "Temporary context")
        ]

        viewModel.startNewChat()

        #expect(viewModel.selectedRunId == nil)
        #expect(viewModel.selectedRun == nil)
        #expect(viewModel.draftMessage.isEmpty)
        #expect(viewModel.draftContextAttachments.isEmpty)
        #expect(viewModel.draftRunMode == .simpleChat)
        #expect(repository.runs.count == 1)
        #expect(repository.runs.first?.id == firstRunId)
    }

    @MainActor
    @Test func chatPageViewModelStopsActiveAgentRuntimeRun() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let appSettings = InMemoryAppSettingsService(defaultAgentRuntimeId: "fake.cancellable")
        let registry = AgentRuntimeRegistry()
        let client = FakeACPClient(
            id: "fake.cancellable",
            displayName: "Cancellable Agent",
            waitsForCancellation: true
        )
        registry.register(ACPClientRuntime(client: client))
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider()),
            appSettingsService: appSettings,
            agentRuntimeRegistry: registry
        )
        let viewModel = MainScreen.ChatPageViewModel(
            runService: RunService(repository: repository, harnessEngine: engine)
        )

        viewModel.draftMessage = "Keep working until stopped"
        viewModel.submitDraft()
        for _ in 0..<100 where client.tasks.isEmpty {
            await Task.yield()
        }

        #expect(viewModel.isSending)
        await viewModel.stopRunAndWait()
        for _ in 0..<100 where viewModel.isSending {
            await Task.yield()
        }

        let run = try #require(repository.runs.first)
        #expect(!viewModel.isSending)
        #expect(client.cancelCount == 1)
        #expect(run.status == .cancelled)
        #expect(run.events.filter { $0.type == .runCancelled }.count == 1)
        #expect(!run.events.contains { $0.type == .runCompleted || $0.type == .runFailed })
    }

    @MainActor
    @Test func chatPageViewModelMergesMultiAgentChunksWithinEachPlanStep() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider())
        )
        let runService = RunService(repository: repository, harnessEngine: engine)
        let viewModel = MainScreen.ChatPageViewModel(runService: runService)
        let runId = UUID()
        let architectStepId = UUID().uuidString
        let coderStepId = UUID().uuidString
        let run = Run(
            id: runId,
            goal: "Build with multiple agents",
            mode: .multiAgent,
            events: [
                RunEvent(
                    runId: runId,
                    type: .providerStreamDelta,
                    message: "Архитектурный ",
                    metadata: ["planStepId": architectStepId, "role": AgentRole.architect.rawValue]
                ),
                RunEvent(
                    runId: runId,
                    type: .providerStreamDelta,
                    message: "ответ.",
                    metadata: ["planStepId": architectStepId, "role": AgentRole.architect.rawValue]
                ),
                RunEvent(
                    runId: runId,
                    type: .providerStreamDelta,
                    message: "Реализация ",
                    metadata: ["planStepId": coderStepId, "role": AgentRole.coder.rawValue]
                ),
                RunEvent(
                    runId: runId,
                    type: .providerStreamDelta,
                    message: "готова.",
                    metadata: ["planStepId": coderStepId, "role": AgentRole.coder.rawValue]
                )
            ]
        )
        repository.insert(run)
        viewModel.selectRun(run)

        let displayedDeltas = viewModel.displayEvents.filter { $0.type == .providerStreamDelta }

        #expect(displayedDeltas.count == 2)
        #expect(displayedDeltas[0].message == "Архитектурный ответ.")
        #expect(displayedDeltas[0].metadata["role"] == AgentRole.architect.rawValue)
        #expect(displayedDeltas[1].message == "Реализация готова.")
        #expect(displayedDeltas[1].metadata["role"] == AgentRole.coder.rawValue)
    }

    @MainActor
    @Test func contextAttachmentServiceLoadsUTF8TextAndRejectsBinaryData() async throws {
        let directory = try makeTemporaryDirectory()
        let textURL = directory.appendingPathComponent("Claude.md")
        let binaryURL = directory.appendingPathComponent("image.bin")
        try Data("# Swift rules".utf8).write(to: textURL)
        try Data([0x00, 0xFF, 0x10]).write(to: binaryURL)
        let service = RunContextAttachmentService()

        let attachment = try service.loadAttachment(from: textURL)

        #expect(attachment.name == "Claude.md")
        #expect(attachment.content == "# Swift rules")
        #expect(attachment.byteCount == 13)
        #expect(throws: RunContextAttachmentError.unsupportedEncoding) {
            try service.loadAttachment(from: binaryURL)
        }
    }

    @MainActor
    @Test func chatPageAttachesReadOnlyFileToRunAndProviderContext() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let provider = RecordingAIProvider()
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(provider)
        )
        let runService = RunService(repository: repository, harnessEngine: engine)
        let viewModel = MainScreen.ChatPageViewModel(
            runService: runService,
            contextAttachmentService: RunContextAttachmentService()
        )
        let attachmentURL = try makeTemporaryDirectory().appendingPathComponent("Claude.md")
        try Data("Use SwiftUI boundaries.".utf8).write(to: attachmentURL)

        await viewModel.attachFileAndWait(attachmentURL)
        viewModel.draftMessage = "Review the attached rules"
        await viewModel.submitDraftAndWait()

        let run = try #require(repository.runs.first)
        let request = try #require(provider.requests.first)
        #expect(viewModel.draftContextAttachments.isEmpty)
        #expect(run.contextAttachments.map(\.name) == ["Claude.md"])
        #expect(run.contextAttachments.first?.content == "Use SwiftUI boundaries.")
        #expect(request.context.contains { $0.contains("BEGIN ATTACHMENT Claude.md") })
        #expect(request.context.contains { $0.contains("Use SwiftUI boundaries.") })
        #expect(request.context.allSatisfy { !$0.contains(attachmentURL.deletingLastPathComponent().path) })
        #expect(run.events.first { $0.type == .userMessage }?.metadata["attachmentNames"] == "Claude.md")
    }

    @MainActor
    @Test func runServiceStartsRunThroughEngineAndExposesRepositoryState() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
        let runService = RunService(repository: repository, harnessEngine: engine)

        let runId = try #require(await runService.startRun(goal: "Route through service"))
        let run = try #require(runService.run(withId: runId))

        #expect(runService.providerName == "Test Provider")
        #expect(runService.runs.count == 1)
        #expect(run.goal == "Route through service")
        #expect(run.events.contains { $0.type == .runCompleted })
    }

    @MainActor
    @Test func harnessEngineUsesDefaultTokenBudgetFromAppSettings() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let provider = RecordingAIProvider()
        let appSettings = InMemoryAppSettingsService(defaultMaxInputTokens: 1_024, defaultMaxOutputTokens: 256)
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(provider),
            appSettingsService: appSettings
        )

        _ = await engine.startRun(goal: "Use configured budget")

        #expect(provider.requests.first?.budget == TokenBudget(maxInputTokens: 1_024, maxOutputTokens: 256))
    }

    @MainActor
    @Test func mainScreenRoutesSectionsThroughPages() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
        let runService = RunService(repository: repository, harnessEngine: engine)
        let chatPageViewModel = MainScreen.ChatPageViewModel(runService: runService)
        let runsPageViewModel = MainScreen.RunsPageViewModel(runService: runService)
        let statsPageViewModel = MainScreen.StatsPageViewModel(statisticsService: UsageStatisticsService(runService: runService))
        let settingsPageViewModel = MainScreen.SettingsPageViewModel(
            providerService: makeProviderService(TestAIProvider()),
            appSettingsService: InMemoryAppSettingsService()
        )
        let approvalService = makeApprovalService(repository: repository)
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        let screenModel = MainScreen.MainScreenViewModel(
            chatPageViewModel: chatPageViewModel,
            runsPageViewModel: runsPageViewModel,
            statsPageViewModel: statsPageViewModel,
            settingsPageViewModel: settingsPageViewModel,
            memoryPageViewModel: makeMemoryPageViewModel(projectService: projectService),
            approvalService: approvalService,
            projectService: projectService
        )

        #expect(screenModel.pages.first is MainScreen.MainShellPage)
        #expect(screenModel.detailPage is MainScreen.ChatPage)

        screenModel.show(section: .runs)

        #expect(screenModel.detailPage is MainScreen.RunsPage)

        screenModel.show(section: .stats)

        #expect(screenModel.detailPage is MainScreen.StatsPage)

        screenModel.show(section: .settings)

        #expect(screenModel.detailPage is MainScreen.SettingsPage)

        _ = await engine.startRun(goal: "Review navigation")
        let run = try #require(repository.runs.first)

        screenModel.selectRun(run)

        #expect(screenModel.selectedSection == .chat)
        #expect(screenModel.detailPage is MainScreen.ChatPage)
        #expect(chatPageViewModel.selectedRun?.id == run.id)
    }

    @MainActor
    @Test func swinjectContainerResolvesRegisteredAppGraph() async throws {
        UserDefaultsAppSettingsService().defaultProviderId = nil
        setenv("WORKHARNESS_SQLITE_PATH", try makeTemporaryDatabaseURL().path, 1)

        let container = Container()
        container.registerDependencies()

        let firstRepository = try #require(container.resolve(RunRepository.self))
        let secondRepository = try #require(container.resolve(RunRepository.self))
        let projectRepository = try #require(container.resolve(ProjectRepositoryProtocol.self))
        let projectService = try #require(container.resolve(ProjectServiceProtocol.self))
        let providerService = try #require(container.resolve(ProviderServiceProtocol.self))
        let runService = try #require(container.resolve(RunServiceProtocol.self))
        let approvalService = try #require(container.resolve(ApprovalServiceProtocol.self))
        let processRunner = try #require(container.resolve(ProcessRunnerProtocol.self))
        let agentRuntimeRegistry = try #require(container.resolve(AgentRuntimeRegistry.self))
        let contextBuilder = try #require(container.resolve(ContextBuilderProtocol.self))
        let toolRegistry = try #require(container.resolve(ToolRegistry.self))
        let mcpToolClient = try #require(container.resolve(MCPToolClientProtocol.self))
        let toolService = try #require(container.resolve(ToolServiceProtocol.self))
        let mcpApprovalGateway = try #require(container.resolve(MCPApprovalGatewayProtocol.self))
        let statisticsService = try #require(container.resolve(UsageStatisticsServiceProtocol.self))
        let statsViewModel = try #require(container.resolve(MainScreen.StatsPageViewModel.self))
        let settingsViewModel = try #require(container.resolve(MainScreen.SettingsPageViewModel.self))
        let scene = try #require(container.resolve(AppSceneProtocol.self))
        let mainScreen = try #require(container.resolve(MainScreenProtocol.self))

        #expect(firstRepository.runs.isEmpty)
        #expect(firstRepository === secondRepository)
        #expect(firstRepository is SQLiteRunRepository)
        #expect(projectRepository is SQLiteProjectRepository)
        #expect(projectRepository.projects.isEmpty)
        #expect(projectService.currentProject == nil)
        #expect(providerService.activeProviderId == MockAIProvider.providerId)
        #expect(runService.runs.isEmpty)
        #expect(approvalService.pendingRequests.isEmpty)
        #expect(processRunner is ProcessRunner)
        #expect(Set(agentRuntimeRegistry.runtimes.map(\.id)).isSubset(of: ["cursor.acp", "claude.cli"]))
        #expect(contextBuilder is ContextBuilder)
        #expect(toolRegistry.availableTools.contains { $0.id == "file.read" })
        #expect(toolRegistry.availableTools.contains { $0.id == "mobile.screen" })
        #expect(mcpToolClient is MCPToolClient)
        #expect(toolService.availableTools.contains { $0.id == "shell.run" })
        #expect(mcpApprovalGateway is MCPApprovalGateway)
        #expect(statisticsService.snapshot.total.runCount == 0)
        #expect(statsViewModel.isEmpty)
        #expect(settingsViewModel.activeProviderName == "Mock Local Provider")
        #expect(scene.viewModel.activeScreen != nil)
        #expect(mainScreen.pagesModel.pages.first is MainScreen.MainShellPage)
    }

    @MainActor
    @Test func toolRegistryExposesDefaultTools() async throws {
        let registry = ToolRegistry(tools: [
            FileReadTool(),
            FileWriteTool(),
            ShellTool(),
            GitTool(),
            RAGSearchTool()
        ])

        let ids = registry.availableTools.map(\.id).sorted()

        #expect(ids == ["file.read", "file.write", "git.run", "rag.search", "shell.run"])
        #expect(try registry.tool(id: "file.read").permission == .readOnly)
        #expect(try registry.tool(id: "file.write").permission == .workspaceWrite)
    }

    @MainActor
    @Test func toolServiceRoutesSafeFileReadThroughMCPAndRecordsEvents() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Read a project file")
        repository.insert(run)
        let mcpClient = FakeMCPToolClient(result: ToolResult(toolId: "file.read", status: .succeeded, output: "let value = 42\n"))
        let service = makeToolService(repository: repository, mcpClient: mcpClient, tools: [FileReadTool()])

        let result = try await service.execute(.init(
            runId: run.id,
            toolId: "file.read",
            arguments: ["path": "Sources/Example.swift"],
            projectRootPath: "/tmp/project"
        ))
        let eventTypes = try #require(repository.run(withId: run.id)?.events.map(\.type))

        #expect(result.status == .succeeded)
        #expect(result.output == "let value = 42\n")
        #expect(mcpClient.invocations.first?.toolId == "file.read")
        #expect(eventTypes == [.toolCallRequested, .toolCallStarted, .toolCallFinished, .toolResult])
    }

    @MainActor
    @Test func mcpToolClientRoutesHarnessToolsToExistingServers() async throws {
        let transport = RecordingMCPToolTransport(response: MCPToolTransportResponse(
            output: "written",
            isError: false
        ))
        let client = MCPToolClient(transport: transport)

        let result = try await client.invoke(MCPToolInvocation(
            toolId: "file.write",
            arguments: ["path": "README.md", "content": "updated"],
            projectRootPath: "/tmp/project"
        ))
        let call = try #require(transport.calls.first)

        #expect(result.status == .succeeded)
        #expect(call.endpoint == URL(string: "http://127.0.0.1:3005/mcp"))
        #expect(call.name == "project_write_file")
        #expect(call.arguments["path"] as? String == "README.md")
        #expect(call.arguments["project_root"] as? String == "/tmp/project")
        #expect(call.arguments["overwrite"] as? Bool == true)
    }

    @MainActor
    @Test func mcpToolClientRoutesMobileAutomationThroughDedicatedGateway() async throws {
        let artifact = RunArtifact(
            name: "Mobile screenshot",
            kind: "screenshot",
            path: "/tmp/project/.workharness/testing/reports/artifacts/screen.png"
        )
        let transport = RecordingMCPToolTransport(response: MCPToolTransportResponse(
            output: "captured",
            isError: false,
            artifacts: [artifact]
        ))
        let client = MCPToolClient(transport: transport)

        let result = try await client.invoke(MCPToolInvocation(
            toolId: "mobile.screen",
            arguments: [
                "action": "capture",
                "argumentsJSON": #"{"platform":"ios","preset":"medium"}"#
            ],
            projectRootPath: "/tmp/project"
        ))
        let call = try #require(transport.calls.first)

        #expect(result.status == .succeeded)
        #expect(result.artifacts == [artifact])
        #expect(call.endpoint == URL(string: "http://127.0.0.1:3009/mcp"))
        #expect(call.name == "screen")
        #expect(call.arguments["action"] as? String == "capture")
        #expect(call.arguments["platform"] as? String == "ios")
        #expect(call.arguments["preset"] as? String == "medium")
        #expect(call.arguments["argumentsJSON"] == nil)
    }

    @MainActor
    @Test func toolServiceRecordsMobileScreenshotAsRunArtifact() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Capture a smoke-test screenshot")
        repository.insert(run)
        let artifact = RunArtifact(
            name: "Mobile screenshot",
            kind: "screenshot",
            path: "/tmp/project/.workharness/testing/reports/artifacts/screen.png"
        )
        let mcpClient = FakeMCPToolClient(result: ToolResult(
            toolId: "mobile.screen",
            status: .succeeded,
            output: "captured",
            artifacts: [artifact]
        ))
        let service = makeToolService(
            repository: repository,
            mcpClient: mcpClient,
            tools: [try #require(MobileAutomationTool.approvedTools.first { $0.id == "mobile.screen" })]
        )

        let result = try await service.execute(.init(
            runId: run.id,
            toolId: "mobile.screen",
            arguments: ["action": "capture"],
            projectRootPath: "/tmp/project"
        ))
        let storedRun = try #require(repository.run(withId: run.id))

        #expect(result.artifacts == [artifact])
        #expect(storedRun.artifacts == [artifact])
        #expect(storedRun.events.map(\.type) == [
            .toolCallRequested,
            .toolCallStarted,
            .toolCallFinished,
            .artifactCreated,
            .toolResult
        ])
        #expect(storedRun.events[3].metadata["path"] == artifact.path)
    }

    @MainActor
    @Test func toolServiceRequestsApprovalBeforeFileWrite() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Write a project file")
        repository.insert(run)
        let projectRoot = try makeTemporaryDirectory()
        let approvalRepository = InMemoryApprovalRepository()
        let service = makeToolService(repository: repository, approvalRepository: approvalRepository, tools: [FileWriteTool()])

        let result = try await service.execute(.init(
            runId: run.id,
            toolId: "file.write",
            arguments: ["path": "Generated.txt", "content": "hello"],
            projectRootPath: projectRoot.path
        ))
        let storedRun = try #require(repository.run(withId: run.id))

        #expect(result.status == .approvalRequired)
        #expect(approvalRepository.requests.count == 1)
        #expect(approvalRepository.requests.first?.mode == .askBeforeWrite)
        #expect(storedRun.status == .waitingForApproval)
        #expect(storedRun.events.map(\.type) == [.toolCallRequested, .approvalRequested])
        #expect(!FileManager.default.fileExists(atPath: projectRoot.appendingPathComponent("Generated.txt").path))
    }

    @MainActor
    @Test func toolServiceRequestsApprovalBeforeShellAndDangerousGit() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Run dangerous tools")
        repository.insert(run)
        let approvalRepository = InMemoryApprovalRepository()
        let service = makeToolService(
            repository: repository,
            approvalRepository: approvalRepository,
            tools: [ShellTool(), GitTool()]
        )

        let shellResult = try await service.execute(.init(
            runId: run.id,
            toolId: "shell.run",
            arguments: ["command": "rm -rf build"],
            projectRootPath: "/tmp"
        ))
        let gitResult = try await service.execute(.init(
            runId: run.id,
            toolId: "git.run",
            arguments: ["arguments": "reset --hard HEAD"],
            projectRootPath: "/tmp"
        ))

        #expect(shellResult.status == .approvalRequired)
        #expect(gitResult.status == .approvalRequired)
        #expect(approvalRepository.requests.map(\.mode).sorted { $0.rawValue < $1.rawValue } == [.askBeforeShell, .askBeforeWrite])
    }

    @MainActor
    @Test func toolServiceWaitsForApprovalThenInvokesMCPOnce() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Write an approved file")
        repository.insert(run)
        let approvalRepository = InMemoryApprovalRepository()
        let approvalService = ApprovalService(
            repository: approvalRepository,
            runRepository: repository,
            recorder: RunRecorder(repository: repository),
            appSettingsService: InMemoryAppSettingsService()
        )
        let mcpClient = FakeMCPToolClient(result: ToolResult(
            toolId: "file.write",
            status: .succeeded,
            output: "written"
        ))
        let service = ToolService(
            registry: ToolRegistry(tools: [FileWriteTool()]),
            mcpClient: mcpClient,
            approvalService: approvalService,
            recorder: RunRecorder(repository: repository)
        )

        let execution = Task { @MainActor in
            try await service.executeAwaitingApproval(.init(
                runId: run.id,
                toolId: "file.write",
                arguments: ["path": "README.md", "content": "hello"],
                projectRootPath: "/tmp/project"
            ))
        }
        while approvalService.pendingRequests.isEmpty {
            await Task.yield()
        }
        let request = try #require(approvalService.pendingRequests.first)
        #expect(mcpClient.invocations.isEmpty)

        try approvalService.approve(requestId: request.id)
        let result = try await execution.value

        #expect(result.status == .succeeded)
        #expect(mcpClient.invocations.count == 1)
        #expect(repository.run(withId: run.id)?.events.map(\.type) == [
            .toolCallRequested,
            .approvalRequested,
            .approvalGranted,
            .toolCallStarted,
            .toolCallFinished,
            .toolResult
        ])
    }

    @MainActor
    @Test func toolServiceAutoApprovesWorkspaceActionAndInvokesMCP() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Write without repeated prompts")
        repository.insert(run)
        let approvalRepository = InMemoryApprovalRepository()
        let mcpClient = FakeMCPToolClient(result: ToolResult(
            toolId: "file.write",
            status: .succeeded,
            output: "written"
        ))
        let service = makeToolService(
            repository: repository,
            mcpClient: mcpClient,
            approvalRepository: approvalRepository,
            appSettingsService: InMemoryAppSettingsService(
                defaultSafetyMode: .autoInsideSandbox
            ),
            tools: [FileWriteTool()]
        )

        let result = try await service.executeAwaitingApproval(.init(
            runId: run.id,
            toolId: "file.write",
            arguments: ["path": "README.md", "content": "hello"],
            projectRootPath: "/tmp/project"
        ))

        #expect(result.status == .succeeded)
        #expect(mcpClient.invocations.count == 1)
        #expect(approvalRepository.requests.count == 1)
        #expect(approvalRepository.requests.first?.status == .granted)
        #expect(repository.run(withId: run.id)?.events.map(\.type) == [
            .toolCallRequested,
            .approvalRequested,
            .approvalGranted,
            .toolCallStarted,
            .toolCallFinished,
            .toolResult
        ])
    }

    @MainActor
    @Test func mcpApprovalGatewayListsAndExecutesHarnessTools() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Read a file")
        repository.insert(run)
        let mcpClient = FakeMCPToolClient(result: ToolResult(
            toolId: "file.read",
            status: .succeeded,
            output: "contents"
        ))
        let gateway = MCPApprovalGateway(toolService: makeToolService(
            repository: repository,
            mcpClient: mcpClient,
            tools: [FileReadTool()]
        ))

        let listResponse = await gateway.handle(
            requestBody: Data(#"{"jsonrpc":"2.0","id":1,"method":"tools/list","params":{}}"#.utf8),
            runId: run.id,
            projectRootPath: "/tmp/project"
        )
        let listObject = try #require(JSONSerialization.jsonObject(with: listResponse.body) as? [String: Any])
        let listResult = try #require(listObject["result"] as? [String: Any])
        let tools = try #require(listResult["tools"] as? [[String: Any]])

        #expect(tools.map { $0["name"] as? String } == ["file.read"])

        let callResponse = await gateway.handle(
            requestBody: Data(#"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"file.read","arguments":{"path":"README.md"}}}"#.utf8),
            runId: run.id,
            projectRootPath: "/tmp/project"
        )
        let callObject = try #require(JSONSerialization.jsonObject(with: callResponse.body) as? [String: Any])
        let callResult = try #require(callObject["result"] as? [String: Any])
        let content = try #require(callResult["content"] as? [[String: Any]])

        #expect(callResult["isError"] as? Bool == false)
        #expect(content.first?["text"] as? String == "contents")
        #expect(mcpClient.invocations.first?.projectRootPath == "/tmp/project")
    }

    @MainActor
    @Test func providerRegistryStoresRegisteredProviders() async throws {
        let registry = ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()])

        #expect(registry.availableProviders.map(\.id).sorted() == ["alternate.provider", "test.provider"])
        #expect(try registry.provider(id: "test.provider").displayName == "Test Provider")
    }

    @MainActor
    @Test func projectServiceAddsProjectWithRootPath() async throws {
        let projectService = ProjectService(repository: InMemoryProjectRepository())

        let project = projectService.addProject(name: "WorkHarness", rootPath: "/tmp/WorkHarness")

        #expect(projectService.projects.count == 1)
        #expect(projectService.projects.first == project)
        #expect(project.rootPath == "/tmp/WorkHarness")
        #expect(projectService.currentProject?.id == project.id)
    }

    @MainActor
    @Test func projectServiceSelectsCurrentProject() async throws {
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        let firstProject = projectService.addProject(name: "First", rootPath: "/tmp/First")
        let secondProject = projectService.addProject(name: "Second", rootPath: "/tmp/Second")

        try projectService.selectProject(id: secondProject.id)

        #expect(projectService.currentProject?.id == secondProject.id)
        #expect(projectService.currentProject?.id != firstProject.id)
    }

    @MainActor
    @Test func projectServiceRestoresCurrentProjectFromRepositoryState() async throws {
        let repository = InMemoryProjectRepository()
        let firstService = ProjectService(repository: repository)
        let project = firstService.addProject(name: "Shared State", rootPath: "/tmp/Shared")
        try firstService.selectProject(id: project.id)

        let restoredService = ProjectService(repository: repository)

        #expect(restoredService.currentProject?.id == project.id)
        #expect(restoredService.currentProject?.rootPath == "/tmp/Shared")
    }

    @MainActor
    @Test func projectServiceExposesMissingCurrentProjectEmptyState() async throws {
        let projectService = ProjectService(repository: InMemoryProjectRepository())

        #expect(projectService.projects.isEmpty)
        #expect(projectService.currentProject == nil)

        let runService = makeRunService()
        let screenModel = MainScreen.MainScreenViewModel(
            chatPageViewModel: MainScreen.ChatPageViewModel(runService: runService),
            runsPageViewModel: MainScreen.RunsPageViewModel(runService: runService),
            statsPageViewModel: MainScreen.StatsPageViewModel(statisticsService: UsageStatisticsService(runService: runService)),
            settingsPageViewModel: MainScreen.SettingsPageViewModel(
                providerService: makeProviderService(TestAIProvider()),
                appSettingsService: InMemoryAppSettingsService()
            ),
            memoryPageViewModel: makeMemoryPageViewModel(projectService: projectService),
            approvalService: makeApprovalService(),
            projectService: projectService
        )

        #expect(screenModel.projectDisplayState.isEmpty)
        #expect(screenModel.projectDisplayState.title == "No Project")
    }

    @MainActor
    @Test func userDefaultsProjectRepositoryPersistsProjectsAcrossInstances() async throws {
        let (suiteName, defaults) = try makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstRepository = UserDefaultsProjectRepository(defaults: defaults)
        let firstProject = Project(name: "First", rootPath: "/tmp/First")
        let secondProject = Project(name: "Second", rootPath: "/tmp/Second")
        firstRepository.insert(firstProject)
        firstRepository.insert(secondProject)
        firstRepository.selectProject(id: firstProject.id)

        let restoredRepository = UserDefaultsProjectRepository(defaults: defaults)

        #expect(restoredRepository.projects.map(\.id) == [secondProject.id, firstProject.id])
        #expect(restoredRepository.project(withId: firstProject.id)?.rootPath == "/tmp/First")
        #expect(restoredRepository.currentProjectId == firstProject.id)
    }

    @MainActor
    @Test func userDefaultsProjectRepositoryClearsCurrentProjectSelection() async throws {
        let (suiteName, defaults) = try makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let repository = UserDefaultsProjectRepository(defaults: defaults)
        let project = Project(name: "WorkHarness", rootPath: "/tmp/WorkHarness")
        repository.insert(project)
        repository.clearCurrentProject()

        let restoredRepository = UserDefaultsProjectRepository(defaults: defaults)

        #expect(restoredRepository.projects.first?.id == project.id)
        #expect(restoredRepository.currentProjectId == nil)
    }

    @MainActor
    @Test func userDefaultsProjectRepositoryIgnoresMissingSavedCurrentProject() async throws {
        let (suiteName, defaults) = try makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(UUID().uuidString, forKey: "projects.currentProjectId")
        let repository = UserDefaultsProjectRepository(defaults: defaults)

        #expect(repository.projects.isEmpty)
        #expect(repository.currentProjectId == nil)
    }

    @MainActor
    @Test func sqliteProjectRepositoryPersistsProjectsAcrossInstances() async throws {
        let databaseURL = try makeTemporaryDatabaseURL()
        let firstRepository = try SQLiteProjectRepository(database: SQLiteDatabase(url: databaseURL))
        let firstProject = Project(name: "First", rootPath: "/tmp/First")
        let secondProject = Project(name: "Second", rootPath: "/tmp/Second")

        firstRepository.insert(firstProject)
        firstRepository.insert(secondProject)
        firstRepository.selectProject(id: firstProject.id)

        let restoredRepository = try SQLiteProjectRepository(database: SQLiteDatabase(url: databaseURL))

        #expect(restoredRepository.projects.map(\.id) == [secondProject.id, firstProject.id])
        #expect(restoredRepository.project(withId: firstProject.id)?.rootPath == "/tmp/First")
        #expect(restoredRepository.currentProjectId == firstProject.id)
    }

    @MainActor
    @Test func sqliteRunRepositoryPersistsRunsAndEventsAcrossInstances() async throws {
        let databaseURL = try makeTemporaryDatabaseURL()
        let firstRepository = try SQLiteRunRepository(database: SQLiteDatabase(url: databaseURL))
        let run = Run(goal: "Persist run")
        let event = RunEvent(runId: run.id, type: .assistantMessage, message: "Stored")

        firstRepository.insert(run)
        firstRepository.appendEvent(event)

        let restoredRepository = try SQLiteRunRepository(database: SQLiteDatabase(url: databaseURL))
        let restoredRun = try #require(restoredRepository.run(withId: run.id))

        #expect(restoredRun.goal == "Persist run")
        #expect(restoredRun.events.map(\.id) == [event.id])
        #expect(restoredRun.events.first?.message == "Stored")
    }

    @MainActor
    @Test func sqliteMemoryRepositoryPersistsProjectMemoryAcrossInstances() async throws {
        let databaseURL = try makeTemporaryDatabaseURL()
        let project = Project(name: "Memory Project")
        let firstRepository = try SQLiteMemoryRepository(database: SQLiteDatabase(url: databaseURL))
        let item = MemoryItem(projectId: project.id, content: "The project uses MCP boundaries.")

        firstRepository.insert(item)

        let restoredRepository = try SQLiteMemoryRepository(database: SQLiteDatabase(url: databaseURL))

        #expect(restoredRepository.items(for: project.id) == [item])
    }

    @MainActor
    @Test func memoryServiceRejectsSensitiveContentAndRecordsMemoryEvent() throws {
        let runRepository = InMemoryRunRepository()
        let run = Run(goal: "Memory run")
        runRepository.insert(run)
        let service = MemoryService(
            repository: InMemoryMemoryRepository(),
            recorder: RunRecorder(repository: runRepository)
        )
        let project = Project(name: "Memory Project")

        let item = try service.saveProjectMemory(
            content: "  The project uses MCP boundaries.  ",
            projectId: project.id,
            runId: run.id
        )

        #expect(item.content == "The project uses MCP boundaries.")
        #expect(runRepository.run(withId: run.id)?.events.first?.type == .memorySaved)

        #expect(throws: MemoryServiceError.sensitiveContent) {
            try service.saveProjectMemory(content: "api_key = do-not-store", projectId: project.id)
        }
    }

    @MainActor
    @Test func mainScreenAddsProjectFromSelectorDraft() async throws {
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        let screenModel = makeMainScreenViewModel(projectService: projectService)

        screenModel.showProjectForm()
        screenModel.projectDraftName = "  WorkHarness  "
        screenModel.projectDraftRootPath = "  /tmp/WorkHarness  "
        screenModel.addProjectFromDraft()

        let project = try #require(screenModel.projects.first)
        #expect(project.name == "WorkHarness")
        #expect(project.rootPath == "/tmp/WorkHarness")
        #expect(screenModel.selectedProjectId == project.id)
        #expect(screenModel.projectDisplayState.title == "WorkHarness")
        #expect(!screenModel.isProjectFormPresented)
        #expect(screenModel.projectFormError == nil)
    }

    @MainActor
    @Test func mainScreenProjectSelectorRequiresProjectName() async throws {
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        let screenModel = makeMainScreenViewModel(projectService: projectService)

        screenModel.showProjectForm()
        screenModel.projectDraftName = "   "
        screenModel.projectDraftRootPath = "/tmp/MissingName"
        screenModel.addProjectFromDraft()

        #expect(screenModel.projects.isEmpty)
        #expect(screenModel.isProjectFormPresented)
        #expect(screenModel.projectFormError == "Project name is required.")
    }

    @MainActor
    @Test func mainScreenProjectSelectorAcceptsFolderPickerPath() async throws {
        let screenModel = makeMainScreenViewModel(projectService: ProjectService(repository: InMemoryProjectRepository()))

        screenModel.showProjectForm()
        screenModel.setProjectDraftRootPath("/tmp/SelectedProject")
        screenModel.projectDraftName = "Selected Project"
        screenModel.addProjectFromDraft()

        #expect(screenModel.projects.first?.rootPath == "/tmp/SelectedProject")
        #expect(screenModel.projectFormError == nil)
    }

    @MainActor
    @Test func mainScreenSelectsProjectThroughProjectService() async throws {
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        let firstProject = projectService.addProject(name: "First", rootPath: "/tmp/First")
        let secondProject = projectService.addProject(name: "Second", rootPath: "/tmp/Second")
        let screenModel = makeMainScreenViewModel(projectService: projectService)

        screenModel.selectProject(secondProject)

        #expect(screenModel.selectedProjectId == secondProject.id)
        #expect(screenModel.selectedProjectId != firstProject.id)
        #expect(screenModel.projectDisplayState.title == "Second")
        #expect(screenModel.projectDisplayState.subtitle == "/tmp/Second")
    }

    @MainActor
    @Test func runsPageViewModelBuildsRunDetailTimelineState() async throws {
        let repository = InMemoryRunRepository()
        let runId = UUID()
        let earlyEvent = RunEvent(
            runId: runId,
            type: .runCreated,
            message: "Created",
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let lateEvent = RunEvent(
            runId: runId,
            type: .providerRequestFinished,
            message: "Finished",
            metadata: ["providerId": "test.provider"],
            createdAt: Date(timeIntervalSince1970: 20)
        )
        let artifact = RunArtifact(
            name: "Report",
            kind: "markdown",
            path: "/tmp/report.md",
            createdAt: Date(timeIntervalSince1970: 30)
        )
        let run = Run(
            id: runId,
            goal: "Inspect timeline",
            status: .completed,
            events: [lateEvent, earlyEvent],
            artifacts: [artifact],
            tokenUsage: TokenUsage(inputTokens: 7, outputTokens: 11, totalCostUSD: Decimal(string: "0.42")!),
            costUsage: CostUsage(totalUSD: Decimal(string: "0.42")!),
            createdAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 40)
        )
        repository.insert(run)
        let viewModel = MainScreen.RunsPageViewModel(runService: makeRunService(repository: repository))

        let detail = try #require(viewModel.selectedRunDetail)

        #expect(detail.title == "Inspect timeline")
        #expect(detail.status == "Completed")
        #expect(detail.events.map(\.id) == [earlyEvent.id, lateEvent.id])
        #expect(detail.metrics.contains(MainScreen.MetricState(title: "Input", value: "7")))
        #expect(detail.metrics.contains(MainScreen.MetricState(title: "Output", value: "11")))
        #expect(detail.metrics.contains(MainScreen.MetricState(title: "Total", value: "18")))
        #expect(detail.metrics.contains(MainScreen.MetricState(title: "Cost", value: "$0.42")))
        #expect(detail.artifacts.first?.title == "Report")
        #expect(detail.selectedEvent?.id == lateEvent.id)
        #expect(detail.selectedEvent?.metadata.first?.key == "providerId")
    }

    @MainActor
    @Test func usageStatisticsServiceAggregatesUsageByProviderRunAndDay() async throws {
        let repository = InMemoryRunRepository()
        let runService = makeRunService(repository: repository)
        let service = UsageStatisticsService(runService: runService, calendar: Calendar(identifier: .gregorian))
        let firstDay = try #require(DateComponents(calendar: .current, year: 2026, month: 7, day: 8).date)
        let secondDay = try #require(DateComponents(calendar: .current, year: 2026, month: 7, day: 9).date)
        let codexRun = Run(
            goal: "Codex run",
            agents: [Agent(role: .coder, providerId: "codex.mcp", model: "codex")],
            tokenUsage: TokenUsage(inputTokens: 10, outputTokens: 15),
            costUsage: CostUsage(totalUSD: Decimal(string: "0.25")!),
            createdAt: firstDay,
            updatedAt: firstDay
        )
        let metadataRunId = UUID()
        let metadataRun = Run(
            id: metadataRunId,
            goal: "Metadata run",
            events: [
                RunEvent(
                    runId: metadataRunId,
                    type: .providerRequestStarted,
                    message: "provider",
                    metadata: ["providerId": "local.llm"],
                    createdAt: secondDay
                )
            ],
            tokenUsage: TokenUsage(inputTokens: 3, outputTokens: 7),
            costUsage: CostUsage(totalUSD: Decimal(string: "0.10")!),
            createdAt: secondDay,
            updatedAt: secondDay
        )

        repository.insert(codexRun)
        repository.insert(metadataRun)

        let snapshot = service.snapshot

        #expect(snapshot.total.runCount == 2)
        #expect(snapshot.total.inputTokens == 13)
        #expect(snapshot.total.outputTokens == 22)
        #expect(snapshot.total.totalTokens == 35)
        #expect(snapshot.total.totalCostUSD == Decimal(string: "0.35")!)
        #expect(snapshot.providers.map(\.providerId) == ["codex.mcp", "local.llm"])
        #expect(snapshot.providers.first?.totalTokens == 25)
        #expect(snapshot.runs.map(\.title) == ["Metadata run", "Codex run"])
        #expect(snapshot.days.map(\.runCount) == [1, 1])
    }

    @MainActor
    @Test func statsPageViewModelExposesUsageRows() async throws {
        let repository = InMemoryRunRepository()
        let runService = makeRunService(repository: repository)
        let viewModel = MainScreen.StatsPageViewModel(statisticsService: UsageStatisticsService(runService: runService))
        let run = Run(
            goal: "Measure usage",
            agents: [Agent(role: .coder, providerId: "stats.provider", model: "stats")],
            tokenUsage: TokenUsage(inputTokens: 4, outputTokens: 6),
            costUsage: CostUsage(totalUSD: Decimal(string: "0.50")!)
        )

        #expect(viewModel.isEmpty)

        repository.insert(run)

        #expect(!viewModel.isEmpty)
        #expect(viewModel.summaryCards.contains(MainScreen.StatsSummaryCardState(title: "Total", value: "10")))
        #expect(viewModel.summaryCards.contains(MainScreen.StatsSummaryCardState(title: "Cost", value: "$0.5")))
        #expect(viewModel.providerRows.first?.providerId == "stats.provider")
        #expect(viewModel.providerRows.first?.tokens == "10")
        #expect(viewModel.runRows.first?.title == "Measure usage")
        #expect(viewModel.dailyRows.first?.runs == "1")
    }

    @MainActor
    @Test func runsPageViewModelSelectsRunAndTimelineEvent() async throws {
        let repository = InMemoryRunRepository()
        let firstRunId = UUID()
        let secondRunId = UUID()
        let firstEvent = RunEvent(runId: firstRunId, type: .runCreated, message: "First")
        let secondEvent = RunEvent(runId: secondRunId, type: .assistantMessage, message: "Second")
        repository.insert(Run(id: firstRunId, goal: "First run", events: [firstEvent]))
        repository.insert(Run(id: secondRunId, goal: "Second run", events: [secondEvent]))
        let viewModel = MainScreen.RunsPageViewModel(runService: makeRunService(repository: repository))

        viewModel.selectRun(id: firstRunId)
        viewModel.selectEvent(id: firstEvent.id)

        #expect(viewModel.selectedRun?.id == firstRunId)
        #expect(viewModel.selectedEvent?.id == firstEvent.id)
        #expect(viewModel.runRows.first { $0.id == firstRunId }?.isSelected == true)
        #expect(viewModel.runRows.first { $0.id == secondRunId }?.isSelected == false)
    }

    @MainActor
    @Test func runsPageViewModelOpensExistingArtifactAndReportsMissingFile() async throws {
        let repository = InMemoryRunRepository()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkHarnessArtifactTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let reportURL = directory.appendingPathComponent("report.md")
        try Data("# Report".utf8).write(to: reportURL)
        let existingArtifact = RunArtifact(name: "Report", kind: "testing-report", path: reportURL.path)
        let missingArtifact = RunArtifact(
            name: "Missing",
            kind: "screenshot",
            path: directory.appendingPathComponent("missing.png").path
        )
        repository.insert(Run(goal: "Inspect evidence", artifacts: [existingArtifact, missingArtifact]))

        var openedURLs: [URL] = []
        let runService = makeRunService(
            repository: repository,
            artifactOpener: {
                openedURLs.append($0)
                return true
            }
        )
        let viewModel = MainScreen.RunsPageViewModel(runService: runService)

        viewModel.openArtifact(id: existingArtifact.id)

        #expect(openedURLs == [reportURL])
        #expect(viewModel.artifactError == nil)

        viewModel.openArtifact(id: missingArtifact.id)

        #expect(openedURLs == [reportURL])
        #expect(viewModel.artifactError == MainScreen.RunsPageDesign.Detail.artifactOpenFailure)
    }

    @MainActor
    @Test func runsPageViewModelExposesEmptyEventsState() async throws {
        let repository = InMemoryRunRepository()
        repository.insert(Run(goal: "Run without events"))
        let viewModel = MainScreen.RunsPageViewModel(runService: makeRunService(repository: repository))

        let detail = try #require(viewModel.selectedRunDetail)

        #expect(!detail.hasEvents)
        #expect(detail.events.isEmpty)
        #expect(detail.selectedEvent == nil)
    }

    @MainActor
    @Test func approvalServiceRequestsAndGrantsApproval() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Write a file")
        repository.insert(run)
        let approvalService = makeApprovalService(repository: repository)

        let request = try approvalService.requestApproval(
            runId: run.id,
            title: "Write file",
            summary: "Allow writing README.md.",
            mode: .askBeforeWrite
        )

        #expect(approvalService.pendingRequests.map(\.id) == [request.id])
        #expect(repository.run(withId: run.id)?.status == .waitingForApproval)
        #expect(repository.run(withId: run.id)?.events.last?.type == .approvalRequested)

        try approvalService.approve(requestId: request.id)

        #expect(approvalService.pendingRequests.isEmpty)
        #expect(approvalService.requests.first?.status == .granted)
        #expect(repository.run(withId: run.id)?.status == .running)
        #expect(repository.run(withId: run.id)?.events.map(\.type).contains(.approvalGranted) == true)
    }

    @MainActor
    @Test func approvalServiceRejectsApprovalAndFailsRun() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Run shell")
        repository.insert(run)
        let approvalService = makeApprovalService(repository: repository)

        let request = try approvalService.requestApproval(
            runId: run.id,
            title: "Run shell command",
            summary: "Allow shell execution.",
            mode: .askBeforeShell
        )

        try approvalService.reject(requestId: request.id)

        #expect(approvalService.requests.first?.status == .rejected)
        #expect(repository.run(withId: run.id)?.status == .failed)
        #expect(repository.run(withId: run.id)?.events.map(\.type).contains(.approvalRejected) == true)
    }

    @MainActor
    @Test func mainScreenShowsAndApprovesPendingApproval() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Ask before write")
        repository.insert(run)
        let approvalService = makeApprovalService(repository: repository)
        let request = try approvalService.requestApproval(
            runId: run.id,
            title: "Write workspace file",
            summary: "Allow writing inside the selected project.",
            mode: .askBeforeWrite
        )
        let screenModel = makeMainScreenViewModel(
            projectService: ProjectService(repository: InMemoryProjectRepository()),
            approvalService: approvalService
        )

        #expect(screenModel.pendingApprovalStates.map(\.id) == [request.id])

        let state = try #require(screenModel.pendingApprovalStates.first)
        screenModel.showApproval(state)
        screenModel.approveActiveApproval()

        #expect(!screenModel.isApprovalSheetPresented)
        #expect(screenModel.pendingApprovalStates.isEmpty)
        #expect(repository.run(withId: run.id)?.events.map(\.type).contains(.approvalGranted) == true)
    }

    @MainActor
    @Test func processRunnerStreamsStdoutAndStderr() async throws {
        let runner = ProcessRunner()

        let events = try await collectProcessEvents(
            runner: runner,
            script: "printf stdout-value; printf stderr-value >&2"
        )

        #expect(events.contains { if case .started = $0 { true } else { false } })
        #expect(events.contains(.stdout("stdout-value")))
        #expect(events.contains(.stderr("stderr-value")))
        #expect(events.last == .finished(ProcessExit(status: .succeeded, exitCode: 0)))
    }

    @MainActor
    @Test func processRunnerMapsNonZeroExitCode() async throws {
        let runner = ProcessRunner()

        let events = try await collectProcessEvents(runner: runner, script: "exit 7")

        #expect(events.last == .finished(ProcessExit(status: .failed, exitCode: 7)))
    }

    @MainActor
    @Test func processRunnerTimesOutLongProcess() async throws {
        let runner = ProcessRunner()

        let events = try await collectProcessEvents(runner: runner, script: "sleep 2", timeout: 0.05)

        #expect(events.last == .finished(ProcessExit(status: .timedOut, exitCode: nil)))
    }

    @MainActor
    @Test func processRunnerCancelsRunningProcess() async throws {
        let runner = ProcessRunner()
        let session = try runner.start(ProcessRunRequest(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "sleep 2"]
        ))
        var iterator = session.events.makeAsyncIterator()
        let startedEvent = try await iterator.next()

        session.cancel()
        let finishedEvent = try await iterator.next()

        #expect(startedEvent != nil)
        #expect(finishedEvent == .finished(ProcessExit(status: .cancelled, exitCode: nil)))
    }

    @MainActor
    @Test func processRunnerRejectsMissingExecutable() async throws {
        let runner = ProcessRunner()
        let missingURL = URL(fileURLWithPath: "/tmp/workharness-missing-executable")

        do {
            _ = try runner.start(ProcessRunRequest(executableURL: missingURL))
            Issue.record("Missing executable should throw.")
        } catch let error as ProcessRunnerError {
            #expect(error == .executableNotFound(missingURL.path))
        }
    }

    @MainActor
    @Test func agentExecutableLocatorFindsExecutableOnConfiguredPath() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executableURL = directory.appendingPathComponent("fake-agent")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executableURL.path
        )

        let locatedURL = AgentExecutableLocator.find(
            named: "fake-agent",
            searchPath: directory.path,
            homeDirectoryURL: directory
        )

        #expect(locatedURL == executableURL)
    }

    @MainActor
    @Test func cliAgentTransportSupportsInputOutputAndCleanExit() async throws {
        let transport = CLIAgentSubprocessTransport()
        let session = try transport.start(CLIAgentProcessConfiguration(
            executableURL: URL(fileURLWithPath: "/bin/cat"),
            timeout: 2
        ))

        try session.sendLine("cli-agent-round-trip")
        session.closeInput()

        var events: [CLIAgentProcessEvent] = []
        for try await event in session.events {
            events.append(event)
        }

        #expect(events.contains { if case .started = $0 { true } else { false } })
        #expect(events.contains(.stdout("cli-agent-round-trip\n")))
        #expect(events.last == .finished(ProcessExit(status: .succeeded, exitCode: 0)))
    }

    @MainActor
    @Test func cliAgentTransportCancelsRunningProcess() async throws {
        let transport = CLIAgentSubprocessTransport()
        let session = try transport.start(CLIAgentProcessConfiguration(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "sleep 2"]
        ))
        var iterator = session.events.makeAsyncIterator()
        _ = try await iterator.next()

        session.cancel()
        let finishedEvent = try await iterator.next()

        #expect(finishedEvent == .finished(ProcessExit(status: .cancelled, exitCode: nil)))
    }

    @MainActor
    @Test func providerServiceSelectsActiveProvider() async throws {
        let settingsService = InMemoryAppSettingsService()
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()]),
            appSettingsService: settingsService
        )

        try providerService.selectProvider(id: "alternate.provider")

        #expect(providerService.activeProviderId == "alternate.provider")
        #expect(try providerService.activeProvider().displayName == "Alternate Provider")
        #expect(settingsService.defaultProviderId == "alternate.provider")
    }

    @MainActor
    @Test func selectingMissingProviderThrowsProviderError() async throws {
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider()]),
            appSettingsService: InMemoryAppSettingsService()
        )

        do {
            try providerService.selectProvider(id: "missing.provider")
            Issue.record("Selecting a missing provider should throw.")
        } catch let error as ProviderError {
            #expect(error == .providerNotFound("missing.provider"))
        }
    }

    @MainActor
    @Test func providerServiceExposesCapabilities() async throws {
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [AlternateAIProvider()]),
            appSettingsService: InMemoryAppSettingsService()
        )

        let capabilities = try providerService.capabilities(for: "alternate.provider")

        #expect(capabilities.supportsStreaming)
        #expect(capabilities.contextWindowTokens == 2_000)
        #expect(capabilities.supportedModels == ["alternate-model"])
    }

    @MainActor
    @Test func harnessEngineUsesActiveProviderWithoutConcreteProviderType() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()]),
            appSettingsService: InMemoryAppSettingsService()
        )
        try providerService.selectProvider(id: "alternate.provider")
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: providerService)

        _ = await engine.startRun(goal: "Use active provider")

        let run = try #require(repository.runs.first)
        #expect(run.agents.first?.providerId == "alternate.provider")
        #expect(run.events.contains { $0.type == .assistantMessage && $0.message == "Hello from alternate provider." })
    }

    @MainActor
    @Test func contextBuilderCreatesMinimalProjectSnapshot() async throws {
        let builder = ContextBuilder()
        let project = Project(name: "WorkHarness", rootPath: "/tmp/WorkHarness")
        let agent = Agent(role: .coder, providerId: "test.provider", model: "test-model")
        let runId = UUID()

        let snapshot = builder.buildSnapshot(from: ContextBuildInput(
            runId: runId,
            agent: agent,
            providerId: "test.provider",
            userMessage: "Add context",
            currentProject: project,
            recentRunSummary: "Previous run summary",
            selectedFiles: ["WorkHarness/App/AppContainer.swift"],
            tokenBudget: TokenBudget(maxInputTokens: 1_000, maxOutputTokens: 200)
        ))

        #expect(snapshot.runId == runId)
        #expect(snapshot.agentId == agent.id)
        #expect(snapshot.providerId == "test.provider")
        #expect(snapshot.userMessage == "Add context")
        #expect(snapshot.projectId == project.id)
        #expect(snapshot.projectName == "WorkHarness")
        #expect(snapshot.rootPath == "/tmp/WorkHarness")
        #expect(snapshot.contextItems.contains("Current project: WorkHarness"))
        #expect(snapshot.contextItems.contains("Project root: /tmp/WorkHarness"))
        #expect(snapshot.includedFiles == ["WorkHarness/App/AppContainer.swift"])
        #expect(snapshot.includedSummaries == ["Previous run summary"])
        #expect(snapshot.includedMemories.isEmpty)
        #expect(snapshot.tokenCount > 0)
    }

    @MainActor
    @Test func contextBuilderAddsAutoApprovalInstructionOnlyForAutoMode() {
        let builder = ContextBuilder()
        let runId = UUID()
        let agent = Agent(role: .coder, providerId: "test.provider", model: "test-model")

        let automaticSnapshot = builder.buildSnapshot(from: ContextBuildInput(
            runId: runId,
            agent: agent,
            providerId: "test.provider",
            userMessage: "Update the file",
            safetyMode: .autoInsideSandbox
        ))
        let manualSnapshot = builder.buildSnapshot(from: ContextBuildInput(
            runId: runId,
            agent: agent,
            providerId: "test.provider",
            userMessage: "Update the file",
            safetyMode: .askBeforeWrite
        ))

        #expect(automaticSnapshot.contextItems.contains(ContextBuilder.autoApprovalInstruction))
        #expect(automaticSnapshot.summary.contains("[WORKHARNESS_APPROVAL_MODE: AUTO_INSIDE_PROJECT]"))
        #expect(!manualSnapshot.contextItems.contains(ContextBuilder.autoApprovalInstruction))
    }

    @MainActor
    @Test func acpRuntimeRunsFakeAgentAndMapsEventsToRunTimeline() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Implement ACP runtime")
        repository.insert(run)
        let recorder = RunRecorder(repository: repository)
        let client = FakeACPClient()
        let runtime = ACPClientRuntime(client: client)
        let registry = AgentRuntimeRegistry()
        registry.register(runtime)

        let session = try await runtime.connect()
        let task = AgentTask(runId: run.id, prompt: run.goal)
        let execution = try await runtime.run(task: task, sessionId: session.id)
        let mapper = ACPRunEventMapper(recorder: recorder)
        var events: [AgentEvent] = []

        for try await event in execution.events {
            events.append(event)
            mapper.record(runId: run.id, event: event)
        }

        let timeline = try #require(repository.run(withId: run.id)?.events)

        #expect(registry.runtime(id: "fake.acp") === runtime)
        #expect(session.capabilities.supports(.canEditFiles))
        #expect(events.contains(.started))
        #expect(events.contains(.textDelta("Patch ready.")))
        #expect(events.contains(.fileChanged(path: "Sources/App.swift")))
        #expect(timeline.contains { $0.type == .agentStarted })
        #expect(timeline.contains { $0.type == .providerStreamDelta && $0.message == "Patch ready." })
        #expect(timeline.contains { $0.type == .fileChanged && $0.message == "Sources/App.swift" })
        #expect(timeline.contains { $0.type == .agentFinished })
    }

    @MainActor
    @Test func harnessEngineRunsSelectedACPAgentThroughRunFlow() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let appSettings = InMemoryAppSettingsService(
            defaultAgentRuntimeId: "fake.acp",
            defaultSafetyMode: .autoInsideSandbox
        )
        appSettings.setAgentModelId("fake-selected-model", for: "fake.acp")
        let registry = AgentRuntimeRegistry()
        let client = FakeACPClient()
        registry.register(ACPClientRuntime(client: client))
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider()),
            contextBuilder: ContextBuilder(),
            appSettingsService: appSettings,
            agentRuntimeRegistry: registry
        )

        let runId = try #require(await engine.startRun(goal: "Run through Cursor"))
        let run = try #require(repository.run(withId: runId))

        #expect(run.mode == .codingLoop)
        #expect(run.agents.first?.providerId == "agent-runtime:fake.acp")
        #expect(run.status == .completed)
        #expect(client.configuredModelId == "fake-selected-model")
        #expect(client.tasks.first?.context?.summary.contains(
            "[WORKHARNESS_APPROVAL_MODE: AUTO_INSIDE_PROJECT]"
        ) == true)
        #expect(run.events.contains { $0.type == .fileChanged && $0.message == "Sources/App.swift" })
        #expect(run.events.contains { $0.type == .runCompleted })
    }

    @MainActor
    @Test func harnessEnginePassesAttachmentContentToSelectedAgentRuntime() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let appSettings = InMemoryAppSettingsService(defaultAgentRuntimeId: "fake.acp")
        let registry = AgentRuntimeRegistry()
        let client = FakeACPClient()
        registry.register(ACPClientRuntime(client: client))
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider()),
            contextBuilder: ContextBuilder(),
            appSettingsService: appSettings,
            agentRuntimeRegistry: registry
        )
        let attachment = RunContextAttachment(
            name: "Claude.md",
            content: "Prefer feature-scoped SwiftUI types."
        )

        _ = await engine.startRun(
            goal: "Review the attached rules",
            contextAttachments: [attachment]
        )

        let task = try #require(client.tasks.first)
        #expect(task.context?.includedFiles.contains("Claude.md") == true)
        #expect(task.context?.contextItems.contains {
            $0.contains("Prefer feature-scoped SwiftUI types.")
        } == true)
        #expect(task.context?.contextItems.allSatisfy { !$0.contains("/Users/") } == true)
    }

    @MainActor
    @Test func acpCodecEncodesJSONRPCLineAndDecodesAgentEvents() throws {
        let request = ACPMessage(id: 7, method: "session/start", params: ["project": "/tmp/project"])
        let encoded = try ACPCodec.encode(request)
        let encodedText = try #require(String(data: encoded, encoding: .utf8))
        #expect(encodedText.hasSuffix("\n"))
        #expect(encodedText.contains("session"))

        let event = try ACPCodec.decodeEvent(from: Data("""
        {"method":"file/changed","params":{"path":"Sources/App.swift"}}
        """.utf8))

        #expect(event == .fileChanged(path: "Sources/App.swift"))
    }

    @MainActor
    @Test func claudeStreamJSONParserMapsChunkedOutputWithoutDuplicatingText() throws {
        let parser = ClaudeStreamJSONParser()
        let firstChunk = """
        {"type":"system","subtype":"init","session_id":"session-1","model":"claude-sonnet-5"}
        {"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Hel
        """
        let secondChunk = """
        lo"}}}
        {"type":"assistant","message":{"content":[{"type":"text","text":"Hello"},{"type":"tool_use","id":"tool-1","name":"Read","input":{"path":"README.md"}}]}}
        {"type":"result","subtype":"success","is_error":false,"result":"Hello","total_cost_usd":0.004,"usage":{"input_tokens":12,"output_tokens":3}}

        """

        let events = try parser.parse(firstChunk) + parser.parse(secondChunk) + parser.finish()
        let usage = TokenUsage(inputTokens: 12, outputTokens: 3, totalCostUSD: Decimal(string: "0.004") ?? 0)

        #expect(events == [
            .started,
            .textDelta("Hello"),
            .toolCallRequested(name: "Read", input: "{\"path\":\"README.md\"}"),
            .tokenUsage(usage),
            .messageCompleted("Hello"),
            .finished(AgentResponse(message: "Hello", tokenUsage: usage, artifacts: []))
        ])
    }

    @MainActor
    @Test func utf8StreamDecoderPreservesClaudeJSONSplitInsideCyrillicScalar() throws {
        let jsonLine = """
        {"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"Файл прочитан"}}}

        """
        let data = Data(jsonLine.utf8)
        let scalarBytes = Array("Ф".utf8)
        let scalarStart = try #require(data.firstRange(of: Data(scalarBytes))?.lowerBound)
        let splitIndex = scalarStart + 1
        var decoder = UTF8StreamDecoder()
        let parser = ClaudeStreamJSONParser()

        let firstOutput = decoder.decode(data.prefix(splitIndex))
        let secondOutput = decoder.decode(data.suffix(from: splitIndex))
        let events = try parser.parse(firstOutput) + parser.parse(secondOutput) + parser.finish()

        #expect(firstOutput.hasSuffix("\"text\":\""))
        #expect(secondOutput.hasPrefix("Файл"))
        #expect(events == [.textDelta("Файл прочитан")])
        #expect(decoder.finish().isEmpty)
    }

    @MainActor
    @Test func claudeStreamJSONParserMapsThinkingAndFailure() throws {
        let parser = ClaudeStreamJSONParser()
        let events = try parser.parse("""
        {"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"thinking_delta","thinking":"Checking project"}}}
        {"type":"result","subtype":"error_max_turns","is_error":true,"result":"Maximum turns reached"}

        """)

        #expect(events == [
            .thinking("Checking project"),
            .failed("Maximum turns reached")
        ])
    }

    @MainActor
    @Test func claudeCLIRuntimeStreamsEventsAndResumesRunSession() async throws {
        let firstOutput = """
        {"type":"system","subtype":"init","session_id":"claude-session-1"}
        {"type":"stream_event","event":{"type":"content_block_delta","delta":{"type":"text_delta","text":"First"}}}
        {"type":"result","subtype":"success","is_error":false,"session_id":"claude-session-1","result":"First","usage":{"input_tokens":4,"output_tokens":1}}

        """
        let secondOutput = """
        {"type":"system","subtype":"init","session_id":"claude-session-1"}
        {"type":"result","subtype":"success","is_error":false,"session_id":"claude-session-1","result":"Second","usage":{"input_tokens":5,"output_tokens":1}}

        """
        let transport = FakeCLIAgentProcessTransport(eventBatches: [
            [.stdout(firstOutput), .finished(ProcessExit(status: .succeeded, exitCode: 0))],
            [.stdout(secondOutput), .finished(ProcessExit(status: .succeeded, exitCode: 0))]
        ])
        let runtime = ClaudeCLIRuntime(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            transport: transport
        )
        let runId = UUID()
        runtime.configure(modelId: "opus", runId: runId)

        let firstSession = try await runtime.connect()
        let firstExecution = try await runtime.run(
            task: AgentTask(runId: runId, prompt: "First", workingDirectory: "/tmp/project"),
            sessionId: firstSession.id
        )
        let firstEvents = try await collectAgentEvents(firstExecution.events)
        await runtime.disconnect(sessionId: firstSession.id)

        runtime.configure(modelId: "opus", runId: runId)
        let secondSession = try await runtime.connect()
        let secondExecution = try await runtime.run(
            task: AgentTask(runId: runId, prompt: "Second", workingDirectory: "/tmp/project"),
            sessionId: secondSession.id
        )
        let secondEvents = try await collectAgentEvents(secondExecution.events)

        #expect(firstEvents.contains(.textDelta("First")))
        #expect(firstEvents.contains(.messageCompleted("First")))
        #expect(secondEvents.contains(.messageCompleted("Second")))
        #expect(transport.configurations[0].arguments.contains("opus"))
        #expect(transport.configurations[0].workingDirectoryURL?.path == "/tmp/project")
        #expect(transport.configurations[0].arguments.contains("--strict-mcp-config"))
        #expect(transport.configurations[0].arguments.contains("--mcp-config"))
        #expect(transport.configurations[0].arguments.contains("--tools"))
        #expect(transport.configurations[0].arguments.contains("mcp__workharness__*"))
        #expect(transport.configurations[0].arguments.contains("dontAsk"))
        let resumeIndex = try #require(transport.configurations[1].arguments.firstIndex(of: "--resume"))
        #expect(transport.configurations[1].arguments[resumeIndex + 1] == "claude-session-1")
    }

    @MainActor
    @Test func claudeCLIRuntimeCancellationStopsActiveProcess() async throws {
        let transport = FakeCLIAgentProcessTransport(eventBatches: [[]], finishesStreams: false)
        let runtime = ClaudeCLIRuntime(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            transport: transport
        )
        let session = try await runtime.connect()
        _ = try await runtime.run(
            task: AgentTask(runId: UUID(), prompt: "Long task"),
            sessionId: session.id
        )

        await runtime.cancel(sessionId: session.id)

        #expect(transport.cancellationCount == 1)
    }

    @MainActor
    @Test(.enabled(if: ProcessInfo.processInfo.environment["WORKHARNESS_LIVE_CLAUDE_TEST"] == "1"))
    func liveClaudeRunReadsProjectFileThroughApprovedMCPGateway() async throws {
        let claudeURL = try #require(AgentExecutableLocator.find(named: "claude"))
        let projectRoot = try makeTemporaryDirectory()
        let marker = "workharness-live-claude-\(UUID().uuidString)"
        try marker.write(
            to: projectRoot.appendingPathComponent("marker.txt"),
            atomically: true,
            encoding: .utf8
        )

        let port = Int.random(in: 20_000...50_000)
        let token = "live-claude-test-token"
        let settings = InMemoryAppSettingsService(
            defaultProviderId: TestAIProvider().id,
            defaultAgentRuntimeId: ClaudeCLIRuntime.runtimeId,
            mcpServerBasePath: AppSettingsDefaults.mcpServerBasePath,
            remoteControlEnabled: true,
            remoteControlPort: port,
            remoteControlToken: token
        )
        settings.setAgentModelId("sonnet", for: ClaudeCLIRuntime.runtimeId)

        let runRepository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: runRepository)
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        _ = projectService.addProject(name: "Live Claude Test", rootPath: projectRoot.path)
        let approvalService = ApprovalService(
            repository: InMemoryApprovalRepository(),
            runRepository: runRepository,
            recorder: recorder,
            appSettingsService: settings
        )
        let serverSupervisor = MCPServerProcessSupervisor {
            settings.mcpServerBasePath
        }
        let mcpClient = MCPToolClient(transport: MCPHTTPToolTransport(
            serverSupervisor: serverSupervisor
        ))
        let toolService = ToolService(
            registry: ToolRegistry(tools: [FileReadTool()]),
            mcpClient: mcpClient,
            approvalService: approvalService,
            recorder: recorder
        )
        let gateway = MCPApprovalGateway(toolService: toolService)
        let runtimeRegistry = AgentRuntimeRegistry()
        let configurationFactory = ClaudeMCPConfigurationFactory {
            ClaudeMCPConfigurationFactory.GatewaySettings(
                baseURL: URL(string: "http://127.0.0.1:\(port)")!,
                authorizationToken: token
            )
        }
        runtimeRegistry.register(ClaudeCLIRuntime(
            executableURL: claudeURL,
            transport: CLIAgentSubprocessTransport(),
            mcpConfigurationFactory: configurationFactory
        ))
        let engine = HarnessEngine(
            repository: runRepository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider()),
            projectService: projectService,
            appSettingsService: settings,
            agentRuntimeRegistry: runtimeRegistry
        )
        let runService = RunService(repository: runRepository, harnessEngine: engine)
        let remoteControl = RemoteControlService(
            runRepository: runRepository,
            runService: runService,
            projectService: projectService,
            approvalService: approvalService,
            appSettingsService: settings,
            mcpApprovalGateway: gateway,
            port: UInt16(port),
            token: token
        )
        try remoteControl.start()
        defer { remoteControl.stop() }
        for _ in 0..<50 where !remoteControl.isRunning {
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(remoteControl.isRunning)

        let runId = try #require(await runService.startRun(
            goal: "Use the file.read tool to read marker.txt. Reply with the exact file content and nothing else."
        ))
        let run = try #require(runRepository.run(withId: runId))
        let assistantOutput = run.events
            .filter { $0.type == .providerStreamDelta || $0.type == .assistantMessage }
            .map(\.message)
            .joined()

        #expect(run.status == .completed)
        #expect(assistantOutput.contains(marker))
        #expect(run.events.contains { $0.type == .toolCallFinished })
    }

    @MainActor
    @Test func claudeMCPConfigurationUsesOnlyPerRunHarnessGateway() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkHarnessTests.ClaudeMCP.\(UUID().uuidString)")
        let factory = ClaudeMCPConfigurationFactory(
            baseDirectoryURL: rootURL,
            gatewayBaseURL: URL(string: "http://127.0.0.1:9876")!,
            authorizationToken: "test-token"
        )
        let runId = UUID()

        let configuration = try factory.makeConfiguration(runId: runId)
        let data = try Data(contentsOf: configuration.fileURL)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let servers = try #require(object["mcpServers"] as? [String: Any])
        let server = try #require(servers["workharness"] as? [String: Any])

        #expect(servers.count == 1)
        #expect(server["type"] as? String == "http")
        #expect(server["url"] as? String == "http://127.0.0.1:9876/mcp/runs/\(runId.uuidString)")
        #expect((server["headers"] as? [String: String])?["Authorization"] == "Bearer test-token")

        factory.removeConfiguration(at: configuration.fileURL)
        #expect(!FileManager.default.fileExists(atPath: configuration.fileURL.path))
    }

    @MainActor
    @Test func acpSubprocessClientPerformsHandshakeAndStartsSessionTask() async throws {
        let connection = FakeACPConnection()
        let client = ACPSubprocessClient(
            id: "fake.subprocess",
            displayName: "Fake Subprocess Agent",
            transport: FakeACPTransport(connection: connection)
        )

        let session = try await client.connect()
        let executionEvents = try await client.run(
            task: AgentTask(runId: UUID(), prompt: "Do the task"),
            sessionId: session.id
        )
        var events: [ACPEvent] = []
        for try await event in executionEvents {
            events.append(event)
        }

        #expect(session.capabilities.supports(.canPlan))
        #expect(connection.messages.map(\.method) == ["initialize", "session/new", "session/prompt"])
        #expect(events.contains { event in
            if case .finished = event { return true }
            return false
        })
    }

    @MainActor
    @Test func acpAgentFactoryCreatesProviderAgnosticRuntime() throws {
        let model = AgentRuntimeModelOption(id: "configured-model", title: "Configured Model")
        let definition = ACPAgentDefinition(
            id: "configured.acp",
            displayName: "Configured ACP Agent",
            subprocess: ACPSubprocessConfiguration(executableURL: URL(fileURLWithPath: "/usr/bin/true")),
            modelOptions: [model],
            defaultModelId: model.id,
            capabilities: AgentCapabilities([.canEditFiles])
        )
        let runtime = ACPAgentFactory(definition: definition).makeRuntime()

        #expect(runtime.id == "configured.acp")
        #expect(runtime.displayName == "Configured ACP Agent")
        #expect(runtime.descriptor.transport == .acp)
        #expect(runtime.descriptor.modelOptions == [model])
        #expect(runtime.descriptor.defaultModelId == model.id)
        #expect(runtime.descriptor.capabilities.supports(.canEditFiles))
    }

    @MainActor
    @Test func cursorACPDefinitionIsDiscoveredWhenCursorIsInstalled() {
        #expect(ACPAgentDefinitions.cursor()?.id == "cursor.acp")
    }

    @Test func capabilityBasedAgentPlannerBuildsOrderedExecutionPlan() throws {
        let planner = CapabilityBasedAgentPlanner()
        let candidates = [
            AgentCandidate(
                agent: Agent(role: .research, providerId: "research", model: "research"),
                capabilities: AgentCapabilities([.canPlan])
            ),
            AgentCandidate(
                agent: Agent(role: .research, providerId: "coder", model: "coder"),
                capabilities: AgentCapabilities([.canEditFiles, .canUseTools])
            ),
            AgentCandidate(
                agent: Agent(role: .research, providerId: "review", model: "review"),
                capabilities: AgentCapabilities([.canOpenDiff])
            ),
            AgentCandidate(
                agent: Agent(role: .research, providerId: "tests", model: "tests"),
                capabilities: AgentCapabilities([.canRunTests])
            )
        ]

        let plan = try planner.plan(goal: "Implement feature", candidates: candidates)

        #expect(plan.steps.map(\.role) == [.architect, .coder, .reviewer, .testRunner])
        #expect(plan.steps[1].dependsOn == [plan.steps[0].id])
        #expect(plan.steps[2].dependsOn == [plan.steps[1].id])
        #expect(plan.steps[3].dependsOn == [plan.steps[1].id])
    }

    @Test func capabilityBasedAgentPlannerFailsWhenCapabilityIsMissing() {
        let planner = CapabilityBasedAgentPlanner()
        let candidate = AgentCandidate(
            agent: Agent(role: .coder, providerId: "coder", model: "coder"),
            capabilities: AgentCapabilities([.canPlan])
        )

        #expect(throws: AgentPlannerError.noCandidate(role: .coder, requiredCapabilities: [.canEditFiles, .canUseTools])) {
            try planner.plan(goal: "Implement feature", candidates: [candidate])
        }
    }

    @Test func capabilityBasedAgentPlannerUsesConfiguredOrderAndSkipsDisabledAssistants() throws {
        let planner = CapabilityBasedAgentPlanner()
        let candidate = AgentCandidate(
            agent: Agent(role: .research, providerId: "all", model: "all"),
            capabilities: AgentCapabilities([.canPlan, .canEditFiles, .canUseTools, .canOpenDiff, .canRunTests])
        )
        var configuration = MultiAgentRunConfiguration.default
        configuration.roles.swapAt(0, 3)
        configuration.roles[1].enabled = false

        let plan = try planner.plan(
            goal: "Implement feature",
            candidates: [candidate],
            configuration: configuration
        )

        #expect(plan.steps.map(\.role) == [.testRunner, .reviewer, .architect])
        #expect(plan.steps[0].dependsOn.isEmpty)
        #expect(plan.steps[1].dependsOn == [plan.steps[0].id])
        #expect(plan.steps[2].dependsOn == [plan.steps[1].id])
        #expect(plan.steps.map(\.configurationId) == [
            configuration.roles[0].id,
            configuration.roles[2].id,
            configuration.roles[3].id
        ])
    }

    @MainActor
    @Test func agentProfileServiceSeedsProjectCatalogAndLoadsMarkdownPrompts() throws {
        let projectRoot = try makeTemporaryDirectory()
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Profiles", rootPath: projectRoot.path)

        let service = AgentProfileService(projectService: projectService)
        let configuration = service.configuration(for: "bug-fix")
        let directory = projectRoot.appendingPathComponent(AgentProfileDefaults.directoryName)

        #expect(service.profiles.map(\.id) == ["bug-fix", "research", "implementation", "testing"])
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(AgentProfileDefaults.manifestFileName).path
        ))
        #expect(configuration.profileName == "Bug Fix")
        #expect(configuration.roles.map(\.assistantName) == [
            "Bug Investigator",
            "Fix Implementer",
            "Regression Verifier"
        ])
        #expect(configuration.roles[0].instructions.contains("Do not edit files"))
        #expect(configuration.roles[1].instructions.contains("deterministic regression test"))
        #expect(configuration.roles[2].promptFilePath.hasSuffix("bug-fix-verifier.md"))
    }

    @MainActor
    @Test func agentProfileServicePersistsSelectionAndAssistantOrder() throws {
        let projectRoot = try makeTemporaryDirectory()
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Profiles", rootPath: projectRoot.path)
        let service = AgentProfileService(projectService: projectService)
        service.selectProfile(id: "bug-fix")
        let implementerId = try #require(service.selectedProfile?.assistants[1].id)

        try service.moveAssistant(id: implementerId, direction: .up)

        let reloaded = AgentProfileService(projectService: projectService)
        #expect(reloaded.selectedProfileId == "bug-fix")
        #expect(reloaded.selectedProfile?.assistants.map(\.name) == [
            "Fix Implementer",
            "Bug Investigator",
            "Regression Verifier"
        ])
        #expect(reloaded.configuration(for: nil).roles.first?.assistantName == "Fix Implementer")
    }

    @MainActor
    @Test func agentProfileServicePersistsAssistantExecutionSettings() throws {
        let projectRoot = try makeTemporaryDirectory()
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Profiles", rootPath: projectRoot.path)
        let service = AgentProfileService(projectService: projectService)
        service.selectProfile(id: "bug-fix")
        let assistants = try #require(service.selectedProfile?.assistants)
        let implementerId = assistants[1].id
        let verifierId = assistants[2].id

        try service.setAssistantEnabled(id: implementerId, enabled: false, profileId: "bug-fix")
        try service.setAssistantEnabled(id: verifierId, enabled: false, profileId: "bug-fix")
        try service.setAssistantModelOverride(
            id: implementerId,
            modelOverride: "claude-sonnet",
            profileId: "bug-fix"
        )

        let reloaded = AgentProfileService(projectService: projectService)
        let configuration = reloaded.configuration(for: "bug-fix")
        #expect(configuration.roles.map(\.enabled) == [true, false, false])
        #expect(configuration.roles[1].modelOverride == "claude-sonnet")
    }

    @MainActor
    @Test func agentProfileServiceImportsMarkdownForTheMappedAssistant() throws {
        let projectRoot = try makeTemporaryDirectory()
        let sourceDirectory = try makeTemporaryDirectory()
        let sourceURL = sourceDirectory.appendingPathComponent("custom.md")
        try "# Custom Research\nReturn verified evidence only.".write(
            to: sourceURL,
            atomically: true,
            encoding: .utf8
        )
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Profiles", rootPath: projectRoot.path)
        let service = AgentProfileService(projectService: projectService)
        service.selectProfile(id: "research")
        let researcherId = try #require(service.selectedProfile?.assistants.first?.id)

        try service.replacePrompt(for: researcherId, withContentsOf: sourceURL)

        let configuration = service.configuration(for: "research")
        #expect(configuration.roles.count == 1)
        #expect(configuration.roles[0].id == researcherId)
        #expect(configuration.roles[0].instructions.contains("Return verified evidence only"))
        #expect(configuration.roles[0].promptFilePath.hasSuffix("research.md"))
    }

    @MainActor
    @Test func agentProfileServiceReloadsPromptFileBeforeBuildingRunConfiguration() throws {
        let projectRoot = try makeTemporaryDirectory()
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Profiles", rootPath: projectRoot.path)
        let service = AgentProfileService(projectService: projectService)
        service.selectProfile(id: "research")
        let researcherId = try #require(service.selectedProfile?.assistants.first?.id)
        let promptURL = try service.promptFileURL(for: researcherId)
        try "# Edited Prompt\nEDITED_ON_DISK_MARKER".write(
            to: promptURL,
            atomically: true,
            encoding: .utf8
        )

        let configuration = service.configuration(for: "research")

        #expect(configuration.roles.first?.instructions.contains("EDITED_ON_DISK_MARKER") == true)
    }

    @MainActor
    @Test func multiAgentCoordinatorExecutesPlanInDependencyOrder() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let run = Run(goal: "Multi-agent task", mode: .multiAgent)
        repository.insert(run)
        let runtime = ACPClientRuntime(client: FakeACPClient())
        let agent = Agent(role: .coder, providerId: "fake.acp", model: "fake")
        let candidate = AgentCandidate(agent: agent, capabilities: AgentCapabilities([.canUseTools]))
        let first = AgentPlanStep(role: .coder, agentId: agent.id, requiredCapabilities: [])
        let second = AgentPlanStep(role: .reviewer, agentId: agent.id, requiredCapabilities: [], dependsOn: [first.id])
        let plan = AgentExecutionPlan(goal: run.goal, steps: [first, second])

        let result = try await MultiAgentCoordinator(repository: repository, recorder: recorder).execute(
            plan: plan,
            candidates: [candidate],
            runtimes: [agent.id: runtime],
            runId: run.id,
            configuration: .default
        )

        #expect(result.steps.map(\.stepId) == [first.id, second.id])
        #expect(repository.run(withId: run.id)?.events.filter { $0.type == .agentStarted }.count == 2)
        #expect(repository.run(withId: run.id)?.events.filter { $0.type == .agentFinished }.count == 2)
    }

    @MainActor
    @Test func multiAgentCoordinatorPassesMappedMarkdownPromptAndProfileMetadata() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let run = Run(goal: "Research authorization", mode: .multiAgent)
        repository.insert(run)
        let client = FakeACPClient()
        let runtime = ACPClientRuntime(client: client)
        let agent = Agent(role: .research, providerId: "fake.acp", model: "fake")
        let candidate = AgentCandidate(
            agent: agent,
            capabilities: AgentCapabilities([.canUseTools])
        )
        let assistantId = UUID()
        let configuration = MultiAgentRunConfiguration(
            profileId: "research",
            profileName: "Research",
            roles: [
                MultiAgentRoleConfiguration(
                    id: assistantId,
                    role: .research,
                    assistantName: "Codebase Researcher",
                    promptFilePath: "/tmp/project/.workharness/agent-profiles/research.md",
                    instructions: "RESEARCH_PROMPT_MARKER"
                )
            ]
        )
        let step = AgentPlanStep(
            configurationId: assistantId,
            role: .research,
            agentId: agent.id,
            requiredCapabilities: [.canUseTools]
        )

        _ = try await MultiAgentCoordinator(repository: repository, recorder: recorder).execute(
            plan: AgentExecutionPlan(goal: run.goal, steps: [step]),
            candidates: [candidate],
            runtimes: [agent.id: runtime],
            runId: run.id,
            configuration: configuration
        )

        let task = try #require(client.tasks.first)
        let startedEvent = try #require(
            repository.run(withId: run.id)?.events.first { $0.type == .agentStarted }
        )
        #expect(task.prompt.contains("RESEARCH_PROMPT_MARKER"))
        #expect(task.prompt.contains("Assistant: Codebase Researcher"))
        #expect(startedEvent.metadata["profileId"] == "research")
        #expect(startedEvent.metadata["assistantName"] == "Codebase Researcher")
        #expect(startedEvent.metadata["promptFilePath"]?.hasSuffix("research.md") == true)
    }

    @MainActor
    @Test func harnessEngineStopsActiveMultiAgentSessionWithoutStartingNextRole() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let appSettings = InMemoryAppSettingsService(defaultAgentRuntimeId: "fake.multi.cancellable")
        let registry = AgentRuntimeRegistry()
        let client = FakeACPClient(
            id: "fake.multi.cancellable",
            displayName: "Cancellable Multi-Agent",
            waitsForCancellation: true
        )
        registry.register(ACPClientRuntime(client: client))
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider()),
            appSettingsService: appSettings,
            agentRuntimeRegistry: registry
        )

        let executionTask = Task {
            await engine.startRun(
                goal: "Run all roles",
                mode: .multiAgent,
                configuration: .default
            )
        }
        for _ in 0..<100 where client.tasks.isEmpty {
            await Task.yield()
        }
        let runId = try #require(repository.runs.first?.id)

        await engine.cancelRun(runId: runId)
        _ = await executionTask.value

        let run = try #require(repository.run(withId: runId))
        #expect(client.cancelCount == 1)
        #expect(client.tasks.count == 1)
        #expect(run.status == .cancelled)
        #expect(run.events.filter { $0.type == .runCancelled }.count == 1)
        #expect(!run.events.contains { $0.type == .runCompleted || $0.type == .runFailed })
    }

    @MainActor
    @Test func harnessEngineBuildsProviderContextThroughContextBuilder() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "WorkHarness", rootPath: "/tmp/WorkHarness")
        let provider = RecordingAIProvider()
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(provider),
            projectService: projectService,
            contextBuilder: ContextBuilder()
        )

        _ = await engine.startRun(goal: "Use context")

        let request = try #require(provider.requests.first)
        let run = try #require(repository.runs.first)
        #expect(request.context.contains("Current project: WorkHarness"))
        #expect(request.context.contains("Project root: /tmp/WorkHarness"))
        #expect(run.events.contains { $0.type == .contextBuilt })
        #expect(run.events.first { $0.type == .contextBuilt }?.metadata["providerId"] == "recording.provider")
    }

    @MainActor
    @Test func harnessEnginePassesDurableRAGSettingsIntoContext() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let settings = RAGRetrievalSettings(
            chunkingStrategy: .structure,
            retrievalMode: .basic,
            topKBeforeFiltering: 16,
            topKAfterFiltering: 4,
            similarityThreshold: 0.6,
            relevanceFilterMode: .heuristic
        )
        let appSettings = InMemoryAppSettingsService(
            ragAnswerMode: .enabled,
            ragRetrievalSettings: settings
        )
        let ragService = FakeRAGService(result: RAGSearchResult(
            answer: "MCP answer",
            citations: [RAGCitation(
                source: "README.md",
                section: "Architecture",
                chunkID: 1,
                quote: "RAG is MCP-backed.",
                score: 0.88
            )],
            isUnknown: false,
            retrieval: RAGRetrievalSummary(
                originalQuestion: "Use RAG",
                searchQuery: "Use RAG",
                candidatesBeforeFiltering: 16,
                chunksAfterFiltering: 4,
                bestScore: 0.88
            )
        ))
        let provider = RecordingAIProvider()
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(provider),
            contextBuilder: ContextBuilder(),
            ragService: ragService,
            appSettingsService: appSettings
        )

        _ = await engine.startRun(goal: "Use RAG")

        #expect(ragService.lastSettings == settings)
        #expect(provider.requests.first?.context.contains { $0.contains("RAG is MCP-backed.") } == true)
        #expect(repository.runs.first?.agents.first?.contextPolicy.includeRAG == true)
    }

    @MainActor
    @Test func contextBuilderIncludesProjectMemoryItems() async throws {
        let project = Project(name: "Memory Project")
        let agent = Agent(role: .coder, providerId: "test.provider", model: "test-model")

        let snapshot = ContextBuilder().buildSnapshot(from: ContextBuildInput(
            runId: UUID(),
            agent: agent,
            providerId: agent.providerId,
            userMessage: "Continue",
            currentProject: project,
            memoryItems: ["The project uses MCP boundaries."]
        ))

        #expect(snapshot.includedMemories == ["The project uses MCP boundaries."])
        #expect(snapshot.summary.contains("Project memory:"))
    }

    @MainActor
    @Test func contextBuilderIncludesRAGCitations() async throws {
        let project = Project(name: "RAG Project")
        let agent = Agent(role: .coder, providerId: "test.provider", model: "test-model")
        let citation = RAGCitation(
            source: "Docs/Architecture.md",
            section: "MCP",
            chunkID: 3,
            quote: "All tools cross the MCP boundary.",
            score: 0.91
        )

        let snapshot = ContextBuilder().buildSnapshot(from: ContextBuildInput(
            runId: UUID(),
            agent: agent,
            providerId: agent.providerId,
            userMessage: "How do tools work?",
            currentProject: project,
            ragResults: [citation]
        ))

        #expect(snapshot.includedRAGResults == [citation])
        #expect(snapshot.summary.contains("RAG results:"))
        #expect(snapshot.summary.contains("All tools cross the MCP boundary."))
    }

    @MainActor
    @Test func contextFoldingPreservesDecisionsFailuresAndNextActions() throws {
        let runId = UUID()
        var run = Run(id: runId, goal: "Finish the feature", status: .failed)
        run.events = [
            RunEvent(runId: runId, type: .userMessage, message: "Implement the feature"),
            RunEvent(runId: runId, type: .assistantMessage, message: "I inspected the project."),
            RunEvent(runId: runId, type: .approvalGranted, message: "Write approved"),
            RunEvent(runId: runId, type: .providerRequestFailed, message: "Provider timed out")
        ]

        let summary = ContextFoldingService().fold(run: run)

        #expect(summary.runSummary.contains("Finish the feature"))
        #expect(summary.conversationSummary.contains("Implement the feature"))
        #expect(summary.decisionLog.contains("Approval Granted: Write approved"))
        #expect(summary.failedAttempts.contains("Provider Failed: Provider timed out"))
        #expect(summary.currentState.contains("Failed"))
        #expect(summary.nextActions.first?.contains("retry") == true)
    }

    @MainActor
    @Test func compactContextAppendsEventAndSummaryCanBuildContext() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: makeProviderService(TestAIProvider()),
            contextBuilder: ContextBuilder(),
            contextFoldingService: ContextFoldingService()
        )

        _ = await engine.startRun(goal: "Compact this run")
        let runId = try #require(repository.runs.first?.id)
        let summary = try #require(engine.compactContext(runId: runId))
        let run = try #require(repository.run(withId: runId))
        let compactedEvent = try #require(run.events.last { $0.type == .contextCompacted })

        #expect(compactedEvent.message == summary.renderedText)
        #expect(compactedEvent.metadata["sourceEventCount"] == "\(summary.sourceEventCount)")

        let agent = try #require(run.agents.first)
        let snapshot = ContextBuilder().buildSnapshot(from: ContextBuildInput(
            runId: runId,
            agent: agent,
            providerId: agent.providerId,
            userMessage: "Continue",
            contextFoldSummary: summary
        ))

        #expect(snapshot.includedSummaries.contains(summary.renderedText))
        #expect(snapshot.summary.contains("Folded context:"))
    }

    @MainActor
    @Test func mcpBackedProviderMapsStreamToAIEvents() async throws {
        let client = FakeMCPProviderClient(events: [
            .started,
            .messageDelta("Hello "),
            .messageDelta("from MCP"),
            .messageCompleted("Hello from MCP"),
            .tokenUsage(TokenUsage(inputTokens: 4, outputTokens: 6)),
            .finished
        ])
        let provider = MCPBackedAIProvider(descriptor: .codexCLI, client: client)
        let request = makeAIRequest(prompt: "Build MCP provider", workingDirectory: "/tmp/WorkHarness")

        let events = try await collectAIEvents(from: provider, request: request)

        #expect(client.requests.first?.providerId == MCPProviderDescriptor.codexCLI.id)
        #expect(client.requests.first?.aiRequest.workingDirectory == "/tmp/WorkHarness")
        #expect(events == [
            .started,
            .messageDelta("Hello "),
            .messageDelta("from MCP"),
            .messageCompleted("Hello from MCP"),
            .tokenUsage(TokenUsage(inputTokens: 4, outputTokens: 6)),
            .finished
        ])
    }

    @MainActor
    @Test func mcpBackedProviderMapsFailureToAIError() async throws {
        let client = FakeMCPProviderClient(events: [
            .started,
            .failed("MCP provider failed")
        ])
        let provider = MCPBackedAIProvider(descriptor: .cursorCLI, client: client)
        let request = makeAIRequest(
            prompt: "Fail please",
            providerId: MCPProviderDescriptor.cursorCLI.id,
            model: "cursor-agent"
        )

        let events = try await collectAIEvents(from: provider, request: request)

        #expect(client.requests.first?.providerId == MCPProviderDescriptor.cursorCLI.id)
        #expect(events == [
            .started,
            .error("MCP provider failed")
        ])
    }

    @MainActor
    @Test func mcpBackedLocalLLMProviderMapsStreamToAIEvents() async throws {
        let client = FakeMCPProviderClient(events: [
            .started,
            .messageDelta("Local "),
            .messageDelta("answer"),
            .messageCompleted("Local answer"),
            .finished
        ])
        let provider = MCPBackedAIProvider(descriptor: .localLLM, client: client)
        let request = makeAIRequest(
            prompt: "Use the local model",
            providerId: MCPProviderDescriptor.localLLM.id,
            model: "local-private"
        )

        let events = try await collectAIEvents(from: provider, request: request)

        #expect(client.requests.first?.providerId == MCPProviderDescriptor.localLLM.id)
        #expect(client.requests.first?.aiRequest.model == "local-private")
        #expect(events == [
            .started,
            .messageDelta("Local "),
            .messageDelta("answer"),
            .messageCompleted("Local answer"),
            .finished
        ])
    }

    @MainActor
    @Test func mcpBackedCLIProvidersAreRegisteredAndSelectable() async throws {
        let container = Container()
        container.registerDependencies()
        let providerService = try #require(container.resolve(ProviderServiceProtocol.self))
        let settingsViewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: InMemoryAppSettingsService()
        )

        #expect(settingsViewModel.providers.contains { $0.id == MCPProviderDescriptor.codexCLI.id && $0.name == "Codex CLI" })
        #expect(settingsViewModel.providers.contains { $0.id == MCPProviderDescriptor.cursorCLI.id && $0.name == "Cursor CLI" })
        #expect(settingsViewModel.providers.contains { $0.id == MCPProviderDescriptor.localLLM.id && $0.name == "Local LLM" })

        let cursor = try #require(settingsViewModel.providers.first { $0.id == MCPProviderDescriptor.cursorCLI.id })
        #expect(cursor.transport == "MCP-backed")
        #expect(cursor.availability == "Local")

        settingsViewModel.selectProvider(id: MCPProviderDescriptor.localLLM.id)

        #expect(providerService.activeProviderId == MCPProviderDescriptor.localLLM.id)
        #expect(settingsViewModel.activeProviderName == "Local LLM")
    }

    @MainActor
    @Test func settingsPageViewModelSelectsACPAgentRuntime() async throws {
        let appSettings = InMemoryAppSettingsService()
        let registry = AgentRuntimeRegistry()
        let model = AgentRuntimeModelOption(id: "fake-model", title: "Fake Model")
        let runtime = ACPClientRuntime(
            client: FakeACPClient(),
            descriptor: AgentRuntimeDescriptor(
                id: "fake.acp",
                displayName: "Fake ACP Agent",
                transport: .acp,
                authentication: .runtimeManaged,
                modelOptions: [model],
                defaultModelId: model.id,
                capabilities: AgentCapabilities([.canEditFiles])
            )
        )
        registry.register(runtime)
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider()]),
            appSettingsService: appSettings
        )
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: appSettings,
            agentRuntimeRegistry: registry
        )

        viewModel.selectExecutionBackend(id: MainScreen.ExecutionBackendItem.runtimeId(runtime.id))

        #expect(viewModel.activeAgentRuntimeId == runtime.id)
        #expect(appSettings.defaultAgentRuntimeId == runtime.id)
        #expect(viewModel.agentRuntimes.first?.isActive == true)
        #expect(viewModel.agentRuntimes.first?.transport == "ACP")
        #expect(viewModel.agentRuntimes.first?.availability == "Installed")
        #expect(viewModel.agentRuntimes.first?.authentication == "Sign-in managed by runtime")
        #expect(viewModel.agentRuntimes.first?.modelOptions == [model])
        #expect(viewModel.selectedAgentModelId == model.id)
        #expect(viewModel.activeExecutionBackendName == "Fake ACP Agent")
        #expect(viewModel.executionBackends.contains {
            $0.kind == .agentRuntime && $0.name == "Fake ACP Agent" && $0.isActive
        })

        let providerBackendId = MainScreen.ExecutionBackendItem.providerId(TestAIProvider().id)
        viewModel.selectExecutionBackend(id: providerBackendId)

        #expect(viewModel.activeAgentRuntimeId == nil)
        #expect(appSettings.defaultAgentRuntimeId == nil)
        #expect(viewModel.activeExecutionBackendId == providerBackendId)
        #expect(viewModel.activeExecutionBackendName == TestAIProvider().displayName)
    }

    @MainActor
    @Test func settingsPageViewModelPersistsModelsPerAgentRuntime() throws {
        let appSettings = InMemoryAppSettingsService()
        let registry = AgentRuntimeRegistry()
        let firstRuntime = ACPClientRuntime(
            client: FakeACPClient(id: "first.acp", displayName: "First Agent"),
            descriptor: AgentRuntimeDescriptor(
                id: "first.acp",
                displayName: "First Agent",
                transport: .acp,
                modelOptions: [
                    .init(id: "first-default", title: "First Default"),
                    .init(id: "first-alternate", title: "First Alternate")
                ],
                defaultModelId: "first-default"
            )
        )
        let secondRuntime = ACPClientRuntime(
            client: FakeACPClient(id: "second.acp", displayName: "Second Agent"),
            descriptor: AgentRuntimeDescriptor(
                id: "second.acp",
                displayName: "Second Agent",
                transport: .acp,
                modelOptions: [
                    .init(id: "second-default", title: "Second Default"),
                    .init(id: "second-alternate", title: "Second Alternate")
                ],
                defaultModelId: "second-default"
            )
        )
        registry.register(firstRuntime)
        registry.register(secondRuntime)
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider()]),
            appSettingsService: appSettings
        )
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: appSettings,
            agentRuntimeRegistry: registry
        )

        viewModel.selectAgentRuntime(id: firstRuntime.id)
        viewModel.selectedAgentModelId = "first-alternate"
        viewModel.saveSettings()
        viewModel.selectAgentRuntime(id: secondRuntime.id)
        viewModel.selectedAgentModelId = "second-alternate"
        viewModel.saveSettings()
        viewModel.selectAgentRuntime(id: firstRuntime.id)

        #expect(appSettings.agentModelId(for: firstRuntime.id) == "first-alternate")
        #expect(appSettings.agentModelId(for: secondRuntime.id) == "second-alternate")
        #expect(viewModel.selectedAgentModelId == "first-alternate")
    }

    @MainActor
    @Test func settingsPageViewModelFallsBackFromUnavailableSavedAgentModel() {
        let appSettings = InMemoryAppSettingsService(defaultAgentRuntimeId: "claude.cli")
        appSettings.setAgentModelId("removed-model", for: "claude.cli")
        let runtime = ACPClientRuntime(
            client: FakeACPClient(id: "claude.cli", displayName: "Claude"),
            descriptor: AgentRuntimeDescriptor(
                id: "claude.cli",
                displayName: "Claude",
                transport: .cli,
                modelOptions: [
                    .init(id: "sonnet", title: "Sonnet"),
                    .init(id: "opus", title: "Opus")
                ],
                defaultModelId: "sonnet"
            )
        )
        let registry = AgentRuntimeRegistry()
        registry.register(runtime)
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider()]),
            appSettingsService: appSettings
        )

        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: appSettings,
            agentRuntimeRegistry: registry
        )

        #expect(viewModel.selectedAgentModelId == "sonnet")
        #expect(viewModel.validatedAgentModelId(for: viewModel.agentRuntimes[0]) == "sonnet")
    }

    @MainActor
    @Test func settingsPageViewModelLoadsProvidersFromProviderService() async throws {
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()]),
            appSettingsService: InMemoryAppSettingsService()
        )
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: InMemoryAppSettingsService()
        )

        #expect(viewModel.providers.map(\.id).sorted() == ["alternate.provider", "test.provider"])
        #expect(viewModel.activeProviderId == "test.provider")
        #expect(viewModel.activeProviderName == "Test Provider")

        let provider = try #require(viewModel.providers.first { $0.id == "test.provider" })
        #expect(provider.isActive)
        #expect(provider.capabilities.contains { $0.title == "Streaming" && $0.value == "Yes" })
        #expect(provider.capabilities.contains { $0.title == "Context window" && $0.value == "1000 tokens" })
        #expect(provider.capabilities.contains { $0.title == "Models" && $0.value == "test-model" })
    }

    @MainActor
    @Test func settingsPageViewModelSelectsActiveProviderThroughProviderService() async throws {
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()]),
            appSettingsService: InMemoryAppSettingsService()
        )
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: InMemoryAppSettingsService()
        )

        viewModel.selectProvider(id: "alternate.provider")

        #expect(providerService.activeProviderId == "alternate.provider")
        #expect(viewModel.activeProviderId == "alternate.provider")
        #expect(viewModel.activeProviderName == "Alternate Provider")
        #expect(viewModel.providers.first { $0.id == "alternate.provider" }?.isActive == true)
        #expect(viewModel.providers.first { $0.id == "test.provider" }?.isActive == false)
    }

    @MainActor
    @Test func settingsPageViewModelSavesEditableAppSettings() async throws {
        let appSettings = InMemoryAppSettingsService()
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider()]),
            appSettingsService: appSettings
        )
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: appSettings
        )

        #expect(!viewModel.hasUnsavedAppSettingsChanges)
        #expect(viewModel.appSettingsStatus == "Saved")

        viewModel.selectedSafetyMode = .askBeforeShell
        viewModel.mcpServerBasePath = "/tmp/MCP_server"
        viewModel.localLLMEndpoint = "http://127.0.0.1:3008/mcp"
        viewModel.localLLMModel = "qwen-local"
        viewModel.defaultMaxInputTokens = 4_096
        viewModel.defaultMaxOutputTokens = 512
        viewModel.remoteControlEnabled = false
        viewModel.remoteControlAllowLAN = true
        viewModel.remoteControlPort = 9797
        viewModel.remoteControlToken = "test-token"
        viewModel.ragAnswerMode = .enabled
        viewModel.ragChunkingStrategy = .structure
        viewModel.ragRetrievalMode = .basic
        viewModel.ragRelevanceFilterMode = .heuristic
        viewModel.ragTopKBeforeFiltering = 18
        viewModel.ragTopKAfterFiltering = 7
        viewModel.ragSimilarityThreshold = 0.42

        #expect(viewModel.hasUnsavedAppSettingsChanges)
        #expect(viewModel.appSettingsStatus == "Unsaved changes")

        viewModel.saveSettings()

        #expect(appSettings.defaultSafetyMode == .askBeforeShell)
        #expect(appSettings.mcpServerBasePath == "/tmp/MCP_server")
        #expect(appSettings.localLLMEndpoint == "http://127.0.0.1:3008/mcp")
        #expect(appSettings.localLLMModel == "qwen-local")
        #expect(appSettings.defaultMaxInputTokens == 4_096)
        #expect(appSettings.defaultMaxOutputTokens == 512)
        #expect(!appSettings.remoteControlEnabled)
        #expect(appSettings.remoteControlAllowLAN)
        #expect(appSettings.remoteControlPort == 9797)
        #expect(appSettings.remoteControlToken == "test-token")
        #expect(appSettings.ragAnswerMode == .enabled)
        #expect(appSettings.ragRetrievalSettings.chunkingStrategy == .structure)
        #expect(appSettings.ragRetrievalSettings.retrievalMode == .basic)
        #expect(appSettings.ragRetrievalSettings.relevanceFilterMode == .heuristic)
        #expect(appSettings.ragRetrievalSettings.topKBeforeFiltering == 18)
        #expect(appSettings.ragRetrievalSettings.topKAfterFiltering == 7)
        #expect(appSettings.ragRetrievalSettings.similarityThreshold == 0.42)
        #expect(!viewModel.hasUnsavedAppSettingsChanges)
    }

    @MainActor
    @Test func settingsPageViewModelSavesAndRevertsAutoApprovalDraft() async throws {
        let appSettings = InMemoryAppSettingsService(
            defaultSafetyMode: .askBeforeWrite
        )
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: makeProviderService(TestAIProvider()),
            appSettingsService: appSettings
        )

        #expect(!viewModel.autoApproveWorkspaceActions)
        #expect(!viewModel.hasUnsavedAppSettingsChanges)

        viewModel.autoApproveWorkspaceActions = true

        #expect(viewModel.selectedSafetyMode == .autoInsideSandbox)
        #expect(viewModel.hasUnsavedAppSettingsChanges)
        #expect(appSettings.defaultSafetyMode == .askBeforeWrite)

        viewModel.saveSettings()

        #expect(viewModel.autoApproveWorkspaceActions)
        #expect(appSettings.defaultSafetyMode == .autoInsideSandbox)
        #expect(!viewModel.hasUnsavedAppSettingsChanges)

        viewModel.autoApproveWorkspaceActions = false
        viewModel.revertSettings()

        #expect(viewModel.autoApproveWorkspaceActions)
        #expect(viewModel.selectedSafetyMode == .autoInsideSandbox)
        #expect(!viewModel.hasUnsavedAppSettingsChanges)
    }

    @MainActor
    @Test func userDefaultsAppSettingsPersistsRAGSettings() throws {
        let defaults = try #require(UserDefaults(suiteName: "WorkHarnessTests.RAGSettings.\(UUID().uuidString)"))
        let first = UserDefaultsAppSettingsService(defaults: defaults)
        first.remoteControlEnabled = false
        first.remoteControlAllowLAN = true
        first.remoteControlPort = 9797
        first.remoteControlToken = "persisted-token"
        first.ragAnswerMode = .enabled
        first.ragRetrievalSettings = RAGRetrievalSettings(
            chunkingStrategy: .structure,
            retrievalMode: .basic,
            topKBeforeFiltering: 20,
            topKAfterFiltering: 6,
            similarityThreshold: 0.5,
            relevanceFilterMode: .heuristic
        )

        let second = UserDefaultsAppSettingsService(defaults: defaults)

        #expect(second.ragAnswerMode == .enabled)
        #expect(!second.remoteControlEnabled)
        #expect(second.remoteControlAllowLAN)
        #expect(second.remoteControlPort == 9797)
        #expect(second.remoteControlToken == "persisted-token")
        #expect(second.ragRetrievalSettings.chunkingStrategy == .structure)
        #expect(second.ragRetrievalSettings.retrievalMode == .basic)
        #expect(second.ragRetrievalSettings.topKBeforeFiltering == 20)
        #expect(second.ragRetrievalSettings.topKAfterFiltering == 6)
        #expect(second.ragRetrievalSettings.similarityThreshold == 0.5)
        #expect(second.ragRetrievalSettings.relevanceFilterMode == .heuristic)
    }

    @MainActor
    @Test func userDefaultsAppSettingsPersistsModelsPerAgentRuntime() throws {
        let defaults = try #require(UserDefaults(suiteName: "WorkHarnessTests.AgentModels.\(UUID().uuidString)"))
        let first = UserDefaultsAppSettingsService(defaults: defaults)
        first.setAgentModelId("cursor-model", for: "cursor.acp")
        first.setAgentModelId("claude-model", for: "claude.cli")

        let second = UserDefaultsAppSettingsService(defaults: defaults)

        #expect(second.agentModelId(for: "cursor.acp") == "cursor-model")
        #expect(second.agentModelId(for: "claude.cli") == "claude-model")
    }

    @MainActor
    @Test func settingsPageViewModelRestoresDefaultsAsDraftAndCanRevert() async throws {
        let appSettings = InMemoryAppSettingsService(
            defaultSafetyMode: .askBeforeShell,
            mcpServerBasePath: "/tmp/MCP_server",
            localLLMEndpoint: "http://127.0.0.1:3008/mcp",
            localLLMModel: "qwen-local",
            defaultMaxInputTokens: 4_096,
            defaultMaxOutputTokens: 512
        )
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider()]),
            appSettingsService: appSettings
        )
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: appSettings
        )

        viewModel.restoreDefaultSettingsDraft()

        #expect(viewModel.hasUnsavedAppSettingsChanges)
        #expect(viewModel.selectedSafetyMode == AppSettingsDefaults.defaultSafetyMode)
        #expect(viewModel.mcpServerBasePath == AppSettingsDefaults.mcpServerBasePath)
        #expect(appSettings.defaultSafetyMode == .askBeforeShell)
        #expect(appSettings.mcpServerBasePath == "/tmp/MCP_server")

        viewModel.revertSettings()

        #expect(!viewModel.hasUnsavedAppSettingsChanges)
        #expect(viewModel.selectedSafetyMode == .askBeforeShell)
        #expect(viewModel.mcpServerBasePath == "/tmp/MCP_server")
    }

    @MainActor
    @Test func providerServiceRestoresSavedDefaultProviderId() async throws {
        let settingsService = InMemoryAppSettingsService(defaultProviderId: "alternate.provider")
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [MockAIProvider(), AlternateAIProvider()]),
            appSettingsService: settingsService
        )

        #expect(providerService.activeProviderId == "alternate.provider")
        #expect(try providerService.activeProvider().displayName == "Alternate Provider")
        #expect(settingsService.defaultProviderId == "alternate.provider")
    }

    @MainActor
    @Test func providerServiceFallsBackToMockWhenSavedProviderIsMissing() async throws {
        let settingsService = InMemoryAppSettingsService(defaultProviderId: "missing.provider")
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [MockAIProvider(), AlternateAIProvider()]),
            appSettingsService: settingsService
        )

        #expect(providerService.activeProviderId == MockAIProvider.providerId)
        #expect(try providerService.activeProvider().displayName == "Mock Local Provider")
        #expect(settingsService.defaultProviderId == MockAIProvider.providerId)
    }

    @MainActor
    @Test func userDefaultsAppSettingsPersistsDefaultProviderIdAcrossInstances() async throws {
        let (suiteName, defaults) = try makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstService = UserDefaultsAppSettingsService(defaults: defaults)
        firstService.defaultProviderId = "alternate.provider"
        firstService.defaultSafetyMode = .askBeforeShell
        firstService.mcpServerBasePath = "/tmp/MCP_server"
        firstService.localLLMEndpoint = "http://127.0.0.1:3008/mcp"
        firstService.localLLMModel = "qwen-local"
        firstService.defaultMaxInputTokens = 4_096
        firstService.defaultMaxOutputTokens = 512

        let secondService = UserDefaultsAppSettingsService(defaults: defaults)

        #expect(secondService.defaultProviderId == "alternate.provider")
        #expect(secondService.defaultSafetyMode == .askBeforeShell)
        #expect(secondService.mcpServerBasePath == "/tmp/MCP_server")
        #expect(secondService.localLLMEndpoint == "http://127.0.0.1:3008/mcp")
        #expect(secondService.localLLMModel == "qwen-local")
        #expect(secondService.defaultMaxInputTokens == 4_096)
        #expect(secondService.defaultMaxOutputTokens == 512)
    }

    @MainActor
    @Test func providerServiceRestoresSavedProviderFromDurableSettings() async throws {
        let (suiteName, defaults) = try makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstSettingsService = UserDefaultsAppSettingsService(defaults: defaults)
        firstSettingsService.defaultProviderId = "alternate.provider"
        let restoredSettingsService = UserDefaultsAppSettingsService(defaults: defaults)
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [MockAIProvider(), AlternateAIProvider()]),
            appSettingsService: restoredSettingsService
        )

        #expect(providerService.activeProviderId == "alternate.provider")
        #expect(try providerService.activeProvider().displayName == "Alternate Provider")
        #expect(restoredSettingsService.defaultProviderId == "alternate.provider")
    }

    @MainActor
    @Test func providerServicePersistsMockFallbackWhenDurableSavedProviderIsMissing() async throws {
        let (suiteName, defaults) = try makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstSettingsService = UserDefaultsAppSettingsService(defaults: defaults)
        firstSettingsService.defaultProviderId = "missing.provider"
        let restoredSettingsService = UserDefaultsAppSettingsService(defaults: defaults)
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [MockAIProvider(), AlternateAIProvider()]),
            appSettingsService: restoredSettingsService
        )
        let verifiedSettingsService = UserDefaultsAppSettingsService(defaults: defaults)

        #expect(providerService.activeProviderId == MockAIProvider.providerId)
        #expect(try providerService.activeProvider().displayName == "Mock Local Provider")
        #expect(verifiedSettingsService.defaultProviderId == MockAIProvider.providerId)
    }
}

@MainActor
private func makeProviderService(_ provider: any AIProvider) -> ProviderService {
    ProviderService(
        registry: ProviderRegistry(providers: [provider]),
        appSettingsService: InMemoryAppSettingsService(defaultProviderId: provider.id)
    )
}

@MainActor
private func makeRunService() -> RunService {
    let repository = InMemoryRunRepository()
    return makeRunService(repository: repository)
}

@MainActor
private func makeRunService(
    repository: InMemoryRunRepository,
    artifactOpener: @escaping (URL) -> Bool = { _ in true }
) -> RunService {
    let recorder = RunRecorder(repository: repository)
    let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
    return RunService(
        repository: repository,
        harnessEngine: engine,
        artifactOpener: artifactOpener
    )
}

@MainActor
private func makeApprovalService() -> ApprovalService {
    makeApprovalService(repository: InMemoryRunRepository())
}

@MainActor
private func makeApprovalService(
    repository: InMemoryRunRepository,
    appSettingsService: AppSettingsServiceProtocol? = nil
) -> ApprovalService {
    ApprovalService(
        repository: InMemoryApprovalRepository(),
        runRepository: repository,
        recorder: RunRecorder(repository: repository),
        appSettingsService: appSettingsService ?? InMemoryAppSettingsService()
    )
}

@MainActor
private func makeToolService(
    repository: InMemoryRunRepository,
    mcpClient: MCPToolClientProtocol? = nil,
    approvalRepository: InMemoryApprovalRepository? = nil,
    appSettingsService: AppSettingsServiceProtocol? = nil,
    tools: [any ToolProtocol]
) -> ToolService {
    let approvalRepository = approvalRepository ?? InMemoryApprovalRepository()
    let mcpClient = mcpClient ?? FakeMCPToolClient()
    return ToolService(
        registry: ToolRegistry(tools: tools),
        mcpClient: mcpClient,
        approvalService: ApprovalService(
            repository: approvalRepository,
            runRepository: repository,
            recorder: RunRecorder(repository: repository),
            appSettingsService: appSettingsService ?? InMemoryAppSettingsService()
        ),
        recorder: RunRecorder(repository: repository)
    )
}

private func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "WorkHarnessTests-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeTemporaryDatabaseURL() throws -> URL {
    try makeTemporaryDirectory().appendingPathComponent("WorkHarness.sqlite")
}

@MainActor
private func makeMainScreenViewModel(
    projectService: ProjectServiceProtocol,
    approvalService: ApprovalServiceProtocol? = nil
) -> MainScreen.MainScreenViewModel {
    let runService = makeRunService()
    return MainScreen.MainScreenViewModel(
        chatPageViewModel: MainScreen.ChatPageViewModel(runService: runService),
        runsPageViewModel: MainScreen.RunsPageViewModel(runService: runService),
        statsPageViewModel: MainScreen.StatsPageViewModel(statisticsService: UsageStatisticsService(runService: runService)),
        settingsPageViewModel: MainScreen.SettingsPageViewModel(
            providerService: makeProviderService(TestAIProvider()),
            appSettingsService: InMemoryAppSettingsService()
        ),
        memoryPageViewModel: makeMemoryPageViewModel(projectService: projectService),
        approvalService: approvalService ?? makeApprovalService(),
        projectService: projectService
    )
}

@MainActor
private func makeMemoryPageViewModel(projectService: ProjectServiceProtocol) -> MainScreen.MemoryPageViewModel {
    let runRepository = InMemoryRunRepository()
    return MainScreen.MemoryPageViewModel(
        memoryService: MemoryService(
            repository: InMemoryMemoryRepository(),
            recorder: RunRecorder(repository: runRepository)
        ),
        projectService: projectService
    )
}

@MainActor
private func collectProcessEvents(
    runner: ProcessRunnerProtocol,
    script: String,
    timeout: TimeInterval? = 2
) async throws -> [ProcessRunEvent] {
    let session = try runner.start(ProcessRunRequest(
        executableURL: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", script],
        timeout: timeout
    ))
    var events: [ProcessRunEvent] = []

    for try await event in session.events {
        events.append(event)
    }

    return events
}

@MainActor
private func collectAIEvents(from provider: AIProvider, request: AIRequest) async throws -> [AIEvent] {
    let stream = try await provider.send(request)
    var events: [AIEvent] = []

    for try await event in stream {
        events.append(event)
    }

    return events
}

@MainActor
private func makeAIRequest(
    prompt: String,
    providerId: String = "mcp.codex.cli",
    model: String = "codex-cli",
    workingDirectory: String? = nil
) -> AIRequest {
    AIRequest(
        runId: UUID(),
        agent: Agent(role: .coder, providerId: providerId, model: model),
        messages: [.init(role: .user, content: prompt)],
        workingDirectory: workingDirectory
    )
}

private func makeIsolatedUserDefaults() throws -> (String, UserDefaults) {
    let suiteName = "WorkHarnessTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defaults.removePersistentDomain(forName: suiteName)
    return (suiteName, defaults)
}

private struct TestAIProvider: AIProvider {
    let id = "test.provider"
    let displayName = "Test Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 1_000,
        costModel: "test",
        supportedModels: ["test-model"]
    )

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageDelta("Hello"))
            continuation.yield(.messageCompleted("Hello from test provider."))
            continuation.yield(.tokenUsage(TokenUsage(inputTokens: 3, outputTokens: 5)))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}

@MainActor
private final class RecordingAIProvider: AIProvider {
    let id = "recording.provider"
    let displayName = "Recording Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 1_000,
        supportedModels: ["recording-model"]
    )
    private(set) var requests: [AIRequest] = []

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        requests.append(request)

        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageCompleted("Recorded."))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}

private final class FakeMCPProviderClient: MCPProviderClientProtocol {
    private let events: [MCPProviderEvent]
    private(set) var requests: [MCPProviderRequest] = []

    init(events: [MCPProviderEvent]) {
        self.events = events
    }

    func streamEvents(for request: MCPProviderRequest) async throws -> AsyncThrowingStream<MCPProviderEvent, Error> {
        requests.append(request)

        let events = events
        return AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

@MainActor
private final class FakeACPClient: ACPClient {
    let id: String
    let displayName: String
    private let sessionId = UUID()
    private let waitsForCancellation: Bool
    private var continuations: [AsyncThrowingStream<ACPEvent, Error>.Continuation] = []
    private(set) var configuredModelId: String?
    private(set) var tasks: [AgentTask] = []
    private(set) var cancelCount = 0

    init(
        id: String = "fake.acp",
        displayName: String = "Fake ACP Agent",
        waitsForCancellation: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.waitsForCancellation = waitsForCancellation
    }

    func configure(modelId: String?) {
        configuredModelId = modelId
    }

    func connect() async throws -> AgentSession {
        AgentSession(
            id: sessionId,
            agentId: id,
            state: .connected,
            capabilities: AgentCapabilities([.canEditFiles, .canStreamTokens, .canOpenDiff])
        )
    }

    func disconnect(sessionId: UUID) async {}

    func run(task: AgentTask, sessionId: UUID) async throws -> AsyncThrowingStream<ACPEvent, Error> {
        tasks.append(task)
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            guard !waitsForCancellation else {
                continuations.append(continuation)
                return
            }
            continuation.yield(.textDelta("Patch ready."))
            continuation.yield(.fileChanged(path: "Sources/App.swift"))
            continuation.yield(.messageCompleted("Done."))
            continuation.yield(.finished(AgentResponse(message: "Done.", tokenUsage: TokenUsage(inputTokens: 2, outputTokens: 3), artifacts: [])))
            continuation.finish()
        }
    }

    func cancel(sessionId: UUID) async {
        cancelCount += 1
        continuations.forEach { $0.finish() }
        continuations.removeAll()
    }
    func pause(sessionId: UUID) async throws {}
    func resume(sessionId: UUID) async throws {}
}

@MainActor
private final class FakeACPTransport: ACPTransport {
    let connection: FakeACPConnection

    init(connection: FakeACPConnection) {
        self.connection = connection
    }

    func connect() async throws -> ACPConnection {
        connection
    }
}

@MainActor
private final class FakeACPConnection: ACPConnection {
    private var continuations: [AsyncThrowingStream<ACPEvent, Error>.Continuation] = []
    private(set) var messages: [ACPMessage] = []

    func send(_ message: ACPMessage) async throws {
        messages.append(message)
        switch message.method {
        case "initialize":
            continuations.forEach { $0.yield(.connected(AgentCapabilities([.canPlan]))) }
        case "session/run":
            continuations.forEach {
                $0.yield(.messageCompleted("Subprocess done."))
                $0.finish()
            }
        default:
            break
        }
    }

    func request(method: String, params: [String: Any]) async throws -> [String: Any] {
        messages.append(ACPMessage(id: messages.count + 1, method: method, params: [:]))
        switch method {
        case "initialize":
            return ["agentCapabilities": ["promptCapabilities": [:]]]
        case "authenticate":
            return [:]
        case "session/new":
            return ["sessionId": "remote-session"]
        case "session/prompt":
            return ["stopReason": "completed"]
        default:
            return [:]
        }
    }

    func events() -> AsyncThrowingStream<ACPEvent, Error> {
        AsyncThrowingStream { continuation in
            continuations.append(continuation)
        }
    }

    func close() async {
        continuations.forEach { $0.finish() }
        continuations.removeAll()
    }
}

@MainActor
private final class FakeRAGService: @MainActor RAGServiceProtocol {
    let result: RAGSearchResult
    private(set) var lastSettings: RAGRetrievalSettings?

    init(result: RAGSearchResult) {
        self.result = result
    }

    func index(zipURL: URL, strategy: RAGChunkingStrategy, replaceExisting: Bool) async throws -> RAGIndexingSummary {
        RAGIndexingSummary(
            strategy: strategy,
            documentCount: 0,
            chunkCount: 0,
            averageTokens: 0,
            minTokens: 0,
            maxTokens: 0,
            embeddingModel: "fake",
            databasePath: zipURL.path,
            duration: 0
        )
    }

    func search(question: String, settings: RAGRetrievalSettings) async throws -> RAGSearchResult {
        lastSettings = settings
        return result
    }

    func clearIndex() async throws {}
}

@MainActor
private final class FakeMCPToolClient: MCPToolClientProtocol {
    private let result: ToolResult
    private(set) var invocations: [MCPToolInvocation] = []

    init(result: ToolResult? = nil) {
        self.result = result ?? ToolResult(toolId: "fake.tool", status: .succeeded, output: "ok")
    }

    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult {
        invocations.append(invocation)
        return result
    }
}

@MainActor
private final class RecordingMCPToolTransport: MCPToolTransportProtocol {
    struct Call {
        let endpoint: URL
        let name: String
        let arguments: [String: Any]
    }

    private(set) var calls: [Call] = []
    private let response: MCPToolTransportResponse

    init(response: MCPToolTransportResponse) {
        self.response = response
    }

    func callTool(
        endpoint: URL,
        name: String,
        arguments: [String: Any]
    ) async throws -> MCPToolTransportResponse {
        calls.append(Call(endpoint: endpoint, name: name, arguments: arguments))
        return response
    }
}

@MainActor
private final class FakeProcessRunner: ProcessRunnerProtocol {
    private let events: [ProcessRunEvent]
    private(set) var requests: [ProcessRunRequest] = []

    init(events: [ProcessRunEvent]) {
        self.events = events
    }

    func start(_ request: ProcessRunRequest) throws -> ProcessRunSession {
        requests.append(request)

        let events = events
        return ProcessRunSession(events: AsyncThrowingStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }, cancelHandler: {})
    }
}

@MainActor
private final class FakeCLIAgentProcessTransport: CLIAgentProcessTransport {
    private var eventBatches: [[CLIAgentProcessEvent]]
    private let finishesStreams: Bool
    private(set) var configurations: [CLIAgentProcessConfiguration] = []
    private(set) var cancellationCount = 0

    init(eventBatches: [[CLIAgentProcessEvent]], finishesStreams: Bool = true) {
        self.eventBatches = eventBatches
        self.finishesStreams = finishesStreams
    }

    func start(_ configuration: CLIAgentProcessConfiguration) throws -> CLIAgentProcessSession {
        configurations.append(configuration)
        let events = eventBatches.isEmpty ? [] : eventBatches.removeFirst()
        let finishesStreams = finishesStreams
        let control = FakeCLIProcessControl()

        return CLIAgentProcessSession(
            events: AsyncThrowingStream { continuation in
                control.continuation = continuation
                for event in events {
                    continuation.yield(event)
                }
                if finishesStreams {
                    continuation.finish()
                }
            },
            writeHandler: { _ in },
            closeInputHandler: {},
            cancelHandler: { [weak self] in
                self?.cancellationCount += 1
                control.cancel()
            }
        )
    }
}

@MainActor
private final class FakeCLIProcessControl {
    var continuation: AsyncThrowingStream<CLIAgentProcessEvent, Error>.Continuation?

    func cancel() {
        continuation?.yield(.finished(ProcessExit(status: .cancelled, exitCode: nil)))
        continuation?.finish()
    }
}

@MainActor
private func collectAgentEvents(
    _ stream: AsyncThrowingStream<AgentEvent, Error>
) async throws -> [AgentEvent] {
    var events: [AgentEvent] = []
    for try await event in stream {
        events.append(event)
    }
    return events
}

private struct AlternateAIProvider: AIProvider {
    let id = "alternate.provider"
    let displayName = "Alternate Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 2_000,
        supportedModels: ["alternate-model"]
    )

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageCompleted("Hello from alternate provider."))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}

private struct FailingAIProvider: AIProvider {
    let id = "failing.provider"
    let displayName = "Failing Provider"
    let capabilities = ProviderCapabilities(supportsStreaming: true, supportedModels: ["failing-model"])

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.error("Provider failed."))
            continuation.finish()
        }
    }
}
