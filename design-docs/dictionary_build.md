# dictionary_build

**Created**: 27-Apr-2026
**Modified**: 28-Sep-2026

---

## Purpose

Defines how the working dictionary is built from the attendance file and the selected date range.

---

## Step 1 — Single-Pass Record Collection

One sequential pass over all attendance records across all files and sheets. Records come from one of two formats, detected per sheet (see `file_processing.md`):

- **Raw punch log** — one record per row: name, department and datetime read from columns matched against the configurable column headers.
- **Daily Attendance Listing** — converted first by `daily_listing_reader.dart`: the page's printed date is combined with each row's In and Out times, producing up to two records per row, with the fixed department `مبنى المديرية`.

From here on both formats are handled identically. Per record:

- Date outside requested range → discard
- Otherwise → add timestamp to that employee's entry in the working dictionary, keyed by employee name. If employee not found, add them along with their department.

Date and time values from Excel files may be stored as Excel serial numbers or formatted text strings. Both are handled. All timestamps are normalized to local device time.

Working dictionary: `employeeName → { name, department, [timestamps] }`

**Complexity:** O(n) where n = total attendance records. Every record read exactly once.

---

## Step 2 — Sort

After finishing processing all Excel files, sort the timestamp list ascending for each employee.

---

## Result

The working dictionary is passed directly to Stage 4 (Schedule Detection). After results are stored to the database, the dictionary is discarded — the database is the sole source of truth.


---

## Implementation Note

This stage must be implemented as a standalone function with the inputs and outputs defined above. The generation service calls it directly and passes its output to the next stage.
