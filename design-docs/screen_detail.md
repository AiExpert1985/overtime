# screen_detail

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Shows the period-by-period breakdown for one employee. Used for audit — displays all stored timestamps, zone results (shift), validity status, and overtime per period. Reached by tapping an employee row on the report screen.

---

## Layout

RTL. Single scrollable screen. Content horizontally centered. Fixed header at top. Scrollable period table below. Only periods with at least one timestamp are shown.

---

## Data Loading

Fetches period details from the database on mount using `employeeResultId` from the route parameter. Queries `shift_period_details` or `daily_period_details` depending on `employeeType`. The Report screen does not preload periods — this screen is responsible for its own data fetch. A loading indicator is shown while the fetch completes.

---

## Timestamp Display Rule

All timestamps are displayed as **time only** — no date component. Format: `H:mm ص/م` using Arabic locale (e.g. `8:14 ص`, `11:35 م`). The date is shown in its own column — repeating it inside timestamp cells adds noise without value.

---

## Component — Employee Header

**Daily employees:**
- Employee name, department, date range
- Total overtime (with rounding)

**Shift employees:**
- Employee name, department, date range
- Total valid shift days
- Total actual working hours (sum of totalAttendanceDuration across all periods)
- Total counted hours (sum of hoursCounted — each valid period contributes 24)
- Total overtime hours — computed live: min(total counted hours, ceiling) − baseline, floored at 0. Ceiling and baseline read from current settings at display time.

---

## Period Table — Daily Employees

One row per calendar day with at least one timestamp, ordered by date ascending.

| Column | Arabic Label | Content |
|---|---|---|
| Date | التاريخ | Short date e.g. 01/12 |
| Weekday | اليوم | Arabic weekday name — read from stored weekday field |
| Day type | نوع اليوم | عادي / عطلة |
| Entry | الدخول | Time of first timestamp |
| All timestamps | البصمات | All intermediate timestamps listed vertically |
| Exit | الخروج | Time of last timestamp |
| Working hours | ساعات الحضور | Duration from first to last timestamp. Shown for all days including invalid. |
| Overtime | الوقت الإضافي | Overtime minutes for this period. 0 if invalid. |
| Notes | ملاحظات | Arabic invalid reason. Empty if valid. |

### Row Color Coding

- Valid period: white background
- Invalid period: light red background

### Invalid Reasons

| Reason | Arabic |
|---|---|
| Fewer than 2 timestamps | بصمة واحدة فقط |
| First timestamp after start time | البصمة الأولى تتجاوز وقت البداية المحدد |

---

## Period Table — Shift Employees

One row per detected shift period, ordered by period date ascending.

| Column | Arabic Label | Content |
|---|---|---|
| Start date | تاريخ البداية | Calendar date this period is anchored to |
| End date | تاريخ النهاية | Date of last timestamp |
| Zones | نقاط التحقق | All zones stacked vertically. Each zone shows: label (e.g. نقطة 1: 08:00) and all timestamps within the zone window. Valid zones (at least one timestamp within center ± tolerance) show normally. Invalid zones show red background with ✗ indicator — a zone can have timestamps and still be invalid if none fall within center ± tolerance. |
| Working hours | ساعات الحضور | Duration from first to last timestamp. Shown for all periods. |
| Hours counted | الساعات المحتسبة | 24 if valid, 0 if invalid |
| Notes | ملاحظات | Arabic invalid reason. Empty if valid. |

Zones column is fixed width — zones stack vertically within the cell.

**Note:** All timestamps within a zone window are always displayed regardless of center validity. The ✗ and red background reflect overtime validity only — not absence of timestamps.

### Row Color Coding

- Valid period: white background
- Invalid period: light red background

### Invalid Reason

| Reason | Arabic |
|---|---|
| Missing timestamp in one or more zones | يوجد فترة زمنية بدون بصمة تحقق |
