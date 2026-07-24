//
// TestingConfigurationTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

struct TestingConfigurationTests {
    @MainActor
    @Test func serviceSeedsCatalogAndMappedMarkdownScenarios() throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Mobile", rootPath: projectRoot.path)

        let service = TestingConfigurationService(projectService: projectService)
        let directory = projectRoot.appendingPathComponent(
            TestingConfigurationDefaults.directoryName
        )
        let firstScenario = try #require(service.catalog.scenarios.first)

        #expect(service.catalog.scenarios.count == 5)
        #expect(service.catalog.target.scheme == "WorkHarnessMobile")
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(
                TestingConfigurationDefaults.manifestFileName
            ).path
        ))
        let gitIgnoreURL = directory.appendingPathComponent(
            TestingConfigurationDefaults.gitIgnoreFileName
        )
        #expect(FileManager.default.fileExists(atPath: gitIgnoreURL.path))
        #expect(
            try String(contentsOf: gitIgnoreURL, encoding: .utf8)
                == TestingConfigurationDefaults.gitIgnoreContents
        )
        #expect(service.scenarioPrompt(for: firstScenario.id).contains("Capture a screenshot"))
        #expect(try service.scenarioFileURL(for: firstScenario.id).lastPathComponent == "pairing-success.md")
    }

    @MainActor
    @Test func servicePersistsTargetEnabledStateAndScenarioOrder() throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Mobile", rootPath: projectRoot.path)
        let service = TestingConfigurationService(projectService: projectService)
        let firstScenario = try #require(service.catalog.scenarios.first)
        let secondScenario = try #require(service.catalog.scenarios.dropFirst().first)
        var target = service.catalog.target
        target.deviceName = "iPhone Test Fixture"

        try service.saveTarget(target)
        try service.setScenarioEnabled(id: firstScenario.id, enabled: false)
        try service.moveScenario(id: secondScenario.id, direction: .up)

        let reloaded = TestingConfigurationService(projectService: projectService)
        #expect(reloaded.catalog.target.deviceName == "iPhone Test Fixture")
        #expect(reloaded.catalog.scenarios.first?.id == secondScenario.id)
        #expect(reloaded.catalog.scenarios.first { $0.id == firstScenario.id }?.enabled == false)
    }

    @MainActor
    @Test func serviceImportsMarkdownIntoMappedScenarioFile() throws {
        let projectRoot = try makeTestingDirectory()
        let sourceRoot = try makeTestingDirectory()
        defer {
            try? FileManager.default.removeItem(at: projectRoot)
            try? FileManager.default.removeItem(at: sourceRoot)
        }
        let sourceURL = sourceRoot.appendingPathComponent("replacement.md")
        try "# Replacement\nSMOKE_REPLACEMENT_MARKER".write(
            to: sourceURL,
            atomically: true,
            encoding: .utf8
        )
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Mobile", rootPath: projectRoot.path)
        let service = TestingConfigurationService(projectService: projectService)
        let scenario = try #require(service.catalog.scenarios.first)

        try service.replaceScenario(for: scenario.id, withContentsOf: sourceURL)

        #expect(service.scenarioPrompt(for: scenario.id).contains("SMOKE_REPLACEMENT_MARKER"))
        #expect(
            try String(contentsOf: service.scenarioFileURL(for: scenario.id), encoding: .utf8)
                .contains("SMOKE_REPLACEMENT_MARKER")
        )
    }

    @MainActor
    @Test func settingsViewModelLoadsSavesAndRevertsTestingTarget() throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Mobile", rootPath: projectRoot.path)
        let testingService = TestingConfigurationService(projectService: projectService)
        let appSettings = InMemoryAppSettingsService()
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [MockAIProvider()]),
            appSettingsService: appSettings
        )
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: providerService,
            appSettingsService: appSettings,
            testingConfigurationService: testingService
        )

        #expect(viewModel.smokeScenarios.count == 5)
        #expect(viewModel.hasUnsavedTestingTargetChanges == false)

        viewModel.testingDeviceName = "Edited Simulator"
        #expect(viewModel.hasUnsavedTestingTargetChanges)

        viewModel.revertTestingTarget()
        #expect(viewModel.testingDeviceName == TestingConfigurationDefaults.catalog.target.deviceName)
        #expect(viewModel.hasUnsavedTestingTargetChanges == false)

        viewModel.testingDeviceName = "Saved Simulator"
        viewModel.saveTestingTarget()

        let reloaded = TestingConfigurationService(projectService: projectService)
        #expect(reloaded.catalog.target.deviceName == "Saved Simulator")
        #expect(viewModel.hasUnsavedTestingTargetChanges == false)
    }

    @MainActor
    @Test func testingAgentProfileLoadsOrderedSpecialistPrompts() throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Mobile", rootPath: projectRoot.path)
        let service = AgentProfileService(projectService: projectService)

        let configuration = service.configuration(for: "testing")

        #expect(configuration.profileName == "Testing")
        #expect(configuration.roles.map(\.assistantName) == [
            "Coverage Analyst",
            "Test Author",
            "Code Test Runner",
            "Smoke Scenario Maintainer",
            "Smoke Runner",
            "Test Reporter"
        ])
        #expect(configuration.roles[0].instructions.contains("at least three production modules"))
        #expect(configuration.roles[3].instructions.contains("If no smoke update was explicitly requested"))
        #expect(configuration.roles[4].instructions.contains("screenshot artifact after every step"))
        #expect(configuration.roles[4].instructions.contains(#"{"target":"ios"}"#))
        #expect(configuration.roles[4].instructions.contains(#"{"package":"<bundle identifier>"}"#))
        #expect(configuration.roles[4].instructions.contains(#""artifactName":"<scenario>-step-<NN>-<slug>""#))
        #expect(configuration.roles[4].instructions.contains("WebDriverAgent cold start"))
        #expect(configuration.roles[5].instructions.contains("Final Verdict"))
    }

    @MainActor
    @Test func agentProfileServiceAddsTestingProfileToExistingProjectCatalog() throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let profileDirectory = projectRoot.appendingPathComponent(
            AgentProfileDefaults.directoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: profileDirectory,
            withIntermediateDirectories: true
        )
        let legacyCatalog = AgentProfileCatalog(
            selectedProfileId: "research",
            profiles: Array(AgentProfileDefaults.catalog.profiles.prefix(3))
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(legacyCatalog).write(
            to: profileDirectory.appendingPathComponent(
                AgentProfileDefaults.manifestFileName
            ),
            options: .atomic
        )
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Existing", rootPath: projectRoot.path)

        let service = AgentProfileService(projectService: projectService)

        #expect(service.selectedProfileId == "research")
        #expect(service.profiles.map(\.id) == ["bug-fix", "research", "implementation", "testing"])
        #expect(service.configuration(for: "testing").roles.count == 6)
    }

    @MainActor
    @Test func agentProfileServiceMigratesMissingBuiltInAssistantInDefaultOrder() throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let profileDirectory = projectRoot.appendingPathComponent(
            AgentProfileDefaults.directoryName,
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: profileDirectory,
            withIntermediateDirectories: true
        )
        var legacyCatalog = AgentProfileDefaults.catalog
        let testingIndex = try #require(
            legacyCatalog.profiles.firstIndex { $0.id == "testing" }
        )
        legacyCatalog.profiles[testingIndex].assistants.removeAll {
            $0.name == "Smoke Scenario Maintainer"
        }
        let smokeIndex = try #require(
            legacyCatalog.profiles[testingIndex].assistants.firstIndex {
                $0.name == "Smoke Runner"
            }
        )
        legacyCatalog.profiles[testingIndex].assistants[smokeIndex].enabled = false
        legacyCatalog.profiles[testingIndex].assistants[smokeIndex].modelOverride = "fixture-model"

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(legacyCatalog).write(
            to: profileDirectory.appendingPathComponent(
                AgentProfileDefaults.manifestFileName
            ),
            options: .atomic
        )
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Existing", rootPath: projectRoot.path)

        let service = AgentProfileService(projectService: projectService)
        let testingProfile = try #require(
            service.profiles.first { $0.id == "testing" }
        )

        #expect(testingProfile.assistants.map(\.name) == [
            "Coverage Analyst",
            "Test Author",
            "Code Test Runner",
            "Smoke Scenario Maintainer",
            "Smoke Runner",
            "Test Reporter"
        ])
        let migratedSmokeRunner = try #require(
            testingProfile.assistants.first { $0.name == "Smoke Runner" }
        )
        #expect(!migratedSmokeRunner.enabled)
        #expect(migratedSmokeRunner.modelOverride == "fixture-model")
        #expect(
            service.prompt(
                for: try #require(
                    testingProfile.assistants.first {
                        $0.name == "Smoke Scenario Maintainer"
                    }
                ).id
            ).contains("Review smoke coverage")
        )
    }

    @MainActor
    @Test func environmentServiceDecodesMobileHealthReport() async throws {
        let diagnostics = makeDiagnostics()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let output = String(decoding: try encoder.encode(diagnostics), as: UTF8.self)
        let service = TestingEnvironmentService(
            mcpClient: TestingFakeMCPClient(result: ToolResult(
                toolId: "mobile.health",
                status: .succeeded,
                output: output
            ))
        )

        let result = try await service.checkEnvironment()

        #expect(result == diagnostics)
        #expect(result.canStartSmokeTests)
    }

    @MainActor
    @Test func settingsViewModelChecksEnvironmentOnlyOnExplicitAction() async throws {
        let diagnostics = makeDiagnostics()
        let appSettings = InMemoryAppSettingsService()
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: ProviderService(
                registry: ProviderRegistry(providers: [MockAIProvider()]),
                appSettingsService: appSettings
            ),
            appSettingsService: appSettings,
            testingEnvironmentService: TestingFakeEnvironmentService(
                diagnostics: diagnostics
            )
        )

        #expect(viewModel.testingEnvironmentDiagnostics == nil)

        viewModel.checkTestingEnvironment()
        while viewModel.isCheckingTestingEnvironment {
            await Task.yield()
        }

        #expect(viewModel.testingEnvironmentDiagnostics == diagnostics)
        #expect(
            viewModel.testingEnvironmentStatus
                == MainScreen.SettingsPageDesign.Testing.diagnosticsReady
        )
    }

    @MainActor
    @Test func smokeTestServiceStartsOnlyEnabledSmokeRolesAsMultiAgentRun() async throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Mobile", rootPath: projectRoot.path)
        let testingService = TestingConfigurationService(projectService: projectService)
        let firstScenario = try #require(testingService.catalog.scenarios.first)
        try testingService.setScenarioEnabled(id: firstScenario.id, enabled: false)
        let launcher = TestingFakeRunLauncher(runId: UUID(
            uuidString: "60000000-0000-0000-0000-000000000001"
        )!)
        let runRepository = InMemoryRunRepository()
        runRepository.insert(Run(
            id: launcher.runId,
            goal: "Smoke fixture",
            status: .completed,
            events: [
                RunEvent(
                    runId: launcher.runId,
                    type: .assistantMessage,
                    message: "## Final Verdict\nPASSED",
                    metadata: ["assistantName": "Test Reporter"]
                )
            ],
            artifacts: [
                RunArtifact(
                    name: "Pairing screenshot",
                    kind: "screenshot",
                    path: "/tmp/pairing.png"
                )
            ]
        ))
        let service = SmokeTestService(
            testingConfigurationService: testingService,
            testingEnvironmentService: TestingFakeEnvironmentService(
                diagnostics: makeDiagnostics()
            ),
            agentProfileService: AgentProfileService(projectService: projectService),
            runLauncher: launcher,
            runRepository: runRepository,
            recorder: RunRecorder(repository: runRepository),
            projectService: projectService
        )

        let runId = try await service.startEnabledScenarios()
        let request = try #require(launcher.request)

        #expect(runId == launcher.runId)
        #expect(request.mode == .multiAgent)
        #expect(request.configuration.roles.map(\.assistantName) == [
            "Smoke Runner",
            "Test Reporter"
        ])
        #expect(!request.goal.contains(firstScenario.name))
        #expect(request.goal.contains("Authentication error"))
        #expect(request.goal.contains("Do not run unit, integration, build, lint"))
        #expect(request.goal.contains("/smoke"))
        #expect(request.configuration.roles[0].instructions.contains("/smoke"))
        let reportArtifact = try #require(
            runRepository.run(withId: runId)?.artifacts.first { $0.kind == "smoke-report" }
        )
        let reportPath = try #require(reportArtifact.path)
        let report = try String(contentsOfFile: reportPath, encoding: .utf8)
        #expect(report.contains("**Final Verdict:** PASSED"))
        #expect(report.contains("`/tmp/pairing.png`"))
        #expect(
            runRepository.run(withId: runId)?.events.suffix(2).map(\.type)
                == [.artifactCreated, .finalSummary]
        )

        _ = try await service.startScenarios(.matching(firstScenario.name))
        #expect(launcher.request?.goal.contains(firstScenario.name) == true)
        #expect(launcher.request?.goal.contains("Authentication error") == false)

        _ = try await service.startScenarios(.all)
        #expect(launcher.request?.goal.contains(firstScenario.name) == true)
        #expect(launcher.request?.goal.contains("Authentication error") == true)
    }

    @MainActor
    @Test func settingsStartsSmokeRunOnlyAfterExplicitAction() async throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Mobile", rootPath: projectRoot.path)
        let testingService = TestingConfigurationService(projectService: projectService)
        let smokeService = TestingFakeSmokeTestService()
        let appSettings = InMemoryAppSettingsService()
        let viewModel = MainScreen.SettingsPageViewModel(
            providerService: ProviderService(
                registry: ProviderRegistry(providers: [MockAIProvider()]),
                appSettingsService: appSettings
            ),
            appSettingsService: appSettings,
            testingConfigurationService: testingService,
            testingEnvironmentService: TestingFakeEnvironmentService(
                diagnostics: makeDiagnostics()
            ),
            smokeTestService: smokeService
        )

        #expect(smokeService.startCount == 0)
        #expect(!viewModel.canRunSmokeTests)
        viewModel.checkTestingEnvironment()
        while viewModel.isCheckingTestingEnvironment {
            await Task.yield()
        }
        #expect(viewModel.canRunSmokeTests)

        viewModel.runSmokeTests()
        while viewModel.isRunningSmokeTests {
            await Task.yield()
        }

        #expect(smokeService.startCount == 1)
        #expect(viewModel.lastSmokeRunId == smokeService.runId)
    }

    @MainActor
    @Test func chatSmokeCommandUsesSharedServiceWithoutSendingOrdinaryMessage() async throws {
        let repository = InMemoryRunRepository()
        let appSettings = InMemoryAppSettingsService()
        let runService = RunService(
            repository: repository,
            harnessEngine: HarnessEngine(
                repository: repository,
                recorder: RunRecorder(repository: repository),
                providerService: ProviderService(
                    registry: ProviderRegistry(providers: [MockAIProvider()]),
                    appSettingsService: appSettings
                )
            )
        )
        let smokeService = TestingFakeSmokeTestService()
        let viewModel = MainScreen.ChatPageViewModel(
            runService: runService,
            contextAttachmentService: RunContextAttachmentService(),
            smokeTestService: smokeService
        )

        viewModel.draftMessage = "/smoke Pairing succeeds"
        await viewModel.submitDraftAndWait()

        #expect(smokeService.selections == [.matching("Pairing succeeds")])
        #expect(viewModel.selectedRunId == smokeService.runId)
        #expect(repository.runs.isEmpty)
        #expect(SmokeTestCommand.selection(from: "/smoke") == .enabled)
        #expect(SmokeTestCommand.selection(from: "/smoke --all") == .all)
        #expect(SmokeTestCommand.selection(from: "/smoke-test") == nil)
    }

    @MainActor
    @Test func testingWorkflowServiceRunsCompleteProfileAndCreatesUnifiedReport() async throws {
        let projectRoot = try makeTestingDirectory()
        defer { try? FileManager.default.removeItem(at: projectRoot) }
        let projectService = ProjectService(repository: InMemoryProjectRepository())
        projectService.addProject(name: "Mobile", rootPath: projectRoot.path)
        let testingService = TestingConfigurationService(projectService: projectService)
        let launcher = TestingFakeRunLauncher(runId: UUID(
            uuidString: "60000000-0000-0000-0000-000000000003"
        )!)
        let runRepository = InMemoryRunRepository()
        runRepository.insert(Run(
            id: launcher.runId,
            goal: "Full testing fixture",
            status: .completed,
            events: [
                RunEvent(
                    runId: launcher.runId,
                    type: .assistantMessage,
                    message: "## Final Verdict\nPASSED",
                    metadata: ["assistantName": "Test Reporter"]
                )
            ],
            artifacts: [
                RunArtifact(
                    name: "Fixture screenshot",
                    kind: "screenshot",
                    path: "/tmp/testing-fixture.png"
                )
            ]
        ))
        let service = TestingWorkflowService(
            testingConfigurationService: testingService,
            testingEnvironmentService: TestingFakeEnvironmentService(
                diagnostics: makeDiagnostics()
            ),
            agentProfileService: AgentProfileService(projectService: projectService),
            runLauncher: launcher,
            runRepository: runRepository,
            recorder: RunRecorder(repository: runRepository),
            projectService: projectService
        )

        let runId = try await service.startFullRun(
            request: "I deployed a new feature. Validate it."
        )
        let request = try #require(launcher.request)

        #expect(runId == launcher.runId)
        #expect(request.mode == .multiAgent)
        #expect(request.configuration.profileName == "Testing · Full")
        #expect(request.configuration.roles.map(\.assistantName) == [
            "Coverage Analyst",
            "Test Author",
            "Code Test Runner",
            "Smoke Scenario Maintainer",
            "Smoke Runner",
            "Test Reporter"
        ])
        #expect(request.goal.contains("I deployed a new feature. Validate it."))
        #expect(request.goal.contains("at least three production modules"))
        #expect(request.goal.contains(testingService.catalog.target.buildCommand))
        #expect(request.goal.contains("Pairing succeeds"))
        #expect(request.configuration.roles.allSatisfy {
            $0.instructions.contains("explicitly started by the user with `/test`")
        })

        let reportArtifact = try #require(
            runRepository.run(withId: runId)?.artifacts.first {
                $0.kind == "testing-report"
            }
        )
        let reportPath = try #require(reportArtifact.path)
        let report = try String(contentsOfFile: reportPath, encoding: .utf8)
        #expect(report.contains("# Testing Report"))
        #expect(report.contains("**Final Verdict:** PASSED"))
        #expect(report.contains("`/tmp/testing-fixture.png`"))
        #expect(report.contains(testingService.catalog.target.codeTestCommand))
        #expect(
            runRepository.run(withId: runId)?.events.suffix(2).map(\.type)
                == [.artifactCreated, .finalSummary]
        )
    }

    @MainActor
    @Test func chatTestCommandStartsFullWorkflowWithoutSendingOrdinaryMessage() async {
        let repository = InMemoryRunRepository()
        let appSettings = InMemoryAppSettingsService()
        let runService = RunService(
            repository: repository,
            harnessEngine: HarnessEngine(
                repository: repository,
                recorder: RunRecorder(repository: repository),
                providerService: ProviderService(
                    registry: ProviderRegistry(providers: [MockAIProvider()]),
                    appSettingsService: appSettings
                )
            )
        )
        let workflowService = TestingFakeWorkflowService()
        let viewModel = MainScreen.ChatPageViewModel(
            runService: runService,
            contextAttachmentService: RunContextAttachmentService(),
            testingWorkflowService: workflowService
        )

        viewModel.draftMessage = "/test I deployed a new feature"
        await viewModel.submitDraftAndWait()

        #expect(workflowService.requests == ["I deployed a new feature"])
        #expect(viewModel.selectedRunId == workflowService.runId)
        #expect(repository.runs.isEmpty)
        #expect(TestingWorkflowCommand.parse("/test") == TestingWorkflowCommand(request: nil))
        #expect(TestingWorkflowCommand.parse("/test --all") == TestingWorkflowCommand(request: nil))
        #expect(TestingWorkflowCommand.parse("/testing") == nil)
    }
}

