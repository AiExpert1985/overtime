# Project Backlog — Overtime Calculation System

**Purpose:** System requirements and implementation details extracted from discovery.

**Date:** 2026-01-15

---

## System Requirements

### 1. Required Inputs

#### 1.1 Attendance Files

- **Format:** Excel (.xlsx, .xls), multiple files/sheets allowed
- **Required columns (Arabic):** اسم الموظف, التاريخ, وقت الدخول, وقت الخروج
- **Validation:** Must match predefined template structure
- **Column matching:** System checks uploaded files against template column names
  - Missing required columns → error, block import
  - Extra columns allowed

#### 1.2 Target Employees File

- **Required columns:** اسم الموظف, نوع التوظيف (مناوب/صباحي), القسم
- **Employment types:** Exactly two types allowed: Shift (مناوب) or Daily (صباحي)
- **Purpose:** Defines eligible employees and their type
- **Missing data:** Not allowed, validation error blocks calculation

#### 1.3 Holidays File

- **Required columns:** التاريخ, مناسبة العطلة
- **Purpose:** Official holidays for Daily employees only
- **Missing data:** Not allowed, validation error blocks calculation

#### 1.4 Date Range

- Start Date and End Date (calendar picker)
- Calculation window: Start 00:00 to End 23:59
- Records outside date range are ignored

---

### 2. Calculation Specifications

#### 2.1 Shift Employee Calculation

**Valid Day Conditions:**

After 10-minute deduplication and minimum gap spacing filter:
- ≥ 5 valid spaced fingerprints
- Time span (last - first) ≥ 24 hours (with 1-hour tolerance by default)

**10-Minute Deduplication:**
- If multiple fingerprints within 10 minutes, keep only the first
- Works across midnight based on duration (≤10 minutes = duplicate)

**Minimum Gap Spacing Filter:**
- Start with first fingerprint
- Ignore all fingerprints within 3 hours (configurable) from previous valid
- Next valid fingerprint = first one after 3-hour gap
- Ensures fingerprints distributed throughout shift, not clustered

**Daily Hours Calculation:**
```
Hours = Last Valid Fingerprint - First Valid Fingerprint
```

**Monthly Overtime Calculation:**
```
Total Hours = Σ(all valid daily hours)
Overtime = max(0, Total Hours - 154)
Round to nearest hour
```

**Invalid Days (ignored):**
- < 5 valid spaced fingerprints after filtering, OR
- Time span < 24 hours (minus tolerance)

**Notes:**
- Shift work spans exactly 2 consecutive calendar days
- 154-hour baseline is fixed regardless of month length or days off
- Multiple work periods: If fingerprints span beyond one shift cycle, calculate total span from first to last fingerprint as long as ≥5 valid spaced fingerprints exist

---

#### 2.2 Daily Employee Calculation

**Morning Fingerprint Requirement (Regular Workdays):**
- Must have fingerprint before 09:00 (configurable)
- If missing → entire day invalid

**Regular Workdays:**
- **1 fingerprint:** Invalid (ignored)
- **2+ fingerprints:** `Overtime = max(0, Last FP - 15:00)`
- Use absolute first and absolute last of the day
- All intermediate fingerprints ignored

**Holidays/Weekends (Fridays, Saturdays, Official Holidays):**
- **Morning fingerprint NOT required**
- **1 fingerprint:** Invalid (ignored)
- **2+ fingerprints:** `Overtime = Last FP - First FP`
- Use absolute first and absolute last of the day

**Monthly Overtime:**
```
Total = Regular Workday Overtime + Holiday Overtime
Round to nearest hour
```

---

#### 2.3 Rounding Rules

| Minutes | Result |
|---------|--------|
| .00-.29 | Round down |
| .30-.59 | Round up |

**Examples:**
- 10h 15m → 10h
- 10h 45m → 11h

---

### 3. User Interface Specifications

#### 3.1 Input Screen

