# Obelisk History

---

## Task 1 — App Foundation & Navigation Shell
**Completed:** 2026-05-16

### What was built
- `pubspec.yaml` — added all 8 packages: flutter_riverpod ^3.3.1, go_router ^17.2.3, sqflite ^2.4.2+1, sqflite_common_ffi ^2.4.0+3, excel ^4.0.6, file_picker ^11.0.2, path_provider ^2.1.5, intl ^0.20.2, plus flutter_localizations (SDK)
- `lib/main.dart` — Windows SQLite init (sqfliteFfiInit + databaseFactoryFfi), ProviderScope with db override, Arabic RTL locale, MaterialApp.router
- `lib/core/database/database.dart` — opens DB at app support path, creates all 8 tables with FK cascade, seeds column_headers (3 defaults) and app_settings (12 defaults), schema version 1
- `lib/core/router/router.dart` — StatefulShellRoute.indexedStack two-tab shell (التقارير / الإعدادات), all 5 named routes (reports, report_generate, report, detail, settings), error route
- `lib/features/reports/screens/` — 4 stub screens (ReportsListScreen, ReportGenerateScreen, ReportScreen, ReportDetailScreen)
- `lib/features/settings/screens/settings_screen.dart` — stub screen

### Outcome
`flutter analyze` — No issues found.

### Decisions
- Database file stored at `getApplicationSupportDirectory()/overtime.db` via path_provider
- `dbProvider` is a `Provider<Database>` that throws if not overridden — overridden in `main()` via ProviderScope.overrides
- Router defined as a top-level `GoRouter` final (no provider needed at this stage)
- All stub screens use `ConsumerWidget` per Riverpod 3.0 conventions

### Deferred
- Actual feature logic for all screens (providers, services, repositories)
- Theme and visual styling beyond RTL locale
- Export logic

---

## Task 2 — Settings Screen & Configuration Repository
**Completed:** 2026-05-16

### What was built
- `lib/features/settings/domain/app_settings.dart` — `AppSettings` model with all 11 configurable fields, `dailyEndTime` and `zoneCount` derived getters, `copyWith`, `fromMap` (parses `shift_start_times` from JSON)
- `lib/features/settings/domain/column_header.dart` — `ColumnHeader` model with `fromMap`
- `lib/features/settings/data/settings_repository.dart` — `SettingsRepository` (concrete, no interface): `loadSettings`, `updateSetting`, `loadColumnHeaders` (ordered: defaults first), `addColumnHeader`, `updateColumnHeader`, `deleteColumnHeader` (all non-default guards)
- `lib/features/settings/providers/settings_provider.dart` — `settingsRepositoryProvider`, `SettingsNotifier` (AsyncNotifier, optimistic update via `AsyncData(apply(current))`), `settingsProvider`, `ColumnHeadersNotifier` (AsyncNotifier, reloads from DB after each mutation), `columnHeadersProvider`
- `lib/features/settings/screens/settings_screen.dart` — Full Settings screen: Daily section (time picker + 3 number fields + derived end time), Shift section (start times list + 5 number fields + derived zone count), Display section (`RadioGroup` + 4 `RadioListTile`), Column Headers section (3 cards with add/edit/delete dialogs); immediate persistence with revert+snackbar on invalid input

### Outcome
`flutter analyze` — No issues found.

### Decisions
- No service layer — settings are pure CRUD, repository → provider directly
- `max_report_date_range` stored in DB but not shown in UI (monthly reports only)
- `SettingsNotifier._save` uses Dart 3 pattern matching (`AsyncData(:final value)`) instead of deprecated `valueOrNull`
- `ColumnHeadersNotifier` method renamed from `update` to `updateHeader` to avoid conflict with inherited `AsyncNotifier.update`
- `RadioGroup` used instead of deprecated `groupValue`/`onChanged` on `RadioListTile` (Flutter 3.32+)
- `alwaysUse24HourFormat: true` injected via `MediaQuery` wrapper in `showTimePicker`
- Controllers initialized once on first data load via `_initialized` flag in `ConsumerStatefulWidget`
- Number fields persist on focus-loss (`Focus.onFocusChange`) and on Enter (`onSubmitted`)

### Deferred
- Theme and visual styling beyond Material 3 defaults
- Export logic
- Report screens feature logic

---

## 20260516-0000 | App Foundation & Navigation Shell | TASK

**Task:** Replaced the default Flutter counter app with the full app foundation for a Windows-only overtime calculation tool. Set up Windows SQLite initialization, Riverpod ProviderScope with a database provider override, Arabic RTL locale, go_router two-tab shell (Reports / Settings), all five named routes, full SQLite schema with FK cascade for all result and config tables, and seeded default column headers and app settings. All screens are stubs pending feature implementation.

---

## 20260516-0100 | Settings Screen & Configuration Repository | TASK

