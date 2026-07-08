//
// ApprovalRepository.swift
// WorkHarness
//
// Created by Auto (Codex) on 08.07.2026.
//

import Foundation
import Observation

@MainActor
protocol ApprovalRepositoryProtocol: BaseRepositoryProtocol {
    var requests: [ApprovalRequest] { get }

    func insert(_ request: ApprovalRequest)
    func updateRequest(_ requestId: UUID, mutation: (inout ApprovalRequest) -> Void)
    func request(withId requestId: UUID) -> ApprovalRequest?
}

extension ApprovalRepositoryProtocol {
    var repository: AppRepository { .approvals }
}

@MainActor
@Observable
final class InMemoryApprovalRepository: ApprovalRepositoryProtocol {
    private(set) var requests: [ApprovalRequest] = []

    func insert(_ request: ApprovalRequest) {
        requests.insert(request, at: 0)
    }

    func updateRequest(_ requestId: UUID, mutation: (inout ApprovalRequest) -> Void) {
        guard let index = requests.firstIndex(where: { $0.id == requestId }) else { return }
        mutation(&requests[index])
    }

    func request(withId requestId: UUID) -> ApprovalRequest? {
        requests.first { $0.id == requestId }
    }
}
