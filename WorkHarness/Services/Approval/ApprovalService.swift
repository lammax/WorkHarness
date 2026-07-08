//
// ApprovalService.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
final class ApprovalService: ApprovalServiceProtocol {
    private let repository: ApprovalRepositoryProtocol
    private let runRepository: RunRepository
    private let recorder: RunRecorder

    init(repository: ApprovalRepositoryProtocol, runRepository: RunRepository, recorder: RunRecorder) {
        self.repository = repository
        self.runRepository = runRepository
        self.recorder = recorder
    }

    var requests: [ApprovalRequest] {
        repository.requests
    }

    var pendingRequests: [ApprovalRequest] {
        repository.requests.filter { $0.status == .pending }
    }

    @discardableResult
    func requestApproval(runId: UUID, title: String, summary: String, mode: SafetyMode) throws -> ApprovalRequest {
        let request = ApprovalRequest(runId: runId, title: title, summary: summary, mode: mode)
        repository.insert(request)
        runRepository.updateRun(runId) { run in
            run.status = .waitingForApproval
        }
        recorder.record(
            runId: runId,
            type: .approvalRequested,
            message: title,
            metadata: approvalMetadata(for: request)
        )
        return request
    }

    func approve(requestId: UUID) throws {
        try decide(requestId: requestId, status: .granted, eventType: .approvalGranted)
    }

    func reject(requestId: UUID) throws {
        try decide(requestId: requestId, status: .rejected, eventType: .approvalRejected)
    }

    private func decide(requestId: UUID, status: ApprovalStatus, eventType: RunEventType) throws {
        guard let request = repository.request(withId: requestId) else {
            throw ApprovalServiceError.requestNotFound(requestId)
        }

        guard request.status == .pending else {
            throw ApprovalServiceError.requestAlreadyDecided(requestId)
        }

        repository.updateRequest(requestId) { request in
            request.status = status
            request.decidedAt = Date()
        }

        let decidedRequest = repository.request(withId: requestId) ?? request
        runRepository.updateRun(request.runId) { run in
            run.status = status == .granted ? .running : .failed
        }
        recorder.record(
            runId: request.runId,
            type: eventType,
            message: decidedRequest.title,
            metadata: approvalMetadata(for: decidedRequest)
        )
    }

    private func approvalMetadata(for request: ApprovalRequest) -> [String: String] {
        [
            "approvalRequestId": request.id.uuidString,
            "status": request.status.rawValue,
            "safetyMode": request.mode.rawValue
        ]
    }
}
