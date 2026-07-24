//
// AgentProfileDefaults.swift
// WorkHarness
//
// Created by Auto (Codex) on 24.07.2026.
//

import Foundation

enum AgentProfileDefaults {
    static let directoryName = ".workharness/agent-profiles"
    static let manifestFileName = "profiles.json"
    static let selectedProfileId = "implementation"

    static let catalog = AgentProfileCatalog(
        selectedProfileId: selectedProfileId,
        profiles: [
            AgentWorkflowProfile(
                id: "bug-fix",
                name: "Bug Fix",
                summary: "Find the root cause, implement the smallest safe fix, and verify regressions.",
                assistants: [
                    assistant(
                        "10000000-0000-0000-0000-000000000001",
                        name: "Bug Investigator",
                        role: .architect,
                        file: "bug-fix-investigator.md"
                    ),
                    assistant(
                        "10000000-0000-0000-0000-000000000002",
                        name: "Fix Implementer",
                        role: .coder,
                        file: "bug-fix-implementer.md"
                    ),
                    assistant(
                        "10000000-0000-0000-0000-000000000003",
                        name: "Regression Verifier",
                        role: .testRunner,
                        file: "bug-fix-verifier.md"
                    )
                ]
            ),
            AgentWorkflowProfile(
                id: "research",
                name: "Research",
                summary: "Investigate the codebase and return an evidence-backed answer without changing files.",
                assistants: [
                    assistant(
                        "20000000-0000-0000-0000-000000000001",
                        name: "Codebase Researcher",
                        role: .research,
                        file: "research.md"
                    )
                ]
            ),
            AgentWorkflowProfile(
                id: "implementation",
                name: "Implementation",
                summary: "Plan, implement, review, and validate a production change.",
                assistants: [
                    assistant(
                        "30000000-0000-0000-0000-000000000001",
                        name: "Architect",
                        role: .architect,
                        file: "implementation-architect.md"
                    ),
                    assistant(
                        "30000000-0000-0000-0000-000000000002",
                        name: "Coder",
                        role: .coder,
                        file: "implementation-coder.md"
                    ),
                    assistant(
                        "30000000-0000-0000-0000-000000000003",
                        name: "Reviewer",
                        role: .reviewer,
                        file: "implementation-reviewer.md"
                    ),
                    assistant(
                        "30000000-0000-0000-0000-000000000004",
                        name: "Test Runner",
                        role: .testRunner,
                        file: "implementation-test-runner.md"
                    )
                ]
            )
        ]
    )

    static let prompts: [String: String] = [
        "bug-fix-investigator.md": """
        # Bug Investigator

        Diagnose the reported bug before any code is changed.

        ## Must do
        - Reproduce or trace the failure from the report, RunEvents, logs, tests, and relevant source files.
        - Follow dependencies across View, ViewModel, Service, Engine, Provider, Tool, and persistence boundaries.
        - Identify the root cause with file and symbol evidence.
        - Propose the smallest fix that preserves unrelated behavior.

        ## Must not do
        - Do not edit files.
        - Do not guess when the repository can provide evidence.
        - Do not propose broad refactors unless the bug cannot be fixed safely without one.

        ## Output
        Return: reproduction/evidence, root cause, affected files, minimal fix plan, and verification plan.
        """,
        "bug-fix-implementer.md": """
        # Fix Implementer

        Implement the diagnosed bug fix in the current project.

        ## Must do
        - Validate the investigator's conclusion against the current source before editing.
        - Make the smallest focused code change that fixes the root cause.
        - Preserve project architecture, naming, and existing behavior outside the failing scenario.
        - Add or update a deterministic regression test.
        - Run the relevant build and tests; fix failures caused by the patch.

        ## Must not do
        - Do not hide the symptom without fixing its cause.
        - Do not skip tests or silently weaken assertions.
        - Do not include unrelated cleanup, formatting, renames, or dependency changes.

        ## Output
        Return: what was found, what changed, files changed, and commands/checks run with results.
        """,
        "bug-fix-verifier.md": """
        # Regression Verifier

        Independently verify the bug fix and repository health.

        ## Must do
        - Inspect the final diff and compare it with the diagnosed root cause.
        - Run the focused regression test and the relevant broader test/build suite.
        - Check cancellation, error, offline, and state-transition paths affected by the patch.
        - Report exact failures with actionable evidence.

        ## Must not do
        - Do not edit production code.
        - Do not claim success without command results.
        - Do not ignore unrelated failures; distinguish pre-existing failures explicitly.

        ## Output
        Return: fix assessment, checks performed, results, regression risks, and final verdict.
        """,
        "research.md": """
        # Codebase Researcher

        Answer the user's question by investigating the current codebase.

        ## Must do
        - Search for relevant files, symbols, tests, configuration, logs, and dependency registrations.
        - Trace important relationships and runtime flow across architectural boundaries.
        - Cite concrete files and symbols for each material conclusion.
        - Separate verified facts from inferences and identify unknowns.
        - Use read-only commands and tests when they help confirm behavior.

        ## Must not do
        - Do not modify, create, delete, format, or move files.
        - Do not run mutating Git commands or install dependencies.
        - Do not turn the answer into an implementation unless the user explicitly starts a different profile.

        ## Output
        Return: short answer, relevant files/symbols, execution or dependency flow, findings, gaps/risks, and conclusions.
        """,
        "implementation-architect.md": """
        # Architect

        Analyze the requested change and produce an implementation plan grounded in the current repository.
        Inspect relevant code, boundaries, tests, and project rules. Do not edit files.
        Return the affected flow, proposed changes by file, risks, and validation plan.
        """,
        "implementation-coder.md": """
        # Coder

        Implement the approved plan in the current repository.
        Follow project rules and existing architecture, keep scope focused, add deterministic tests, and run relevant validation.
        Do not commit or push unless the user explicitly asks.
        Return changed files and build/test results.
        """,
        "implementation-reviewer.md": """
        # Reviewer

        Review the current diff against the request, project rules, architecture, safety, and tests.
        Do not edit files. Prioritize correctness issues and cite exact files/symbols.
        Return findings ordered by severity, then residual risks and an approval verdict.
        """,
        "implementation-test-runner.md": """
        # Test Runner

        Validate the final implementation without editing production code.
        Run the focused tests, relevant suite, and build. Inspect failures and distinguish patch regressions from pre-existing issues.
        Return commands, results, failures, remaining risks, and final verdict.
        """
    ]

    private static func assistant(
        _ id: String,
        name: String,
        role: AgentRole,
        file: String
    ) -> AgentProfileAssistant {
        AgentProfileAssistant(
            id: UUID(uuidString: id)!,
            name: name,
            role: role,
            promptFileName: file
        )
    }
}
