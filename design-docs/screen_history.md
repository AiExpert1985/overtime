# screen_history

**Created**: 27-Apr-2026
**Modified**: 27-Apr-2026

---

## Purpose

The second tab of the app. Lists all generated reports ordered by generation date descending. The user can open any report or delete it. After a new report is generated, the app switches to this tab and pushes the new Report screen automatically — this screen refreshes its list from the database when returned to.

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

Tapping a row navigates to the Report screen, passing the `reportId`. The Report screen loads its own data from the database on mount.

Swiping a row reveals a delete option. Arabic confirmation prompt before deletion. Deletion is permanent — cascade deletes all child data.

---

## Data Source

List loaded from database when the tab is opened or returned to. Summary-level data only — name, dates, id. The Report screen handles its own full data load.
