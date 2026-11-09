import SwiftUI
import UIKit

struct TokenLoginView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var tokenInput = ""
    @State private var revealToken = false
    @State private var showManualToken = false

    var body: some View {
        ZStack {
            GhostTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    HStack {
                        Button {
                            vm.cancelGitHubDeviceFlow()
                            dismiss()
                        } label: {
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
                            .frame(width: 112, height: 112)
                            .shadow(color: GhostTheme.violetGlow.opacity(0.75), radius: 20)

                        Text("SideSource")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                        Text("تسجيل آمن عبر GitHub App")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(GhostTheme.textSecondary)
                        Text("@\(SideSourceGitHubApp.owner) · App ID \(SideSourceGitHubApp.appID)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(GhostTheme.textSecondary.opacity(0.8))
                    }

                    deviceFlowCard

                    if let err = vm.authError {
                        Text(err)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(GhostTheme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(GhostTheme.danger.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityIdentifier("loginError")
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showManualToken.toggle() }
                    } label: {
                        Label(showManualToken ? "إخفاء إدخال التوكن اليدوي" : "خيار بديل: إدخال توكن يدويًا", systemImage: "key.horizontal")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(GhostTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .accessibilityIdentifier("toggleManualToken")

                    if showManualToken { manualTokenCard }
                    permissionsGuideCard
                }
                .padding(16)
            }
        }
        .onDisappear {
            if vm.isDeviceFlowPolling || vm.isRequestingDeviceCode {
                vm.cancelGitHubDeviceFlow()
            }
        }
    }

    private var deviceFlowCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 24))
                    .foregroundColor(GhostTheme.gold)
                VStack(alignment: .leading, spacing: 3) {
                    Text("تسجيل الدخول عبر GitHub")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                    Text("من دون كتابة أو نسخ توكن شخصي")
                        .font(.system(size: 11))
                        .foregroundColor(GhostTheme.textSecondary)
                }
                Spacer()
            }

            Text("سننشئ رمزًا مؤقتًا من 8 خانات. أدخله في GitHub للموافقة، وسيتم اكتشافها وحفظ الدخول تلقائيًا.")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            if let code = vm.deviceFlowCode {
                Text(code)
                    .font(.system(size: 30, weight: .heavy, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(GhostTheme.gold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.black.opacity(0.34))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .accessibilityIdentifier("githubDeviceCode")

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = code
                    } label: {
                        Label("نسخ الرمز", systemImage: "doc.on.doc")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(Color.white.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("copyGitHubDeviceCode")

                    Button {
                        openURL(vm.deviceFlowURL ?? SideSourceGitHubApp.deviceVerificationURL)
                    } label: {
                        Label("فتح GitHub", systemImage: "safari")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(GhostTheme.goldGradient)
                            .clipShape(Capsule())
                    }
                    .accessibilityIdentifier("openGitHubDevicePage")
                }
            } else {
                Button {
                    vm.startGitHubDeviceFlow()
                } label: {
                    HStack(spacing: 9) {
                        if vm.isRequestingDeviceCode {
                            ProgressView().tint(.black)
                        } else {
                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 16, weight: .bold))
                        }
                        Text(vm.isRequestingDeviceCode ? "جارٍ الاتصال بـ GitHub…" : "تسجيل الدخول عبر GitHub")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GhostTheme.goldGradient)
                    .clipShape(Capsule())
                }
                .disabled(vm.isRequestingDeviceCode || vm.isDeviceFlowPolling)
                .accessibilityIdentifier("githubDeviceLogin")
            }

            if let status = vm.deviceFlowStatus {
                HStack(alignment: .top, spacing: 8) {
                    if vm.isDeviceFlowPolling { ProgressView().tint(GhostTheme.gold) }
                    Text(status)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(GhostTheme.gold)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .accessibilityIdentifier("deviceFlowStatus")
            }

            if vm.isDeviceFlowPolling {
                Button("إلغاء تسجيل الدخول") { vm.cancelGitHubDeviceFlow() }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(GhostTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("cancelGitHubDeviceFlow")
            }
        }
        .padding(18)
        .background(GhostTheme.heroGradient)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(GhostTheme.violetGlow.opacity(0.45)))
    }

    private var manualTokenCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("الدخول بتوكن يدوي")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            HStack {
                Image(systemName: "key.fill").foregroundColor(GhostTheme.gold)
                Group {
                    if revealToken {
                        TextField("ghp_… أو ghu_…", text: $tokenInput)
                    } else {
                        SecureField("ghp_… أو ghu_…", text: $tokenInput)
                    }
                }
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .environment(\.layoutDirection, .leftToRight)
                .foregroundColor(.white)
                .accessibilityIdentifier("manualGitHubToken")

                Button { revealToken.toggle() } label: {
                    Image(systemName: revealToken ? "eye" : "eye.slash")
                        .foregroundColor(GhostTheme.textSecondary)
                }
            }
            .padding(14)
            .background(Color.black.opacity(0.35))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(GhostTheme.borderSubtle))

            Button {
                KeychainService.deleteRefreshToken()
                Task { await vm.authenticate(with: tokenInput, saveToKeychain: true) }
            } label: {
                HStack {
                    if vm.isAuthenticating { ProgressView().tint(.black) }
                    Text("تسجيل الدخول بالتوكن")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(GhostTheme.goldGradient)
                .clipShape(Capsule())
            }
            .disabled(vm.isAuthenticating || tokenInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("manualTokenLogin")

            Text("التوكن يُحفظ في Keychain المشفر على هذا الجهاز فقط.")
                .font(.system(size: 10))
                .foregroundColor(GhostTheme.textSecondary)
        }
        .padding(16)
        .ghostCard()
    }

    private var permissionsGuideCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill").foregroundColor(GhostTheme.gold)
                Text("عن صلاحيات التطبيق")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(GhostTheme.gold)
            }
            Text("صلاحيات الدخول يحددها GitHub App بعد موافقتك. يستخدم SideSource الصلاحيات التي وافقت عليها لإدارة المستودعات وملفات JSON ورفع Releases وتشغيل Actions عند توفر الإذن.")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
            Text("لا يمر التوكن عبر خادم وسيط ولا يُكتب في السجلات.")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(GhostTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(GhostTheme.gold.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
