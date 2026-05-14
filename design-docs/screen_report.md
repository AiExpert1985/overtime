# screen_report

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Displays the results of one generated report. Loaded from the database on mount — same code path for newly generated reports and historical ones. All summaries computed live from the loaded rows.

---

## Layout

RTL. Three tabs — shift employees, daily employees, undetected employees. Each tab is fully self-contained. Back button in top bar returns to Reports List.

The active tab is remembered when navigating to the Detail screen and back.

---

## Data Loading

On mount, the report screen loads all three employee result sets from the database using the `reportId` route parameter:
- Shift employee results from `shift_employee_results`
- Daily employee results from `daily_employee_results`
- Undetected employee results from `undetected_employee_results`

Period details are NOT loaded here — they are fetched lazily by the Detail screen.

All summary values (totals, counts) are computed from the loaded rows. Only employees where `is_included = 1` contribute to summaries.

---

## Report Header

A minimal header above all tabs shows:
- Report generation date and time
- Date range the report covers

---

## Tab — Shift Employees (مناوبة)

### Summary Cards

Displayed at the top of the tab. Computed live from loaded rows. Only included employees (is_included = 1) counted.

- Total shift employees in report
- Total included employees
- Total overtime hours (sum across included employees)

### Filter Bar

**Radio buttons** — mutually exclusive, one must always be selected:
- **محتسبون** — show only included employees (is_included = 1). Default.
- **مستثنون** — show only excluded employees (is_included = 0).

**Search field** — live text search by employee name or department. Filters within the active radio selection.

**تصدير Excel** — exports shift employees only. Includes only included employees and their periods. Shows loading state. Success: snackbar with file path. Failure: error snackbar.

### Employee Table

| Column | Arabic label |
|---|---|
| Employee name | اسم الموظف |
| Department | القسم |
| Overtime hours | ساعات إضافية |
| Included | محتسب |

The **Included** column shows a toggle per row. Toggling updates `is_included` in the database immediately and recalculates the summary cards live. No confirmation prompt.

### Row Behavior

Tapping an employee row (outside the toggle) pushes the Detail screen, passing `employeeResultId` and `employeeType` as route parameters.

### Sorting

Alphabetical ascending by employee name within the active filter view.

### Empty State

- No shift employees in report: لا يوجد موظفون بنظام المناوبة.
- Search yields nothing: لا توجد نتائج مطابقة.

---

## Tab — Daily Employees (صباحي)

### Summary Cards

Computed live from loaded rows. Only included employees counted.

- Total daily employees in report
- Total included employees
- Total overtime hours (sum of overtime_minutes across included employees, converted with rounding)

### Filter Bar

Same structure as shift tab: radio buttons (محتسبون / مستثنون), search field, and export button.

**تصدير Excel** — exports daily employees only. Includes only included employees and their periods.

### Employee Table

| Column | Arabic label |
|---|---|
| Employee name | اسم الموظف |
| Department | القسم |
| Total overtime | المجموع |
| Included | محتسب |

Same toggle behavior as shift tab — immediate DB update, live summary recalculation.

### Row Behavior

Tapping an employee row (outside the toggle) pushes the Detail screen, passing `employeeResultId` and `employeeType` as route parameters.

### Sorting

Alphabetical ascending by employee name.

### Empty State

- No daily employees in report: لا يوجد موظفون بنظام الدوام الصباحي.
- Search yields nothing: لا توجد نتائج مطابقة.

---

## Tab — Undetected Employees (غير محدَّدون)

Employees whose employment type could not be determined during schedule detection. Shown for audit and debugging purposes only.

### Summary Card

- Total undetected employees in report

No overtime totals — undetected employees have no calculated data.

### Filter Bar

**Search field** only — live text search by employee name or department. No radio buttons, no export button.

### Employee Table

| Column | Arabic label |
|---|---|
| Employee name | اسم الموظف |
| Department | القسم |
| Failure reason | سبب عدم الكشف |

Read-only. No inclusion toggle. No row navigation — tapping a row does nothing.

### Sorting

Alphabetical ascending by employee name.

### Empty State

- No undetected employees: تم كشف جميع الموظفين بنجاح.

---

## Export Format

Each detected tab exports a separate `.xlsx` file. Undetected employees are never exported.

Export fetches period details for all included employees at export time — periods are not held in memory by the report screen.

**Shift export — ورقة واحدة:**
- Summary section: date range, total included employees, total overtime hours
- Employee table: name, department, overtime hours — included employees only, sorted alphabetically
- Period detail section: one section per employee with zone breakdown, ordered by period date ascending

**Daily export — ورقة واحدة:**
- Summary section: date range, total included employees, total overtime hours
- Employee table: name, department, total overtime — included employees only, sorted alphabetically
- Period detail section: one section per employee with per-day breakdown, ordered by date ascending

Export always uses the full included set regardless of active search filter.
