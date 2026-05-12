# Obelisk Task History

## 20260507-1200 | Project Foundation Setup | TASK

**Task:** Bootstrapped the project from blank Flutter boilerplate. Added all required packages (riverpod, go_router, sqflite + sqflite_common_ffi, excel, file_picker, path_provider, intl, flutter_localizations). Created the feature-first folder structure (file_processing, reporting, shared). Set up the SQLite database with all 7 tables and first-launch seeding for 13 app_settings defaults and 7 default column headers. Configured go_router with a StatefulShellRoute tab shell (3 tabs, state preserved across switches) and all 6 named routes. Replaced the boilerplate main.dart with the proper app root: Windows SQLite FFI init before runApp, ProviderScope, Arabic locale, RTL, and GlobalLocalizations delegates. Created bare placeholder screens for all routes. All shared domain models defined as plain data containers.

**Rejected:** Riverpod code generation (riverpod_generator + build_runner) — user chose manual providers instead.

---

## 20260507-1500 | File Processing Feature + Input Screen | TASK

**Task:** Implemented Stage 1 of the main workflow — Excel file upload, validation, and Input screen UI. FileProcessing has no owned DB tables; shared config (column headers, max date range) is read through two shared repositories added to the shared layer. The file processing service is stateless: it accepts file paths and column headers, validates per-sheet headers against DB-stored acceptable values, checks row validity, and returns a sealed success/failure result. Input screen state (file card states, parsed data, date range) lives in a non-auto-dispose provider so it survives tab switches. The Generate button is fully wired for enabled/disabled state but its tap action is a stub — report generation (Stages 3–6) is deferred to the next task.

**Rejected:** Connecting the Generate button to any generation logic — deferred by design. Date range validation (max range check) was confirmed to belong to the Input screen, not the FileProcessing service.

---

## 20260507-1600 | Input Screen Bug Fix + UI Redesign | TASK

**Task:** Fixed two silent failure bugs and redesigned the Input screen layout. Bug 1: file pick methods were async futures dropped into void callbacks — exceptions silently died without updating state; fixed with try/catch that drives both card error state and a dismissible error notification. Bug 2: the database file already existed from a prior run, so the schema's `onCreate` was skipped and `column_headers` was never created; fixed by moving schema creation to `onOpen` with idempotent `IF NOT EXISTS` guards and a count-based seed guard for default rows. Layout change: the three file upload cards now sit in a single centered horizontal row rather than stacked vertically; date range pickers and the Generate button are centered below. A teal Material 3 color theme was applied app-wide. Card states have distinct background tints (valid = green, invalid = red).

**Rejected:** Reordering the layout (file cards remain above date pickers, per design doc).

---

## 20260507-1700 | Settings Screen + Column Header Management | TASK

**Task:** Implemented the Settings screen (Tab 3) with all four sections and the Column Header Management sub-screen. SettingsRepository expanded with `getString`, `setValue`, `getShiftStartTimes`, and `setShiftStartTimes`. ColumnHeadersRepository expanded with a `ColumnHeaderItem` model and full CRUD (add, update, delete, existence check). `SettingsNotifier` (AsyncNotifier) loads all 13 settings from DB on mount and persists each change immediately on field confirm. `ColumnHeadersNotifier` (AsyncNotifier) manages the CRUD screen state and increments `headersVersionProvider` after every mutation. The Input screen notifier listens to `headersVersionProvider` and resets all file cards to empty whenever headers change, preventing stale validation state. DB migration added to `_seedDefaults` (idempotent UPDATE) to upgrade existing installs from `shift_start_times = ["08:00"]` to `["08:00","11:00"]`; fresh-install seed also updated. Settings screen includes: time picker for daily start time with derived end-time display, number-input dialogs for all numeric settings, shift start times chip list with add/delete, derived zone count display, rounding mode radio group (using RadioGroup API), and navigation row to the Column Header Management sub-screen. Column Header Management screen lists all headers grouped by file type → field, with lock icon on defaults and edit/delete icons on user-added values; add/edit dialogs validate non-empty and uniqueness per field before writing.

**Rejected:** Nothing deferred — all agreed scope delivered.

---

## 20260508-1200 | Report Generation — Stages 2–6 | TASK

**Task:** Wired the Generate button to run the full report generation pipeline (Stages 2–6). Dictionary build, period extraction, and overtime calculation are pure functions in the reporting application layer. A generation service orchestrates the pipeline and persists results to the database in a single transaction. Generation state is managed by a dedicated notifier that the Input screen observes — handling the loading indicator, unmatched-employee review dialog (continue / abort / export names to Excel), error snackbar, and post-success navigation. On success the app navigates directly to the new report and refreshes the reports list. All three stub screens (Reports List, Report, Detail) are fully implemented and load exclusively from the database. The reports list refreshes via a version counter incremented after generation and after delete. Rounding is display-only; raw minutes are always stored.

**Rejected:** Excel export button on the Report screen — deferred to next task.

---

## 20260509-1200 | Excel Export from Report Screen | TASK

