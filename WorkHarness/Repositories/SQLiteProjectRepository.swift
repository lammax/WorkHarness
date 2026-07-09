//
// SQLiteProjectRepository.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation
import Observation
import SQLite3

@MainActor
@Observable
final class SQLiteProjectRepository: ProjectRepositoryProtocol {
    private enum StateKey {
        static let currentProjectId = "projects.currentProjectId"
    }

    private let database: SQLiteDatabase
    private(set) var projects: [Project]
    private(set) var currentProjectId: UUID?

    init(database: SQLiteDatabase) {
        self.database = database
        self.projects = (try? database.fetchAllJSON(
            sql: "SELECT payload FROM projects ORDER BY sort_order ASC",
            as: Project.self
        )) ?? []

        if let rawId = (try? database.stateValue(key: StateKey.currentProjectId)) ?? nil,
           let projectId = UUID(uuidString: rawId),
           projects.contains(where: { $0.id == projectId }) {
            self.currentProjectId = projectId
        }
    }

    func insert(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        projects.insert(project, at: 0)

        if currentProjectId == nil {
            currentProjectId = project.id
        }

        persistProjects()
        persistCurrentProjectId()
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
        persistCurrentProjectId()
    }

    private func persistProjects() {
        try? database.execute("DELETE FROM projects")
        for (index, project) in projects.enumerated() {
            try? database.withStatement(
                "INSERT OR REPLACE INTO projects (id, payload, sort_order) VALUES (?, ?, ?)"
            ) { statement in
                let data = try JSONEncoder().encode(project)
                sqlite3_bind_text(statement, 1, project.id.uuidString, -1, SQLITE_TRANSIENT)
                _ = data.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, 2, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
                }
                sqlite3_bind_int64(statement, 3, Int64(index))
                guard sqlite3_step(statement) == SQLITE_DONE else { return }
            }
        }
    }

    private func persistCurrentProjectId() {
        try? database.setState(key: StateKey.currentProjectId, value: currentProjectId?.uuidString)
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
