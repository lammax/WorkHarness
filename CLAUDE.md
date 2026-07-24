# CLAUDE.md — WorkHarness

Самодостаточные локальные правила Claude Code для WorkHarness. Они адаптированы
из `AGENTS.md` и глобального `agent-harness` skill под Swift, SwiftUI и
изолированный Claude runtime. Общение и отчёты — на русском; code identifiers и
comments — на английском.

WorkHarness — local-first macOS AI Agent Harness / Orchestrator, не
чат-приложение. Центральная сущность — `Run`; Chat является UI-поверхностью над
`Run` и append-only `RunEvent`.

## Execution environment

Claude работает внутри WorkHarness, а не в unrestricted Claude Code session.

- Использовать только capabilities, опубликованные `workharness` MCP server.
- Built-in Read/Edit/Write/Bash/Web/Skill/Agent и slash commands могут быть
  недоступны; не считать их наличие обязательным.
- Доступные project tools обнаруживать через MCP. File/shell/git/RAG operations
  выполняются только через разрешённые WorkHarness tools.
- Все пути ограничены активным project root. Не выходить за его пределы.
- Writes, shell и mutating git проходят WorkHarness approval. Сразу вызывать
  соответствующий MCP tool: не просить подтверждение обычным текстом и не
  останавливаться до tool call. WorkHarness сам применит текущую approval policy
  и при необходимости приостановит вызов до решения пользователя.
- Если capability отсутствует или approval отклонён, продолжить безопасную
  read-only работу и точно указать, что осталось непроверенным.
- `file.write` заменяет файл целиком: непосредственно перед записью прочитать
  полный актуальный файл и сохранить unrelated content.
- Не логировать и не записывать в rules/settings/fixtures/MCP config токены,
  credentials и другие secrets.

## Before changing code

1. Исследовать затронутые файлы, соседние patterns, DI и tests.
2. Определить owning layer и dependency direction.
3. Проверить влияние на persistence, RunEvents, cancellation и security.
4. Сделать минимальный coherent slice без unrelated refactoring.
5. Добавить focused deterministic tests и выполнить доступную validation.
6. Не объявлять build/tests успешными без фактического запуска.

Для feature использовать `Research -> Plan -> Execute -> Validate -> Report`.
Для bugfix: `Reproduce -> Diagnose root cause -> Minimal Fix -> Regression
Validation -> Report`. Если prompt требует один автономный проход, не
останавливаться ради необязательных вопросов: принять безопасные разумные
предположения и перечислить их в отчёте.

## Stack и структура

- Swift, SwiftUI, Observation, Swift Concurrency.
- Swinject для DI.
- SQLite за persistence/repository boundary.
- Swift Testing и `xcodebuild` для validation.
- LLM backends: MCP-backed `AIProvider`.
- Full coding agents: provider-agnostic `AgentRuntime`; ACP предпочтителен,
  текущие изолированные CLI runtimes допустимы.
- Реальное tool execution: MCP servers. WorkHarness владеет registry, metadata,
  approval flow, RunEvents и adapters.
- Связанный MCP package:
  `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`.

```text
WorkHarness/
├── App/                 # composition root и scene
├── DI/                  # Swinject registration
├── Navigation/          # Screen/Page primitives
├── UI/Screens/          # feature Screen/Page/View/ViewModel/Design
├── UI/Views/            # только shared views
├── Models/              # domain без SwiftUI/transport/storage DTO
├── HarnessEngine/       # orchestration и Run lifecycle
├── AgentRuntime/        # coding agent sessions
├── Services/            # UI-facing application boundaries
├── Providers/           # AIProvider abstractions/MCP adapters
├── Repositories/        # data access/state storage
├── Persistence/         # SQLite/mapping
├── RemoteControl/       # authenticated Remote API
└── Tools/               # registry/metadata/MCP adapters
```

Мобильный Remote Client — отдельный клиент WorkHarness Remote API. Не помещать
mobile-specific networking, pairing, storage или UI в macOS WorkHarness.

## Architecture invariants

```text
View -> ViewModel -> Service / HarnessFacade -> HarnessEngine
                                                ↓
                                      Repository / Provider / Tool
```

- View не вызывает repository/provider/tool/network/process.
- Feature ViewModel зависит от `*ServiceProtocol`, а не от
  repository/provider/tool/runtime.
- Service координирует engine/repositories/providers/tools.
- Repository владеет только data access/state storage.
- Generic orchestration зависит от protocols/capabilities, не от `Claude`,
  `Cursor` или concrete provider.
- `HarnessEngine`, providers, tools и repositories не зависят от SwiftUI.
- Важное Run-действие порождает `RunEvent`; после записи событие не мутировать
  ради streaming UI.
