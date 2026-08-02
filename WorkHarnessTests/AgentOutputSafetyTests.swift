//
// AgentOutputSafetyTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 02.08.2026.
//

import Foundation
import Testing
@testable import WorkHarness

struct AgentOutputSafetyTests {
    @MainActor
    @Test func harnessFailsRunWhenProviderStopsAtPreparatoryAnswer() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let provider = PreparatoryAnswerProvider()
        let providerService = ProviderService(
            registry: ProviderRegistry(providers: [provider]),
            appSettingsService: InMemoryAppSettingsService(defaultProviderId: provider.id)
        )
        let engine = HarnessEngine(
            repository: repository,
            recorder: recorder,
            providerService: providerService,
            agentOutputSafetyPolicy: AgentOutputSafetyPolicy(
                artifactStore: FileRunArtifactStore(fallbackRoot: root)
            )
        )

        let runId = try #require(await engine.startRun(goal: "Fix the issue"))
        let run = try #require(repository.run(withId: runId))

        #expect(run.status == .failed)
        #expect(!run.events.contains { $0.type == .runCompleted })
        #expect(run.events.contains {
            $0.type == .validationFinished && $0.metadata["status"] == "failed"
        })
        #expect(run.artifacts.count == 1)
    }

    @MainActor
    @Test func rejectsPseudoToolTranscriptAndPreservesItOutsideTimeline() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let policy = AgentOutputSafetyPolicy(
            artifactStore: FileRunArtifactStore(fallbackRoot: root)
        )
        let transcript = """
        Открою текущий diff.

        **Tool: bash**
        {"command":"git diff"}
        {"tool_response":"\(String(repeating: "DI/", count: 8_000))"}
        """

        let result = try policy.process(
            output: transcript,
            runId: UUID(),
            sourceId: UUID(),
            name: "Rejected output",
            artifactKind: "rejected-agent-output",
            projectRootPath: nil
        )

        #expect(result.rejectionReason == .pseudoToolTranscript)
        #expect(result.content.count < 1_000)
        #expect(!result.content.contains("git diff"))
        let artifactPath = try #require(result.artifact?.path)
        #expect(try String(contentsOfFile: artifactPath, encoding: .utf8) == transcript)
    }

    @MainActor
    @Test func rejectsPreparatoryAndTruncatedFinalAnswers() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let policy = AgentOutputSafetyPolicy(
            artifactStore: FileRunArtifactStore(fallbackRoot: root)
        )

        let preparatory = try policy.process(
            output: "Открою текущий diff, чтобы понять состояние.",
            runId: UUID(),
            sourceId: UUID(),
            name: "Output",
            artifactKind: "rejected-agent-output",
            projectRootPath: nil
        )
        let truncated = try policy.process(
            output: "Partial result [1015281 characters truncated]",
            runId: UUID(),
            sourceId: UUID(),
            name: "Output",
            artifactKind: "rejected-agent-output",
            projectRootPath: nil
        )

        #expect(preparatory.rejectionReason == .incompleteFinalAnswer)
        #expect(truncated.rejectionReason == .incompleteFinalAnswer)
    }

    @MainActor
    @Test func largeCompletedOutputUsesBoundedPreviewAndFullArtifact() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let policy = AgentOutputSafetyPolicy(
            artifactStore: FileRunArtifactStore(fallbackRoot: root),
            configuration: .init(maxInlineCharacters: 120, previewCharacters: 40)
        )
        let output = "Implemented and verified. " + String(repeating: "safe-result ", count: 100)

        let result = try policy.process(
            output: output,
            runId: UUID(),
            sourceId: UUID(),
            name: "Large output",
            artifactKind: "agent-output",
            projectRootPath: nil
        )

        #expect(result.rejectionReason == nil)
        #expect(result.content.count < output.count)
        #expect(result.metadata["outputStorage"] == "artifactReference")
        let artifactPath = try #require(result.artifact?.path)
        #expect(try String(contentsOfFile: artifactPath, encoding: .utf8) == output)
    }
}

private struct PreparatoryAnswerProvider: AIProvider {
    let id = "test.preparatory"
    let displayName = "Preparatory Provider"
    let capabilities = ProviderCapabilities(supportedModels: ["test"])

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageCompleted("Открою текущий diff, чтобы понять состояние."))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}

private func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}