private func makeTestingDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(
        "WorkHarnessTestingConfigurationTests-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func makeDiagnostics() -> TestingEnvironmentDiagnostics {
    TestingEnvironmentDiagnostics(
        checkedAt: Date(timeIntervalSince1970: 1_721_811_600),
        checks: [
            TestingDiagnosticCheck(
                id: "claudeInMobile",
                title: "Claude in Mobile",
                status: .ready,
                message: "Installed",
                remediation: nil
            ),
            TestingDiagnosticCheck(
                id: "xcode",
                title: "Xcode",
                status: .ready,
                message: "Xcode 26",
                remediation: nil
            ),
            TestingDiagnosticCheck(
                id: "simulator",
                title: "iOS Simulator",
                status: .ready,
                message: "Booted",
                remediation: nil
            )
        ]
    )
}

@MainActor
private final class TestingFakeMCPClient: MCPToolClientProtocol {
    private let result: ToolResult

    init(result: ToolResult) {
        self.result = result
    }

    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult {
        result
    }
}

@MainActor
private final class TestingFakeEnvironmentService: TestingEnvironmentServiceProtocol {
    let diagnostics: TestingEnvironmentDiagnostics

    init(diagnostics: TestingEnvironmentDiagnostics) {
        self.diagnostics = diagnostics
    }