**Task:** Implemented the full Settings screen (Tab 2) backed by a configuration repository reading and writing the app_settings and column_headers SQLite tables. Covers four sections: daily employee settings, shift employee settings, display rounding mode, and column header management. All changes persist immediately on input. Invalid values revert to the last valid value with an Arabic snackbar. The max_report_date_range setting is stored but not exposed in the UI — reports are always monthly. No service layer was introduced; the repository talks to the provider directly.

**Rejected:** Service layer between repository and provider — no business rules exist in settings, adding one would be speculative abstraction.

---

## 20260516-0200 | Reports List Screen | TASK

**Task:** Implemented Tab 1 (Reports List Screen) — shows all generated reports in a table ordered by generation datetime descending. Tapping a row navigates to the Report screen. A FAB at the bottom-left (RTL start position) pushes the Report Generation screen. Delete shows an Arabic confirmation dialog and cascades through all child data. The tab refreshes its list from the database whenever the user switches back to the Reports tab (via `_AppShell` invalidation) or after a delete. No service layer — pure CRUD, repository → provider directly.

**Rejected:** DataTable widget — custom ListView with explicit GestureDetector/InkWell split gives cleaner control over row-tap vs delete-button hit areas in RTL layout.

---

## 20260516-0300 | Report Generation Screen | TASK

**Task:** Implemented the Report Generation screen (pushed from the Reports List FAB). Full UI: attendance file list card with empty/with-files states, file picker integration (xlsx/xls, multi-select, max 10 files, duplicate dedup), info hint dialog, date range pickers with inline Arabic validation (end before start, range exceeds max), and a Generate button whose enabled/disabled condition is wired to state. Generate button tap is a no-op — generation wired in a later task. All screen state lives in a Notifier provider. Added `maxReportDateRange` to AppSettings (was stored in DB but not exposed in the model). File validation (Excel parsing, column header lookup) is deferred to the next task — all added files are stubbed as valid.

---

## 20260516-0400 | File Upload & Validation | TASK

**Task:** Replaced stub file validation with real Excel parsing. Files appear in the list immediately with a loading spinner while validation runs async. A new service (application layer) reads all sheets per file, matches header values against the column_headers table, and verifies at least one valid data row exists. Files that fail header matching or are unreadable get a template-mismatch error; files with valid headers but no valid rows get a no-valid-rows error. The excel package only supports .xlsx internally — .xls files are caught and treated as invalid. The Generate button does not count files still being validated.

---

## 20260517-0000 | Generation Pipeline — Stage 6: Shift Period Extractor | TASK

**Task:** Implemented Stage 6 of the report generation pipeline — shift period extractor. For each shift employee, the report date range is walked day by day; each calendar day defines a period window anchored to the employee's detected start time. Timestamps falling in a window are grouped into that period and bucketed across N contiguous zones. Each zone is marked satisfied only if it contains a timestamp within tolerance of the zone's center time. Periods with fewer than 2 satisfied zones are discarded. Timestamps near the boundary of two adjacent period windows are intentionally stored in both. Two new domain models were introduced: one for zone-level data (set entirely by this stage) and one for period-level data (base fields set here; calculated fields left null for Stage 8 to fill). The shift employee entry model was extended with a mutable period list populated by this stage.

---

## 20260517-0100 | Generation Pipeline — Stage 7: Daily Period Extractor | TASK

**Task:** Implemented Stage 7 of the report generation pipeline — daily period extractor. A new `DailyPeriod` model carries extractor-set fields (periodIndex, date, weekday, dayType, allTimestamps) with calculator fields left null for Stage 9. A new `DailyEmployeeEntry` model mirrors `ShiftEmployeeEntry` and carries the periods list. The `extractDailyPeriods` method on `GenerationService` takes the daily hash table and the off-days set from Stage 5, groups each employee's timestamps by calendar date using the existing `_groupByDay` helper, classifies each day as regular or off via off-days set membership, and builds `DailyPeriod` objects in ascending date order. Returns a new `Map<String, DailyEmployeeEntry>`. Arabic weekday names derived via a static 7-element lookup. Days with exactly 1 timestamp are included — validity is Stage 9's responsibility.

---

## 20260517-0200 | Generation Pipeline — Stage 8: Shift Overtime Calculator | TASK

**Task:** Implemented Stage 8 of the report generation pipeline — shift overtime calculator. Each `ShiftPeriod` is enriched in place with its end date, total attendance duration, validity flag (all zones must be satisfied), hours counted (24 if valid, 0 if not), and Arabic notes if invalid. Per-employee overtime is then computed by summing hours counted, capping at the ceiling, subtracting the baseline, and storing the result in minutes for consistency with daily employees. The `ShiftEmployeeEntry` model was extended with an `overtimeMinutes` field set by this stage. The calculator is a standalone method on `GenerationService` with clear input and output — no UI changes, no DB changes.

---

## 20260517-0500 | Report Screen | TASK

