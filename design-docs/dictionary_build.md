# dictionary_build

**Created**: 27-Apr-2026 **Modified**: 27-Apr-2026

---

## Purpose

Defines how the working dictionary is built from the uploaded files and selected date range. This is Stage 3 of the app workflow — see `main_workflow.md`. The dictionary and unmatched list are the output of this stage — if unmatched employees exist, the user is prompted before period extraction begins.

---

## Step 1 — Employee Lookup Set

A hash set is built from the target employees file. Each entry: { name, employment_type, department }. Used for O(1) lookup in the next step.

If the same employee name appears more than once across all employees files, the last row encountered for that name is used. No error is raised — this is treated as a data quality issue.

---

## Step 2 — Single-Pass Fingerprint Filtering

One sequential pass over all attendance records across all files and sheets. Per record:

- Name not in hash set → discard
- Date outside requested range → discard
- Otherwise → add timestamp to that employee's list in the working dictionary

If the same employee name appears across multiple attendance files or sheets, their timestamps are all added to the same dictionary entry — merging happens naturally during this pass.

Date and time values from Excel files may be stored as Excel serial numbers or formatted text strings. Both are handled. All timestamps are normalized to local device time.

Working dictionary: `employeeName → { name, type, department, [timestamps] }`

**Complexity:** O(n) where n = total fingerprint records. Minimum possible — every record read once.

---

## Step 3 — Sort

For each employee in the dictionary, sort timestamp list ascending.

---

## Step 4 — Unmatched Detection

Employees in the target list with no dictionary entry are flagged as unmatched. Their names are collected into an unmatched list. If the list is not empty, the user is prompted before extraction proceeds.

If the unmatched list is empty, extraction proceeds immediately.

If the user chooses to continue despite unmatched employees, those employees are carried forward with zero overtime and an Arabic note. See `screen_report.md` for how unmatched employees are displayed.

If the user chooses to abort, generation stops cleanly and the user returns to the Input screen with all selections intact.

### Unmatched Names Export

From the review dialog, the user may export the unmatched names only to a file. This serves as a correction checklist — the user can compare against their attendance files, fix name spelling, and re-run. The export contains only the unmatched names, nothing else.

---

## Name Matching Rules

Matching between attendance records and target employees is exact string comparison — case-sensitive and whitespace-sensitive. A trailing space or different capitalization causes a mismatch. The app does not infer intent — mismatches surface as unmatched employees in the report.

---

## Result

The working dictionary and unmatched list are the output of Stage 3. After the user confirms at the unmatched review prompt, the dictionary is the sole input to Stage 4 (Period Extraction). After results are stored to the database, the dictionary is discarded — the database is the sole source of truth.