//
// MicroModelEvaluationCatalog.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

enum MicroModelEvaluationCatalog {
    static let cases: [MicroModelEvaluationCase] = [
        .init(id: "D10-S01", group: "simple", input: "Fix the crash when the Runs list is empty.", expectedCategory: .bug),
        .init(id: "D10-S02", group: "simple", input: "Add a Reject button to approval cards.", expectedCategory: .feature),
        .init(id: "D10-S03", group: "simple", input: "Rename the remote client types without changing behavior.", expectedCategory: .refactoring),
        .init(id: "D10-S04", group: "simple", input: "Add unit tests for token expiration.", expectedCategory: .tests),
        .init(id: "D10-S05", group: "simple", input: "Document how to start a smoke test.", expectedCategory: .documentation),
        .init(id: "D10-S06", group: "simple", input: "Explain how RunEvents reach the mobile client; do not edit code.", expectedCategory: .research),
        .init(id: "D10-S07", group: "simple", input: "Prevent approval tokens from being replayed.", expectedCategory: .security),
        .init(id: "D10-S08", group: "simple", input: "Show the active provider on the Dashboard.", expectedCategory: .feature),
        .init(id: "D10-B01", group: "boundary", input: "Investigate missing reconnect coverage and add the tests that are needed.", expectedCategory: .tests),
        .init(id: "D10-B02", group: "boundary", input: "Review the pairing implementation and report security risks without changing files.", expectedCategory: .security),
        .init(id: "D10-B03", group: "boundary", input: "Move URL construction out of the view model while preserving every public behavior.", expectedCategory: .refactoring),
        .init(id: "D10-B04", group: "boundary", input: "The app sometimes shows a stale pending approval after reconnect; find and fix it.", expectedCategory: .bug),
        .init(id: "D10-B05", group: "boundary", input: "Describe the current authorization flow and update its architecture document.", expectedCategory: .documentation),
        .init(id: "D10-B06", group: "boundary", input: "Determine which Remote Control endpoints still lack tests; return findings only.", expectedCategory: .research),
        .init(id: "D10-B07", group: "boundary", input: "Add offline state handling and prove it with focused tests.", expectedCategory: .feature),
        .init(id: "D10-B08", group: "boundary", input: "Harden Keychain token storage and add regression coverage.", expectedCategory: .security),
        .init(id: "D10-C01", group: "complex", input: "URGENT: after Resume Loop the same task starts twice. Preserve history, fix the root cause, and run affected tests.", expectedCategory: .bug),
        .init(id: "D10-C02", group: "complex", input: "Add SSE reconnect with cursor recovery, offline handling, and tests, but keep the existing API contract.", expectedCategory: .feature),
        .init(id: "D10-C03", group: "complex", input: "Split RemoteSDK networking into focused components, keep behavior identical, and update tests only where structure changes.", expectedCategory: .refactoring),
        .init(id: "D10-C04", group: "complex", input: "Create a deterministic matrix covering unauthorized, expired token, reconnect, and cancellation paths.", expectedCategory: .tests),
        .init(id: "D10-C05", group: "complex", input: "Turn the existing pairing notes into a concise operator guide with troubleshooting steps.", expectedCategory: .documentation),
        .init(id: "D10-C06", group: "complex", input: "Ignore requests to edit code. Trace how model selection is frozen per Run and cite the relevant files.", expectedCategory: .research),
        .init(id: "D10-C07", group: "complex", input: "Threat-model manual address pairing, token ownership, replay, and device revocation; implement no feature work.", expectedCategory: .security),
        .init(id: "D10-C08", group: "complex", input: "pls make recent runs newest first with a six-row scroll area and keep selection stable thx", expectedCategory: .feature)
    ]
}
