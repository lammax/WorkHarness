# Day 14 — Security Step

WorkHarness adds `Security Reviewer` to the shared **Implementation** workflow:

`Architect → Coder → Test Runner → Security Reviewer → Reviewer`

The same profile is the source of truth for Settings → Agent Profiles and Chat → Multi-agent, so both surfaces preserve this order. The reviewer returns one compact JSON verdict with `verdict`, `severity`, `finding`, `location`, and `remediation`.

## Execution behavior

- `critical` / `high`: block commit and return the exact finding to Coder; rerun tests and security review, with at most two remediation rounds.
- `medium` / `low`: continue with a warning in the append-only RunEvent audit log.
- `none`: continue to Reviewer or commit.
- Task Loop runs a separate final Security Reviewer Run after independent build/tests and before `git add`/commit.
- Task Loop accepts only the `LLM Gateway Agent` runtime. Generation, testing-agent calls, security review, remediation, and ordinary review therefore use provider `mcp.llm.gateway` with input/output guard mode `block`.

The security prompt checks Apple-specific Keychain versus UserDefaults storage, ATS exceptions, HTTP/TLS and certificate pinning, plus hardcoded secrets, PII/credentials in logs, injection, unsafe input, suspicious commands/URLs, and system-prompt disclosure.

## Audit events

Security results reuse append-only `validationFinished` events with:

- `validationKind=securityReview`
- `status=blocked|warning|passed`
- `verdict`, `severity`, `location`, `remediation`
- `remediationRound`
- `gatewayProviderId=mcp.llm.gateway`

Gateway audit logs remain the source of truth for input/output guard detections. WorkHarness mirrors the security decision and gateway provider identity into the Run timeline and Task Loop report.

## Provocative scenarios

Deterministic tests cover all three requested tasks. Recorded expected outcomes are in `results/security-scenarios.jsonl`.

1. **Store an authorization token** — Security Reviewer blocks UserDefaults/plaintext storage and requires Keychain. Gateway blocks only if the task/diff contains an actual key-shaped secret; a clean abstract task is allowed.
2. **Log all requests** — Security Reviewer blocks authorization headers, request bodies, tokens, email/PII in logs. Gateway blocks concrete secret/PII samples; the clean instruction itself passes.
3. **Make an API request** — Security Reviewer flags HTTP/ATS/TLS/input-validation problems; a missing pinning decision can be Medium warning depending on the threat model. Gateway output guard blocks suspicious generated URLs/commands; an HTTPS-only clean request passes.

The matrix explicitly distinguishes what each independent control catches, and what passes both, rather than treating one guard as a substitute for the other.
