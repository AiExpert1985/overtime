# main_workflow

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Highest-level description of how the app works end to end. Read this first. All other docs provide the exact details — this doc provides the flow.

---

## The 7 Stages

### Stage 1 — File Upload and Validation

The user uploads one or more attendance Excel files on the Report Generation screen. Files are validated immediately on upload — column headers are checked and at least one valid row must exist. A file card shows green on pass, red with Arabic reason on failure.

There is no employee list to manage and no holidays to configure. Everything is derived from the attendance file.

See `screen_report_generate.md` and `file_processing.md`.

### Stage 2 — Generate Report Triggered

The Generate Report button becomes active only when at least one attendance file is valid and both start and end dates are filled. When the user presses the button, report generation begins immediately with no further prompts.

See `screen_report_generate.md`.

### Stage 3 — Dictionary Build

A single pass over all attendance records across all files and sheets. Every unique employee name found in the file becomes a dictionary entry. Records outside the selected date range are discarded. The result is one entry per detected employee with their sorted timestamp list.

No external employee list is consulted. The attendance file is the sole source of employee identity.

See `dictionary_build.md`.

### Stage 4 — Schedule Detection

Runs inline on the working dictionary. For each employee, the detection algorithm determines employment type (shift or daily) and, for shift employees, the shift start time. Both are derived from the timestamp patterns in the dictionary — no stored employee data is used.

The dictionary is silently split into three buckets:
- **Shift bucket** — fully detected as shift with a confirmed start time
- **Daily bucket** — fully detected as daily
- **Undetected bucket** — failed detection at any stage, with a recorded failure reason

No dialog is shown. Generation continues immediately regardless of how many employees end up in each bucket.

See `schedule_detection.md`.

### Stage 5 — Off-Day Detection

Runs on the daily bucket only. Uses attendance density across the date range to classify each day as regular or off. The result is a hash set of off-day dates passed to the daily period extractor in Stage 6.

Requires at least 2 daily employees to produce meaningful results. If fewer are present, the hash set is empty and all days are treated as regular.

See `off_day_detection.md`.

### Stage 6 — Period Extraction and Overtime Calculation

Each bucket is processed by its type-specific extractor and calculator in sequence:

**Shift employees:** periods are extracted using the detected shift start time and zone configuration, then validated and overtime is calculated.

**Daily employees:** periods are extracted using calendar day grouping and the off-days hash set, then validated and overtime is calculated.

**Undetected employees:** no extraction or calculation. Their name, department, and failure reason are carried directly to storage.

All extractors and calculators run as pure functions — same input always produces the same output.

See `period_extractor_shift.md`, `overtime_calculation_shift.md`, `period_extractor_daily.md`, `overtime_calculation_daily.md`.

### Stage 7 — Store and Navigate

All three result sets are stored to the database. All in-memory structures are discarded — the database becomes the sole source of truth.

After storage, the report is loaded from the database into the report provider. The Report Generation screen is popped and the newly generated Report screen is pushed on top of the Reports List.

All report screens — whether reached after generation or by tapping a history row — always load from the database. There is no in-memory hand-off path.

See `screen_report.md` and `database_schema.md`.

---

## Error Handling

Any failure during Stages 3–7 aborts generation entirely. No partial results are stored. The user sees an Arabic error message and remains on the Report Generation screen with all inputs intact.

---

## Key Design Principles

- The attendance file is the sole source of employee identity — no persistent employee table
- Every generation is completely fresh — no data carried between runs
- Generation never pauses for user input after the button is pressed
- All in-memory structures are discarded after results are stored
- Report screens always load from the database — no in-memory hand-off
- Extractors and calculators are pure functions — same input always produces same output
- Rounding is display-only — raw minute values are always stored
- Aggregate totals and summaries are always computed live from stored rows — never stored themselves
