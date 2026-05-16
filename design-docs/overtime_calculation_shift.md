# overtime_calculation_shift

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines validity rules and overtime calculation for shift employees. Receives the shift hash table enriched with `ShiftPeriod` lists from `period_extractor_shift.md`. Enriches each `ShiftPeriod` in place with calculated fields and returns the updated hash table. Pure function — no database access, no UI dependency.

Periods with fewer than 2 satisfied zones have already been discarded by the extractor before this calculator receives them. Every period received here has at least 2 zones satisfied.

---

## Input

Shift hash table: `employeeName → { name, department, detectedShiftStartTime, [timestamps], [ShiftPeriod] }`

Each `ShiftPeriod` at this stage has base fields only (`periodDate`, `allTimestamps`, `zoneResults`, `periodIndex`). This calculator adds the remaining fields.

---

## Per-Period Enrichment

For each `ShiftPeriod`, the calculator sets:

- **endDate** — ISO 8601 date of the last timestamp. Derived at calculation time.
- **totalAttendanceDuration** — minutes from first to last timestamp. Set for all periods including invalid ones. Audit display only.
- **hoursCounted** — 24 if valid, 0 if invalid.
- **isValid** — whether all zones are satisfied. Set at calculation time — never changes after.
- **notes** — Arabic invalid reason. Null if valid.

A period spanning 26 actual hours still counts as 24. A period spanning 23 actual hours that meets all zone conditions also counts as 24.

---

## Validity Rules

Each period is valid only if all zones are satisfied — every zone must contain at least one timestamp within its tolerance window.

Zone results are pre-computed by the extractor and carried in each RawShiftPeriod's zoneResults list. The calculator reads these directly — it does not recompute zone assignments.

If any zone has no timestamp within its window, the period is invalid.

**Invalid reason stored:** يوجد فترة زمنية بدون بصمة تحقق

The specific zones that failed are visible in the detail screen from the zone timestamp display — a generic reason is sufficient.

---

## Hours Per Valid Period

Binary result: valid = 24 hours, invalid = 0 hours. No rounding needed or applied.

---

## Output

The same shift hash table with all `ShiftPeriod` objects fully enriched:

`employeeName → { name, department, detectedShiftStartTime, [timestamps], [ShiftPeriod] }`

Where every `ShiftPeriod` now has all fields set. Total overtime per employee is always computed live at display time: sum of `hoursCounted` across periods → apply ceiling → subtract baseline → floor at 0. Never stored as a separate field.

---

## Settings Used

| Setting | Default |
|---|---|
| Shift duration | 24 hours |
| Zone interval | 6 hours |
| Tolerance | 60 minutes |
| Baseline hours | 154 hours |
| Ceiling hours | 192 hours |

All defined in `config.md`, managed in `screen_configuration.md`.

`shift_start_times` is used by the schedule detection algorithm only — not by the extractor or calculator at report generation time. The employee's `detectedShiftStartTime` from the shift hash table entry is used by the extractor instead.


---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
