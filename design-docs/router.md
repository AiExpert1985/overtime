# router

**Created**: 27-Apr-2026
**Modified**: 12-May-2026

---

## Shell — Bottom Tab Bar

Four persistent tabs form the app shell. The tab bar is always visible except when a push screen is active on top.

| Tab | Label (Arabic) | Root Screen |
|---|---|---|
| 1 | الموظفون | Employees Screen |
| 2 | العطل | Holidays Screen |
| 3 | التقارير | Reports List Screen |
| 4 | الإعدادات | Settings Screen |

Switching tabs preserves each tab's navigation stack.

---

## Screens and Routes

| Name | Path | Screen | Parameters |
|---|---|---|---|
| `employees` | `/employees` | Employees Screen | — |
| `holidays` | `/holidays` | Holidays Screen | — |
| `reports` | `/reports` | Reports List Screen | — |
| `report_generate` | `/reports/generate` | Report Generation Screen | — |
| `report` | `/reports/:reportId` | Report Screen | `reportId` — integer, database id |
| `detail` | `/reports/:reportId/detail/:employeeName` | Detail Screen | `reportId` — integer, `employeeName` — Arabic string, percent-encoded |
| `settings` | `/settings` | Settings Screen | — |
| `column_headers` | `/settings/column-headers` | Column Header Management Screen | — |

---

## Route Details

### employees — `/employees`

Root of Tab 1. Lists all permanent employees. Add, edit, delete operations inline.

### holidays — `/holidays`

Root of Tab 2. Lists all permanent holidays. Add, edit, delete operations inline.

### reports — `/reports`

Root of Tab 3. Shows the list of all generated reports ordered by generation datetime descending.

The floating add button in the bottom-left corner pushes the Report Generation screen.

### report_generate — `/reports/generate`

Pushed on top of the Reports List within Tab 3. Reached only from the floating add button.

Handles attendance file upload, date range selection, and employee selection. On successful generation, this screen is popped and the new Report screen is pushed in its place.

### report — `/reports/:reportId`

Pushed on top of the Reports List within Tab 3. Reached two ways: automatically after generation, or by tapping a row in the Reports List.

The screen loads the full report from the database on mount using the `reportId` parameter. No pre-loading by the caller is required.

Back button returns to the Reports List.

### detail — `/reports/:reportId/detail/:employeeName`

Pushed on top of the Report screen within Tab 3. Reached only by tapping an employee row on the Report screen.

Reads from the current report provider already loaded by the Report screen — no additional database fetch needed.

Arabic employee names must be percent-encoded in the URL.

Back button returns to the Report screen.

### settings — `/settings`

Root of Tab 4. Single scrollable screen with all configurable settings inline.

### column_headers — `/settings/column-headers`

Pushed on top of the Settings screen within Tab 4. Reached by tapping the Column Headers management entry.

Back button returns to the Settings screen.

---

## Navigation Flow

```
Tab 1 — Employees
  └── (CRUD inline, no push screens)

Tab 2 — Holidays
  └── (CRUD inline, no push screens)

Tab 3 — Reports List
  ├── floating add button → Report Generation Screen
  │                               └── success → pops generation, pushes Report Screen
  │                                                   └── taps employee → Detail Screen
  │                                                                           └── back → Report Screen
  │                                                   back → Reports List
  └── taps report row → Report Screen
                              └── taps employee → Detail Screen
                                                      └── back → Report Screen
                              back → Reports List

Tab 4 — Settings
  └── taps Column Headers → Column Header Management Screen
                                  └── back → Settings Screen
```

---

## Navigation Rules

**Always use named routes.** No screen builds a path string manually.

**Report screen loads its own data.** The Report screen fetches from the database on mount using its `reportId`. The caller navigates directly — no pre-loading required.

**Arabic names in URLs must be percent-encoded.** Use encoding when constructing the detail route path and decoding when reading back.

**Back navigation** is handled by the router's built-in stack behavior — no custom handling needed.

| From | Back goes to |
|---|---|
| Report Generation Screen | Reports List |
| Report Screen | Reports List |
| Detail Screen | Report Screen |
| Column Header Management | Settings Screen |

---

## Error Route

Any unmatched path shows a full-screen Arabic message: الصفحة غير موجودة. Safety net — should never appear in normal use.

---

## Later Improvements

**Deep linking to specific reports.** Routes already support it — deferred because there is no notification system in v1.
