# schedule_detection

**Created**: 12-May-2026 **Modified**: 16-May-2026

---

## Purpose

Defines the algorithm for detecting each employee's employment type (shift or daily) and, for shift employees, their shift start time and shift periods. 

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
|min_zones_satisfied|`zoneCount − 1`|Derived from zone count at runtime — not hardcoded. Requires all zones except one to be satisfied, forcing overnight zone presence while tolerating exactly one mis-punch. With default 5 zones: 4. With 4 zones: 3. With 3 zones: 2. Blocks daily employee collision regardless of zone configuration.|
|min_anchor_pairs|2|Phase 2 only. Minimum number of valid anchor pairs required to confirm an irregular shift employee. Lower than min_valid_periods because irregular employees have minimal stamps by nature.|
|rest_gap_days|2|Phase 2 only. Minimum number of consecutive days with zero timestamps required after a closing stamp to confirm a rest gap.|

---

## Zone Layout

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

### Phase 1 — Preparation
#### Step 1 — Attendance Pre-Check

Count all calendar days where the employee has at least 1 timestamp.

`attendance_days / report_period_days ≥ min_attendance_density (0.15)`

If fails → mark employee as `undetected`, reason: **أيام الحضور أقل من 15% من مدة الفترة**, skip to next employee.

#### Step 2 — Build Valid Periods Per Start Time

For each configured start time S in `shift_start_times`, build `validPeriods[S] = []`:

For each calendar day D in the report range:

```
windowStart      = D @ S − shift_tolerance
windowEnd        = D @ S + shift_duration + shift_tolerance
windowTimestamps = all employee timestamps where windowStart ≤ ts ≤ windowEnd
```

If `windowTimestamps` is empty → skip this day, no period created.

### Phase 2 — Zone-Based Shift Detection

#### Step 1  — Compute zone results

compute zone results using the Zone Layout above. Count `satisfiedZones`.

If `satisfiedZones ≥ min_zones_satisfied (zoneCount − 1)` → append a `ShiftPeriod` to `validPeriods[S]`:

|Field|Value|
|---|---|
|periodIndex|0-based index within validPeriods[S]|
|periodDate|D (ISO 8601)|
|allTimestamps|windowTimestamps, sorted ascending|
|zoneResults|list of `{ zoneIndex, startTime, endTime, timestamps[], isSatisfied }`|


Calculated fields (`endDate`, `totalAttendanceDuration`, `hoursCounted`, `isValid`, `notes`) are left unset — the calculator fills them in Stage 7.

if failed this step, directly check the employee with below irregular check

Irregular Shift Detection

Runs only for employees who failed Phase 1 Classification. These employees have insufficient zone signal to confirm as shift — Phase 2 checks for a minimal but valid shift pattern before defaulting to daily.

#### Definition — Anchor Pair

For a configured start time S and calendar day D, an anchor pair exists when all three conditions are met:

- **Opening stamp:** at least one timestamp falls within `[D @ S − shift_tolerance, D @ S + shift_tolerance]`
- **Closing stamp:** at least one timestamp falls within `[D+1 @ S − shift_tolerance, D+1 @ S + shift_tolerance]`
- **Rest gap:** zero timestamps exist on D+2 AND zero timestamps exist on D+3
- **Next Return**: at least one timestamp exist on D+4 or D+5

A pair that satisfies opening and closing but not the rest gap is discarded — it could be a daily employee stamping on consecutive days.

#### Step 1 — Count Anchor Pairs Per Start Time

For each configured start time S, iterate over every calendar day D in the report range:

```
openingWindow = [D @ S − shift_tolerance,   D @ S + shift_tolerance]
closingWindow = [D+1 @ S − shift_tolerance, D+1 @ S + shift_tolerance]

hasOpening = any timestamp falls within openingWindow
hasClosing = any timestamp falls within closingWindow
hasRestGap = zero timestamps on D+2 AND zero timestamps on D+3
hasReturn = any timestamp falls within D+4 or D+5

if hasOpening AND hasClosing AND hasRestGap AND hasReturn:
  anchorPairs[S] += 1
```

#### Step 2 — Find the Winning Start Time

```
winnerStartTime = S with max len(validPeriods[S])
winnerCount     = len(validPeriods[winnerStartTime])
totalValid      = sum of len(validPeriods[S]) for all S
```

If two or more start times share the same `winnerCount`, a tie exists. The confidence check in Step 4 handles this.

#### Step 3 — Classify

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

Anchor pair periods are stored as `ShiftPeriod` objects. Because these periods have only 2 timestamps (opening and closing), most interior zones will be unsatisfied. The shift overtime calculator (Stage 7) will mark these periods as `isValid = false` and `hoursCounted = 0` by its standard rules. This is correct — irregular shift periods are visible in the detail screen for audit purposes but do not contribute to overtime totals.

---

## Classification Logic Summary

|Phase|Condition|Result|Reason|
|---|---|---|---|
|Pre-check|attendance_days / reportDays < 0.15|undetected|Too little data to analyze|
|Phase 1|winnerCount ≥ 3 AND confidence passes|shift|Clear zone-based shift pattern|
|Phase 1|winnerCount < 3|→ Phase 2|Insufficient zone signal, try anchor pair detection|
|Phase 1|Multiple start times AND (tie OR confidence < 0.60)|undetected|Ambiguous start time|
|Phase 2|anchorPairs ≥ 2 AND confidence passes|shift|Irregular shift pattern confirmed|
|Phase 2|anchorPairs < 2|daily|No shift pattern of any kind|
|Phase 2|Multiple start times AND (tie OR confidence < 0.60)|undetected|Ambiguous start time|

An employee with weak signal is daily. An employee with strong but ambiguous signal is undetected.

---

## Detection Failure Reasons

|Reason|Arabic|Triggered by|
|---|---|---|
|Raw attendance days below 15% of period|أيام الحضور أقل من 15% من مدة الفترة|Pre-check|
|Shift start time ambiguous|وقت بداية المناوبة غير واضح|Phase 1 or Phase 2 confidence check|

---

## Output — Three Buckets

**Shift hash table:** `employeeName → { name, department, detectedShiftStartTime, [timestamps], [ShiftPeriod] }` Employees confirmed as shift, with periods already populated. Stage 7 calculator enriches these periods directly.

**Daily hash table:** `employeeName → { name, department, [timestamps] }` Employees confirmed as daily.

**Undetected list:** `[ { name, department, failureReason } ]` Employees who failed the pre-check or the confidence check. Carried directly to storage in Stage 9.

All three are in-memory only. None is persisted until Stage 10.

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