//
// SmokeTestService.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
final class SmokeTestService: SmokeTestServiceProtocol {
    private let testingConfigurationService: TestingConfigurationServiceProtocol
    private let testingEnvironmentService: TestingEnvironmentServiceProtocol
    private let agentProfileService: AgentProfileServiceProtocol
    private let runLauncher: any RunLaunchingProtocol

    init(
        testingConfigurationService: TestingConfigurationServiceProtocol,
        testingEnvironmentService: TestingEnvironmentServiceProtocol,
        agentProfileService: AgentProfileServiceProtocol,
        runLauncher: any RunLaunchingProtocol
    ) {
        self.testingConfigurationService = testingConfigurationService
        self.testingEnvironmentService = testingEnvironmentService
        self.agentProfileService = agentProfileService
        self.runLauncher = runLauncher
    }

    func startScenarios(_ selection: SmokeTestSelection) async throws -> UUID {
        let diagnostics = try await testingEnvironmentService.checkEnvironment()
        guard diagnostics.canStartSmokeTests else {
            throw SmokeTestServiceError.environmentUnavailable
        }

        testingConfigurationService.reload()
        let scenarios = try scenarios(for: selection)

        var configuration = agentProfileService.configuration(for: "testing")
        configuration.profileName = "Testing · Smoke"
        configuration.roles = configuration.roles.filter(Self.isSmokeRole)
        guard configuration.roles.contains(where: {
            $0.enabled && $0.promptFilePath.hasSuffix(Self.smokeRunnerFileName)
        }) else {
            throw SmokeTestServiceError.smokeRunnerUnavailable
        }
        configuration.roles = configuration.roles.map { role in
            var role = role
            role.instructions = """
            This Run was explicitly started from Settings > Testing. Execute smoke testing only. \
            Do not run the code-coverage, test-authoring, or code-test phases.

            \(role.instructions)
            """
            return role
        }

        guard let runId = await runLauncher.startRun(
            goal: goal(for: scenarios),
            mode: .multiAgent,
            configuration: configuration
        ) else {
            throw SmokeTestServiceError.runStartFailed
        }
        return runId
    }

    private func scenarios(for selection: SmokeTestSelection) throws -> [SmokeScenario] {
        let scenarios = testingConfigurationService.catalog.scenarios
        switch selection {
        case .enabled:
            let enabled = scenarios.filter(\.enabled)
            guard !enabled.isEmpty else {
                throw SmokeTestServiceError.noEnabledScenarios
            }
            return enabled
        case .all:
            guard !scenarios.isEmpty else {
                throw SmokeTestServiceError.noEnabledScenarios
            }
            return scenarios
        case .matching(let selector):
            let normalizedSelector = selector.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let scenario = scenarios.first(where: {
                $0.id.uuidString.caseInsensitiveCompare(normalizedSelector) == .orderedSame
                    || $0.name.caseInsensitiveCompare(normalizedSelector) == .orderedSame
                    || $0.promptFileName.caseInsensitiveCompare(normalizedSelector) == .orderedSame
            }) else {
                throw SmokeTestServiceError.scenarioNotFound(selector)
            }
            return [scenario]
        }
    }

    private func goal(for scenarios: [SmokeScenario]) -> String {
        let target = testingConfigurationService.catalog.target
        let scenarioList = scenarios.enumerated().map { index, scenario in
            "\(index + 1). \(scenario.name) — .workharness/testing/smoke/\(scenario.promptFileName)"
        }.joined(separator: "\n")

        return """
        Run the enabled smoke scenarios after this explicit Settings action.
        Do not run unit, integration, build, lint, or code-authoring phases.

        Target:
        - Platform: \(target.platform.title)
        - Scheme: \(target.scheme)
        - Bundle identifier: \(target.bundleIdentifier)
        - Device: \(target.deviceName)

        Enabled scenarios, in order:
        \(scenarioList)

        Use only approved mobile MCP tools. Capture a screenshot after every step and produce a \
        smoke-only report with passed, failed, or blocked verdict.
        """
    }

    private static func isSmokeRole(_ role: MultiAgentRoleConfiguration) -> Bool {
        role.promptFilePath.hasSuffix(smokeRunnerFileName)
            || role.promptFilePath.hasSuffix(reporterFileName)
    }

    private static let smokeRunnerFileName = "testing-smoke-runner.md"
    private static let reporterFileName = "testing-reporter.md"
}
