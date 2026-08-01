# مدير تحميل الأفلام والمسلسلات — Xtream Downloader

تطبيق iPhone مبني بـ Flutter لتنزيل الأفلام والمسلسلات من خادم Xtream Codes.
التطبيق **للتنزيل فقط** — لا يحتوي على مشغّل فيديو ولا بث مباشر ولا قنوات.

---

## ما الذي يفعله التطبيق

- تسجيل دخول بـ Server URL / Username / Password مع أزرار لصق ومسح لكل خانة.
- حفظ بيانات الدخول في **Keychain** والدخول التلقائي في المرات التالية.
- جلب **Movies** و **Series** فقط من `player_api.php`.
- واجهة عربية كاملة RTL مع بانر وأقسام وبحث فوري وفلاتر.
- تحميل فيلم مفرد، أو حلقة مفردة، أو **موسم كامل** بترتيب تسلسلي.
- إدارة تحميلات كاملة: إيقاف، استئناف، إلغاء، حذف، تحديد متعدد.
- تنظيم الملفات في `Downloads/Movies` و `Downloads/Series/<اسم>/Season NN`.

---

## القرارات المعمارية المهمة

### محركا التحميل

يوجد محركان خلف واجهة `DownloadEngine` واحدة، ويُختار بينهما من الإعدادات:

| | `background` (الافتراضي) | `turbo` |
|---|---|---|
| التقنية | URLSession عبر `background_downloader` | Dio + HTTP Range |
| يكمل والتطبيق مغلق | ✅ | ❌ |
| اتصالات متعددة لكل ملف | ❌ (اتصال واحد) | ✅ حتى 16 |
| استئناف بعد الانقطاع | ✅ | ✅ |

**لماذا محركان؟** لأن iOS لا يسمح بالجمع بينهما. التحميل الذي ينجو من إغلاق
التطبيق يجب أن يمر عبر URLSession، وهذه تملك الاتصال ولا تسمح بتقسيم الملف.
أي تطبيق يدّعي الاثنين معاً على iOS إما يوقف التحميل عند الخروج، أو لا يقسّم
فعلياً. الافتراضي هو `background` لأن ملفات الفيديو كبيرة، وقيمة إكمال التحميل
والهاتف في الجيب أعلى من قيمة السرعة الإضافية.

خانة "عدد الاتصالات" في الإعدادات **معطّلة** تلقائياً في وضع الخلفية، مع شرح
للمستخدم بدل تركها كخيار وهمي لا أثر له.

### تحميل الموسم الكامل

عند الضغط على "تحميل الموسم كاملاً":

1. كل الحلقات تُضاف إلى القائمة فوراً بحالة `queued`.
2. كلها تحمل نفس `groupId` وترتيباً `sequenceIndex`.
3. المجدول في `DownloadQueueManager._pump()` يمنع تشغيل أكثر من حلقة واحدة من
   نفس المجموعة، ويسمح فقط للحلقة صاحبة أصغر `sequenceIndex` غير المنتهية.
4. عند انتهاء الحلقة يُستدعى `_pump()` مجدداً فتبدأ التالية.

هذا يعني أن الموسم يتحمّل حلقة تلو الأخرى بالترتيب، حتى لو كان
"التحميلات المتوازية" مضبوطاً على 10 — لأن التوازي يطبَّق على أفلام أو مواسم
مختلفة، لا داخل الموسم الواحد.

### أسماء الملفات

اسم الملف يُؤخذ من الخادم كما هو. `FilenameSanitizer` يستبدل فقط الرموز التي
يرفضها نظام الملفات (`/ \ : * ? " < > |` والأحرف التحكمية) والنقاط في نهاية
الاسم. الاسم الأصلي غير المعدّل يُحفظ في Hive ويُعرض للمستخدم في كل الشاشات.

```
الخادم:  Breaking Bad S01E01 Pilot
القرص:   Downloads/Series/Breaking Bad/Season 01/Breaking Bad S01E01 Pilot.mp4
```

### الملفات على القرص

تُحفظ في `Application Documents Directory` وليس في `Caches` (نظام iOS يمسح
Caches عند امتلاء المساحة). مع `UIFileSharingEnabled` و
`LSSupportsOpeningDocumentsInPlace` في `Info.plist`، تظهر الملفات في تطبيق
**Files** تحت "On My iPhone" ويمكن فتحها بأي مشغّل أو نقلها إلى الكمبيوتر.

أثناء التحميل يُكتب الملف باسم `.part`، ويُعاد تسميته إلى اسمه النهائي فقط بعد
نجاح التحميل، فلا تبقى ملفات ناقصة تبدو مكتملة.

### حصر الـ API

`XtreamApi` يحتوي على قائمة بيضاء صريحة:

```dart
static const Set<String> _allowedActions = {
  'get_vod_categories', 'get_vod_streams', 'get_vod_info',
  'get_series_categories', 'get_series', 'get_series_info',
};
```

أي محاولة لاستدعاء `get_live_streams` أو `get_short_epg` ترمي `StateError`.
لا يوجد في المشروع أي كود لـ Live أو EPG أو Catchup أو تشغيل الفيديو.

---

## البنية

```
lib/
├── core/            ثوابت، أخطاء، شبكة، ثيم، أدوات، DI
├── domain/          entities · repositories (عقود) · usecases
├── data/            xtream_api · keychain · hive · mappers · تنفيذ العقود
├── downloader/      محرك التحميل والمجدول ومسارات التخزين
└── presentation/    providers · pages · widgets
```

الاعتماديات تتجه للداخل فقط: `presentation → domain ← data`. طبقة `domain`
لا تستورد Flutter ولا Dio ولا Hive.

