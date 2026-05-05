# database_schema

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

Defines all tables, columns, relationships, and versioning strategy. All database access is owned by the Reporting feature's repository. FileProcessing has no database presence.

---

## Tables Overview

```
reports
  └── employee_results
        └── period_details

column_headers
app_settings
```

---

## reports

One row per generated report. Unique key is generation date.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| generation_date | text, unique | ISO 8601 date |
| range_start | text | ISO 8601 date |
| range_end | text | ISO 8601 date |
| total_employees | integer | Matched and unmatched combined |
| total_overtime_hours | integer | Shift employees: total overtime hours. |
| total_daily_overtime_minutes | integer | Daily employees: total regular workday overtime minutes. |
| total_holiday_overtime_minutes | integer | Daily employees: total holiday/weekend overtime minutes. |
| unmatched_employee_count | integer | |

---

## employee_results

One row per employee per report. Cascade deleted with parent report.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| report_id | integer, FK → reports.id | Cascade delete |
| employee_name | text | |
| employment_type | text | 'shift' or 'daily' |
| department | text | |
| overtime_hours | integer | Shift only: total overtime hours (integer). Null for daily. |
| overtime_minutes | integer | Daily only: regular workday overtime total in minutes. Null for shift. |
| holiday_overtime_minutes | integer, nullable | Daily only: holiday/weekend overtime total in minutes. Null for shift. |
| has_attendance | integer | 1 if records found, 0 if not |
| notes | text, nullable | Arabic message for unmatched employees |

---

## period_details

One row per detected period per employee result. Covers both daily and shift employees. Cascade deleted with parent employee result. All data is report output — not raw input.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| employee_result_id | integer, FK → employee_results.id | Cascade delete |
| period_index | integer | Order of this period within the employee's results, 0-based |
| anchor_timestamp | text | ISO 8601 datetime. First timestamp of the period. |
| is_valid | integer | 1 if period contributed hours, 0 if invalid |
| is_holiday | integer | 1 for daily holiday/weekend periods. 0 otherwise. Null for shift. |
| first_timestamp | text, nullable | ISO 8601 datetime |
| last_timestamp | text, nullable | ISO 8601 datetime |
| all_timestamps | text | JSON array of ISO 8601 datetime strings — all timestamps sorted ascending. Used for audit display. |
| working_hours_actual_minutes | integer | Actual duration from first to last timestamp in minutes. Stored for both types. Audit display only — not used in overtime formula. |
| zone_data | text, nullable | Shift only. JSON array of zone results: [{ centerTime, timestamps[], isSatisfied }]. Null for daily. |
| overtime_minutes_raw | integer | Calculated overtime before daily cap. 0 if invalid. Null for shift (shift uses hours not minutes). |
| overtime_minutes_capped | integer | Overtime after daily cap. 0 if invalid. Null for shift. |
| hours_counted | integer, nullable | Shift only. 24 if valid, 0 if invalid. Null for daily. |
| notes | text, nullable | Arabic reason if invalid. Null if valid. |

---

## app_settings

One row per setting key. Seeded with defaults on first launch. Never overwrites existing rows on re-seed.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| key | text, unique | Setting identifier — matches keys in `config.md` |
| value | text | Current value |

Predefined keys: `daily_start_time`, `daily_work_duration`, `daily_max_overtime`, `shift_start_times`, `shift_duration`, `shift_zone_interval`, `shift_start_end_tolerance`, `shift_inner_tolerance`, `shift_period_gap`, `shift_baseline_hours`, `shift_ceiling_hours`, `rounding_mode`.

---

## column_headers

One row per acceptable header value per field key.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| file_type | text | 'attendance', 'employees', or 'holidays' |
| field_key | text | Internal field identifier |
| header_value | text | Arabic column header to match |
| is_default | integer | 1 = built-in default, cannot be edited or deleted. 0 = user-added. |

---

## Report Versioning

`generation_date` is unique. Generating a new report on the same calendar day replaces the existing one — cascade delete removes all child rows first, then the new report is inserted fresh.

---

## Schema Initialization

Schema created on first launch if tables do not exist. A version number tracks schema changes — migrations applied in sequence on version mismatch. Default values seeded into `column_headers` and `app_settings` on first launch, existence-checked before insert.

---

## Later Improvements

**Report archiving.** Keep multiple reports per day with a sequence number. Requires changing the unique constraint on `generation_date`.

**Export history.** Track export events in a separate `export_log` table.
