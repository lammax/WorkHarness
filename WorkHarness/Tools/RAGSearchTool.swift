//
// RAGSearchTool.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

@MainActor
struct RAGSearchTool: ToolProtocol {
    let id = "rag.search"
    let displayName = "Search Project Knowledge"
    let description = "Search the MCP-backed RAG index and return citations."
    let permission: ToolPermission = .readOnly
    let inputSchema = [
        ToolInputField(name: "question", description: "Question to retrieve relevant project knowledge for.", required: true)
    ]
}
