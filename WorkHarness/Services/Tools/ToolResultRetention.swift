//
// ToolResultRetention.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

protocol RunArtifactStoreProtocol {
    func storeText(
        _ content: String,
        runId: UUID,
        sourceId: UUID,
        name: String,
        kind: String,
        projectRootPath: String?
    ) throws -> RunArtifact

    func readText(artifactId: UUID, offset: Int, limit: Int) throws -> RunArtifactContentPage
    func cleanupArtifacts(olderThan cutoff: Date) throws -> Int
}

extension RunArtifactStoreProtocol {
    func readText(artifactId: UUID, offset: Int, limit: Int) throws -> RunArtifactContentPage {
        throw RunArtifactStoreError.retrievalUnsupported
    }

    func cleanupArtifacts(olderThan cutoff: Date) throws -> Int { 0 }
}

struct RunArtifactContentPage: Equatable {
    var artifactId: UUID
    var content: String
    var offset: Int
    var nextOffset: Int?
    var totalCharacterCount: Int
    var hasMore: Bool
}

struct FileRunArtifactStore: RunArtifactStoreProtocol {
    private let fileManager: FileManager
    private let fallbackRoot: URL?

    init(fileManager: FileManager = .default, fallbackRoot: URL? = nil) {
        self.fileManager = fileManager
        self.fallbackRoot = fallbackRoot
    }

    func storeText(
        _ content: String,
        runId: UUID,
        sourceId: UUID,
        name: String,
        kind: String,
        projectRootPath: String?
    ) throws -> RunArtifact {
        _ = try? cleanupArtifacts(
            olderThan: Date().addingTimeInterval(-30 * 24 * 60 * 60)
        )
        let root = try storageRoot()
        let directory = root
            .appendingPathComponent(".workharness", isDirectory: true)
            .appendingPathComponent("artifacts", isDirectory: true)
            .appendingPathComponent(runId.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let artifactId = UUID()
        let filename = "\(artifactId.uuidString).txt"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return RunArtifact(id: artifactId, name: name, kind: kind, path: url.path)
    }

    func readText(artifactId: UUID, offset: Int, limit: Int) throws -> RunArtifactContentPage {
        let boundedOffset = max(0, offset)
        let boundedLimit = min(max(1, limit), 12_000)
        let root = try artifactsRoot()
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            throw RunArtifactStoreError.artifactNotFound(artifactId)
        }
        let expectedName = "\(artifactId.uuidString).txt"
        guard let url = enumerator.compactMap({ $0 as? URL }).first(where: {
            $0.lastPathComponent == expectedName
        }) else {
            throw RunArtifactStoreError.artifactNotFound(artifactId)
        }
        let content = try String(contentsOf: url, encoding: .utf8)
        let startOffset = min(boundedOffset, content.count)
        let start = content.index(content.startIndex, offsetBy: startOffset)
        let retainedCount = min(boundedLimit, content.distance(from: start, to: content.endIndex))
        let end = content.index(start, offsetBy: retainedCount)
        let nextOffset = startOffset + retainedCount
        let hasMore = nextOffset < content.count
        return RunArtifactContentPage(
            artifactId: artifactId,
            content: String(content[start..<end]),
            offset: startOffset,
            nextOffset: hasMore ? nextOffset : nil,
            totalCharacterCount: content.count,
            hasMore: hasMore
        )
    }

    func cleanupArtifacts(olderThan cutoff: Date) throws -> Int {
        let root = try artifactsRoot()
        guard fileManager.fileExists(atPath: root.path),
              let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
              ) else { return 0 }
        var removed = 0
        for case let url as URL in enumerator where url.pathExtension == "txt" {
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values.isRegularFile == true,
                  let modifiedAt = values.contentModificationDate,
                  modifiedAt < cutoff else { continue }
            try fileManager.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    private func storageRoot() throws -> URL {
        if let fallbackRoot {
            return fallbackRoot
        }
        guard let applicationSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw ToolResultRetentionError.artifactStorageUnavailable
        }
        return applicationSupport.appendingPathComponent("WorkHarness", isDirectory: true)
    }

