//
// ProcessRunnerRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Swinject

extension Container {
    func registerProcessRunner() {
        register(ProcessRunnerProtocol.self) { _ in
            ProcessRunner()
        }.inObjectScope(.container)
    }
}
