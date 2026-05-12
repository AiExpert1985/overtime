# file_processing

**Created**: 27-Apr-2026 **Modified**: 12-May-2026 **Version**: 2.0

---

## Purpose

Defines how the attendance Excel file is opened and validated when the user selects it on the Report Generation screen. Validation runs immediately on file selection — not at generation time. Any further processing (filtering, merging, matching) happens during report generation — see `dictionary_build.md` and `main_workflow.md`.

Employees and holidays are no longer file-based. They are permanent reference data managed in their own screens — see `screen_employees.md` and `screen_holidays.md`.

---

## Supported Formats

`.xlsx` and `.xls` formats. Multiple sheets within a single file are all read. Multiple separate attendance files are supported — the user may select several files at once.

---

## Column Header Validation

Each required field key has a list of acceptable Arabic header values stored in the database. Default values are defined in `config.md`. The user may add additional acceptable values via the Settings tab — see `screen_configuration.md`.

When a file is opened, the parser reads the first row of each sheet. Each header value is trimmed of leading and trailing whitespace before comparison. For each required field key, the parser checks whether any column header matches any acceptable value for that field. If a required field key has no match, the file is rejected.

---

## Attendance File

### Required Fields

| Field key | What it represents |
|---|---|
| employee_name | The employee's name |
| datetime | The full date and time of the fingerprint event |

### Valid Row

A row is valid if both employee name and datetime are present and non-empty.

---

## Validation Errors

| Situation | Arabic message |
|---|---|
| Attendance file not provided | يرجى تحميل ملف حضور |
| File does not match expected structure | الملف لا يتطابق مع القالب المطلوب |
| File contains no valid rows | الملف لا يحتوي على صفوف صالحة |

---

## Later Improvements

**Partial file recovery.** Skip invalid rows rather than rejecting the whole file, and report how many rows were skipped.

**Additional file formats.** CSV support for systems that do not produce Excel files.