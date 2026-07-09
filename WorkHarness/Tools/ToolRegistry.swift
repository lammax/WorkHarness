//
// ToolRegistry.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

@MainActor
final class ToolRegistry {
    private var toolsById: [String: any ToolProtocol]

    init(tools: [any ToolProtocol] = []) {
        self.toolsById = Dictionary(uniqueKeysWithValues: tools.map { ($0.id, $0) })
    }

    var availableTools: [ToolDefinition] {
        toolsById.values.map(\.definition).sorted { $0.displayName < $1.displayName }
    }

    func register(_ tool: any ToolProtocol) {
        toolsById[tool.id] = tool
    }

    func tool(id: String) throws -> any ToolProtocol {
        guard let tool = toolsById[id] else {
            throw ToolError.toolNotFound(id)
        }

        return tool
    }
}
