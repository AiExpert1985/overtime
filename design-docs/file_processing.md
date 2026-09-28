# file_processing

**Created**: 27-Apr-2026
**Modified**: 28-Sep-2026
**Version**: 4.0

---

## Purpose

Defines how the attendance Excel file is opened and validated when the user selects it on the Report Generation screen. Validation runs immediately on file selection — not at generation time. Any further processing (dictionary build, detection, calculation) happens during report generation — see `dictionary_build.md` and `main_workflow.md`.

---

## Supported Formats

`.xlsx` and `.xls` formats. Multiple sheets within a single file are all read. Multiple files are supported — the user may add files one at a time or several at once, and may add more files after an initial selection. Up to 400 files per report.

Two attendance layouts are accepted and may be mixed freely in one report. The format is detected per sheet: a sheet whose opening rows carry the title "Daily Attendance Listing" is read as a Daily Attendance Listing (see below); every other sheet is read as a raw punch log (the Attendance File sections). Validation and dictionary build use the same detection, so a file always validates and generates by the same rules.

---

## File List Behavior

Each file is validated independently as soon as it is added to the list. Adding a new file does not affect the validation status of files already in the list. Files may be deleted from the list individually at any time.

At generation time, only files with valid status are read. Invalid files in the list are silently ignored — they are never passed to the dictionary build stage.

---

## Column Header Validation

Applies to the raw punch log format only. The Daily Attendance Listing uses fixed labels and ignores these settings — see below.

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

## Daily Attendance Listing

A processed report exported by the attendance software, one printed page per file (a month is typically 180–300 files). Handled by `daily_listing_reader.dart`, which converts it into the same (name, department, timestamp) records the raw punch log produces, so nothing after the dictionary build knows which format a timestamp came from.

**Why a separate reader.** The raw punch log path assumes one timestamp per row, a header on the first row, and configurable header values. This format breaks all three — the date is outside the rows, each row holds two times, and the header sits below a title block — so it gets its own reader instead of complicating the existing path, which stays unchanged.

**Fixed labels, not configurable.** The title (`Daily Attendance Listing`) and column labels (`Name`, `In`, `Out`) are printed by the attendance software's report template and are hardcoded in the reader. They are **not** read from the `column_headers` settings, and adding values on the Settings screen has no effect on this format. If the software ever renames them, the constants in the reader must be updated.

- **Date** — printed once near the top of the sheet as `MM-DD-YYYY  Ddd` (e.g. `04-05-2026  Sun`) and applied to every row on the page. The weekday must agree with the date; a sheet with no readable date is rejected — guessing it would misplace every timestamp.
- **Columns** — located by the header row's `Name`, `In` and `Out` labels, never by fixed position: column positions differ between exports of the same report.
- **Rows** — an employee row starts with a numeric sequence cell before the name. Each row's In and Out cells (12-hour text, e.g. `07:54 AM`) become two separate timestamp records; an empty cell produces none, so an In-only row yields one record. The software's own Work/Overtime/Short columns are ignored.
- **Department** — the export has none; every record gets the fixed department `مبنى المديرية` (all files of this format come from that one building).
- **Validation** — a sheet with the title, a readable date and the header row is valid even with no employee rows (each day's last page often holds only the day's summary block). Without a date or header it fails with the template-mismatch message. In/Out text that is not a recognisable time is counted into the same skipped-rows warning as the raw punch log.

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
