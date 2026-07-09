//
// ShellTool.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
struct ShellTool: ToolProtocol {
    let id = "shell.run"
    let displayName = "Run Shell Command"
    let description = "Runs a shell command inside the current project root."
    let permission: ToolPermission = .shell
    let inputSchema = [
        ToolInputField(name: "command", description: "Shell command to execute.", required: true)
    ]

    func approvalRequirement(
        for arguments: [String: String],
        context: ToolExecutionContext
    ) -> ToolApprovalRequirement? {
        ToolApprovalRequirement(
            title: "Approve shell command",
            summary: arguments["command"] ?? "Run shell command.",
            mode: .askBeforeShell
        )
    }
}
