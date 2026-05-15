# database_schema

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines all tables, columns, relationships, and versioning strategy. The schema is intentionally minimal — only report results and configuration are persisted. All employee data, detection results, and intermediate calculations are in-memory only and discarded after each generation.

---

## Tables Overview

```
reports
  ├── shift_employee_results      (FK → reports.id)
  │     └── shift_period_details  (FK → shift_employee_results.id)
  ├── daily_employee_results      (FK → reports.id)
  │     └── daily_period_details  (FK → daily_employee_results.id)
  └── undetected_employee_results (FK → reports.id)

column_headers
app_settings
```

---

## reports

One row per generated report. Multiple reports on the same calendar day are allowed.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | Foreign key used by all result tables |
| generation_datetime | text | ISO 8601 datetime — date and time the report was generated |
| range_start | text | ISO 8601 date |
| range_end | text | ISO 8601 date |

No aggregate totals are stored here. All summaries are computed live from the employee result tables when the report is loaded.

---

## shift_employee_results

One row per shift employee per report. Cascade deleted with parent report.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| report_id | integer, FK → reports.id | Cascade delete |
| employee_name | text | |
| department | text | Detected during generation — snapshot, not linked to any employee table |
| overtime_hours | integer | Total overtime hours for this employee |
| is_included | integer | 1 = included in report totals and export (default). 0 = excluded by user toggle. |

`is_included` defaults to 1 at generation time. The user may toggle it on the report screen. The value is persisted and survives app close/reopen.

---

## shift_period_details

One row per detected shift period per employee. Cascade deleted with parent employee result. Loaded only when the user opens the detail screen for a specific employee.

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
| is_valid | integer | 1 if period satisfied all zone rules, 0 if not. Set at generation time — never changes. |
| notes | text, nullable | Arabic invalid reason. Null if valid. |

---

## daily_employee_results

One row per daily employee per report. Cascade deleted with parent report.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| report_id | integer, FK → reports.id | Cascade delete |
| employee_name | text | |
| department | text | Detected during generation — snapshot, not linked to any employee table |
| overtime_minutes | integer | Total overtime minutes for this employee |
| is_included | integer | 1 = included in report totals and export (default). 0 = excluded by user toggle. |

`is_included` defaults to 1 at generation time. The user may toggle it on the report screen. The value is persisted and survives app close/reopen.

---

## daily_period_details

One row per detected daily period per employee. Cascade deleted with parent employee result. Loaded only when the user opens the detail screen for a specific employee.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| employee_result_id | integer, FK → daily_employee_results.id | Cascade delete |
| period_index | integer | Order of this period within the employee's results, 0-based |
| date | text | ISO 8601 date |
| weekday | text | Arabic weekday name e.g. الأحد. Stored at generation time — not recomputed later. |
| day_type | text | 'regular' or 'off' |
| all_timestamps | text | JSON array of ISO 8601 datetime strings, sorted ascending |
| total_attendance_duration | integer | Duration from first to last timestamp in minutes. Audit display only. |
| overtime_minutes | integer | Overtime for this period in minutes. 0 if invalid. |
| is_valid | integer | 1 if period satisfied validation rules, 0 if not. Set at generation time — never changes. |
| notes | text, nullable | Arabic invalid reason. Null if valid. |

---

## undetected_employee_results

One row per undetected employee per report. Cascade deleted with parent report. No period tables — undetected employees have no calculated data.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| report_id | integer, FK → reports.id | Cascade delete |
| employee_name | text | |
| department | text | |
| failure_reason | text | Arabic string describing why detection failed. See `schedule_detection.md`. |

Never contributes to any summary calculation. Not exported. Read-only in the report screen — no inclusion toggle.

---

## column_headers

One row per acceptable header value per field key. Attendance file only. Three field keys seeded by default: `employee_name`, `department`, `datetime`. Additional header values per field may be added by the user via the Settings screen.

| Column | Type | Notes |
|---|---|---|
| id | integer, PK, auto-increment | |
| file_type | text | 'attendance' only |
| field_key | text | Internal field identifier |
| header_value | text | Arabic column header to match |
| is_default | integer | 1 = built-in default, cannot be edited or deleted. 0 = user-added. |

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

## Report Storage

Reports are always appended — generating a new report never replaces or deletes an existing one. The user deletes reports manually from the Reports List screen. Deletion cascades through all child tables automatically.

---

## Schema Initialization

Schema created on first launch if tables do not exist. A version number tracks schema changes — migrations applied in sequence on version mismatch. Default values seeded into `column_headers` and `app_settings` on first launch, existence-checked before insert.

---

## Later Improvements

**Export history.** Track export events in a separate `export_log` table.

---

## Live Calculations at Load Time

When a report is loaded, the following are computed from the stored rows — never from stored aggregate fields:

- Total shift employees (count of shift_employee_results rows)
- Total daily employees (count of daily_employee_results rows)
- Total undetected employees (count of undetected_employee_results rows)
- Total included shift employees (count where is_included = 1)
- Total included daily employees (count where is_included = 1)
- Total shift overtime hours (sum of overtime_hours where is_included = 1)
- Total daily overtime minutes (sum of overtime_minutes where is_included = 1)
- Valid period counts, attendance duration sums, and all other summary values

This ensures summaries always reflect the current is_included state without requiring any update to the reports table.
