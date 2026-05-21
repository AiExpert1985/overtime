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

## 20260517-0600 | Detail Screen | TASK

**Task:** Implemented the Detail Screen — the last unimplemented screen. Reached by tapping an employee row on the Report Screen. Fetches its own period data on mount. Shift employees show a fixed header with live-computed overtime (ceiling and baseline from current settings at display time, not the stored value) and a period table where zones are stacked vertically per row — invalid zones are visually flagged. Daily employees show a header with stored total overtime (rounded per current rounding mode) and a nine-column period table. Both tables use light red row backgrounds for invalid periods. Three display-side domain models were introduced to separate DB deserialization from the pipeline's in-memory generation models. The repository was extended with two methods to load individual employee result rows for the header. Provider uses the constructor-arg family pattern consistent with the Report Screen.

---

## 20260517-0700 | Report & Detail UX Improvements | TASK

**Task:** Three independent improvements to the Report and Detail screens. (1) Undetected employee detail screen: Stage 4 now carries raw timestamps through UndetectedEntry. A new `undetected_period_details` table (schema v2, migration added) stores one row per calendar day per employee. The existing `detail` route was extended with a third type (`undetected`) rather than adding a new route. The detail screen shows a header with name, department, date range, and failure reason, plus a timestamp-per-day table. Old reports without stored period data show a graceful Arabic empty-state. Valid day = any day with ≥1 timestamp. (2) Zone window display: zone checkpoint labels in the shift detail table now show the full window (start and end) in AM/PM format, matching the timestamp format already used throughout the screen. (3) Overtime presence filter: shift and daily tabs gain a secondary radio filter (الكل / بوقت إضافي) applied after the محتسبون/مستثنون radio and before the search field. Default is "الكل". Filter state lives in the report notifier alongside existing filter state.

---

## 20260519-0000 | Animated Generation Overlay | TASK

**Task:** Replaced the modal barrier shown during report generation with a pluggable, animated full-screen overlay. A self-contained `GenerationOverlay` widget accepts a list of `GenerationPhase` objects (each with a label and configurable duration, default 4 s) and a generation future, then runs the phase animation in parallel with the pipeline. Navigation fires only when both the animation sequence and the pipeline complete. If the pipeline errors, the animation is interrupted immediately and the existing error banner is shown. The overlay displays a pulsing gold magic-wand icon, a fade+slide phase label transition, and animated progress dots — all inside a centered dialog box sized at ¼ screen width × ¼ screen height with a semi-transparent backdrop. Phases are defined in the generate screen and passed to the widget, keeping the overlay free of business logic. The generate screen was converted to a stateful widget to hold the active future reference.

---

## 20260519-0100 | Home Screen & Drawer Navigation Restructure | TASK

**Task:** Replaced the two-tab bottom-nav shell with a flat router where the report generation screen is the root. History and Settings are now reached via a side drawer, both opened with push navigation so the back button always returns to the home screen. The reports list FAB was removed — new reports start only from the home screen. AppBar titles added to the history and settings screens. The drawer contains navigation tiles for history and settings plus an "عن النظام" section with the department credit text. The generation form is vertically centered in the viewport. The home screen title was moved from the AppBar into the body as a large heading above the form, with the AppBar kept for the drawer icon only. Report navigation after generation uses push (not go) so the back button on the report screen naturally returns to home. The generation overlay card was removed — animation and phase text render directly on the full-screen dark backdrop at larger sizes.

**Rejected:** Using go (stack-replace) for post-generation report navigation — it left the report screen with no back button; push was used instead.

---

## 20260519-0200 | Report Screen UI Improvements | TASK

**Task:** Redesigned the Report Screen UI. The three-tab bar was replaced with a two-segment button (مناوبة / صباحي) that looks and behaves like a toggle button. Undetected employees were moved out of the tab bar into a warning icon button in the AppBar with a badge showing the count; clicking opens a dismissable modal dialog with the same search-and-table content as before. Filter radio buttons were replaced with two dropdowns — inclusion (الكل / محتسبون / مستثنون) and overtime (الكل / بوقت إضافي / بدون وقت إضافي) — both defaulting to الكل. Filter state in the provider changed from non-nullable bool to nullable bool (null = show all) using a copyWith sentinel pattern. Employee rows are now color-coded: excluded rows get a light grey background, rows with overtime get a light amber background. The search field was narrowed with a clearer Arabic hint. The day type label "عادي" was renamed to "دوام" in both the detail screen and the Excel export.

