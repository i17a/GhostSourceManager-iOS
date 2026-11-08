import SwiftUI

struct SourcesDashboardView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel
    @State private var searchQuery: String = ""
    @State private var segmentIndex: Int = 0
    @State private var customPathText: String = "apps.json"

    private var filteredRepos: [GitHubRepo] {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.repositories }
        return vm.repositories.filter {
            $0.name.lowercased().contains(q)
                || $0.fullName.lowercased().contains(q)
                || ($0.description?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                heroBanner
                segmentedHeader

                if segmentIndex == 0 {
                    sourcesContent
                } else if segmentIndex == 1 {
                    settingsContent
                } else {
                    aboutContent
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 110)
        }
    }

    private var heroBanner: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text("★ GitHub")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(GhostTheme.gold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(GhostTheme.gold.opacity(0.15))
                    .clipShape(Capsule())

                if let user = vm.currentUser {
                    Text("مرحباً، \(user.name ?? user.login)")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                    Text("متصل بحساب @\(user.login) — اختر مستودع سورسك لإدارة التطبيقات.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))

                    HStack(spacing: 8) {
                        Button("تحديث") {
                            Task { await vm.refreshRepositories() }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(GhostTheme.goldGradient)
                        .clipShape(Capsule())

                        Button("خروج") {
                            vm.signOut()
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())
                    }
                } else {
                    Text("مرحباً بك في\nGhost Source Manager")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                    Text("سجل دخولك باستخدام GitHub Token لإدارة مصادر التطبيقات ونشر التحديثات")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))

                    Button {
                        vm.showLoginSheet = true
                    } label: {
                        Text("تسجيل الدخول")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundColor(.black)
                            .padding(.horizontal, 22)
                            .padding(.vertical, 10)
                            .background(GhostTheme.goldGradient)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer(minLength: 0)

            Image("GhostMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 105, height: 105)
                .shadow(color: GhostTheme.violetGlow.opacity(0.8), radius: 18)
        }
        .padding(18)
        .background(GhostTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(GhostTheme.violetGlow.opacity(0.45)))
    }

    private var segmentedHeader: some View {
        HStack(spacing: 6) {
            segmentPill(index: 0, title: "المصادر", icon: "square.stack.3d.up.fill")
            segmentPill(index: 1, title: "الإعدادات", icon: "shippingbox")
            segmentPill(index: 2, title: "حول التطبيق", icon: "info.circle")
        }
        .padding(6)
        .ghostCard()
    }

    private func segmentPill(index: Int, title: String, icon: String) -> some View {
        let active = segmentIndex == index
        return Button {
            segmentIndex = index
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 12))
                Text(title).font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(active ? GhostTheme.gold : GhostTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(active ? GhostTheme.gold.opacity(0.16) : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(active ? GhostTheme.gold.opacity(0.6) : .clear))
        }
    }

    @ViewBuilder
    private var sourcesContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("مستودعاتي")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(.white)
                Text("اختر المستودع الذي يحتوي على سورسك")
                    .font(.system(size: 11))
                    .foregroundColor(GhostTheme.textSecondary)
            }
            Spacer()
            HStack {
                Image(systemName: "magnifyingglass").foregroundColor(GhostTheme.textSecondary)
                TextField("البحث في المستودعات...", text: $searchQuery)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 190)
            .ghostCard()
        }

        if vm.selectedRepo != nil {
            branchAndFileSelector
        }

        if vm.currentUser == nil {
            Text("قم بتسجيل الدخول أولاً لجلب مستودعات حسابك من GitHub.")
                .font(.system(size: 13))
                .foregroundColor(GhostTheme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(24)
                .ghostCard()
        } else if vm.isLoadingRepos {
            ProgressView("جارِ جلب المستودعات...")
                .tint(GhostTheme.gold)
                .padding(24)
        } else {
            ForEach(filteredRepos) { repo in
                let isSelected = vm.selectedRepo?.id == repo.id
                Button {
                    customPathText = "apps.json"
                    Task { await vm.selectRepository(repo) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(repo.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                            Text(repo.description ?? repo.fullName)
                                .font(.system(size: 12))
                                .foregroundColor(GhostTheme.textSecondary)
                                .lineLimit(1)
                            HStack(spacing: 12) {
                                Label(repo.isPrivate ? "خاص" : "عام", systemImage: repo.isPrivate ? "lock.fill" : "globe")
                                    .foregroundColor(repo.isPrivate ? GhostTheme.gold : GhostTheme.textSecondary)
                                Label(repo.defaultBranch, systemImage: "arrow.triangle.branch")
                                    .foregroundColor(GhostTheme.textSecondary)
                            }
                            .font(.system(size: 11))
                        }
                        Spacer()
                        if isSelected {
                            Text("✓ محدد")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(GhostTheme.gold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(GhostTheme.gold.opacity(0.16))
                                .clipShape(Capsule())
                        }
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13))
                            .foregroundColor(GhostTheme.textSecondary)
                    }
                    .padding(16)
                    .ghostCard(highlighted: isSelected)
                }
            }
        }
    }

    private var branchAndFileSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("الفرع وملف السورس (JSON)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(GhostTheme.gold)

            HStack {
                Text("الفرع:")
                    .font(.system(size: 12))
                    .foregroundColor(GhostTheme.textSecondary)
                Picker("الفرع", selection: Binding(
                    get: { vm.selectedBranch },
                    set: { newVal in Task { await vm.changeBranch(newVal) } }
                )) {
                    ForEach(vm.branches) { br in
                        Text(br.name).tag(br.name)
                    }
                }
                .tint(GhostTheme.gold)

                Spacer()

                Menu {
                    ForEach(vm.candidateFiles, id: \.self) { path in
                        Button(path) {
                            vm.selectedFilePath = path
                            customPathText = path
                            Task { await vm.loadSelectedSourceFile() }
                        }
                    }
                } label: {
                    Label(vm.selectedFilePath, systemImage: "doc.badge.gearshape")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GhostTheme.gold)
                }
            }

            HStack {
                TextField("مسار ملف مخصص (مثلاً apps.json)", text: $customPathText)
                    .font(.system(size: 12, design: .monospaced))
                    .environment(\.layoutDirection, .leftToRight)
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("تحميل") {
                    vm.selectedFilePath = customPathText.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await vm.loadSelectedSourceFile() }
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(GhostTheme.goldGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            if vm.missingSourceFilePrompt {
                VStack(alignment: .leading, spacing: 8) {
                    Text("الملف غير موجود بعد في هذا الفرع. هل تريد إنشاء ملف مصدر جديد؟")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(GhostTheme.gold)
                    Button("تأكيد إنشاء ملف سورس جديد") {
                        Task { await vm.createNewStarterSourceFile() }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(GhostTheme.goldGradient)
                    .clipShape(Capsule())
                }
            }

            if let err = vm.sourceError {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(GhostTheme.danger)
            }
        }
        .padding(16)
        .ghostCard()
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("إعدادات الأمان والمصدر")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text("• يُخزن التوكن في iOS Keychain فقط بحماية kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly.")
                .font(.system(size: 12))
                .foregroundColor(GhostTheme.textSecondary)
            Text("• يتم التحقق من SHA للملف قبل كل عملية حفظ لمنع الكتابة فوق تعديلات أحدث بصمت.")
                .font(.system(size: 12))
                .foregroundColor(GhostTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .ghostCard()
    }

    private var aboutContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ghost Source Manager لنظام iOS")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
            Text("مدير مصادر متكامل لـ AltStore و SideStore و LiveContainer يعمل مباشرة عبر GitHub API دون خوادم وسيطة.")
                .font(.system(size: 12))
                .foregroundColor(GhostTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .ghostCard()
    }
}
