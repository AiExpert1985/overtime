# config

**Created**: 27-Apr-2026
**Modified**: 12-May-2026

---

## Purpose

Single source of truth for all constants and configurable defaults. Every value is referenced by name — no literal values in business logic. Configurable values are managed in `screen_configuration.md` and stored in the `app_settings` table. Each configurable value has a name and an Arabic description shown as a hint to the user.

---

## Daily Employee Settings

| Key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| daily_start_time | 09:00 | وقت البداية | وقت بداية الدوام الصباحي. يُستخدم لأمرين: التحقق من أن البصمة الأولى لا تتجاوزه في أيام العمل الاعتيادية، واحتساب وقت النهاية تلقائياً (وقت البداية + مدة الدوام) |
| daily_work_duration | 8 hours | مدة الدوام | مدة يوم العمل الاعتيادي بالساعات. يُحسب وقت النهاية تلقائياً من وقت البداية + المدة |
| daily_max_overtime | 3 hours | الحد الأقصى للإضافي اليومي | أقصى عدد ساعات إضافية يُحتسب في اليوم الواحد، سواء كان يوم عمل أو عطلة |

End time is derived: `daily_start_time + daily_work_duration`. Not a stored setting.

---

## Shift Employee Settings

| Key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| shift_start_times | [08:00] | أوقات بداية المناوبة | قائمة الأوقات المحتملة لبداية المناوبة. يختلف وقت البداية من موظف لآخر — يبحث المستخرج عن أول وقت مطابق لأي من هذه القيم ليجعله نقطة البداية الثابتة لذلك الموظف |
| shift_duration | 24 hours | مدة المناوبة | المدة الكاملة للمناوبة الواحدة بالساعات |
| shift_zone_interval | 6 hours | فترة نقاط التحقق | المسافة الزمنية بين كل نقطة تحقق والأخرى. عدد النقاط = مدة المناوبة ÷ هذه الفترة |
| shift_start_end_tolerance | 30 minutes | هامش البداية والنهاية | الهامش الزمني بالدقائق المسموح به لبصمتي البداية والنهاية |
| shift_inner_tolerance | 60 minutes | هامش النقاط الداخلية | الهامش الزمني بالدقائق المسموح به للبصمات في نقاط التحقق الداخلية |
| shift_period_gap | 6 hours | نافذة الكشف عن فترة جديدة | المدة التي يُبحث خلالها عن بصمة بداية الفترة التالية بعد نهاية الفترة الحالية |
| shift_baseline_hours | 154 hours | ساعات العمل الأساسية | عدد ساعات العمل الشهرية قبل احتساب الإضافي |
| shift_ceiling_hours | 192 hours | الحد الأقصى للساعات الشهرية | أقصى عدد ساعات عمل يُحتسب في الشهر، بغض النظر عن عدد الفترات الصالحة |

---

## Display Settings

| Key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| rounding_mode | quarter | وضع التقريب | طريقة عرض الساعات الإضافية: بدون تقريب، تقريب لربع ساعة، أو تقريب لساعة كاملة |
| max_report_date_range | 31 days | الحد الأقصى لمدة التقرير | الحد الأقصى لعدد الأيام المسموح بها في نطاق التاريخ عند توليد تقرير |

Rounding options: `none` / `quarter` / `hour`. Applied at display time only — stored values are always raw minutes.

---

## Default Column Headers

Seeded on first launch. Cannot be deleted or edited. Additional values added via `screen_configuration.md`. Only the attendance file has configurable column headers — employees and holidays are no longer file-based.

### Attendance File

| Field key | Default | Arabic Name | Arabic Description |
|---|---|---|---|
| employee_name | اسم الموظف | عمود اسم الموظف | اسم العمود الذي يحتوي على أسماء الموظفين في ملف الحضور |
| datetime | التاريخ والوقت | عمود التاريخ والوقت | اسم العمود الذي يحتوي على تاريخ ووقت البصمة معاً |
