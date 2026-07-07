//
// RepositoriesRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerRepositories() {
        register(InMemoryRunRepository.self) { _ in
            InMemoryRunRepository()
        }.inObjectScope(.container)

        register(RunRepository.self) { resolver in
            resolver.resolve(InMemoryRunRepository.self)!
        }.inObjectScope(.container)
    }
}
