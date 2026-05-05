# file_processing

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026
**Version**: 1.0

---

## Purpose

Defines how the three input Excel files are opened and validated when the user selects them. Validation runs immediately on file selection — not at generation time. Any further processing of the file contents (filtering, merging, matching) is a report generation concern — see `report_generation.md`.

---

## Supported Formats

All three files support `.xlsx` and `.xls` formats. Multiple sheets within a single file are all read. Attendance files and target employees files support multiple separate files. The holidays file accepts a single file only.

---

## Column Header Validation

Each file type has a defined set of required field keys. For each field key, there is a list of acceptable Arabic header values stored in the database. Default values are defined in `config.md`. The user may add additional acceptable values via the Settings tab — see `screen_configuration.md`.

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

## Target Employees File

### Required Fields

| Field key | What it represents |
|---|---|
| employee_name | The employee's full name |
| employment_type | Either the Arabic value for shift or daily |
| department | The employee's department |

### Valid Row

A row is valid if all three fields are present and employment type contains one of the two recognized Arabic values defined in `config.md`. Any unrecognized employment type value causes the entire file to be rejected.

---

## Holidays File

### Required Fields

| Field key | What it represents |
|---|---|
| date | The calendar date of the holiday |
| occasion | The name or description of the holiday in Arabic |

### Valid Row

A row is valid if both fields are present and non-empty.

---

## Validation Errors

| Situation | Arabic message |
|---|---|
| Attendance file not provided | يرجى تحميل ملف حضور |
| Employees file not provided | يرجى تحميل ملف الموظفين المستهدفين |
| Holidays file not provided | يرجى تحميل ملف العطل الرسمية |
| File does not match expected structure | الملف لا يتطابق مع القالب المطلوب |
| Employment type value not recognized | نوع التوظيف غير معروف في ملف الموظفين |
| File contains no valid rows | الملف لا يحتوي على صفوف صالحة |

---

## Later Improvements

**Partial file recovery.** Skip invalid rows rather than rejecting the whole file, and report how many rows were skipped.

**Additional file formats.** CSV support for systems that do not produce Excel files.
