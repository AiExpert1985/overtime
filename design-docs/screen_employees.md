# screen_employees

**Created**: 12-May-2026
**Modified**: 12-May-2026

---

## Purpose

Tab 1 of the app. Manages the permanent list of employees used as the source for report generation. Employees added here are available for selection on every report. Changes here have no effect on previously generated reports.

---

## Layout

RTL. Scrollable table filling the screen. Floating add button (FAB) in the bottom-left corner. Two action buttons in the top bar: **كشف الجداول** (Detect Schedules) and **تصدير** (Export). Empty state message if no employees have been added yet: لم يتم إضافة أي موظفين بعد.

---

## Component — Employees Table

All employees displayed as a table, ordered alphabetically by name ascending.

| Column | Arabic Label | Content |
|---|---|---|
| Employee number | الرقم الوظيفي | Unique identifier |
| Name | الاسم | Full name |
| Employment type | نوع التوظيف | مناوب or صباحي |
| Department | القسم | Department name |
| Shift start | وقت البداية | Detected shift start time e.g. 08:00. Empty if daily or not yet detected. |
| Actions | — | Edit and delete icons per row |

Shift employees with no `detected_shift_start_time` are shown with a warning indicator in the Shift start column: لم يتم الكشف بعد. This signals they cannot be included in a report until detection runs or the value is set manually.

---

## Add / Edit Dialog

Tapping the FAB opens the Add dialog. Tapping the edit icon opens the same dialog pre-populated.

Fields:
- **الرقم الوظيفي** — text input, required, must be unique
- **الاسم** — text input, required
- **نوع التوظيف** — dropdown: مناوب / صباحي, required
- **القسم** — text input, required
- **وقت بداية المناوبة** — time picker, shown only when نوع التوظيف is مناوب. Optional — can be left empty and detected later. Allows manual override of the detected value.

Save button disabled until all required fields are filled. If the employee number already exists, an Arabic error is shown inline: الرقم الوظيفي مستخدم بالفعل. On successful save, row is inserted or updated immediately and the table refreshes.

---

## Detect Schedules

Tapping **كشف الجداول** opens a file picker for an attendance Excel file — same format as report generation. See `file_processing.md` for validation rules.

After a valid file is selected, detection runs immediately. A loading indicator is shown. When complete, a results summary dialog is shown. See `schedule_detection.md` for the full algorithm and outcome messages.

Detection overwrites `employment_type` and `detected_shift_start_time` only where confidence thresholds are met. Existing values are left unchanged where thresholds are not met.

---

## Delete

Tapping the delete icon shows an Arabic confirmation prompt before removal. Deletion is permanent — hard delete. If the deleted employee appears in `report_selected_employees` (saved selection cache), that row is cascade deleted automatically.

Previously generated reports are not affected — all result rows are denormalized snapshots.

---

## Report Generation Guard

A shift employee with no `detected_shift_start_time` cannot be selected for report generation. If such an employee is in the saved selection when the Report Generation screen opens, they are excluded from the pre-populated selection and a warning is shown: بعض الموظفين المناوبين لم يتم كشف وقت بدايتهم ولن يظهروا في القائمة.

---

## Data Source

Reads from and writes to the `employees` table via the ReferenceData repository.
