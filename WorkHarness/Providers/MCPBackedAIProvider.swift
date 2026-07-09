//
// MCPBackedAIProvider.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
struct MCPBackedAIProvider: AIProvider {
    let id: String
    let displayName: String
    let capabilities: ProviderCapabilities

    private let descriptor: MCPProviderDescriptor
    private let client: MCPProviderClientProtocol

    init(descriptor: MCPProviderDescriptor, client: MCPProviderClientProtocol) {
        self.descriptor = descriptor
        self.client = client
        id = descriptor.id
        displayName = descriptor.displayName
        capabilities = descriptor.capabilities
    }

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        let mcpStream = try await client.streamEvents(for: MCPProviderRequest(
            providerId: descriptor.id,
            aiRequest: request
        ))

        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                do {
                    for try await event in mcpStream {
                        continuation.yield(map(event))

                        if case .finished = event {
                            continuation.finish()
                        } else if case .failed = event {
                            continuation.finish()
                        }
                    }
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    private func map(_ event: MCPProviderEvent) -> AIEvent {
        switch event {
        case .started:
            .started
        case .messageDelta(let delta):
            .messageDelta(delta)
        case .messageCompleted(let message):
            .messageCompleted(message)
        case .tokenUsage(let usage):
            .tokenUsage(usage)
        case .finished:
            .finished
        case .failed(let message):
            .error(message)
        }
    }
}
