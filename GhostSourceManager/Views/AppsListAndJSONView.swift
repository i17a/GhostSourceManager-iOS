import SwiftUI

struct AppsListAndJSONView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel
    @State private var showJSONEditor = false
    @State private var draftJSON = ""
    @State private var commitMessage = "Update source manifest via Ghost Source Manager"
    @State private var editorError: String?
    @State private var appPendingDelete: SourceAppItem?
    @State private var isSavingJSON = false
    @FocusState private var isJSONEditorFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let manifest = vm.manifest {
                    sourceSummaryHeader(manifest)

                    if showJSONEditor {
                        rawEditorSection
                    } else {
                        ForEach(manifest.apps) { app in
                            appRow(app)
                        }
                    }
                } else {
                    Text("اختر مستودعاً وحمّل ملف السورس أولاً من تبويب المصادر.")
                        .font(.system(size: 13))
                        .foregroundColor(GhostTheme.textSecondary)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .ghostCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showJSONEditor {
                jsonEditorToolbar
            }
        }
        .confirmationDialog("تأكيد حذف التطبيق", isPresented: Binding(
            get: { appPendingDelete != nil },
            set: { if !$0 { appPendingDelete = nil } }
        )) {
            Button("حذف وحفظ التعديل في GitHub", role: .destructive) {
                if let target = appPendingDelete {
                    Task { try? await vm.deleteApp(target) }
                }
            }
            Button("إلغاء", role: .cancel) {}
        }
    }

    private func sourceSummaryHeader(_ manifest: ParsedSourceManifest) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(manifest.name)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundColor(.white)
                    Text("\(manifest.apps.count) تطبيقات في السورس")
                        .font(.system(size: 12))
                        .foregroundColor(GhostTheme.gold)
                }
                Spacer()
                if let rawURL = vm.rawSourceURLString {
                    Button {
                        UIPasteboard.general.string = rawURL
                    } label: {
                        Label("نسخ الرابط", systemImage: "doc.on.doc")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(GhostTheme.goldGradient)
                            .clipShape(Capsule())
                    }
                }
            }

            Picker("الوضع", selection: $showJSONEditor) {
                Text("التطبيقات").tag(false)
                Text("محرر JSON الكامل").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("mode.json")
            .onChange(of: showJSONEditor) { isJSON in
                if isJSON { draftJSON = vm.rawJSONString }
            }
        }
        .padding(16)
        .ghostCard()
    }

    private func appRow(_ app: SourceAppItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Text(app.bundleIdentifier)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(GhostTheme.textSecondary)
                Text("v\(app.version)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(GhostTheme.gold)
            }
            Spacer()
            Button {
                vm.editingApp = app
                vm.selectedTab = .addIPA
            } label: {
                Image(systemName: "pencil").foregroundColor(.white).padding(8)
            }
            Button {
                appPendingDelete = app
            } label: {
                Image(systemName: "trash").foregroundColor(GhostTheme.danger).padding(8)
            }
        }
        .padding(14)
        .ghostCard()
    }

    private var rawEditorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextEditor(text: $draftJSON)
                .font(.system(size: 12, design: .monospaced))
                .environment(\.layoutDirection, .leftToRight)
                .multilineTextAlignment(.leading)
                .focused($isJSONEditorFocused)
                .scrollDismissesKeyboard(.interactively)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("manifestJSONEditor")
                .frame(minHeight: 340, maxHeight: 560)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let err = editorError {
                Text(err).font(.system(size: 12)).foregroundColor(GhostTheme.danger)
            }

        }
        .padding(16)
        .ghostCard()
    }

    private var jsonEditorToolbar: some View {
        VStack(spacing: 8) {
            if isJSONEditorFocused {
                HStack {
                    Spacer()
                    Button("إخفاء لوحة المفاتيح") {
                        isJSONEditorFocused = false
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GhostTheme.textPrimary)
                    .accessibilityIdentifier("hideJSONKeyboard")
                }
            }
            HStack {
                Button("تنسيق والتحقق") {
                    do {
                        let parsed = try SourceManifestCoder.parse(jsonString: draftJSON)
                        draftJSON = try SourceManifestCoder.serializePretty(parsed.rawRootObject)
                        editorError = nil
                    } catch {
                        editorError = error.localizedDescription
                    }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(GhostTheme.gold)
                .accessibilityIdentifier("validateJSON")

                Spacer()

                Button {
                    guard !isSavingJSON else { return }
                    Task {
                        isSavingJSON = true
                        defer { isSavingJSON = false }
                        do {
                            _ = try SourceManifestCoder.parse(jsonString: draftJSON)
                            editorError = nil
                            try await vm.saveRawJSON(draftJSON, commitMessage: commitMessage)
                        } catch {
                            editorError = error.localizedDescription
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isSavingJSON { ProgressView().tint(.black) }
                        Text("حفظ في GitHub")
                    }
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(GhostTheme.goldGradient)
                    .clipShape(Capsule())
                }
                .disabled(isSavingJSON)
                .accessibilityIdentifier("saveJSON")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(GhostTheme.cardTop)
        .overlay(alignment: .top) {
            Rectangle().fill(GhostTheme.violetGlow.opacity(0.45)).frame(height: 1)
        }
    }
}
