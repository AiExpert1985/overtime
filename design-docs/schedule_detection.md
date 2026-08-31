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
- Config: `shift_start_times`, `shift_duration`, `shift_zone_interval`, `shift_inner_tolerance`
- Constant: `detection_edge_tolerance` (see `config.md`) — used for the period window, the zone-satisfied count, and the anchor pair opening window. `shift_edge_tolerance` is **not** used by detection.
- Config: `daily_start_time`, `daily_delay_allowance`

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

Computed in three ordered steps. Detection and the overtime calculator share this layout — the same zones serve classification and validity.

**Step 1 — centers.**

|Zone|Center|
|---|---|
|B1|`D @ S`|
|Inner zone i|`D @ S + i × shift_zone_interval`|
|BN|`D @ S + shift_duration`|

**Step 2 — buckets.** Each boundary sits at the midpoint between neighbouring centers. The two outer edges have no neighbour, so the edge tolerance is used there instead.

|Field|Formula|
|---|---|
|First bucket start|`B1_center − detection_edge_tolerance` (= `windowStart`)|
|Boundary between zone i and i+1|`center[i] + (center[i+1] − center[i]) / 2`|
|Last bucket end|`BN_center + detection_edge_tolerance` (= `windowEnd`)|

Buckets are contiguous and non-overlapping, so every timestamp in the period window falls into exactly one bucket. Inner bucket width equals `shift_zone_interval` whenever `shift_duration` is a multiple of `shift_zone_interval`; when it is not, the gap before BN is larger, and the midpoint rule above is what governs.

**Step 3 — validity windows.**

Two windows are computed per zone, from the same centers and the same buckets.

|Purpose|Edge zone tolerance|Inner zone tolerance|Used by|
|---|---|---|---|
|Classification|`detection_edge_tolerance`|`shift_inner_tolerance`|the `satisfiedZones` count below — never stored|
|Overtime validity|`shift_edge_tolerance`|`shift_inner_tolerance`|the stored `isSatisfied` flag, read by `overtime_calculation_shift.md`|

|Field|Formula|
|---|---|
|Center window|`[zone_center − tolerance, zone_center + tolerance]`|
|satisfied|at least one timestamp **in this zone's bucket** falls within the relevant center window|

Both windows are evaluated only against timestamps already assigned to that zone's bucket, so a detection window wider than half the zone interval is clipped by the bucket rather than reaching into a neighbour's. The one-timestamp-one-zone model holds regardless of how the two tolerances compare.

Because a fully valid period satisfies every zone under the narrow window, it satisfies every zone under the wide one too — so the wider detection window only ever admits periods the calculator then marks invalid. It changes classification, never the set of valid periods.

For inner zones the window is centered inside the bucket. For B1 and BN it sits at the *outer* end of the bucket, not the middle — B1's window opens exactly where its bucket opens. This asymmetry is intended.

With start 08:00, `shift_zone_interval` 6h, `shift_edge_tolerance` 30, `shift_inner_tolerance` 120 and 5 zones, B1's bucket is 07:30–11:00 while its window is only 07:30–08:30; B2's bucket is 11:00–17:00 with its window centered at 12:00–16:00.

**Boundaries.** Every boundary belongs to the zone that opens there — exclusive on the end it closes, inclusive on the end it opens — except the final boundary of the period window, which is inclusive on both sides so the closing timestamp is never dropped. Validity windows follow the same convention, which is why `config.md` caps each tolerance at half the zone interval: a wider window could be satisfied by a timestamp belonging to a neighbouring bucket.

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
windowStart      = D @ S − detection_edge_tolerance
windowEnd        = D @ S + shift_duration + detection_edge_tolerance
windowTimestamps = all employee timestamps where windowStart ≤ ts ≤ windowEnd
```

If `windowTimestamps` is empty → skip this day, no period created.

Otherwise, compute zone results using the Zone Layout above. Count `satisfiedZones`.

**Zone check:** Counting satisfied zones with the *classification* windows — if `satisfiedZones ≥ min_zones_satisfied (zoneCount − 1)` → append a `ShiftPeriod` to `validPeriods[S]`:

|Field|Value|
|---|---|
|periodIndex|0-based index within validPeriods[S]|
|periodDate|D (ISO 8601)|
|allTimestamps|windowTimestamps, sorted ascending|
|zoneResults|list of `{ zoneIndex, startTime, endTime, windowStart, windowEnd, timestamps[], isSatisfied }`|

Calculated fields (`endDate`, `totalAttendanceDuration`, `hoursCounted`, `isValid`, `notes`) are left unset — the calculator fills them in Stage 7.

**Anchor pair check (fallback):** If the zone check failed, run the anchor pair check for this day D and start time S:

```
openingWindow = [D @ S − detection_edge_tolerance, D @ S + detection_edge_tolerance]

