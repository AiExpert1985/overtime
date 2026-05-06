# data_shared_models

**Created**: 27-Apr-2026
**Modified**: 05-May-2026

---

## Purpose

Defines all shared data objects used across the pipeline: input objects produced by FileProcessing and consumed by Reporting, and result objects produced by the calculators and consumed by the report screens. All are plain data containers — no behavior, no dependencies.

---

## Input Objects

These cross the boundary between FileProcessing and Reporting.

### Employee

Represents one person from the target employees file.

**Fields:**

- **name** — the employee's full name as it appears in the target employees file. Used as the join key when matching against attendance records. Matching is exact — see `dictionary_build.md`.
- **employmentType** — either shift or daily. Determines which extractor and calculator apply.
- **department** — the department this employee belongs to. Used for display only — no effect on calculation.

---

### AttendanceRecord

Represents all fingerprint timestamps found for one employee across all provided attendance files, filtered to the requested date range.

**Fields:**

- **employeeName** — matched against Employee.name. Must be an exact string match.
- **fingerprints** — all timestamps for this employee within the date range, sorted ascending. See `dictionary_build.md`.

---

### Holiday

Represents one official holiday from the holidays file.

**Fields:**

- **date** — the calendar date of the holiday. Time component is ignored.
- **occasion** — the name or description of the holiday in Arabic. Display only — no effect on calculation.

---

## Extractor Output

Two separate classes — one per employment type. The class itself identifies the type.

### RawDailyEmployeePeriods

Output of the daily period extractor.

**Fields:**

- **name** — employee's full name
- **department** — employee's department
- **periods** — list of RawDailyPeriod

#### RawDailyPeriod

- **date** — calendar date (ISO 8601)
- **dayType** — regular / holiday / weekend
- **timestamps** — all timestamps of the day, sorted ascending

---

### RawShiftEmployeePeriods

Output of the shift period extractor.

**Fields:**

- **name** — employee's full name
- **department** — employee's department
- **periods** — list of RawShiftPeriod

#### RawShiftPeriod

- **anchorTimestamp** — the defining start timestamp of this period
- **timestamps** — all timestamps within the period span, sorted ascending

---

## Calculator Output

Two separate classes — no shared parent. The class itself identifies the type.

### DailyEmployeeResult

Output of the daily calculator. Stored to and loaded from the database. Read directly by report screens.

**Fields:**

- **name** — employee's full name
- **department** — employee's department
- **isUnmatched** — true if no attendance records were found for this employee
- **notes** — Arabic message for unmatched employees. Null if matched.
- **totalRegularOvertimeMinutes** — total overtime on regular workdays, in minutes
- **totalHolidayOvertimeMinutes** — total overtime on holiday/weekend days, in minutes
- **periods** — list of DailyPeriodDetail

#### DailyPeriodDetail

- **date** — calendar date of this period
- **weekday** — Arabic weekday name e.g. الأحد، الاثنين. Stored at generation time from the date field — not recomputed later.
- **dayType** — regular / holiday / weekend
- **timestamps** — all timestamps of the day, sorted ascending
- **totalAttendanceDuration** — duration from first to last timestamp, in minutes
- **overtimeMinutes** — overtime for this period. 0 if valid with no overtime. 0 if invalid.
- **isValid** — whether this period contributed to overtime
- **notes** — Arabic invalid reason. Null if valid.

---

### ShiftEmployeeResult

Output of the shift calculator. Stored to and loaded from the database. Read directly by report screens.

**Fields:**

- **name** — employee's full name
- **department** — employee's department
- **isUnmatched** — true if no attendance records were found for this employee
- **notes** — Arabic message for unmatched employees. Null if matched.
- **totalOvertimeHours** — total overtime hours for the month
- **periods** — list of ShiftPeriodDetail

#### ShiftPeriodDetail

- **startDate** — calendar date of the anchor timestamp. Stored at generation time.
- **endDate** — calendar date of the last timestamp. Stored at generation time — not derived later to avoid dependency on shift duration setting which may change.
- **anchorTimestamp** — the defining start timestamp of this period
- **timestamps** — all timestamps within the period, sorted ascending
- **totalAttendanceDuration** — duration from first to last timestamp, in minutes
- **zoneResults** — list of zone results, one per zone: { centerTime, timestamps, isSatisfied }
- **hoursCounted** — 24 if valid, 0 if invalid
- **isValid** — whether this period contributed to overtime
- **notes** — Arabic invalid reason. Null if valid.
