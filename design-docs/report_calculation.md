# report_calculation

**Created**: 14-May-2026
**Modified**: 16-May-2026

---

## Purpose

Defines how report data is loaded from the database and how summary values are assembled for display. All business calculations are performed at generation time and stored — display is purely passive. No overtime formulas, no ceiling/baseline logic, no period aggregation runs at load time. Applies equally to newly generated reports and historical ones loaded from the reports list.

---

## Data Loading

### Report Screen Load

When the report screen mounts, three queries run in parallel using `reportId`:

1. Load all rows from `shift_employee_results` where `report_id = reportId`
2. Load all rows from `daily_employee_results` where `report_id = reportId`
3. Load all rows from `undetected_employee_results` where `report_id = reportId`

Each `shift_employee_results` row carries the pre-computed `overtime_hours` (stored in minutes). Each `daily_employee_results` row carries the pre-computed `total_overtime_minutes`. No period detail rows are loaded at this stage.

Period details are loaded lazily when the user opens the detail screen for a specific employee.

### Detail Screen Load

When the detail screen mounts, one query runs using `employeeResultId` and `employeeType`:

- If `employeeType = shift` → load all rows from `shift_period_details` where `employee_result_id = employeeResultId`
- If `employeeType = daily` → load all rows from `daily_period_details` where `employee_result_id = employeeResultId`

Order by `period_index` ascending.

---

## Shift Employee Display

### Per-Employee Overtime

Read directly from the stored `overtime_hours` field in `shift_employee_results`. No formula applied at display time.

### Per-Employee Totals (detail screen header)

All values read from stored period rows — no business logic:

- **Total valid periods** — count of period rows where `is_valid = 1`
- **Total worked hours** — sum of `total_attendance_duration` across all periods, converted to hours. Audit display only.
- **Total counted hours** — sum of `hours_counted` across all periods
- **Overtime hours** — read from the stored `overtime_hours` on the employee result row

### Report Tab Summary Cards

- **Total shift employees** — count of all shift_employee_results rows
- **Total included** — count where `is_included = 1`
- **Total overtime hours** — sum of stored `overtime_hours` for rows where `is_included = 1`. Simple addition only.

---

## Daily Employee Display

### Per-Employee Overtime

Read directly from the stored `total_overtime_minutes` field in `daily_employee_results`. No formula applied at display time.

### Per-Employee Totals (detail screen header)

- **Total overtime** — stored `total_overtime_minutes` converted to hours/minutes with configured rounding

### Report Tab Summary Cards

- **Total daily employees** — count of all daily_employee_results rows
- **Total included** — count where `is_included = 1`
- **Total overtime** — sum of stored `total_overtime_minutes` for rows where `is_included = 1`. Simple addition only. Displayed with configured rounding.

---

## Rounding

Applied at display time only. Raw minutes are never rounded in storage or calculation.

| Mode | Rule |
|---|---|
| none | Display raw minutes as hours and minutes |
| quarter | Round to nearest 15 minutes. Midpoint (≥ 8 min) rounds up. |
| half | Round to nearest 30 minutes. Midpoint (≥ 15 min) rounds up. |
| hour | Round to nearest 60 minutes. Midpoint (≥ 30 min) rounds up. |

Rounding applies to display and export output only. The stored `total_overtime_minutes` and `overtime_hours` values are always raw.

---

## is_included Toggle Behavior

When the user toggles `is_included` for an employee:

1. Update `is_included` in the database immediately
2. Add or subtract that employee's stored overtime value from the in-memory running total — no DB re-fetch, no business logic
3. UI updates instantly

---

## Undetected Employees

Loaded from `undetected_employee_results` and displayed in the undetected tab. No calculations apply — only name, department, and failure reason are shown. Never contribute to any summary card or export.

---

## Export

Export reads the stored per-employee values directly. Periods are fetched for all included employees at export time if not already loaded. Excluded employees (`is_included = 0`) are never exported.

**Shift export:**
- Per employee: stored `overtime_hours` converted for display
- Summary: total included employees, total overtime hours

**Daily export:**
- Per employee: stored `total_overtime_minutes` displayed with configured rounding
- Summary: total included employees, total overtime (with rounding)

Export always uses the full included set regardless of the active search filter on screen.
