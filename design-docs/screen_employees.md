# screen_employees

**Created**: 12-May-2026
**Modified**: 12-May-2026

---

## Purpose

Tab 1 of the app. Manages the permanent list of employees used as the source for report generation. Employees added here are available for selection on every report. Changes here have no effect on previously generated reports.

---

## Layout

RTL. Scrollable table filling the screen. Floating add button (FAB) in the bottom-left corner. Empty state message if no employees have been added yet: لم يتم إضافة أي موظفين بعد.

---

## Component — Employees Table

All employees displayed as a table, ordered alphabetically by name ascending.

| Column | Arabic Label | Content |
|---|---|---|
| Employee number | الرقم الوظيفي | Display only |
| Name | الاسم | Full name |
| Employment type | نوع التوظيف | مناوب or صباحي |
| Department | القسم | Department name |
| Actions | — | Edit and delete icons per row |

---

## Add / Edit Dialog

Tapping the FAB opens the Add dialog. Tapping the edit icon opens the same dialog pre-populated.

Fields:
- **الرقم الوظيفي** — text input, required, must be unique
- **الاسم** — text input, required
- **نوع التوظيف** — dropdown: مناوب / صباحي, required
- **القسم** — text input, required

Save button disabled until all fields are filled. If the employee number already exists, an Arabic error is shown inline: الرقم الوظيفي مستخدم بالفعل. On successful save, row is inserted or updated immediately and the table refreshes.

---

## Delete

Tapping the delete icon shows an Arabic confirmation prompt before removal. Deletion is permanent — hard delete. If the deleted employee appears in `report_selected_employees` (saved selection cache), that row is cascade deleted automatically.

Previously generated reports are not affected — all result rows are denormalized snapshots.

---

## Data Source

Reads from and writes to the `employees` table via the ReferenceData repository.
