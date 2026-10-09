# نسخة iOS على TestFlight من غير Mac

البناء والرفع بيحصلوا على جهاز macOS عند GitHub (GitHub Actions). المستودع public، فالدقايق دي مجانية.
الملف: `.github/workflows/ios-testflight.yml`. بيتشغّل بإيدك بس، وعمره ما بيشتغل لوحده.

## مرة واحدة بس

1. **حساب Apple Developer:** اشترك في https://developer.apple.com/programs/ (حوالي $99 في السنة).
2. **الـ Team ID:** من developer.apple.com/account ← Membership details، انسخ الـ Team ID (10 حروف وأرقام).
3. **سجّل الـ Bundle ID:** من Certificates, Identifiers & Profiles ← Identifiers ← زرار + ← App IDs ← App.
   - اختار **Explicit** واكتب `com.dandoona.kidsEnglishApp`.
   - مش محتاج تفعّل أي Capability.
4. **اعمل التطبيق في App Store Connect:** من https://appstoreconnect.apple.com ← Apps ← + ← New App.
   - Platform: iOS.
   - الاسم: اسم التطبيق في المتجر، ولازم ميكونش متاخد قبل كده.
   - Bundle ID: اختار `com.dandoona.kidsEnglishApp` من القايمة.
   - SKU: أي كلمة، مثلًا `dandoona-english`.
5. **مفتاح API:** من App Store Connect ← Users and Access ← Integrations ← App Store Connect API ← Team Keys ← +.
   - الصلاحية **Admin**: دي اللي بتخلّي Apple تعمل شهادة التوقيع بنفسها.
   - نزّل ملف `.p8`. **بيتنزّل مرة واحدة بس، فاحتفظ بيه في مكان آمن ومتحطّوش في المستودع.**
   - انسخ الـ **Key ID** والـ **Issuer ID** من نفس الصفحة.
6. **الـ Secrets في GitHub:** من المستودع ← Settings ← Secrets and variables ← Actions ← New repository secret. ضيف:

   | الاسم | القيمة |
   |---|---|
   | `APPLE_TEAM_ID` | الـ Team ID من خطوة 2 |
   | `ASC_KEY_ID` | الـ Key ID |
   | `ASC_ISSUER_ID` | الـ Issuer ID |
   | `ASC_KEY_P8` | محتوى ملف `.p8` كله، من `-----BEGIN PRIVATE KEY-----` لحد سطر `END` (افتحه بـ Notepad وانسخه) |
   | `API_BASE_URL` (اختياري) | عنوان السيرفر `https://...` لو مرفوع |

   **من غير `API_BASE_URL`** النسخة بتشتغل من غير سيرفر، والوحدات اللي هتتلعب هي Letters وColors بس، لأن الباقي packs بتتنزّل من السيرفر.
7. **دخّل ملف الـ workflow على `main`:** GitHub مش بيظهر زرار «Run workflow» إلا لو الملف موجود على الفرع الأساسي.
   - الفرع `ios-testflight` فيه الملف ده، ومعاه تعديلين صغيرين: `ITSAppUsesNonExemptEncryption = false` في Info.plist، وإزالة 2 import زيادة في ملفات اختبار.
   - افتح Pull Request من `ios-testflight` لـ `main` واعمله merge بنفسك.

## كل ما تحب تطلّع نسخة

1. من GitHub ← تبويب **Actions** ← **iOS TestFlight** ← **Run workflow**.
   - اختار الفرع، وغالبًا هيكون `main`.
   - في خانة السيرفر ممكن تكتب عنوان مختلف لنسخة معيّنة، أو تسيبها فاضية.
2. البناء بياخد حوالي 20-30 دقيقة. الترتيب: الاختبارات، بعدين البناء، بعدين التوقيع، بعدين الرفع. لو حاجة وقفت، اللوج بيوضّح السبب، ولو secret ناقص بيكتب اسمه.
3. بعد ما Apple تخلّص معالجة النسخة (عادةً 10-30 دقيقة) هتلاقيها في App Store Connect ← التطبيق ← **TestFlight**. رقم البناء هو رقم مرة التشغيل، والإصدار `0.1.0` من `pubspec.yaml`.
4. **المختبرين الداخليين** (لحد 100 من فريق حسابك):
   - TestFlight ← Internal Testing ← اعمل جروب وضيف الناس. لازم الأول يكونوا متضافين في Users and Access.
   - بينزّلوا تطبيق TestFlight على الآيفون ويقبلوا الدعوة. مفيش مراجعة من Apple.
5. **المختبرين الخارجيين** (أي حد بالإيميل أو برابط عام):
   - محتاجين **Beta App Review**، ورابط **سياسة خصوصية**، وبيانات تواصل.
   - التطبيق للأطفال، فـ Apple هتراجع بوابة الأهل وسياسة الخصوصية بتدقيق.

## ملاحظات

- اسم التطبيق اللي بيظهر تحت الأيقونة على الموبايل حاليًا «Kids English App» (`CFBundleDisplayName` في Info.plist). ماتغيّرش. لو عايزه يتغيّر، ده قرارك.
- البناء بيستخدم Flutter 3.47.6، نفس النسخة اللي اتعملت بيها الاختبارات.
- مفتاح `.p8` بيتكتب في مجلد مؤقت على جهاز البناء وبيتمسح في الآخر. أي حد يقدر يشوف الـ Secrets في المستودع، لكن مش هيقدر يقرا قيمتها.
- لو ظهر خطأ زي «No Accounts» أو «No signing certificate»: اتأكد إن صلاحية المفتاح **Admin**، وإن الـ Bundle ID متسجّل (خطوة 3)، وإن التطبيق معمول في App Store Connect (خطوة 4).
- البناء مش هيشتغل بجد إلا لما تحط الـ Secrets وتشغّله. ملف الـ workflow متجرّبش على macOS، لأن مفيش Mac ولا GitHub Actions في بيئة إعداده.
