# dictionary_build

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Defines how the working dictionary is built from the attendance file and the selected date range. This is Stage 3 of the app workflow — see `main_workflow.md`. No external employee list is used — all employees are detected directly from the attendance file.

---

## Step 1 — Single-Pass Record Collection

One sequential pass over all attendance records across all files and sheets. Per record:

- Date outside requested range → discard
- Otherwise → add timestamp to that employee's entry in the working dictionary, keyed by employee name

Department is read from the same row as the timestamp and stored on the dictionary entry. If the same employee appears across multiple rows, the department value from the first encountered row is used — department is expected to be consistent per employee.

If the same employee name appears across multiple attendance files or sheets, their timestamps are merged into the same dictionary entry naturally during this pass.

Date and time values from Excel files may be stored as Excel serial numbers or formatted text strings. Both are handled. All timestamps are normalized to local device time.

Working dictionary: `employeeName → { name, department, [timestamps] }`

**Complexity:** O(n) where n = total attendance records. Every record read exactly once.

---

## Step 2 — Sort

For each employee in the dictionary, sort the timestamp list ascending.

---

## Result

The working dictionary is the output of Stage 3. It is passed directly to Stage 4 (Schedule Detection). After results are stored to the database, the dictionary is discarded — the database is the sole source of truth.

There is no unmatched employee concept — every name found in the attendance file within the date range becomes a dictionary entry. Filtering by employee happens implicitly through the detection algorithm in Stage 4.
