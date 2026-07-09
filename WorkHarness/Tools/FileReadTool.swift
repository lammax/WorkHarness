//
// FileReadTool.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
struct FileReadTool: ToolProtocol {
    let id = "file.read"
    let displayName = "Read File"
    let description = "Reads a UTF-8 file inside the current project."
    let permission: ToolPermission = .readOnly
    let inputSchema = [
        ToolInputField(name: "path", description: "Relative file path inside the project root.", required: true)
    ]
}
