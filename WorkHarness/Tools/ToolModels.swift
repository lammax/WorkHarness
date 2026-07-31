//
// ToolModels.swift
// WorkHarness
//
// Created by Auto (Codex) on 09.07.2026.
//

import Foundation

enum ToolPermission: String, Codable, CaseIterable, Equatable {
    case readOnly
    case workspaceWrite
    case shell
    case git
    case network
    case secrets
    case destructive

    var requiresDefaultApproval: Bool {
        switch self {
        case .readOnly:
            false
        case .workspaceWrite, .shell, .git, .network, .secrets, .destructive:
            true
        }
    }

    var safetyMode: SafetyMode {
        switch self {
        case .readOnly:
            .readOnly
        case .workspaceWrite, .git, .destructive:
            .askBeforeWrite
        case .shell, .network, .secrets:
            .askBeforeShell
        }
    }
}

struct ToolInputField: Codable, Equatable {
    var name: String
    var description: String
    var required: Bool
}

struct ToolApprovalRequirement: Codable, Equatable {
    var title: String
    var summary: String
    var mode: SafetyMode
}

struct ToolExecutionContext: Equatable {
    var runId: UUID
    var projectRootPath: String?

    init(runId: UUID, projectRootPath: String? = nil) {
        self.runId = runId
        self.projectRootPath = projectRootPath
    }
}

struct ToolExecutionRequest: Equatable {
    var id: UUID
    var runId: UUID
    var toolId: String
    var arguments: [String: String]
    var projectRootPath: String?
    var outputWindow: ToolOutputWindow?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        runId: UUID,
        toolId: String,
        arguments: [String: String] = [:],
        projectRootPath: String? = nil,
        outputWindow: ToolOutputWindow? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.runId = runId
        self.toolId = toolId
        self.arguments = arguments
        self.projectRootPath = projectRootPath
        self.outputWindow = outputWindow
        self.createdAt = createdAt
    }
}

struct ToolOutputWindow: Codable, Equatable {
    var offset: Int
    var limit: Int

    init(offset: Int = 0, limit: Int) {
        self.offset = max(0, offset)
        self.limit = max(1, limit)
    }
}

enum ToolExecutionStatus: String, Codable, Equatable {
    case succeeded
    case failed
    case approvalRequired
}

enum ToolResultStorage: String, Codable, Equatable {
    case inline
    case artifactReference
}

struct ToolResultRetention: Codable, Equatable {
    var storage: ToolResultStorage
    var originalCharacterCount: Int
    var retainedCharacterCount: Int
    var wasRedacted: Bool
    var artifactId: UUID?
    var policy: String

    init(
        storage: ToolResultStorage = .inline,
        originalCharacterCount: Int = 0,
        retainedCharacterCount: Int = 0,
        wasRedacted: Bool = false,
        artifactId: UUID? = nil,
        policy: String = "request"
    ) {
        self.storage = storage
        self.originalCharacterCount = originalCharacterCount
        self.retainedCharacterCount = retainedCharacterCount
        self.wasRedacted = wasRedacted
        self.artifactId = artifactId
        self.policy = policy
    }
}

struct ToolResult: Codable, Equatable {
    var toolId: String
    var status: ToolExecutionStatus
    var output: String
    var metadata: [String: String]
    var artifacts: [RunArtifact]
    var retention: ToolResultRetention

    init(
        toolId: String,
        status: ToolExecutionStatus,
        output: String,
        metadata: [String: String] = [:],
        artifacts: [RunArtifact] = [],
        retention: ToolResultRetention? = nil
    ) {
        self.toolId = toolId
        self.status = status
        self.output = output
        self.metadata = metadata
        self.artifacts = artifacts
        self.retention = retention ?? ToolResultRetention(
            originalCharacterCount: output.count,
            retainedCharacterCount: output.count
        )
    }

    private enum CodingKeys: String, CodingKey {
        case toolId
        case status
        case output
        case metadata
        case artifacts
        case retention
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolId = try container.decode(String.self, forKey: .toolId)
        status = try container.decode(ToolExecutionStatus.self, forKey: .status)
        output = try container.decode(String.self, forKey: .output)
        metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        artifacts = try container.decodeIfPresent([RunArtifact].self, forKey: .artifacts) ?? []
        retention = try container.decodeIfPresent(ToolResultRetention.self, forKey: .retention)
            ?? ToolResultRetention(
                originalCharacterCount: output.count,
                retainedCharacterCount: output.count
            )
    }
}

enum ToolError: LocalizedError, Equatable {
    case missingArgument(String)
    case missingProjectRoot
    case pathEscapesProjectRoot(String)
    case toolNotFound(String)
    case mcpAdapterNotConnected
    case mcpTransportNotConnected(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            "Missing required tool argument: \(name)"
        case .missingProjectRoot:
            "A project root is required for this tool."
        case .pathEscapesProjectRoot(let path):
            "Path escapes the project root: \(path)"
        case .toolNotFound(let toolId):
            "Tool was not found: \(toolId)"
        case .mcpAdapterNotConnected:
            "MCP tool adapter is not connected yet."
        case .mcpTransportNotConnected(let path):
            "MCP tool transport is not connected. Expected MCP server base: \(path)"
        }
    }
}
