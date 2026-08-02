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
    var rejectionReason: AgentOutputRejectionReason?
}

struct MultiAgentHandoffPolicy {
    private let outputSafetyPolicy: AgentOutputSafetyPolicy
    let configuration: MultiAgentHandoffConfiguration

    init(
        artifactStore: any RunArtifactStoreProtocol = FileRunArtifactStore(),
        configuration: MultiAgentHandoffConfiguration = MultiAgentHandoffConfiguration()
    ) {
        self.configuration = configuration
        self.outputSafetyPolicy = AgentOutputSafetyPolicy(
            artifactStore: artifactStore,
            configuration: AgentOutputSafetyConfiguration(
                maxInlineCharacters: configuration.maxInlineCharacters,
                previewCharacters: configuration.previewCharacters
            )
        )
    }

    func prepare(
        output: String,
        runId: UUID,
        stepId: UUID,
        assistantName: String,
        projectRootPath: String?
    ) throws -> MultiAgentHandoffResult {
        let processed = try outputSafetyPolicy.process(
            output: output,
            runId: runId,
            sourceId: stepId,
            name: "\(assistantName) handoff",
            artifactKind: "multi-agent-handoff",
            projectRootPath: projectRootPath
        )
        var metadata = processed.metadata
        metadata["handoffStorage"] = processed.metadata["outputStorage"]
        if processed.artifact == nil {
            metadata["retentionPolicy"] = "until-next-step"
        }
        return MultiAgentHandoffResult(
            content: processed.content,
            artifact: processed.artifact,
            metadata: metadata,
            rejectionReason: processed.rejectionReason
        )
    }

}
