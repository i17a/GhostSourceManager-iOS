import SwiftUI
import UniformTypeIdentifiers

struct AddIPAPublishView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel

    @State private var showFileImporter = false
    @State private var analyzedIPA: AnalyzedIPA?
    @State private var parseError: String?

    @State private var appName: String = ""
    @State private var bundleID: String = ""
    @State private var developerName: String = ""
    @State private var version: String = "1.0.0"
    @State private var buildVersion: String = "1"
    @State private var localizedDescription: String = ""
    @State private var manualDownloadURL: String = ""
    @State private var releaseTag: String = "v1.0.0"

    @State private var uploadToRelease: Bool = true
    @State private var updateManifest: Bool = true

    @State private var showConfirmPublish = false
    @State private var showReplaceAssetConfirm = false
    @State private var isPublishing = false
    @State private var progressMessage: String = ""
    @State private var publishError: String?
    @State private var outcome: SourceManagerViewModel.PublishOutcome?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerBar
                ipaDropCard
                metadataEditorCard
                publishOptionsCard
                summaryCard
                actionButtons
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 115)
        }
        .onAppear(perform: populateFromEditingApp)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let first = urls.first else { return }
                do {
                    let info = try IPAAnalyzerService.analyze(fileURL: first)
                    analyzedIPA = info
                    appName = info.appName
                    bundleID = info.bundleIdentifier
                    version = info.shortVersion
                    buildVersion = info.buildVersion
                    releaseTag = "v\(info.shortVersion)"
                    if localizedDescription.isEmpty {
                        localizedDescription = "تطبيق \(info.appName) لنظام iOS"
                    }
                    parseError = nil
                } catch {
                    parseError = error.localizedDescription
                }
            case .failure(let err):
                parseError = err.localizedDescription
            }
        }
        .confirmationDialog("تأكيد الكتابة إلى مستودع GitHub", isPresented: $showConfirmPublish, titleVisibility: .visible) {
            Button("تأكيد الرفع والنشر") {
                Task { await executePublish(replaceAsset: false) }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("المستودع: \(vm.selectedRepo?.fullName ?? "-")\nالفرع: \(vm.selectedBranch)\nملف السورس: \(vm.selectedFilePath)")
        }
        .confirmationDialog("ملف IPA موجود مسبقاً بنفس الاسم", isPresented: $showReplaceAssetConfirm, titleVisibility: .visible) {
            Button("استبدال الأصل والمتابعة", role: .destructive) {
                Task { await executePublish(replaceAsset: true) }
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("يوجد ملف بنفس الاسم داخل هذا الإصدار على GitHub Release. هل تريد استبداله؟")
        }
    }

    private func populateFromEditingApp() {
        guard let app = vm.editingApp else { return }
        appName = app.name
        bundleID = app.bundleIdentifier
        developerName = app.developerName
        version = app.version
        buildVersion = app.buildVersion
        localizedDescription = app.localizedDescription
        manualDownloadURL = app.downloadURL
        uploadToRelease = false
    }

    private var headerBar: some View {
        HStack {
            Image("GhostMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .padding(6)
                .background(GhostTheme.cardTop)
                .clipShape(RoundedRectangle(cornerRadius: 14))

            Spacer()

            VStack(spacing: 2) {
                Text("إضافة IPA وتعديل التطبيق")
                    .font(.system(size: 17, weight: .heavy))
                    .foregroundColor(.white)
                Text("ارفع ملف IPA أو عدّل بيانات التطبيق")
                    .font(.system(size: 11))
                    .foregroundColor(GhostTheme.textSecondary)
            }

            Spacer()

            Button {
                vm.selectedTab = .sources
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .ghostCard()
            }
        }
    }

    private var ipaDropCard: some View {
        Button {
            showFileImporter = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "icloud.and.arrow.up.fill")
                    .font(.system(size: 32))
                    .foregroundColor(GhostTheme.violetGlow)
                Text("اختر ملف IPA من الملفات")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text("يتم استخراج Info.plist والأيقونة محلياً على جهازك")
                    .font(.system(size: 11))
                    .foregroundColor(GhostTheme.textSecondary)

                if let ipa = analyzedIPA {
                    Text("✓ تم اختيار وتحليل \(ipa.fileName)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GhostTheme.success)
                }
                if let err = parseError {
                    Text(err)
                        .font(.system(size: 12))
                        .foregroundColor(GhostTheme.danger)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .background(GhostTheme.heroGradient)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundColor(GhostTheme.violetGlow)
            )
        }
    }

    private var metadataEditorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("بيانات التطبيق", systemImage: "gearshape.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            labeledField("اسم التطبيق", text: $appName, ltr: true)
            labeledField("معرف الحزمة", text: $bundleID, ltr: true)
            HStack(spacing: 10) {
                labeledField("الإصدار", text: $version, ltr: true)
                labeledField("البناء", text: $buildVersion, ltr: true)
            }
            labeledField("المطور", text: $developerName, ltr: false)
            labeledField("الوصف", text: $localizedDescription, ltr: false)
            if uploadToRelease {
                labeledField("وسم Release", text: $releaseTag, ltr: true)
            } else {
                labeledField("رابط التنزيل", text: $manualDownloadURL, ltr: true)
            }
        }
        .padding(16)
        .ghostCard()
    }

    private func labeledField(_ label: String, text: Binding<String>, ltr: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(GhostTheme.textSecondary)
            TextField(label, text: text)
                .font(.system(size: 13))
                .environment(\.layoutDirection, ltr ? .leftToRight : .rightToLeft)
                .foregroundColor(.white)
                .padding(10)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var publishOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("خيارات النشر", systemImage: "paperplane.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Toggle("رفع IPA إلى GitHub Release", isOn: $uploadToRelease)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .tint(GhostTheme.violetGlow)

            Toggle("تحديث ملف السورس (JSON)", isOn: $updateManifest)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .tint(GhostTheme.gold)
        }
        .padding(16)
        .ghostCard()
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ملخص العملية")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            if !progressMessage.isEmpty {
                Text(progressMessage)
                    .font(.system(size: 12))
                    .foregroundColor(GhostTheme.gold)
            }
            if let err = publishError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(GhostTheme.danger)
            }
            if let out = outcome {
                if let warn = out.partialFailureWarning {
                    Text(warn).font(.system(size: 12)).foregroundColor(GhostTheme.gold)
                } else {
                    Text("✓ تم النشر وتحديث السورس بنجاح!")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(GhostTheme.success)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ghostCard()
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                Task { await preparePublish() }
            } label: {
                HStack {
                    if isPublishing { ProgressView().tint(.black) }
                    Text("متابعة الرفع والنشر")
                        .font(.system(size: 14, weight: .heavy))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(GhostTheme.goldGradient)
                .clipShape(Capsule())
            }
            .disabled(isPublishing)

            Button("إلغاء") {
                analyzedIPA = nil
                publishError = nil
                outcome = nil
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 14)
            .ghostCard()
        }
    }

    private func preparePublish() async {
        publishError = nil
        guard vm.currentUser != nil else {
            vm.showLoginSheet = true
            return
        }
        guard vm.selectedRepo != nil else {
            publishError = "يرجى اختيار مستودع من تبويب المصادر أولاً."
            return
        }
        guard !appName.isEmpty, !bundleID.isEmpty, !version.isEmpty else {
            publishError = "يرجى تعبئة اسم التطبيق ومعرّف الحزمة والإصدار."
            return
        }
        if uploadToRelease && analyzedIPA == nil {
            publishError = "يرجى اختيار ملف .ipa أولاً أو إيقاف خيار رفع Release."
            return
        }
        if uploadToRelease, let ipa = analyzedIPA {
            if await vm.checkReleaseAssetExists(tagName: releaseTag, assetName: ipa.fileName) {
                showReplaceAssetConfirm = true
                return
            }
        }
        showConfirmPublish = true
    }

    private func executePublish(replaceAsset: Bool) async {
        isPublishing = true
        publishError = nil
        do {
            outcome = try await vm.publishIPAAndUpdateSource(
                existingIndex: vm.editingApp?.index,
                name: appName,
                bundleID: bundleID,
                developerName: developerName,
                version: version,
                buildVersion: buildVersion,
                localizedDescription: localizedDescription,
                manualDownloadURL: manualDownloadURL,
                manualIconURL: vm.editingApp?.iconURL ?? "",
                fileSize: analyzedIPA?.fileSize ?? vm.editingApp?.size ?? 0,
                minOSVersion: analyzedIPA?.minimumOSVersion,
                tagName: releaseTag,
                uploadToRelease: uploadToRelease,
                updateManifest: updateManifest,
                analyzedIPA: analyzedIPA,
                replaceExistingAsset: replaceAsset,
                onStepUpdate: { msg in progressMessage = msg }
            )
        } catch {
            publishError = error.localizedDescription
        }
        isPublishing = false
    }
}
