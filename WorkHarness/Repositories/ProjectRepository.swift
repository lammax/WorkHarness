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

@MainActor
@Observable
final class UserDefaultsProjectRepository: ProjectRepositoryProtocol {
    private enum Key {
        static let projects = "projects.items"
        static let currentProjectId = "projects.currentProjectId"
    }

    private let defaults: UserDefaults
    private(set) var projects: [Project]
    private(set) var currentProjectId: UUID?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.projects = Self.restoreProjects(from: defaults)
        self.currentProjectId = Self.restoreCurrentProjectId(from: defaults, projects: projects)
    }

    func insert(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: 0)

        if currentProjectId == nil {
            currentProjectId = project.id
        }

        persist()
    }

    func project(withId projectId: UUID) -> Project? {
        projects.first { $0.id == projectId }
    }

    func selectProject(id projectId: UUID) {
        currentProjectId = projectId
        persistCurrentProjectId()
    }

    func clearCurrentProject() {
        currentProjectId = nil
        defaults.removeObject(forKey: Key.currentProjectId)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(projects) {
            defaults.set(data, forKey: Key.projects)
        }

        persistCurrentProjectId()
    }

    private func persistCurrentProjectId() {
        if let currentProjectId {
            defaults.set(currentProjectId.uuidString, forKey: Key.currentProjectId)
        } else {
            defaults.removeObject(forKey: Key.currentProjectId)
        }
    }

    private static func restoreProjects(from defaults: UserDefaults) -> [Project] {
        guard let data = defaults.data(forKey: Key.projects),
              let projects = try? JSONDecoder().decode([Project].self, from: data) else {
            return []
        }

        return projects
    }

    private static func restoreCurrentProjectId(from defaults: UserDefaults, projects: [Project]) -> UUID? {
        guard let rawId = defaults.string(forKey: Key.currentProjectId),
              let projectId = UUID(uuidString: rawId),
              projects.contains(where: { $0.id == projectId }) else {
            return nil
        }

        return projectId
    }
}
