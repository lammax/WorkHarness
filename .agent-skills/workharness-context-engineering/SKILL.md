---
name: workharness-context-engineering
description: Mandatory additional context-engineering rules for WorkHarness. Apply together with the existing WorkHarness architecture and development skills whenever work affects agent loops, ContextBuilder, prompts, provider requests, message history, tools, MCP/ACP adapters, retrieval, memory, ContextSnapshot, Run/RunEvent persistence, compaction, long-running runs, subagents, or token and cost budgets.
---

# WorkHarness Context Engineering

This is an additional mandatory skill. It extends the existing WorkHarness
architecture and development skills; it does not replace them.

Apply it equally when WorkHarness is developed or operated through Codex,
Claude Code, Cursor, another CLI agent, or a network provider.

If this skill conflicts with a convenience-oriented implementation choice,
follow this skill. If it conflicts with an explicit security or safety rule,
follow the stricter rule.

## Objective

Treat model context as a finite attention budget. Build the smallest
high-signal context that is sufficient for the agent's current decision.

Do not optimize for filling the provider's maximum context window. More tokens
can reduce focus, retrieval accuracy, predictability, speed, and cost
efficiency.

## Preserve WorkHarness architecture

Keep the dependency direction:

`View → ViewModel → Service → Engine/Repository/Provider`

Mandatory boundaries:

- UI code must not assemble prompts or context.
- UI code must not retrieve memory or invoke tools, providers, repositories, or
  the Engine directly.
- Provider-specific context limits and message formats must remain behind
  abstractions.
- Context construction must be deterministic and independently testable.
- Context policy must not be duplicated across UI, providers, CLI adapters, and
  remote clients.
- Prefer a focused addition to the current architecture over a new subsystem.

## Classify information before adding it

Classify every candidate context item:

1. **Required now** — include directly because the current decision depends on
   it.
2. **Retrievable later** — retain a lightweight typed reference and load it
   just in time.
3. **Persistent state** — store outside the context as structured project,
   agent, or run state.
4. **Discardable** — omit it or clear it after the relevant result has been
   consumed.

Every included item must have:

- a purpose;
- a source or provenance;
- a priority;
- a freshness signal when staleness matters;
- an estimated or measured token cost;
- a retention policy.

## Build context deliberately

The context-building workflow must:

1. State the current agent objective.
2. Select the minimal applicable instructions.
3. Select only evidence required for the current step.
4. Use stable ordering and explicit sections.
5. Apply a token budget and explicit overflow priorities.
6. Expose omissions, truncation, and compaction to the Engine.
7. Produce metadata suitable for observability and cost accounting.

Use clear sections such as:

- objective;
- applicable instructions;
- current state and constraints;
- selected evidence;
- available tools;
- required output.

Keep system instructions minimal but sufficient. Prefer a few diverse canonical
examples over a large catalogue of edge cases.

## Retrieve progressively

Prefer just-in-time retrieval for large or changing information spaces:

- begin with paths, IDs, titles, timestamps, schemas, summaries, or indexes;
- retrieve the smallest useful fragment;
- expand only when evidence from the current step justifies it;
- keep the original source addressable;
- fail safely when a reference is missing, stale, unauthorized, or malformed.

Do not preload an entire repository, inbox, database result, conversation,
artifact set, or tool history merely because it might become relevant.

Do not add embeddings, RAG, a vector database, or elaborate memory until a
measured retrieval problem requires it.

## Design agent-facing tools for context efficiency

Every tool, MCP adapter, ACP adapter, CLI adapter, or provider-facing capability
must have:

- one clear responsibility;
- minimal semantic overlap with other tools;
- descriptive and unambiguous input parameters;
- bounded structured output;
- filtering, narrowing, or pagination for potentially large results;
- useful recovery-oriented errors without internal-data dumps;
- a lightweight metadata or summary response before large payloads;
- explicit rules for secrets, logging, retention, and result clearing.

If a human cannot confidently choose between two tools for a task, simplify the
contracts before exposing both to the agent.

## Manage tool results and message history

