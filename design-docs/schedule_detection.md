# schedule_detection

**Created**: 12-May-2026 **Modified**: 16-May-2026

---

## Purpose

Defines the algorithm for detecting each employee's employment type (shift or daily) and, for shift employees, their shift start time and shift periods. Runs inline as Stage 4 of the report generation pipeline. Operates entirely on the working dictionary built in Stage 3. No database reads or writes during detection. No user interaction — runs silently to completion.

**This stage replaces both the old Stage 4 (type detection) and Stage 6 (shift period extraction).** Valid shift periods are built during detection and carried directly into the shift hash table. Stage 6 is removed from the pipeline.

---

## Inputs

- Working dictionary: `employeeName → { name, department, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Report period duration — total calendar days between report start and end date (inclusive)
- Config: `shift_start_times`, `shift_duration`, `shift_zone_interval`, `shift_tolerance`

---

## Employee Type Enumeration

Every employee is assigned exactly one of three types as the output of this stage:

|Type|Meaning|
|---|---|
|`shift`|Confirmed shift employee with a detected start time and populated periods|
|`daily`|Confirmed daily employee|
|`undetected`|Could not be classified — stored with a failure reason|

---

## Hardcoded Constants

|Constant|Value|Reason|
|---|---|---|
|min_attendance_density|0.15|Cheap pre-filter — employee must have appeared on at least 15% of report days|
|min_valid_periods|3|Winner must have at least 3 valid periods — hard to achieve by luck, absorbs mis-punches|
|min_start_time_confidence|0.60|Applied only when multiple start times are configured. Winner's valid periods must be ≥ 60% of all valid periods across all start times.|
|min_zones_satisfied|2|Minimum satisfied zones for a window to be counted as a valid period|

---

## Zone Layout

Identical to `period_extractor_shift.md`. Defined here for completeness.

Zone count = `(shift_duration / shift_zone_interval) + 1` Default: `(24 / 6) + 1 = 5 zones` (B1 through B5).

For a window starting at `windowStart = D @ S − shift_tolerance`:

|Field|Formula|
|---|---|
|Zone start|`windowStart + i × shift_zone_interval`|
|Zone end|`windowStart + (i+1) × shift_zone_interval` for inner zones; `windowEnd` for last zone|
|Zone center|`D @ S + i × shift_zone_interval`|
|Center window|`[zone_center − shift_tolerance, zone_center + shift_tolerance]`|
|isSatisfied|at least one timestamp falls within center window|

Last zone end is always inclusive. All other zone ends are exclusive.

---

## Algorithm

Runs independently for each employee.

### Step 1 — Attendance Pre-Check

Count all calendar days where the employee has at least 1 timestamp.

`attendance_days / report_period_days ≥ min_attendance_density (0.15)`

If fails → mark employee as `undetected`, reason: **أيام الحضور أقل من 15% من مدة الفترة**, skip to next employee.

### Step 2 — Build Valid Periods Per Start Time

For each configured start time S in `shift_start_times`, build `validPeriods[S] = []`:

For each calendar day D in the report range:

```
windowStart      = D @ S − shift_tolerance
windowEnd        = D @ S + shift_duration + shift_tolerance
windowTimestamps = all employee timestamps where windowStart ≤ ts ≤ windowEnd
```

If `windowTimestamps` is empty → skip this day, no period created.

Otherwise, compute zone results using the Zone Layout above. Count `satisfiedZones`.

If `satisfiedZones ≥ min_zones_satisfied (2)` → append a `ShiftPeriod` to `validPeriods[S]`:

|Field|Value|
|---|---|
|periodIndex|0-based index within validPeriods[S]|
|periodDate|D (ISO 8601)|
|allTimestamps|windowTimestamps, sorted ascending|
|zoneResults|list of `{ zoneIndex, startTime, endTime, timestamps[], isSatisfied }`|

Calculated fields (`endDate`, `totalAttendanceDuration`, `hoursCounted`, `isValid`, `notes`) are left unset — the calculator fills them in Stage 8.

### Step 3 — Find the Winning Start Time

```
winnerStartTime = S with max len(validPeriods[S])
winnerCount     = len(validPeriods[winnerStartTime])
totalValid      = sum of len(validPeriods[S]) for all S
```

If two or more start times share the same `winnerCount`, a tie exists. The confidence check in Step 4 handles this.

### Step 4 — Classify

**Check 1 — Minimum valid periods:**

```
if winnerCount < min_valid_periods (3):
  → daily
```

No meaningful shift pattern — employee is genuinely daily.

**Check 2 — Start time confidence (only when multiple start times configured):**

```
if len(shift_start_times) > 1:
  if tie OR winnerCount / totalValid < min_start_time_confidence (0.60):
    → undetected: "وقت بداية المناوبة غير واضح"
```

Employee has clear shift signal but it is split across multiple start times — ambiguous, not daily. When only one start time is configured this check is skipped entirely — `winnerCount / totalValid` is always 100%.

**Result — shift:**

```
detectedShiftStartTime = winnerStartTime
periods = validPeriods[winnerStartTime]
→ shift
```

---

## Classification Logic Summary

|Condition|Result|Reason|
|---|---|---|
|attendance_days / reportDays < 0.15|undetected|Too little data to analyze|
|winnerCount < 3|daily|No meaningful shift pattern|
|Multiple start times AND (tie OR confidence < 0.60)|undetected|Ambiguous start time|
|Otherwise|shift|Clear pattern confirmed|

An employee with weak signal is daily. An employee with strong but ambiguous signal is undetected — they need investigation, not a default classification.

---

## Detection Failure Reasons

|Reason|Arabic|
|---|---|
|Raw attendance days below 15% of period|أيام الحضور أقل من 15% من مدة الفترة|
|Shift start time ambiguous|وقت بداية المناوبة غير واضح|

---

## Output — Three Buckets

**Shift hash table:** `employeeName → { name, department, detectedShiftStartTime, [timestamps], [ShiftPeriod] }` Employees confirmed as shift, with periods already populated. Stage 8 calculator enriches these periods directly.

**Daily hash table:** `employeeName → { name, department, [timestamps] }` Employees confirmed as daily.

**Undetected list:** `[ { name, department, failureReason } ]` Employees who failed the pre-check or the confidence check. Carried directly to storage in Stage 10.

All three are in-memory only. None is persisted until Stage 10.

---

## Pipeline Impact

This stage now produces shift periods directly, making the old Stage 6 (`period_extractor_shift.md`) redundant. The pipeline stages are renumbered:

|Old|New|Change|
|---|---|---|
|Stage 4 — Schedule Detection|Stage 4 — Schedule Detection|Replaced with this algorithm. Now also builds ShiftPeriod objects.|
|Stage 5 — Off-Day Detection|Stage 5 — Off-Day Detection|No change|
|Stage 6 — Shift Period Extraction|**Removed**|Merged into Stage 4|
|Stage 7 — Daily Period Extraction|Stage 6 — Daily Period Extraction|Renumbered only|
|Stage 8 — Shift Overtime Calculation|Stage 7 — Shift Overtime Calculation|Renumbered only|
|Stage 9 — Daily Overtime Calculation|Stage 8 — Daily Overtime Calculation|Renumbered only|
|Stage 10 — Store and Navigate|Stage 9 — Store and Navigate|Renumbered only|

---

## What This Stage Does NOT Do

- Does not read from or write to the database
- Does not use any previously stored employee data
- Does not show any dialog or pause generation
- Does not detect daily employee start time — all daily employees use the global `daily_start_time` from config
- Does not enrich ShiftPeriod calculated fields — that is the shift overtime calculator

---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.