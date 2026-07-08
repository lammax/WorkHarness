//
// CodexCLIProvider.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
struct CodexCLIProvider: AIProvider {
    static let providerId = "codex.cli"

    let id = CodexCLIProvider.providerId
    let displayName = "Codex CLI"
    let capabilities = ProviderCapabilities(
        supportsStreaming: true,
        supportsToolCalls: false,
        supportsFileEditing: true,
        supportsShellExecution: true,
        supportsLocalExecution: true,
        contextWindowTokens: nil,
        costModel: "codex-cli-account",
        supportsApprovals: true,
        supportsMCP: false,
        supportedModels: ["codex-cli"]
    )

    private let processRunner: ProcessRunnerProtocol
    private let executableURL: URL
    private let baseArguments: [String]
    private let timeout: TimeInterval?

    init(
        processRunner: ProcessRunnerProtocol,
        executableURL: URL = URL(fileURLWithPath: "/usr/bin/env"),
        baseArguments: [String] = ["codex"],
        timeout: TimeInterval? = nil
    ) {
        self.processRunner = processRunner
        self.executableURL = executableURL
        self.baseArguments = baseArguments
        self.timeout = timeout
    }

    func send(_ request: AIRequest) async throws -> AsyncThrowingStream<AIEvent, Error> {
        let session = try processRunner.start(ProcessRunRequest(
            executableURL: executableURL,
            arguments: arguments(for: request),
            workingDirectoryURL: workingDirectoryURL(for: request),
            timeout: timeout
        ))

        return AsyncThrowingStream { continuation in
            Task { @MainActor in
                var completedMessage = ""
                var stderrOutput = ""

                do {
                    for try await event in session.events {
                        switch event {
                        case .started:
                            continuation.yield(.started)
                        case .stdout(let output):
                            completedMessage += output
                            continuation.yield(.messageDelta(output))
                        case .stderr(let output):
                            stderrOutput += output
                        case .finished(let exit):
                            handleExit(exit, completedMessage: completedMessage, stderrOutput: stderrOutput, continuation: continuation)
                        }
                    }
                } catch {
                    continuation.yield(.error(error.localizedDescription))
                    continuation.finish()
                }
            }
        }
    }

    private func arguments(for request: AIRequest) -> [String] {
        baseArguments + promptArguments(for: request)
    }

    private func promptArguments(for request: AIRequest) -> [String] {
        let prompt = request.messages
            .map { "\($0.role.rawValue): \($0.content)" }
            .joined(separator: "\n\n")

        return ["exec", "--", prompt]
    }

    private func workingDirectoryURL(for request: AIRequest) -> URL? {
        guard let workingDirectory = request.workingDirectory, !workingDirectory.isEmpty else { return nil }
        return URL(fileURLWithPath: workingDirectory)
    }

    private func handleExit(
        _ exit: ProcessExit,
        completedMessage: String,
        stderrOutput: String,
        continuation: AsyncThrowingStream<AIEvent, Error>.Continuation
    ) {
        switch exit.status {
        case .succeeded:
            continuation.yield(.messageCompleted(completedMessage))
            continuation.yield(.finished)
        case .failed:
            continuation.yield(.error(errorMessage(prefix: "Codex CLI failed", stderrOutput: stderrOutput, exitCode: exit.exitCode)))
        case .cancelled:
            continuation.yield(.error("Codex CLI was cancelled."))
        case .timedOut:
            continuation.yield(.error("Codex CLI timed out."))
        }

        continuation.finish()
    }

    private func errorMessage(prefix: String, stderrOutput: String, exitCode: Int32?) -> String {
        let trimmedError = stderrOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let exitDescription = exitCode.map { " Exit code: \($0)." } ?? ""

        if trimmedError.isEmpty {
            return "\(prefix).\(exitDescription)"
        }

        return "\(prefix).\(exitDescription) \(trimmedError)"
    }
}
