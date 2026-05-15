# schedule_detection

**Created**: 12-May-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the algorithm for detecting each employee's employment type (shift or daily) and, for shift employees, their shift start time. Runs inline as Stage 4 of the report generation pipeline. Operates entirely on the working dictionary built in Stage 3. No database reads or writes during detection. No user interaction — runs silently to completion.

---

## Inputs

- Working dictionary: `employeeName → { name, department, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Report period duration — total calendar days between report start and end date (inclusive). Used as the denominator for the 20% threshold.
- Config: `shift_start_times`, `shift_zone_interval`, `shift_tolerance`

---

## Employee Type Enumeration

Every employee is assigned exactly one of three types as the output of this stage:

| Type | Meaning |
|---|---|
| `shift` | Confirmed shift employee with a detected start time |
| `daily` | Confirmed daily employee |
| `undetected` | Could not be classified — stored with a failure reason |

---

## Algorithm 1 — Employment Type Detection

Runs iteratively — independently for each employee in the dictionary.

### Pre-Check — Attendance Density

Count all calendar days where the employee has at least 1 timestamp. This answers: did this employee show up enough days to be worth analyzing at all?

**Note:** This check is intentionally separate from Stage 1. The pre-check measures raw presence — how many days this employee appeared in the attendance file regardless of timestamp quality. Stage 1 then filters to days with ≥ 2 timestamps, which are the only days usable for zone analysis. An employee could pass the pre-check but still fail Stage 1 if most of their days had only a single timestamp.

`attendance_days / report_period_days ≥ 20%`

If fails → mark employee as `undetected`, reason: **أيام الحضور أقل من 20% من مدة الفترة**, skip to next employee.

### Stage 1 — Day Filtering

From the employee's days, discard any day with fewer than 2 timestamps — these days cannot produce meaningful zone signal. Check the remaining days (days with ≥ 2 timestamps):

`remaining_days / report_period_days ≥ 20%`

If fails → mark employee as `undetected`, reason: **أيام الحضور الصالحة أقل من 20% من مدة الفترة**, skip to next employee.

If passes → proceed to Stage 2 with these days.

### Stage 2 — Zone Bucketing

For each remaining day, divide the 24-hour period into zones using `shift_zone_interval`. Count active zones (zones containing at least one timestamp).

Zone count per day = `24 / shift_zone_interval` (default 24 / 6 = 4 zones).

Classify each day:
- 1 active zone → **discard** (insufficient signal)
- 2 active zones → **daily bucket**
- 3 or more active zones → **shift bucket**

**Note:** A day with 0 active zones cannot occur at this stage — Stage 1 guarantees every day has ≥ 2 timestamps, so at least 1 zone will always be active.

### Stage 3 — Employment Type Vote

- `winning_bucket` = whichever of shift or daily bucket has more days
- `losing_bucket` = the other bucket

**Confidence check:** `winning_bucket / (winning_bucket + losing_bucket) ≥ 0.75`

If the two buckets are equal, confidence is exactly 50% — fails the threshold.

If fails → mark employee as `undetected`, reason: **نوع التوظيف غير واضح**, skip to next employee.

If passes → employment type confirmed as the winning bucket's type. Shift employees proceed to Algorithm 2. Daily employees are placed in the daily hash table.

---

## Algorithm 2 — Shift Start Time Detection

Runs only for employees confirmed as `shift` in Algorithm 1. Runs iteratively — independently for each shift employee.

### Stage 1 — Start Time Bucketing

**Note:** Only the shift bucket days from Algorithm 1 Stage 2 are used here — not all calendar days of the employee.

For each shift bucket day, check every configured start time in `shift_start_times`. For each start time, check if any timestamp in that day falls within `shift_tolerance` of that start time. If yes → assign the day to that start time's bucket.

One day may be assigned to multiple start time buckets if its timestamps match more than one start time window.

Days whose timestamps match no start time window at all are placed in the **unmatched bucket**. A day that matched at least one start time bucket is never placed in the unmatched bucket — these are mutually exclusive.

Three bucket types always exist:
- **Start time buckets** — one per configured start time (may have 0 days)
- **Unmatched bucket** — days that matched no start time window at all

### Stage 2 — Start Time Vote

- `winning_bucket` = start time bucket with the most days
- `losing_buckets` = all other start time buckets combined
- `unmatched_bucket` = days that matched no start time window

**Confidence check:** `winning_bucket / (winning_bucket + losing_buckets + unmatched_bucket) ≥ 0.60`

The unmatched bucket is always included in the denominator — this ensures the formula works consistently whether one or many start times are configured, and naturally penalizes employees whose timestamps don't align well with any configured start time.

If two start time buckets are tied for most days, pick either as winner — the confidence will be ≤ 50% and will fail the threshold regardless.

If fails → mark employee as `undetected`, reason: **وقت بداية المناوبة غير واضح**.

If passes → shift start time confirmed as the winning bucket's configured start time. Employee placed in the shift hash table with their detected start time.

---

## Detection Failure Reasons

| Reason | Arabic |
|---|---|
| Raw attendance days below 20% of period | أيام الحضور أقل من 20% من مدة الفترة |
| Usable days (≥ 2 timestamps) below 20% of period | أيام الحضور الصالحة أقل من 20% من مدة الفترة |
| Employment type vote failed | نوع التوظيف غير واضح |
| Shift start time vote failed | وقت بداية المناوبة غير واضح |

---

## Output — Three Buckets

After both algorithms complete for all employees:

**Shift hash table:** `employeeName → { name, department, detectedShiftStartTime, [timestamps] }`
Employees confirmed as shift with a confirmed start time.

**Daily hash table:** `employeeName → { name, department, [timestamps] }`
Employees confirmed as daily.

**Undetected list:** `[ { name, department, failureReason } ]`
Employees who failed at any stage of either algorithm. Carried directly to storage in Stage 10 — no extraction or calculation runs for them.

All three are in-memory only. None is persisted until Stage 10.

---

## What This Algorithm Does NOT Do

- Does not read from or write to the database
- Does not use any previously stored employee data
- Does not show any dialog or pause generation
- Does not detect daily employee start time — all daily employees use the global `daily_start_time` from config

---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