hasOpening  = any timestamp falls within openingWindow
hasActivity = any timestamp exists on D+1 (any time)
hasRestGap  = zero timestamps on D+2 AND zero timestamps on D+3
hasReturn   = any timestamp exists on D+4
isWeekend   = D+2 is Friday AND D+3 is Saturday

if hasOpening AND hasActivity AND hasRestGap AND hasReturn AND NOT isWeekend:
  append a ShiftPeriod to validPeriods[S] with:
    periodDate    = D
    allTimestamps = all timestamps from D and D+1, sorted ascending
    zoneResults   = zone results computed above (most zones unsatisfied — stored for audit)
```

`isWeekend` guards against a weekly false positive: when shift start time is close to daily start time, a Sun–Thu daily employee satisfies all four conditions every week (works Wed→Thu, off Fri–Sat, returns Sun). Two weeks produces `winnerCount = 2`, wrongly classifying them as shift. Excluding the natural Friday–Saturday weekend eliminates this pattern with no dependency on Stage 5 off-day detection.

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
  → run daily validation gate (below)
```

**Daily Validation Gate**

Reached when the employee failed to produce enough valid shift periods. Before classifying as daily, verify the employee actually follows a daily schedule. Uses config: `daily_start_time`, `daily_delay_allowance`.

```
entryWindow = [daily_start_time − daily_delay_allowance,
               daily_start_time + daily_delay_allowance]

workingDays = non-weekend (non-Friday, non-Saturday) days in report range
morningDays = days where employee has at least one timestamp within entryWindow
threshold   = max(10, workingDays × 0.50)

if morningDays < threshold:
  → undetected: "لا ينتمي لنظام المناوبة أو الدوام الصباحي"

→ daily
```

The floor of 10 prevents the ratio from becoming too easy to pass on short reports — a shift employee on a 3-day cycle works at most ~10 shifts per month, so requiring at least 10 morning stamps keeps the threshold meaningful regardless of report length.

**Design notes:**

- An exit stamp condition was considered (requiring 50% of morning days to also have an exit stamp within the exit window) but was rejected — many employees are officially entry-only by policy, and requiring exit stamps would wrongly classify them as undetected.
- A separate `entry_only` employee category was considered for employees who never punch out, but rejected — it would require changes across every layer (calculator, schema, report screen, export, detail screen). The current design already handles them correctly: they pass the gate, enter the daily bucket, and each period is marked invalid by the calculator with "بصمة واحدة فقط". No overtime is calculated, which is correct. The detail screen shows all red rows but the classification and totals are accurate.

An employee who fails the gate has neither a convincing shift pattern nor a convincing daily pattern — they are undetected, not silently misclassified.

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
|Step 4|winnerCount ≥ 3 AND confidence passes|shift|Shift pattern confirmed|
|Step 4|winnerCount < 3 → daily gate passes|daily|Confirmed daily schedule|
|Step 4|winnerCount < 3 → daily gate fails|undetected|Neither shift nor daily pattern|
|Step 4|Multiple start times AND (tie OR confidence < 0.60)|undetected|Ambiguous start time|

An employee with weak shift signal must pass the daily validation gate to be classified as daily — otherwise undetected. An employee with strong but ambiguous shift signal is undetected.

---

## Detection Failure Reasons

|Reason|Arabic|Triggered by|
|---|---|---|
|Raw attendance days below 15% of period|أيام الحضور أقل من 15% من مدة الفترة|Pre-check|
|Shift start time ambiguous|وقت بداية المناوبة غير واضح|Step 4 confidence check|
|Neither shift nor daily pattern|لا ينتمي لنظام المناوبة أو الدوام الصباحي|Step 4 daily validation gate|

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