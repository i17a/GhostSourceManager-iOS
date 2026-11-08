import SwiftUI
import UIKit

struct AppsListAndJSONView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel
    @State private var showJSONEditor = false
    @State private var draftJSON = ""
    @State private var commitMessage = "Update source manifest via Ghost Source Manager"
    @State private var editorError: String?
    @State private var appPendingDelete: SourceAppItem?
    @State private var isSavingJSON = false
    @FocusState private var isJSONEditorFocused: Bool
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        VStack(spacing: 0) {
            if let manifest = vm.manifest {
                sourceSummaryHeader(manifest)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 8)

                if showJSONEditor {
                    jsonEditorToolbar
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }

                ScrollView {
                    if showJSONEditor {
                        rawEditorContent
                            .padding(.horizontal, 16)
                            .padding(.bottom, 14)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(manifest.apps) { app in appRow(app) }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                ScrollView {
                    Text("اختر مستودعاً وحمّل ملف السورس أولاً من تبويب المصادر.")
                        .font(.system(size: 13))
                        .foregroundColor(GhostTheme.textSecondary)
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .ghostCard()
                        .padding(16)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showJSONEditor, vm.manifest != nil { jsonSaveBar }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("تم") { isJSONEditorFocused = false }
                    .accessibilityIdentifier("doneJSONKeyboard")
            }
        }
        .confirmationDialog("تأكيد حذف التطبيق", isPresented: Binding(
            get: { appPendingDelete != nil },
            set: { if !$0 { appPendingDelete = nil } }
        )) {
            Button("حذف وحفظ التعديل في GitHub", role: .destructive) {
                if let target = appPendingDelete { Task { try? await vm.deleteApp(target) } }
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
                else { isJSONEditorFocused = false }
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
            Button { appPendingDelete = app } label: {
                Image(systemName: "trash").foregroundColor(GhostTheme.danger).padding(8)
            }
        }
        .padding(14)
        .ghostCard()
    }

    private var rawEditorContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextEditor(text: $draftJSON)
                .font(.system(size: 13, design: .monospaced))
                .environment(\.layoutDirection, .leftToRight)
                .multilineTextAlignment(.leading)
                .focused($isJSONEditorFocused)
                .scrollDismissesKeyboard(.interactively)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityIdentifier("manifestJSONEditor")
                .frame(height: 430)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.45))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if let err = editorError {
                Text(err)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GhostTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("jsonValidationError")
            }
        }
        .padding(16)
        .ghostCard()
    }

    private var jsonEditorToolbar: some View {
        HStack(spacing: 6) {
            jsonTool("تنسيق", icon: "text.alignleft", id: "formatJSON") {
                do {
                    let parsed = try SourceManifestCoder.parse(jsonString: draftJSON)
                    draftJSON = try SourceManifestCoder.serializePretty(parsed.rawRootObject)
                    editorError = nil
                } catch { editorError = error.localizedDescription }
            }
            jsonTool("تحقق", icon: "checkmark.circle", id: "validateJSON") {
                do {
                    _ = try SourceManifestCoder.parse(jsonString: draftJSON)
                    editorError = nil
                } catch { editorError = error.localizedDescription }
            }
            jsonTool("نسخ", icon: "doc.on.doc", id: "copyJSON") {
                UIPasteboard.general.string = draftJSON
            }
            jsonTool("لصق", icon: "doc.on.clipboard", id: "pasteJSON") {
                if let pasted = UIPasteboard.general.string { draftJSON += pasted }
            }
            jsonTool("تراجع", icon: "arrow.uturn.backward", id: "undoJSON") {
                undoManager?.undo()
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("jsonEditorToolbar")
    }

    private func jsonTool(_ title: String, icon: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                Text(title).font(.system(size: 9, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundColor(GhostTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(GhostTheme.cardTop)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(GhostTheme.violetGlow.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    private var jsonSaveBar: some View {
        VStack(spacing: 8) {
            if let err = editorError {
                Text(err)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(GhostTheme.danger)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("jsonValidationError")
            }
            TextField("رسالة الحفظ إلى GitHub", text: $commitMessage)
                .font(.system(size: 12))
                .textInputAutocapitalization(.sentences)
                .padding(10)
                .background(Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("jsonCommitMessage")

            Button {
                guard !isSavingJSON else { return }
                Task {
                    isSavingJSON = true
                    defer { isSavingJSON = false }
                    do {
                        _ = try SourceManifestCoder.parse(jsonString: draftJSON)
                        editorError = nil
                        try await vm.saveRawJSON(draftJSON, commitMessage: commitMessage)
                    } catch { editorError = error.localizedDescription }
                }
            } label: {
                HStack(spacing: 8) {
                    if isSavingJSON { ProgressView().tint(.black) }
                    Text("حفظ في GitHub").font(.system(size: 15, weight: .heavy))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(GhostTheme.goldGradient)
                .clipShape(Capsule())
            }
            .disabled(isSavingJSON)
            .accessibilityIdentifier("saveJSON")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(GhostTheme.cardTop)
    }
}
