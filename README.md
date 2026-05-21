# Overtime Calculator

A Windows desktop application built with Flutter that automates overtime calculation from biometric attendance data. It reads raw attendance exports from fingerprint devices, classifies each employee's work schedule automatically, and produces a detailed overtime report — with no manual data entry beyond uploading the files.

---

## The Problem

Calculating overtime from biometric attendance data is tedious and error-prone when done manually. Attendance exports from fingerprint devices are raw timestamp lists — they do not indicate whether an employee works a 24-hour shift schedule or a standard daily schedule, they do not separate regular days from off-days, and they do not apply the correct overtime formula per schedule type. Someone has to classify every employee, apply the right rules, and aggregate totals. This application does all of that automatically.

---

## How It Works

The user selects one or more attendance Excel files and a date range, then presses Generate. The app runs a 10-stage pipeline entirely without user input:

**Stage 1 — File Validation**
Each uploaded file is validated immediately on selection. The app checks that the file is a readable `.xlsx` file and that its columns match the configured header names (employee name, department, timestamp). Invalid files are flagged inline and excluded from generation.

**Stage 2 — Trigger**
The Generate button activates only when at least one valid file is loaded and a date range is set. Pressing it starts the pipeline.

**Stage 3 — Dictionary Build**
A single pass over all files and sheets collects every attendance record within the selected date range. The result is one entry per unique employee name, carrying their department and a sorted list of all their timestamps.

**Stage 4 — Schedule Detection**
The most complex stage. For each employee, the algorithm analyses their timestamp patterns to classify them as a shift employee, a daily employee, or undetected. For shift employees it also identifies which configured shift start time they work. No stored employee data is used — classification is derived entirely from how timestamps are distributed across the reporting period. The algorithm uses zone-based period validation, attendance density checks, and confidence voting to make the classification decision. Employees that do not clearly fit either schedule type are placed in an undetected bucket with a failure reason.

**Stage 5 — Off-Day Detection**
Runs on the daily employee bucket. The algorithm counts attendance across the date range and classifies any day where fewer than 25% of daily employees attended as an off-day. The result is a set of off-day dates used by the daily period extractor.

**Stage 6 — Shift Period Extraction**
For each shift employee, the report range is walked day by day. Each day is tested as a candidate shift start. A period is valid if enough zone checkpoints (evenly spaced across the 24-hour shift window) contain a timestamp within the configured tolerance. Valid periods are collected per employee.

**Stage 7 — Daily Period Extraction**
For each daily employee, timestamps are grouped by calendar date. Each date becomes a period, classified as a regular workday or an off-day using the set from Stage 5.

**Stage 8 — Shift Overtime Calculation**
Each shift period is validated by checking that all zone checkpoints are satisfied. Valid periods count as 24 hours worked; invalid periods count as zero. Per-employee total is capped at the monthly ceiling, the baseline is subtracted, and the result is the employee's overtime.

**Stage 9 — Daily Overtime Calculation**
Each daily period is validated. Regular days require at least two timestamps and a first timestamp within the configured delay allowance; overtime is time worked beyond the end of the standard workday, capped at the daily maximum. Off-days require only two timestamps; overtime is the full attendance span, also capped.

**Stage 10 — Storage and Navigation**
All three result sets (shift employees with period details, daily employees with period details, undetected employees) are written to SQLite in a single atomic transaction. After storage, the app navigates automatically to the Report screen for the new report.

---

## Output

The Report screen shows results split into two tabs — shift employees and daily employees. Each tab has summary cards (total employees, included count, gross overtime, deserved overtime), per-column inline filters (name, department, overtime presence, inclusion status), and an inclusion toggle per employee that writes to the database immediately. Tapping an employee row opens a detail screen showing the full period breakdown with zone-level data for shift employees.

Reports are stored permanently and accessible from the History screen. Both the report list view and the per-employee detail view can be exported to Excel at any time.

---

## Employee Types

**Shift employees** work 24-hour rotational shifts. Their overtime is the total valid shift hours above the monthly baseline, capped at the monthly ceiling. A shift is valid only if biometric stamps appear near each configured zone checkpoint throughout the 24-hour window.

**Daily employees** work a standard start-time to end-time schedule. Overtime accrues on regular days when the employee stays beyond the configured end time, and on off-days for any attendance at all. Each day is calculated independently and capped at a daily maximum.

**Undetected employees** appear in a separate screen with their failure reason and raw daily timestamp data. They are excluded from overtime totals.

---

## Tech Stack

| Concern | Solution |
|---|---|
| UI framework | Flutter (Windows desktop only) |
| State management | Riverpod 3.x (`AsyncNotifier` / `Notifier`) |
| Navigation | go_router |
| Database | SQLite via `sqflite_common_ffi` |
| Excel I/O | `excel` package |
| File picker | `file_picker` |
| Locale | Arabic (`ar`), RTL, all user-facing strings in Arabic |

---

## Architecture

The app follows a strict four-layer architecture: Presentation (widgets and providers), Application (generation service and business rules), Domain (plain data models), and Data (repositories). All business logic lives in the generation service. Providers expose state only. Screens observe providers and forward user intent — no logic in widgets.

All calculations happen at generation time and are stored. The report screens are purely passive — they read from the database and display, with no formulas running at load time. The database is the sole source of truth after generation completes.
