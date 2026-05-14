# overtime_calculation_shift

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines validity rules and overtime calculation for shift employees. Receives the list of RawShiftPeriod objects from `period_extractor_shift.md` and returns a `ShiftEmployeeResult`. Pure function — no database access, no UI dependency.

Non-shift days have already been discarded by the extractor before this calculator receives the periods. Every period received here has at least one inner zone timestamp.

---

## Per-Period Result

Each period produces two distinct values:

**totalAttendanceDuration** — the real duration from the period's first timestamp to its last timestamp, in minutes. Shown in the detail screen for audit purposes. Has no effect on the overtime formula.

**hoursCounted** — binary: 24 hours if the period is valid, 0 if invalid. This is the value used in the monthly formula — not the actual working hours.

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

## Monthly Calculation

1. Sum 24 hours for each valid period. Invalid periods contribute zero. This is the total worked hours.
2. Apply ceiling to total worked hours: if total exceeds configured ceiling (default 192h), cap at ceiling. The ceiling applies to worked hours — not to the final overtime value.
3. Subtract baseline from capped total. If result is negative or zero, overtime = 0.

Example: 10 valid periods = 240h → capped to 192h → minus 154h baseline = 38h overtime.

Final value stored as integer hours in `overtimeHours` on the ShiftEmployeeResult.

An employee with all invalid periods contributes zero overtime but still appears in the report as a detected shift employee — distinct from an undetected employee.

---

## Output

Returns `ShiftEmployeeResult`. See `data_shared_models.md`.

---

## Settings Used

| Setting | Default |
|---|---|
| Shift duration | 24 hours |
| Zone interval | 6 hours |
| Start/end tolerance | 60 minutes |
| Inner zone tolerance | 30 minutes |
| Baseline hours | 154 hours |
| Ceiling hours | 192 hours |

All defined in `config.md`, managed in `screen_configuration.md`.

`shift_start_times` is used by the schedule detection algorithm only — not by the extractor or calculator at report generation time. The employee's `detectedShiftStartTime` from the shift hash table entry is used by the extractor instead.


---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
