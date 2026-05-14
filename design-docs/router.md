# router

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Shell — Bottom Tab Bar

Two persistent tabs form the app shell. The tab bar is always visible except when a push screen is active on top.

| Tab | Label (Arabic) | Root Screen |
|---|---|---|
| 1 | التقارير | Reports List Screen |
| 2 | الإعدادات | Settings Screen |

Switching tabs preserves each tab's navigation stack.

---

## Screens and Routes

| Name | Path | Screen | Parameters |
|---|---|---|---|
| `reports` | `/reports` | Reports List Screen | — |
| `report_generate` | `/reports/generate` | Report Generation Screen | — |
| `report` | `/reports/:reportId` | Report Screen | `reportId` — integer, database id |
| `detail` | `/reports/:reportId/detail/:employeeType/:employeeResultId` | Detail Screen | `reportId` — integer, `employeeType` — 'shift' or 'daily', `employeeResultId` — integer, database id of the employee result row |
| `settings` | `/settings` | Settings Screen | — |
| `column_headers` | `/settings/column-headers` | Column Header Management Screen | — |

---

## Route Details

### reports — `/reports`

Root of Tab 1. Shows the list of all generated reports ordered by generation datetime descending.

The floating add button in the bottom-left corner pushes the Report Generation screen.

### report_generate — `/reports/generate`

Pushed on top of the Reports List within Tab 1. Reached only from the floating add button.

Handles attendance file upload and date range selection. No employee selection step — employees are detected from the file. On successful generation, this screen is popped and the new Report screen is pushed in its place.

### report — `/reports/:reportId`

Pushed on top of the Reports List within Tab 1. Reached two ways: automatically after generation, or by tapping a row in the Reports List.

Loads shift and daily employee results from the database on mount. Computes all summaries live from the loaded rows. No pre-loading by the caller is required.

Back button returns to the Reports List.

### detail — `/reports/:reportId/detail/:employeeType/:employeeResultId`

Pushed on top of the Report screen within Tab 1. Reached only by tapping an employee row.

Fetches period details from the database on mount using `employeeResultId` — the database id of the employee result row. `employeeType` determines which period table to query (`shift_period_details` or `daily_period_details`).

Back button returns to the Report screen.

### settings — `/settings`

Root of Tab 2. Single scrollable screen with all configurable settings inline.

### column_headers — `/settings/column-headers`

Pushed on top of the Settings screen within Tab 2. Reached by tapping the Column Headers management entry.

Back button returns to the Settings screen.

---

## Navigation Flow

```
Tab 1 — Reports List
  ├── floating add button → Report Generation Screen
  │                               └── success → pops generation, pushes Report Screen
  │                                                   └── taps employee → Detail Screen
  │                                                                           └── back → Report Screen
  │                                                   back → Reports List
  └── taps report row → Report Screen
                              └── taps employee → Detail Screen
                                                      └── back → Report Screen
                              back → Reports List

Tab 2 — Settings
  └── taps Column Headers → Column Header Management Screen
                                  └── back → Settings Screen
```

---

## Navigation Rules

**Always use named routes.** No screen builds a path string manually.

**Report screen loads its own data.** Fetches employee results from the database on mount using `reportId`. Caller navigates directly — no pre-loading required.

**Detail screen fetches its own periods.** Uses `employeeResultId` from the route parameter to query only that employee's period rows from the correct table. The Report screen does not preload periods.

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
