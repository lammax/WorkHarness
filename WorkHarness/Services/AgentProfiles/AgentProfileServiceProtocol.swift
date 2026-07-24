//
// AgentProfileServiceProtocol.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

@MainActor
protocol AgentProfileServiceProtocol: BaseServiceProtocol {
    var profiles: [AgentWorkflowProfile] { get }
    var selectedProfileId: String { get }
    var selectedProfile: AgentWorkflowProfile? { get }
    var promptDirectoryPath: String? { get }

    func reload()
    func selectProfile(id: String)
    func configuration(for profileId: String?) -> MultiAgentRunConfiguration
    func prompt(for assistantId: UUID) -> String
    func promptFileURL(for assistantId: UUID) throws -> URL
    func setAssistantEnabled(id: UUID, enabled: Bool, profileId: String?) throws
    func setAssistantModelOverride(id: UUID, modelOverride: String?, profileId: String?) throws
    func moveAssistant(id: UUID, direction: AgentProfileMoveDirection) throws
    func replacePrompt(for assistantId: UUID, withContentsOf sourceURL: URL) throws
}

extension AgentProfileServiceProtocol {
    var service: AppService { .agentProfiles }
}

enum AgentProfileMoveDirection {
    case up
    case down
}

enum AgentProfileServiceError: LocalizedError, Equatable {
    case projectRootUnavailable
    case profileNotFound
    case assistantNotFound
    case invalidMarkdownFile
    case promptFileUnavailable

    var errorDescription: String? {
        switch self {
        case .projectRootUnavailable:
            "Select a project with a root folder before configuring agent profiles."
        case .profileNotFound:
            "The selected agent profile no longer exists."
        case .assistantNotFound:
            "The selected assistant no longer exists."
        case .invalidMarkdownFile:
            "The prompt must be a non-empty Markdown file."
        case .promptFileUnavailable:
            "The assistant prompt file is unavailable."
        }
    }
}