**Components:**
- File upload widgets for:
  - Attendance files (one or more)
  - Target Employees file (one)
  - Holidays file (one)
- Template download links for each file type
- Date range pickers (Start Date, End Date)
- Generate Report button

**Behavior:**
- Generate Report button disabled until all files valid
- Clear error messages if invalid
- All files required before generation

**Validation Feedback:**
- Show validation status per file
- Display specific error messages (see section 4)

---

#### 3.2 Output Screen (Main Report)

**Summary Section:**
- Total employees (count)
- Total overtime hours (sum)
- Count of unmatched employees
- Start date
- End date

**Employee Table:**

| اسم الموظف | القسم | ساعات الإضافي | ملاحظات |
|------------|-------|---------------|---------|
| ...        | ...   | ...           | [عرض التفاصيل] |

**Sorting:**
- Descending by overtime hours
- Unmatched employees at bottom with red background

**Row Colors:**
- Normal rows: default background
- Unmatched employees: red background

**Actions:**
- Click row → navigate to Employee Detail screen
- History button → navigate to Past Reports screen
- Export Excel button → generate Excel file of current report

---

#### 3.3 Employee Detail Screen

**Header:**
- Employee name
- Employment type (Shift/Daily)
- Department
- Total overtime hours
- Start date
- End date

**Daily Table:**

| التاريخ | اليوم | الدخول | الخروج | البصمات | ملاحظات |
|---------|-------|--------|--------|---------|---------|
| 01/12   | الأحد | 08:00  | 10:00+1 | 08:00<br>12:00<br>18:00<br>22:00<br>10:00+1 | 26 ساعة |

**Color Coding:**
- Green row: Valid day
- Red row: Invalid day (with reason in notes column)

**Time Format:**
- `HH:MM` for same-day times
- `HH:MM+1` for next-day times
- `-` if missing

**Fingerprints Column (البصمات):**
- List all fingerprints for the day
- Multi-line display
- Format: `HH:MM` or `HH:MM+1`

**Notes Column (ملاحظات):**
- For valid days: show hours worked (e.g., "26 ساعة")
- For invalid days: show reason (see section 4)

---

#### 3.4 Past Reports Screen (History)

**List of Reports:**
- Sorted by generation date (newest first)
- Show generation date, date range, total employees, total overtime

**Actions:**
- Click report → load and display as Main Report
- No recalculation, display stored results

---

### 4. Validation & Error Messages

#### 4.1 File Validation Errors

| Error Condition | Message (Arabic) |
|-----------------|------------------|
| Missing attendance file | "يرجى تحميل ملف حضور" |
| Missing target employees file | "يرجى تحميل ملف الموظفين المستهدفين" |
| Missing holidays file | "يرجى تحميل ملف العطل الرسمية" |
| Invalid file format / column mismatch | "الملف لا يتطابق مع القالب المطلوب" |
| Invalid date range | "تاريخ البداية يجب أن يكون قبل تاريخ النهاية" |

#### 4.2 Invalid Day Notes (Arabic)

| Scenario | Notes Text |
|----------|-----------|
| Shift: < 5 valid spaced fingerprints | "عدد البصمات أقل من 5" |
| Shift: < 24h span (after tolerance) | "الفترة الزمنية أقل من 24 ساعة" |
| Daily: No morning fingerprint | "لا توجد بصمة صباحية (قبل 9 صباحاً)" |
| Daily: Only 1 fingerprint | "بصمة واحدة فقط" |

#### 4.3 Unmatched Employees

**Display:**
- Appear at bottom of employee table
- Red background
- Notes: "لم يتم العثور على سجلات للحضور, يجب التحقق من صحة الاسم"

**Cause:**
- Employee in target file but no attendance records found in selected date range
- Could indicate: wrong date range selected, wrong attendance file, or name mismatch

#### 4.4 Zero Attendance Notification

**Condition:** Zero attendance logs found in selected date range

**Action:** Notify user with message suggesting possible wrong range or wrong file uploaded

