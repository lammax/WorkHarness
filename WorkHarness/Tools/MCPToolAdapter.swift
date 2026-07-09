//
// MCPToolAdapter.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
struct MCPToolAdapter: ToolProtocol {
    let id = "mcp.invoke"
    let displayName = "Invoke MCP Tool"
    let description = "Placeholder adapter for external MCP-provided tools."
    let permission: ToolPermission = .network
    let inputSchema = [
        ToolInputField(name: "serverId", description: "MCP server identifier.", required: true),
        ToolInputField(name: "toolName", description: "MCP tool name.", required: true)
    ]

    func approvalRequirement(
        for arguments: [String: String],
        context: ToolExecutionContext
    ) -> ToolApprovalRequirement? {
        ToolApprovalRequirement(
            title: "Approve MCP tool",
            summary: "Invoke \(arguments["toolName"] ?? "an MCP tool").",
            mode: .askBeforeShell
        )
    }
}
