# router

**Created**: 27-Apr-2026
**Modified**: 05-May-2026, how screens connect to each other, and what information must be passed when navigating. The router is the single source of truth for navigation. No screen constructs its own path or decides where to go independently.

---

## Shell — Bottom Tab Bar

Three persistent tabs form the app shell. The tab bar is always visible except when a push screen is active on top.

| Tab | Label (Arabic) | Root Screen |
|---|---|---|
| 1 | الإدخال | Input Screen |
| 2 | التقارير | Reports List Screen |
| 3 | الإعدادات | Settings Screen |

Switching tabs preserves each tab's navigation stack. If the user is deep in the Reports tab and switches to Settings, returning to Reports resumes where they left off.

---

## Screens and Routes

| Name | Path | Screen | Parameters |
|---|---|---|---|
| `input` | `/input` | Input Screen | — |
| `reports` | `/reports` | Reports List Screen | — |
| `report` | `/reports/:reportId` | Report Screen | `reportId` — integer, database id |
| `detail` | `/reports/:reportId/detail/:employeeName` | Detail Screen | `reportId` — integer, `employeeName` — Arabic string, percent-encoded |
| `settings` | `/settings` | Settings Screen | — |
| `column_headers` | `/settings/column-headers` | Column Header Management Screen | — |

---

## Route Details

### input — `/input`

Root of Tab 1. The starting point for file upload and report generation. No parameters.

After successful generation, the app switches to Tab 2 (Reports) and pushes the Report screen automatically. The Input tab stack is not affected.

### reports — `/reports`

Root of Tab 2. Shows the list of all generated reports ordered by generation date descending. No parameters.

After generation, the app navigates here automatically and pushes the new report on top of this screen.

### report — `/reports/:reportId`

Pushed on top of the Reports list within Tab 2. Reached two ways: automatically after generation, or by tapping a row in the Reports list.

The screen loads the full report from the database on mount using the `reportId` parameter. No pre-loading by the caller is required — the screen is self-sufficient.

Back button returns to the Reports list.

### detail — `/reports/:reportId/detail/:employeeName`

Pushed on top of the Report screen within Tab 2. Reached only by tapping an employee row on the Report screen.

Reads from the current report provider already loaded by the Report screen — no additional database fetch needed.

Arabic employee names must be percent-encoded in the URL.

Back button returns to the Report screen.

### settings — `/settings`

Root of Tab 3. Single scrollable screen with all configurable settings inline. No parameters.

### column_headers — `/settings/column-headers`

Pushed on top of the Settings screen within Tab 3. Reached by tapping the Column Headers management entry on the Settings screen.

Back button returns to the Settings screen.

---

## Navigation Flow

```
Tab 1 — Input
  └── generates report → switches to Tab 2, pushes Report Screen
                              └── taps employee → Detail Screen
                                                      └── back → Report Screen
                                                  back → Reports List

Tab 2 — Reports List
  └── taps report row → Report Screen
                              └── taps employee → Detail Screen
                                                      └── back → Report Screen
                                                  back → Reports List

Tab 3 — Settings
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
| Report Screen | Reports List |
| Detail Screen | Report Screen |
| Column Header Management | Settings Screen |

---

## Error Route

Any unmatched path shows a full-screen Arabic message: الصفحة غير موجودة. Safety net — should never appear in normal use.

---

## Later Improvements

**Deep linking to specific reports.** Routes already support it — deferred because there is no notification system in v1.
