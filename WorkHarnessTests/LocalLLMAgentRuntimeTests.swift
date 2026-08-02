//
// LocalLLMAgentRuntimeTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 02.08.2026.
//

import Foundation
import Testing
@testable import WorkHarness

@Suite
struct LocalLLMAgentRuntimeTests {
    @MainActor
    @Test func localRuntimeExecutesStructuredToolActionThroughToolService() async throws {
        let provider = ScriptedLocalLLMProviderClient(responses: [
            #"{"type":"tool","toolId":"file.read","arguments":{"path":"README.md"}}"#,
            #"{"type":"final","content":"README inspected and the task is complete."}"#
        ])
        let tools = RecordingLocalRuntimeToolService()
        let runtime = LocalLLMAgentRuntime(
            providerClient: provider,
            toolService: tools,
            settingsService: InMemoryAppSettingsService(localLLMModel: "qwen-test")
        )
        let runId = UUID()
        runtime.configure(modelId: "qwen-test", runId: runId, workingDirectory: "/tmp/project")
        let session = try await runtime.connect()
        let execution = try await runtime.run(
            task: AgentTask(runId: runId, prompt: "Inspect README", workingDirectory: "/tmp/project"),
            sessionId: session.id
        )
        var events: [AgentEvent] = []
        for try await event in execution.events { events.append(event) }

        #expect(tools.requests.count == 1)
        #expect(tools.requests.first?.toolId == "file.read")
        #expect(tools.requests.first?.projectRootPath == "/tmp/project")
        #expect(provider.requests.count == 2)
        #expect(provider.requests.last?.aiRequest.messages.contains {
            $0.role == .tool && $0.content.contains("README contents")
        } == true)
        #expect(events.contains {
            if case .finished(let response) = $0 {
                return response.message.contains("task is complete")
            }
            return false
        })
    }

    @Test func artifactStoreRetrievesBoundedPagesByOpaqueIdentifier() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "WorkHarnessArtifactContract-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let store = FileRunArtifactStore(fallbackRoot: root)
        let artifact = try store.storeText(
            "abcdefghijklmnopqrstuvwxyz",
            runId: UUID(),
            sourceId: UUID(),
            name: "large output",
            kind: "test",
            projectRootPath: nil
        )

        let first = try store.readText(artifactId: artifact.id, offset: 0, limit: 5)
        let second = try store.readText(
            artifactId: artifact.id,
            offset: try #require(first.nextOffset),
            limit: 5
        )

        #expect(first.content == "abcde")
        #expect(first.hasMore)
        #expect(second.content == "fghij")
        #expect(first.totalCharacterCount == 26)
        #expect(artifact.path?.contains(artifact.id.uuidString) == true)
    }
}

@MainActor
private final class ScriptedLocalLLMProviderClient: MCPProviderClientProtocol {
    private var responses: [String]
    private(set) var requests: [MCPProviderRequest] = []

    init(responses: [String]) {
        self.responses = responses
    }

    func streamEvents(
        for request: MCPProviderRequest
    ) async throws -> AsyncThrowingStream<MCPProviderEvent, Error> {
        requests.append(request)
        let response = responses.removeFirst()
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageCompleted(response))
            continuation.yield(.tokenUsage(TokenUsage(inputTokens: 10, outputTokens: 5)))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}

@MainActor
private final class RecordingLocalRuntimeToolService: ToolServiceProtocol {
    let availableTools = [
        ToolDefinition(
            id: "file.read",
            displayName: "Read File",
            description: "Read a bounded file window.",
            inputSchema: [ToolInputField(name: "path", description: "Relative path", required: true)]
        )
    ]
    private(set) var requests: [ToolExecutionRequest] = []

    func execute(_ request: ToolExecutionRequest) async throws -> ToolResult {
        try await executeAwaitingApproval(request)
    }

    func executeAwaitingApproval(_ request: ToolExecutionRequest) async throws -> ToolResult {
        requests.append(request)
        return ToolResult(toolId: request.toolId, status: .succeeded, output: "README contents")
    }
}
