# architecture_overview

**Created**: 27-Apr-2026
**Modified**: 12-May-2026

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

## Features

**FileProcessing** — reads and validates the attendance Excel file, produces `AttendanceRecord` objects. No overtime logic. No employee or holiday file parsing.

**ReferenceData** — owns the permanent employees and holidays tables. Provides employee lists (for selection UI and for report generation) and the holidays list (for day classification). No overtime logic.

**Reporting** — consumes parsed attendance records, employee data, and holidays from the other features. Runs calculations, persists results, owns all report screens and the report generation screen. No file parsing.

**Dependency direction:** Reporting → FileProcessing. Reporting → ReferenceData. Never the reverse. ReferenceData and FileProcessing do not depend on each other.

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

## Feature Boundaries

Each feature owns its models, its service, and its repository. The rules below are absolute:

- **The service is the only public interface of a feature.** When one feature needs something from another, it calls that feature's service — never its repository, never its models directly.
- **No feature reaches into another feature's internals.** Dependency direction: Reporting → FileProcessing, Reporting → ReferenceData. Never the reverse. ReferenceData and FileProcessing do not depend on each other.
- **A feature must be removable without changing any other feature's code.** If removing a feature requires editing another feature, the boundaries are wrong.
- **Intra-feature calls are allowed.** Two services within the same feature may call each other directly. The boundary rules apply across features only.

---

## Key Rules

- Providers call services and expose the result. No business logic inside providers.
- Screens observe providers only. Widgets never call services or repositories directly.
- Failures are typed exceptions caught at the service boundary, translated into Arabic messages for the user.
- No abstract repository interfaces — one concrete implementation per repository.
- No event system — flow is linear: parse → calculate → store → display.
- Report screens always load from the database — including newly generated reports. There is no in-memory hand-off path. Store first, then load, then navigate.

---

## Shared Domain Objects

Defined in `data_shared_models.md`. Split into three groups:

**Input objects** — produced by FileProcessing or ReferenceData, consumed by Reporting:
- **Employee** — id, number, name, employment type, department. Produced by ReferenceData from the employees table.
- **AttendanceRecord** — employee name + raw sorted fingerprint timestamps. Produced by FileProcessing from the attendance file.
- **Holiday** — date + occasion name. Produced by ReferenceData from the holidays table.

**Extractor output objects** — produced by period extractors, consumed by calculators:
- **RawDailyEmployeePeriods** — name, department, periods with day type and timestamps
- **RawShiftEmployeePeriods** — name, department, periods with anchor timestamp and timestamps

**Calculator output objects** — produced by calculators, stored to DB, read by report screens:
- **DailyEmployeeResult** — daily overtime breakdown with per-period detail
- **ShiftEmployeeResult** — shift overtime breakdown with per-period detail

---

## Document Map

| Doc | Covers |
|---|---|
| `architecture_overview.md` | This document — platform, packages, layers, rules |
| `main_workflow.md` | 6-stage app flow — start here after architecture_overview |
| `router.md` | Routes, parameters, navigation rules |
| `database_schema.md` | Tables, columns, relationships, versioning |
| `data_shared_models.md` | All shared data objects — input, extractor output, calculator output |
| `config.md` | All thresholds, constants, configurable defaults with Arabic descriptions |
| `period_extractor_daily.md` | Daily period extractor algorithm |
| `period_extractor_shift.md` | Shift period extractor algorithm |
| `overtime_calculation_daily.md` | Daily employee validity rules and overtime calculation |
| `overtime_calculation_shift.md` | Shift employee validity rules and overtime calculation |
| `file_processing.md` | Attendance file — parsing and validation |
| `dictionary_build.md` | Dictionary build — Stage 3 detail: filtering, merging, name matching |
| `screen_employees.md` | Employees management screen — CRUD for permanent employee list |
| `screen_holidays.md` | Holidays management screen — CRUD for permanent holidays list |
| `screen_report_generate.md` | Report generation screen — attendance file, date range, employee selection |
| `screen_report.md` | Report screen — two tabs, employee tables |
| `screen_detail.md` | Detail screen — period breakdown for both employee types |
| `screen_report_list.md` | Report List Screen — list of all generated reports, delete |
| `screen_configuration.md` | Configuration screen — numeric settings and attendance column headers |
