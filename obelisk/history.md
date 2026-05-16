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

## Agreed Task Sequence (Deferred)

The following tasks were agreed during discovery and must be implemented in order:

1. **Report Generation Screen** — Full UI (file list card, date range pickers, Generate button) with all elements present but Generate non-functional. Stub screen only.
2. **File Upload & Validation** — Stage 1: file picker (up to 10 Excel files), column header validation against `column_headers` table, Arabic error messages.
3. **Generation Pipeline — Stage by Stage** — Implement the 10-stage pipeline function by function per `main_workflow.md`: dictionary build → schedule detection → off-day detection → shift period extractor → daily period extractor → shift overtime calculator → daily overtime calculator → storage → wire Generate button.

---
