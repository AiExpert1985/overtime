# screen_detail

**Created**: 27-Apr-2026
**Modified**: 05-May-2026

---

## Purpose

Shows the period-by-period breakdown for one employee. Used for audit — displays all stored timestamps, zone results (shift), validity status, and overtime per period. Reached by tapping an employee row on the report screen.

---

## Layout

RTL. Fixed header at top. Scrollable period table below. Only periods with at least one timestamp are shown.

---

## Timestamp Display Rule

All timestamps throughout this screen are displayed as **time only** — no date component. Format: `H:mm ص/م` using Arabic locale (e.g. `8:14 ص`, `11:35 م`). The date is already shown in its own column — repeating it inside timestamp cells adds noise without value.

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
- Total actual working hours (sum of `totalAttendanceDuration` across all periods)
- Total counted hours (sum of `hoursCounted` across all periods — each period contributes 24 or 0)
- Total overtime hours — reconstructed at display time: min(total counted hours, ceiling) − baseline, floored at 0. Ceiling and baseline values are read from current settings at display time. The stored `totalOvertimeHours` field on the employee record is the authoritative value — the reconstruction here is for showing the breakdown only.

---

## Period Table — Daily Employees

One row per calendar day with at least one timestamp, ordered by date ascending.

| Column | Arabic Label | Content |
|---|---|---|
| Date | التاريخ | Short date e.g. 01/12 |
| Weekday | اليوم | Arabic weekday name e.g. الأحد، الاثنين — read from stored weekday field |
| Day type | نوع اليوم | عادي / عطلة / عطلة أسبوعية |
| Entry | الدخول | Time of first timestamp e.g. 8:14 ص |
| All timestamps | البصمات | Time of all timestamps between entry and exit, listed vertically |
| Exit | الخروج | Time of last timestamp e.g. 3:47 م |
| Working hours | ساعات الحضور | Actual duration from first to last timestamp. Shown for all days — valid and invalid. |
| Overtime | الوقت الإضافي | Overtime for valid periods. 0 for valid with no overtime. |
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
| Start date | تاريخ البداية | Date of anchor timestamp |
| End date | تاريخ النهاية | Date of last timestamp — read from stored endDate field |
| Anchor | بصمة البداية | Time of anchor timestamp e.g. 8:02 ص |
| Zones | نقاط التحقق | All zones stacked vertically. Each zone shows: label (e.g. نقطة 1: 08:00), times of timestamps within zone, or — if empty |
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

Reads from the current report provider, which was populated by the Report screen's database fetch on mount. No additional database fetch needed.
