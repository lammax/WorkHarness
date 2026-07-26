//
// RunEventDisplayFormatterTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 26.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

struct RunEventDisplayFormatterTests {
    @Test
    func formatsFileResultAsReadableText() {
        let event = makeEvent(
            message: #"{"content":"Hello, Swift!","path":"Sources/App.swift","truncated":false}"#
        )

        #expect(
            RunEventDisplayFormatter.message(for: event)
                == "File: Sources/App.swift\n\nHello, Swift!"
        )
    }

    @Test
    func formatsShellResultWithoutJSONNoise() {
        let event = makeEvent(
            message: #"{"standardOutput":"Tests passed","standardError":"","exitCode":0}"#
        )

        #expect(RunEventDisplayFormatter.message(for: event) == "Tests passed")
    }

    @Test
    func preservesShellFailureDetails() {
        let event = makeEvent(
            message: #"{"standardOutput":"","standardError":"Build failed","exitCode":65}"#
        )

        #expect(
            RunEventDisplayFormatter.message(for: event)
                == "Error output:\nBuild failed\n\nExit code: 65"
        )
    }

    @Test
    func formatsGenericJSONAsKeyValueText() {
        let event = makeEvent(
            message: #"{"action":"created","bytesWritten":2019,"path":"Tests/NewTests.swift"}"#
        )
        let message = RunEventDisplayFormatter.message(for: event)

        #expect(message.contains("Action: created"))
        #expect(message.contains("Bytes written: 2019"))
        #expect(message.contains("Path: Tests/NewTests.swift"))
        #expect(!message.contains(#"{"#))
    }

    @Test
    func leavesNonToolEventsUnchanged() {
        let message = #"{"answer":"Keep this JSON"}"#
        let event = RunEvent(
            runId: UUID(),
            type: .assistantMessage,
            message: message
        )

        #expect(RunEventDisplayFormatter.message(for: event) == message)
    }

    private func makeEvent(message: String) -> RunEvent {
        RunEvent(
            runId: UUID(),
            type: .toolResult,
            message: message
        )
    }
}
