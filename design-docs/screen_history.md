# screen_history

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

The second tab of the app. Lists all previously generated reports. The user can open any past report or delete it. Also receives the newly generated report automatically after generation completes on the Input tab.

---

## Layout

RTL. Scrollable table filling the screen. Empty state message if no reports exist: لا توجد تقارير سابقة.

---

## Component — Reports Table

All saved reports displayed as a table, ordered by generation date descending.

| Column | Arabic Label | Content |
|---|---|---|
| Generation date | تاريخ الإنشاء | Date the report was generated |
| Period from | من | Report start date |
| Period to | إلى | Report end date |

Tapping a row loads the full report and pushes the Report screen on top of this tab.

Swiping a row reveals a delete option. Arabic confirmation prompt before deletion. Deletion is permanent — cascade deletes all child data.

---

## Data Source

Table loaded from database when the tab is opened or returned to. Summary-level only — full report loaded when a row is tapped.
