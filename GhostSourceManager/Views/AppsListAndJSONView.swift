import SwiftUI

struct AppsListAndJSONView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel
    @State private var showJSONEditor = false
    @State private var draftJSON = ""
    @State private var commitMessage = "Update source manifest via Ghost Source Manager"
    @State private var editorError: String?
    @State private var appPendingDelete: SourceAppItem?

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
            .padding(.bottom, 115)
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
            .onChange(of: showJSONEditor) { _, isJSON in
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
                .frame(minHeight: 260)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let err = editorError {
                Text(err).font(.system(size: 12)).foregroundColor(GhostTheme.danger)
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

                Spacer()

                Button("حفظ في GitHub") {
                    Task {
                        do {
                            editorError = nil
                            try await vm.saveRawJSON(draftJSON, commitMessage: commitMessage)
                        } catch {
                            editorError = error.localizedDescription
                        }
                    }
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(GhostTheme.goldGradient)
                .clipShape(Capsule())
            }
        }
        .padding(16)
        .ghostCard()
    }
}
