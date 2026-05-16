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

## Zone Center Definitions

Each zone has a center time used for validity checking:

| Zone | Center time |
|---|---|
| B1 (start) | `startTime` |
| B2 … B(N-1) (inner) | `startTime + (i × zone_interval)` where i = zone index |
| BN (end) | `startTime + shift_duration` |

**Example** — start 08:00, zone_interval 6h, shift_duration 24h, tolerance 60min:

| Zone | Center | Valid window |
|---|---|---|
| B1 | 08:00 day 1 | 07:00 – 09:00 day 1 |
| B2 | 14:00 day 1 | 13:00 – 15:00 day 1 |
| B3 | 20:00 day 1 | 19:00 – 21:00 day 1 |
| B4 | 02:00 day 2 | 01:00 – 03:00 day 2 |
| B5 | 08:00 day 2 | 07:00 – 09:00 day 2 |

---

## Validity Rules

**Note:** All timestamps within a zone window are collected and stored for display purposes — the user sees every timestamp per zone in the detail screen. However, for overtime calculation, a zone is valid only if at least one timestamp falls within `[zone_center − tolerance, zone_center + tolerance]`. A zone may contain timestamps but still be invalid if none are close enough to the center.

A period is valid only if **all zones** are satisfied by this center-based check.

Zone results carry both the full timestamp list (for display) and the `isSatisfied` flag (for overtime). The calculator reads `isSatisfied` from each zone result directly — it does not recompute zone assignments.

If any zone has `isSatisfied = false` → `isValid = false`, `hoursCounted = 0`, `notes` set to Arabic reason.

**Invalid reason stored:** يوجد فترة زمنية بدون بصمة تحقق

Invalid zones are highlighted in the detail screen with a red background and ✗ indicator.

---

## Hours Per Valid Period

Binary result: valid = 24 hours (`hoursCounted = 24`), invalid = 0 hours (`hoursCounted = 0`). No rounding needed or applied.

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
