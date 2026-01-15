# Overtime Calculation System — Domain Contracts

**Status:** Frozen
**Date:** 2026-01-15

---

## System Identity

### What It Is

- Read-only overtime calculator for employees based on uploaded Excel files (attendance, target employees, holidays)
- Calculates overtime for completed time periods using employment-type-specific rules
- Stores calculation results as immutable snapshots in local SQLite database
- Each calculation is identified by generation date; recalculating on same date overwrites previous

### What It Is NOT

- Not a payroll system
- Not an approval workflow system
- Not an attendance correction/editing tool
- Not a real-time monitoring system

### Users

HR staff or administrators who upload files after month ends and generate overtime reports

### Core Promise

Given identical input files and date range, produce bitwise identical overtime calculations every time, with no randomness, timestamps, or external dependencies.

---

## Business Invariants

### Eligibility & Identity

**Contract 1: Only Target Employees Eligible**
Only employees listed in Target Employees file are calculated. Attendance for non-target employees is completely ignored.

**Contract 2: Exact Name Matching**
Employee names must match 100% exactly (case-sensitive, whitespace-sensitive) between attendance and target employee files.

**Contract 3: Single Employment Type**
Each employee has exactly one employment type (Shift or Daily) per calculation period. Cannot change mid-month.

---

### Data Integrity

**Contract 4: Fingerprints Are Source of Truth**
Fingerprint records are immutable and cannot be modified or deleted. They are the authoritative data source.

**Contract 5: Calculation Determinism**
Given identical input files + date range, overtime calculation produces bitwise identical results every time. No randomness, no timestamps, no external dependencies.

**Contract 6: 10-Minute Deduplication**
Fingerprints ≤10 minutes apart are treated as one (keep first). Works across midnight based on duration, not calendar boundaries. Applied FIRST before any other validation.

---

### Shift Employee Rules

**Contract 7: Minimum Fingerprint Spacing Rule**
After 10-min deduplication, apply spacing filter:
- Start with first fingerprint
- Ignore all fingerprints within SHIFT_MIN_GAP_HOURS from previous valid fingerprint
- Next valid fingerprint = first one after SHIFT_MIN_GAP_HOURS
- Repeat until all fingerprints processed
- SHIFT_MIN_GAP_HOURS = 3 hours (default, configurable)
- Purpose: Ensures fingerprints spread throughout shift, not clustered

**Contract 8: Shift Valid Day Conditions**
Both required after deduplication and spacing filter:
- ≥5 valid spaced fingerprints
- Time span (last valid - first valid): ≥ SHIFT_MIN_HOURS with tolerance
- If either fails → entire day invalid and ignored

**Contract 9: Shift Hour Span with Tolerance**
- Minimum span = SHIFT_MIN_HOURS (24 hours default)
- Allowed tolerance = SHIFT_HOUR_TOLERANCE (1 hour default, configurable)
- Valid if: span ≥ (SHIFT_MIN_HOURS - SHIFT_HOUR_TOLERANCE)

**Contract 10: Shift Daily Hours**
`last_valid_fingerprint - first_valid_fingerprint`

**Contract 11: Shift Monthly Overtime**
- Total Hours = sum of all valid daily hours
- Overtime = max(0, Total Hours - SHIFT_BASELINE_HOURS)
- SHIFT_BASELINE_HOURS = 154 hours (default, configurable)
- **Baseline is FIXED regardless of:**
  - Month length (28, 29, 30, or 31 days)
  - Days off taken by employee
  - Actual working days in the month
- Result rounded to nearest hour

**Contract 12: Shift Work Span**
Shift work always spans exactly 2 consecutive calendar days, never 3+

---

### Daily Employee Rules — Regular Workdays

**Contract 13: Morning Fingerprint Mandatory**
- Fingerprint before DAILY_MORNING_CUTOFF required on regular workdays
- DAILY_MORNING_CUTOFF = 09:00 (default, configurable)
- If missing → entire day invalid

**Contract 14: Regular Workday Overtime**
- 1 fingerprint → invalid (ignored)
- 2+ fingerprints → `overtime = max(0, last_fingerprint - 15:00)`
- Use absolute first and absolute last of the day

---

### Daily Employee Rules — Holidays/Weekends

**Contract 15: Holiday/Weekend Definition**
Fridays, Saturdays, and dates in official holidays file

**Contract 16: Holiday Overtime**
- Morning fingerprint NOT required
- 1 fingerprint → invalid (ignored)
- 2+ fingerprints → `overtime = last_fingerprint - first_fingerprint`
- Use absolute first and absolute last of the day

**Contract 17: Daily Monthly Overtime**
`Regular_OT + Holiday_OT`, rounded to nearest hour

---

### System-Wide Rules

**Contract 18: Rounding Rule**
Minutes 00-29 → round down, 30-59 → round up

**Contract 19: Month Definition**
Calendar month (1st to last day of month)

**Contract 20: Date Range Scope**
Calculation window is [Start_Date 00:00, End_Date 23:59]. Records outside ignored.

**Contract 21: Report Uniqueness**
One report per `generation_date` (unique key). Latest overwrites previous on same date.

**Contract 22: File Validation Requirements**
- Required columns (matching template names exactly) must exist
- Extra columns allowed
- Missing required columns → validation error, no import

**Contract 23: Error Handling - Attendance**
Missing/malformed data in attendance sheet is ignored (row level)

**Contract 24: Error Handling - Target/Holidays**
Missing data in target employees or holidays files → validation error, blocks calculation

**Contract 25: Database Integrity**
Only completed, error-free calculations saved to database. Validation errors prevent DB write.

**Contract 26: Zero Attendance Notification**
If zero attendance logs found in selected date range → notify user (possible wrong range or wrong file)

**Contract 27: Read-Only Architecture**
System never modifies uploaded files. Input files NOT stored, only calculated results stored.

---

## Safety-Critical Rules

**Data Quality Risk: Name Matching Strictness**
100% exact matching (case, whitespace) could cause legitimate employees to appear as "unmatched" due to minor data entry variations (extra space, Arabic character variants like hamza).

**Audit Trail Risk: Report Overwrite**
Recalculating on same generation_date completely overwrites previous report with no versioning or audit trail.

**Data Quality Risk: Silent Row Ignoring**
Malformed attendance rows silently ignored - could mask data quality issues and lead to incorrect totals.

**Business Logic Risk: Fixed Baseline Regardless of Absences**
Shift employees compared against 154 hours even if they took days off - could be perceived as unfair, but this is an intentional business rule for consistency.

**Validation Risk: Fingerprint Spacing Filter**
The 3-hour minimum gap rule is powerful but could invalidate legitimate days if employee had valid reasons for clustered fingerprints (emergencies, system errors, etc.). No override mechanism exists.

---

## Explicit Non-Goals

- No payroll or salary calculation
- No approval workflows
- No manual corrections or attendance editing
- No adjustment for days off or absences
- No real-time calculations (always historical)
- No user authentication/authorization
- No multi-user concurrency handling

---

## Open Questions

None — all critical aspects clarified during discovery.
