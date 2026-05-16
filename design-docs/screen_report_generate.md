# screen_report_generate

**Created**: 12-May-2026
**Modified**: 14-May-2026

---

## Purpose

The report generation screen. Pushed from the Reports List screen via the floating add button. Handles attendance file upload and date range selection only — no employee selection. Employees are detected automatically from the attendance file during generation. On successful generation, this screen is popped and the new Report screen is pushed in its place.

---

## Layout

RTL. Single scrollable screen. Content horizontally centered. Scrollable content arranged vertically:

1. Screen title
2. Attendance file picker card
3. Date range pickers (start and end)
4. Generate report button

---

## Component — Attendance File List Card

A single card that acts as a container for all uploaded attendance files. The card is always visible. Files are added to it sequentially or in bulk — each upload appends to the existing list without affecting previously added files.

### Card States

**Empty** — no files uploaded yet:
- Arabic label: ملفات الحضور
- Info icon button (!)
- Prompt text: لم يتم إضافة أي ملفات بعد
- Add files button

**With files** — one or more files present:
- Info icon button (!)
- List of file rows (see below)
- Add more files button at the bottom of the card

### File Row

Each uploaded file occupies one row inside the card:

| Element | Details |
|---|---|
| File name | Truncated if too long |
| Status indicator | Green check if valid, red X if invalid |
| Error message | Shown below file name if invalid — Arabic reason |
| Delete icon | Removes this file from the list and from memory immediately. No confirmation prompt. |

### Adding Files

Tapping either the initial add button or the "add more" button opens the file picker. The user may select one or multiple files at once. Each selected file is appended to the list and validated immediately. Files already in the list are unaffected.

Maximum 10 files per report. If adding the selected files would bring the total above 10, all selected files are rejected and an inline Arabic error is shown: يُسمح بحد أقصى 10 ملفات فقط. The "add more" button is hidden once 10 files are loaded.

### Validation

Each file is validated on append — column headers checked, at least one valid row required. Validation is per-file and independent. Adding a new file does not re-validate existing files.

### Invalid Files

Invalid files remain visible in the list with their error reason. They are never used during generation — only valid files are processed. The user may delete them or leave them. Their presence does not block generation as long as at least one valid file exists.

### Info Hint Dialog

Tapping (!) shows: ملف Excel يحتوي على ثلاثة أعمدة: اسم الموظف، القسم، التاريخ والوقت. يمكن تقديم أكثر من ملف، وكل ملف يمكن أن يحتوي على أكثر من ورقة عمل.

---

## Component — Date Range Pickers

Two calendar pickers: start date (من) and end date (إلى). Both must be filled for the Generate button to become active.

### Validation Rules

- End date must not be before start date.
- The range must not exceed `max_report_date_range` (default 32 days).
- Both the start date and end date are inclusive — records on both boundary dates are included in the report.

Inline Arabic error message shown below the pickers if either rule is violated.

---

## Component — Generate Report Button

Full-width prominent button labeled توليد التقرير.

### Enabled Condition

Enabled only when:
- At least one file in the list has valid status
- Both dates are selected and pass validation

Invalid files in the list do not block the button — only valid file count matters.

### Loading State

Button switches to loading indicator. Screen becomes non-interactive. Generation runs through all stages silently — detection, extraction, calculation, storage — with no interruptions or dialogs.

### Success

This screen is popped and the new Report screen is pushed on top of the Reports List. Undetected employees are visible in the report's undetected tab.

### Failure

Button returns to enabled state. Dismissible Arabic error banner appears at top. All inputs preserved.

---

## Screen State

All state held in a provider. Generate button observes combined readiness — at least one valid file and both dates filled and valid. The file list and date range are preserved if the user navigates away and returns within the same session. On successful generation, the file list and date range are cleared.
