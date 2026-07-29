# Day 8 Routing Test Series

Configuration:

- runtime: Claude Code CLI;
- routing: enabled;
- fast model: Haiku;
- fallback model: Sonnet;
- prompt-length threshold: 240 characters.
- selected project: WorkHarnessMobile;
- all prompts are read-only, prohibit tools, and must not change project files.

| ID | Prompt | Expected route | Reason |
|---|---|---|---|
| D8-01 | `Ответь одним предложением: какую роль выполняет WorkHarnessMobile? Не используй инструменты и не меняй файлы.` | Haiku | short simple prompt |
| D8-02 | `Ответь кратко: какие данные обычно показывает мобильный экран Runs? Не используй инструменты и не меняй файлы.` | Haiku | short simple prompt |
| D8-03 | `Назови два удобных действия на экране Approvals мобильного клиента. Не используй инструменты и не меняй файлы.` | Haiku | short simple prompt |
| D8-04 | `Одним предложением опиши назначение RemoteSDK. Не используй инструменты и не меняй файлы.` | Haiku | short simple prompt |
| D8-05 | `Без использования инструментов назови три риска безопасности хранения pairing token в WorkHarnessMobile. Код и файлы не меняй.` | Sonnet | critical keyword |
| D8-06 | `Без использования инструментов опиши архитектуру восстановления SSE-подключения WorkHarnessMobile после потери сети. Файлы не меняй.` | Sonnet | critical keyword |
| D8-07 | `Без использования инструментов подготовь подробный проектный анализ подключения WorkHarnessMobile к удалённому WorkHarness: сопоставь модели запросов и ответов, возможные состояния интерфейса, обработку ошибок, восстановление соединения, наблюдаемость и необходимое тестовое покрытие. Ответ структурируй, но код и файлы не меняй.` | Sonnet | prompt longer than 240 characters |
| D8-08 | `Ответь без инструментов и изменений файлов:\n- назови назначение Approvals\n- объясни действие Reject\n- предложи один тест` | Sonnet | three requirements |

## Recorded deterministic result

| Route | Requests | Count |
|---|---|---:|
| Haiku | D8-01–D8-04 | 4 |
| Sonnet | D8-05–D8-08 | 4 |

The routing branches are covered by
`agentModelRoutingEscalatesLongCriticalAndMultiRequirementPrompts` and the
HarnessEngine integration test. For the submission video, select
WorkHarnessMobile, run D8-01 and D8-05 in the real UI, and show their
`Model Routing` events.