**Task:** Implemented the Report Screen — the main results view for a generated report. The screen loads all three employee result sets from the database on mount and displays them across three tabs (shift / daily / undetected). Each detected tab has live summary cards (total employees, included employees, total overtime), a filter bar with radio buttons (محتسبون / مستثنون), a live search field, and an Excel export button. Employee tables show inclusion toggles that write to the database immediately and update summary totals in place without a full reload. Tapping an employee row navigates to the Detail screen via route parameters. The undetected tab is read-only with search only (no radio, no export). Three new display-side domain models were introduced (separate from pipeline models). The repository was extended with display query methods and a period-loading method used at export time. The Riverpod 3.x family provider pattern uses a constructor-arg notifier (not `FamilyAsyncNotifier`, which does not exist in 3.x). Excel export fetches period details on demand at export time and saves via a Save As dialog. Period details are not loaded or held in memory by this screen.

**Rejected:** Auto-save to a fixed directory for export — Save As dialog chosen so the user controls the destination.

---

## Agreed Task Sequence (Deferred)

The following tasks were agreed during discovery and must be implemented in order:

1. ~~**Report Generation Screen**~~ ✓ Done
2. ~~**File Upload & Validation**~~ ✓ Done
3. **Generation Pipeline — Stage by Stage** — Implement the 10-stage pipeline function by function per `main_workflow.md`: dictionary build → schedule detection → off-day detection → ~~shift period extractor~~ ✓ Done → ~~daily period extractor~~ ✓ Done → ~~shift overtime calculator~~ ✓ Done → ~~daily overtime calculator~~ ✓ Done → storage → wire Generate button.

**Confirmed 2026-05-16:** Staged implementation order confirmed by user. One stage per task, validated before the next begins. Stages map 1:1 to `main_workflow.md` pipeline stages.

---

## 20260516-0500 | Generation Pipeline — Stage 3: Dictionary Build | TASK

**Task:** Implemented Stage 3 of the report generation pipeline — dictionary build. A single pass over all valid attendance Excel files and their sheets collects all records within the selected date range, building one entry per unique employee name with their department and sorted timestamp list. File-level read errors abort generation with an Arabic exception; row-level issues (missing fields, unparseable datetime) are silently skipped. `GenerationService` is introduced as the single service class that will host all pipeline stages in sequence — only Stage 3 is implemented now. Generate button wiring is deferred to the final pipeline task.

---

## 20260516-0600 | Generation Pipeline — Stage 4: Schedule Detection | TASK

**Task:** Implemented Stage 4 of the report generation pipeline — schedule detection. A new synchronous `detectSchedules` method on `GenerationService` classifies every dictionary employee into one of three buckets: shift, daily, or undetected. Algorithm 1 applies a 20% attendance density pre-check, a 20% usable-day check, zone bucketing (24/interval zones), and a 75%-confidence employment-type vote. Algorithm 2 runs only for confirmed shift employees and uses a 60%-confidence start-time vote against all configured start times plus an unmatched bucket. Three new domain models carry the output: a shift entry (with detected start time as a string matching the configured value), an undetected entry (with one of four Arabic failure reasons), and a result container holding all three buckets. All logic is pure in-memory with no I/O.

---

## 20260516-0700 | Generation Pipeline — Stage 5: Off-Day Detection | TASK

**Task:** Implemented Stage 5 of the report generation pipeline — off-day detection. A synchronous `detectOffDays` method on `GenerationService` takes the daily hash table and the report date range, enumerates every calendar date in the range, counts attending employees per date, and returns a set of dates where attendance fell strictly below the 25% hardcoded threshold. Empty daily table returns an empty set immediately. No new files or domain models — threshold defined as a private constant on the service. Output is consumed by Stage 7 (daily period extractor).

---

## 20260517-0300 | Generation Pipeline — Stage 9: Daily Overtime Calculator | TASK

**Task:** Implemented Stage 9 of the report generation pipeline — daily overtime calculator. Each daily period is validated and enriched with its overtime result. Regular-day validation requires at least two timestamps and the first stamp within the configured delay allowance; overtime is the time worked beyond the derived end-of-day, capped at the daily maximum. Off-day validation requires only two timestamps; overtime is the full attendance span, capped at the same maximum. Both failure cases produce Arabic notes per spec. The daily employee entry model was extended with a total overtime field set by this stage, mirroring the Stage 8 shift pattern, so Stage 10 storage can read it directly. A stale sentence in `overtime_calculation_daily.md` ("computed live at display time — never stored") contradicts the final design; `data_shared_models.md` is authoritative — total is computed at generation time and stored.

---

## 20260517-0400 | Generation Pipeline — Stage 10: Storage & Wire Generate Button | TASK

**Task:** Implemented Stage 10 — the final pipeline stage. All three result sets (shift employees with period details, daily employees with period details, undetected employees) are persisted to SQLite in a single atomic transaction. Timestamps and zone data are serialized as JSON strings per the schema. The Generate button now runs the full 10-stage pipeline end to end; on success the generate screen is replaced by the newly created report screen, the reports list provider is invalidated, and the form state is cleared. On failure, all inputs are preserved and a dismissible Arabic error banner appears. The screen is fully non-interactive during generation via a modal barrier. The generation orchestration lives entirely in the provider notifier — no logic in the screen.

---