---

### 5. Database Schema

#### 5.1 Table: reports

```sql
CREATE TABLE reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  generation_date TEXT UNIQUE NOT NULL,
  date_range_start TEXT NOT NULL,
  date_range_end TEXT NOT NULL,
  total_employees INTEGER NOT NULL,
  total_overtime_hours REAL NOT NULL,
  unmatched_employee_count INTEGER NOT NULL
);
```

#### 5.2 Table: employee_results

```sql
CREATE TABLE employee_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  report_id INTEGER NOT NULL,
  employee_name TEXT NOT NULL,
  employment_type TEXT NOT NULL,
  department TEXT NOT NULL,
  total_overtime_hours REAL NOT NULL,
  has_attendance BOOLEAN NOT NULL,
  notes TEXT,
  FOREIGN KEY (report_id) REFERENCES reports(id)
);
```

#### 5.3 Table: daily_details

```sql
CREATE TABLE daily_details (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  employee_result_id INTEGER NOT NULL,
  date TEXT NOT NULL,
  weekday TEXT NOT NULL,
  first_fingerprint TEXT,
  last_fingerprint TEXT,
  all_fingerprints TEXT,  -- JSON array
  is_valid BOOLEAN NOT NULL,
  overtime_hours_raw REAL,
  notes TEXT,
  FOREIGN KEY (employee_result_id) REFERENCES employee_results(id)
);
```

**Report Versioning:**
- `generation_date` is unique key
- Latest report on same date overwrites previous
- No versioning or audit trail for overwrites

---

### 6. Edge Cases & Special Behaviors

| Scenario | Behavior |
|----------|----------|
| Employee in attendance, not in target file | Ignore completely (not calculated) |
| Employee in target file, no attendance | Show at bottom with red background as "unmatched" |
| Multiple fingerprints same timestamp | Apply 10-minute deduplication |
| Last fingerprint before 3 PM (Daily employee, regular day) | Overtime = 0 |
| Shift total hours < 154 | Overtime = 0 |
| Attendance records outside date range | Ignore |
| Exactly 10 minutes between fingerprints | Considered duplicate, keep first |
| Two fingerprints ≤10 min across midnight | Deduplicate based on duration |
| Malformed time cell in attendance | Ignore row silently |
| Missing data in target employees or holidays | Validation error, block import |

---

### 7. Sample Calculations

#### 7.1 Shift Employee Example

```
Valid days after deduplication and spacing filter:
Day 1: 26h (5 valid FPs, 26h span) ✓
Day 2: Invalid (4 valid FPs after spacing) ✗
Day 3: 25h (5 valid FPs, 25h span) ✓
Day 4: Invalid (5 valid FPs, 23h span) ✗
Day 5: 27h (6 valid FPs, 27h span) ✓
...

Total: 308h
Overtime: 308 - 154 = 154h
```

#### 7.2 Daily Employee Example

```
Regular workdays:
Dec 1: Morning ✓, Last 17:00 → 2h
Dec 2: Morning ✓, Last 18:30 → 3.5h
Dec 3: No morning → Invalid ✗
Dec 4: Morning ✓, Last 14:00 → 0h
Regular OT: 5.5h

Holidays/Weekends:
Dec 6 (Fri): 10:00-16:00 → 6h
Dec 7 (Sat): 09:00-13:00 → 4h
Holiday OT: 10h

Total: 15.5h → Rounded to 16h
```

---

### 8. Excel Templates

**Note:** Downloadable in app

#### 8.1 Attendance Template

| اسم الموظف | التاريخ | وقت الدخول | وقت الخروج |
|------------|---------|-----------|-----------|

#### 8.2 Target Employees Template

| اسم الموظف | نوع التوظيف | القسم |
|------------|-------------|-------|

#### 8.3 Holidays Template

| التاريخ | مناسبة العطلة |
|---------|--------------|

---

### 9. Testing Checklist

