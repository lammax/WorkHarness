# Day 10 Frozen Evaluation Cases

The source of truth is `MicroModelEvaluationCatalog.swift`. The set is frozen
before the live evaluation so its expected labels cannot be adjusted to match
model output.

| Group | IDs | Count | Purpose |
| --- | --- | ---: | --- |
| Simple | D10-S01…D10-S08 | 8 | Direct, single-intent requests |
| Boundary | D10-B01…D10-B08 | 8 | Mixed wording or closely related intents |
| Complex | D10-C01…D10-C08 | 8 | Multiple constraints, noise or security-sensitive wording |

The expected labels cover all seven allowed categories:

- `bug`
- `feature`
- `refactoring`
- `tests`
- `documentation`
- `research`
- `security`

Examples include crash fixes, approval UI, behavior-preserving refactoring,
test matrices, operator documentation, read-only architecture research and
pairing/token security. WorkHarness records the case ID and expected/final
category in the result artifact without placing previous cases into the next
model context.
