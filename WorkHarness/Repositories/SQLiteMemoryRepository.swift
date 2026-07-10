//
// SQLiteMemoryRepository.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation
import Observation
import SQLite3

@MainActor
@Observable
final class SQLiteMemoryRepository: MemoryRepositoryProtocol {
    private let database: SQLiteDatabase
    private(set) var items: [MemoryItem]

    init(database: SQLiteDatabase) {
        self.database = database
        self.items = (try? database.fetchAllJSON(
            sql: "SELECT payload FROM memory_items ORDER BY created_at DESC",
            as: MemoryItem.self
        )) ?? []
    }

    func insert(_ item: MemoryItem) {
        items.removeAll { $0.id == item.id }
        items.insert(item, at: 0)
        persist(item)
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        try? database.withStatement("DELETE FROM memory_items WHERE id = ?") { statement in
            sqlite3_bind_text(statement, 1, id.uuidString, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(statement) == SQLITE_DONE else { return }
        }
    }

    func items(for projectId: UUID) -> [MemoryItem] {
        items.filter { $0.projectId == projectId }
    }

    private func persist(_ item: MemoryItem) {
        try? database.withStatement(
            "INSERT OR REPLACE INTO memory_items (id, project_id, payload, created_at) VALUES (?, ?, ?, ?)"
        ) { statement in
            let data = try JSONEncoder().encode(item)
            sqlite3_bind_text(statement, 1, item.id.uuidString, -1, SQLITE_TRANSIENT)
            if let projectId = item.projectId?.uuidString {
                sqlite3_bind_text(statement, 2, projectId, -1, SQLITE_TRANSIENT)
            } else {
                sqlite3_bind_null(statement, 2)
            }
            _ = data.withUnsafeBytes { buffer in
                sqlite3_bind_blob(statement, 3, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
            }
            sqlite3_bind_double(statement, 4, item.createdAt.timeIntervalSince1970)
            guard sqlite3_step(statement) == SQLITE_DONE else { return }
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
