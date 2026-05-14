# schedule_detection

**Created**: 12-May-2026
**Modified**: 12-May-2026

---

## Purpose

Defines the algorithm for automatically detecting each employee's employment type (shift or daily) and, for shift employees, their shift start time. Results are written to the `employees` table. This is a standalone tool — not part of report generation. See `screen_employees.md` for how it is triggered.

---

## Inputs

- Attendance file — same format as used in report generation. See `file_processing.md`.
- Full employees list from the `employees` table.
- Config: `shift_start_times`, `shift_zone_interval`, `shift_start_end_tolerance`, `daily_start_time`.

No date range is selected by the user — the full date span present in the attendance file is used.

---

## Thresholds (applied at every stage)

| Threshold | Value | Meaning |
|---|---|---|
| Minimum detection density | 20% | Bucketed days / total scanned days must be ≥ 20% |
| Minimum confidence | 75% | Winning bucket / total bucketed days must be ≥ 75% |

Both thresholds must pass at each stage. Failing either at any stage produces an undetected result for that employee at that stage — existing values are left unchanged.

---

## Stage 1 — Day Scanning

For each employee, collect all days in the attendance file where the employee has at least one timestamp. These are the **scanned days**.

For each scanned day, divide the 24-hour period into zones using `shift_zone_interval`. Count how many zones contain at least one timestamp — these are **active zones**.

Zone count per day = `24 / shift_zone_interval` (default 24 / 6 = 4 zones).

Classify each day:
- Active zones > half of total zones → **shift day candidate**
- Active zones = half of total zones (exactly 2 out of 4) → **daily day candidate**
- Active zones < half (1 zone or fewer) → **discard** — not placed in any bucket

---

## Stage 2 — Employment Type Vote

After scanning all days:

- `shift_bucket` = count of shift day candidates
- `daily_bucket` = count of daily day candidates
- `total_bucketed` = shift_bucket + daily_bucket
- `total_scanned` = all days with at least one timestamp

**Density check:** `total_bucketed / total_scanned ≥ 0.20`
If fails → employee result: **undetected (insufficient data)**

**Confidence check:** `winning_bucket / total_bucketed ≥ 0.75`
If fails → employee result: **undetected (ambiguous type)**

If both pass → `employment_type` is confirmed as the winning bucket's type. Written to the employees table.

---

## Stage 3 — Shift Start Time Detection (shift employees only)

Only runs for employees confirmed as shift in Stage 2.

For each day in `shift_bucket`, scan for timestamps within `shift_start_end_tolerance` of each configured start time in `shift_start_times`. Assign the day to the sub-bucket of the closest matching start time. If a day has timestamps near multiple start times, assign to the closest match — if equidistant, assign to the earlier start time. If no configured start time matches within tolerance, discard the day from this stage.

- `total_start_bucketed` = days assigned to any start time sub-bucket
- `winning_start_bucket` = sub-bucket with the most days

**Density check:** `total_start_bucketed / shift_bucket ≥ 0.20`
If fails → employee result: **undetected (insufficient shift start data)**

**Confidence check:** `winning_start_bucket / total_start_bucketed ≥ 0.75`
If fails → employee result: **undetected (ambiguous shift start)**

If both pass → `detected_shift_start_time` is confirmed as the winning sub-bucket's start time. Written to the employees table.

---

## Writes

If Stage 2 passes: overwrite `employment_type` in the employees table.
If Stage 3 passes: overwrite `detected_shift_start_time` in the employees table.
If any stage fails: leave existing values unchanged — no partial overwrites within a stage.

Stages are independent per employee. An employee can have their type confirmed but start time left undetected (and unchanged) if Stage 3 fails.

---

## Results Summary

After detection completes, a summary is shown to the user. Per employee, one of the following outcomes:

| Outcome | Meaning |
|---|---|
| نوع التوظيف ووقت البداية محدَّدان | Type and start time both detected (shift employee) |
| نوع التوظيف محدَّد (صباحي) | Type detected as daily — no start time needed |
| نوع التوظيف محدَّد، وقت البداية غير محدَّد | Type detected as shift, start time detection failed |
| غير محدَّد: بيانات غير كافية | Density threshold failed at Stage 2 |
| غير محدَّد: نوع التوظيف غير واضح | Confidence threshold failed at Stage 2 |
| غير محدَّد: بيانات بداية المناوبة غير كافية | Density threshold failed at Stage 3 |
| غير محدَّد: وقت بداية المناوبة غير واضح | Confidence threshold failed at Stage 3 |

The summary shows counts per outcome and a per-employee breakdown. The user can dismiss and manually edit any employee whose detection failed.

---

## What This Algorithm Does NOT Do

- Does not detect daily employee start time — all daily employees use the global `daily_start_time` from config.
- Does not run automatically during report generation — it is a standalone tool.
- Does not affect previously generated reports — detection only writes to the `employees` table.
