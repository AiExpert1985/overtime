# main_workflow

**Created**: 27-Apr-2026
**Modified**: 12-May-2026

---

## Purpose

Highest-level description of how the app works end to end. Read this first. All other docs provide the exact details — this doc provides the flow.

---

## The 6 Stages

### Stage 1 — File Upload and Validation

The user uploads the attendance Excel file on the Report Generation screen. The file is validated immediately on upload — column headers are checked and at least one valid row must exist. A file card shows green on pass, red with Arabic reason on failure.

Employees and holidays are no longer uploaded as files. They are permanent reference data managed in the Employees and Holidays screens. If no employees have been added yet, the Generate button will never become active.

See `screen_report_generate.md` and `file_processing.md`.

### Stage 2 — Generate Report Triggered

The Generate Report button becomes active only when the attendance file is uploaded and valid, both start and end dates are filled, and at least one employee is selected. When the user presses the button, report generation begins immediately.

See `screen_report_generate.md`.

### Stage 3 — Dictionary Build

A working dictionary is built in memory from the attendance file, the selected employees (from the permanent employees table), the holidays list (from the permanent holidays table), and the selected date range. Records outside the selected employee list or date range are discarded. The result is one entry per matched employee with their sorted timestamp list. If any selected employees have no attendance records, the user is prompted to abort or continue before proceeding.

See `dictionary_build.md` for the exact steps and rules.

### Stage 4 — Period Extraction

Each employee's sorted timestamp list is passed to a type-specific extractor — daily or shift. The daily extractor returns a `RawDailyEmployeePeriods` object; the shift extractor returns a `RawShiftEmployeePeriods` object. Both are ordered earliest to latest.

See `period_extractor_daily.md` and `period_extractor_shift.md`.

### Stage 5 — Overtime Calculation

Each employee's period list is passed to a type-specific calculator — daily or shift. Each calculator returns valid/invalid results with overtime values. Results are assembled into a ReportSummary and stored to the database. The working dictionary is discarded — the database becomes the sole source of truth.

See `overtime_calculation_daily.md` and `overtime_calculation_shift.md`.

### Stage 6 — Navigate to Report

After results are stored, the report is loaded from the database into the report provider. The Report Generation screen is popped, and the newly generated Report screen is pushed on top of the Reports List. The user sees their report immediately without any manual navigation.

All report screens — whether reached after generation or by tapping a history row — always load from the database. There is no separate in-memory path for newly generated reports. This ensures one consistent loading code path throughout the app.

See `screen_report.md`.

---

## Error Handling

Any failure during Stages 3–5 aborts generation entirely. No partial results are stored. The user sees an Arabic error message and remains on the Report Generation screen with all selections intact. If the user aborts at the unmatched review prompt, this is a clean abort — not an error.

---

## Key Design Principles

- Input files are never stored — only calculated results are persisted
- The working dictionary is built once and discarded after results are stored
- Extractors and calculators are pure functions — same input always produces same output
- Rounding is display-only — raw minute values are always stored
