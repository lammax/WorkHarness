//
// ToolResultRetentionTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 31.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

@Suite
struct ToolResultRetentionTests {
    @MainActor
    @Test func legacyToolResultDecodesWithInlineRetentionDefaults() throws {
        let legacy = """
        {
          "toolId": "file.read",
          "status": "succeeded",
          "output": "small",
          "metadata": {},
          "artifacts": []
        }
        """

        let result = try JSONDecoder().decode(ToolResult.self, from: Data(legacy.utf8))

        #expect(result.retention.storage == .inline)
        #expect(result.retention.originalCharacterCount == 5)
        #expect(result.retention.retainedCharacterCount == 5)
    }

    @MainActor
    @Test func largeToolResultBecomesResolvableRedactedArtifactAndBoundedEvent() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Read large output")
        repository.insert(run)
        let secret = "sk-sensitive-value-123456"
        let rawOutput = "token=\(secret)\n" + String(repeating: "payload ", count: 80)
        let service = makeService(
            repository: repository,
            result: ToolResult(toolId: "file.read", status: .succeeded, output: rawOutput),
            artifactRoot: root,
            configuration: ToolResultRetentionConfiguration(
                maxInlineCharacters: 120,
                previewCharacters: 40,
                maxErrorCharacters: 80
            )
        )

        let result = try await service.execute(.init(
            runId: run.id,
            toolId: "file.read",
            arguments: ["path": "large.txt", "api_token": secret],
            projectRootPath: root.path
        ))

        #expect(result.retention.storage == .artifactReference)
        #expect(result.output.count < rawOutput.count)
        #expect(!result.output.contains(secret))
        let artifact = try #require(result.artifacts.last)
        let path = try #require(artifact.path)
        let stored = try String(contentsOfFile: path, encoding: .utf8)
        #expect(stored.contains("[REDACTED]"))
        #expect(!stored.contains(secret))
        let storedRun = try #require(repository.run(withId: run.id))
        #expect(storedRun.artifacts.contains(artifact))
        let event = try #require(storedRun.events.last { $0.type == .toolResult })
        #expect(event.message == result.output)
        #expect(event.metadata["outputStorage"] == "artifactReference")
        #expect(!event.metadata.values.contains { $0.contains(secret) })
    }

    @MainActor
    @Test func repeatedLargeToolCallsCreateDistinctArtifactsWithoutGrowingInlineEvents() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Repeat reads")
        repository.insert(run)
        let output = String(repeating: "abcdefghij", count: 50)
        let service = makeService(
            repository: repository,
            result: ToolResult(toolId: "file.read", status: .succeeded, output: output),
            artifactRoot: root,
            configuration: ToolResultRetentionConfiguration(
                maxInlineCharacters: 100,
                previewCharacters: 20,
                maxErrorCharacters: 80
            )
        )

        let first = try await service.execute(.init(
            runId: run.id,
            toolId: "file.read",
            arguments: ["path": "one.txt"],
            projectRootPath: root.path
        ))
        let second = try await service.execute(.init(
            runId: run.id,
            toolId: "file.read",
            arguments: ["path": "two.txt"],
            projectRootPath: root.path
        ))

        #expect(first.retention.artifactId != second.retention.artifactId)
        let storedRun = try #require(repository.run(withId: run.id))
        #expect(storedRun.artifacts.filter { $0.kind == "tool-result" }.count == 2)
        #expect(storedRun.events.filter { $0.type == .toolResult }.allSatisfy {
            $0.message.count < output.count
        })
    }

    @MainActor
    @Test func outputWindowReturnsDeterministicPageAndContinuationOffset() throws {
        let processor = ToolResultRetentionProcessor(
            artifactStore: FileRunArtifactStore(fallbackRoot: FileManager.default.temporaryDirectory),
            configuration: ToolResultRetentionConfiguration(
                maxInlineCharacters: 12,
                previewCharacters: 4,
                maxErrorCharacters: 20
            )
        )
        let result = try processor.process(
            ToolResult(toolId: "file.read", status: .succeeded, output: "abcdefghijklmnopqrstuvwxyz"),
            request: ToolExecutionRequest(
                runId: UUID(),
                toolId: "file.read",
                outputWindow: ToolOutputWindow(offset: 5, limit: 4)
            )
        )

        #expect(result.output.hasPrefix("fghi"))
        #expect(result.output.contains("Next _output_offset: 9"))
        #expect(result.metadata["outputOffset"] == "5")
        #expect(result.metadata["outputLimit"] == "4")
        #expect(result.metadata["hasMore"] == "true")
    }

    @MainActor
    @Test func toolFailureIsRedactedAndBoundedBeforeEventAndCallerExposure() async throws {
        let repository = InMemoryRunRepository()
        let run = Run(goal: "Fail safely")
        repository.insert(run)
        let secret = "Bearer abcdefghijklmnop"
        let service = makeService(
            repository: repository,
            error: RetentionTestError.failure(secret + String(repeating: "x", count: 300)),
            configuration: ToolResultRetentionConfiguration(
                maxInlineCharacters: 100,
                previewCharacters: 20,
                maxErrorCharacters: 60
            )
        )

        do {
            _ = try await service.execute(.init(
                runId: run.id,
                toolId: "file.read",
                arguments: ["path": "missing.txt", "authorization": secret]
            ))
            Issue.record("Expected bounded tool failure.")
        } catch {
            #expect(error.localizedDescription.count < 100)
            #expect(!error.localizedDescription.contains(secret))
            #expect(error.localizedDescription.contains("[error output bounded]"))
        }

        let event = try #require(repository.run(withId: run.id)?.events.last)
        #expect(event.type == .toolCallFailed)
        #expect(event.message.count < 100)
        #expect(!event.message.contains(secret))
    }

    @MainActor
    private func makeService(
        repository: InMemoryRunRepository,
        result: ToolResult? = nil,
        error: Error? = nil,
        artifactRoot: URL? = nil,
        configuration: ToolResultRetentionConfiguration
    ) -> ToolService {
        let recorder = RunRecorder(repository: repository)
        return ToolService(
            registry: ToolRegistry(tools: [FileReadTool()]),
            mcpClient: RetentionMCPClient(result: result, error: error),
            approvalService: ApprovalService(
                repository: InMemoryApprovalRepository(),
                runRepository: repository,
                recorder: recorder,
                appSettingsService: InMemoryAppSettingsService()
            ),
            recorder: recorder,
            resultProcessor: ToolResultRetentionProcessor(
                artifactStore: FileRunArtifactStore(fallbackRoot: artifactRoot),
                configuration: configuration
            )
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "WorkHarnessToolRetention-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

@MainActor
private final class RetentionMCPClient: MCPToolClientProtocol {
    private let result: ToolResult?
    private let error: Error?

    init(result: ToolResult?, error: Error?) {
        self.result = result
        self.error = error
    }

    func invoke(_ invocation: MCPToolInvocation) async throws -> ToolResult {
        if let error { throw error }
        return try #require(result)
    }
}

private enum RetentionTestError: LocalizedError {
    case failure(String)

    var errorDescription: String? {
        switch self {
        case .failure(let message):
            message
        }
    }
}
