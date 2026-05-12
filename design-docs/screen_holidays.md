# screen_holidays

**Created**: 12-May-2026
**Modified**: 12-May-2026

---

## Purpose

Tab 2 of the app. Manages the permanent list of official holidays used during daily overtime calculation to classify day types. Changes here have no effect on previously generated reports — day type is stored as a denormalized snapshot.

---

## Layout

RTL. Scrollable table filling the screen. Floating add button (FAB) in the bottom-left corner. Empty state message if no holidays have been added: لم يتم إضافة أي عطل رسمية بعد.

---

## Component — Holidays Table

All holidays displayed as a table, ordered by date ascending.

| Column | Arabic Label | Content |
|---|---|---|
| Date | التاريخ | e.g. 01/01/2026 |
| Occasion | المناسبة | Arabic description |
| Actions | — | Edit and delete icons per row |

---

## Add / Edit Dialog

Tapping the FAB opens the Add dialog. Tapping the edit icon opens the same dialog pre-populated.

Fields:
- **التاريخ** — date picker (calendar), required
- **المناسبة** — text input, required

Save button disabled until both fields are filled. On save, row is inserted or updated immediately and the table refreshes.

No uniqueness enforced on date — the same date may appear more than once if needed. This is treated as a data quality matter, not a validation error.

---

## Delete

Tapping the delete icon shows an Arabic confirmation prompt before removal. Deletion is permanent — hard delete.

Previously generated reports are not affected.

---

## Data Source

Reads from and writes to the `holidays` table via the ReferenceData repository.
