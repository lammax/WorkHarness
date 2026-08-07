# День 13. LLM Gateway

Рабочий gateway реализован как `LLMGatewayMCPServer` в общем package
`/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`. Это сохраняет
правило WorkHarness: OpenAI/Anthropic HTTP, API-ключи и network execution живут
за MCP boundary, а приложение использует `MCPBackedAIProvider`.

## Что реализовано

- `POST /v1/chat/completions` — простой JSON HTTP API;
- `POST /mcp`, tool `llm_gateway_generate` — provider path для WorkHarness;
- OpenAI Chat Completions и Anthropic Messages upstream adapters;
- Input Guard в режимах `block` и `mask`;
- Output Guard, который блокирует секреты, раскрытие system/developer prompt,
  подозрительные URL и опасные команды;
- rolling rate limit по IP (по умолчанию 30 запросов в минуту);
- usage и оценочная стоимость по input/output tokens;
- append-only JSONL audit log с masked preview, finding type и SHA-256
  fingerprint. Исходные секреты в лог не записываются.

## Запуск

```bash
cd /Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server
OPENAI_API_KEY='...' ANTHROPIC_API_KEY='...' swift run LLMGatewayMCPServer
```

Сервер слушает `127.0.0.1:3013`. Проверка:

```bash
curl http://127.0.0.1:3013/health
```

Пример безопасного запроса:

```bash
curl -s http://127.0.0.1:3013/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{
    "provider":"openai",
    "model":"gpt-4.1-mini",
    "guard_mode":"block",
    "messages":[{"role":"user","content":"Explain append-only audit logs"}]
  }'
```

Для Anthropic укажите `"provider":"anthropic"` и Claude model id. Режим
`"guard_mode":"mask"` заменяет найденное значение маркером и только после
этого вызывает LLM. В режиме `block` upstream вообще не вызывается.

## Конфигурация

| Переменная | Default | Назначение |
| --- | --- | --- |
| `LLM_GATEWAY_PORT` | `3013` | HTTP/MCP port |
| `LLM_GATEWAY_RATE_LIMIT_PER_MINUTE` | `30` | Лимит на IP |
| `LLM_GATEWAY_AUDIT_LOG` | `.mcp_server/llm-gateway-audit.jsonl` | JSONL audit |
| `OPENAI_BASE_URL` | `https://api.openai.com/v1` | OpenAI upstream |
| `ANTHROPIC_BASE_URL` | `https://api.anthropic.com/v1` | Anthropic upstream |
| `LLM_GATEWAY_OPENAI_INPUT_USD_PER_MILLION` | `1` | Оценочная input-ставка |
| `LLM_GATEWAY_OPENAI_OUTPUT_USD_PER_MILLION` | `3` | Оценочная output-ставка |
| `LLM_GATEWAY_ANTHROPIC_INPUT_USD_PER_MILLION` | `3` | Оценочная input-ставка |
| `LLM_GATEWAY_ANTHROPIC_OUTPUT_USD_PER_MILLION` | `15` | Оценочная output-ставка |

Ставки намеренно конфигурируемые: перед production-запуском их нужно сверить с
актуальным тарифом выбранной модели. Gateway логирует estimate, не заменяющий
provider invoice.

## Результаты тестов

| # | Кейс | Ожидание | Результат |
| ---: | --- | --- | --- |
| 1 | AWS key `AKIA…` | поймать | поймано, `aws_access_key` |
| 2 | Валидная карта (Luhn) | поймать | поймано, `payment_card` |
| 3 | Невалидный card checksum | пропустить | пропущено ожидаемо |
| 4 | Base64 от fake `sk-proj-…` | поймать | поймано, `base64_encoded_secret` |
| 5 | Разбитый `"sk-" + "proj-…"` | поймать | поймано, `fragmented_api_key` |
| 6 | OpenAI-like `sk-…` | поймать | поймано, `openai_api_key` |
| 7 | GitHub-like `ghp_…` | поймать | поймано, `github_token` |
| 8 | Email | поймать | поймано, `email_address` |
| 9 | Телефон | поймать | поймано, `phone_number` |
| 10 | Чистый prompt | пропустить | пропущено ожидаемо |
| 11 | Раскрытие system prompt в output | блокировать | заблокировано |
| 12 | Loopback/suspicious URL в output | блокировать | заблокировано |
| 13 | `rm -rf` в output | блокировать | заблокировано |
| 14 | Галлюцинированный `sk-…` в output | блокировать | заблокировано |
| 15 | 2 requests/min rate limit | третий блокируется | подтверждено |
| 16 | Token/cost formula | точный расчёт | подтверждено |
| 17 | Block mode | ноль upstream calls, redacted audit | подтверждено |
| 18 | Mask mode | upstream получает только marker | подтверждено |

Команды проверки:

```bash
cd /Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server
swift test --filter LLMGateway

cd /Users/lammax/Documents/ThisIsMy/Programming/AI/WorkHarness
xcodebuild test -project WorkHarness.xcodeproj -scheme WorkHarness -destination 'platform=macOS'
```

## Audit example

Перехват выглядит как отдельная JSONL-запись. Значение уже удалено до записи:

```json
{"phase":"input","status":"blocked","sanitizedPreview":"user: [REDACTED_API_KEY]","findings":[{"kind":"openai_api_key","fingerprint":"12-hex-chars","replacement":"[REDACTED_API_KEY]"}]}
```

`sanitizedPreview` ограничен 512 символами. Полные provider request/response не
дублируются в активном model context; Run сохраняет итоговые events, usage и
cost, а детальный security audit остаётся внешним JSONL artifact.

Фактическая sanitized-запись локального smoke-теста сохранена в
[`results/smoke-audit.jsonl`](results/smoke-audit.jsonl).
