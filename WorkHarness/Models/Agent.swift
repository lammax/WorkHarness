//
// Agent.swift
// WorkHarness
//
// Created by Auto (Codex) on 07.07.2026.
//

import Foundation

struct Agent: Identifiable, Codable, Equatable {
    let id: UUID
    var role: AgentRole
    var providerId: String
    var model: String
    var tools: [String]
    var permissions: AgentPermissions
    var systemPrompt: String
    var contextPolicy: ContextPolicy
    var memoryPolicy: MemoryPolicy
    var stopConditions: [String]
    var validationPolicy: ValidationPolicy

    init(
        id: UUID = UUID(),
        role: AgentRole,
        providerId: String,
        model: String,
        tools: [String] = [],
        permissions: AgentPermissions = AgentPermissions(),
        systemPrompt: String = "",
        contextPolicy: ContextPolicy = ContextPolicy(),
        memoryPolicy: MemoryPolicy = MemoryPolicy(),
        stopConditions: [String] = [],
        validationPolicy: ValidationPolicy = ValidationPolicy()
    ) {
        self.id = id
        self.role = role
        self.providerId = providerId
        self.model = model
        self.tools = tools
        self.permissions = permissions
        self.systemPrompt = systemPrompt
        self.contextPolicy = contextPolicy
        self.memoryPolicy = memoryPolicy
        self.stopConditions = stopConditions
        self.validationPolicy = validationPolicy
    }
}

enum AgentRole: String, Codable, CaseIterable, Equatable {
    case architect
    case coder
    case reviewer
    case testRunner
    case git
    case research
    case rag

    var label: String {
        switch self {
        case .architect: "Architect"
        case .coder: "Coder"
        case .reviewer: "Reviewer"
        case .testRunner: "Test Runner"
        case .git: "Git"
        case .research: "Research"
        case .rag: "RAG"
        }
    }
}

struct AgentPermissions: Codable, Equatable {
    var canReadFiles: Bool = true
    var canWriteFiles: Bool = false
    var canRunShell: Bool = false
    var canUseNetwork: Bool = false
    var requiresApproval: Bool = true
}

struct ContextPolicy: Codable, Equatable {
    var maxInputTokens: Int = 16_000
    var includeGitDiff: Bool = true
    var includeRecentRunSummary: Bool = true
    var includeMemoryFacts: Bool = true
}

struct MemoryPolicy: Codable, Equatable {
    var canReadMemory: Bool = true
    var canWriteMemory: Bool = false
}

struct ValidationPolicy: Codable, Equatable {
    var requireBuild: Bool = false
    var requireTests: Bool = false
    var requireReview: Bool = false
}
