//
// ProjectService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
final class ProjectService: ProjectServiceProtocol {
    private let repository: ProjectRepositoryProtocol

    init(repository: ProjectRepositoryProtocol) {
        self.repository = repository
    }

    var projects: [Project] {
        repository.projects
    }

    var currentProject: Project? {
        guard let currentProjectId = repository.currentProjectId else { return nil }
        return repository.project(withId: currentProjectId)
    }

    @discardableResult
    func addProject(name: String, rootPath: String?) -> Project {
        let project = Project(name: name, rootPath: rootPath)
        repository.insert(project)

        if repository.currentProjectId == nil {
            repository.selectProject(id: project.id)
        }

        return project
    }

    func selectProject(id projectId: UUID) throws {
        guard repository.project(withId: projectId) != nil else {
            throw ProjectServiceError.projectNotFound(projectId)
        }

        repository.selectProject(id: projectId)
    }

    func clearCurrentProject() {
        repository.clearCurrentProject()
    }
}
