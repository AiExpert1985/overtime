# data_shared_models

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the domain models used across the pipeline. All are plain data containers — no behavior, no dependencies. No input models exist — employee identity and department are read directly from the attendance file during generation.

---

## Pipeline Flow

Period objects are created by the extractors with base fields, then enriched in place by the calculators with calculated fields. The same object travels through both stages — no separate raw or result objects.

---

## Employee Models

### ShiftEmployeeResult

Represents one shift employee's result within a report.

| Field | Type | Notes |
|---|---|---|
| employeeName | string | |
| department | string | Read from attendance file — snapshot at generation time |
| isIncluded | boolean | User-controlled toggle. True by default. Persisted. |
| periods | List\<ShiftPeriod\> | Loaded lazily — only when detail screen is opened |

Total overtime is always computed live by summing `hoursCounted` across periods, applying ceiling, then subtracting baseline. Never stored as a separate field.

---

### DailyEmployeeResult

Represents one daily employee's result within a report.

| Field | Type | Notes |
|---|---|---|
| employeeName | string | |
| department | string | Read from attendance file — snapshot at generation time |
| isIncluded | boolean | User-controlled toggle. True by default. Persisted. |
| periods | List\<DailyPeriod\> | Loaded lazily — only when detail screen is opened |

Total overtime is always computed live by summing `overtimeMinutes` across periods. Never stored as a separate field.

---

### UndetectedEmployeeResult

Represents one employee whose type could not be determined during schedule detection. No overtime, no periods.

| Field | Type | Notes |
|---|---|---|
| employeeName | string | |
| department | string | |
| failureReason | string | Arabic string. One of the reasons defined in `schedule_detection.md`. |

Never contributes to summaries. Not exported. No `isIncluded` toggle — always read-only in the report screen.

---

## Period Models

Single object per period type. Created by the extractor with base fields, enriched in place by the calculator with calculated fields.

---

### ShiftPeriod

| Field | Set by | Type | Notes |
|---|---|---|---|
| periodIndex | extractor | integer | 0-based order within the employee's period list |
| periodDate | extractor | string | ISO 8601 date this period is anchored to |
| endDate | calculator | string | ISO 8601 date of last timestamp — derived at calculation time |
| allTimestamps | extractor | List\<DateTime\> | All timestamps within the period, sorted ascending |
| zoneResults | extractor | List\<ZoneResult\> | One entry per zone: { zoneIndex, startTime, endTime, timestamps, isSatisfied } |
| totalAttendanceDuration | calculator | integer | Minutes from first to last timestamp. Audit only. |
| hoursCounted | calculator | integer | 24 if valid, 0 if invalid |
| isValid | calculator | boolean | Set at calculation time — never changes after |
| notes | calculator | string? | Arabic invalid reason. Null if valid. |

---

### DailyPeriod

| Field | Set by | Type | Notes |
|---|---|---|---|
| periodIndex | extractor | integer | 0-based order within the employee's period list |
| date | extractor | string | ISO 8601 date |
| weekday | extractor | string | Arabic weekday name e.g. الأحد. Derived from date at extraction time. |
| dayType | extractor | string | 'regular' or 'off' |
| allTimestamps | extractor | List\<DateTime\> | All timestamps of the day, sorted ascending |
| totalAttendanceDuration | calculator | integer | Minutes from first to last timestamp. Audit only. |
| overtimeMinutes | calculator | integer | Overtime for this period. 0 if invalid. |
| isValid | calculator | boolean | Set at calculation time — never changes after |
| notes | calculator | string? | Arabic invalid reason. Null if valid. |

---

## isValid vs isIncluded

These two boolean fields exist at different levels and must not be confused:

| Field | Level | Set by | Can change? | Meaning |
|---|---|---|---|---|
| isValid | Period | Calculator during generation | Never | Did this period satisfy the calculation rules |
| isIncluded | Employee | User toggle on report screen | Yes, persisted | Should this employee count toward totals and export |

Period-level `isValid` is a permanent calculation result. Employee-level `isIncluded` is a user preference. They are completely independent.