- Mutating/dangerous tool call проходит approval path.
- Перед новым MCP capability проверить существующие MCP servers.

## Swift и SwiftUI conventions

- Protocol: `<Responsibility>Protocol`; service: `<Domain>Service`;
  error: `<Boundary>Error`; runtime: `<Backend><Transport>Runtime`.
- Не использовать `Manager`, `Helper`, `Utils`, `Handler`, `Processor` без
  узкого очевидного scope.
- Feature types объявлять в `extension <Name>Screen`.
- Screen владеет Page routing; Page не управляет global scene/window navigation.
- `*View`: layout, bindings, forwarding actions.
- `*ViewModel`: explicit UI state и service/facade calls.
- Один `*Design` для Screen scope и один для каждой Page scope; component
  constants держать в nested sections.
- В каждом View: локальный `typealias Design = ...`; без повторяемых UI literals.
- Constructor injection, explicit access control, typed errors, `async/await`.
- Cancellation должна быть явной; не использовать fire-and-forget или
  `Task.detached` без ownership.
- Один primary type на файл, когда практично.
- Feature files размещать в `WorkHarness/UI/Screens/<Name>/`.

Новый Swift-файл:

```swift
//
// FileName.swift
// WorkHarness
//
// Created by Auto (Codex) on DD.MM.YYYY.
//

import Foundation

@MainActor
protocol FeatureServiceProtocol: BaseServiceProtocol {
    func load() async throws -> FeatureState
}

@MainActor
final class FeatureService: FeatureServiceProtocol {
    private let repository: FeatureRepositoryProtocol

    init(repository: FeatureRepositoryProtocol) {
        self.repository = repository
    }

    func load() async throws -> FeatureState {
        try await repository.load()
    }
}
```

Порядок: header → imports → attributes/primary type → private dependencies →
initializer → public/internal API → private helpers. Зарегистрировать dependency
в соответствующем `DI/*Register.swift`: shared обычно `.container`,
Screen/Page обычно `.transient`.

## Хорошие примеры из WorkHarness

1. ViewModel зависит от service protocol
   (`UI/Screens/Main/Pages/Runs/RunsPageViewModel.swift`):

```swift
@MainActor @Observable
final class RunsPageViewModel {
    private let runService: RunServiceProtocol
    init(runService: RunServiceProtocol) { self.runService = runService }
}
```

2. View использует namespace и Design
   (`UI/Screens/Main/Pages/Runs/RunsPageView.swift`):

```swift
extension MainScreen {
    struct RunsPageView: View {
        typealias Design = RunsPageDesign
        @Bindable var viewModel: RunsPageViewModel
    }
}
```

3. Service является application boundary
   (`Services/Run/RunService.swift`):

```swift
func startRun(goal: String) async -> UUID? {
    await harnessEngine.startRun(goal: goal)
}
```

4. State transition сопровождается append-only event
   (`Services/Approval/ApprovalService.swift`):

```swift
runRepository.updateRun(runId) { $0.status = .waitingForApproval }
recorder.record(runId: runId, type: .approvalRequested, message: title)
```

5. Focused test проверяет observable behavior без сети/CLI:

```swift
viewModel.selectProvider(id: "alternate.provider")
#expect(providerService.activeProviderId == "alternate.provider")
#expect(viewModel.activeProviderId == "alternate.provider")
```

## Антипаттерны

```swift
// BAD: View создаёт backend/storage dependency.
Button("Run") { ClaudeCLIRuntime(...).execute(...) }
let repository = SQLiteRunRepository(...)

// BAD: concrete runtime branching в generic code.
if runtime.id == "claude.cli" { runClaudePath() }

// BAD: записанный RunEvent мутируется ради stream.
repository.events[index].message += delta

// BAD: business action и magic values внутри View.
Button("Approve") { repository.updateStatus(.granted) }.padding(17)

// BAD: обход MCP/approval и утечка секрета.
try! Process.run(rmURL, arguments: ["-rf", path])
logger.info("token=\(token)")
```

Также запрещены force unwrap/`try!` вне контролируемого DI composition root,
прямой SQL вне repository/persistence, silent error swallowing, реальная
network/CLI/wall-clock delay в unit tests и unrelated mass refactoring.

## Subagents, skills и config scopes

- Делегировать только если runtime публикует Agent/subagent capability и задача
  ограничена, независима и не пересекается по файлам с другой работой.
- Главный agent отвечает за интеграцию, итоговый diff и validation.
- При делегировании передать цель, scope, paths, ограничения, известные факты,
  ожидаемый output и запрет commit/push.
