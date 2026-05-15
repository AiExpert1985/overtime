# screen_configuration

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Tab 2 of the app. Manages all user-configurable settings: daily employee thresholds, shift employee thresholds, display rounding mode, and attendance column header values.

---

## Layout

RTL. Single scrollable screen. Settings are displayed inline — no sub-screens except for Column Header Management, which is pushed as a separate screen.

Each setting row shows:
- Arabic name (right-aligned)
- Current value (editable inline or via tap)
- Hint button (?) — tapping shows the full Arabic description from `config.md` as a small dismissible dialog

All changes take effect immediately.

---

## Section — Daily Employee Settings

| Setting | Default | Input type |
|---|---|---|
| بداية الدوام | 08:00 | Time picker |
| ساعات الدوام | 8 hours | Number input (hours) |
| اقصى وقت اضافي | 3 hours | Number input (hours) |

End time shown as read-only derived value: "وقت النهاية: HH:MM" — updates automatically when start time or duration changes.

---

## Section — Shift Employee Settings

| Setting | Default | Input type |
|---|---|---|
| بداية المناوبة | [08:00] | List — multiple values allowed. Add button adds a new time entry. Each entry has a delete icon. At least one value must remain. Used by schedule detection only — not applied directly during report generation. |
| مدة المناوبة | 24 hours | Number input (hours) |
| عدد ساعات كل بصمة | 6 hours | Number input (hours) |
| دقائق السماح لبصمة البداية و النهاية | 60 minutes | Number input (minutes) |
| دقائق سماح البصمة خلال المناوبة | 30 minutes | Number input (minutes) |
| ساعات العمل الأساسية | 154 hours | Number input (hours) |
| الحد الأقصى للساعات الشهرية | 192 hours | Number input (hours) |

Zone count shown as read-only derived value: "عدد نقاط التحقق: N" — derived from shift_duration / zone_interval.

---

## Section — Display Settings

**وضع التقريب** — four mutually exclusive options (radio group):

| Option | Arabic Label |
|---|---|
| No rounding | بدون تقريب |
| Quarter-hour | تقريب لربع ساعة |
| Half-hour | تقريب لنصف ساعة |
| Hour | تقريب لساعة كاملة |

Default: quarter-hour. Affects display only — stored values unchanged.

Standard rounding rule: if remainder is at or above the midpoint of the interval, round up; otherwise round down. Examples: 1h 08m → 1h 15m (quarter), 1h 07m → 1h 00m (quarter), 1h 45m → 2h (hour), 1h 29m → 1h (hour).

---

## Section — Column Header Management

Displayed as a single row with a brief description and a navigation arrow. Tapping pushes the Column Header Management screen.

---

## Screen — Column Header Management

Pushed from the Settings screen. Back button returns to Settings.

Covers the attendance file only. Lists all field keys for the attendance file. Per field:
- Default values shown with lock icon — cannot be edited or deleted
- User-added values shown with edit and delete icons
- Add button opens a single-input Arabic text dialog. Value must be non-empty and unique per field.
- Edit opens the same dialog pre-populated.
- Delete shows Arabic confirmation prompt before removing.

Changes take effect next time an attendance file is selected on the Report Generation screen.