---

## البناء — IPA غير موقّع

التوقيع منفصل تماماً عن البناء. لا يوجد في المستودع Team ID ولا شهادة ولا ملف
تزويد، ولا يحتاج البناء إلى حساب Apple Developer.

### لماذا لا نستخدم `flutter build ipa`

`flutter build ipa` يستدعي `xcodebuild -exportArchive`، وهذا يتطلب ملف تزويد
ويفشل بدونه. البديل الصحيح هو بناء `Runner.app` بدون توقيع ثم تغليفه يدوياً:

```
Payload/
└── Runner.app
```

ضغط هذا المجلد بامتداد `.ipa` هو تعريف صيغة IPA حرفياً. هذا ما يتوقعه أي
مزوّد توقيع خارجي.

### أمر البناء النهائي

```bash
flutter build ios --release --no-codesign
mkdir -p build/ios/Payload
cp -R build/ios/iphoneos/Runner.app build/ios/Payload/
cd build/ios && zip -qry ../../xtream_downloader-unsigned.ipa Payload
```

أو باستخدام السكربت الجاهز الذي ينفّذ ما سبق مع `pub get` و`analyze`:

```bash
bash tool/build_unsigned_ipa.sh
```

الناتج: `build/ios/ipa/xtream_downloader-unsigned.ipa`

> هذا الملف **لا يُثبَّت كما هو**. ارفعه إلى خدمة التوقيع التي تستخدمها.

### تغيير الـ Bundle Identifier

القيمة معرَّفة في مكان واحد:

```
tool/app_config.env
```

```
APP_BUNDLE_ID = com.iss10a.downloader
```

عدّلها ثم نفّذ:

```bash
bash tool/apply_ios_config.sh
```

السكربت يكتب المعرّف في `project.pbxproj` — وهذا ضروري لأن الإعدادات المكتوبة
مباشرة في ملف مشروع Xcode لها أولوية على أي `xcconfig`. ويحذف في نفس الوقت
`CODE_SIGN_IDENTITY` و`DEVELOPMENT_TEAM` و`PROVISIONING_PROFILE_SPECIFIER`
في كل التهيئات، فلا يبقى أثر لأي توقيع في المشروع.

### تجهيز المشروع محلياً (على Windows، بلا Mac)

```bash
flutter create --platforms=ios,android --org com.example \
  --project-name xtream_downloader .
```

يولّد هذا `ios/Runner.xcodeproj`. **مهم:** قد يستبدل الأمر
`ios/Runner/Info.plist` و`ios/Podfile`، فأعد نسخ النسختين المرفوعتين في
المستودع فوقهما، ثم:

```bash
bash tool/apply_ios_config.sh
flutter pub get
flutter analyze
flutter test
```

> إن لم تنفّذ هذه الخطوة فلا مشكلة: كلا الـ workflow يولّد المجلدات على خادم
> البناء ويعيد ملفات الإعداد فوقها تلقائياً.

### فتح المشروع في Xcode

```bash
cd ios && pod install
open Runner.xcworkspace
```

افتح `Runner.xcworkspace` وليس `Runner.xcodeproj`، وإلا لن يجد Xcode الحزم
المثبّتة عبر CocoaPods. في تبويب Signing & Capabilities ستجد التوقيع معطّلاً
وخانة الفريق فارغة — هذا مقصود.

---

## CI/CD

يوجد ملفان جاهزان، استخدم أيهما شئت:

| | الملف | كيف تحصل على الـ IPA |
|---|---|---|
| **GitHub Actions** | `.github/workflows/ios-unsigned.yml` | تبويب Actions ← آخر تشغيل ← Artifacts |
| **Codemagic** | `codemagic.yaml` | صفحة البناء ← Artifacts |

كلاهما ينفّذ: توليد مجلد iOS إن لزم ← تطبيق الإعدادات وتعطيل التوقيع ←
`flutter pub get` ← `flutter analyze` ← `flutter test` ← `pod install` ←
بناء release غير موقّع ← تغليف ورفع الـ IPA.

**GitHub Actions لا يحتاج أي Secret.** يعمل على `macos-15` مباشرة بعد الرفع.
يمكنك تشغيله يدوياً من `Run workflow` وتمرير Bundle ID مختلف عند الحاجة.

**Codemagic** يحتاج فقط ربط المستودع — لا مفتاح API ولا شهادات. غيّر قيمة
`APP_BUNDLE_ID` في `codemagic.yaml` إن أردت.

لا يوجد في أي منهما رفع إلى App Store ولا TestFlight.

## المتطلبات

- iOS 16.0+
- Flutter stable
- Xcode 16+ (على Codemagic فقط)

## الحزم المستخدمة

`flutter_riverpod` · `dio` · `background_downloader` · `hive` ·
`flutter_secure_storage` · `path_provider` · `cached_network_image` · `intl`

---

## ملاحظات على الأداء

- الشبكات تستخدم `SliverGridDelegateWithMaxCrossAxisExtent` مع `cacheExtent`
  محدود، فلا تُبنى إلا العناصر المرئية حتى لو كانت المكتبة بعشرات الآلاف.
- `PosterImage` يحدد `memCacheWidth` فيُخزَّن البوستر بدقة العرض لا بدقته
  الأصلية.
- الكتابة إلى Hive أثناء التحميل مُجمّعة كل ثانيتين بدل كل تحديث تقدّم.
- المكتبة تُخزَّن مؤقتاً 6 ساعات، فالفتح التالي للتطبيق فوري بلا انتظار شبكة.
