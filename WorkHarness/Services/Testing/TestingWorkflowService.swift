//
// TestingWorkflowService.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
final class TestingWorkflowService: TestingWorkflowServiceProtocol {
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

    func startFullRun(request: String?) async throws -> UUID {
        let diagnostics = try await testingEnvironmentService.checkEnvironment()
        guard diagnostics.canStartSmokeTests else {
            throw TestingWorkflowServiceError.environmentUnavailable
        }

        testingConfigurationService.reload()
        let scenarios = testingConfigurationService.catalog.scenarios.filter(\.enabled)
        guard !scenarios.isEmpty else {
            throw TestingWorkflowServiceError.noEnabledScenarios
        }

        var configuration = agentProfileService.configuration(for: Self.profileId)
        guard Self.requiredPromptFiles.allSatisfy({ promptFile in
            configuration.roles.contains {
                $0.enabled && $0.promptFilePath.hasSuffix(promptFile)
            }
        }) else {
            throw TestingWorkflowServiceError.testingProfileIncomplete
        }

        configuration.profileName = "Testing · Full"
        configuration.roles = configuration.roles.map { role in
            var role = role
            role.instructions = """
            This Run was explicitly started by the user with `/test`. Execute the complete configured Testing flow \
            in order and preserve evidence for the final report.

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
            goal: goal(request: request, scenarios: scenarios),
            mode: .multiAgent,
            configuration: configuration
        ) else {
            throw TestingWorkflowServiceError.runStartFailed
        }

        try createReport(
            runId: runId,
            request: request,
            scenarios: scenarios,
            diagnostics: diagnostics
        )
        return runId
    }

    private func createReport(
        runId: UUID,
        request: String?,
        scenarios: [SmokeScenario],
        diagnostics: TestingEnvironmentDiagnostics
    ) throws {
        guard let run = runRepository.run(withId: runId) else {
            throw TestingWorkflowServiceError.completedRunUnavailable
        }
        guard let rootPath = projectService.currentProject?.rootPath else {
            throw TestingWorkflowServiceError.reportDirectoryUnavailable
        }

        let reportsDirectory = URL(fileURLWithPath: rootPath, isDirectory: true)
            .appendingPathComponent(TestingConfigurationDefaults.directoryName, isDirectory: true)
            .appendingPathComponent(TestingConfigurationDefaults.reportsDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: reportsDirectory, withIntermediateDirectories: true)
        let reportURL = reportsDirectory
            .appendingPathComponent("testing-\(run.id.uuidString.lowercased())")
            .appendingPathExtension("md")
        try reportMarkdown(
            run: run,
            request: request,
            scenarios: scenarios,
            diagnostics: diagnostics
        ).write(to: reportURL, atomically: true, encoding: .utf8)

        let artifact = RunArtifact(
            name: "Testing Report",
            kind: "testing-report",
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
            message: "Testing report saved: \(reportURL.path)",
            metadata: ["verdict": verdict(for: run)]
        )
    }

    private func reportMarkdown(
        run: Run,
        request: String?,
        scenarios: [SmokeScenario],
        diagnostics: TestingEnvironmentDiagnostics
    ) -> String {
        let target = testingConfigurationService.catalog.target
        let requestText = request?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userContext = requestText.flatMap { $0.isEmpty ? nil : $0 }
            ?? "Validate the current project state."
        let environment = diagnostics.checks.map {
            "- **\($0.title):** \($0.status.rawValue.uppercased()) — \($0.message)"
        }.joined(separator: "\n")
        let phases = Self.requiredAssistantNames.map { assistantName in
            let finished = run.events.contains {
                $0.type == .agentFinished && $0.metadata["assistantName"] == assistantName
            }
            return "- **\(assistantName):** \(finished ? "COMPLETED" : "MISSING")"
        }.joined(separator: "\n")
        let scenarioList = scenarios.enumerated().map {
            "\($0.offset + 1). **\($0.element.name)** — `\($0.element.promptFileName)`"
        }.joined(separator: "\n")
        let artifacts = run.artifacts.isEmpty
            ? "- No artifacts were recorded."
            : run.artifacts.map {
                "- **\($0.kind):** `\($0.path ?? $0.name)`"
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
        # Testing Report

        - **Run:** `\(run.id.uuidString)`
        - **Status:** \(run.status.label)
        - **Final Verdict:** \(verdict(for: run))

        ## User Request

        \(userContext)

        ## Commands

        - **Build:** `\(target.buildCommand)`
        - **Code tests:** `\(target.codeTestCommand)`

        ## Environment

        \(environment)

        ## Workflow Phases

        \(phases)

        ## Smoke Scenarios

        \(scenarioList)

        ## Artifacts

        \(artifacts)

        ## Screenshot Evidence

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

        guard Self.requiredAssistantNames.allSatisfy({ assistantName in
            run.events.contains {
                $0.type == .agentFinished && $0.metadata["assistantName"] == assistantName
            }
        }) else {
            return "BLOCKED"
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

    private func goal(request: String?, scenarios: [SmokeScenario]) -> String {
        let target = testingConfigurationService.catalog.target
        let scenarioList = scenarios.enumerated().map { index, scenario in
            "\(index + 1). \(scenario.name) — .workharness/testing/smoke/\(scenario.promptFileName)"
        }.joined(separator: "\n")
        let requestText = request?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userContext = requestText.flatMap { $0.isEmpty ? nil : $0 }
            ?? "Validate the current project state."

        return """
        Execute the complete Testing profile after this explicit `/test` command.

        User context:
        \(userContext)

        Required flow:
        1. Find meaningful code-test gaps in at least three production modules.
        2. Add deterministic unit or integration tests for those gaps.
        3. Run the configured build and code-test commands.
        4. Review smoke coverage. Update the catalog and Markdown scenarios only if the user context explicitly requests coverage for a new or changed feature.
        5. Run every enabled smoke scenario through the approved mobile MCP gateway.
        6. Produce one evidence-backed report. A skipped or blocked required phase is not a pass.

        Commands:
        - Build: \(target.buildCommand)
        - Code tests: \(target.codeTestCommand)

        Smoke target:
        - Platform: \(target.platform.title)
        - Scheme: \(target.scheme)
        - Bundle identifier: \(target.bundleIdentifier)
        - Device: \(target.deviceName)

        Enabled smoke scenarios, in order:
        \(scenarioList)
        """
    }

    private static func isFailureEvent(_ event: RunEvent) -> Bool {
        switch event.type {
        case .providerRequestFailed, .toolCallFailed, .error, .runFailed:
            true
        default:
            false
        }
    }

    private static let profileId = "testing"
    private static let reporterFileName = "testing-reporter.md"
    private static let requiredAssistantNames = [
        "Coverage Analyst",
        "Test Author",
        "Code Test Runner",
        "Smoke Scenario Maintainer",
        "Smoke Runner",
        "Test Reporter"
    ]
    private static let requiredPromptFiles = [
        "testing-coverage-analyst.md",
        "testing-test-author.md",
        "testing-code-test-runner.md",
        "testing-smoke-scenario-maintainer.md",
        "testing-smoke-runner.md",
        reporterFileName
    ]
}
