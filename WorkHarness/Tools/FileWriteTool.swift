//
// FileWriteTool.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
struct FileWriteTool: ToolProtocol {
    let id = "file.write"
    let displayName = "Write File"
    let description = "Writes UTF-8 content to a file inside the current project."
    let permission: ToolPermission = .workspaceWrite
    let inputSchema = [
        ToolInputField(name: "path", description: "Relative file path inside the project root.", required: true),
        ToolInputField(name: "content", description: "UTF-8 content to write.", required: true)
    ]

    func approvalRequirement(
        for arguments: [String: String],
        context: ToolExecutionContext
    ) -> ToolApprovalRequirement? {
        ToolApprovalRequirement(
            title: "Approve file write",
            summary: "Write to \(arguments["path"] ?? "a project file").",
            mode: .askBeforeWrite
        )
    }
}
