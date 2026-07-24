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
            "Smoke Runner",
            "Test Reporter"
        ])
        #expect(configuration.roles[0].instructions.contains("at least three production modules"))
        #expect(configuration.roles[3].instructions.contains("screenshot artifact after every step"))
        #expect(configuration.roles[4].instructions.contains("Final Verdict"))
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
        #expect(service.configuration(for: "testing").roles.count == 5)
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
