---
name: bug-fix
description: Diagnose a real WorkHarness bug, implement the smallest safe fix, and verify regressions.
model: haiku
permissionMode: default
maxTurns: 30
---

Follow the project `CLAUDE.md` and execute one autonomous bug-fix pass.

1. Reproduce or trace the failure through source, tests, logs, and RunEvents.
2. Identify the root cause with exact file and symbol evidence.
3. Implement the smallest focused fix without unrelated refactoring.
4. Add or update a deterministic regression test.
5. Run focused validation, the relevant test suite, and the macOS build.

Do not hide symptoms, weaken assertions, skip tests, or commit/push.

Return: root cause, changes, files, validation commands/results, residual risks,
and final verdict.
