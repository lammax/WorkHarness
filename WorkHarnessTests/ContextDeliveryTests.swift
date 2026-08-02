//
// ContextDeliveryTests.swift
// WorkHarness
//
// Created by Auto (Codex) on 30.07.2026.
//

import Foundation
import Testing
@testable import WorkHarness

struct ContextDeliveryTests {
    @MainActor
    @Test func cursorACPReceivesBuiltContextExactlyOnce() async throws {
        let connection = ContextDeliveryACPConnection()
        let client = ACPSubprocessClient(
            id: "context.cursor.acp",
            displayName: "Context Cursor ACP",
            transport: ContextDeliveryACPTransport(connection: connection)
        )
        let runtime = ACPClientRuntime(
            client: client,
            descriptor: AgentRuntimeDescriptor(
                id: client.id,
                displayName: client.displayName,
                transport: .acp,
                contextDeliveryMode: .renderedPrompt
            )
        )
        let registry = AgentRuntimeRegistry()
        registry.register(runtime)
        let repository = InMemoryRunRepository()
        let settings = InMemoryAppSettingsService(defaultAgentRuntimeId: client.id)
        let engine = HarnessEngine(
            repository: repository,
            recorder: RunRecorder(repository: repository),
            providerService: contextProviderService(),
            contextBuilder: ContextBuilder(),
            appSettingsService: settings,
            agentRuntimeRegistry: registry
        )
        let marker = "CURSOR_CONTEXT_MARKER"

        let runId = try #require(await engine.startRun(
            goal: "Inspect the supplied context",
            contextAttachments: [
                RunContextAttachment(name: "context.txt", content: marker)
            ]
        ))

        let prompt = try #require(connection.promptText)
        let event = try #require(repository.run(withId: runId)?.events.first {
            $0.type == .contextBuilt
        })
        #expect(prompt.contains(marker))
        #expect(occurrenceCount(of: marker, in: prompt) == 1)
        #expect(prompt.contains("Task:\nInspect the supplied context"))
        #expect(event.metadata["deliveryMode"] == ContextDeliveryMode.renderedPrompt.rawValue)
        #expect(event.metadata["contextWindowCapability"] == "unknown")
        #expect(event.metadata["outputReservationCapability"] == "configured")
        #expect(event.metadata["usageReportingCapability"] == "unknown")
        #expect(event.metadata["cancellationCapability"] == "unknown")
        #expect(event.metadata["capabilityFallbacks"]?.contains(
            "contextWindow:configuredInputBudget"
        ) == true)
    }

    @MainActor
    @Test func claudeReceivesBuiltContextExactlyOnce() async throws {
        let marker = "CLAUDE_CONTEXT_MARKER"
        let output = """
        {"type":"system","subtype":"init","session_id":"context-session"}
        {"type":"result","subtype":"success","is_error":false,"session_id":"context-session","result":"Done","usage":{"input_tokens":4,"output_tokens":1}}

        """
        let transport = ContextDeliveryCLITransport(events: [
            .stdout(output),
            .finished(ProcessExit(status: .succeeded, exitCode: 0))
        ])
        let runtime = ClaudeCLIRuntime(
            executableURL: URL(fileURLWithPath: "/tmp/claude"),
            transport: transport
        )
        let task = AgentTask(
            runId: UUID(),
            prompt: "Inspect the supplied context",
            context: makeSnapshot(marker: marker)
        )
        let session = try await runtime.connect()

        let execution = try await runtime.run(task: task, sessionId: session.id)
        _ = try await collect(execution.events)
        await runtime.disconnect(sessionId: session.id)

        let prompt = try #require(transport.configurations.first?.arguments.last)
        #expect(prompt == task.renderedPrompt)
        #expect(occurrenceCount(of: marker, in: prompt) == 1)
        #expect(ClaudeCLIRuntime.runtimeDescriptor.contextDeliveryMode == .renderedPrompt)
    }

    @MainActor
    @Test func localLLMEncodesContextAsOneStructuredSystemMessage() throws {
        let firstMarker = "LOCAL_CONTEXT_ONE"
        let secondMarker = "LOCAL_CONTEXT_TWO"
        let client = MCPProviderClient(configuration: MCPProviderConfiguration())
        let agent = Agent(
            role: .coder,
            providerId: MCPProviderDescriptor.localLLM.id,
            model: "local-test"
        )
        let request = AIRequest(
            runId: UUID(),
            agent: agent,
            messages: [
                ProviderMessage(role: .user, content: "Inspect the supplied context")
            ],
            context: [firstMarker, secondMarker]
        )

        let messages = client.localLLMMessages(from: request)

        #expect(messages.count == 2)
        #expect(messages[0].role == ProviderMessageRole.system.rawValue)
        #expect(messages[0].content == "\(firstMarker)\n\n\(secondMarker)")
        #expect(messages[1].role == ProviderMessageRole.user.rawValue)
        #expect(occurrenceCount(of: firstMarker, in: messages[0].content) == 1)
        #expect(occurrenceCount(of: secondMarker, in: messages[0].content) == 1)
    }

    @MainActor
    @Test func contextBuiltEventContainsMetadataWithoutRawContext() async throws {
        let repository = InMemoryRunRepository()
        let provider = ContextRecordingProvider()
        let marker = "PRIVATE_ATTACHMENT_CONTENT"
        let engine = HarnessEngine(
            repository: repository,
            recorder: RunRecorder(repository: repository),
            providerService: ProviderService(
                registry: ProviderRegistry(providers: [provider]),
                appSettingsService: InMemoryAppSettingsService()
            ),
            contextBuilder: ContextBuilder()
        )

        let runId = try #require(await engine.startRun(
            goal: "Review an attachment",
            contextAttachments: [
                RunContextAttachment(name: "private.txt", content: marker)
            ]
        ))

        let event = try #require(repository.run(withId: runId)?.events.first {
            $0.type == .contextBuilt
        })
        let request = try #require(provider.requests.first)
        #expect(request.context.contains { $0.contains(marker) })
        #expect(!event.message.contains(marker))
        #expect(!event.metadata.values.contains { $0.contains(marker) })
        #expect(event.metadata["deliveryMode"] == ContextDeliveryMode.structuredMessages.rawValue)
        #expect(event.metadata["contextItemCount"] == "\(request.context.count)")
        #expect(event.metadata["contextSectionCount"] == "\(request.context.count)")
        #expect(event.metadata["contextSourceCount"] == "2")
        #expect(event.metadata["attachmentCount"] == "1")
        #expect(event.metadata["providerContextWindowTokens"] == "16000")
        #expect(event.metadata["contextWindowCapability"] == "reported")
        #expect(event.metadata["outputReservationCapability"] == "unavailable")
        #expect(event.metadata["streamingCapability"] == "supported")
        #expect(event.metadata["toolsCapability"] == "unsupported")
        #expect(event.metadata["usageReportingCapability"] == "supported")
        #expect(event.metadata["cancellationCapability"] == "unsupported")
        #expect(event.metadata["capabilityFallbacks"] == "outputReservation:none")
    }

    @MainActor
    @Test func providerSelectionChangesEncodingButNotContextPolicy() throws {
        let runId = UUID()
        let agent = Agent(role: .coder, providerId: "test", model: "test")
        let attachment = RunContextAttachment(
            name: "policy.txt",
            content: "Equivalent provider-neutral evidence"
        )
        let builder = ContextBuilder()
        let commonInput = ContextBuildInput(
            runId: runId,
            agent: agent,
            providerId: "structured.provider",
            userMessage: "Inspect the evidence",
            contextAttachments: [attachment],
            tokenBudget: TokenBudget(maxInputTokens: 8_000, maxOutputTokens: 1_000),
            providerContextWindowTokens: 16_000,
            deliveryMode: .structuredMessages
        )
        let structured = try builder.buildSnapshot(from: commonInput)
        var renderedInput = commonInput
        renderedInput.providerId = "rendered.runtime"
        renderedInput.deliveryMode = .renderedPrompt
        let rendered = try builder.buildSnapshot(from: renderedInput)

        #expect(structured.contextItems == rendered.contextItems)
        #expect(structured.sections == rendered.sections)
        #expect(structured.omissions == rendered.omissions)
        #expect(structured.estimatedInputTokenCount == rendered.estimatedInputTokenCount)
        #expect(structured.windowConstraint == rendered.windowConstraint)
        #expect(structured.deliveryMode == .structuredMessages)
        #expect(rendered.deliveryMode == .renderedPrompt)
    }

    @MainActor
    @Test func providerAndRuntimeCapabilitiesUseTheSameBoundaryContract() {
        let providerPlan = ProviderCapabilities(
            supportsStreaming: true,
            supportsToolCalls: true,
            contextWindowTokens: 32_000,
            supportsUsageReporting: true,
            supportsCancellation: false
        ).contextDeliveryPlan(reservedOutputTokens: 2_000)
        let runtimePlan = AgentRuntimeDescriptor(
            id: "runtime",
            displayName: "Runtime",
            transport: .cli,
            contextDeliveryMode: .renderedPrompt,
            capabilities: AgentCapabilities([.canStreamTokens, .canUseTools]),
            contextWindowTokens: 32_000,
            supportsUsageReporting: true,
            supportsCancellation: false
        ).contextDeliveryPlan(reservedOutputTokens: 2_000)

        #expect(providerPlan.capabilities == runtimePlan.capabilities)
        #expect(providerPlan.mode == .structuredMessages)
        #expect(runtimePlan.mode == .renderedPrompt)
    }

    @MainActor
    @Test func legacyProviderCapabilitiesDecodeWithUnknownNewCapabilities() throws {
        let payload = Data("""
        {
          "supportsStreaming": true,
          "supportsToolCalls": false,
          "supportsFileEditing": false,
          "supportsShellExecution": false,
          "supportsVision": false,
          "supportsEmbeddings": false,
          "supportsReasoningMode": false,
          "supportsLocalExecution": true,
          "supportsApprovals": false,
          "supportsMCP": true,
          "supportedModels": ["legacy"]
        }
        """.utf8)

        let capabilities = try JSONDecoder().decode(
            ProviderCapabilities.self,
            from: payload
        )

        #expect(capabilities.supportsUsageReporting == nil)
        #expect(capabilities.supportsCancellation == nil)
        #expect(capabilities.contextDeliveryPlan(
            reservedOutputTokens: nil
        ).capabilities.usageReporting == .unknown)
    }

    @MainActor
    private func makeSnapshot(marker: String) -> ContextSnapshot {
        ContextSnapshot(
            runId: UUID(),
            providerId: ClaudeCLIRuntime.runtimeId,
            userMessage: "Inspect the supplied context",
            summary: "Summary containing \(marker)",
            contextItems: ["Attached context:\n\(marker)"],
            deliveryMode: .renderedPrompt,
            tokenCount: 4
        )
    }

    private func occurrenceCount(of needle: String, in haystack: String) -> Int {
        guard !needle.isEmpty else { return 0 }
        return haystack.components(separatedBy: needle).count - 1
    }

    @MainActor
    private func collect(
        _ stream: AsyncThrowingStream<AgentEvent, Error>
    ) async throws -> [AgentEvent] {
        var events: [AgentEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    @MainActor
    private func contextProviderService() -> ProviderService {
        ProviderService(
            registry: ProviderRegistry(providers: [ContextRecordingProvider()]),
            appSettingsService: InMemoryAppSettingsService()
        )
    }
}

@MainActor
private final class ContextDeliveryACPTransport: ACPTransport {
    private let connection: ContextDeliveryACPConnection

    init(connection: ContextDeliveryACPConnection) {
        self.connection = connection
    }

    func connect() async throws -> ACPConnection {
        connection
    }
}

@MainActor
private final class ContextDeliveryACPConnection: ACPConnection {
    private var continuations: [AsyncThrowingStream<ACPEvent, Error>.Continuation] = []
    private(set) var promptText: String?

    func send(_ message: ACPMessage) async throws {}

    func request(method: String, params: [String: Any]) async throws -> [String: Any] {
        switch method {
        case "initialize":
            return ["agentCapabilities": ["promptCapabilities": [:]]]
        case "session/new":
            return ["sessionId": "context-remote-session"]
        case "session/prompt":
            let blocks = params["prompt"] as? [[String: Any]]
            promptText = blocks?.first?["text"] as? String
            return ["stopReason": "completed"]
        default:
            return [:]
        }
    }

    func events() -> AsyncThrowingStream<ACPEvent, Error> {
        AsyncThrowingStream { continuation in
            continuations.append(continuation)
        }
    }

    func close() async {
        continuations.forEach { $0.finish() }
        continuations.removeAll()
    }
}

@MainActor
private final class ContextDeliveryCLITransport: CLIAgentProcessTransport {
    private let events: [CLIAgentProcessEvent]
    private(set) var configurations: [CLIAgentProcessConfiguration] = []

    init(events: [CLIAgentProcessEvent]) {
        self.events = events
    }

    func start(_ configuration: CLIAgentProcessConfiguration) throws -> CLIAgentProcessSession {
        configurations.append(configuration)
        let events = events
        return CLIAgentProcessSession(
            events: AsyncThrowingStream { continuation in
                events.forEach { continuation.yield($0) }
                continuation.finish()
            },
            writeHandler: { _ in },
            closeInputHandler: {},
            cancelHandler: {}
        )
    }
}

@MainActor
private final class ContextRecordingProvider: AIProvider {
    let id = "context.recording.provider"
    let displayName = "Context Recording Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        contextWindowTokens: 16_000,
        supportedModels: ["context-test"],
        supportsUsageReporting: true,
        supportsCancellation: false
    )
    private(set) var requests: [AIRequest] = []

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        requests.append(request)
        return AsyncThrowingStream { continuation in
            continuation.yield(.started)
            continuation.yield(.messageCompleted("Done"))
            continuation.yield(.finished)
            continuation.finish()
        }
    }
}