**Task:** Implemented the Excel export button on the Report screen. A new application-layer service builds a two-sheet `.xlsx` saved to Downloads: Sheet 1 mirrors the Report screen (summary header + daily table + shift table); Sheet 2 mirrors the Detail screen (one section per matched employee, daily then shift, alphabetical, with header info and period rows). An auto-dispose notifier manages export state. The Report screen listens for success/error and shows snackbars; the action bar with loading-aware button sits between the report header and the tab bar. Rounding logic is duplicated in the service to respect the no-upward-import rule.

**Rejected:** Including unmatched employees in Sheet 2 — no detail view exists for them, so they are omitted.

---

## 20260509-1500 | Name Matching Fix + Additive Multi-File Upload | TASK

**Task:** Fixed two issues. (1) Name mismatch bug: Excel embeds invisible Unicode characters (RTL/LTR marks, zero-width spaces, BOM, directional embeddings, non-breaking spaces) in Arabic text cells that standard trim() does not remove, causing names that look identical to fail the exact-string dictionary lookup. The fix strips these characters from all cell values and column headers at parse time. (2) All three file cards (attendance, employees, holidays) now support incremental additive uploads: each pick appends new files to the existing list rather than replacing it; duplicate paths are silently skipped. Each file is parsed individually and carries its own valid/invalid status. The card displays a count + validity summary line that opens a list dialog showing each file's name, status chip, and a delete button; the dialog auto-closes when the last file is removed. The holidays card was upgraded from single-file-only to multi-file, matching the other two cards. Card validity requires all entries to be valid; the generate button remains disabled while any file is invalid.

**Rejected:** "Replace all" button in the valid state — removed entirely; users delete unwanted files via the dialog instead.

---

## 20260511-1200 | Attendance Timestamp Parser Fix | TASK

**Task:** Fixed the attendance file timestamp parser to correctly handle the real-world format `M/D/YYYY H:MM:SS AM/PM` (e.g. `10/2/2025  7:53:07 AM`). Two bugs were present: (1) the parser treated position 1 as day and position 2 as month (D/M order), but the attendance file uses M/D order — months and days were swapped for all text-cell timestamps; (2) AM/PM suffixes were not handled, causing the regex to fail entirely for 12-hour timestamps. The fix corrects the group order, adds AM/PM capture with 12→24-hour conversion (12 AM → midnight, 12 PM stays noon). Additionally, silent row-skipping on unparseable datetime cells was replaced with a fail-fast failure returned immediately, surfacing an Arabic error on the file card instead of producing a silently incomplete report.

---

## 20260511-1500 | Report + Detail Screen Scrollable and Centered | TASK

**Task:** Made the data tables in the Report screen (Daily and Shift tabs) and the Detail screen (Daily and Shift variants) both scrollable and horizontally centered. Tables are centered on screen when narrower than the screen width, and horizontally scrollable when wider. The Report screen tabs also support vertical scrolling within their fixed-height tab area.

---

## 20260511-1600 | File Parse Exception Logging | TASK

**Task:** Added debug logging to the file open helper so that the real exception and stack trace are printed to the console whenever a file fails to decode. Previously all exceptions were silently swallowed, making it impossible to diagnose why a file was rejected.

**Rejected:** XLS file support — not in scope; files in the legacy binary `.xls` format are intentionally unsupported and the existing "file invalid" error is acceptable.

---

## 20260512-0000 | Report Screen Scroll + Row Navigation Fix | TASK

**Task:** Fixed two bugs on the Report screen. (1) DataTable tabs (Daily and Shift) were not vertically scrollable — the scroll nesting was reversed (horizontal outer, vertical inner) which doesn't work reliably on Windows desktop; fixed by making vertical the outer scroll and horizontal the inner, matching the Detail screen's approach. (2) Tapping a matched employee row did nothing — the checkbox column rendered by default when `onSelectChanged` is set was interfering with hit-testing on desktop; fixed by setting `showCheckboxColumn: false` on both DataTables. Navigation callback itself (`goNamed('detail', ...)`) was already correct.

---

## 20260512-1200 | Excel numFmt Styles Compatibility Fix | TASK

**Task:** Fixed a crash when uploading xlsx files that declare built-in numFmt IDs (< 164) in their custom numFmts section — a format produced by some Excel variants. The `excel` package rejects these with a hard exception. The fix pre-processes the raw xlsx bytes before parsing: unzips the file, strips the offending `<numFmt>` entries from `xl/styles.xml`, updates the count attribute, and rezips. If pre-processing fails for any reason the original bytes are passed through unchanged. The `archive` package (already a transitive dependency at 3.6.1) was made an explicit dependency.

---

## 20260512-1400 | Report Screen Live Search and Filter | TASK

**Task:** Added a combined search-and-filter bar to the Report screen, sitting between the report header and the tab bar. The bar contains: a live search field (filters by employee name or department on each keystroke, scoped to the active tab); three filter chips (مع وقت إضافي / بدون وقت إضافي / غير موجودين) all checked by default — unchecking any hides that category; and the Excel export button at the end of the same row. Search and filter combine with AND logic. When the combined filter yields an empty list the tab shows "لا توجد نتائج مطابقة" instead of the normal empty-report message. The export action continues to export the full unfiltered data. The separate Action Bar row was removed; the export button was folded into the unified bar.

**Rejected:** Per-tab separate search fields — a single shared field covers the active tab. Hiding unmatched employees from search results — they are included if their name/department matches.
