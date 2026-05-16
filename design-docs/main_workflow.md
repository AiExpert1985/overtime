# main_workflow

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Highest-level description of how the app works end to end. Read this first. All other docs provide the exact details — this doc provides the flow.

---

## The 10 Stages

### Stage 1 — File Upload and Validation

The user uploads attendance Excel files (one or more). Files are shown as rows in a file list card — each validated immediately on upload with a valid/invalid status. Files can be added sequentially or in bulk, and deleted individually. At generation time, only valid files are used — invalid files in the list are ignored.

See `file_processing.md` and `screen_report_generate.md`.

### Stage 2 — Generate Report Triggered

The Generate Report button becomes active only when at least one attendance file is valid and both start and end dates are filled. When the user presses the button, report generation begins immediately.

See `screen_report_generate.md`.

### Stage 3 — Dictionary Build

A single pass over all attendance records across all files and sheets. Every unique employee name found in the file becomes a dictionary entry. Records outside the selected date range are discarded. The result is one entry per detected employee with their department, and sorted timestamp list.

See `dictionary_build.md`.

### Stage 4 — Employee Separation

Runs inline on the working dictionary. For each employee, the detection algorithm determines employment type (shift or daily) and, for shift employees, the shift start time. Both are derived from the timestamp patterns in the dictionary — no stored employee data is used. the result are 3 types of employees:
1. **Shift employees:** Employees in the shift bucket
2. **Daily employees:** Employees in the daily bucket
3. **Undetected employees:** Employees that don't fit in either bucket

See `schedule_detection.md`.

### Stage 5 — Off-Day Detection

Runs on the daily bucket only. Uses attendance density across the date range to classify each day as regular or off. The result is a hash set of off-day dates passed to the daily period extractor in Stage 7.

See `off_day_detection.md`.

### Stage 6 — Shift Employees Period Extraction 

periods are extracted using the detected shift start time and zone configuration.

See `period_extractor_shift.md`

### Stage 7 — Daily Employees Period Extraction 

periods are extracted using calendar day grouping and the off-days hash set.

See `period_extractor_daily.md`

### Stage 8 — Shift Employees Overtime Calculation

 validated and overtime is calculated.

See  `overtime_calculation_shift.md`

### Stage 9 — Daily Employees Overtime Calculation

validated and overtime is calculated.

See `overtime_calculation_daily.md`.

### Stage 10 — Store and Navigate

All three result sets are stored to the database inside a single SQLite transaction — either all writes succeed or none do. All in-memory structures are discarded after the transaction commits — the database becomes the sole source of truth.

After storage, the report is automatically loaded from the database into the report provider. The Report Generation screen is popped and the newly generated Report screen is pushed on top of the Reports List.

All report screens — whether reached after generation or by tapping a history row — always load from the database. There is no in-memory hand-off path. Display is purely passive: no calculations run at load time.

See `screen_report.md` and `database_schema.md`.

---

## Error Handling

Any failure during Stages 3–10 aborts generation entirely. No partial results are stored. The user sees an Arabic error message and remains on the Report Generation screen with all inputs intact.

---

## Key Design Principles

- The attendance file is the sole source of employee identity — no persistent employee table
- Every generation is completely fresh — no data carried between runs
- Generation never pauses for user input after the button is pressed
- **Each stage is implemented as a separate standalone function with defined inputs and outputs — the generation service orchestrates them in sequence, passing the output of each stage as input to the next**
- All in-memory structures are discarded after results are stored
- Report screens always load from the database — no in-memory hand-off
- Extractors and calculators are pure functions — same input always produces same output
- Rounding is display-only — raw minute values are always stored
- **All business calculations happen at generation time and are stored. Display is purely passive — no overtime formulas, no aggregation logic runs at load time.**
- **Per-employee overtime totals are stored at generation time and never change.** Report-level summaries (totals across employees) are the only values assembled at display time, as simple addition of stored per-employee values filtered by `is_included`.
- **Stage 10 writes are atomic — a single SQLite transaction wraps all inserts. Either the full report is stored or nothing is.**
