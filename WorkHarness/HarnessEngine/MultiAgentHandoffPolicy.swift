//
// MultiAgentHandoffPolicy.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation

struct MultiAgentHandoffConfiguration: Equatable {
    var maxInlineCharacters: Int = 12_000
    var previewCharacters: Int = 2_000
    var maxPersistedStreamCharacters: Int = 4_000
}

struct MultiAgentHandoffResult {
    var content: String
    var artifact: RunArtifact?
    var metadata: [String: String]
}

struct MultiAgentHandoffPolicy {
    private let artifactStore: any RunArtifactStoreProtocol
    let configuration: MultiAgentHandoffConfiguration

    init(
        artifactStore: any RunArtifactStoreProtocol = FileRunArtifactStore(),
        configuration: MultiAgentHandoffConfiguration = MultiAgentHandoffConfiguration()
    ) {
        self.artifactStore = artifactStore
        self.configuration = configuration
    }

    func prepare(
        output: String,
        runId: UUID,
        stepId: UUID,
        assistantName: String,
        projectRootPath: String?
    ) throws -> MultiAgentHandoffResult {
        let redacted = SensitiveTextRedactor.redact(output)
        let wasRedacted = redacted != output
        guard redacted.count > configuration.maxInlineCharacters else {
            return MultiAgentHandoffResult(
                content: redacted,
                artifact: nil,
                metadata: [
                    "handoffStorage": "inline",
                    "originalCharacterCount": "\(output.count)",
                    "retainedCharacterCount": "\(redacted.count)",
                    "wasRedacted": "\(wasRedacted)",
                    "retentionPolicy": "until-next-step"
                ]
            )
        }

        let artifact = try artifactStore.storeText(
            redacted,
            runId: runId,
            sourceId: stepId,
            name: "\(assistantName) handoff",
            kind: "multi-agent-handoff",
            projectRootPath: projectRootPath
        )
        let reference = artifactReference(artifact, projectRootPath: projectRootPath)
        let preview = String(redacted.prefix(configuration.previewCharacters))
        let content = """
        Previous step output exceeded the inline handoff limit (\(redacted.count) characters).
        Full redacted output: \(reference)
        Retrieve only the fragment required for the current decision.

        Preview:
        \(preview)
        """
        return MultiAgentHandoffResult(
            content: content,
            artifact: artifact,
            metadata: [
                "handoffStorage": "artifactReference",
                "originalCharacterCount": "\(output.count)",
                "retainedCharacterCount": "\(content.count)",
                "wasRedacted": "\(wasRedacted)",
                "retentionPolicy": "persistent-until-explicit-cleanup",
                "artifactId": artifact.id.uuidString
            ]
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
}