---

## 20260519-0300 | Report Screen Inline Filters | TASK

**Task:** Moved all Report Screen filters inline under their corresponding table column headers, replacing the separate filter bar. Each column now carries its own filter control: employee name search (name-only), department search, an overtime checkbox pair (لديه اضافي / بدون اضافي), and an inclusion checkbox pair (مشمول / غير مشمول). Checkbox pair logic: both checked or both unchecked shows all; only one checked filters to that category. The last column was renamed to "المشمولون بالوقت الإضافي". The report info bar (generation date + date range) was moved to the bottom of the screen; the export button was consolidated into that footer at the far left, and is tab-aware. Employee name search is now name-only — department has its own separate field.

---

## 20260519-0400 | Report Screen Cards, Daily Overtime Split & Layout Improvements | TASK

**Task:** Seven improvements to the Report Screen. (1) Summary cards expanded to 4 per tab with tab-specific Arabic labels: total employees (المناوبة / الدوام الصباحي suffix), included employees, gross total overtime (all employees regardless of inclusion toggle), and deserved overtime (included employees only). (2) Daily employee table overtime column split into three sub-columns: دوام (regular-day), عطلة (off-day), كلي (total). Required adding regular_overtime_minutes and off_overtime_minutes to the daily_employee_results DB table (schema v3 migration via two ALTER TABLE statements) and carrying the split through Stage 9, Stage 10, and the display row model. (3) Export button moved from the bottom footer into the AppBar actions. (4) AppBar title changed to include the report date range. (5) Bottom bar simplified to generation date only, centered, with a Divider separator above it. (6) Segment buttons (مناوبة / صباحي) made larger and bolder. (7) DB migration bug fix: schema version bumped 2→3 so the ALTER TABLE statements run on existing databases — without this the generation insert failed silently in the UI.

---

## 20260520-0000 | Report Filters Fix, Export Restructure & Detail Export | TASK

**Task:** Three improvements to the Report Screen. (1) Filter checkbox logic corrected: both checkboxes unchecked in a pair now shows zero employees, not all employees. Applies to both the overtime pair and the inclusion pair on both the shift and daily tabs. (2) Main screen Excel exports (shift and daily) simplified to list-only — period details removed, repo dependency removed. (3) Detail screen gained a download button in the AppBar that exports the currently viewed employee's full period breakdown to Excel: shift employees get a period table with zone results, daily employees get a per-day table, undetected employees get a per-day timestamp table. Detail screen converted to ConsumerStatefulWidget to hold exporting state.

---

## 20260520-0100 | Overtime Zero Display & Daily Export Column Split | TASK

**Task:** Two improvements to the Report Screen. (1) Overtime cells in the employee list now show "---" instead of empty or "0 ساعة" when an employee has no overtime — applies to both shift rows (which previously showed "0 ساعة") and daily rows (which rendered an empty Column). (2) Daily employee Excel export employee table split from one total overtime column into three columns: off-day overtime, regular-day overtime, and total overtime. Off-day and regular columns show "---" when zero; total always shows the formatted value.

---

## 20260520-0200 | Undetected Employees Full Screen & Inline Filters | TASK

**Task:** Replaced the undetected employees modal dialog on the Report Screen with a dedicated full-screen route pushed via go_router. The new screen reads from the existing report provider by report ID — no new data loading. A new named route `undetected` was added nested under the report route. The screen has a combined inline filter header with three per-column controls: a name search field, a department dropdown, and a failure-reason dropdown. Dropdowns are populated from the full unfiltered row set so options never disappear while filtering. Selecting "الكل" (null value) in a dropdown shows all rows for that column. Row taps navigate to the existing undetected detail screen. The old `_UndetectedDialog`, `_TableHeader`, and `_UndetectedRow` classes were removed from the report screen file.

**Rejected:** Passing undetected rows via route extras — provider access by report ID is cleaner and avoids stale data.

---

## 20260520-0300 | Shift Detail Zone Display Improvements | TASK

