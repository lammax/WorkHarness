# Day 8 Video Script

Target duration: 2–3 minutes.

## 1. Prepare WorkHarnessMobile

1. Open WorkHarness.
2. Select the **WorkHarnessMobile** project.
3. Show that its root is:

   `/Users/lammax/Documents/ThisIsMy/Programming/AI/WorkHarnessMobile`

4. Explain that both test requests are read-only and explicitly prohibit
   tools. Day 8 verifies model routing, not the MCP tool loop.

## 2. Settings

1. Open **Settings → Execution & Providers**.
2. Select **Claude Code CLI**.
3. Show:
   - **Automatic model routing**;
   - Haiku as the fast model;
   - Sonnet as the strong fallback;
   - threshold `240`;
   - **Save for Next Run**.
4. Enable routing and save.

Say: routing applies only to new direct Runs and never switches the model
inside an active Run.

## 3. Fast route — WorkHarnessMobile

1. Open Chat.
2. Run:

   `Ответь одним предложением: какую роль выполняет WorkHarnessMobile? Не используй инструменты и не меняй файлы.`

3. Open its timeline or Runs details.
4. Show the `Model Routing` event:
   - route `fast`;
   - model `haiku`;
   - reason `short_simple_prompt`.
5. Briefly show the one-sentence answer without tool calls or file changes.

## 4. Fallback route — WorkHarnessMobile

1. Start a new Run:

   `Без использования инструментов назови три риска безопасности хранения pairing token в WorkHarnessMobile. Код и файлы не меняй.`

2. Show the `Model Routing` event:
   - route `fallback`;
   - model `sonnet`;
   - reason `critical_keyword`.
3. Show `matchedKeyword` in the event metadata.
4. Briefly show Sonnet's three-item read-only answer without tool calls.

## 5. Code and tests

1. Briefly show `AgentModelRoutingService`.
2. Show the routing tests.
3. Show the final output:

   `** TEST SUCCEEDED **`

Conclude: while working with the same WorkHarnessMobile project, WorkHarness
kept a short repository question on Haiku and escalated the security-sensitive
question to Sonnet.
