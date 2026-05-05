# screen_report

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

Shows a single generated report. Pushed on top of the Reports tab — reached automatically after generation or by tapping a row in the Reports list. A back button returns to the Reports list.

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

Reads from the current report provider. No database fetch on mount.
