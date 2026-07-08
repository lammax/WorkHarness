//
// ProcessRunSession.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
final class ProcessRunSession {
    let events: AsyncThrowingStream<ProcessRunEvent, Error>
    private let cancelHandler: () -> Void

    init(events: AsyncThrowingStream<ProcessRunEvent, Error>, cancelHandler: @escaping () -> Void) {
        self.events = events
        self.cancelHandler = cancelHandler
    }

    func cancel() {
        cancelHandler()
    }
}
