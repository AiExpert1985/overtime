# period_extractor_daily

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the period extraction algorithm for daily employees. Receives one entry from the daily hash table and returns a list of RawDailyPeriod objects. Pure function — no database access, no overtime rules, no side effects.

---

## What a Daily Employee Is

A daily employee works standard morning shifts on regular workdays. Their attendance is measured strictly within one calendar day — a fingerprint on day 2 never belongs to day 1.

---

## Input

- Daily hash table entry: `{ name, department, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Off-days hash set — produced by Stage 5 (off-day detection). Contains all dates classified as off-days for this report. Passed in as input to this extractor at Stage 7.

---

## Output

List of RawDailyPeriod, ordered by date ascending.

### RawDailyPeriod

| Field | Content |
|---|---|
| date | Calendar date (ISO 8601) |
| dayType | regular / off |
| timestamps | All timestamps of the day, sorted ascending |

Days with zero timestamps are not included. Days with exactly one timestamp are included — the calculator determines validity, not the extractor.

---

## Algorithm

**Step 1 — Group by calendar date**
Partition the timestamp list by calendar date. Each partition is one candidate period. A timestamp on day 2 is never placed in day 1's partition regardless of time.

**Step 2 — Classify day type**
For each date:
- Date exists in off-days hash set → off
- Otherwise → regular

Weekends (Friday/Saturday) are naturally classified as off because they appear in the off-days hash set — auto-detection captures them without special-casing.

**Step 3 — Build RawDailyPeriod**
For each date partition, set timestamps = full sorted list, dayType = classified type. Create one RawDailyPeriod.

**Step 4 — Output**
Return periods ordered by date ascending.

---

## What This Extractor Does NOT Do

- Does not validate periods (valid/invalid) — that is `overtime_calculation_daily.md`
- Does not calculate overtime
- Does not apply the morning cutoff rule
- Does not deduplicate timestamps
- Does not run off-day detection — the off-days hash set is passed in as input
