# screen_detail

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

Shows the period-by-period breakdown for one employee. Used for audit — displays all stored timestamps, zone results (shift), validity status, and overtime per period. Reached by tapping an employee row on the report screen.

---

## Layout

RTL. Fixed header at top. Scrollable period table below. Only periods with at least one timestamp are shown.

---

## Component — Employee Header

**Daily employees:**
- Employee name, employment type, department, date range
- Total regular overtime (with rounding)
- Total holiday/weekend overtime (with rounding)
- Grand total overtime (with rounding)

**Shift employees:**
- Employee name, employment type, department, date range
- Total valid shift days
- Total actual working hours (sum of actual durations across all periods)
- Total counted hours (valid days × 24)
- Total overtime hours (counted hours − baseline, floored at 0, capped at ceiling)

---

## Period Table — Daily Employees

One row per calendar day with at least one timestamp, ordered by date ascending.

| Column | Arabic Label | Content |
|---|---|---|
| Date | التاريخ | Short date e.g. 01/12 |
| Day type | نوع اليوم | عادي / عطلة / عطلة أسبوعية |
| Entry | الدخول | First timestamp of the day |
| All timestamps | البصمات | All timestamps between entry and exit, listed vertically |
| Exit | الخروج | Last timestamp of the day |
| Working hours | ساعات الحضور | Actual duration from first to last timestamp. Shown for all days — valid and invalid. |
| Overtime | الوقت الإضافي | Overtime hours for valid periods. 0 for valid with no overtime. |
| Notes | ملاحظات | Invalid reason if applicable. Empty if valid. |

### Row Color Coding

- Valid day (any overtime including zero): white background
- Invalid day: light red background

### Invalid Reasons

| Reason | Arabic |
|---|---|
| Fewer than 2 timestamps | بصمة واحدة فقط |
| First timestamp after start time | البصمة الأولى تتجاوز وقت البداية المحدد |

---

## Period Table — Shift Employees

One row per detected shift period, ordered by anchor timestamp ascending.

| Column | Arabic Label | Content |
|---|---|---|
| Date | التاريخ | Date of anchor timestamp |
| Anchor | بصمة البداية | Anchor timestamp |
| Zones | نقاط التحقق | All zones stacked vertically. Each zone shows: label (e.g. نقطة 1: 08:00), timestamps within zone, or — if empty |
| Working hours | ساعات الحضور | Actual duration from first to last timestamp of the period. Shown for all periods valid or invalid. |
| Hours counted | الساعات المحتسبة | 24 if valid, 0 if invalid. Used in monthly overtime formula. |
| Notes | ملاحظات | Invalid reason if applicable. Empty if valid. |

Zones column is fixed width regardless of zone count — zones stack vertically within the cell. Empty zones are visually distinct (dash or red indicator), making invalid periods self-explanatory without requiring a detailed text reason.

### Row Color Coding

- Valid period: white background
- Invalid period: light red background

### Invalid Reason

| Reason | Arabic |
|---|---|
| Missing timestamp in one or more check zones | يوجد فترة زمنية بدون بصمة تحقق |

---

## Data Source

Reads from the current report provider. No database fetch on mount.
