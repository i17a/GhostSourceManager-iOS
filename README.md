# Ghost Source Manager — تطبيق iOS أصلي (Swift & SwiftUI)

تطبيق iOS أصلي مبني بـ **Swift** و **SwiftUI** لإدارة مصادر تطبيقات iOS المتوافقة مع **AltStore** و **SideStore** و **LiveContainer** مباشرة عبر حسابك في GitHub دون أي خادم وسيط.

---

## 1. سير العمل والوظائف المتوفرة

1. **تسجيل الدخول بـ GitHub Personal Access Token:**
   - التحقق الفوري من الحساب عبر `GET /user` وعرض اسم الحساب وصورته والصلاحيات.
   - تخزين التوكن حصريًا داخل **iOS Keychain** (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`) وحذفه فور تسجيل الخروج، مع عدم طباعته في أي سجل أو عنوان URL.
2. **اختيار المستودع والفرع وملف السورس:**
   - جلب المستودعات العامة والخاصة المتاحة للتوكن مع البحث والفرز.
   - جلب الفروع واكتشاف ملفات الـ JSON المرشحة (`apps.json`, `source.json`, `altstore.json` وغيرها) أو كتابة مسار مخصص، مع حفظ آخر اختيار تلقائيًا.
   - دعم إنشاء ملف سورس جديد فارغ فقط بعد تأكيد صريح من المستخدم إذا كان المسار غير موجود (404).
3. **إدارة السورس والتطبيقات ومحرر JSON الكامل:**
   - قراءة وتحليل JSON مع **الحفاظ الكامل على الحقول الإضافية أو غير المعروفة** عند إعادة الحفظ (`JSONSerialization` بدون إسقاط مفاتيح مخصصة).
   - التعامل الآمن مع غياب `localizedDescription` دون تعطيل التطبيق أو رفض ملف السورس، مع تنبيه المستخدم بأي قيمة افتراضية تُضاف عند النشر.
   - حماية التحديثات عبر `SHA` الخاص بالملف لمنع الكتابة فوق تعديلات خارجية أحدث بصمت.
4. **إضافة وتحليل ملفات IPA محليًا ورفعها إلى GitHub Release:**
   - استخراج `Payload/*.app/Info.plist` والأيقونة محليًا على الجهاز باستخدام `Compression` (zlib) و`PropertyListSerialization` دون مكتبات خارجية.
   - مراجعة وتعديل البيانات قبل النشر، وفحص وجود أصل بنفس الاسم في Release لطلب التأكيد قبل الاستبدال.
   - رفع ملف الـ IPA إلى GitHub Release في المستودع المختار نفسه، ورفع الأيقونة إلى `icons/`، وتحديث `downloadURL` وسجل `versions` في ملف السورس، مع تتبع منفصل لكل خطوة وعدم اعتبار النشر ناجحًا بالكامل إذا نجحت خطوة وفشلت أخرى.

---

## 2. صلاحيات GitHub Token المطلوبة

أنشئ التوكن من إعدادات GitHub (`Settings -> Developer settings -> Personal access tokens`):
- **Fine-grained PAT (موصى به لأقل صلاحيات):** اختر المستودع المستهدف فقط وامنح صلاحية `Contents: Read and write` (لقراءة الفروع وتحديث JSON والأيقونات وإنشاء Releases ورفع الأصول) و`Metadata: Read-only`.
- **Classic PAT:** فعّل `repo` للمستودعات الخاصة والعامة، أو `public_repo` للمستودعات العامة فقط، وأضف `workflow` فقط إذا أردت تشغيل GitHub Actions.

---

## 3. كيفية بناء التطبيق وإنتاج ملف IPA بنفسك

### الخيار الأول: البناء محليًا عبر Xcode على macOS
1. فك ضغط الملف `GhostSourceManager-iOS.zip`.
2. افتح `GhostSourceManager.xcodeproj` مباشرة في **Xcode 15+** (أو نفّذ `xcodegen generate` إذا أردت إعادة توليد المشروع من `project.yml`).
3. من إعدادات التوقيع **Signing & Capabilities**، اختر حساب Apple Developer الخاص بك (`Team`) وعدّل `Bundle Identifier` إذا لزم.
4. اختر `Any iOS Device (arm64)` ثم من القائمة العلوية اختر **Product -> Archive** ثم **Distribute App** لتصدير ملف `.ipa` موقّع، أو وصّل هاتفك مباشرة واضغط **Run**.

### الخيار الثاني: البناء التلقائي عبر GitHub Actions
يحتوي المشروع على ملف `.github/workflows/build-ios.yml` يدعم التشغيل اليدوي (`workflow_dispatch`) أو عند `push` أو إنشاء `tag` يبدأ بـ `v*`.

#### أ) لإنتاج ملف IPA موقّع (Signed IPA):
أضف الأسرار التالية في مستودعك (`Settings -> Secrets and variables -> Actions`):
- `BUILD_CERTIFICATE_BASE64`: شهادة التوقيع بصيغة `.p12` محوّلة إلى Base64 (`base64 -i cert.p12 | pbcopy`).
- `P12_PASSWORD`: كلمة مرور ملف `.p12`.
- `BUILD_PROVISION_PROFILE_BASE64`: ملف `.mobileprovision` محوّل إلى Base64.
- `KEYCHAIN_PASSWORD`: كلمة مرور عشوائية لإنشاء Keychain مؤقت أثناء البناء.
- `APPLE_TEAM_ID`: معرّف الفريق المكوّن من 10 خانات في حساب Apple Developer.
- `EXPORT_METHOD` *(اختياري)*: `ad-hoc` أو `development` أو `app-store` (الافتراضي `ad-hoc`).

عند توفر هذه الأسرار ينتج الـ Workflow ملف artifact باسم `GhostSourceManager-Signed-IPA-v<version>-b<build>`.

#### ب) بدون إضافة أسرار التوقيع:
يتحقق الـ Workflow من سلامة الكود ويبني حزمة `GhostSourceManager.app` غير موقّعة داخل artifact باسم `GhostSourceManager-Unsigned-AppBundle-...` مع إشعار صريح بأن الحزمة **غير موقّعة وليست ملف IPA جاهزًا للتثبيت المباشر**، حتى توقّعها بأداتك الخاصة (مثل Xcode أو AltServer/SideStore/Feather بشهادتك الخاصة).

---

## 4. القيود وملاحظات التوافق

- يعتمد نجاح تثبيت وتشغيل أي ملف IPA عبر أدوات مثل **SideStore** أو **AltStore** أو **LiveContainer** أو **TrollStore** على صلاحية التوقيع، توافق شهادة المطور، إصدار نظام iOS (الحد الأدنى المضبوط هو iOS 16.0+)، ونوع الجهاز.
- ملفات PNG المضغوطة بصيغة Apple CgBI الخاصة داخل بعض حزم IPA القديمة قد لا تُعرض كـ PNG قياسي دون فك CgBI؛ يتعرّف المحلل المحلي تلقائيًا على الـ PNG القياسي أو `iTunesArtwork` لتجنب رفع صورة تالفة، ويسمح بإدخال أو الاحتفاظ برابط أيقونة مخصص.
