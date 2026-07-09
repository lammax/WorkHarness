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
- `ViewModel -> Repository`, если есть соответствующий service boundary
- `ViewModel -> Provider`
- `ViewModel -> Tool`
- `Provider -> ViewModel`
- `HarnessEngine -> SwiftUI`
- provider-specific branching в generic orchestration code

## 3. Слои и владение ответственностью

- `WorkHarness/App/` — composition root, DI, app scene/shell.
- `WorkHarness/DI/` — Swinject registration-файлы по Artesia-style: `DependencyRegistration`, `SceneRegister`, `ScreensRegister`, `ServicesRegister`, `RepositoriesRegister`, `ProvidersRegister`, `EngineRegister`.
- `WorkHarness/Navigation/` — базовые протоколы `Viewable`, `BaseScreenProtocol`, `BasePageProtocol`, `PagesViewModel`, `PagesControlView`, app-level screen routing.
- `WorkHarness/Screens/` — feature-модули UI по Screen/Page архитектуре.
- `WorkHarness/Models/` — domain models, без SwiftUI, storage DTO, network DTO и provider-specific типов.
- `WorkHarness/ViewModels/` — только legacy/общие ViewModel, если нет Screen-модуля; новые feature ViewModel держать внутри соответствующего Screen namespace.
- `WorkHarness/Views/` — только общие переиспользуемые views; feature views держать рядом с Screen/Page.
- `WorkHarness/Design/` — только общий дизайн, если появится; feature design держать внутри соответствующего Screen/Page модуля.
- `WorkHarness/HarnessEngine/` — orchestration, loops, approvals, validation, event recording.
- `WorkHarness/Services/` — business/application фасады между ViewModel и HarnessEngine/Repositories/Providers/Tools.
- `WorkHarness/Providers/` — AI backend protocols/adapters. CLI tools вроде Codex CLI/Cursor CLI должны быть providers/adapters.
- `WorkHarness/Repositories/` — data access и in-memory/persistence-backed storage.
- `WorkHarness/Tools/` — shell/git/file/search/RAG/browser/MCP tools, когда появятся.
- `WorkHarness/Persistence/` — SQLite/GRDB и mapping, когда появится persistence.

## 4. UI: View / ViewModel / Design

- В `*View.swift` — UI-разметка, композиция компонентов, биндинги, forwarding user actions через closures/ViewModel methods.
- В `*ViewModel.swift` — UI state, правила состояний, вызовы services/facades, преобразование domain data для UI.
- В `*Design.swift` — UI-константы: spacing, sizes, colors, icons, animation durations, строки, accessibility identifiers, test IDs.
- Не переносить business/orchestration logic в `*View.swift`.
- Feature ViewModel обращается к сервису/фасаду, а не напрямую к repository, provider, tool или engine.
- Не хранить визуальные magic values в `*ViewModel.swift`.
- Для новых экранов и крупных правок использовать Screen/Page структуру:

```text
Screens/<Name>/
├── <Name>Screen.swift
├── <Name>ScreenProtocol.swift
├── <Name>ScreenViewModel.swift
├── <Name>ScreenDesign.swift
├── Components/
└── Pages/
    └── <PageName>/
        ├── <PageName>Page.swift
        ├── <PageName>PageView.swift
        ├── <PageName>PageViewModel.swift
        └── <PageName>PageDesign.swift
```

Все типы конкретного Screen/Page/Component объявлять внутри `extension <Name>Screen { ... }`, чтобы модуль имел один namespace и не разрастался глобальными типами.

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
- Все внешние provider-интеграции должны подключаться через MCP boundary, а не через прямые SDK/HTTP adapters внутри приложения.
- `AIProvider` остаётся внутренним протоколом WorkHarness; для внешних облачных/удалённых AI backend использовать MCP-backed provider adapter, который мапит MCP capability/result в `AIProvider`/`AIEvent`.
- База для MCP server уже подготовлена в `/Users/lammax/Documents/ThisIsMy/Programming/AI/MCP_server`; при реализации MCP-backed providers/tools использовать её как исходную локальную основу, если пользователь явно не указал другой сервер.
- Исключение: локальные CLI agent backends, такие как Codex CLI и Cursor CLI, могут быть отдельными CLI providers/adapters поверх `ProcessRunner`, если они выполняются локально и проходят через safety/approval boundaries.
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
- Не добавлять прямые `OpenAIProvider`, `AnthropicProvider`, `GeminiProvider`, `OpenRouterProvider` и аналогичные network-specific adapters в приложение; такие backends должны приходить через MCP.
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
  - создать commit с кратким описанием того, что заливается
  - сразу выполнить push текущей ветки
