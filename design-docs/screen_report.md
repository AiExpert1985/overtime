# screen_report

**Created**: 27-Apr-2026
**Modified**: 05-May-2026

---

## Layout

RTL. Fixed summary header at top. Tab bar below the header. Scrollable employee table inside each tab. Back button in top bar.

The active employee tab (daily/shift) is remembered when navigating to the Detail screen and back.

---

## Component — Report Header

Displayed above both tabs. Shows:

- Date range the report covers
- Total employees (matched and unmatched combined)
- Total shift overtime hours (sum across matched shift employees)
- Total daily regular overtime hours (sum across matched daily employees, with rounding)
- Total daily holiday overtime hours (sum across matched daily employees, with rounding)
- Unmatched employee count

---

## Component — Action Bar

Sits between header and tab bar. One action:

**تصدير Excel** — exports current report to Downloads folder. Shows loading state during export. Success: snackbar with file path. Failure: error snackbar.

### Export Format

Single `.xlsx` file with two sheets:

**Sheet 1 — ملخص التقرير**: mirrors the Report screen. Contains the report header summary (date range, totals, unmatched count) followed by the daily employees table and the shift employees table, each with the same columns shown on screen.

**Sheet 2 — تفاصيل الموظفين**: mirrors the Detail screen layout. One section per employee (daily and shift combined), separated by a blank row. Each section begins with the employee name and header values, followed by their period rows with the same columns shown on the detail screen.

---

## Tab — Daily Employees

### Table Columns

| Column | Arabic label |
|---|---|
| Employee name | اسم الموظف |
| Department | القسم |
| Regular overtime | ساعات عادية |
| Holiday overtime | ساعات عطلة |
| Grand total | المجموع |

Grand total = regular + holiday, displayed with configured rounding mode.

### Sorting

Alphabetical ascending by employee name.

### Row Behavior

Tapping any matched employee row pushes the Detail screen. See `screen_detail.md`.

### Unmatched Employees

Shown at bottom with red background. Notes column: لم يتم العثور على سجلات للحضور، يجب التحقق من صحة الاسم. No navigation on tap.

### Empty State

لا يوجد موظفون بنظام الدوام الصباحي.

---

## Tab — Shift Employees

### Table Columns

| Column | Arabic label |
|---|---|
| Employee name | اسم الموظف |
| Department | القسم |
| Overtime hours | ساعات إضافية |

### Sorting

Alphabetical ascending by employee name.

### Row Behavior

Tapping any matched employee row pushes the Detail screen. See `screen_detail.md`.

### Unmatched Employees

Same behavior as daily tab.

### Empty State

لا يوجد موظفون بنظام المناوبة.

---

## Data Source

Loads the full report from the database on mount using the `reportId` route parameter. This applies equally to newly generated reports and historical ones — there is no special path for either. A loading indicator is shown while the fetch completes.
