//
// RepositoriesRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerRepositories() {
        register(InMemoryApprovalRepository.self) { _ in
            InMemoryApprovalRepository()
        }.inObjectScope(.container)

        register(ApprovalRepositoryProtocol.self) { resolver in
            resolver.resolve(InMemoryApprovalRepository.self)!
        }.inObjectScope(.container)

        register(InMemoryProjectRepository.self) { _ in
            InMemoryProjectRepository()
        }.inObjectScope(.container)

        register(UserDefaultsProjectRepository.self) { _ in
            UserDefaultsProjectRepository()
        }.inObjectScope(.container)

        register(ProjectRepositoryProtocol.self) { resolver in
            resolver.resolve(UserDefaultsProjectRepository.self)!
        }.inObjectScope(.container)

        register(InMemoryRunRepository.self) { _ in
            InMemoryRunRepository()
        }.inObjectScope(.container)

        register(RunRepository.self) { resolver in
            resolver.resolve(InMemoryRunRepository.self)!
        }.inObjectScope(.container)
    }
}
