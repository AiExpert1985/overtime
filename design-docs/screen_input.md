# screen_input

**Created**: 27-Apr-2026 **Modified**: 05-May-2026 **Version**: 1.1

---

## Purpose

The first tab of the app. Collects the three required Excel files and triggers report generation. After successful generation, the app switches to the Reports tab automatically.

---

## Layout

Full RTL layout. All labels and buttons in Arabic. Content arranged vertically, scrollable if needed.

Visual hierarchy top to bottom:

1. Screen title
2. Three file picker cards
3. Date range pickers (start date and end date)
4. Generate report button

---

## Component — File Picker Card

Three cards — one per required input file: attendance files, target employees file, holidays file. Each card is self-contained and handles one file input end to end.

The info icon button (!) is always visible regardless of card state.

### States

**Empty** — no file selected:

- Arabic label for this input
- Info icon button (!)
- Button to pick a file

**Valid** — file passed validation:

- File name
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

Both attendance files and target employees files support multi-file selection. The user may select several files at once. The card shows the count of valid files selected and indicates if any failed. The holidays file accepts a single file only.

### Info Hint Dialog

Tapping (!) opens a small dismissible dialog with static Arabic text describing the expected structure of that file. Dismissed by tapping outside or a close button. For validation rules see `file_processing.md`.

**Attendance file hint:** ملف Excel يحتوي على عمودين:

- اسم الموظف
- التاريخ والوقت

يمكن تقديم أكثر من ملف، وكل ملف يمكن أن يحتوي على أكثر من ورقة عمل.

**Target employees file hint:** ملف Excel يحتوي على 3 أعمدة:

- اسم الموظف
- نوع التوظيف (مناوب أو صباحي)
- القسم

يمكن تقديم أكثر من ملف.

**Holidays file hint:** ملف Excel يحتوي على عمودين:

- التاريخ
- مناسبة العطلة

---

## Component — Date Range Pickers

Two calendar pickers displayed inline on the screen: start date (من) and end date (إلى). Each opens a calendar on tap. Both must be filled for the Generate button to become active. The selected dates persist when switching tabs — they are not reset unless generation succeeds.

### Validation Rules

- End date must not be before start date.
- The range (end date − start date + 1) must not exceed the configured maximum (`max_report_date_range`, default 31 days).

If either rule is violated, an inline Arabic error message is shown below the date pickers and the Generate button remains disabled.

---

## Component — Generate Report Button

Full-width prominent button labeled توليد التقرير.

### Enabled Condition

Enabled only when all three file cards are in the valid state AND both start and end dates are selected AND the date range passes validation (end ≥ start, range ≤ max).

### Tapped

Generation begins immediately — no dialog.

### Loading State

Button switches to loading indicator. Screen becomes non-interactive until generation completes.

### Success

App switches to Tab 2 (Reports) and pushes the new Report screen automatically. All file selections and date pickers are reset to empty state.

### Failure

Button returns to enabled state. Dismissible error banner appears at top of screen with Arabic error message. File selections and dates are preserved.

---

## Screen State

File card states and date range held in a provider. Generate button observes combined readiness — enabled only when all cards are valid and both dates are selected. No widget computes readiness independently.

File selections and date range preserved when switching tabs — reset only on successful generation.

---

## Later Improvements

**Remember last used files.** Pre-populate cards with last successfully used file paths on next launch.

**Drag and drop.** Allow files to be dragged onto cards on desktop.