//
// SQLiteRunRepository.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation
import Observation
import SQLite3

@MainActor
@Observable
final class SQLiteRunRepository: RunRepository {
    private let database: SQLiteDatabase
    private(set) var runs: [Run]

    init(database: SQLiteDatabase) {
        self.database = database
        self.runs = (try? database.fetchAllJSON(
            sql: "SELECT payload FROM runs ORDER BY updated_at DESC",
            as: Run.self
        )) ?? []
    }

    func insert(_ run: Run) {
        runs.removeAll { $0.id == run.id }
        runs.insert(run, at: 0)
        persist(run)
    }

    func appendEvent(_ event: RunEvent) {
        updateRun(event.runId) { run in
            run.events.append(event)
        }

        try? database.withStatement(
            "INSERT OR REPLACE INTO run_events (id, run_id, payload, created_at) VALUES (?, ?, ?, ?)"
        ) { statement in
            let data = try JSONEncoder().encode(event)
            sqlite3_bind_text(statement, 1, event.id.uuidString, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 2, event.runId.uuidString, -1, SQLITE_TRANSIENT)
            _ = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 3, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            }
            sqlite3_bind_double(statement, 4, event.createdAt.timeIntervalSince1970)
            guard sqlite3_step(statement) == SQLITE_DONE else { return }
        }
    }

    func updateRun(_ runId: UUID, mutation: (inout Run) -> Void) {
        guard let index = runs.firstIndex(where: { $0.id == runId }) else { return }
        mutation(&runs[index])
        runs[index].updatedAt = Date()
        persist(runs[index])
    }

    func run(withId runId: UUID) -> Run? {
        runs.first { $0.id == runId }
    }

    private func persist(_ run: Run) {
        try? database.withStatement(
            "INSERT OR REPLACE INTO runs (id, payload, updated_at) VALUES (?, ?, ?)"
        ) { statement in
            let data = try JSONEncoder().encode(run)
            sqlite3_bind_text(statement, 1, run.id.uuidString, -1, SQLITE_TRANSIENT)
            _ = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 2, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            }
            sqlite3_bind_double(statement, 3, run.updatedAt.timeIntervalSince1970)
            guard sqlite3_step(statement) == SQLITE_DONE else { return }
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
