# Technical Memory — Overtime Calculation System

**Purpose:** Technical decisions and knowledge that cannot be reliably inferred from code.

**Status:** Active
**Last Updated:** 2026-01-15

---

## Stack & Platform

**Platform:** Flutter + SQLite (local database, no server)

**Why:** Simple deployment, read-only snapshot model doesn't require server infrastructure. Suitable for single-user desktop application with local data storage.

**Key Packages:**
- `sqflite` - Database
- `excel` - Excel parsing
- `file_picker` - File uploads
- `intl` - Arabic date/number formatting

---

## Configurable Business Rule Variables

These constants control business logic and must be centrally defined (not hardcoded throughout codebase):

```
SHIFT_BASELINE_HOURS = 154          # Overtime baseline for shift employees
SHIFT_MIN_HOURS = 24                # Minimum shift duration
SHIFT_HOUR_TOLERANCE = 1            # Allowed deviation from minimum hours
SHIFT_MIN_GAP_HOURS = 3             # Minimum gap between valid fingerprints
DAILY_MORNING_CUTOFF = 09:00        # Morning fingerprint deadline for daily employees
```

**Why:** Business rules may evolve. Centralized configuration prevents scattered hardcoded values and enables future changes without code surgery.

---

## Fingerprint Processing Pipeline

**Two-Phase Filtering for Shift Employees:**

1. **Phase 1: 10-minute deduplication**
   - Keeps first within 10-min window
   - Removes accidental duplicate scans

2. **Phase 2: Minimum gap spacing filter**
   - Keeps first after MIN_GAP_HOURS from previous valid
   - Ensures legitimate spread throughout shift

**Why Phase 2 Exists:**
After deduplication, we need to verify fingerprints are genuinely distributed across the shift (not just 5 scans in first hour). The 3-hour gap ensures legitimate presence throughout the work period.

---

## Data Handling Decisions

**Fingerprint Sorting on Import:**
Attendance Excel must be sorted chronologically by timestamp when first imported, before calculations begin.

**Why:** Ensures "first" and "last" fingerprint logic works correctly. Cannot rely on Excel row order.

**Date Format Flexibility:**
Support all known date formats (DD/MM/YYYY, YYYY-MM-DD, etc.) as long as parseable.

**Why:** Different Excel sources may use different formats; reduces user friction and import errors.

**Next-Day Detection:**
Determine if fingerprint is next day using timestamp's date component, not just time.

**Why:** Handles overnight shifts spanning midnight. Time alone cannot distinguish 10:00 AM Day 1 from 10:00 AM Day 2.

**No Input File Storage:**
Don't store uploaded Excel files, only calculated results.

**Why:** Reduces storage footprint. Calculation is deterministic, so files can be re-uploaded if needed for recalculation.

---

## Database Schema

```
reports:
  - generation_date (UNIQUE key)
  - date_range_start, date_range_end
  - total_employees, total_overtime_hours
  - unmatched_employee_count

employee_results:
  - FK to reports
  - employee_name, employment_type, department
  - total_overtime_hours, has_attendance, notes

daily_details:
  - FK to employee_results
  - date, weekday
  - first_fingerprint, last_fingerprint
  - all_fingerprints (JSON)
  - is_valid, overtime_hours_raw, notes
```

**Why This Structure:**
One-to-many hierarchy (reports → employees → daily details) supports:
- Drill-down UI navigation
- Historical queries
- Atomic report storage (all data for one calculation stored together)

---

## Performance Considerations

**Use `compute()` for Large Files:**
Process large Excel files in isolates.

**Why:** Prevents UI freezing during calculation. Excel parsing and overtime calculation can be CPU-intensive for large datasets.

---

## UI/UX Technical Decisions

**Arabic/RTL Layout:**
All UI in Arabic, right-to-left layout, Arabic numerals.

**Why:** Target users are Arabic speakers. RTL support must be built into layout from the start, not retrofitted.

**Color Coding:**
- Green rows = valid days
- Red rows = invalid days (with reason in notes column)
- Red background = unmatched employees

**Why:** Quick visual distinction without reading every detail cell.

**Time Display Format:**
`HH:MM` or `HH:MM+1` for next-day times, `-` for missing.

**Why:** Clear indication of overnight work without cluttering UI with full dates.

**Template Download Links:**
Provide downloadable Excel templates in app.

**Why:** Reduces file format errors by providing exact required structure. Users can fill templates rather than guessing column names.

---

## Required Commands

(To be filled during implementation phase)

**Build:**
```
(TBD)
```

**Run:**
```
(TBD)
```

**Test:**
```
(TBD)
```

---

## Constraints & Conventions

**Language:** Arabic (RTL)
**Platform Target:** Desktop (Linux/Windows/macOS via Flutter)
**Deployment:** Local installation, no network dependency
**Data Persistence:** SQLite only, no cloud sync

---

## Decision Rationale Summary

| Decision | Why |
|----------|-----|
| Local SQLite (no server) | Simpler deployment, suitable for read-only snapshot model |
| Two-phase fingerprint filtering | Phase 1 removes duplicates, Phase 2 ensures legitimate shift coverage |
| Configurable rule constants | Business rules may change; centralized config enables easy updates |
| No input file storage | Deterministic calculation means files can be re-uploaded if needed |
| JSON for all_fingerprints | Flexible storage for variable-length arrays without schema changes |
| compute() for large files | Prevents UI freezing during calculation |
| Arabic/RTL from start | Retrofitting RTL is costly; design for it from beginning |