    func checkEnvironment() async throws -> TestingEnvironmentDiagnostics {
        diagnostics
    }
}

@MainActor
private final class TestingFakeRunLauncher: RunLaunchingProtocol {
    struct Request {
        let goal: String
        let mode: RunMode
        let configuration: MultiAgentRunConfiguration
    }

    let runId: UUID
    private(set) var request: Request?

    init(runId: UUID) {
        self.runId = runId
    }

    func startRun(
        goal: String,
        mode: RunMode,
        configuration: MultiAgentRunConfiguration
    ) async -> UUID? {
        request = Request(goal: goal, mode: mode, configuration: configuration)
        return runId
    }
}

@MainActor
private final class TestingFakeSmokeTestService: SmokeTestServiceProtocol {
    let runId = UUID(uuidString: "60000000-0000-0000-0000-000000000002")!
    private(set) var selections: [SmokeTestSelection] = []

    var startCount: Int {
        selections.count
    }

    func startScenarios(_ selection: SmokeTestSelection) async throws -> UUID {
        selections.append(selection)
        return runId
    }
}

@MainActor
private final class TestingFakeWorkflowService: TestingWorkflowServiceProtocol {
    let runId = UUID(uuidString: "60000000-0000-0000-0000-000000000004")!
    private(set) var requests: [String?] = []

    func startFullRun(request: String?) async throws -> UUID {
        requests.append(request)
        return runId
    }
}