**Task:** Three UI-only improvements to the zone checkpoint column in the shift employee detail screen. (1) Removed the "نقطة X:" prefix from zone labels. (2) Timestamps moved inline with the zone window on the same line, formatted as "window: ts1، ts2"; zones with no timestamps show "✗" after the window instead of "---", with no leading ✗ sign. (3) Each zone row uses a fixed flex-ratio layout (window flex:2, content flex:3) so all windows are the same width and all timestamps start from the same horizontal point. (4) Zone window now shows the acceptable timestamp window (center − tolerance to center + tolerance) instead of the full zone boundary. Generation-time tolerance is derived from the last zone's stored width (lastZone.endTime − lastZone.startTime = 2 × tolerance), eliminating any dependency on current settings.

**Rejected:** Reading tolerance from current settingsProvider — incorrect if settings changed after report generation. Storing tolerance as a separate field in zone JSON — unnecessary since it is recoverable from the last zone's stored boundaries.

---

## 20260520-0400 | Shift Detail Zone Timestamp Split | TASK

**Task:** Split the single timestamps column in the shift employee detail screen's zone widget into two separate sub-columns — one for timestamps within the allowed window (center ± tolerance) and one for timestamps within the zone boundary but outside that window. A sub-header row ("النافذة" / "داخل النافذة" / "خارج النافذة") is prepended once per period's zone group. Both sub-columns show a red ✗ when empty. Zone invalidity (red background) is still determined by the stored isSatisfied flag. The split is computed at render time from existing ZoneRow data — no data model, DB, or pipeline changes.

---

## 20260520-0500 | Undetected-to-Daily Promotion Stage | TASK

**Task:** Added Stage 4.5 — a post-processing step that runs after schedule detection and before off-day detection. Undetected employees with raw attendance days (calendar days with ≥1 timestamp) at or above a configurable threshold are promoted into the daily bucket and flow through Stages 5, 7, and 9 as regular daily employees. Employees below the threshold remain in the undetected list. The threshold is a private constant on the generation service. No DB schema changes, no UI changes, no new domain models — promoted employees are indistinguishable from naturally detected daily employees.

---

## 20260520-0600 | Schedule Detection V2 — Unified Classification & Period Extraction | TASK

