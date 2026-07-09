//
//  WorkHarnessTests.swift
//  WorkHarnessTests
//
//  Created by Максим Ламанский on 7.07.26.
//

import Testing
import Swinject
import Foundation
@testable import WorkHarness

struct WorkHarnessTests {

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
    @Test func mainScreenRoutesSectionsThroughPages() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
        let runService = RunService(repository: repository, harnessEngine: engine)
        let chatPageViewModel = MainScreen.ChatPageViewModel(runService: runService)
        let runsPageViewModel = MainScreen.RunsPageViewModel(runService: runService)
        let settingsPageViewModel = MainScreen.SettingsPageViewModel(providerService: makeProviderService(TestAIProvider()))
        let approvalService = makeApprovalService(repository: repository)
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        let screenModel = MainScreen.MainScreenViewModel(
            chatPageViewModel: chatPageViewModel,
            runsPageViewModel: runsPageViewModel,
            settingsPageViewModel: settingsPageViewModel,
            approvalService: approvalService,
            projectService: projectService
        )

        #expect(screenModel.pages.first is MainScreen.MainShellPage)
        #expect(screenModel.detailPage is MainScreen.ChatPage)

        screenModel.show(section: .runs)

        #expect(screenModel.detailPage is MainScreen.RunsPage)

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
        let contextBuilder = try #require(container.resolve(ContextBuilderProtocol.self))
        let toolRegistry = try #require(container.resolve(ToolRegistry.self))
        let mcpToolClient = try #require(container.resolve(MCPToolClientProtocol.self))
        let toolService = try #require(container.resolve(ToolServiceProtocol.self))
        let settingsViewModel = try #require(container.resolve(MainScreen.SettingsPageViewModel.self))
        let scene = try #require(container.resolve(AppSceneProtocol.self))
        let mainScreen = try #require(container.resolve(MainScreenProtocol.self))

        #expect(firstRepository.runs.isEmpty)
        #expect(firstRepository === secondRepository)
        #expect(projectRepository is UserDefaultsProjectRepository)
        #expect(projectRepository.projects.isEmpty)
        #expect(projectService.currentProject == nil)
        #expect(providerService.activeProviderId == MockAIProvider.providerId)
        #expect(runService.runs.isEmpty)
        #expect(approvalService.pendingRequests.isEmpty)
        #expect(processRunner is ProcessRunner)
        #expect(contextBuilder is ContextBuilder)
        #expect(toolRegistry.availableTools.contains { $0.id == "file.read" })
        #expect(mcpToolClient is MCPToolClient)
        #expect(toolService.availableTools.contains { $0.id == "mcp.invoke" })
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
            MCPToolAdapter()
        ])

        let ids = registry.availableTools.map(\.id).sorted()

        #expect(ids == ["file.read", "file.write", "git.run", "mcp.invoke", "shell.run"])
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
            settingsPageViewModel: MainScreen.SettingsPageViewModel(providerService: makeProviderService(TestAIProvider())),
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
        let settingsViewModel = MainScreen.SettingsPageViewModel(providerService: providerService)

        #expect(settingsViewModel.providers.contains { $0.id == MCPProviderDescriptor.codexCLI.id && $0.name == "Codex CLI" })
        #expect(settingsViewModel.providers.contains { $0.id == MCPProviderDescriptor.cursorCLI.id && $0.name == "Cursor CLI" })
        #expect(settingsViewModel.providers.contains { $0.id == MCPProviderDescriptor.localLLM.id && $0.name == "Local LLM" })

        settingsViewModel.selectProvider(id: MCPProviderDescriptor.localLLM.id)

        #expect(providerService.activeProviderId == MCPProviderDescriptor.localLLM.id)
        #expect(settingsViewModel.activeProviderName == "Local LLM")
    }

    @MainActor
    @Test func settingsPageViewModelLoadsProvidersFromProviderService() async throws {
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [TestAIProvider(), AlternateAIProvider()]),
            appSettingsService: InMemoryAppSettingsService()
        )
        let viewModel = MainScreen.SettingsPageViewModel(providerService: providerService)

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
        let viewModel = MainScreen.SettingsPageViewModel(providerService: providerService)

        viewModel.selectProvider(id: "alternate.provider")

        #expect(providerService.activeProviderId == "alternate.provider")
        #expect(viewModel.activeProviderId == "alternate.provider")
        #expect(viewModel.activeProviderName == "Alternate Provider")
        #expect(viewModel.providers.first { $0.id == "alternate.provider" }?.isActive == true)
        #expect(viewModel.providers.first { $0.id == "test.provider" }?.isActive == false)
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

        let secondService = UserDefaultsAppSettingsService(defaults: defaults)

        #expect(secondService.defaultProviderId == "alternate.provider")
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
private func makeRunService(repository: InMemoryRunRepository) -> RunService {
    let recorder = RunRecorder(repository: repository)
    let engine = HarnessEngine(repository: repository, recorder: recorder, providerService: makeProviderService(TestAIProvider()))
    return RunService(repository: repository, harnessEngine: engine)
}

@MainActor
private func makeApprovalService() -> ApprovalService {
    makeApprovalService(repository: InMemoryRunRepository())
}

@MainActor
private func makeApprovalService(repository: InMemoryRunRepository) -> ApprovalService {
    ApprovalService(
        repository: InMemoryApprovalRepository(),
        runRepository: repository,
        recorder: RunRecorder(repository: repository)
    )
}

@MainActor
private func makeToolService(
    repository: InMemoryRunRepository,
    mcpClient: MCPToolClientProtocol? = nil,
    approvalRepository: InMemoryApprovalRepository? = nil,
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
            recorder: RunRecorder(repository: repository)
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

@MainActor
private func makeMainScreenViewModel(
    projectService: ProjectServiceProtocol,
    approvalService: ApprovalServiceProtocol? = nil
) -> MainScreen.MainScreenViewModel {
    let runService = makeRunService()
    return MainScreen.MainScreenViewModel(
        chatPageViewModel: MainScreen.ChatPageViewModel(runService: runService),
        runsPageViewModel: MainScreen.RunsPageViewModel(runService: runService),
        settingsPageViewModel: MainScreen.SettingsPageViewModel(providerService: makeProviderService(TestAIProvider())),
        approvalService: approvalService ?? makeApprovalService(),
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
    providerId: String = MCPProviderDescriptor.codexCLI.id,
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
private final class FakeMCPToolClient: MCPToolClientProtocol {
    private let result: ToolResult
    private(set) var invocations: [MCPToolInvocation] = []

    init(result: ToolResult = ToolResult(toolId: "fake.tool", status: .succeeded, output: "ok")) {
        self.result = result
    }

    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult {
        invocations.append(invocation)
        return result
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
