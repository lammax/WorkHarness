//
// AgentWorkflowProfile.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

struct AgentWorkflowProfile: Identifiable, Codable, Equatable {
    var id: String
    var name: String
    var summary: String
    var assistants: [AgentProfileAssistant]
}

struct AgentProfileAssistant: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var role: AgentRole
    var promptFileName: String
    var enabled: Bool
    var modelOverride: String?

    init(
        id: UUID = UUID(),
        name: String,
        role: AgentRole,
        promptFileName: String,
        enabled: Bool = true,
        modelOverride: String? = nil
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.promptFileName = promptFileName
        self.enabled = enabled
        self.modelOverride = modelOverride
    }
}

struct AgentProfileCatalog: Codable, Equatable {
    var selectedProfileId: String
    var profiles: [AgentWorkflowProfile]
}
