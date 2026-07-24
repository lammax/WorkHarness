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
    private let runRepository: RunRepository
    private let recorder: RunRecorder
    private let projectService: ProjectServiceProtocol
    private let fileManager: FileManager

    init(
        testingConfigurationService: TestingConfigurationServiceProtocol,
        testingEnvironmentService: TestingEnvironmentServiceProtocol,
        agentProfileService: AgentProfileServiceProtocol,
        runLauncher: any RunLaunchingProtocol,
        runRepository: RunRepository,
        recorder: RunRecorder,
        projectService: ProjectServiceProtocol,
        fileManager: FileManager = .default
    ) {
        self.testingConfigurationService = testingConfigurationService
        self.testingEnvironmentService = testingEnvironmentService
        self.agentProfileService = agentProfileService
        self.runLauncher = runLauncher
        self.runRepository = runRepository
        self.recorder = recorder
        self.projectService = projectService
        self.fileManager = fileManager
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
            This Run was explicitly started by the user from Testing settings or a `/smoke` chat command. Execute smoke testing only. \
            Do not run the code-coverage, test-authoring, or code-test phases.

            \(role.instructions)
            """
            if role.promptFilePath.hasSuffix(Self.reporterFileName) {
                role.instructions += """

                End the response with exactly:
                ## Final Verdict
                PASSED, FAILED, or BLOCKED
                """
            }
            return role
        }

        guard let runId = await runLauncher.startRun(
            goal: goal(for: scenarios),
            mode: .multiAgent,
            configuration: configuration
        ) else {
            throw SmokeTestServiceError.runStartFailed
        }
        try createReport(
            runId: runId,
            scenarios: scenarios,
            diagnostics: diagnostics
        )
        return runId
    }

    private func createReport(
        runId: UUID,
        scenarios: [SmokeScenario],
        diagnostics: TestingEnvironmentDiagnostics
    ) throws {
        guard let run = runRepository.run(withId: runId) else {
            throw SmokeTestServiceError.completedRunUnavailable
        }
        guard let rootPath = projectService.currentProject?.rootPath else {
            throw SmokeTestServiceError.reportDirectoryUnavailable
        }

        let reportsDirectory = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(TestingConfigurationDefaults.directoryName, isDirectory: true)
            .appendingPathComponent(TestingConfigurationDefaults.reportsDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        let reportURL = reportsDirectory
            .appendingPathComponent("smoke-\(run.id.uuidString.lowercased())")
            .appendingPathExtension("md")
        try reportMarkdown(
            run: run,
            scenarios: scenarios,
            diagnostics: diagnostics
        ).write(to: reportURL, atomically: true, encoding: .utf8)

        let artifact = RunArtifact(
            name: "Smoke Test Report",
            kind: "smoke-report",
            path: reportURL.path
        )
        recorder.recordArtifact(runId: run.id, artifact: artifact)
        recorder.record(
            runId: run.id,
            type: .artifactCreated,
            message: artifact.name,
            metadata: [
                "artifactId": artifact.id.uuidString,
                "kind": artifact.kind,
                "path": reportURL.path
            ]
        )
        recorder.record(
            runId: run.id,
            type: .finalSummary,
            message: "Smoke report saved: \(reportURL.path)",
            metadata: ["verdict": verdict(for: run)]
        )
    }

    private func reportMarkdown(
        run: Run,
        scenarios: [SmokeScenario],
        diagnostics: TestingEnvironmentDiagnostics
    ) -> String {
        let environment = diagnostics.checks.map {
            "- **\($0.title):** \($0.status.rawValue.uppercased()) — \($0.message)"
        }.joined(separator: "\n")
        let scenarioList = scenarios.enumerated().map {
            "\($0.offset + 1). **\($0.element.name)** — `\($0.element.promptFileName)`"
        }.joined(separator: "\n")
        let screenshots = run.artifacts.filter { $0.kind == "screenshot" }
        let screenshotList = screenshots.isEmpty
            ? "- No screenshot artifacts were recorded."
            : screenshots.map { "- `\($0.path ?? $0.name)`" }.joined(separator: "\n")
        let failures = run.events.filter(Self.isFailureEvent)
        let failureList = failures.isEmpty
            ? "- No Run failure events were recorded."
            : failures.map { "- **\($0.type.label):** \($0.message)" }.joined(separator: "\n")
        let reporterOutput = reporterOutput(from: run)

        return """
        # Smoke Test Report

        - **Run:** `\(run.id.uuidString)`
        - **Status:** \(run.status.label)
        - **Final Verdict:** \(verdict(for: run))

        ## Environment

        \(environment)

        ## Scenarios

        \(scenarioList)

        ## Screenshot Artifacts

        \(screenshotList)

        ## Failure Events

        \(failureList)

        ## Test Reporter

        \(reporterOutput.isEmpty ? "No Test Reporter output was recorded." : reporterOutput)
        """
    }

    private func reporterOutput(from run: Run) -> String {
        let reporterEvents = run.events.filter {
            $0.metadata["assistantName"] == "Test Reporter"
        }
        if let completed = reporterEvents.last(where: { $0.type == .assistantMessage }) {
            return completed.message
        }
        return reporterEvents
            .filter { $0.type == .providerStreamDelta }
            .map(\.message)
            .joined()
    }

    private func verdict(for run: Run) -> String {
        switch run.status {
        case .failed:
            return "FAILED"
        case .cancelled, .interrupted:
            return "BLOCKED"
        default:
            break
        }

        let output = reporterOutput(from: run).uppercased()
        for verdict in ["FAILED", "BLOCKED", "PASSED"] {
            if output.contains("FINAL VERDICT: \(verdict)")
                || output.contains("FINAL VERDICT\n\(verdict)")
                || output.contains("FINAL VERDICT\r\n\(verdict)") {
                return verdict
            }
        }
        return "BLOCKED"
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
        Run the enabled smoke scenarios after this explicit user request from Testing settings or a `/smoke` chat command.
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

    private static func isFailureEvent(_ event: RunEvent) -> Bool {
        switch event.type {
        case .providerRequestFailed, .toolCallFailed, .error, .runFailed:
            true
        default:
            false
        }
    }

    private static let smokeRunnerFileName = "testing-smoke-runner.md"
    private static let reporterFileName = "testing-reporter.md"
}
