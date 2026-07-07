# AGENTS.md — WorkHarness

Правила проекта для AI-агента (Codex). Файл размещается в корне репозитория `WorkHarness`.

Источник стиля правил: `/Users/lammax/Downloads/artesia-ios-codex-rules/AGENTS.md`, адаптировано для локального macOS SwiftUI AI Agent Harness 07.07.2026.

---

## 1. Обязательный контекст перед работой

- Перед планированием или изменениями в этом репозитории прочитать и применять глобальный skill `agent-harness`, установленный в:
  - `/Users/lammax/.codex/skills/agent-harness/SKILL.md`
- Для задач по архитектуре, UI, engine, providers, tools, memory/RAG, testing или roadmap читать соответствующие reference-файлы из:
  - `/Users/lammax/.codex/skills/agent-harness/references/`
- Если в репозитории появится проектная документация (`Documentation/`, `Docs/`, `.codex/`, локальные skills/rules), перед изменениями читать релевантные файлы.
- Если архитектурные паттерны проекта меняются в ходе задачи, сначала обновить соответствующие правила/skill/documentation, затем код.

## 2. Архитектурный принцип проекта

WorkHarness — не чат-приложение. Это локальный AI Agent Harness / Orchestrator для разработки.

Центральная доменная сущность — `Run`, не `Chat`.

Соблюдать поток зависимостей:

```text
View -> ViewModel -> Service / HarnessFacade -> HarnessEngine
                                                ↓
                                      Repository / Provider / Tool
```

Запрещено:

- `View -> Provider`
- `View -> Repository`
- `View -> Tool`
- `Provider -> ViewModel`
- `HarnessEngine -> SwiftUI`
- provider-specific branching в generic orchestration code

## 3. Слои и владение ответственностью

- `WorkHarness/App/` — composition root, DI, app shell.
- `WorkHarness/Models/` — domain models, без SwiftUI, storage DTO, network DTO и provider-specific типов.
- `WorkHarness/ViewModels/` — UI state, user actions, вызовы service/facade/engine.
- `WorkHarness/Views/` — только декларативный UI и forwarding actions.
- `WorkHarness/Design/` — UI-константы: размеры, отступы, радиусы, цвета, иконки, строки, accessibility/test IDs.
- `WorkHarness/HarnessEngine/` — orchestration, loops, approvals, validation, event recording.
- `WorkHarness/Providers/` — AI backend protocols/adapters. CLI tools вроде Codex CLI/Cursor CLI должны быть providers/adapters.
- `WorkHarness/Repositories/` — data access и in-memory/persistence-backed storage.
- `WorkHarness/Tools/` — shell/git/file/search/RAG/browser/MCP tools, когда появятся.
- `WorkHarness/Persistence/` — SQLite/GRDB и mapping, когда появится persistence.

## 4. UI: View / ViewModel / Design

- В `*View.swift` — UI-разметка, композиция компонентов, биндинги, forwarding user actions через closures/ViewModel methods.
- В `*ViewModel.swift` — UI state, правила состояний, вызовы engine/services, преобразование domain data для UI.
- В `*Design.swift` — UI-константы: spacing, sizes, colors, icons, animation durations, строки, accessibility identifiers, test IDs.
- Не переносить business/orchestration logic в `*View.swift`.
- Не хранить визуальные magic values в `*ViewModel.swift`.
- Для новых экранов и крупных правок придерживаться структуры:

```text
Feature
├── Screen
├── Page
├── View
├── ViewModel
├── State
├── Design
└── Components
```

Можно адаптировать имена под текущую структуру проекта, но не смешивать ответственности.

## 5. Запрет UI-хардкода

- В `*View.swift` не оставлять повторяемые размеры, отступы, радиусы, opacity, фиксированные высоты/ширины, иконки и UI-строки.
- Выносить их в соответствующий `*Design.swift` или общий Design-файл.
- В `View` допустимы:
  - ссылки на `Design.*`
  - enum-кейсы
  - технические литералы, не относящиеся к UI-оформлению
  - одноразовые прототипные значения только в раннем scaffold, с явным намерением вынести при стабилизации экрана

## 6. RunEvent и наблюдаемость

- Каждое важное действие внутри Run должно порождать `RunEvent`.
- Предпочитать append-only события. Не мутировать уже записанные события ради streaming UI.
- Для provider streaming использовать события вроде:
  - `runCreated`
  - `agentStarted`
  - `providerRequestStarted`
  - `providerStreamDelta`
  - `assistantMessage`
  - `providerRequestFinished`
  - `agentFinished`
  - `runCompleted`
  - `providerRequestFailed`
  - `runFailed`