**Calculation Tests:**
- [ ] Shift: 5 valid spaced FPs, 24h → Valid
- [ ] Shift: 4 valid FPs after spacing → Invalid
- [ ] Shift: 5 valid FPs, 23h span → Invalid (or valid if within tolerance)
- [ ] Shift: 10-min deduplication works correctly
- [ ] Shift: 3-hour spacing filter works correctly
- [ ] Shift: Fingerprints spanning 3 days handled correctly
- [ ] Daily: Morning FP, last 5 PM → 2h OT
- [ ] Daily: No morning FP → Invalid
- [ ] Daily: Holiday with 2 FPs → Calculate span
- [ ] Daily: Only 1 FP → Invalid
- [ ] Rounding: 10h 15m → 10h
- [ ] Rounding: 10h 45m → 11h

**UI Tests:**
- [ ] RTL layout displays correctly
- [ ] Arabic text and numerals display correctly
- [ ] Red rows at bottom for unmatched employees
- [ ] Green/red rows in detail view
- [ ] Time format shows +1 for next day correctly
- [ ] History loads past reports
- [ ] Export generates valid Excel

**Validation Tests:**
- [ ] Generate button blocked when files missing
- [ ] Error for invalid Excel format
- [ ] Error for missing required columns
- [ ] Error for invalid date range
- [ ] Error for missing data in target employees file
- [ ] Error for missing data in holidays file
- [ ] Silent ignore for malformed attendance rows
- [ ] Zero attendance notification appears correctly

**Database Tests:**
- [ ] Report generation_date is unique
- [ ] Latest report overwrites previous on same date
- [ ] Validation errors prevent database write
- [ ] All relationships (FK) work correctly

---

### 10. Implementation Notes

**RTL Support:**
All UI elements must support right-to-left layout. This includes:
- Text alignment
- Layout direction
- Icons and navigation flow

**Arabic Display:**
Use Arabic numerals and text throughout. Ensure proper font rendering.

**Performance:**
Use `compute()` for large file processing to prevent UI freezing.

**File Storage:**
Input files NOT stored in database, only calculated results stored.

**Report Identity:**
Generation date is unique key. Recalculating on same date replaces previous report completely.

---

## Remaining Tasks

### Phase 1: Core Implementation
- [ ] Set up Flutter project structure
- [ ] Implement SQLite database schema
- [ ] Create Excel template files
- [ ] Implement Excel file parser with column validation
- [ ] Implement 10-minute deduplication logic
- [ ] Implement minimum gap spacing filter for Shift employees
- [ ] Implement Shift employee calculation logic
- [ ] Implement Daily employee calculation logic
- [ ] Implement rounding logic
- [ ] Implement date range filtering

### Phase 2: UI Implementation
- [ ] Implement Input Screen with file pickers
- [ ] Implement file validation feedback
- [ ] Implement Main Report screen with employee table
- [ ] Implement Employee Detail screen with daily table
- [ ] Implement Past Reports (History) screen
- [ ] Implement Excel export functionality
- [ ] Implement RTL layout support
- [ ] Implement Arabic text rendering

### Phase 3: Error Handling & Validation
- [ ] Implement all validation error messages (Arabic)
- [ ] Implement unmatched employee handling
- [ ] Implement invalid day notes (Arabic)
- [ ] Implement zero attendance notification
- [ ] Implement malformed data handling

### Phase 4: Testing
- [ ] Write unit tests for calculation logic
- [ ] Write unit tests for deduplication
- [ ] Write unit tests for spacing filter
- [ ] Write unit tests for rounding
- [ ] Write integration tests for end-to-end flow
- [ ] Write UI tests for all screens
- [ ] Test with sample data files

### Phase 5: Polish
- [ ] Add template download functionality
- [ ] Optimize performance for large files
- [ ] Ensure proper Arabic/RTL rendering across all screens
- [ ] Final testing with real-world data

---

> **This file is for human reference only and has NO authority.**
> **Only contracts, frozen tasks, and code define system behavior.**