    private func artifactsRoot() throws -> URL {
        try storageRoot()
            .appendingPathComponent(".workharness", isDirectory: true)
            .appendingPathComponent("artifacts", isDirectory: true)
    }

}

struct ToolResultRetentionConfiguration: Equatable {
    var maxInlineCharacters: Int = 12_000
    var previewCharacters: Int = 2_000
    var maxErrorCharacters: Int = 2_000
}

struct ToolResultRetentionProcessor {
    private let artifactStore: any RunArtifactStoreProtocol
    private let configuration: ToolResultRetentionConfiguration

    init(
        artifactStore: any RunArtifactStoreProtocol = FileRunArtifactStore(),
        configuration: ToolResultRetentionConfiguration = ToolResultRetentionConfiguration()
    ) {
        self.artifactStore = artifactStore
        self.configuration = configuration
    }

    func process(_ result: ToolResult, request: ToolExecutionRequest) throws -> ToolResult {
        let redactedOutput = redact(result.output, arguments: request.arguments)
        let safeMetadata = redact(result.metadata, arguments: request.arguments)
        let wasRedacted = redactedOutput != result.output || safeMetadata != result.metadata
        let originalCharacterCount = result.output.count
        let window = normalizedWindow(request.outputWindow, contentCount: redactedOutput.count)

        if let window {
            return windowedResult(
                result,
                redactedOutput: redactedOutput,
                safeMetadata: safeMetadata,
                wasRedacted: wasRedacted,
                window: window
            )
        }

        guard redactedOutput.count > configuration.maxInlineCharacters else {
            var processed = result
            processed.output = redactedOutput
            processed.metadata = safeMetadata.merging([
                "outputStorage": ToolResultStorage.inline.rawValue,
                "originalCharacterCount": "\(originalCharacterCount)",
                "retainedCharacterCount": "\(redactedOutput.count)",
                "wasRedacted": "\(wasRedacted)",
                "retentionPolicy": "request"
            ]) { _, new in new }
            processed.retention = ToolResultRetention(
                storage: .inline,
                originalCharacterCount: originalCharacterCount,
                retainedCharacterCount: redactedOutput.count,
                wasRedacted: wasRedacted
            )
            return processed
        }

        let artifact = try artifactStore.storeText(
            redactedOutput,
            runId: request.runId,
            sourceId: request.id,
            name: "\(result.toolId) output",
            kind: "tool-result",
            projectRootPath: request.projectRootPath
        )
        let reference = "artifact:\(artifact.id.uuidString)"
        let retrievalInstruction = "Retrieve the WorkHarness artifact by ID with bounded offset and limit."
        let preview = String(redactedOutput.prefix(configuration.previewCharacters))
        let boundedOutput = """
        Tool output exceeded the inline limit (\(redactedOutput.count) characters).
        Full redacted output: \(reference)
        \(retrievalInstruction)

        Preview:
        \(preview)
        """
        var processed = result
        processed.output = boundedOutput
        processed.metadata = safeMetadata.merging([
            "outputStorage": ToolResultStorage.artifactReference.rawValue,
            "originalCharacterCount": "\(originalCharacterCount)",
            "retainedCharacterCount": "\(boundedOutput.count)",
            "wasRedacted": "\(wasRedacted)",
            "retentionPolicy": "persistent-until-explicit-cleanup",
            "artifactId": artifact.id.uuidString
        ]) { _, new in new }
        processed.artifacts.append(artifact)
        processed.retention = ToolResultRetention(
            storage: .artifactReference,
            originalCharacterCount: originalCharacterCount,
            retainedCharacterCount: boundedOutput.count,
            wasRedacted: wasRedacted,
            artifactId: artifact.id,
            policy: "persistent-until-explicit-cleanup"
        )
        return processed
    }

    func boundedErrorMessage(_ error: Error, request: ToolExecutionRequest) -> String {
        let redacted = redact(error.localizedDescription, arguments: request.arguments)
        guard redacted.count > configuration.maxErrorCharacters else { return redacted }
        return "\(redacted.prefix(configuration.maxErrorCharacters))… [error output bounded]"
    }