- Если пользователь сказал `закомить`, `сделай коммит`, `комит`, `commit` или аналогичную команду, трактовать это как `commit + push`: сначала проверить `git status`, создать commit с кратким описанием изменений, затем выполнить push.
- Если пользователь сказал `запушь`, `сделай push`, `пушни`, `пуш`, `push` или аналогичную команду без отдельного слова `commit`, трактовать это как `commit + push`: сначала проверить `git status`, создать commit с кратким описанием изменений, затем выполнить push.
- Если пользователь явно попросил `commit + push`, выполнить оба действия в этом порядке.
- Если пользователь попросил push, но рабочее дерево чистое и новых commit делать не из чего, выполнить только push текущей ветки.
- Никогда не использовать destructive git-команды (`git reset --hard`, `git checkout --`, массовые revert) без явной команды пользователя.

## 10. Цикл сборки (Build-Fix-Rebuild Loop)

После изменений в Swift-коде выполнять цикл валидации:

1. Запустить релевантную сборку:
   - `xcodebuild build -project WorkHarness.xcodeproj -scheme WorkHarness -destination 'platform=macOS'`
2. Если есть ошибки сборки — исправить их в этом же контексте.
3. Повторять build-fix-build до успешной сборки.
4. Для изменений в engine/service/view model/provider/repository запускать тесты:
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

## 15. Саммари при заполнении контекста

- Если контекст текущего чата заполнен на 95% или больше и активных действий больше не выполняется, агент должен сразу подготовить саммари для следующего чата.
- Не ждать отдельной просьбы пользователя, если задача остановилась из-за предела контекста, завершилась, заблокирована или больше нет выполняющихся команд/проверок.
- Саммари должно быть коротким, но достаточным для продолжения работы в новом чате.
- Обязательный формат саммари:
  - что сделано;
  - что осталось сделать по шагам.
- Если есть важные ограничения, незавершённые проверки, ошибки сборки, dirty git state или файлы с существенными изменениями, указать их в соответствующем пункте саммари.

## 16. Роли / специализация при декомпозиции задач

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

## 17. Архитектура Screen / Page

Обязательный стандарт при создании и редактировании крупных экранов, многошаговых flow и внутренних страниц WorkHarness. Дополняет разделы 1, 3 и 4.

### Как соотносятся Screen и Page

- `Screen` — верхнеуровневая область приложения или раздел навигации: владеет ViewModel/роутером, выбирает стартовую Page, управляет переходами между Page.
- `Page` — внутренний шаг или состояние Screen: не знает про глобальную навигацию приложения и не обращается напрямую к scene/window/app container.
- Screen ViewModel является точкой владения состоянием, page-моделями и навигационными методами для Page.
- Page и PageView передают user actions в Screen ViewModel или PageViewModel, но не мутируют стек страниц напрямую.

### Файловая структура Screen

Для новых сложных разделов использовать структуру:

```text
WorkHarness/Screens/<Name>/
├── <Name>Screen.swift
├── <Name>ScreenProtocol.swift
├── <Name>ScreenViewModel.swift
├── <Name>ScreenDesign.swift
├── <Name>ScreenState.swift
├── <Name>ScreenOption.swift
├── Components/
└── Pages/
    └── <PageName>/
```

Если проектная структура пока проще, допускается размещение в существующих `Views/`, `ViewModels/`, `Design/` только для общих/legacy типов. Для новых feature-модулей использовать `Screens/<Name>/...`.

- `*Screen.swift` / root `*View.swift` — тонкая композиция UI, binding и forwarding actions.
- `*ScreenViewModel.swift` — состояние Screen, создание/хранение page-моделей, роутинг Page, вызовы services/facades.
- `*ScreenDesign.swift` — UI-константы уровня Screen: layout, strings, icons, accessibility IDs.
- `*ScreenOption.swift` — входные параметры Screen, если нужны.
- `Components/` — переиспользуемые subviews домена.
- `Pages/<PageName>/` — файлы отдельной Page.
- Все типы, относящиеся к Screen или его Page/Components (`*View`, `*ViewModel`, `*Design`, `*Page`, state/options), объявлять внутри `extension <Name>Screen { ... }`, как namespace модуля.
- Для каждого модуля допускается только один `*Design.swift`. Если нужны группы констант для subview/component/state — использовать вложенные `enum`/`struct` внутри основного Design, а не создавать дополнительные design-типы рядом.
- Внутри каждого `*View` и private subview подключать дизайн локально через `typealias Design = <ModuleDesign>` или `typealias Design = <ModuleDesign>.<NestedSection>`, как в Artesia. В теле view обращаться к `Design.*`, а не к длинным полным именам.
- `*ViewModel` не выносить в общий `WorkHarness/ViewModels/`, если он принадлежит конкретному Screen/Page. Такой ViewModel должен лежать рядом с модулем и быть объявлен в `extension <Name>Screen`.
- `*ScreenProtocol` должен наследоваться от `BaseScreenProtocol`; Screen отдаёт `pagesModel`, а `BaseScreenProtocol.content` рендерит `PagesControlView`.
- `*Page` должен наследоваться от `BasePageProtocol` и хранить `content` как view соответствующей Page.

### Screen ViewModel как роутер страниц

