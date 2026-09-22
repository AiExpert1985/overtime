# off_day_detection

**Created**: 14-May-2026
**Modified**: 14-May-2026

---

## Purpose

Defines the algorithm for automatically detecting off-days from attendance data. Runs as Stage 5 of the app workflow — after schedule detection splits employees into type-specific hash tables, before period extraction begins. Produces a hash set of off-day dates consumed by the daily period extractor in Stage 6. Pure function — no database access, no side effects.

Off-days include weekends, public holidays, and any other day where the majority of daily employees did not attend. No manual input is required.

---

## Input

- Daily hash table: `employeeName → { name, department, [timestamps] }` — all daily employees with timestamps sorted ascending, filtered to report date range
- `off_day_threshold` — configured percentage (default 60%). From `config.md`.

---

## Output

A hash set of dates (ISO 8601) classified as off-days. Passed directly to the daily period extractor in Stage 6. Not persisted.

---

## Minimum Employee Guard

If no daily employees are present in the hash table, the algorithm returns an empty hash set. All days are treated as regular. No error is raised.

---

## Algorithm

**Step 1 — Enumerate dates**
Collect every calendar date in the report range.

**Step 2 — Weekend check**
Friday and Saturday are the organization's fixed weekly rest days for daily employees. Any date falling on Friday or Saturday is classified as off-day unconditionally — no attendance check is performed for it. This is a fixed rule, not user-configurable.

**Step 3 — Count attendance per date**
For every remaining (non-weekend) date, count how many daily employees have 1 or more timestamps on that date. This is the attended count.

**Step 4 — Classify**
For each non-weekend date:

`attendance_rate = attended_count / total_daily_employees`

- If `attendance_rate < off_day_threshold` → off-day
- Otherwise → regular

**Step 5 — Output**
Return the set of all dates classified as off-day (weekend dates plus density-classified dates).

---

## Threshold Behavior

The threshold is a strict less-than comparison. A day must fall strictly below the threshold to be classified as off. At the default of 60%: a day where 60% or more of daily employees attended is classified as regular.

Example with 10 daily employees and 60% threshold:
- 2 attended → 20% → off (below 60%)
- 5 attended → 50% → off (below 60%)
- 6 attended → 60% → regular (at threshold)
- 8 attended → 80% → regular (above 60%)

Raised from an original default of 25% after measuring real attendance data: genuine weekdays never dipped below ~70% attendance among daily employees and genuine weekends never exceeded ~20%, while a partial-holiday day with a reduced skeleton crew sat at ~36% — well above the old 25% threshold, so it was wrongly classified as a regular working day and missed entirely. 60% catches that case with a comfortable margin below genuine weekday attendance. See `config.md`.

---

## Hardcoded Constants

| Constant | Value |
|---|---|
| Off-day threshold | 60% |
| Weekly rest days | Friday, Saturday |

These values are fixed in code — not user-configurable. Defined in `config.md` hardcoded constants.

---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
