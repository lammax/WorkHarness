//
// ExecutionLoopStateStore.swift
// WorkHarness
//
// Created by Auto (Codex) on 02.08.2026.
//

import Foundation

struct ExecutionLoopTaskCheckpoint: Codable, Equatable {
    var task: ExecutionTask
    var attemptNumber: Int
    var startedAt: Date
    var headBeforeTask: String
    var runId: UUID?
}

struct ExecutionLoopCheckpoint: Codable, Equatable {
    var version: Int = 1
    var attempt: ExecutionLoopAttempt
    var pool: ExecutionTaskPool
    var activeTask: ExecutionLoopTaskCheckpoint?
    var recoveryTaskId: String?
    var savedAt: Date
}

protocol ExecutionLoopStateStoreProtocol {
    func load() throws -> ExecutionLoopCheckpoint?
    func save(_ checkpoint: ExecutionLoopCheckpoint) throws
}

struct FileExecutionLoopStateStore: ExecutionLoopStateStoreProtocol {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupportURL = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? fileManager.temporaryDirectory
            self.fileURL = applicationSupportURL
                .appendingPathComponent("WorkHarness", isDirectory: true)
                .appendingPathComponent("ExecutionLoop", isDirectory: true)
                .appendingPathComponent("checkpoint.json", isDirectory: false)
        }
    }

    func load() throws -> ExecutionLoopCheckpoint? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder.executionLoop.decode(
            ExecutionLoopCheckpoint.self,
            from: Data(contentsOf: fileURL)
        )
    }

    func save(_ checkpoint: ExecutionLoopCheckpoint) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder.executionLoop.encode(checkpoint)
        try data.write(to: fileURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var executionLoop: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var executionLoop: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
