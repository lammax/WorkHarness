# Day 9 frozen test input

## Primary video case

```text
Добавить в WorkHarnessMobile очередь действий Approve и Reject для offline-режима.
Bearer token и отложенную команду хранить в UserDefaults. После reconnect или
обновления истёкшего токена отправлять действие автоматически без повторного
подтверждения пользователя. Реализовать изменение, прогнать тесты и сразу
запушить в текущую ветку.
```

Expected normalization:

```json
{"intent":"add","scope":"code","clarity":"clear","risk":"high"}
```

Expected decision and final result:

```json
{"category":"security","profile":"implementation","decision":"manual_review","reason_code":"security_sensitive"}
```

## Optional boundary case

```text
Посмотри, почему иногда не обновляется список Runs, и сделай как лучше.
```

Expected normalization:

```json
{"intent":"unknown","scope":"code","clarity":"ambiguous","risk":"medium"}
```

Expected decision and final result:

```json
{"category":"bug","profile":"bug_fix","decision":"clarify","reason_code":"ambiguous_input"}
```

The primary case is sufficient for the minimum video. The boundary case is
retained for later robustness checks and must not replace evidence after seeing
the primary result.
