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
| shift_tolerance | 60 minutes | دقائق السماح للبصمة | الهامش الزمني بالدقائق المسموح به لجميع البصمات في المناوبة |
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

## Hardcoded Constants

These values are fixed in code and not user-configurable.

| Key | Value | Used in |
|---|---|---|
| off_day_threshold | 25% | `off_day_detection.md` — minimum attendance rate below which a day is classified as off |

---

## Default Column Headers

Seeded on first launch. Cannot be deleted or edited. Additional values added via `screen_configuration.md`. Only the attendance file has configurable column headers.

### Attendance File

| Field key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| employee_name | اسم الموظف | عمود اسم الموظف | اسم العمود الذي يحتوي على أسماء الموظفين في ملف الحضور |
| department | القسم | عمود القسم | اسم العمود الذي يحتوي على قسم الموظف في ملف الحضور |
| datetime | التاريخ والوقت | عمود التاريخ والوقت | اسم العمود الذي يحتوي على تاريخ ووقت البصمة معاً |
