# period_extractor_shift

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the period extraction algorithm for shift employees. Receives the shift hash table, enriches each employee entry with their period and zone results, and returns the updated hash table. Pure function — no database access, no overtime rules, no side effects.

---

## What a Shift Employee Is

A shift employee works continuous duty periods that span across calendar days. One period typically lasts 24 hours. Each period is anchored to a calendar day using the employee's detected shift start time.

---

## Input

- Shift hash table: `employeeName → { name, department, detectedShiftStartTime, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Settings: `shift_duration`, `shift_zone_interval`, `shift_tolerance` (from `config.md`)

`detectedShiftStartTime` is determined by the schedule detection algorithm in Stage 4. It is passed in directly — not read from any stored employee record.

---

## Output

The same shift hash table enriched with a list of `ShiftPeriod` objects per employee:

`employeeName → { name, department, detectedShiftStartTime, [timestamps], [ShiftPeriod] }`

### ShiftPeriod — base fields set by extractor

| Field | Content |
|---|---|
| periodIndex | 0-based order within the employee's period list |
| periodDate | Calendar date (ISO 8601) this period is anchored to |
| allTimestamps | All timestamps within the period window, sorted ascending |
| zoneResults | List of zone results: `{ zoneIndex, startTime, endTime, timestamps[], isSatisfied }` |

Calculated fields (`endDate`, `totalAttendanceDuration`, `hoursCounted`, `isValid`, `notes`) are added to the same object by the calculator in Stage 8. See `overtime_calculation_shift.md`.

The function builds the `ShiftPeriod` list for each employee, then stores it back into the employee's hash table entry. The calculator reads these period lists directly from the hash table in the next stage.

---

## Zone Layout

Zone count = `(shift_duration / shift_zone_interval) + 1`
Default: `(24 / 6) + 1 = 5 zones` (B1 through B5).

Zones are contiguous — each zone starts exactly where the previous one ends. No gaps exist between zones, so every timestamp within the total window falls into exactly one zone.

| Zone | Start | End | Width |
|---|---|---|---|
| B1 | `startTime − tolerance` | `B1_start + zone_interval` | `zone_interval` |
| B2 | `B1_end` | `B2_start + zone_interval` | `zone_interval` |
| ... | ... | ... | `zone_interval` |
| B(N-1) | `B(N-2)_end` | `B(N-1)_start + zone_interval` | `zone_interval` |
| BN (last) | `B(N-1)_end` | `startTime + shift_duration + tolerance` | `2 × tolerance` |

**Example** — start time 08:00, tolerance 60 min, zone_interval 6h, shift_duration 24h (5 zones):

| Zone | Start | End |
|---|---|---|
| B1 | 07:00 day 1 | 13:00 day 1 |
| B2 | 13:00 day 1 | 19:00 day 1 |
| B3 | 19:00 day 1 | 01:00 day 2 |
| B4 | 01:00 day 2 | 07:00 day 2 |
| B5 | 07:00 day 2 | 09:00 day 2 |

The last zone (BN) is always `2 × tolerance` wide — it is intentionally narrow, designed only to catch the closing stamp.

---

## Algorithm

Runs for each employee in the shift hash table independently.

### Step 1 — Compute Zone Boundaries

Using the employee's `detectedShiftStartTime` and settings, compute the start and end time of each zone as defined in the Zone Layout section above. These boundaries are fixed for all periods of this employee.

### Step 2 — Period Separation

For each calendar day D in the report range, define the period window:

`[ D @ (startTime − tolerance), (D+1) @ (startTime + tolerance) ]`

Iterate through the employee's timestamps and assign each timestamp to the period window it falls within. A timestamp near the start time on D+1 naturally falls within both D's closing window and D+1's opening window — it is stored in both periods. This is correct and intentional.

If a day has no timestamps in its window, no period is created for that day.

### Step 3 — Zone Bucketing

For each candidate period, assign each timestamp to the zone whose window it falls within. Every timestamp within the period window falls into at least one zone — no timestamp is left unassigned.

For each zone, compute `isSatisfied`:

`isSatisfied = true` if at least one timestamp in this zone falls within `[zone_center − tolerance, zone_center + tolerance]`

Otherwise `isSatisfied = false`.

**Note:** All timestamps within a zone window are stored in `zoneResults` regardless of whether they satisfy the center check. This is intentional — all timestamps are shown to the user in the detail screen for audit purposes. The `isSatisfied` flag is used exclusively for overtime validity by the calculator in Stage 8.

### Step 4 — Discard Weak Periods

Discard any period where fewer than 2 zones are satisfied. A period with only 1 satisfied zone indicates a stray or closing stamp, not a genuine shift presence.

### Step 5 — Update Hash Table

For each employee, store the list of `ShiftPeriod` objects into the employee's hash table entry under a `periods` field. Return the enriched hash table.

**Note:** `ShiftPeriod` carries `periodDate` only at this stage. `endDate` is derived at calculation time from the last timestamp by the calculator — not part of the extractor output.

---

## Shared Timestamps

A timestamp near the start time on D+1 morning falls within both D's window (as a closing stamp for BN) and D+1's window (as an opening stamp for B1). It is stored in both periods. This is correct and intentional — it closes one period and opens the next.

---

## What This Extractor Does NOT Do

- Does not validate periods — that is `overtime_calculation_shift.md`
- Does not calculate overtime
- Does not access the database
- Does not run schedule detection — detectedShiftStartTime is passed in as input

---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
