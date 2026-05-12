# screen_report

**Created**: 27-Apr-2026
**Modified**: 12-May-2026

---

## Layout

RTL. Fixed summary header at top. Search and filter bar below the header. Tab bar below that. Scrollable employee table inside each tab. Back button in top bar.

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

## Component — Search and Filter Bar

Sits between the report header and the tab bar. All controls are in a single centered row:

**Search field** — live text search by employee name or department. Filters the active tab's rows on each keystroke. Scoped to whichever tab is currently visible.

**Filter chips** — three checkboxes, all checked by default:

| Chip | Arabic label | Matches |
|---|---|---|
| With overtime | مع وقت إضافي | Matched employees whose overtime > 0 |
| Without overtime | بدون وقت إضافي | Matched employees whose overtime = 0 |
| Unmatched | غير موجودين | Employees with no attendance records found |

Unchecking a chip hides that category. Search and filter combine with AND logic — a row must satisfy both the text query and the active chip set to appear.

**تصدير Excel** — at the end of the row. Exports the full unfiltered report to Downloads. Shows loading state during export. Success: snackbar with file path. Failure: error snackbar.

### Empty State under Active Filter

When the combined search + filter yields no rows, the tab shows **لا توجد نتائج مطابقة** instead of the normal no-employees message.

### Export Format

Single `.xlsx` file with two sheets:

**Sheet 1 — ملخص التقرير**: mirrors the Report screen. Contains the report header summary (date range, totals, unmatched count) followed by the daily employees table and the shift employees table, each with the same columns shown on screen.

**Sheet 2 — تفاصيل الموظفين**: mirrors the Detail screen layout. One section per employee (daily and shift combined), separated by a blank row. Each section begins with the employee name and header values, followed by their period rows with the same columns shown on the detail screen.

Export always uses the full unfiltered dataset regardless of active search or filter state.

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

- No employees in report: لا يوجد موظفون بنظام الدوام الصباحي.
- Active search/filter yields nothing: لا توجد نتائج مطابقة.

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

- No employees in report: لا يوجد موظفون بنظام المناوبة.
- Active search/filter yields nothing: لا توجد نتائج مطابقة.

---

## Data Source

Loads the full report from the database on mount using the `reportId` route parameter. This applies equally to newly generated reports and historical ones — there is no special path for either. A loading indicator is shown while the fetch completes.
