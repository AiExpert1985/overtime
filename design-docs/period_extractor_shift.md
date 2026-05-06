# period_extractor_shift

**Created**: 27-Apr-2026
**Modified**: 05-May-2026

---

## Purpose

Defines the period extraction algorithm for shift employees. Receives a dictionary entry for one employee and returns a `RawShiftEmployeePeriods` object. Pure function — no database access, no overtime rules, no side effects.

---

## What a Shift Employee Is

A shift employee works continuous duty periods that span across calendar days. One period typically lasts 24 hours. The extractor identifies period boundaries from the timestamp sequence without relying on calendar dates.

---

## Input

- Dictionary entry: `{ name, department, employmentType, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Settings: start times list, shift duration, zone interval, start/end tolerance, inner zone tolerance, period gap window (from `config.md`)

Timestamps in the list may fall on different calendar dates — a shift starting on day 1 will naturally have timestamps on day 2. The extractor works with absolute datetime values and does not treat calendar day boundaries as period boundaries. This is correct and expected behavior.

---

## Output Object — RawShiftEmployeePeriods

| Field | Content |
|---|---|
| name | Employee name, carried from dictionary |
| department | Employee department, carried from dictionary |
| periods | List of RawShiftPeriod, ordered by anchor timestamp ascending |

### RawShiftPeriod

| Field | Content |
|---|---|
| anchorTimestamp | The defining start timestamp of this period |
| timestamps | All timestamps within the period span, sorted ascending |

---

## Algorithm

**Step 1 — Detect fixed start time**
Scan timestamps from earliest. Find the first timestamp that matches any time in the configured start times list, within start/end tolerance. This matched time becomes the **fixed start time for all periods of this employee**. Subsequent period anchors must match this same time.

**Step 2 — Build first period**
From the anchor timestamp, span forward `shift_duration` hours. All timestamps within this span belong to this period.

**Step 3 — Define zones**
Divide the span into zones: zone count = `shift_duration / zone_interval`.
- Zone centers: anchor, anchor + zone_interval, anchor + 2×zone_interval, ...
- Zone windows: start/end zones use start/end tolerance. Inner zones use inner zone tolerance.
- Each timestamp is assigned to the zone whose window it falls within. Timestamps between zones are stored in timestamps but satisfy no zone.

**Step 4 — Detect next period**
From the last timestamp of the current period, look for a next timestamp within the period gap window (configured separately — default 6 hours):
- **Found** → the last timestamp of the current period becomes the anchor of the next period (shared timestamp). Go to Step 2.
- **Not found** → scan forward for the next timestamp matching the fixed start time. When found, go to Step 2.
- **No more timestamps** → extraction complete.

**Step 5 — Shared timestamp note**
A timestamp that closes one period and opens the next is stored in both periods — as the last timestamp of the closing period and the anchor of the opening period. This is correct and intentional.

---

## What This Extractor Does NOT Do

- Does not validate periods (valid/invalid) — that is `overtime_calculation_shift.md`
- Does not calculate overtime
- Does not access the database
- Does not know about holidays or calendar dates
