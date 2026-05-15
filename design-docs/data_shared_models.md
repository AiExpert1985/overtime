# data_shared_models

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the four domain models used across the pipeline. All are plain data containers — no behavior, no dependencies. These are the only models the app needs. No input models exist — employee identity and department are read directly from the attendance file during generation.

---

## Calculator Output Models

Produced by the calculators and detection stage, stored to the database, and read back by the report screens. Two employee models with periods for detected employees, one flat model for undetected employees.

---

### ShiftEmployeeResult

Represents one shift employee's result within a report.

| Field | Type | Notes |
|---|---|---|
| employeeName | string | |
| department | string | Read from attendance file — snapshot at generation time |
| overtimeHours | integer | Total overtime hours for the month |
| isIncluded | boolean | User-controlled toggle. True by default. Persisted. |
| periods | List\<ShiftPeriod\> | Loaded lazily — only when detail screen is opened |

---

### ShiftPeriod

One shift period for a shift employee.

| Field | Type | Notes |
|---|---|---|
| periodIndex | integer | 0-based order within the employee's period list |
| periodDate | string | ISO 8601 date this period is anchored to |
| endDate | string | ISO 8601 date of last timestamp |
| allTimestamps | List\<DateTime\> | All timestamps within the period, sorted ascending |
| totalAttendanceDuration | integer | Minutes from first to last timestamp. Audit only. |
| zoneResults | List\<ZoneResult\> | One entry per zone: { zoneIndex, startTime, endTime, timestamps, isSatisfied } |
| hoursCounted | integer | 24 if valid, 0 if invalid |
| isValid | boolean | Set at generation time — never changes |
| notes | string? | Arabic invalid reason. Null if valid. |

---

### DailyEmployeeResult

Represents one daily employee's result within a report.

| Field | Type | Notes |
|---|---|---|
| employeeName | string | |
| department | string | Read from attendance file — snapshot at generation time |
| overtimeMinutes | integer | Total overtime minutes across all days |
| isIncluded | boolean | User-controlled toggle. True by default. Persisted. |
| periods | List\<DailyPeriod\> | Loaded lazily — only when detail screen is opened |

---

### DailyPeriod

One calendar day period for a daily employee.

| Field | Type | Notes |
|---|---|---|
| periodIndex | integer | 0-based order within the employee's period list |
| date | string | ISO 8601 date |
| weekday | string | Arabic weekday name e.g. الأحد. Stored at generation time. |
| dayType | string | 'regular' or 'off' |
| allTimestamps | List\<DateTime\> | All timestamps of the day, sorted ascending |
| totalAttendanceDuration | integer | Minutes from first to last timestamp. Audit only. |
| overtimeMinutes | integer | Overtime for this period. 0 if invalid. |
| isValid | boolean | Set at generation time — never changes |
| notes | string? | Arabic invalid reason. Null if valid. |

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

## isValid vs isIncluded

These two boolean fields exist at different levels and must not be confused:

| Field | Level | Set by | Can change? | Meaning |
|---|---|---|---|---|
| isValid | Period | Calculator during generation | Never | Did this period satisfy the calculation rules |
| isIncluded | Employee | User toggle on report screen | Yes, persisted | Should this employee count toward totals and export |

Period-level `isValid` is a permanent calculation result. Employee-level `isIncluded` is a user preference. They are completely independent.
