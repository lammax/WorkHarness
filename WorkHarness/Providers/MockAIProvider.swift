//
// MockAIProvider.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

struct MockAIProvider: AIProvider {
    static let providerId = "mock.local"

    let id = MockAIProvider.providerId
    let displayName = "Mock Local Provider"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsToolCalls: false,
        supportsVision: false,
        supportsLocalExecution: true,
        contextWindowTokens: 8_000,
        costModel: "free-local-mock",
        supportedModels: ["mock-harness-v1"]
    )

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                continuation.yield(.started)

                let prompt = request.messages.last(where: { $0.role == .user })?.content ?? ""
                let response = "Run created for: \(prompt)\n\nI am the mock provider. The harness can now record user and assistant events without binding the UI to a real backend."
                let chunks = response.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
                var assembled = ""

                for chunk in chunks {
                    try? await Task.sleep(for: .milliseconds(35))
                    let token = assembled.isEmpty ? chunk : " \(chunk)"
                    assembled += token
                    continuation.yield(.messageDelta(token))
                }

                continuation.yield(.messageCompleted(assembled))
                continuation.yield(.tokenUsage(TokenUsage(inputTokens: prompt.count / 4, outputTokens: assembled.count / 4)))
                continuation.yield(.finished)
                continuation.finish()
            }
        }
    }
}
