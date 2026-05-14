# database_schema

**Created**: 27-Apr-2026
**Modified**: 12-May-2026

---

## Purpose

Defines all tables, columns, relationships, and versioning strategy. FileProcessing has no database presence. The Reporting feature owns report result tables. The ReferenceData feature owns employees, holidays, and the attendance column headers table.

---

## Tables Overview

```
employees
holidays
report_selected_employees

reports
  ├── daily_employee_results
  │     └── daily_period_details
  └── shift_employee_results
        └── shift_period_details

column_headers
app_settings
```

---

## employees

One row per employee. Permanent reference data — not tied to any report. Hard delete only.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| employee_number | text, unique | Unique identifier. Enforced at DB level. |
| name | text | Full name. Used as join key during report generation. Case-sensitive and whitespace-sensitive. |
| employment_type | text | 'shift' or 'daily' |
| department | text | Display only — no effect on calculation |
| detected_shift_start_time | text, nullable | Time string e.g. '08:00'. Set by schedule detection. Null until detected. Only meaningful for shift employees. |

No FK relationship to any report table. Deleting an employee has no effect on previously generated reports — all result rows are denormalized snapshots. Employee number uniqueness is enforced at the DB level — the add/edit dialog shows an Arabic error if a duplicate is entered.

---

## holidays

One row per holiday date. Permanent reference data — flat list, no year scoping. Used only during daily overtime calculation to classify day types.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| date | text | ISO 8601 date |
| occasion | text | Arabic name or description. Display only — no effect on calculation. |

No FK relationship to any report table. Deleting a holiday has no effect on previously generated reports — day type is stored as a denormalized snapshot in `daily_period_details`.

---

## reports

One row per generated report. Multiple reports on the same calendar day are allowed.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| generation_datetime | text | ISO 8601 datetime — date and time the report was generated |
| range_start | text | ISO 8601 date |
| range_end | text | ISO 8601 date |
| total_employees | integer | Matched and unmatched combined |
| total_shift_overtime_hours | integer | Sum of overtime hours across all matched shift employees |
| total_daily_overtime_minutes | integer | Sum of regular workday overtime minutes across all matched daily employees |
| total_holiday_overtime_minutes | integer | Sum of holiday/weekend overtime minutes across all matched daily employees |
| unmatched_employee_count | integer | |

---

## daily_employee_results

One row per daily employee per report. Cascade deleted with parent report.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| report_id | integer, FK → reports.id | Cascade delete |
| employee_name | text | |
| department | text | |
| overtime_minutes | integer | Regular workday overtime total in minutes. 0 if unmatched. |
| holiday_overtime_minutes | integer | Holiday/weekend overtime total in minutes. 0 if unmatched. |
| is_unmatched | integer | 1 if no attendance records found, 0 if matched |
| notes | text, nullable | Arabic message for unmatched employees. Null if matched. |

---

## daily_period_details

One row per detected daily period per employee result. Cascade deleted with parent employee result.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| employee_result_id | integer, FK → daily_employee_results.id | Cascade delete |
| period_index | integer | Order of this period within the employee's results, 0-based |
| date | text | ISO 8601 date |
| weekday | text | Arabic weekday name e.g. الأحد |
| day_type | text | 'regular', 'holiday', or 'weekend' |
| all_timestamps | text | JSON array of ISO 8601 datetime strings, sorted ascending |
| total_attendance_duration | integer | Duration from first to last timestamp in minutes. Audit display only. |
| overtime_minutes | integer | Calculated overtime in minutes. 0 if invalid. |
| is_valid | integer | 1 if period contributed to overtime, 0 if invalid |
| notes | text, nullable | Arabic invalid reason. Null if valid. |

---

## shift_employee_results

One row per shift employee per report. Cascade deleted with parent report.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| report_id | integer, FK → reports.id | Cascade delete |
| employee_name | text | |
| department | text | |
| overtime_hours | integer | Total overtime hours. 0 if unmatched. |
| is_unmatched | integer | 1 if no attendance records found, 0 if matched |
| notes | text, nullable | Arabic message for unmatched employees. Null if matched. |

---

## shift_period_details

One row per detected shift period per employee result. Cascade deleted with parent employee result.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| employee_result_id | integer, FK → shift_employee_results.id | Cascade delete |
| period_index | integer | Order of this period within the employee's results, 0-based |
| period_date | text | ISO 8601 date this period is anchored to |
| end_date | text | ISO 8601 date of last timestamp |
| all_timestamps | text | JSON array of ISO 8601 datetime strings, sorted ascending |
| total_attendance_duration | integer | Duration from first to last timestamp in minutes. Audit display only. |
| zone_data | text | JSON array of zone results: [{ centerTime, timestamps[], isSatisfied }] |
| hours_counted | integer | 24 if valid, 0 if invalid |
| is_valid | integer | 1 if period contributed to overtime, 0 if invalid |
| notes | text, nullable | Arabic invalid reason. Null if valid. |

---

## report_selected_employees

Persists the employee selection from the most recent report generation attempt. Loaded as the default selection when the user opens the Report Generation screen. Replaced entirely each time the user confirms a new selection and starts generation.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| employee_id | integer, FK → employees.id | Cascade delete — if employee is deleted, the saved selection row is removed |

This is the only table that holds a FK to `employees`. It is safe to cascade delete because it is a UI convenience cache, not a report result.

---

## app_settings

One row per setting key. Seeded with defaults on first launch. Never overwrites existing rows on re-seed.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| key | text, unique | Setting identifier — matches keys in `config.md` |
| value | text | Current value |

Predefined keys: `daily_start_time`, `daily_work_duration`, `daily_max_overtime`, `shift_start_times`, `shift_duration`, `shift_zone_interval`, `shift_start_end_tolerance`, `shift_inner_tolerance`, `shift_baseline_hours`, `shift_ceiling_hours`, `rounding_mode`, `max_report_date_range`.

---

## column_headers

One row per acceptable header value per field key. Only attendance file headers are managed here — employees and holidays are no longer file-based.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| file_type | text | 'attendance' only |
| field_key | text | Internal field identifier |
| header_value | text | Arabic column header to match |
| is_default | integer | 1 = built-in default, cannot be edited or deleted. 0 = user-added. |

---

## Report Storage

Reports are always appended — generating a new report never replaces or deletes an existing one. The user deletes reports manually from the Report List screen. Each report is identified by its auto-increment `id`. Multiple reports covering the same date range or generated on the same day are permitted.

---

## Schema Initialization

Schema created on first launch if tables do not exist. A version number tracks schema changes — migrations applied in sequence on version mismatch. Default values seeded into `column_headers` and `app_settings` on first launch, existence-checked before insert. The `employees` and `holidays` tables start empty — no seeded data.

---

## Later Improvements

**Export history.** Track export events in a separate `export_log` table.
