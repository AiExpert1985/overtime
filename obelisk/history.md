# Obelisk Task History

## 20260507-1200 | Project Foundation Setup | TASK

**Task:** Bootstrapped the project from blank Flutter boilerplate. Added all required packages (riverpod, go_router, sqflite + sqflite_common_ffi, excel, file_picker, path_provider, intl, flutter_localizations). Created the feature-first folder structure (file_processing, reporting, shared). Set up the SQLite database with all 7 tables and first-launch seeding for 13 app_settings defaults and 7 default column headers. Configured go_router with a StatefulShellRoute tab shell (3 tabs, state preserved across switches) and all 6 named routes. Replaced the boilerplate main.dart with the proper app root: Windows SQLite FFI init before runApp, ProviderScope, Arabic locale, RTL, and GlobalLocalizations delegates. Created bare placeholder screens for all routes. All shared domain models defined as plain data containers.

**Rejected:** Riverpod code generation (riverpod_generator + build_runner) — user chose manual providers instead.

---

## 20260507-1500 | File Processing Feature + Input Screen | TASK

**Task:** Implemented Stage 1 of the main workflow — Excel file upload, validation, and Input screen UI. FileProcessing has no owned DB tables; shared config (column headers, max date range) is read through two shared repositories added to the shared layer. The file processing service is stateless: it accepts file paths and column headers, validates per-sheet headers against DB-stored acceptable values, checks row validity, and returns a sealed success/failure result. Input screen state (file card states, parsed data, date range) lives in a non-auto-dispose provider so it survives tab switches. The Generate button is fully wired for enabled/disabled state but its tap action is a stub — report generation (Stages 3–6) is deferred to the next task.

**Rejected:** Connecting the Generate button to any generation logic — deferred by design. Date range validation (max range check) was confirmed to belong to the Input screen, not the FileProcessing service.

---
