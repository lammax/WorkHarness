//
// ContextContractTests.swift
// WorkHarness
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

struct ContextContractTests {
    @MainActor
    @Test func contextBuilderProducesDeterministicOrderedContract() throws {
        let input = makeCompleteInput()
        let builder = ContextBuilder()

        let first = builder.buildSnapshot(from: input)
        let second = builder.buildSnapshot(from: input)

        #expect(first.objective == input.userMessage)
        #expect(first.objectiveSource == second.objectiveSource)
        #expect(first.objectiveSource?.kind == .objective)
        #expect(first.objectiveSource?.informationClass == .requiredNow)
        #expect(first.objectiveSource?.priority == .critical)
        #expect(first.sections == second.sections)
        #expect(first.contextItems == second.contextItems)
        #expect(first.omissions == second.omissions)
        #expect(first.windowConstraint == second.windowConstraint)
        #expect(first.sections.map(\.content) == first.contextItems)
        #expect(first.sections.map(\.order) == Array(first.sections.indices))
        #expect(first.sections.map(\.kind) == [
            .projectIdentity,
            .projectRoot,
            .safetyInstruction,
            .recentRunSummary,
            .foldedContext,
            .selectedFiles,
            .attachment,
            .projectMemory,
            .retrievalResults
        ])
    }

    @MainActor
    @Test func everySelectedSourceHasContextPolicyMetadata() throws {
        let snapshot = ContextBuilder().buildSnapshot(from: makeCompleteInput())
        let sources = snapshot.sections.flatMap(\.sources)

        #expect(!sources.isEmpty)
        #expect(sources.allSatisfy { !$0.id.isEmpty })
        #expect(sources.allSatisfy { !$0.purpose.isEmpty })
        #expect(sources.allSatisfy { $0.estimatedTokenCount > 0 })
        #expect(sources.contains {
            $0.kind == .fileReference &&
                $0.informationClass == .retrievableLater &&
                $0.retentionPolicy == .externalReference
        })
        #expect(sources.contains {
            $0.kind == .memory &&
                $0.informationClass == .persistentState &&
                $0.retentionPolicy == .project
        })
        #expect(sources.contains {
            $0.kind == .safetyPolicy &&
                $0.informationClass == .requiredNow &&
                $0.priority == .critical
        })
        #expect(snapshot.windowConstraint == ContextWindowConstraint(
            configuredMaxInputTokens: 8_000,
            reservedOutputTokens: 1_000,
            providerContextWindowTokens: 16_384
        ))
        #expect(snapshot.omissions.isEmpty)
    }

    @MainActor
    @Test func contextSnapshotDecodesLegacyPayloadWithoutTypedContract() throws {
        let snapshot = ContextBuilder().buildSnapshot(from: makeCompleteInput())
        let encoded = try JSONEncoder().encode(snapshot)
        var object = try #require(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "sections")
        object.removeValue(forKey: "omissions")
        object.removeValue(forKey: "windowConstraint")
        object.removeValue(forKey: "deliveryMode")
        object.removeValue(forKey: "objectiveSource")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(ContextSnapshot.self, from: legacyData)

        #expect(decoded.contextItems == snapshot.contextItems)
        #expect(decoded.objectiveSource == nil)
        #expect(decoded.sections.isEmpty)
        #expect(decoded.omissions.isEmpty)
        #expect(decoded.deliveryMode == .unsupported)
        #expect(decoded.windowConstraint == ContextWindowConstraint(
            configuredMaxInputTokens: nil,
            reservedOutputTokens: nil,
            providerContextWindowTokens: nil
        ))
    }

    private func makeCompleteInput() -> ContextBuildInput {
        let runId = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
        let project = Project(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
            name: "WorkHarness",
            rootPath: "/tmp/WorkHarness"
        )
        let agent = Agent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
            role: .coder,
            providerId: "test.provider",
            model: "test-model"
        )
        let fold = ContextFoldSummary(
            runSummary: "Continue the context contract.",
            conversationSummary: "The audit is complete.",
            decisionLog: ["Keep one ContextBuilder."],
            currentState: "Implementing Phase 2.",
            failedAttempts: [],
            nextActions: ["Add deterministic sections."],
            sourceEventCount: 4,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let attachment = RunContextAttachment(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!,
            name: "requirements.md",
            content: "Preserve provider-neutral context policy."
        )
        let citation = RAGCitation(
            source: "Documentation/Architecture.md",
            section: "Context",
            chunkID: 7,
            quote: "Context construction has one owner.",
            score: 0.95
        )

        return ContextBuildInput(
            runId: runId,
            agent: agent,
            providerId: "test.provider",
            userMessage: "Implement the minimal context contract.",
            currentProject: project,
            recentRunSummary: "The delivery boundary is stable.",
            contextFoldSummary: fold,
            selectedFiles: ["WorkHarness/HarnessEngine/ContextBuilder.swift"],
            contextAttachments: [attachment],
            memoryItems: ["WorkHarness uses a provider-neutral ContextBuilder."],
            ragResults: [citation],
            tokenBudget: TokenBudget(maxInputTokens: 8_000, maxOutputTokens: 1_000),
            providerContextWindowTokens: 16_384,
            safetyMode: .autoInsideSandbox,
            deliveryMode: .structuredMessages
        )
    }
}
