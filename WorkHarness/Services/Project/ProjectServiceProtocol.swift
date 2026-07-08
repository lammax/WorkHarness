//
// ProjectServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
protocol ProjectServiceProtocol: BaseServiceProtocol {
    var projects: [Project] { get }
    var currentProject: Project? { get }

    @discardableResult
    func addProject(name: String, rootPath: String?) -> Project
    func selectProject(id projectId: UUID) throws
    func clearCurrentProject()
}

extension ProjectServiceProtocol {
    var service: AppService { .projects }
}
