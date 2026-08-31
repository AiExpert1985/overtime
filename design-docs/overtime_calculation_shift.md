# overtime_calculation_shift

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines validity rules and overtime calculation for shift employees. Receives the shift hash table enriched with `ShiftPeriod` lists built during schedule detection — see `schedule_detection.md`. The separate extraction stage described in `period_extractor_shift.md` was retired when detection began building periods directly. Enriches each `ShiftPeriod` in place with calculated fields and returns the updated hash table. Pure function — no database access, no UI dependency.

Periods below `min_zones_satisfied` (`zoneCount − 1`) have already been discarded during detection, except anchor-pair periods, which bypass the zone check entirely. That discard is a separate, earlier filter — it removes a period outright, while the checks below only mark a surviving period invalid.

A consequence worth knowing: because a zone-based period reaching this calculator has at most one unsatisfied zone, its reason set holds at most one zone reason. The set becomes genuinely multi-valued through the duration check, or on anchor-pair periods.

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
- **isValid** — true only when the reason set is empty. Set at calculation time — never changes after.
- **notes** — set of every applicable Arabic invalid reason. Empty set if valid.

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

Zone results carry both the full timestamp list (for display) and the `isSatisfied` flag (for overtime). The calculator reads `isSatisfied` from each zone result directly — it does not recompute zone assignments.

`isSatisfied` is computed with `shift_edge_tolerance`, not the wider `detection_edge_tolerance` that governs classification. A period can therefore be admitted by detection and still fail every check here — that is the intended separation, not a contradiction.

### All checks run — no short-circuit

Four independent checks run on every period. None skips another, so evaluation order does not affect the outcome. Each failed check adds its Arabic reason to a **set** — a set, not a list, so multiple failing inner zones collapse to one entry with no manual dedup.

| Reason | Arabic |
|---|---|
| B1 not satisfied | بصمة الدخول خارج الوقت المسموح به |
| One or more inner zones not satisfied | لم يتم استيفاء العدد المطلوب من نقاط التحقق الداخلية (المطلوب: X نقطة) |
| BN not satisfied | بصمة الخروج خارج الوقت المسموح به |
| Attendance span below the minimum | مدة الحضور الفعلية أقل من الحد الأدنى المطلوب |

X is the number of inner zones, `zoneCount − 2`. The inner reason is added once no matter how many inner zones fail.

### Duration check

`totalAttendanceDuration ≥ (shift_duration × 60) − shift_duration_tolerance`, in minutes.

`totalAttendanceDuration` is the existing first-to-last timestamp span — no other value is used. This check is independent of the zone checks: a period can fail it while satisfying every zone, and vice versa. With the default `shift_duration_tolerance` of 60 minutes and an edge tolerance of 30, a period whose opening and closing stamps both sit inside their windows always passes, since the narrowest such span is `shift_duration − 2 × shift_edge_tolerance`.

Because the span is measured from the extreme timestamps, it is sensitive to a stray early or late punch. This is accepted deliberately — `totalAttendanceDuration` is the defined input.

`isValid = true` if and only if the reason set is empty. `hoursCounted` stays binary: 24 if valid, 0 if invalid.

Invalid zones are highlighted in the detail screen with a red background and ✗ indicator.

---

## Hours Per Valid Period

Binary result: valid = 24 hours (`hoursCounted = 24`), invalid = 0 hours (`hoursCounted = 0`). No rounding needed or applied.

---

## Output

The same shift hash table with all `ShiftPeriod` objects fully enriched, and each employee entry updated with a computed `overtimeHours` field:

`employeeName → { name, department, detectedShiftStartTime, overtimeHours, [timestamps], [ShiftPeriod] }`

### Per-Employee Overtime Formula

After enriching all periods for an employee:

```
totalHoursCounted = sum of hoursCounted across all periods
cappedHours = min(totalHoursCounted, shift_ceiling_hours)
overtimeHours = max(0, cappedHours − shift_baseline_hours)
```

Stored in minutes on the employee result row for consistency with daily employees. Never recomputed after storage — this value is the permanent result of this generation run.

---

## Settings Used

| Setting | Default |
|---|---|
| Shift duration | 24 hours |
| Zone interval | 6 hours |
| Edge tolerance | 30 minutes |
| Inner tolerance | 120 minutes |
| Duration tolerance | 60 minutes |
| Baseline hours | 154 hours |
| Ceiling hours | 192 hours |

All defined in `config.md`, managed in `screen_configuration.md`.

`shift_start_times` is used by the schedule detection algorithm only — not by the extractor or calculator at report generation time. The employee's `detectedShiftStartTime` from the shift hash table entry is used by the extractor instead.


---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
