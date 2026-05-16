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

## 20260516-0000 | App Foundation & Navigation Shell | TASK

**Task:** Replaced the default Flutter counter app with the full app foundation for a Windows-only overtime calculation tool. Set up Windows SQLite initialization, Riverpod ProviderScope with a database provider override, Arabic RTL locale, go_router two-tab shell (Reports / Settings), all five named routes, full SQLite schema with FK cascade for all result and config tables, and seeded default column headers and app settings. All screens are stubs pending feature implementation.

---
