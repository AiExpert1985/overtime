# period_extractor_shift

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the period extraction algorithm for shift employees. Receives one entry from the shift hash table and returns a list of RawShiftPeriod objects. Pure function — no database access, no overtime rules, no side effects.

---

## What a Shift Employee Is

A shift employee works continuous duty periods that span across calendar days. One period typically lasts 24 hours. Each period is anchored to a calendar day using the employee's detected shift start time.

---

## Input

- Shift hash table entry: `{ name, department, detectedShiftStartTime, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Settings: `shift_duration`, `shift_zone_interval`, `shift_start_end_tolerance`, `shift_inner_tolerance` (from `config.md`)

`detectedShiftStartTime` is the value determined by the schedule detection algorithm in Stage 4. It is passed in directly — not read from any stored employee record.

---

## Output

List of RawShiftPeriod, ordered by period date ascending.

### RawShiftPeriod

| Field | Content |
|---|---|
| periodDate | Calendar date (ISO 8601) this period is anchored to |
| timestamps | All timestamps within the period window, sorted ascending |
| zoneResults | List of zone results: { centerTime, timestamps[], isSatisfied } |

---

## Period Window Definition

For each calendar day D, the period window is:

`[ D @ (startTime − start_end_tolerance), (D+1) @ (startTime + start_end_tolerance) ]`

Example with start time 08:00 and tolerance 60 minutes:
`[ D @ 07:00, (D+1) @ 09:00 ]`

The window always extends into the next calendar day. Timestamps near the start time on D+1 naturally fall into both D's window (as a closing stamp) and D+1's window (as an opening stamp) — this shared timestamp behavior is automatic and correct.

For the last day of the report range, the window still extends into D+1. Timestamps on D+1 morning that fall within the window are collected — they belong to the last period.

---

## Zone Definitions

Zone count = `shift_duration / shift_zone_interval` (default 24 / 6 = 4 zones).

Zones are indexed from B1 (start) to BN (end):

| Zone | Center time | Tolerance used |
|---|---|---|
| B1 (start) | startTime | start_end_tolerance |
| B2 … B(N-1) (inner) | startTime + (i × zone_interval) | inner_tolerance |
| BN (end) | startTime + shift_duration | start_end_tolerance |

Each timestamp in the window is assigned to the zone whose window it falls within. A timestamp that falls between two zone windows is stored in the period's timestamp list but satisfies no zone.

---

## Algorithm

**Step 1 — Build candidate periods**
For each calendar day D in the report range, define the period window. Collect all employee timestamps within that window. If a day has no timestamps in its window, skip it — no period is created for that day.

**Step 2 — Zone bucketing**
For each candidate period, assign each timestamp to its zone. Record which zones are satisfied (have at least one timestamp).

**Step 3 — Discard non-shift days**
Discard any period where no inner zone (B2 through B(N-1)) has any timestamp. A period with only B1 and/or BN timestamps indicates a closing or stray stamp, not a genuine shift presence. These periods are not passed to the calculator.

**Step 4 — Output**
Return remaining periods ordered by period date ascending.

---

## Shared Timestamps

A timestamp near the start time on D+1 morning falls within both D's window (as a late BN stamp) and D+1's window (as a B1 stamp). It is stored in both periods. This is correct and intentional — it closes one period and opens the next.

---

## What This Extractor Does NOT Do

- Does not validate periods — that is `overtime_calculation_shift.md`
- Does not calculate overtime
- Does not access the database
- Does not run schedule detection — detectedShiftStartTime is passed in as input


---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
