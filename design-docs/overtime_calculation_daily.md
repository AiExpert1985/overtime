# overtime_calculation_daily

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines validity rules and overtime calculation for daily employees. Receives the daily hash table enriched with `DailyPeriod` lists from `period_extractor_daily.md`. Enriches each `DailyPeriod` in place with calculated fields and returns the updated hash table. Pure function — no database access, no UI dependency.

---

## Input

Daily hash table: `employeeName → { name, department, [timestamps], [DailyPeriod] }`

Each `DailyPeriod` at this stage has base fields only (`date`, `dayType`, `allTimestamps`, `weekday`, `periodIndex`). This calculator adds the remaining fields.

---

## Per-Period Enrichment

For each `DailyPeriod`, the calculator sets:

- **totalAttendanceDuration** — minutes from first to last timestamp. Set for all periods including invalid ones. Audit display only.
- **overtimeMinutes** — calculated overtime in minutes. 0 if invalid.
- **isValid** — whether this period passed validation. Set at calculation time — never changes after.
- **notes** — Arabic invalid reason. Null if valid.

---

## End Time Derivation

End time is not a stored setting. Derived as: `end_time = daily_start_time + daily_work_duration`.

Example: start 08:00 + 8 hours = end 16:00. Overtime is anything worked beyond 16:00.

---

## Regular Day Rules

### Validation

Both conditions must be met:
1. Period has at least 2 timestamps.
2. First timestamp is not later than `daily_start_time + daily_delay_allowance`.

The delay allowance gives employees a configurable grace period after the official start time. Overtime is still calculated from `end_time` regardless of when the employee arrived — the delay allowance only affects validity, not the overtime formula.

Example: start 08:00, delay allowance 60 min → employee valid if first timestamp ≤ 09:00. End time remains 16:00.

If either condition fails → `isValid = false`, `overtimeMinutes = 0`, `notes` set to Arabic reason.

### Calculation

`overtimeMinutes = max(0, lastTimestamp − end_time)`

Capped at configured daily maximum.

### Invalid Reasons

| Condition | Arabic |
|---|---|
| Fewer than 2 timestamps | بصمة واحدة فقط |
| First timestamp after start time + delay allowance | البصمة الأولى تتجاوز وقت البداية مع وقت السماح |

---

## Off Day Rules

### Validation

One condition must be met:
1. Period has at least 2 timestamps.

No start time requirement.

### Calculation

`overtimeMinutes = lastTimestamp − firstTimestamp`

Capped at configured daily maximum.

### Invalid Reason

| Condition | Arabic |
|---|---|
| Fewer than 2 timestamps | بصمة واحدة فقط |

---

## Output

The same daily hash table with all `DailyPeriod` objects fully enriched:

`employeeName → { name, department, [timestamps], [DailyPeriod] }`

Where every `DailyPeriod` now has all fields set. Total overtime per employee is always computed live at display time by summing `overtimeMinutes` across periods — never stored as a separate field.

---

## Settings Used

| Setting | Default |
|---|---|
| Start time | 08:00 |
| Work duration | 8 hours |
| Max overtime per day | 3 hours |

All defined in `config.md`, managed in `screen_configuration.md`.

---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
