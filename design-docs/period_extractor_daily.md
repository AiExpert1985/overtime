# period_extractor_daily

**Created**: 27-Apr-2026 **Modified**: 14-May-2026

---

## Purpose

Defines the period extraction algorithm for daily employees. Receives the daily hash table, enriches each employee entry with their period list, and returns the updated hash table. Pure function — no database access, no overtime rules, no side effects.

---

## What a Daily Employee Is

A daily employee works standard morning shifts on regular workdays. Their attendance is measured strictly within one calendar day — a fingerprint on day 2 never belongs to day 1.

---

## Input

- Daily hash table: `employeeName → { name, department, [timestamps] }` — timestamps sorted ascending, filtered to report date range
- Off-days hash set — produced by Stage 5 (off-day detection). Contains all dates classified as off-days for this report. Passed in as input to this extractor at Stage 7.

---

## Output

The same daily hash table enriched with a list of `RawDailyPeriod` objects per employee:

`employeeName → { name, department, [timestamps], [RawDailyPeriod] }`

### RawDailyPeriod

|Field|Content|
|---|---|
|date|Calendar date (ISO 8601)|
|dayType|regular / off|
|timestamps|All timestamps of the day, sorted ascending|
|weekday|Arabic weekday name stored at extraction time e.g. الأحد، الاثنين|

---

## Algorithm

Runs for each employee in the daily hash table independently.

**Step 1 — Group by calendar date** Partition the timestamp list by calendar date. Each partition is one candidate period. A timestamp on day 2 is never placed in day 1's partition regardless of time.

**Step 2 — Drop empty partitions** Discard any partition with 0 timestamps. These days have no attendance signal.

**Step 3 — Classify day type** For each remaining partition:

- Date exists in off-days hash set → off
- Otherwise → regular

**Step 4 — Build RawDailyPeriod** For each remaining partition, create one `RawDailyPeriod` with: date, dayType, full sorted timestamp list, and Arabic weekday name derived from the date.

Days with exactly 1 timestamp are included — the calculator determines validity, not the extractor.

**Step 5 — Update Hash Table** Store the list of `RawDailyPeriod` objects into the employee's hash table entry under a `periods` field. Return the enriched hash table.

---

## What This Extractor Does NOT Do

- Does not validate periods (valid/invalid) — that is `overtime_calculation_daily.md`
- Does not calculate overtime
- Does not apply the morning cutoff rule
- Does not deduplicate timestamps
- Does not run off-day detection — the off-days hash set is passed in as input

---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.