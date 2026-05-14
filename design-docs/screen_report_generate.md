# screen_report_generate

**Created**: 12-May-2026
**Modified**: 14-May-2026

---

## Purpose

The report generation screen. Pushed from the Reports List screen via the floating add button. Handles attendance file upload and date range selection only — no employee selection. Employees are detected automatically from the attendance file during generation. On successful generation, this screen is popped and the new Report screen is pushed in its place.

---

## Layout

RTL. Scrollable content arranged vertically:

1. Screen title
2. Attendance file picker card
3. Date range pickers (start and end)
4. Generate report button

---

## Component — Attendance File Picker Card

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

Multiple attendance files may be selected at once. The card shows the count of valid files. All files are processed together in Stage 3.

### Info Hint Dialog

Tapping (!) shows: ملف Excel يحتوي على ثلاثة أعمدة: اسم الموظف، القسم، التاريخ والوقت. يمكن تقديم أكثر من ملف، وكل ملف يمكن أن يحتوي على أكثر من ورقة عمل.

---

## Component — Date Range Pickers

Two calendar pickers: start date (من) and end date (إلى). Both must be filled for the Generate button to become active.

### Validation Rules

- End date must not be before start date.
- The range must not exceed `max_report_date_range` (default 31 days).

Inline Arabic error message shown below the pickers if either rule is violated.

---

## Component — Generate Report Button

Full-width prominent button labeled توليد التقرير.

### Enabled Condition

Enabled only when:
- At least one attendance file card is valid
- Both dates are selected and pass validation

### Loading State

Button switches to loading indicator. Screen becomes non-interactive. Generation runs through all stages silently — detection, extraction, calculation, storage — with no interruptions or dialogs.

### Success

This screen is popped and the new Report screen is pushed on top of the Reports List. Undetected employees are visible in the report's undetected tab.

### Failure

Button returns to enabled state. Dismissible Arabic error banner appears at top. All inputs preserved.

---

## Screen State

All state held in a provider. Generate button observes combined readiness. File card state and date range preserved if the user navigates away and returns within the same session.
