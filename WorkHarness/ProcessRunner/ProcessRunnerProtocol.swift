//
// ProcessRunnerProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
protocol ProcessRunnerProtocol: AnyObject {
    func start(_ request: ProcessRunRequest) throws -> ProcessRunSession
}
