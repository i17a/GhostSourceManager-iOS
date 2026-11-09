# SideSource — تطبيق iOS أصلي لإدارة مصادر التطبيقات

SideSource تطبيق iOS مبني بـ Swift وSwiftUI لإدارة مصادر AltStore وSideStore وLiveContainer مباشرةً عبر GitHub API، دون خادم وسيط. اسم العرض واسم الحزمة الظاهرين في iOS هما `SideSource`، وملف IPA الناتج من GitHub Actions اسمه `SideSource.ipa`.

## تسجيل الدخول إلى GitHub

الطريقة الأساسية هي **تسجيل الدخول عبر GitHub App Device Flow**. اضغط «تسجيل الدخول عبر GitHub»؛ يعرض التطبيق رمز مستخدم مؤقتًا من ثماني خانات، مع زر لنسخه وفتح `https://github.com/login/device`. أدخل الرمز ووافق في GitHub، وسيستمر التطبيق بالتحقق وفق فترة polling التي يحددها GitHub ثم يتحقق من هوية الحساب ويحفظ access token في iOS Keychain. عند إرجاع GitHub رمز تجديد، يُحفظ هو الآخر في Keychain ويستخدم لتجديد جلسة Device Flow. لا يُرسل التوكن إلى خادم وسيط ولا يُكتب في السجلات.

إعداد GitHub App المستخدم في هذا المشروع: المالك `@iosghost`، App ID `5674573`، وClient ID `Iv23limggee6Tl8yFl01`. طلب Device Flow يستخدم **Client ID**؛ App ID معلومة تعريفية منفصلة. يجب أن يكون Device Flow مفعّلًا في إعدادات GitHub App، وأن تمنح إعدادات التطبيق صلاحيات GitHub المناسبة لقراءة/كتابة Contents وإدارة Releases وتشغيل Actions بحسب الوظائف التي تريدها. يطلب التطبيق `offline_access` لدعم access token قابل للتجديد عند تفعيل انتهاء الصلاحية.

يوجد خيار ثانوي لإدخال Personal Access Token يدويًا. استخدم fine-grained token مع `Contents: Read and write` و`Metadata: Read-only` للمستودع المستهدف، وأضف صلاحية Actions عند الحاجة لتشغيل workflow. يبقى الخيار اليدوي متوافقًا مع PAT المستخدم سابقًا.

وثائق GitHub: [Device Flow](https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps) و[إنشاء user access token لتطبيق GitHub App](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app).

## الوظائف

- اختيار مستودع GitHub وفرعه وملف JSON، مع حفظ آخر اختيار.
- تحرير manifest مع الحفاظ على الحقول الإضافية أو غير المعروفة، وعدم رفض الملفات عند غياب `localizedDescription`.
- التحقق من JSON مع تشخيص موقع الخطأ، وحماية الحفظ من استبدال نسخة أحدث باستخدام SHA.
- تحليل IPA محليًا، تعديل بيانات التطبيق، ورفع ملف IPA والأيقونة إلى GitHub Release وتحديث manifest.
- شريط تنقل سفلي عائم بزجاج داكن، notch مركزي وزر إضافة IPA، وتباعد آمن للمحتوى.

## البناء محليًا

افتح `GhostSourceManager.xcodeproj` في Xcode 15 أو أحدث، أو أعد توليده باستخدام `xcodegen generate` من `project.yml`. يظل اسم مشروع Xcode واسم module الداخلي `GhostSourceManager` لأجل التوافق مع الاختبارات والبنية الحالية؛ اسم التطبيق الظاهر على iPhone هو `SideSource`. لتوقيع محلي، اختر فريق Apple Developer وملف provisioning المناسب.

## البناء عبر GitHub Actions

يبدأ `.github/workflows/build-ios.yml` يدويًا أو عند push إلى `main` أو إنشاء tag يبدأ بـ `v`. يبني التطبيق مباشرةً دون تشغيل المحاكيات افتراضيًا. عند التشغيل اليدوي يمكن تفعيل الإدخال `run_simulator_tests` اختياريًا لتشغيل اختبارات الوحدة والواجهة على أجهزة iPhone المحاكية.

- إذا أُضيفت أسرار توقيع Apple المطلوبة إلى GitHub Actions، يُرفع artifact موقّع يحتوي الملف `SideSource.ipa`.
- دون أسرار التوقيع، يُحزم `GhostSourceManager.app` داخل `Payload/` ويُرفع artifact غير موقّع يحتوي `SideSource.ipa` جاهزًا للتوقيع عبر SideStore أو AltStore أو Feather أو LiveContainer.

## التوافق

يتطلب التطبيق iOS 16.0 أو أحدث. تثبيت IPA غير الموقّع يتطلب توقيعه بشهادة مناسبة؛ نجاح البناء لا يعني أنه موقّع أو جاهز للتثبيت المباشر.