- Skill использовать только если runtime публикует Skill capability и skill
  доступен. Отсутствие skills/subagents в isolated WorkHarness Run ожидаемо.

```text
~/.claude/CLAUDE.md             # global personal behavior
./CLAUDE.md                     # shared project behavior
./CLAUDE.local.md               # personal project behavior, gitignored
.claude/settings.json           # shared enforceable settings
.claude/settings.local.json     # personal settings, gitignored
.claude/skills/                 # optional project skills
.claude/agents/                 # optional project subagents
```

Project settings не являются способом обойти принудительные WorkHarness tools,
MCP config или approval policy.

## Agent Profiles

- `AgentRole` — специализация; `AgentWorkflowProfile` — data-driven workflow,
  состав ассистентов и порядок вызова.
- Профили проекта хранятся в `.workharness/agent-profiles/`: `profiles.json`
  содержит mapping и порядок, каждый ассистент использует отдельный `.md` prompt.
- Markdown prompt является source of truth. WorkHarness загружает его через
  `AgentProfileServiceProtocol` и передаёт snapshot в новый Run.
- Не зашивать профили и порядок в SwiftUI или generic planner. Settings меняет
  их только через service boundary. Перед новым multi-agent Run prompts повторно
  читаются с диска; обычный Chat профильные prompts не использует.
- Multi-agent `RunEvent.metadata` должен сохранять profile/assistant/prompt path
  для audit и воспроизводимого сравнения запусков.
- Research выполняется read-only. Bug Fix проходит diagnosis, focused fix и
  regression verification; Implementation — plan, code, review, test.

## Run Recovery

- Durable truth после перезапуска — SQLite `Run` и append-only `RunEvent`, а не
  runtime/CLI/ACP session в памяти.
- На старте сохранённые `running`/`waitingForApproval` Runs становятся
  `interrupted` с одним `runInterrupted` event.
- Resume создаёт новую runtime-сессию в том же Run и сначала проверяет текущий
  workspace/git diff по сохранённой цели и последним событиям.
- Restart создаёт новый Run с исходными mode, attachments и multi-agent config.
- Не утверждать, что Resume точно продолжает потерянный процесс, и не повторять
  уже выполненные изменения вслепую.

## Testing configuration и smoke automation

- Проектная testing-конфигурация хранится в `.workharness/testing/`:
  `testing.json` содержит target, команды, enabled state и порядок, а `smoke/*.md`
  — отдельные сценарии с шагами, assertions и требованиями к screenshots.
- Settings работает с этими файлами только через
  `TestingConfigurationServiceProtocol`.
- Smoke-сценарии запускаются только по явному нажатию специальной кнопки в
  Settings. Не запускать их автоматически при старте приложения, сохранении
  настроек, обычном чате или после каждого изменения кода.
- Code tests и smoke tests — отдельные validation layers, объединяемые в один
  Run/report.
- Claude in Mobile и другие UI automation tools подключаются только через
  WorkHarness Tool/MCP/approval gateway. Не обходить RunEvents, permissions и
  audit прямым MCP config agent runtime.
- Smoke flow использует deterministic fixture, accessibility identifiers и
  semantic locators. Каждый шаг фиксирует pass/fail и screenshot artifact.
- Сценарии data-driven; не зашивать их список в SwiftUI или orchestrator.
- Runtime reports/screenshots хранить отдельно от versioned scenario sources.

## Validation, git и report

```bash
xcodebuild build \
  -project WorkHarness.xcodeproj \
  -scheme WorkHarness \
  -destination 'platform=macOS'

xcodebuild test \
  -project WorkHarness.xcodeproj \
  -scheme WorkHarness \
  -destination 'platform=macOS'
```

- Повторять build-fix-rebuild до успеха.
- Для engine/service/view model/provider/repository tests обязательны.
- Fixtures детерминированы: без real network/CLI, случайных sleep и secrets.
- Отдельного lint gate сейчас нет; не заявлять `lint passed`.
- Перед завершением проверить DI/scope, failures, auth/offline/cancellation,
  RunEvents, approval/security и unrelated diff.
- Не делать commit/push без явной команды. Команда `commit` или `push` означает:
  status → scoped commit при наличии изменений → push текущей ветки.
- Итог: что изменено, какие build/tests реально прошли, что не проверено,
  assumptions и остаточные риски.

## AI Advent rules experiment

Для v1/v2 использовать один исходный commit, backend, model и battle prompt.
Первую генерацию не исправлять вручную. Сохранить RunEvents, diff и build/test
output. Усилить rules только по найденным нарушениям, вернуться к исходному
commit и повторить тот же prompt. Не диктовать в rules готовое решение battle
task: правила описывают устойчивые standards.
