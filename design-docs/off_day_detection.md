# off_day_detection

**Created**: 14-May-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the algorithm for automatically detecting off-days from attendance data. Runs as Stage 5 of the app workflow — after schedule detection splits employees into type-specific hash tables, before period extraction begins. Produces a hash set of off-day dates consumed by the daily period extractor in Stage 7. Pure function — no database access, no side effects.

Off-days include weekends, public holidays, and any other day where the majority of daily employees did not attend. No manual input is required.

---

## Input

- Daily hash table: `employeeName → { name, department, [timestamps] }` — all daily employees with timestamps sorted ascending, filtered to report date range
- `off_day_threshold` — configured percentage (default 25%). From `config.md`.

---

## Output

A hash set of dates (ISO 8601) classified as off-days. Passed directly to the daily period extractor in Stage 7. Not persisted.

---

## Minimum Employee Guard

If no daily employees are present in the hash table, the algorithm returns an empty hash set. All days are treated as regular. No error is raised.

---

## Algorithm

**Step 1 — Enumerate dates**
Collect every calendar date in the report range.

**Step 2 — Count attendance per date**
For each date, count how many daily employees have 1 or more timestamps on that date. This is the attended count.

**Step 3 — Classify**
For each date:

`attendance_rate = attended_count / total_daily_employees`

- If `attendance_rate < off_day_threshold` → off-day
- Otherwise → regular

**Step 4 — Output**
Return the set of all dates classified as off-day.

---

## Threshold Behavior

The threshold is a strict less-than comparison. A day must fall strictly below the threshold to be classified as off. At the default of 25%: a day where 25% or more of daily employees attended is classified as regular.

Example with 10 daily employees and 25% threshold:
- 2 attended → 20% → off (below 25%)
- 3 attended → 30% → regular (above 25%)
- 5 attended → 50% → regular (above 25%)

---

## Hardcoded Constant

| Constant | Value |
|---|---|
| Off-day threshold | 25% |

This value is fixed in code — not user-configurable. Defined in `config.md` hardcoded constants.

---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
