# period_extractor_daily

**Created**: 27-Apr-2026
**Modified**: 05-May-2026

---

## Purpose

Defines the period extraction algorithm for daily employees. Receives a dictionary entry for one employee and returns a `RawDailyEmployeePeriods` object. Pure function — no database access, no overtime rules, no side effects.

---

## What a Daily Employee Is

A daily employee works standard morning shifts on regular workdays. Their attendance is measured strictly within one calendar day — a fingerprint on day 2 never belongs to day 1.

---

## Input

- Dictionary entry: `{ name, department, employmentType, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Holidays list (for day classification only)

---

## Output Object — RawDailyEmployeePeriods

| Field | Content |
|---|---|
| name | Employee name, carried from dictionary |
| department | Employee department, carried from dictionary |
| periods | List of RawDailyPeriod, ordered by date ascending |

### RawDailyPeriod

| Field | Content |
|---|---|
| date | Calendar date (ISO 8601) |
| dayType | regular / holiday / weekend |
| timestamps | All timestamps of the day, sorted ascending |

Days with zero timestamps are not included. Days with exactly one timestamp are included — the calculator determines validity, not the extractor.

---

## Algorithm

**Step 1 — Group by calendar date**
Partition the timestamp list by calendar date. Each partition is one candidate period. A timestamp on day 2 is never placed in day 1's partition regardless of time.

**Step 2 — Classify day type**
For each date:
- Friday or Saturday → weekend
- Date exists in holidays list → holiday
- Otherwise → regular

**Step 3 — Build RawDailyPeriod**
For each date partition, set timestamps = full sorted list, dayType = classified type. Create one RawDailyPeriod.

**Step 4 — Output**
Return `RawDailyEmployeePeriods` with periods ordered by date ascending.

---

## What This Extractor Does NOT Do

- Does not validate periods (valid/invalid) — that is `overtime_calculation_daily.md`
- Does not calculate overtime
- Does not apply the morning cutoff rule
- Does not deduplicate timestamps
