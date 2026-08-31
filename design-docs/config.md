# config

**Created**: 27-Apr-2026
**Modified**: 14-May-2026

---

## Purpose

Single source of truth for all constants and configurable defaults. Every value is referenced by name — no literal values in business logic. Configurable values are managed in `screen_configuration.md` and stored in the `app_settings` table. Each configurable value has a name and an Arabic description shown as a hint to the user.

---

## Daily Employee Settings

| Key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| daily_start_time | 08:00 | بداية الدوام | وقت بداية الدوام الصباحي |
| daily_work_duration | 8 hours | ساعات الدوام | مدة يوم العمل الاعتيادي بالساعات |
| daily_max_overtime | 3 hours | اقصى وقت اضافي | أقصى عدد ساعات إضافية الممكن احتسابه للموظف في اليوم الواحد |
| daily_delay_allowance | 60 minutes | وقت السماح بالتأخير | الهامش الزمني المسموح به للموظف للحضور بعد وقت البداية في أيام العمل الاعتيادية |

End time is derived: `daily_start_time + daily_work_duration`. Not a stored setting.

---

## Shift Employee Settings

| Key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| shift_start_times | [08:00] | بداية المناوبة | قائمة الأوقات المحتملة لبداية المناوبة ممكن ادخال اكثر من وقت |
| shift_duration | 24 hours | مدة المناوبة | المدة الكاملة للمناوبة الواحدة بالساعات |
| shift_zone_interval | 6 hours | عدد ساعات كل بصمة | الوقت المسموح به للبصمات خلال المناوبة الواحدة |
| shift_edge_tolerance | 30 minutes | سماحية بصمة الدخول والخروج | الهامش الزمني بالدقائق المسموح به لبصمة بداية المناوبة ونهايتها |
| shift_inner_tolerance | 120 minutes | سماحية البصمات الداخلية | الهامش الزمني بالدقائق المسموح به لبصمات التحقق خلال المناوبة |
| shift_duration_tolerance | 60 minutes | سماحية مدة المناوبة | الهامش الزمني بالدقائق المسموح به للنقص في مدة الحضور الفعلية عن مدة المناوبة |
| shift_baseline_hours | 154 hours | ساعات العمل الأساسية | عدد ساعات العمل الشهرية المطلوبة |
| shift_ceiling_hours | 192 hours | الحد الأقصى للساعات الشهرية | أقصى عدد ساعات عمل يُحتسب في الشهر، اي ساعات اكثر منه تهمل و لا تدخل في حساب الساعات الاضافية |

---

## Display Settings

| Key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| rounding_mode | quarter | وضع التقريب | طريقة عرض الساعات الإضافية: بدون تقريب، تقريب لربع ساعة، نصف ساعة, أو تقريب لساعة كاملة |
| max_report_date_range | 32 days | الحد الأقصى لمدة التقرير | الحد الأقصى لعدد الأيام المسموح بها في نطاق التاريخ عند توليد تقرير |

Rounding options: `none` / `quarter` / `half` / `hour`. Applied at display time only — stored values are always raw minutes.

---

## Tolerance Constraint

`shift_edge_tolerance` and `shift_inner_tolerance` must each be ≤ `shift_zone_interval / 2`.

A zone's validity window must never reach outside its own bucket. If it did, a timestamp could satisfy one zone's window while belonging to a neighbouring zone's bucket, breaking the one-timestamp-one-zone model. The narrowest bucket half-width is `shift_zone_interval / 2`, so both tolerances are capped there — the constraint applies to both equally.

Enforced in two places:

- **Config time** — `screen_configuration.md` blocks any edit to `shift_zone_interval`, `shift_edge_tolerance`, or `shift_inner_tolerance` that would violate it, and reports the allowed maximum.
- **Generation time** — re-checked before the pipeline runs, as defence in depth in case settings were altered outside the validated flow. Violation aborts generation with an Arabic error, consistent with `main_workflow.md` — no partial results stored.

---

## Hardcoded Constants

These values are fixed in code and not user-configurable.

| Key | Value | Used in |
|---|---|---|
| off_day_threshold | 25% | `off_day_detection.md` — minimum attendance rate below which a day is classified as off |
| detection_edge_tolerance | 120 minutes | `schedule_detection.md` — edge tolerance used by classification only, never by overtime validity |

`detection_edge_tolerance` is deliberately wider than `shift_edge_tolerance` and deliberately not user-configurable. Classification asks "does this person work shifts?", which a punch 90 minutes off the mark still answers yes to; overtime validity asks "did this period meet the rules?", which it does not. Keeping them separate means editing `shift_edge_tolerance` changes who earns overtime without changing who is classified as a shift worker.

---

## Default Column Headers

Seeded on first launch. Cannot be deleted or edited. Additional values added via `screen_configuration.md`. Only the attendance file has configurable column headers.

### Attendance File

| Field key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| employee_name | اسم الموظف | عمود اسم الموظف | اسم العمود الذي يحتوي على أسماء الموظفين في ملف الحضور |
| department | القسم | عمود القسم | اسم العمود الذي يحتوي على قسم الموظف في ملف الحضور |
| datetime | التاريخ والوقت | عمود التاريخ والوقت | اسم العمود الذي يحتوي على تاريخ ووقت البصمة معاً |
