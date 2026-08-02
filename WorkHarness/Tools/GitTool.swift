//
// GitTool.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
struct GitTool: ToolProtocol {
    let id = "git.run"
    let displayName = "Run Git"
    let description = "Runs git commands inside the current project root."
    let permission: ToolPermission = .git
    let inputSchema = [
        ToolInputField(name: "arguments", description: "Git arguments separated by spaces.", required: true)
    ]

    func approvalRequirement(
        for arguments: [String: String],
        context: ToolExecutionContext
    ) -> ToolApprovalRequirement? {
        let parsedArguments = parseArguments(arguments["arguments"] ?? "")
        guard requiresApproval(for: parsedArguments) else { return nil }

        return ToolApprovalRequirement(
            title: "Approve git command",
            summary: "git \(parsedArguments.joined(separator: " "))",
            mode: .askBeforeWrite
        )
    }

    private func requiresApproval(for arguments: [String]) -> Bool {
        guard let command = arguments.first else { return true }
        let joined = arguments.joined(separator: " ")

        if command == "push" || command == "commit" || command == "merge" || command == "rebase" {
            return true
        }

        if command == "reset" && joined.contains("--hard") {
            return true
        }

        if command == "clean" || command == "checkout" || command == "switch" || command == "restore" {
            return true
        }

        return false
    }

    private func parseArguments(_ rawArguments: String) -> [String] {
        rawArguments
            .split(separator: " ")
            .map(String.init)
    }
}
