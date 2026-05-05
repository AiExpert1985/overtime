# algorithm_extractor_daily

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

Defines the period extraction algorithm for daily employees. Receives a sorted timestamp list for one employee and returns a list of daily Period objects. Pure function — no database access, no overtime rules, no side effects.

---

## What a Daily Employee Is

A daily employee works standard morning shifts on regular workdays. Their attendance is measured strictly within one calendar day — a fingerprint on day 2 never belongs to day 1.

---

## Input

- Sorted timestamp list for one daily employee (filtered to report date range)
- Holidays list (for day classification only)
- Settings: start time, work duration (from `config.md`)

---

## The Period Object (Daily)

One Period per calendar day that has at least one timestamp.

| Field | Content |
|---|---|
| date | Calendar date (ISO 8601) |
| dayType | regular / holiday / weekend |
| firstTimestamp | Earliest timestamp of the day |
| lastTimestamp | Latest timestamp of the day |
| allTimestamps | All timestamps of the day, sorted ascending |
| employeeName | Carried from dictionary |
| employmentType | daily |

---

## Algorithm

**Step 1 — Group by calendar date**
Partition the timestamp list by calendar date. Each partition is one candidate period. A timestamp on day 2 is never placed in day 1's partition regardless of time.

**Step 2 — Classify day type**
For each date:
- Friday or Saturday → weekend
- Date exists in holidays list → holiday
- Otherwise → regular

**Step 3 — Build Period**
For each date partition, set firstTimestamp = earliest, lastTimestamp = latest, allTimestamps = full sorted list. Create one Period.

**Step 4 — Output**
Return list of Periods ordered by date ascending. Days with zero timestamps are not included.

---

## What This Extractor Does NOT Do

- Does not validate periods (valid/invalid) — that is `overtime_calculation_daily.md`
- Does not calculate overtime
- Does not apply the morning cutoff rule
- Does not deduplicate timestamps
