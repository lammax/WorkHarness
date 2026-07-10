//
// SQLiteDatabase.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation
import SQLite3

@MainActor
final class SQLiteDatabase {
    private let connection: OpaquePointer

    convenience init() throws {
        try self.init(url: Self.defaultDatabaseURL())
    }

    init(url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var database: OpaquePointer?
        guard sqlite3_open(url.path, &database) == SQLITE_OK, let database else {
            throw SQLiteDatabaseError.openFailed(String(cString: sqlite3_errmsg(database)))
        }

        self.connection = database
        try execute("PRAGMA foreign_keys = ON")
        try migrate()
    }

    deinit {
        sqlite3_close(connection)
    }

    func execute(_ sql: String) throws {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteDatabaseError.prepareFailed(errorMessage)
        }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.stepFailed(errorMessage)
        }
    }

    func upsertJSON<T: Encodable>(table: String, id: String, value: T) throws {
        let data = try JSONEncoder().encode(value)
        try withStatement("INSERT OR REPLACE INTO \(table) (id, payload) VALUES (?, ?)") { statement in
            bind(id, at: 1, in: statement)
            bind(data, at: 2, in: statement)
            try stepDone(statement)
        }
    }

    func fetchJSON<T: Decodable>(table: String, id: String, as type: T.Type) throws -> T? {
        try withStatement("SELECT payload FROM \(table) WHERE id = ? LIMIT 1") { statement in
            bind(id, at: 1, in: statement)

            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return try decodeColumn(0, in: statement, as: type)
        }
    }

    func fetchAllJSON<T: Decodable>(sql: String, as type: T.Type) throws -> [T] {
        try withStatement(sql) { statement in
            var values: [T] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                values.append(try decodeColumn(0, in: statement, as: type))
            }

            return values
        }
    }

    func setState(key: String, value: String?) throws {
        if let value {
            try withStatement("INSERT OR REPLACE INTO app_state (key, value) VALUES (?, ?)") { statement in
                bind(key, at: 1, in: statement)
                bind(value, at: 2, in: statement)
                try stepDone(statement)
            }
        } else {
            try withStatement("DELETE FROM app_state WHERE key = ?") { statement in
                bind(key, at: 1, in: statement)
                try stepDone(statement)
            }
        }
    }

    func stateValue(key: String) throws -> String? {
        try withStatement("SELECT value FROM app_state WHERE key = ? LIMIT 1") { statement in
            bind(key, at: 1, in: statement)

            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return String(cString: sqlite3_column_text(statement, 0))
        }
    }

    func withStatement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }

        guard sqlite3_prepare_v2(connection, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteDatabaseError.prepareFailed(errorMessage)
        }

        return try body(statement)
    }

    private func migrate() throws {
        try execute("""
        CREATE TABLE IF NOT EXISTS runs (
            id TEXT PRIMARY KEY NOT NULL,
            payload BLOB NOT NULL,
            updated_at REAL NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS run_events (
            id TEXT PRIMARY KEY NOT NULL,
            run_id TEXT NOT NULL,
            payload BLOB NOT NULL,
            created_at REAL NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS projects (
            id TEXT PRIMARY KEY NOT NULL,
            payload BLOB NOT NULL,
            sort_order INTEGER NOT NULL
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS app_state (
            key TEXT PRIMARY KEY NOT NULL,
            value TEXT
        )
        """)
        try execute("""
        CREATE TABLE IF NOT EXISTS memory_items (
            id TEXT PRIMARY KEY NOT NULL,
            project_id TEXT,
            payload BLOB NOT NULL,
            created_at REAL NOT NULL
        )
        """)
    }

    private var errorMessage: String {
        String(cString: sqlite3_errmsg(connection))
    }

    private func decodeColumn<T: Decodable>(_ index: Int32, in statement: OpaquePointer, as type: T.Type) throws -> T {
        let bytes = sqlite3_column_blob(statement, index)
        let count = Int(sqlite3_column_bytes(statement, index))
        let data = Data(bytes: bytes!, count: count)
        return try JSONDecoder().decode(type, from: data)
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteDatabaseError.stepFailed(errorMessage)
        }
    }

    private func bind(_ value: String, at index: Int32, in statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    }

    private func bind(_ data: Data, at index: Int32, in statement: OpaquePointer) {
        _ = data.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(data.count), SQLITE_TRANSIENT)
        }
    }

    private static func defaultDatabaseURL() throws -> URL {
        if let overridePath = ProcessInfo.processInfo.environment["WORKHARNESS_SQLITE_PATH"],
           !overridePath.isEmpty {
            return URL(fileURLWithPath: overridePath)
        }

        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return baseURL
            .appendingPathComponent("WorkHarness", isDirectory: true)
            .appendingPathComponent("WorkHarness.sqlite")
    }
}

enum SQLiteDatabaseError: LocalizedError, Equatable {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)

    var errorDescription: String? {
        switch self {
        case .openFailed(let message):
            "SQLite open failed: \(message)"
        case .prepareFailed(let message):
            "SQLite prepare failed: \(message)"
        case .stepFailed(let message):
            "SQLite step failed: \(message)"
        }
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
