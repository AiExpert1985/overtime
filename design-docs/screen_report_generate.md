# screen_report_generate

**Created**: 12-May-2026
**Modified**: 12-May-2026

---

## Purpose

The report generation screen. Pushed from the Reports List screen via the floating add button. Handles attendance file upload, date range selection, and employee selection. On successful generation, this screen is popped and the new Report screen is pushed in its place.

---

## Layout

RTL. Scrollable content arranged vertically:

1. Screen title
2. Attendance file picker card
3. Date range pickers (start and end)
4. Employee selection card
5. Generate report button

---

## Component — Attendance File Picker Card

Single card for the attendance file. Identical behavior to the original file picker card design — see the card states (empty / valid / invalid) and multi-file support described below.

### States

**Empty** — no file selected:
- Arabic label: ملف الحضور
- Info icon button (!)
- Button to pick a file

**Valid** — file passed validation:
- File name(s)
- Green success indicator
- Info icon button (!)
- Button to replace the file

**Invalid** — file failed validation:
- File name
- Red error indicator
- Arabic error message
- Info icon button (!)
- Button to try a different file

### Multi-File Support

Multiple attendance files may be selected at once. The card shows the count of valid files.

### Info Hint Dialog

Tapping (!) shows: ملف Excel يحتوي على عمودين: اسم الموظف، التاريخ والوقت. يمكن تقديم أكثر من ملف.

---

## Component — Date Range Pickers

Two calendar pickers: start date (من) and end date (إلى). Both must be filled for the Generate button to become active.

### Validation Rules

- End date must not be before start date.
- The range must not exceed `max_report_date_range` (default 31 days).

Inline Arabic error message shown below the pickers if either rule is violated.

---

## Component — Employee Selection Card

Shows the current selection state. Tapping opens the Employee Selection Dialog.

### States

**Empty** — no employees selected:
- Label: لم يتم اختيار أي موظفين
- Tap anywhere on the card to open the selection dialog

**With selection** — one or more employees selected:
- Count label: e.g. تم اختيار ٥ موظفين
- Tapping the card opens the selection dialog where the user can add or remove employees
- A secondary action to clear all: مسح الكل

---

## Employee Selection Dialog

Full-screen dialog. Shows the complete employees list with checkboxes. The current selection is pre-checked.

### Search Bar

Live search at the top. Filters by name, department, or employee number on each keystroke.

### Employee List

Each row shows: employee number, name, department, employment type. Checkbox on the right. The user may check and uncheck freely while searching — selections persist across search queries within the same dialog session.

### Actions

- **إغلاق** — discards any changes made in this dialog session and returns to the generation screen with the previous selection unchanged.
- **تأكيد** — applies the current checkbox state as the new selection and returns to the generation screen.

---

## Saved Selection (Default)

When the screen opens, the employee selection is pre-populated from the `report_selected_employees` table — the selection saved from the previous generation. The user may adjust it or use it as-is.

If no previous selection exists (first use), the selection starts empty.

The saved selection is updated in the database when the user presses Generate — not when they confirm in the dialog. If generation is aborted or fails, the saved selection is not updated.

---

## Component — Generate Report Button

Full-width prominent button labeled توليد التقرير.

### Enabled Condition

Enabled only when:
- Attendance file card is valid
- Both dates are selected and pass validation
- At least one employee is selected

### Loading State

Button switches to loading indicator. Screen becomes non-interactive.

### Success

The `report_selected_employees` table is updated with the current selection. This screen is popped and the new Report screen is pushed on top of the Reports List.

### Failure

Button returns to enabled state. Dismissible Arabic error banner appears at top. All inputs preserved.

---

## Screen State

All state held in a provider. Generate button observes combined readiness. File card state, date range, and employee selection all preserved if the user navigates away and returns within the same session.
