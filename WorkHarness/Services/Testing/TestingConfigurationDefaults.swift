//
// TestingConfigurationDefaults.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

enum TestingConfigurationDefaults {
    static let directoryName = ".workharness/testing"
    static let scenarioDirectoryName = "smoke"
    static let reportsDirectoryName = "reports"
    static let manifestFileName = "testing.json"

    static let catalog = TestingConfigurationCatalog(
        target: TestingTargetConfiguration(
            platform: .iOSSimulator,
            xcodeContainerPath: "WorkHarnessMobile.xcodeproj",
            scheme: "WorkHarnessMobile",
            bundleIdentifier: "com.lammax.projects.ios.ai.harness.work.mobile.WorkHarnessMobile",
            deviceName: "iPhone 16 Pro",
            buildCommand: "xcodebuild build -project WorkHarnessMobile.xcodeproj -scheme WorkHarnessMobile -destination 'platform=iOS Simulator,name=iPhone 16 Pro'",
            codeTestCommand: "xcodebuild test -project WorkHarnessMobile.xcodeproj -scheme WorkHarnessMobile -destination 'platform=iOS Simulator,name=iPhone 16 Pro'"
        ),
        scenarios: [
            scenario(
                "40000000-0000-0000-0000-000000000001",
                name: "Pairing succeeds",
                summary: "Connect to a deterministic WorkHarness fixture and verify capabilities.",
                file: "pairing-success.md"
            ),
            scenario(
                "40000000-0000-0000-0000-000000000002",
                name: "Authentication error",
                summary: "Reject an invalid token and keep retry available.",
                file: "authentication-error.md"
            ),
            scenario(
                "40000000-0000-0000-0000-000000000003",
                name: "Runs list and details",
                summary: "Open fixture Runs, inspect one Run, and verify its events.",
                file: "runs-list-and-detail.md"
            ),
            scenario(
                "40000000-0000-0000-0000-000000000004",
                name: "Approval decision",
                summary: "Open a pending approval and submit a decision.",
                file: "approval-decision.md"
            ),
            scenario(
                "40000000-0000-0000-0000-000000000005",
                name: "Remote Run cancellation",
                summary: "Start a remote Run, observe a live event, and cancel it.",
                file: "remote-run-cancellation.md"
            )
        ]
    )

    static let scenarioPrompts: [String: String] = [
        "pairing-success.md": """
        # Pairing succeeds

        ## Preconditions
        - Launch WorkHarnessMobile with the deterministic UI-testing fixture.
        - Use the fixture host and pairing code exposed by the test configuration.

        ## Steps
        1. Capture the initial Pairing screen.
        2. Enter the fixture host.
        3. Enter the valid pairing code.
        4. Tap Pair.
        5. Verify that the paired state and server capabilities are visible.

        ## Evidence
        Capture a screenshot after every step. Mark the scenario failed if the expected paired state is not visible.
        """,
        "authentication-error.md": """
        # Authentication error

        ## Preconditions
        - Launch WorkHarnessMobile with the deterministic UI-testing fixture.

        ## Steps
        1. Enter the fixture host.
        2. Enter an invalid pairing code.
        3. Tap Pair.
        4. Verify that an authentication error is visible.
        5. Verify that the fields and Pair action remain available for retry.

        ## Evidence
        Capture a screenshot after every step. Do not treat a generic timeout as an authentication pass.
        """,
        "runs-list-and-detail.md": """
        # Runs list and details

        ## Preconditions
        - Start from a paired fixture session containing deterministic Runs.

        ## Steps
        1. Open the Runs list.
        2. Verify the expected fixture Run title and status.
        3. Open that Run.
        4. Verify the Run details and ordered RunEvents.

        ## Evidence
        Capture a screenshot after every step and report the missing title, status, or event when an assertion fails.
        """,
        "approval-decision.md": """
        # Approval decision

        ## Preconditions
        - Start from a paired fixture session with one pending approval.

        ## Steps
        1. Open the approval inbox.
        2. Open the fixture approval.
        3. Verify its action and risk details.
        4. Approve the request.
        5. Verify that it leaves the pending inbox and shows the approved state.

        ## Evidence
        Capture a screenshot after every step. Never approve a non-fixture request.
        """,
        "remote-run-cancellation.md": """
        # Remote Run cancellation

        ## Preconditions
        - Start from a paired deterministic fixture session.

        ## Steps
        1. Start a new remote Run with the fixture goal.
        2. Verify that the Run appears as running.
        3. Wait for the deterministic live RunEvent.
        4. Cancel the Run.
        5. Verify the cancelled terminal state.

        ## Evidence
        Capture a screenshot after every step. Report whether failure occurred during start, streaming, cancellation, or final-state refresh.
        """
    ]

    private static func scenario(
        _ id: String,
        name: String,
        summary: String,
        file: String
    ) -> SmokeScenario {
        SmokeScenario(
            id: UUID(uuidString: id)!,
            name: name,
            summary: summary,
            promptFileName: file
        )
    }
}
