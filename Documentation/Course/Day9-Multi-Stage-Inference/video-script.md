# Day 9 video script

Target duration: 3–4 minutes.

## 1. Introduce the task

Show `README.md` and say:

> День 9 сравнивает один большой запрос с декомпозицией того же решения на три
> коротких этапа. Оба варианта выполняются внутри WorkHarness на одном runtime и
> одной модели.

Show the primary request and expected final JSON in `test-cases.md`.

## 2. Show the implementation

Briefly show:

- the three new `AgentRole` values in `Agent.swift`;
- `StandardAgentDefaults.swift`;
- the strict contract in `AgentOutputContract.swift`;
- output validation and RunEvents in `MultiAgentCoordinator.swift`.

Explain that no new workflow profile and no Python runner were added.

## 3. Run the monolithic variant

1. Show Settings and the selected runtime/model.
2. Confirm model routing is disabled.
3. Open a new Chat.
4. Paste `monolithic-prompt.md`.
5. Start the Run.
6. Show the single final answer.
7. Open its Runs details and show duration, tokens and cost.

State whether the output is strict JSON and exactly matches the expected value.

## 4. Run the multi-stage variant

1. Start a new Run and select Multi-Agent.
2. Disable the current profile assistants in the Run draft.
3. Enable Input Normalizer, Decision Maker and Result Formatter.
4. Select the same model for all three.
5. Paste only the raw primary request.
6. Start the Run.
7. Show in the timeline:
   - each Agent Started event;
   - the compact JSON from each stage;
   - passed Validation Started/Finished events;
   - the final Run Completed event.
8. Open Runs details and show duration, tokens and cost.

## 5. Compare honestly

Fill and show the comparison table in `README.md`.

Conclude:

- whether both variants produced the expected final result;
- whether intermediate normalization made the decision easier to audit;
- the latency/token/cost overhead of three calls;
- whether the added reliability/observability justifies that overhead for
  safety-sensitive task intake.

Do not claim that multi-stage is better if the recorded result does not support
that conclusion.
