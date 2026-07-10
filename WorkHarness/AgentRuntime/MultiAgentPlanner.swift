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

enum AgentPlannerError: LocalizedError, Equatable {
    case noCandidate(role: AgentRole, requiredCapabilities: Set<AgentCapability>)

    var errorDescription: String? {
        switch self {
        case .noCandidate(let role, let capabilities):
            let names = capabilities.map(\.rawValue).sorted().joined(separator: ", ")
            return "No agent can perform \(role.label). Required capabilities: \(names)."
        }
    }
}

protocol AgentPlannerProtocol {
    func plan(goal: String, candidates: [AgentCandidate]) throws -> AgentExecutionPlan
}

struct CapabilityBasedAgentPlanner: AgentPlannerProtocol {
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
        for requirement in requirements {
            guard let candidate = candidates.first(where: { candidate in
                requirement.capabilities.isSubset(of: candidate.capabilities.values)
            }) else {
                throw AgentPlannerError.noCandidate(
                    role: requirement.role,
                    requiredCapabilities: requirement.capabilities
                )
            }

            steps.append(AgentPlanStep(
                role: requirement.role,
                agentId: candidate.agent.id,
                requiredCapabilities: requirement.capabilities,
                dependsOn: steps.last.map { [$0.id] } ?? []
            ))
        }

        return AgentExecutionPlan(goal: goal, steps: steps)
    }
}