- Screen ViewModel владеет текущей Page/стеком Page и предоставляет методы `show<Page>()`, `go<Page>()`, `back()` или их доменно-понятные аналоги.
- Page-моделям передавать callbacks с `[weak self]`, если callback удерживается дольше одного синхронного вызова.
- Screen ViewModel наследуется от `PagesViewModel`, создаёт стартовую Page и переключает Page через `show(page:)`/аналогичные методы.
- `Screen` управляет `Page`; `Page` не управляет `Screen`, `AppScene`, `AppContainer` или глобальной навигацией.
- `AppContainer` создаёт зависимости, ViewModel и root Screen; `AppScene` держит стек Screen уровня приложения.

### Dependency Injection

DI в WorkHarness следует Artesia-паттерну и использует Swinject как стратегический DI container:

- `AppContainer` владеет singleton `Swinject.Container` и открывает его как `AppContainer.resolver`.
- `AppContainer` создаёт `Container().synchronize() as! Container`, вызывает `registerDependencies()` и больше не собирает dependency graph вручную.
- `Container` предоставляет `register(...)`, `resolve(...)`, argument-based factories и scopes `.container` / `.transient`.
- `DependencyRegistration.registerDependencies()` вызывает отдельные регистрационные extension-файлы.
- Новые зависимости регистрировать в профильных файлах:
  - `RepositoriesRegister.swift`
  - `ServicesRegister.swift`
  - `ProvidersRegister.swift`
  - `EngineRegister.swift`
  - `ScreensRegister.swift`
  - `SceneRegister.swift`
- `WorkHarnessApp` получает root scene через `AppContainer.resolver.resolve(AppSceneProtocol.self)!`.
- `AppContainer` не должен вручную создавать весь граф зависимостей в init; он только настраивает контейнер.
- Shared state/services/repositories регистрировать через `.inObjectScope(.container)`.
- Screens/pages/view models, которые должны создаваться заново при каждом открытии, регистрировать через `.inObjectScope(.transient)`.
- Предпочитать регистрацию по protocol type, когда есть устойчивый protocol boundary.

### Services / Repositories

- Сервис является UI-facing/business boundary: ViewModel вызывает `*ServiceProtocol`, сервис координирует engine/repository/provider/tool зависимости.
- Репозиторий отвечает за data access/state storage и не содержит UI/business orchestration.
- Для сервисов использовать `*ServiceProtocol: BaseServiceProtocol`; для репозиториев — `*RepositoryProtocol: BaseRepositoryProtocol`, когда boundary устойчив.
- Сервисы и репозитории регистрировать в Swinject по protocol type.
- Предпочитать constructor injection в сервисах; прямой доступ к `AppContainer.resolver` держать только в composition root/DI factory, если нет веской причины.
- Запрещено: `ViewModel -> Repository`, `ViewModel -> Provider`, `ViewModel -> Tool`, если есть соответствующий сервисный boundary.

### Текущий закреплённый flow WorkHarness

Текущая стартовая цепочка:

```text
WorkHarnessApp
↓
AppContainer
↓
AppScene
↓
MainScreen
↓
MainShellPage
↓
ChatPage / RunsPage / PlaceholderPage
```

`MainScreen` — основной Screen приложения. `ChatPage` является UI-поверхностью над `Run`/`RunEvent`, а не самостоятельной доменной сущностью.
- Выход из Screen или смена глобального раздела выполняется только через Screen ViewModel / app-level navigation model.
- View не должна напрямую обращаться к app container, repositories, providers, tools или мутировать navigation stack.

### Файловая структура Page

Для Page использовать:

```text
Pages/<PageName>/
├── <PageName>Page.swift
├── <PageName>PageView.swift
├── <PageName>PageViewModel.swift
├── <PageName>PageDesign.swift
└── <PageName>PageState.swift
```

Правила Page:

- `*Page.swift` собирает Page и связывает PageView с нужной моделью.
- `*PageView.swift` содержит только UI-композицию и forwarding actions.
- `*PageViewModel.swift` нужен, если у Page есть собственное состояние или преобразование данных; иначе Page может работать от Screen ViewModel.
- `*PageDesign.swift` хранит константы и строки конкретной Page.
- Внутри одной Page не создавать несколько `*Design`-типов: subview-дизайн держать во вложенных секциях `*PageDesign`.
- Page не вызывает providers/tools/repositories напрямую и не знает про глобальную scene/window-навигацию.

### Чеклист при создании/правке Screen или Page

- [ ] Screen/root View тонкий; логика и роутинг в Screen ViewModel / navigation ViewModel.
- [ ] Page не знает про глобальную навигацию и не обращается к app container напрямую.
- [ ] View / ViewModel / Design разделены.
- [ ] Типы Screen/Page/Component объявлены внутри `extension <Name>Screen`.
- [ ] На каждый модуль ровно один Design-файл/Design-тип; детали оформлены вложенными секциями.
- [ ] Back/close actions проходят через ViewModel.
- [ ] Callbacks, которые могут удерживаться, используют `[weak self]`.
- [ ] Нет прямых обращений View -> provider/tool/repository.

## 18. Итоговое правило

Если правило из `agent-harness` skill и локальное правило из этого файла расходятся, применять более строгое правило, если пользователь явно не сказал иначе.
