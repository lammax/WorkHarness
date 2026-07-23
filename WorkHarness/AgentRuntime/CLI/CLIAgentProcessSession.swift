//
// CLIAgentProcessSession.swift
// WorkHarness
//
// Created by Auto (Codex) on 23.07.2026.
//

import Foundation

@MainActor
final class CLIAgentProcessSession {
    let events: AsyncThrowingStream<CLIAgentProcessEvent, Error>

    private let writeHandler: @MainActor (Data) throws -> Void
    private let closeInputHandler: @MainActor () -> Void
    private let cancelHandler: @MainActor () -> Void

    init(
        events: AsyncThrowingStream<CLIAgentProcessEvent, Error>,
        writeHandler: @escaping @MainActor (Data) throws -> Void,
        closeInputHandler: @escaping @MainActor () -> Void,
        cancelHandler: @escaping @MainActor () -> Void
    ) {
        self.events = events
        self.writeHandler = writeHandler
        self.closeInputHandler = closeInputHandler
        self.cancelHandler = cancelHandler
    }

    func send(_ data: Data) throws {
        try writeHandler(data)
    }

    func send(_ text: String) throws {
        try send(Data(text.utf8))
    }

    func sendLine(_ line: String) throws {
        try send("\(line)\n")
    }

    func closeInput() {
        closeInputHandler()
    }

    func cancel() {
        cancelHandler()
    }
}
