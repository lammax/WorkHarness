//
// ProcessRunner.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
final class ProcessRunner: ProcessRunnerProtocol {
    func start(_ request: ProcessRunRequest) throws -> ProcessRunSession {
        try validate(request)

        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.environment = request.environment
        process.currentDirectoryURL = request.workingDirectoryURL
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        var didFinish = false
        var timeoutTask: Task<Void, Never>?
        var continuationRef: AsyncThrowingStream<ProcessRunEvent, Error>.Continuation?

        func finish(status: ProcessExitStatus, exitCode: Int32?) {
            guard !didFinish else { return }
            didFinish = true
            timeoutTask?.cancel()
            stdoutPipe.fileHandleForReading.readabilityHandler = nil
            stderrPipe.fileHandleForReading.readabilityHandler = nil
            continuationRef?.yield(.finished(ProcessExit(status: status, exitCode: exitCode)))
            continuationRef?.finish()
        }

        let events = AsyncThrowingStream<ProcessRunEvent, Error> { continuation in
            continuationRef = continuation

            stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
                continuation.yield(.stdout(output))
            }

            stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8), !output.isEmpty else { return }
                continuation.yield(.stderr(output))
            }

            process.terminationHandler = { process in
                Task { @MainActor in
                    let status: ProcessExitStatus = process.terminationStatus == 0 ? .succeeded : .failed
                    finish(status: status, exitCode: process.terminationStatus)
                }
            }

            continuation.onTermination = { _ in
                Task { @MainActor in
                    guard !didFinish, process.isRunning else { return }
                    process.terminate()
                }
            }

            do {
                try process.run()
            } catch {
                continuation.finish(throwing: ProcessRunnerError.launchFailed(error.localizedDescription))
                return
            }

            continuation.yield(.started(ProcessStart(
                processIdentifier: process.processIdentifier,
                executablePath: request.executableURL.path,
                arguments: request.arguments
            )))

            if let timeout = request.timeout {
                timeoutTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    guard !Task.isCancelled, !didFinish else { return }

                    if process.isRunning {
                        process.terminate()
                    }
                    finish(status: .timedOut, exitCode: nil)
                }
            }
        }

        return ProcessRunSession(events: events) {
            guard !didFinish else { return }

            if process.isRunning {
                process.terminate()
            }
            finish(status: .cancelled, exitCode: nil)
        }
    }

    private func validate(_ request: ProcessRunRequest) throws {
        if let timeout = request.timeout, timeout <= 0 {
            throw ProcessRunnerError.invalidTimeout(timeout)
        }

        guard FileManager.default.isExecutableFile(atPath: request.executableURL.path) else {
            throw ProcessRunnerError.executableNotFound(request.executableURL.path)
        }
    }
}
