# screen_report_list

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Tab 1 of the app. Lists all generated reports ordered by generation datetime descending. The user can open any report or delete it. After a new report is generated, the Report Generation screen is popped and the new Report screen is pushed on top of this screen automatically — this screen refreshes its list from the database when returned to.

A floating add button (FAB) in the bottom-left corner pushes the Report Generation screen.

---

## Layout

RTL. Single scrollable screen. Content horizontally centered. Scrollable table filling the screen. Empty state message if no reports exist: لا توجد تقارير سابقة.

---

## Component — Reports Table

All saved reports displayed as a table, ordered by generation datetime descending.

| Column              | Arabic Label  | Content                                                        |
| ------------------- | ------------- | -------------------------------------------------------------- |
| Generation datetime | تاريخ الإنشاء | Date and time the report was generated (e.g. 05/05/2026 14:32) |
| Period from         | من            | Report start date                                              |
| Period to           | إلى           | Report end date                                                |
| Actions             | —             | Delete button per row                                          |

Tapping a row (outside the delete button) navigates to the Report screen, passing the `reportId`. The Report screen loads its own data from the database on mount.

Tapping the delete button shows an Arabic confirmation prompt before deletion. Deletion is permanent — cascade deletes all child data.

---

## Data Source

List loaded from database when the tab is opened or returned to. Per report row: id, generation datetime, date range, and undetected employee count (queried as count of `undetected_employee_results` rows for that report id). The Report screen handles its own full data load.
