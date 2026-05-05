# overtime_calculation_shift

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

Defines validity rules and overtime calculation for shift employees. Receives the Period list from `algorithm_extractor_shift.md` and returns a result per period. Pure function — no database access, no UI dependency.

---

## Per-Period Result

Each period produces two distinct values:

**Actual working hours** — the real duration from the period's first timestamp to its last timestamp. Stored in minutes for precision. Shown in the detail screen for audit purposes. Has no effect on the overtime formula.

**Hours counted** — binary: 24 hours if the period is valid, 0 if invalid. This is the value used in the monthly formula — not the actual working hours.

These are stored separately. A period spanning 26 actual hours still counts as 24. A period spanning 23 actual hours that meets all zone conditions also counts as 24.

---

## Validity Rules

Each period is valid only if all zones are satisfied — every zone must contain at least one timestamp within its tolerance window.

Zone count = `shift_duration / zone_interval` (default 24h / 6h = 4 zones).

If any zone has no timestamp within its window, the period is invalid.

**Invalid reason stored:** يوجد فترة زمنية بدون بصمة تحقق

The specific zones that failed are visible in the detail screen from the zone timestamp display — a generic reason is sufficient.

---

## Hours Per Valid Period

Binary result: valid = 24 hours, invalid = 0 hours. No rounding needed or applied.

---

## Monthly Calculation

1. Sum 24 hours for each valid period. Invalid periods contribute zero. This is the total worked hours.
2. Apply ceiling to total worked hours: if total exceeds configured ceiling (default 192h), cap at ceiling. This limits the maximum hours that can enter the overtime formula.
3. Subtract baseline from capped total. If result is negative or zero, overtime = 0.

Example: 10 valid periods = 240h → capped to 192h → minus 154h baseline = 38h overtime.

Final value stored as integer hours.

An employee with all invalid periods is still matched with zero overtime — distinct from an unmatched employee.

---

## Settings Used

| Setting | Default |
|---|---|
| Shift duration | 24 hours |
| Zone interval | 6 hours |
| Start/end tolerance | 30 minutes |
| Inner zone tolerance | 60 minutes |
| Baseline hours | 154 hours |
| Ceiling hours | 192 hours |

All defined in `config.md`, managed in `screen_configuration.md`.
