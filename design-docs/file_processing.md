# file_processing

**Created**: 27-Apr-2026
**Modified**: 14-May-2026
**Version**: 3.0

---

## Purpose

Defines how the attendance Excel file is opened and validated when the user selects it on the Report Generation screen. Validation runs immediately on file selection — not at generation time. Any further processing (dictionary build, detection, calculation) happens during report generation — see `dictionary_build.md` and `main_workflow.md`.

---

## Supported Formats

`.xlsx` and `.xls` formats. Multiple sheets within a single file are all read. Multiple files are supported — the user may add files one at a time or several at once, and may add more files after an initial selection.

---

## File List Behavior

Each file is validated independently as soon as it is added to the list. Adding a new file does not affect the validation status of files already in the list. Files may be deleted from the list individually at any time.

At generation time, only files with valid status are read. Invalid files in the list are silently ignored — they are never passed to the dictionary build stage.

---

## Column Header Validation

Each required field key has a list of acceptable Arabic header values stored in the database. Default values are defined in `config.md`. The user may add additional acceptable values via the Settings screen — see `screen_configuration.md`.

When a file is opened, the parser reads the first row of each sheet. Each header value is trimmed of leading and trailing whitespace before comparison. For each required field key, the parser checks whether any column header matches any acceptable value for that field. If a required field key has no match, the file is rejected.

---

## Attendance File

### Required Fields

| Field key | What it represents |
|---|---|
| employee_name | The employee's name |
| department | The employee's department |
| datetime | The full date and time of the fingerprint event |

### Valid Row

A row is valid if employee name, department, and datetime are all present and non-empty.

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
