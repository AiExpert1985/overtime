# report_calculation

**Created**: 14-May-2026
**Modified**: 14-May-2026

---

## Purpose

Defines how report data is loaded from the database and how all aggregations, summaries, and per-employee overtime values are computed. Nothing in this document is stored — everything is calculated at load time from the raw stored rows. Applies equally to newly generated reports and historical ones loaded from the reports list.

---

## Data Loading

### Report Screen Load

When the report screen mounts, three queries run in parallel using `reportId`:

1. Load all rows from `shift_employee_results` where `report_id = reportId`
2. Load all rows from `daily_employee_results` where `report_id = reportId`
3. Load all rows from `undetected_employee_results` where `report_id = reportId`

Period details are **not** loaded at this stage. They are fetched lazily when the user opens the detail screen for a specific employee.

### Detail Screen Load

When the detail screen mounts, one query runs using `employeeResultId` and `employeeType`:

- If `employeeType = shift` → load all rows from `shift_period_details` where `employee_result_id = employeeResultId`
- If `employeeType = daily` → load all rows from `daily_period_details` where `employee_result_id = employeeResultId`

Order by `period_index` ascending.

---

## Shift Employee Calculations

### Per-Employee Overtime

Computed from the employee's `shift_period_details` rows:

```
total_worked_hours = sum of hours_counted across all periods
capped_hours = min(total_worked_hours, shift_ceiling_hours)
overtime_hours = max(0, capped_hours - shift_baseline_hours)
```

An employee with all invalid periods has `total_worked_hours = 0` → `overtime_hours = 0`. Still appears in the report — distinct from an undetected employee.

### Per-Employee Totals (detail screen header)

- **Total valid periods** — count of periods where `is_valid = 1`
- **Total worked hours** — sum of `total_attendance_duration` across all periods, converted to hours. Audit display only.
- **Total counted hours** — sum of `hours_counted` across all periods
- **Overtime hours** — computed as above

### Report Tab Summary Cards

Computed from loaded `shift_employee_results` rows and their period data:

- **Total shift employees** — count of all shift employee result rows
- **Total included** — count where `is_included = 1`
- **Total overtime hours** — sum of per-employee `overtime_hours` for included employees only

---

## Daily Employee Calculations

### Per-Employee Overtime

Computed from the employee's `daily_period_details` rows:

```
total_overtime_minutes = sum of overtime_minutes across all periods
```

No ceiling or baseline — each period's overtime is already capped at `daily_max_overtime` during generation.

### Per-Employee Totals (detail screen header)

- **Total overtime** — `total_overtime_minutes` converted to hours/minutes with configured rounding

### Report Tab Summary Cards

Computed from loaded `daily_employee_results` rows and their period data:

- **Total daily employees** — count of all daily employee result rows
- **Total included** — count where `is_included = 1`
- **Total overtime** — sum of `total_overtime_minutes` for included employees only, displayed with configured rounding

---

## Rounding

Applied at display time only. Raw minutes are never rounded in storage or calculation.

| Mode | Rule |
|---|---|
| none | Display raw minutes as hours and minutes |
| quarter | Round to nearest 15 minutes. Midpoint (≥ 8 min) rounds up. |
| half | Round to nearest 30 minutes. Midpoint (≥ 15 min) rounds up. |
| hour | Round to nearest 60 minutes. Midpoint (≥ 30 min) rounds up. |

---

## is_included Toggle Behavior

When the user toggles `is_included` for an employee:

1. Update `is_included` in the database immediately
2. Recompute all summary cards live from the already-loaded in-memory data — no DB re-fetch needed
3. UI updates instantly

---

## Undetected Employees

Loaded from `undetected_employee_results` and displayed in the undetected tab. No calculations apply — only name, department, and failure reason are shown. Never contribute to any summary card or export.

---

## Export Calculations

Export uses the same calculations defined above. Periods are fetched for all included employees at export time if not already loaded. Excluded employees (`is_included = 0`) are never exported.

**Shift export totals:**
- Per employee: overtime hours as computed above
- Summary: total included employees, total overtime hours

**Daily export totals:**
- Per employee: total overtime minutes displayed with configured rounding
- Summary: total included employees, total overtime hours (with rounding)
