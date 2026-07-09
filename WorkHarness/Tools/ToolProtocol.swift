//
// ToolProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
protocol ToolProtocol {
    var id: String { get }
    var displayName: String { get }
    var description: String { get }
    var permission: ToolPermission { get }
    var inputSchema: [ToolInputField] { get }

    func approvalRequirement(
        for arguments: [String: String],
        context: ToolExecutionContext
    ) -> ToolApprovalRequirement?
}

extension ToolProtocol {
    var definition: ToolDefinition {
        ToolDefinition(
            id: id,
            displayName: displayName,
            description: description,
            permission: permission,
            inputSchema: inputSchema,
            requiresApproval: permission.requiresDefaultApproval
        )
    }

    func approvalRequirement(
        for arguments: [String: String],
        context: ToolExecutionContext
    ) -> ToolApprovalRequirement? {
        guard permission.requiresDefaultApproval else { return nil }
        return ToolApprovalRequirement(
            title: "Approve \(displayName)",
            summary: description,
            mode: permission.safetyMode
        )
    }
}
