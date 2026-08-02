//
// AgentOutputSafetyPolicy.swift
// WorkHarness
//
// Created by Auto (Codex) on 02.08.2026.
//

import Foundation

enum AgentOutputRejectionReason: String, Codable, Equatable {
    case emptyFinalAnswer
    case pseudoToolTranscript
    case incompleteFinalAnswer

    var message: String {
        switch self {
        case .emptyFinalAnswer:
            "Agent finished without a final answer."
        case .pseudoToolTranscript:
            "Agent returned a plain-text tool transcript instead of completing the tool action."
        case .incompleteFinalAnswer:
            "Agent stopped at a preparatory or truncated response without a completed result."
        }
    }
}

struct AgentOutputSafetyConfiguration: Equatable {
    var maxInlineCharacters: Int = 12_000
    var previewCharacters: Int = 2_000
}

struct AgentOutputSafetyResult {
    var content: String
    var artifact: RunArtifact?
    var metadata: [String: String]
    var rejectionReason: AgentOutputRejectionReason?
}

struct AgentOutputSafetyPolicy {
    private let artifactStore: any RunArtifactStoreProtocol
    let configuration: AgentOutputSafetyConfiguration

    init(
        artifactStore: any RunArtifactStoreProtocol = FileRunArtifactStore(),
        configuration: AgentOutputSafetyConfiguration = AgentOutputSafetyConfiguration()
    ) {
        self.artifactStore = artifactStore
        self.configuration = configuration
    }

    func process(
        output: String,
        runId: UUID,
        sourceId: UUID,
        name: String,
        artifactKind: String,
        projectRootPath: String?
    ) throws -> AgentOutputSafetyResult {
        let redacted = SensitiveTextRedactor.redact(output)
        let rejectionReason = rejectionReason(for: redacted)
        let requiresArtifact = rejectionReason != nil ||
            redacted.count > configuration.maxInlineCharacters
        let artifact = try requiresArtifact
            ? artifactStore.storeText(
                redacted,
                runId: runId,
                sourceId: sourceId,
                name: name,
                kind: artifactKind,
                projectRootPath: projectRootPath
            )
            : nil
        let reference = artifact.map {
            artifactReference($0, projectRootPath: projectRootPath)
        }
        let storage = artifact == nil ? "inline" : "artifactReference"
        let content: String

        if let rejectionReason {
            content = """
            Agent output rejected: \(rejectionReason.message)
            Preserved redacted output: \(reference ?? "unavailable")
            """
        } else if let reference {
            let preview = String(redacted.prefix(configuration.previewCharacters))
            content = """
            Agent output exceeded the inline limit (\(redacted.count) characters).
            Full redacted output: \(reference)
            Retrieve only the fragment required for the current decision.

            Preview:
            \(preview)
            """
        } else {
            content = redacted
        }

        var metadata = [
            "outputSafetyStatus": rejectionReason == nil ? "accepted" : "rejected",
            "outputStorage": storage,
            "originalCharacterCount": "\(output.count)",
            "retainedCharacterCount": "\(content.count)",
            "wasRedacted": "\(redacted != output)",
            "retentionPolicy": artifact == nil
                ? "run-event"
                : "persistent-until-explicit-cleanup"
        ]
        if let rejectionReason {
            metadata["outputRejectionReason"] = rejectionReason.rawValue
        }
        if let artifact {
            metadata["artifactId"] = artifact.id.uuidString
        }

        return AgentOutputSafetyResult(
            content: content,
            artifact: artifact,
            metadata: metadata,
            rejectionReason: rejectionReason
        )
    }

    private func rejectionReason(for output: String) -> AgentOutputRejectionReason? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .emptyFinalAnswer }

        let lowercased = trimmed.lowercased()
        let containsToolHeader = matches(
            #"(?im)^\s*\*\*tool:\s*[^*]+\*\*\s*$"#,
            in: trimmed
        )
        let containsToolPayload = lowercased.contains("\"tool_response\"") ||
            lowercased.contains("<tool_call>") ||
            lowercased.contains("<tool_result>") ||
            matches(#"(?i)\"command\"\s*:"#, in: trimmed)
        if containsToolHeader ||
            (lowercased.contains("\"tool_response\"") && containsToolPayload) {
            return .pseudoToolTranscript
        }

        if matches(#"(?i)\[[0-9]+\s+characters?\s+truncated\]"#, in: trimmed) ||
            lowercased.contains("[output truncated]") {
            return .incompleteFinalAnswer
        }

        let isShortPreparatoryAnswer = trimmed.count <= 600 && matches(
            #"(?is)^\s*(i(?:'ll| will| am going to)|let me|opening|checking|inspecting|открою|проверю|посмотрю|изучу|сейчас)\b"#,
            in: trimmed
        )
        let hasCompletionSignal = matches(
            #"(?i)\b(done|completed|implemented|fixed|verified|готово|сделано|исправлено|реализовано|проверено)\b"#,
            in: trimmed
        )
        if isShortPreparatoryAnswer && !hasCompletionSignal {
            return .incompleteFinalAnswer
        }

        return nil
    }

    private func matches(_ pattern: String, in value: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private func artifactReference(_ artifact: RunArtifact, projectRootPath: String?) -> String {
        guard let path = artifact.path else { return "artifact:\(artifact.id.uuidString)" }
        guard let projectRootPath,
              path.hasPrefix(projectRootPath + "/") else {
            return "artifact:\(artifact.id.uuidString)"
        }
        return String(path.dropFirst(projectRootPath.count + 1))
    }
}
