# schedule_detection

**Created**: 12-May-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the algorithm for detecting each employee's employment type (shift or daily) and, for shift employees, their shift start time. Runs inline as Stage 4 of the report generation pipeline. Operates entirely on the working dictionary built in Stage 3. No database reads or writes during detection. No user interaction — runs silently to completion.

---

## Inputs

- Working dictionary: `employeeName → { name, department, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Config: `shift_start_times`, `shift_zone_interval`, `shift_start_end_tolerance`, `daily_start_time`

---

## Thresholds

| Threshold | Value | Meaning |
|---|---|---|
| Minimum detection density | 20% | Bucketed days / total scanned days must be ≥ 20% |
| Minimum confidence | 75% | Winning bucket / total bucketed days must be ≥ 75% |

Both thresholds must pass at each stage. Failing either produces an undetected result for that employee.

---

## Per-Employee Detection

Runs independently for each employee in the dictionary.

### Stage A — Day Scanning

Collect all days where the employee has at least one timestamp. These are the **scanned days**.

For each scanned day, divide the 24-hour period into zones using `shift_zone_interval`. Count how many zones contain at least one timestamp — these are **active zones**.

Zone count per day = `24 / shift_zone_interval` (default 24 / 6 = 4 zones).

Classify each day:
- Active zones > half of total zones → **shift day candidate**
- Active zones = half of total zones (exactly 2 out of 4) → **daily day candidate**
- Active zones < half (1 zone or fewer) → **discard**

### Stage B — Employment Type Vote

- `shift_bucket` = count of shift day candidates
- `daily_bucket` = count of daily day candidates
- `total_bucketed` = shift_bucket + daily_bucket
- `total_scanned` = all days with at least one timestamp

**Density check:** `total_bucketed / total_scanned ≥ 0.20`
If fails → result: **undetected (insufficient data)**

**Confidence check:** `winning_bucket / total_bucketed ≥ 0.75`
If fails → result: **undetected (ambiguous type)**

If both pass → employment type confirmed as winning bucket's type.

### Stage C — Shift Start Time Detection (shift employees only)

For each day in `shift_bucket`, scan for timestamps within `shift_start_end_tolerance` of each configured start time in `shift_start_times`. Assign the day to the sub-bucket of the closest matching start time. If equidistant between two start times, assign to the earlier one. If no configured start time matches within tolerance, discard the day from this stage.

- `total_start_bucketed` = days assigned to any start time sub-bucket
- `winning_start_bucket` = sub-bucket with the most days

**Density check:** `total_start_bucketed / shift_bucket ≥ 0.20`
If fails → result: **undetected (insufficient shift start data)**

**Confidence check:** `winning_start_bucket / total_start_bucketed ≥ 0.75`
If fails → result: **undetected (ambiguous shift start)**

If both pass → shift start time confirmed as the winning sub-bucket's start time.

---

## Detection Failure Reasons

Stored on the undetected employee result. Shown in the report's undetected tab.

| Reason | Arabic |
|---|---|
| Stage B density failed | بيانات غير كافية للكشف |
| Stage B confidence failed | نوع التوظيف غير واضح |
| Stage C density failed | بيانات بداية المناوبة غير كافية |
| Stage C confidence failed | وقت بداية المناوبة غير واضح |

---

## Output — Three Buckets

After detection completes for all employees, the working dictionary is split into three buckets passed to the next stages:

**Shift hash table:** `employeeName → { name, department, detectedShiftStartTime, [timestamps] }`
Employees confirmed as shift with a confirmed start time.

**Daily hash table:** `employeeName → { name, department, [timestamps] }`
Employees confirmed as daily.

**Undetected list:** `[ { name, department, failureReason } ]`
Employees who failed detection at any stage. Carried directly to storage in Stage 7 — no extraction or calculation runs for them.

All three are in-memory only. None is persisted until Stage 7.

---

## What This Algorithm Does NOT Do

- Does not read from or write to the database
- Does not use any previously stored employee data
- Does not show any dialog or pause generation
- Does not detect daily employee start time — all daily employees use the global `daily_start_time` from config
