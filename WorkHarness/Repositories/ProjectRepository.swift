//
// ProjectRepository.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation
import Observation

@MainActor
protocol ProjectRepositoryProtocol: BaseRepositoryProtocol {
    var projects: [Project] { get }
    var currentProjectId: UUID? { get }

    func insert(_ project: Project)
    func project(withId projectId: UUID) -> Project?
    func selectProject(id projectId: UUID)
    func clearCurrentProject()
}

extension ProjectRepositoryProtocol {
    var repository: AppRepository { .projects }
}

@MainActor
@Observable
final class InMemoryProjectRepository: ProjectRepositoryProtocol {
    private(set) var projects: [Project] = []
    private(set) var currentProjectId: UUID?

    func insert(_ project: Project) {
        projects.insert(project, at: 0)
    }

    func project(withId projectId: UUID) -> Project? {
        projects.first { $0.id == projectId }
    }

    func selectProject(id projectId: UUID) {
        currentProjectId = projectId
    }

    func clearCurrentProject() {
        currentProjectId = nil
    }
}
