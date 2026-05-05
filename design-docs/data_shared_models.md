# data_shared_models

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

Defines the three data objects that cross the boundary between FileProcessing and Reporting. FileProcessing produces them. Reporting consumes them. Neither feature owns them exclusively — they are shared domain concepts.

These are plain data containers. They carry no behavior and depend on nothing.

---

## Employee

Represents one person from the target employees file.

**Fields:**

- **name** — the employee's full name as it appears in the target employees file. Used as the join key when matching against attendance records. Matching is exact — see `report_generation.md`.
- **employmentType** — either shift or daily. Determines which set of calculation rules applies. See `overtime_calculation_shift.md` and `overtime_calculation_daily.md`.
- **department** — the department this employee belongs to. Used for display only — it has no effect on calculation.

---

## AttendanceRecord

Represents all fingerprint timestamps found for one employee across all provided attendance files, filtered to the requested date range.

**Fields:**

- **employeeName** — matched against Employee.name by the Reporting feature. Must be an exact string match.
- **fingerprints** — all timestamps for this employee within the date range, sorted ascending. Raw timestamps — filtering is applied during report generation. See `report_generation.md`.

---

## Holiday

Represents one official holiday from the holidays file.

**Fields:**

- **date** — the calendar date of the holiday. Only the date matters — the time component is ignored.
- **occasion** — the name or description of the holiday in Arabic. Used for display only — it has no effect on calculation.
