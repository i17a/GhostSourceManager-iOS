import SwiftUI

struct TokenLoginView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var tokenInput: String = ""
    @State private var revealToken: Bool = false

    var body: some View {
        ZStack {
            GhostTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.backward")
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .ghostCard()
                        }
                        Spacer()
                    }

                    VStack(spacing: 8) {
                        Image("GhostMascot")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 132, height: 132)
                            .shadow(color: GhostTheme.violetGlow.opacity(0.75), radius: 22)

                        Text("Ghost Source Manager")
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("إدارة مصادر التطبيقات بسهولة")
                            .font(.system(size: 13))
                            .foregroundColor(GhostTheme.textSecondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("تسجيل الدخول")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                Text("أدخل GitHub Personal Access Token للمتابعة")
                                    .font(.system(size: 12))
                                    .foregroundColor(GhostTheme.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "person.badge.key.fill")
                                .font(.system(size: 24))
                                .foregroundColor(GhostTheme.gold)
                        }

                        HStack {
                            Image(systemName: "key.fill")
                                .foregroundColor(GhostTheme.gold)
                            Group {
                                if revealToken {
                                    TextField("ghp_XXXXXXXXXXXXXXXXXXXX", text: $tokenInput)
                                } else {
                                    SecureField("ghp_XXXXXXXXXXXXXXXXXXXX", text: $tokenInput)
                                }
                            }
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .environment(\.layoutDirection, .leftToRight)
                            .foregroundColor(.white)

                            Button { revealToken.toggle() } label: {
                                Image(systemName: revealToken ? "eye" : "eye.slash")
                                    .foregroundColor(GhostTheme.textSecondary)
                            }
                        }
                        .padding(14)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(GhostTheme.borderSubtle))

                        if let err = vm.authError {
                            Text(err)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(GhostTheme.danger)
                        }

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(GhostTheme.gold)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("معلومات مهمة")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(GhostTheme.gold)
                                Text("يُحفظ التوكن حصراً في iOS Keychain المشفر على جهازك ولا يُرسل لأي خادم وسيط. تأكد من منح صلاحية repo لقراءة وكتابة ملفات المصدر ورفع ملفات Release.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.82))
                            }
                        }
                        .padding(12)
                        .background(GhostTheme.gold.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        Button {
                            Task { await vm.authenticate(with: tokenInput, saveToKeychain: true) }
                        } label: {
                            HStack {
                                if vm.isAuthenticating {
                                    ProgressView().tint(.black)
                                } else {
                                    Text("تسجيل الدخول")
                                        .font(.system(size: 16, weight: .heavy))
                                }
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(GhostTheme.goldGradient)
                            .clipShape(Capsule())
                        }
                        .disabled(vm.isAuthenticating || tokenInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(20)
                    .background(GhostTheme.heroGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(GhostTheme.violetGlow.opacity(0.45)))

                    permissionsGuideCard
                }
                .padding(16)
            }
        }
    }

    private var permissionsGuideCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(GhostTheme.gold)
                Text("كيف تحصل على التوكن؟")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("أنشئ Personal Access Token من إعدادات GitHub مع الصلاحيات:")
                .font(.system(size: 12))
                .foregroundColor(GhostTheme.textSecondary)

            Label("repo — قراءة وكتابة المستودعات ورفع الإصدارات", systemImage: "checkmark")
                .font(.system(size: 12))
                .foregroundColor(.white)
            Label("public_repo — للمستودعات العامة فقط عند الرغبة", systemImage: "checkmark")
                .font(.system(size: 12))
                .foregroundColor(.white)
            Label("workflow — لتشغيل GitHub Actions عند الحاجة", systemImage: "checkmark")
                .font(.system(size: 12))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .ghostCard()
    }
}