    private func windowedResult(
        _ result: ToolResult,
        redactedOutput: String,
        safeMetadata: [String: String],
        wasRedacted: Bool,
        window: ToolOutputWindow
    ) -> ToolResult {
        let start = redactedOutput.index(
            redactedOutput.startIndex,
            offsetBy: min(window.offset, redactedOutput.count)
        )
        let end = redactedOutput.index(
            start,
            offsetBy: min(window.limit, redactedOutput.distance(from: start, to: redactedOutput.endIndex))
        )
        let content = String(redactedOutput[start..<end])
        let nextOffset = window.offset + content.count
        let hasMore = nextOffset < redactedOutput.count
        let suffix = hasMore
            ? "\n\n[More output available. Next _output_offset: \(nextOffset)]"
            : ""
        var processed = result
        processed.output = content + suffix
        processed.metadata = safeMetadata.merging([
            "outputStorage": ToolResultStorage.inline.rawValue,
            "originalCharacterCount": "\(result.output.count)",
            "retainedCharacterCount": "\(processed.output.count)",
            "outputOffset": "\(window.offset)",
            "outputLimit": "\(window.limit)",
            "hasMore": "\(hasMore)",
            "wasRedacted": "\(wasRedacted)",
            "retentionPolicy": "request"
        ]) { _, new in new }
        processed.retention = ToolResultRetention(
            storage: .inline,
            originalCharacterCount: result.output.count,
            retainedCharacterCount: processed.output.count,
            wasRedacted: wasRedacted
        )
        return processed
    }

    private func normalizedWindow(_ window: ToolOutputWindow?, contentCount: Int) -> ToolOutputWindow? {
        guard let window else { return nil }
        return ToolOutputWindow(
            offset: min(window.offset, contentCount),
            limit: min(window.limit, configuration.maxInlineCharacters)
        )
    }

    private func redact(_ metadata: [String: String], arguments: [String: String]) -> [String: String] {
        metadata.reduce(into: [:]) { result, pair in
            result[pair.key] = isSensitiveKey(pair.key)
                ? "[REDACTED]"
                : SensitiveTextRedactor.redact(pair.value, sensitiveValues: sensitiveValues(arguments))
        }
    }

    private func redact(_ content: String, arguments: [String: String]) -> String {
        SensitiveTextRedactor.redact(content, sensitiveValues: sensitiveValues(arguments))
    }

    private func isSensitiveKey(_ key: String) -> Bool {
        let normalized = key.lowercased()
        return ["token", "secret", "password", "api_key", "apikey", "authorization"]
            .contains { normalized.contains($0) }
    }

    private func sensitiveValues(_ arguments: [String: String]) -> [String] {
        arguments.compactMap { key, value in
            isSensitiveKey(key) && !value.isEmpty ? value : nil
        }
    }
}

enum SensitiveTextRedactor {
    static func redact(_ content: String, sensitiveValues: [String] = []) -> String {
        var redacted = content
        for value in sensitiveValues where !value.isEmpty {
            redacted = redacted.replacingOccurrences(of: value, with: "[REDACTED]")
        }
        let patterns = [
            #"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]{8,}"#,
            #"\bsk-[A-Za-z0-9_-]{8,}"#,
            #"(?i)(api[_-]?key|password|secret|token)\s*[:=]\s*[^\s,;]+"#
        ]
        for pattern in patterns {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: "[REDACTED]",
                options: .regularExpression
            )
        }
        return redacted
    }
}

enum ToolResultRetentionError: LocalizedError {
    case artifactStorageUnavailable

    var errorDescription: String? {
        switch self {
        case .artifactStorageUnavailable:
            "Tool output is too large to return inline and artifact storage is unavailable."
        }
    }
}

enum RunArtifactStoreError: LocalizedError, Equatable {
    case artifactNotFound(UUID)
    case retrievalUnsupported

    var errorDescription: String? {
        switch self {
        case .artifactNotFound(let id):
            "Artifact was not found: \(id.uuidString)."
        case .retrievalUnsupported:
            "This artifact store does not support content retrieval."
        }
    }
}