**Task:** Replaced the V1 schedule detection algorithm (Stage 4) and the shift period extractor (Stage 6) with a single unified V2 algorithm. V2 tries every configured shift start time against every calendar day in the report range, building valid shift periods (windows satisfying ≥ N zone checkpoints) during classification rather than in a separate pass. Employees with fewer than 3 valid periods go directly to daily; employees with ambiguous start time confidence (< 60%, multiple start times only) go to undetected. Stage 4.5 (promote undetected to daily) was removed — V2 classifies employees with insufficient shift signal as daily directly, making the promotion step unnecessary. The old Stages 7–10 renumbered to 6–9. Also fixed a misclassification bug where daily employees (stamping at shift start time and again within zone 2's tolerance window) were wrongly classified as shift: the minimum satisfied-zones threshold is now dynamic — `(zoneCount − 1)` clamped to a minimum of 2 — requiring 4 of 5 zones in the default setup. Daily employees can satisfy at most 3 zones (opening, one mid-day stamp at zone 2 boundary, and next-day opening via zone 5), which falls below the new threshold.

**Rejected:** Keeping V1 as a user-facing settings toggle alongside V2 — V2 is strictly better and a toggle creates user confusion with no benefit. Pre-filtering apparent daily employees before V2 (Solution 2) — adds fragile heuristics with new tunable parameters; the dynamic zone threshold cleanly handles the described case. Treating the confidence check across start times as a robust multi-start-time discriminator — it has a known failure mode when start times are separated by exact multiples of zone_interval, so it serves only as a secondary guard for the ambiguous-start-time undetected reason.

---

## 20260520-0700 | Department Filter Dropdown on Report Screen | TASK

**Task:** Replaced the department text-search fields in the shift and daily filter headers on the Report Screen with exact-match dropdown selectors, matching the pattern already in use on the undetected employees screen. Dropdown options are derived from the full unfiltered row set at render time so available options never disappear while other filters are active. Selecting "الكل" clears the department filter. The provider state fields were changed from `String` (substring search) to `String?` (null = all, non-null = exact match), with a sentinel pattern in `copyWith` to distinguish "clear to null" from "not provided".

---

## 20260520-0800 | Schedule Detection Phase 2 — Irregular Shift Detection | TASK

**Task:** Added Phase 2 anchor pair detection to the schedule detection stage. Employees who fail Phase 1 (fewer than 3 valid zone-based periods) are now tested for an irregular shift pattern before being defaulted to daily. An anchor pair requires four conditions on a calendar day D: an opening stamp within the tight shift start window, a closing stamp within the same tight window on D+1, a rest gap (zero timestamps on D+2 and D+3), and a return stamp on D+4 or D+5. Employees with 2 or more valid anchor pairs are classified as shift; below that threshold they fall to daily. The start-time confidence check (60%) applies in Phase 2 identically to Phase 1. Anchor pair periods are stored as ShiftPeriod objects and flow through the shift overtime calculator unchanged — since only zones 1 and 5 are satisfied, all anchor pair periods are marked invalid with 0 hours counted. The intent is correct classification (shift tab, not daily), not overtime accrual for these periods.

**Rejected:** Hardcoding `min_zones_satisfied = 4` — kept the existing dynamic formula `(zoneCount − 1).clamp(2, zoneCount)` which is more correct for non-default zone configurations. Raising `min_start_time_confidence` from 0.60 to 0.75 — deferred to a future task.

---

## 20260520-0900 | Schedule Detection Bug Fixes — Anchor Pair Integration | TASK

**Task:** Fixed three bugs in the schedule detection stage that caused daily↔shift misclassifications. (1) The anchor pair activity check was too strict — it required a closing stamp near the shift start time on D+1, while the spec requires any stamp on D+1 at any time. Fixed to match the spec. (2) Anchor pairs were implemented as a separate Phase 2 that only ran when zone-based periods fell below the minimum threshold, meaning zone periods and anchor pair periods were never combined in the same bucket. Fixed by integrating the anchor pair check as a per-day fallback inside the zone-check loop — both types now contribute to the same period list and are counted against the single `min_valid_periods = 3` threshold. The separate Phase 2 and its `min_anchor_pairs = 2` threshold were removed. (3) Daily employees on a Sun-Thu schedule triggered the anchor pair check every week because the natural Fri-Sat weekend satisfied the rest gap condition. Fixed by rejecting any rest gap where both D+2 and D+3 fall on Friday-Saturday — a gap must include at least one regular working day to be meaningful.

**Rejected:** Pre-computing off-days from the full dictionary to detect weekend gaps — unnecessary since the weekend is always Friday-Saturday in this app's context; a simple day-of-week check is sufficient and avoids any pipeline dependency.

---

## 20260521-0000 | Daily Validation Gate — Schedule Detection | TASK

**Task:** Added a daily validation gate in schedule detection that runs when an employee fails to produce enough valid shift periods. Before classifying the employee as daily, the gate verifies they follow a daily schedule using two sequential checks: (1) morningDays (days with a timestamp within the entry window) must be ≥ 50% of working days in the report range; (2) exitDays (subset of morningDays with a timestamp within the exit window) must be ≥ 50% of morningDays. Employees who fail either check become undetected with reason "لا ينتمي لنظام المناوبة أو الدوام الصباحي". Working days exclude Fridays and Saturdays. morningDays counts all calendar days (including weekends) to avoid penalising employees who work seven days. The gate uses the existing daily config already available in AppSettings — no signature changes were needed.

---

## 20260521-0100 | Daily Validation Gate — Simplified Threshold | TASK

**Task:** Simplified the daily validation gate. The exit condition (requiring 50% of morning days to also have an exit stamp) was removed because entry-only employees are common by policy and the downstream calculator already handles missing exit stamps correctly. The entry threshold was changed from a pure 50% ratio to `max(10, workingDays × 0.50)` — the floor of 10 prevents the ratio from being too easy to satisfy on short reports, since a shift employee on a 3-day cycle produces at most ~10 opening stamps per month. The gate now has a single check only.

**Rejected:** Exit stamp condition — wrongly classifies entry-only employees as undetected; downstream calculator handles the missing stamp correctly with an invalid period and zero overtime.

---
