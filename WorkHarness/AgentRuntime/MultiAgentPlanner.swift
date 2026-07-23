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
    var role: AgentRole
    var agentId: UUID
    var requiredCapabilities: Set<AgentCapability>
    var dependsOn: [UUID]

    init(
        id: UUID = UUID(),
        role: AgentRole,
        agentId: UUID,
        requiredCapabilities: Set<AgentCapability>,
        dependsOn: [UUID] = []
    ) {
        self.id = id
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
    var enabled: Bool
    var modelOverride: String?
    var instructions: String

    init(id: UUID = UUID(), role: AgentRole, enabled: Bool = true, modelOverride: String? = nil, instructions: String = "") {
        self.id = id
        self.role = role
        self.enabled = enabled
        self.modelOverride = modelOverride
        self.instructions = instructions
    }
}

struct MultiAgentRunConfiguration: Codable, Equatable {
    var roles: [MultiAgentRoleConfiguration]

    static var `default`: MultiAgentRunConfiguration {
        MultiAgentRunConfiguration(roles: CapabilityBasedAgentPlanner.defaultRoles.map {
            MultiAgentRoleConfiguration(role: $0)
        })
    }

    func configuration(for role: AgentRole) -> MultiAgentRoleConfiguration? {
        roles.first { $0.role == role }
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
    static let defaultRoles: [AgentRole] = [.architect, .coder, .reviewer, .testRunner]

    private struct Requirement {
        let role: AgentRole
        let capabilities: Set<AgentCapability>
    }

    func plan(goal: String, candidates: [AgentCandidate]) throws -> AgentExecutionPlan {
        let requirements = [
            Requirement(role: .architect, capabilities: [.canPlan]),
            Requirement(role: .coder, capabilities: [.canEditFiles, .canUseTools]),
            Requirement(role: .reviewer, capabilities: [.canOpenDiff]),
            Requirement(role: .testRunner, capabilities: [.canRunTests])
        ]

        var steps: [AgentPlanStep] = []
        var previousStepID: UUID?
        var codingStepID: UUID?
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
            switch requirement.role {
            case .architect:
                dependencies = []
            case .coder:
                dependencies = previousStepID.map { [$0] } ?? []
            case .reviewer, .testRunner:
                dependencies = codingStepID.map { [$0] } ?? []
            default:
                dependencies = previousStepID.map { [$0] } ?? []
            }

            let step = AgentPlanStep(
                role: requirement.role,
                agentId: candidate.agent.id,
                requiredCapabilities: requirement.capabilities,
                dependsOn: dependencies
            )
            steps.append(step)
            previousStepID = step.id
            if requirement.role == .coder { codingStepID = step.id }
        }

        return AgentExecutionPlan(goal: goal, steps: steps)
    }

    func plan(goal: String, candidates: [AgentCandidate], configuration: MultiAgentRunConfiguration) throws -> AgentExecutionPlan {
        let fullPlan = try plan(goal: goal, candidates: candidates)
        let enabledRoles = Set(configuration.roles.filter(\.enabled).map(\.role))
        for step in fullPlan.steps where enabledRoles.contains(step.role) {
            for dependency in step.dependsOn {
                guard let dependencyStep = fullPlan.steps.first(where: { $0.id == dependency }),
                      enabledRoles.contains(dependencyStep.role) else {
                    let dependencyRole = fullPlan.steps.first(where: { $0.id == dependency })?.role ?? .architect
                    throw AgentPlannerError.disabledDependency(role: step.role, dependency: dependencyRole)
                }
            }
        }

        return AgentExecutionPlan(
            id: fullPlan.id,
            goal: fullPlan.goal,
            steps: fullPlan.steps.filter { enabledRoles.contains($0.role) }
        )
    }
}