- Do not keep raw tool output in active context indefinitely.
- Once consumed, replace a large result with a typed reference or a distilled
  statement that preserves the facts needed later.
- Do not silently treat an LLM-generated summary as authoritative source data.
- Preserve links from summaries to source artifacts or events.
- Avoid storing the same large payload independently in message history,
  `RunEvent`, logs, artifacts, and memory.
- Redact secrets and sensitive personal data before provider or log exposure
  whenever the original value is unnecessary.

## Handle long-running work

Choose the lightest mechanism supported by an observed need:

### Compaction

Use when an active run or conversation approaches its useful context budget.
Preserve:

- user intent and current objective;
- accepted decisions and architectural constraints;
- critical evidence and source references;
- completed work and produced artifacts;
- unresolved problems and risks;
- the next concrete action.

Remove repetition, obsolete intermediate reasoning, and consumed raw tool
results. Make compaction an explicit event, never an invisible rewrite.

### Structured notes

Use for cross-step or cross-session state such as milestones, dependencies,
plans, decisions, and unresolved work. Notes must have freshness or invalidation
rules and must be retrieved selectively.

### Subagents

Use only for independent bounded work where isolated context or parallel
exploration materially helps. Give a subagent only task-local context. Require
a concise evidence-backed handoff. Do not use subagents as a substitute for
compaction, clear ownership, or a well-scoped main task.

## Observe without duplicating context

Use existing WorkHarness concepts such as `Run`, `RunEvent`,
`ContextSnapshot`, artifacts, token usage, and cost usage.

Record, where applicable:

- selected sources and selection reason;
- estimated and actual token counts;
- section-level budget usage;
- retrieval operations;
- omitted or truncated sources;
- compaction events and summary provenance;
- provider limits and overflow behavior.

Prefer metadata, hashes, references, and measurements over logging raw sensitive
content.

## Verification requirements

Add or update tests for every changed context policy. Cover applicable cases:

- relevant evidence is included;
- irrelevant evidence is omitted;
- context ordering is deterministic;
- the same input produces the same context plan;
- overflow follows an explicit priority policy;
- omission and truncation are observable;
- retrieval loads only requested data;
- missing, stale, or unauthorized references fail safely;
- compaction preserves intent, decisions, constraints, open issues, artifacts,
  and next action;
- sensitive fields do not reach prompts, events, or logs unnecessarily;
- context tokens and cost are accounted for;
- provider differences do not leak into UI or domain layers.

For quality-sensitive behavior, compare at least one realistic run trace before
and after the change. Prefer measured evidence over an assumption that more
context is better.

## Mandatory completion checklist

A relevant task is not complete until all applicable statements are true:

- [ ] The current agent decision or behavior is explicit.
- [ ] Every context source has a reason to exist.
- [ ] Required-now, retrievable, persistent, and discardable data are separated.
- [ ] Context ordering and sections are deterministic.
- [ ] Budget and overflow priorities are explicit.
- [ ] Omission, truncation, and compaction are observable.
- [ ] Large content is retrieved progressively.
- [ ] Tool responsibilities are unambiguous and outputs are bounded.
- [ ] Raw-result retention or clearing is defined.
- [ ] Sensitive data exposure is minimized.
- [ ] UI and provider abstraction boundaries remain intact.
- [ ] Applicable automated tests pass.
- [ ] Token and cost impact is visible.
- [ ] A concise context-impact note is included in the implementation report.

## Required context-impact note

For every completed relevant change, report:

1. What now enters model context and why.
2. What remains external and how it is retrieved.
3. What is discarded, summarized, or compacted.
4. What budget or limiting mechanism applies.
5. How the behavior was verified.

## Scope control

Do not turn adoption of this skill into a rewrite of WorkHarness.

Use this priority:

1. correctness and safety defects;
2. architecture-boundary violations;
3. missing observability and tests;
4. measured context-quality, latency, or cost problems;
5. optional optimization.

Do not implement speculative infrastructure merely because it appears in this
skill. Record non-MVP opportunities in the backlog.

## Source

Adapted for WorkHarness from Anthropic:
[Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents),
published September 29, 2025.
