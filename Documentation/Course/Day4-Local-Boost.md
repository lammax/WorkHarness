# Day 4 — Local Boost

Status: minimum local setup implemented and verified; the Claude benchmark is
blocked by the current account limit and must be repeated before submission.

## Environment

- Device: MacBook Pro, Apple M3 Pro, 11 CPU cores, 18 GB unified memory.
- Local runtime: Ollama 0.18.0.
- IDE: Cursor 3.13.10.
- IDE extension: Continue 2.0.0.
- WorkHarness local provider boundary: `LocalLLMMCPServer`.

## Selected models

| Surface | Model | Purpose |
|---|---|---|
| Cursor Agent | `gpt-5.4-nano-none` | Minimal cloud baseline |
| Claude Code | `haiku` | Minimal Claude baseline |
| Continue + Ollama | `qwen2.5-coder:1.5b` | Local Chat, Edit and Autocomplete |
| WorkHarness | `qwen2.5-coder:1.5b` via MCP | Local provider baseline |

## Local configuration

- Context window: 16,384 tokens.
- Maximum output: 2,048 tokens.
- Temperature: 0.1.
- Top-p: 0.9.
- Autocomplete prompt budget: 2,048 tokens.
- Project rule: `.continue/rules/01-workharness.md`.
- Continue user configuration: `~/.continue/config.yaml`.
- Complete project rules: `AGENTS.md`.
- Claude project rules and examples: `CLAUDE.md`.

Continue applies project rules to Chat, Edit and Agent requests. Continue does
not inject rules into autocomplete, so autocomplete is evaluated only as local
code continuation with nearby-file context.

## Fixed benchmark prompts

### Day 1 — Feature

> Add installed Local LLM model selection to WorkHarness Settings. Discover
> available models through the existing LocalLLMMCPServer, keep backend-specific
> behavior outside WorkHarness, route SettingsPageViewModel through a service
> boundary, preserve Save/Revert behavior, add focused tests, and run the
> required macOS build and test suite. Do not ask follow-up questions and do not
> commit or push.

Acceptance:

- installed generation models are returned by `local_llm_list_models`;
- the Local LLM provider page displays its endpoint, model picker, explicit
  refresh action and dedicated Save/Revert controls;
- selection participates in draft/dirty/save/revert behavior;
- no View/ViewModel-to-provider dependency is introduced;
- build and focused tests pass.

### Day 2 — Bug Fix

> Bug Fix profile: changing Local LLM endpoint or model in Settings and pressing
> Save does not affect the existing MCPProviderClient until WorkHarness is
> restarted. Find the root cause, implement the smallest safe fix, add a
> deterministic regression test, and run relevant validation. Do not make
> unrelated changes and do not commit or push.

### Day 2 — Research

> Research profile: explain how a Local LLM request travels from WorkHarness
> Settings to LocalLLMMCPServer and Ollama, how ContextBuilder content reaches
> the model, and which RunEvents make the request observable. Cite exact files
> and symbols, identify current limitations, and do not change any files.

## Benchmark protocol

- Use the same prompt and acceptance criteria.
- Start from the same Git revision or equivalent isolated worktree.
- Count the first autonomous response before manual correction.
- Record elapsed time, files changed, build/tests, architectural violations and
  required follow-up prompts.
- Keep failed attempts; do not convert them into a pass.

## Results

The implementation run used the cloud Codex assistant. Cursor and Claude are
additional minimum-model baselines requested for the course evidence.

| Criterion | Cloud Codex | Cursor minimal | Claude Haiku | Local Qwen 1.5B |
|---|---|---|---|---|
| Day 1 feature | Passed: model discovery, picker, refresh, save/revert path and tests implemented | Not run | Blocked by account limit | Failed as an implementation answer: invented direct ViewModel-to-server calls and incomplete tests |
| Day 2 Bug Fix | Passed: MCP client now reads saved configuration dynamically; regression test added | Not run | Blocked by account limit | Failed: identified stale configuration generally, but proposed a forbidden singleton and direct ViewModel-to-provider dependency |
| Day 2 Research | Not run separately | Passed first response; accurate overall dependency trace with minor omissions | Blocked by account limit | Failed in Claude agent mode: returned an invented tool schema instead of inspecting files |
| Code quality | Production-quality, builds and tests pass | Good for the research response | Not measured | Good only for small isolated code; unsafe for project-wide changes |
| Measured speed | Full implementation session, not directly comparable | 106.83 s for Research | Failed after 2.61–3.20 s due credits/session limits | 2.96 s for a small Swift function; 4.81 s Bug Fix answer; 15.31 s Feature answer; 6.91 s failed agent attempt |
| Project-context understanding | Strong | Strong, with incomplete Settings/DI inspection | Not measured | Weak even with architecture supplied in the prompt |
| Works without internet | No | No | No | Yes after the model is downloaded |

### Local runtime verification

- `qwen2.5-coder:1.5b` is installed in Ollama (Q4_K_M, approximately 986 MB).
- `GET /health` on `LocalLLMMCPServer` returned `OK`.
- `local_llm_list_models` returned Qwen, Llama 3 and Phi-3, and correctly
  excluded the installed embedding-only model.
- `local_llm_generate` returned valid Swift for a small stable-deduplication
  function in 2.96 seconds.
- Feature and Bug Fix answers were retained as failures instead of being
  manually corrected into passes.

### Validation

- `swift build --product LocalLLMMCPServer`: passed.
- WorkHarness macOS build: passed.
- WorkHarness full test suite: passed; the opt-in live Claude test was skipped.
- Continue configuration YAML: parsed successfully.

## Initial recommendation

Qwen 2.5 Coder 1.5B is sufficient for fast autocomplete, boilerplate, small
pure functions, narrow transformations, explanations of explicitly attached
code and privacy-sensitive offline drafts. It is not sufficient for autonomous
WorkHarness feature work, multi-file bug fixing or reliable tool use. Use a
cloud assistant for architecture, repository-wide changes, debugging and
validation.

Before course submission, repeat the three fixed prompts with Claude Haiku
after the session limit resets, run the missing Cursor Feature/Bug Fix
benchmarks in isolated worktrees, and capture screenshots of Continue chat,
autocomplete, WorkHarness model selection and the result table.
