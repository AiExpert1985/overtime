# architecture_overview

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

Read this before reading any other doc. Defines the platform, packages, layer rules, feature boundaries, and shared data concepts.

---

## Platform

Windows desktop only. Flutter latest stable.

---

## Packages

| Package | Purpose |
|---|---|
| `riverpod` ^3.x | State management — Riverpod 3.0 only |
| `go_router` | Navigation |
| `sqflite` | SQLite database |
| `sqflite_common_ffi` | Required for Windows desktop SQLite support |
| `excel` | Excel reading and writing |
| `file_picker` | Windows file picker dialog |
| `path_provider` | Resolve Downloads folder path for export |
| `intl` | Arabic date and number formatting |

---

## Riverpod 3.0 Conventions

- Use `AsyncNotifier` + `AsyncNotifierProvider` for async operations.
- Use `Notifier` + `NotifierProvider` for synchronous state.
- **Never use** `StateProvider`, `StateNotifierProvider`, or `ChangeNotifierProvider` — these are legacy.
- Providers defined at top level only, never inside widgets.
- Widgets extend `ConsumerWidget` or `ConsumerStatefulWidget`.

---

## Localization

Single locale: Arabic (`ar`), RTL. Applied globally at app root. All user-facing strings written directly in Arabic — no ARB files.

---

## Windows Initialization

Two calls required in `main()` before `runApp()`, in this order:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `sqfliteFfiInit()` + set `databaseFactory = databaseFactoryFfi`

Omitting either causes silent runtime failure.

---

## Layer Architecture

Four layers. Communication flows downward only — never upward, never sideways.

| Layer | Owns | Rule |
|---|---|---|
| Presentation | Widgets, providers | Renders state. Forwards user intent to services. No calculations, no business conditions, no logic of any kind. |
| Application | Services | All business rules live here. Services write state to providers. Services call other services within the same feature freely. |
| Domain | Plain model objects | No logic, no dependencies on any other layer. |
| Data | Repositories | All database access. Nothing above this layer knows what is behind it. |

---

## Key Rules

- Providers call services and expose the result. No business logic inside providers.
- Screens observe providers only. Widgets never call services or repositories directly.
- Failures are typed exceptions caught at the service boundary, translated into Arabic messages for the user.
- No abstract repository interfaces — one concrete implementation per repository.
- No event system — flow is linear: parse → detect → calculate → store → display.
- Report screens always load from the database — including newly generated reports. There is no in-memory hand-off path. Store first, then load, then navigate.
- Aggregate totals are never stored — always computed live from stored rows.

---