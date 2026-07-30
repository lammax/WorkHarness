//
// StandardAgentDefaults.swift
// WorkHarness
//
// Created by Auto (Codex) on 30.07.2026.
//

import Foundation

enum StandardAgentDefaults {
    static let inferenceConfigurationId = "inference"
    static let inferenceConfigurationName = "Inference"
    static let inferenceRoleIds: Set<UUID> = Set(inferenceRoles.map(\.id))

    static let inferenceRoles: [MultiAgentRoleConfiguration] = [
        MultiAgentRoleConfiguration(
            id: stableId("90000000-0000-0000-0000-000000000001"),
            role: .inputNormalizer,
            enabled: false,
            instructions: """
            Normalize the raw task without making the final execution decision.
            Return exactly one compact JSON object with these string fields:
            intent, scope, clarity, risk.
            Use only the enum values permitted by the output contract.
            Do not use Markdown fences, commentary, tools, or repository files.
            """,
            outputContract: AgentOutputContract(
                requiredKeys: ["intent", "scope", "clarity", "risk"],
                allowedValues: [
                    "intent": ["fix", "add", "refactor", "test", "document", "research", "secure", "unknown"],
                    "scope": ["code", "documentation", "tests", "mixed", "unknown"],
                    "clarity": ["clear", "ambiguous"],
                    "risk": ["low", "medium", "high"]
                ]
            )
        ),
        MultiAgentRoleConfiguration(
            id: stableId("90000000-0000-0000-0000-000000000002"),
            role: .decisionMaker,
            enabled: false,
            instructions: """
            Make the task-intake decision from the previous normalized JSON.
            Return exactly one compact JSON object with these string fields:
            category, profile, decision, reason_code.
            Use only the enum values permitted by the output contract.
            Do not use Markdown fences, commentary, tools, or repository files.
            """,
            outputContract: AgentOutputContract(
                requiredKeys: ["category", "profile", "decision", "reason_code"],
                allowedValues: [
                    "category": ["bug", "feature", "refactoring", "tests", "documentation", "research", "security"],
                    "profile": ["bug_fix", "research", "implementation", "testing"],
                    "decision": ["execute", "clarify", "manual_review"],
                    "reason_code": [
                        "standard",
                        "ambiguous_input",
                        "security_sensitive",
                        "destructive_action",
                        "insufficient_context"
                    ]
                ]
            )
        ),
        MultiAgentRoleConfiguration(
            id: stableId("90000000-0000-0000-0000-000000000003"),
            role: .resultFormatter,
            enabled: false,
            instructions: """
            Validate and canonicalize the previous decision without changing its meaning.
            Return exactly one compact JSON object with these string fields in this order:
            category, profile, decision, reason_code.
            Use only the enum values permitted by the output contract.
            Do not use Markdown fences, commentary, tools, or repository files.
            """,
            outputContract: AgentOutputContract(
                requiredKeys: ["category", "profile", "decision", "reason_code"],
                allowedValues: [
                    "category": ["bug", "feature", "refactoring", "tests", "documentation", "research", "security"],
                    "profile": ["bug_fix", "research", "implementation", "testing"],
                    "decision": ["execute", "clarify", "manual_review"],
                    "reason_code": [
                        "standard",
                        "ambiguous_input",
                        "security_sensitive",
                        "destructive_action",
                        "insufficient_context"
                    ]
                ]
            )
        )
    ]

    static func addingInferenceRoles(
        to configuration: MultiAgentRunConfiguration,
        preserving draft: MultiAgentRunConfiguration? = nil
    ) -> MultiAgentRunConfiguration {
        var configuration = configuration
        let draftById = Dictionary(uniqueKeysWithValues: (draft?.roles ?? []).map { ($0.id, $0) })
        for index in configuration.roles.indices {
            if let defaultRole = inferenceRoles.first(where: {
                $0.id == configuration.roles[index].id
            }) {
                configuration.roles[index].outputContract = defaultRole.outputContract
                if configuration.roles[index].instructions
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty {
                    configuration.roles[index].instructions = defaultRole.instructions
                }
            }
            guard let draftRole = draftById[configuration.roles[index].id] else {
                continue
            }
            configuration.roles[index].enabled = draftRole.enabled
            configuration.roles[index].modelOverride = draftRole.modelOverride
        }

        let existingIds = Set(configuration.roles.map(\.id))
        for defaultRole in inferenceRoles where !existingIds.contains(defaultRole.id) {
            var role = defaultRole
            if let draftRole = draftById[role.id] {
                role.enabled = draftRole.enabled
                role.modelOverride = draftRole.modelOverride
            }
            configuration.roles.append(role)
        }
        return configuration
    }

    static func isInferenceRole(id: UUID) -> Bool {
        inferenceRoleIds.contains(id)
    }

    private static func stableId(_ value: String) -> UUID {
        guard let id = UUID(uuidString: value) else {
            preconditionFailure("Invalid standard agent UUID: \(value)")
        }
        return id
    }
}
