//
// RepositoriesRegister.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Swinject

extension Container {
    func registerRepositories() {
        register(SQLiteDatabase.self) { _ in
            try! SQLiteDatabase()
        }.inObjectScope(.container)

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

        register(SQLiteProjectRepository.self) { resolver in
            SQLiteProjectRepository(database: resolver.resolve(SQLiteDatabase.self)!)
        }.inObjectScope(.container)

        register(ProjectRepositoryProtocol.self) { resolver in
            resolver.resolve(SQLiteProjectRepository.self)!
        }.inObjectScope(.container)

        register(InMemoryRunRepository.self) { _ in
            InMemoryRunRepository()
        }.inObjectScope(.container)

        register(SQLiteRunRepository.self) { resolver in
            SQLiteRunRepository(database: resolver.resolve(SQLiteDatabase.self)!)
        }.inObjectScope(.container)

        register(RunRepository.self) { resolver in
            resolver.resolve(SQLiteRunRepository.self)!
        }.inObjectScope(.container)

        register(SQLiteMemoryRepository.self) { resolver in
            SQLiteMemoryRepository(database: resolver.resolve(SQLiteDatabase.self)!)
        }.inObjectScope(.container)

        register(MemoryRepositoryProtocol.self) { resolver in
            resolver.resolve(SQLiteMemoryRepository.self)!
        }.inObjectScope(.container)
    }
}
