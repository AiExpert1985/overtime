# overtime_calculation_daily

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines validity rules and overtime calculation for daily employees. Receives the list of RawDailyPeriod objects from `period_extractor_daily.md` and returns a `DailyEmployeeResult`. Pure function — no database access, no UI dependency.

---

## Per-Period Result

Each period produces two distinct values:

**totalAttendanceDuration** — the real duration from the period's first timestamp to its last timestamp, in minutes. Shown in the detail screen for audit purposes. Not used in the overtime formula.

**overtimeMinutes** — calculated against the end time (regular days) or as full span (off days), capped at daily maximum. This is what accumulates toward the monthly total.

---

## End Time Derivation

End time is not a stored setting. Derived as: `end_time = start_time + work_duration`.

Example: start 09:00 + 8 hours = end 17:00. Overtime is anything worked beyond 17:00.

---

## Regular Day Rules

### Validation

Both conditions must be met:
1. Period has at least 2 timestamps.
2. First timestamp is not later than the configured start time.

If either fails, period is invalid.

### Calculation

`overtimeMinutes = max(0, lastTimestamp − end_time)`

Capped at configured daily maximum.

### Invalid Reasons

| Condition | Arabic |
|---|---|
| Fewer than 2 timestamps | بصمة واحدة فقط |
| First timestamp after start time | البصمة الأولى تتجاوز وقت البداية المحدد |

---

## Off Day Rules

Off days include weekends and any day auto-detected as an off-day. The calculator applies the same rules regardless of which reason caused the off classification.

### Validation

One condition must be met:
1. Period has at least 2 timestamps.

No start time requirement.

### Calculation

`overtimeMinutes = lastTimestamp − firstTimestamp`

Capped at configured daily maximum. Calendar day grouping in the extractor enforces the natural 24-hour ceiling — no explicit cap needed here.

### Invalid Reason

| Condition | Arabic |
|---|---|
| Fewer than 2 timestamps | بصمة واحدة فقط |

---

## Monthly Total

All overtime accumulated into a single `overtimeMinutes` value on the DailyEmployeeResult regardless of day type. Stored as raw minutes — no rounding applied. Rounding is display-only per configured rounding mode in `screen_configuration.md`.

---

## Output

Returns `DailyEmployeeResult`. See `data_shared_models.md`.

---

## Settings Used

| Setting | Default |
|---|---|
| Start time | 09:00 |
| Work duration | 8 hours |
| Max overtime per day | 3 hours |

All defined in `config.md`, managed in `screen_configuration.md`.
