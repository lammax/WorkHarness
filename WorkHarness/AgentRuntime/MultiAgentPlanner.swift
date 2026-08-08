//
// MultiAgentPlanner.swift
// WorkHarness
//
// Created by Auto (Codex) on 10.07.2026.
//

import Foundation

struct AgentCandidate: Identifiable, Codable, Equatable {
    let id: UUID
    var agent: Agent
    var capabilities: AgentCapabilities

    init(id: UUID = UUID(), agent: Agent, capabilities: AgentCapabilities) {
        self.id = id
        self.agent = agent
        self.capabilities = capabilities
    }
}

struct AgentPlanStep: Identifiable, Codable, Equatable {
    let id: UUID
    var configurationId: UUID?
    var role: AgentRole
    var agentId: UUID
    var requiredCapabilities: Set<AgentCapability>
    var dependsOn: [UUID]

    init(
        id: UUID = UUID(),
        configurationId: UUID? = nil,
        role: AgentRole,
        agentId: UUID,
        requiredCapabilities: Set<AgentCapability>,
        dependsOn: [UUID] = []
    ) {
        self.id = id
        self.configurationId = configurationId
        self.role = role
        self.agentId = agentId
        self.requiredCapabilities = requiredCapabilities
        self.dependsOn = dependsOn
    }
}

struct AgentExecutionPlan: Identifiable, Codable, Equatable {
    let id: UUID
    var goal: String
    var steps: [AgentPlanStep]

    init(id: UUID = UUID(), goal: String, steps: [AgentPlanStep]) {
        self.id = id
        self.goal = goal
        self.steps = steps
    }
}

struct MultiAgentRoleConfiguration: Identifiable, Codable, Equatable {
    let id: UUID
    var role: AgentRole
    var assistantName: String
    var promptFilePath: String
    var enabled: Bool
    var modelOverride: String?
    var instructions: String
    var outputContract: AgentOutputContract?

    init(
        id: UUID = UUID(),
        role: AgentRole,
        assistantName: String? = nil,
        promptFilePath: String = "",
        enabled: Bool = true,
        modelOverride: String? = nil,
        instructions: String = "",
        outputContract: AgentOutputContract? = nil
    ) {
        self.id = id
        self.role = role
        self.assistantName = assistantName ?? role.label
        self.promptFilePath = promptFilePath
        self.enabled = enabled
        self.modelOverride = modelOverride
        self.instructions = instructions
        self.outputContract = outputContract
    }
}

struct MultiAgentRunConfiguration: Codable, Equatable {
    var profileId: String?
    var profileName: String?
    var roles: [MultiAgentRoleConfiguration]

    init(
        profileId: String? = nil,
        profileName: String? = nil,
        roles: [MultiAgentRoleConfiguration]
    ) {
        self.profileId = profileId
        self.profileName = profileName
        self.roles = roles
    }

    static var `default`: MultiAgentRunConfiguration {
        MultiAgentRunConfiguration(profileId: nil, profileName: nil, roles: CapabilityBasedAgentPlanner.defaultRoles.map {
            MultiAgentRoleConfiguration(role: $0)
        })
    }

    func configuration(for role: AgentRole) -> MultiAgentRoleConfiguration? {
        roles.first { $0.role == role }
    }

    func configuration(for step: AgentPlanStep) -> MultiAgentRoleConfiguration? {
        if let configurationId = step.configurationId,
           let configuration = roles.first(where: { $0.id == configurationId }) {
            return configuration
        }
        return configuration(for: step.role)
    }
}

enum AgentPlannerError: LocalizedError, Equatable {
    case noCandidate(role: AgentRole, requiredCapabilities: Set<AgentCapability>)
    case disabledDependency(role: AgentRole, dependency: AgentRole)

    var errorDescription: String? {
        switch self {
        case .noCandidate(let role, let capabilities):
            let names = capabilities.map(\.rawValue).sorted().joined(separator: ", ")
            return "No agent can perform \(role.label). Required capabilities: \(names)."
        case .disabledDependency(let role, let dependency):
            return "\(role.label) requires \(dependency.label) to remain enabled."
        }
    }
}

protocol AgentPlannerProtocol {
    func plan(goal: String, candidates: [AgentCandidate]) throws -> AgentExecutionPlan
}

struct CapabilityBasedAgentPlanner: AgentPlannerProtocol {
    static let defaultRoles: [AgentRole] = [.architect, .coder, .testRunner, .securityReviewer, .reviewer]

    private struct Requirement {
        let role: AgentRole
        let capabilities: Set<AgentCapability>
    }

    func plan(goal: String, candidates: [AgentCandidate]) throws -> AgentExecutionPlan {
        let requirements = [
            Requirement(role: .architect, capabilities: [.canPlan]),
            Requirement(role: .coder, capabilities: [.canEditFiles, .canUseTools]),
            Requirement(role: .testRunner, capabilities: [.canRunTests]),
            Requirement(role: .securityReviewer, capabilities: [.canOpenDiff]),
            Requirement(role: .reviewer, capabilities: [.canOpenDiff])
        ]

        var steps: [AgentPlanStep] = []
        var previousStepID: UUID?
        for requirement in requirements {
            guard let candidate = candidates.first(where: { candidate in
                requirement.capabilities.isSubset(of: candidate.capabilities.values)
            }) else {
                throw AgentPlannerError.noCandidate(
                    role: requirement.role,
                    requiredCapabilities: requirement.capabilities
                )
            }

            let dependencies: [UUID]
            dependencies = previousStepID.map { [$0] } ?? []

            let step = AgentPlanStep(
                role: requirement.role,
                agentId: candidate.agent.id,
                requiredCapabilities: requirement.capabilities,
                dependsOn: dependencies
            )
            steps.append(step)
            previousStepID = step.id
        }

        return AgentExecutionPlan(goal: goal, steps: steps)
    }

    func plan(goal: String, candidates: [AgentCandidate], configuration: MultiAgentRunConfiguration) throws -> AgentExecutionPlan {
        var steps: [AgentPlanStep] = []
        var previousStepId: UUID?

        for roleConfiguration in configuration.roles where roleConfiguration.enabled {
            let capabilities = requiredCapabilities(for: roleConfiguration.role)
            guard let candidate = candidates.first(where: {
                capabilities.isSubset(of: $0.capabilities.values)
            }) else {
                throw AgentPlannerError.noCandidate(
                    role: roleConfiguration.role,
                    requiredCapabilities: capabilities
                )
            }

            let step = AgentPlanStep(
                configurationId: roleConfiguration.id,
                role: roleConfiguration.role,
                agentId: candidate.agent.id,
                requiredCapabilities: capabilities,
                dependsOn: previousStepId.map { [$0] } ?? []
            )
            steps.append(step)
            previousStepId = step.id
        }

        return AgentExecutionPlan(goal: goal, steps: steps)
    }

    private func requiredCapabilities(for role: AgentRole) -> Set<AgentCapability> {
        switch role {
        case .architect:
            [.canPlan]
        case .coder:
            [.canEditFiles, .canUseTools]
        case .reviewer:
            [.canOpenDiff]
        case .securityReviewer:
            [.canOpenDiff]
        case .testRunner:
            [.canRunTests]
        case .inputNormalizer, .decisionMaker, .resultFormatter:
            []
        case .git:
            [.canUseTools]
        case .research, .rag:
            [.canUseTools]
        }
    }
}
