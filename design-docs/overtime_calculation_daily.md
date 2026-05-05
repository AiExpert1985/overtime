# overtime_calculation_daily

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

Defines validity rules and overtime calculation for daily employees. Receives the Period list from `algorithm_extractor_daily.md` and returns a result per period. Pure function — no database access, no UI dependency.

---

## Per-Period Result

Each period produces two distinct values:

**Actual working hours** — the real duration from the period's first timestamp to its last timestamp. Stored in minutes. Shown in the detail screen for audit purposes.

**Overtime hours** — calculated against the end time (regular days) or as full span (holiday days), capped at daily maximum. This is what accumulates toward the monthly total.

Both are stored separately per period.

---

## End Time Derivation

End time is not a stored setting. Derived as: `end_time = start_time + work_duration`.

Example: start 09:00 + 8 hours = end 17:00. Overtime is anything worked beyond 17:00.

---

## Normal Day Rules

### Validation

Both conditions must be met:
1. Period has at least 2 timestamps.
2. firstTimestamp is not later than the configured start time.

If either fails, period is invalid.

### Calculation

`overtime = max(0, lastTimestamp − end_time)`

Capped at configured daily maximum. Both raw and capped values stored.

### Invalid Reasons

| Condition | Arabic |
|---|---|
| Fewer than 2 timestamps | بصمة واحدة فقط |
| First timestamp after start time | البصمة الأولى تتجاوز وقت البداية المحدد |

---

## Holiday / Weekend Day Rules

### Validation

One condition must be met:
1. Period has at least 2 timestamps.

No start time requirement.

### Calculation

`overtime = lastTimestamp − firstTimestamp`

Capped at configured daily maximum. Both raw and capped values stored. Calendar day grouping in the extractor enforces the natural 24-hour ceiling — no explicit cap needed here.

### Invalid Reason

| Condition | Arabic |
|---|---|
| Fewer than 2 timestamps | بصمة واحدة فقط |

---

## Monthly Totals

Regular and holiday/weekend overtime accumulated separately in minutes. Never combined. Both stored as raw minutes — no rounding applied. Rounding is display-only per configured rounding mode in `screen_configuration.md`.

Separation is intentional — the cost per overtime hour may differ between regular days and holidays.

---

## Settings Used

| Setting | Default |
|---|---|
| Start time | 09:00 |
| Work duration | 8 hours |
| Max overtime per day | 3 hours |

All defined in `config.md`, managed in `screen_configuration.md`.
