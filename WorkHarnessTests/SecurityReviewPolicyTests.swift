//
// SecurityReviewPolicyTests.swift
// WorkHarnessTests
//
// Created by Auto (Codex) on 08.08.2026.
//

import Foundation
import Testing
@testable import WorkHarness

struct SecurityReviewPolicyTests {
    private let policy = SecurityReviewPolicy()

    @Test func authorizationTokenInUserDefaultsBlocksCommit() throws {
        let decision = try policy.decision(from: #"{"verdict":"block","severity":"high","finding":"Authorization token stored in UserDefaults instead of Keychain","location":"TokenStore.swift:42","remediation":"Store the token with Keychain Services and remove plaintext persistence"}"#)

        #expect(decision.blocksCommit)
        #expect(decision.feedback.contains("TokenStore.swift:42"))
    }

    @Test func loggingAllRequestsBlocksOnPIIAndAuthorizationHeaders() throws {
        let decision = try policy.decision(from: #"{"verdict":"block","severity":"critical","finding":"Request logger records authorization headers and PII","location":"NetworkLogger.swift:18","remediation":"Allowlist safe metadata and redact credentials and personal data"}"#)

        #expect(decision.auditStatus == "blocked")
    }

    @Test func HTTPAPIRequestProducesNonBlockingHardeningWarning() throws {
        let decision = try policy.decision(from: #"{"verdict":"warning","severity":"medium","finding":"Certificate pinning is not configured for the sensitive API","location":"APIClient.swift:31","remediation":"Document the trust model and add pinning when the threat model requires it"}"#)

        #expect(!decision.blocksCommit)
        #expect(decision.auditStatus == "warning")
    }

    @MainActor
    @Test func coordinatorRegeneratesAndRetestsAfterHighFindingBeforeReviewer() async throws {
        let repository = InMemoryRunRepository()
        let recorder = RunRecorder(repository: repository)
        let run = Run(goal: "Store an authorization token", mode: .multiAgent)
        repository.insert(run)
        let outputs = [
            "implemented",
            "tests passed",
            #"{"verdict":"block","severity":"high","finding":"Token stored in UserDefaults","location":"TokenStore.swift:42","remediation":"Use Keychain"}"#,
            "fixed with Keychain",
            "tests passed again",
            #"{"verdict":"clean","severity":"none","finding":"none","location":"none","remediation":"none"}"#,
            "approved"
        ]
        let client = FakeACPClient(completedMessages: outputs)
        let runtime = ACPClientRuntime(client: client)
        let agent = Agent(role: .coder, providerId: "fake.acp", model: "fake")
        let candidate = AgentCandidate(agent: agent, capabilities: AgentCapabilities())
        let roleConfigurations = [
            MultiAgentRoleConfiguration(role: .coder),
            MultiAgentRoleConfiguration(role: .testRunner),
            MultiAgentRoleConfiguration(
                role: .securityReviewer,
                outputContract: SecurityReviewPolicy.outputContract
            ),
            MultiAgentRoleConfiguration(role: .reviewer)
        ]
        let configuration = MultiAgentRunConfiguration(
            profileId: "implementation",
            profileName: "Implementation",
            roles: roleConfigurations
        )
        var previousId: UUID?
        let steps = roleConfigurations.map { role in
            let step = AgentPlanStep(
                configurationId: role.id,
                role: role.role,
                agentId: agent.id,
                requiredCapabilities: [],
                dependsOn: previousId.map { [$0] } ?? []
            )
            previousId = step.id
            return step
        }

        let result = try await MultiAgentCoordinator(
            repository: repository,
            recorder: recorder
        ).execute(
            plan: AgentExecutionPlan(goal: run.goal, steps: steps),
            candidates: [candidate],
            runtimes: [agent.id: runtime],
            runId: run.id,
            configuration: configuration
        )

        let executedRoles: [AgentRole] = result.steps.map { $0.role }
        #expect(executedRoles == [
            .coder, .testRunner, .securityReviewer,
            .coder, .testRunner, .securityReviewer,
            .reviewer
        ])
        #expect(client.tasks[3].prompt.contains("Fix security finding"))
        let securityEvents = repository.run(withId: run.id)?.events.filter {
            $0.metadata["validationKind"] == "securityReview"
        } ?? []
        #expect(securityEvents.map { $0.metadata["status"] } == ["blocked", "passed"])
        #expect(securityEvents.allSatisfy {
            $0.metadata["gatewayProviderId"] == MCPProviderDescriptor.llmGateway.id
        })
    }
}
