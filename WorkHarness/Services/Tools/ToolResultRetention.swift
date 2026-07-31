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
        let root = try storageRoot()
        let directory = root
            .appendingPathComponent(".workharness", isDirectory: true)
            .appendingPathComponent("artifacts", isDirectory: true)
            .appendingPathComponent(runId.uuidString, isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(sourceId.uuidString)-\(safeFilename(name)).txt"
        let url = directory.appendingPathComponent(filename, isDirectory: false)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return RunArtifact(name: name, kind: kind, path: url.path)
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

    private func safeFilename(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        return String(scalars).prefix(80).lowercased()
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
        let reference = artifactReference(artifact, projectRootPath: request.projectRootPath)
        let retrievalInstruction = artifact.path?.hasPrefix((request.projectRootPath ?? "") + "/") == true
            ? "Use file.read with _output_offset and _output_limit to retrieve a narrow window."
            : "Open the WorkHarness artifact by ID \(artifact.id.uuidString) to inspect the full result."
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

    private func artifactReference(_ artifact: RunArtifact, projectRootPath: String?) -> String {
        guard let path = artifact.path else { return "artifact:\(artifact.id.uuidString)" }
        guard let projectRootPath,
              path.hasPrefix(projectRootPath + "/") else {
            return "artifact:\(artifact.id.uuidString)"
        }
        return String(path.dropFirst(projectRootPath.count + 1))
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
