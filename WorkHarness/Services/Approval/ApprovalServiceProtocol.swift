//
// ApprovalServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation

@MainActor
protocol ApprovalServiceProtocol: BaseServiceProtocol {
    var requests: [ApprovalRequest] { get }
    var pendingRequests: [ApprovalRequest] { get }

    @discardableResult
    func requestApproval(runId: UUID, title: String, summary: String, mode: SafetyMode) throws -> ApprovalRequest
    func approve(requestId: UUID) throws
    func reject(requestId: UUID) throws
}

extension ApprovalServiceProtocol {
    var service: AppService { .approvals }
}
