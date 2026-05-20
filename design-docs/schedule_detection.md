# schedule_detection

**Created**: 12-May-2026 **Modified**: 16-May-2026

---

## Purpose

Defines the algorithm for detecting each employee's employment type (shift or daily) and, for shift employees, their shift start time and shift periods. Runs inline as Stage 4 of the report generation pipeline. Operates entirely on the working dictionary built in Stage 3. No database reads or writes during detection. No user interaction — runs silently to completion.

Detection and shift period extraction are combined in a single pass — valid shift periods are built during detection and carried directly into the shift hash table.

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
|min_anchor_pairs|2|Minimum number of valid anchor pairs required when counting periods via the anchor pair fallback. Lower than min_valid_periods because irregular employees have minimal stamps by nature.|
|rest_gap_days|2|Minimum number of consecutive days with zero timestamps required after a shift period to confirm a rest gap in the anchor pair check.|

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

Runs independently for each employee. For each day and each configured start time, a zone check runs first. If the zone check fails, an anchor pair check runs immediately as a fallback. Both checks contribute to the same `validPeriods[S]` buckets. A single classification step at the end decides the employee's type based on the total period count — regardless of how each period was found.

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

**Zone check:** If `satisfiedZones ≥ min_zones_satisfied (zoneCount − 1)` → append a `ShiftPeriod` to `validPeriods[S]`:

|Field|Value|
|---|---|
|periodIndex|0-based index within validPeriods[S]|
|periodDate|D (ISO 8601)|
|allTimestamps|windowTimestamps, sorted ascending|
|zoneResults|list of `{ zoneIndex, startTime, endTime, timestamps[], isSatisfied }`|

Calculated fields (`endDate`, `totalAttendanceDuration`, `hoursCounted`, `isValid`, `notes`) are left unset — the calculator fills them in Stage 7.

**Anchor pair check (fallback):** If the zone check failed, run the anchor pair check for this day D and start time S:

```
openingWindow = [D @ S − shift_tolerance, D @ S + shift_tolerance]

hasOpening  = any timestamp falls within openingWindow
hasActivity = any timestamp exists on D+1 (any time)
hasRestGap  = zero timestamps on D+2 AND zero timestamps on D+3
hasReturn   = any timestamp exists on D+4

if hasOpening AND hasActivity AND hasRestGap AND hasReturn:
  append a ShiftPeriod to validPeriods[S] with:
    periodDate    = D
    allTimestamps = all timestamps from D and D+1, sorted ascending
    zoneResults   = zone results computed above (most zones unsatisfied — stored for audit)
```

The opening stamp confirms shift start. Activity on D+1 confirms presence during the shift body without requiring an exact closing time. The rest gap confirms genuine days off. The return stamp on D+4 confirms the repeating cycle — ruling out a one-off isolated period.

Anchor pair periods are appended to the same `validPeriods[S]` bucket as zone-check periods. The classification step treats them identically. Because most interior zones are unsatisfied, the shift overtime calculator (Stage 7) will mark these periods as `isValid = false` and `hoursCounted = 0` — they appear in the detail screen for audit but do not contribute to overtime totals.

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

|Step|Condition|Result|Reason|
|---|---|---|---|
|Pre-check|attendance_days / reportDays < 0.15|undetected|Too little data to analyze|
|Step 2 (per day)|satisfiedZones ≥ zoneCount − 1|period added to validPeriods[S]|Full zone signal confirmed|
|Step 2 (per day)|zone check failed AND anchor pair conditions met|period added to validPeriods[S]|Irregular shift pattern for this day|
|Step 4|winnerCount < 3|daily|No meaningful shift pattern|
|Step 4|Multiple start times AND (tie OR confidence < 0.60)|undetected|Ambiguous start time|
|Step 4|Otherwise|shift|Pattern confirmed|

An employee with weak signal is daily. An employee with strong but ambiguous signal is undetected.

---

## Detection Failure Reasons

|Reason|Arabic|Triggered by|
|---|---|---|
|Raw attendance days below 15% of period|أيام الحضور أقل من 15% من مدة الفترة|Pre-check|
|Shift start time ambiguous|وقت بداية المناوبة غير واضح|Step 4 confidence check|

---

## Output — Three Buckets

**Shift hash table:** `employeeName → { name, department, detectedShiftStartTime, [timestamps], [ShiftPeriod] }` Employees confirmed as shift, with periods already populated. Stage 7 calculator enriches these periods directly.

**Daily hash table:** `employeeName → { name, department, [timestamps] }` Employees confirmed as daily.

**Undetected list:** `[ { name, department, failureReason } ]` Employees who failed the pre-check or the confidence check. Carried directly to storage in Stage 9.

All three are in-memory only. None is persisted until Stage 9.

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