- RunEvents должны быть пригодны для replay, debugging, statistics, remote streaming и audit trail.

## 7. Providers

- Каждый AI backend должен быть за общим `AIProvider` protocol.
- Provider может:
  - принимать request
  - stream events
  - сообщать token/cost usage
  - сообщать errors
  - описывать capabilities
- Provider не должен:
  - знать о SwiftUI
  - владеть memory/RAG/orchestration
  - решать global permissions
  - напрямую редактировать файлы без approval path harness engine
- CLI process execution не размазывать по проекту. Для CLI backend создавать отдельный provider/adapter.

## 8. Tools и безопасность

Опасные действия требуют явного approval path:

- `rm`
- `sudo`
- `git push`
- `git reset --hard`
- network calls
- secrets access
- writes outside workspace
- dependency installation

Tool layer должен быть отделен от UI и Providers.

## 9. Git workflow

- Не делать commit/push без явной просьбы пользователя.
- Если пользователь попросил commit:
  - сначала проверить `git status`
  - не включать unrelated changes
  - использовать понятное commit message
- Если пользователь попросил push или workflow явно требует push, выполнять push только после подтверждения/доступного approval path.
- Никогда не использовать destructive git-команды (`git reset --hard`, `git checkout --`, массовые revert) без явной команды пользователя.

## 10. Цикл сборки (Build-Fix-Rebuild Loop)

После изменений в Swift-коде выполнять цикл валидации:

1. Запустить релевантную сборку:
   - `xcodebuild build -project WorkHarness.xcodeproj -scheme WorkHarness -destination 'platform=macOS'`
2. Если есть ошибки сборки — исправить их в этом же контексте.
3. Повторять build-fix-build до успешной сборки.
4. Для изменений в engine/view model/provider/repository запускать тесты:
   - `xcodebuild test -project WorkHarness.xcodeproj -scheme WorkHarness -destination 'platform=macOS'`

В финальном ответе кратко фиксировать результат последней сборки/тестов.

## 11. Тестирование

Приоритет тестов:

- Run state transitions
- RunEvent sequence
- Provider adapter success/error/cancellation/usage
- Tool approval logic
- Tool permission logic
- ContextBuilder / ContextFolding
- Memory write policy
- ViewModel state/actions

Fake providers должны быть детерминированными и не зависеть от реальных задержек, сети или CLI.

## 12. Минимальный scope для багфиксов

- Для багфиксов и крэшей делать минимальный точечный фикс.
- Не расширять scope рефакторингом, переименованиями, переносами и новыми абстракциями, если это не требуется для устранения бага.
- Сохранять существующее поведение UI и business logic вне аварийного сценария.
- После фикса запускать минимально достаточную проверку и фиксировать остаточные риски.

## 13. Новые файлы Swift, созданные агентом

Для новых Swift-файлов, создаваемых агентом с нуля, использовать Xcode-заголовок:

```swift
//
// FileName.swift
// WorkHarness
//
// Created by Auto (Codex) on DD.MM.YYYY.
//
```

- Не менять `Created by` в уже существующих файлах и в файлах, созданных пользователем.
- Если текущая папка/проект уже использует иной шаблон, сохранить совместимость, но автор для новых agent-created файлов — `Auto (Codex)`.

## 14. Документация и правила

- Проектные правила хранятся в `AGENTS.md` в корне репозитория.
- Дополнительную документацию создавать в `Documentation/` или `Docs/`, если такая структура появится.
- Не плодить разрозненные `.md` в случайных папках.
- Если в ходе работы появляется устойчивый архитектурный паттерн, обновить `AGENTS.md` или профильный skill/reference.

## 15. Роли / специализация при декомпозиции задач

Перед сложной задачей классифицировать фокус:

- архитектура / boundaries
- SwiftUI UI
- engine/orchestration
- provider integration
- tools/MCP
- memory/RAG/context
- testing/QA
- performance
- security/safety
- documentation

При однозначном типе задачи применять соответствующий фокус без лишних уточнений. При смешанной задаче сначала провести короткое исследование, затем разделить работу на узкие шаги.

## 16. Итоговое правило

Если правило из `agent-harness` skill и локальное правило из этого файла расходятся, применять более строгое правило, если пользователь явно не сказал иначе.
