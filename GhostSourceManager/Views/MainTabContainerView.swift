import SwiftUI
import UIKit

struct MainTabContainerView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel
    @State private var keyboardVisible = false

    var body: some View {
        VStack(spacing: 0) {
            if vm.selectedTab != .addIPA {
                topHeader
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }

            Group {
                switch vm.selectedTab {
                case .home, .sources:
                    SourcesDashboardView()
                case .addIPA:
                    AddIPAPublishView()
                case .apps:
                    AppsListAndJSONView()
                case .reports:
                    ReportsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(GhostTheme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !keyboardVisible { customBottomBar }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
        .sheet(isPresented: $vm.showLoginSheet) {
            TokenLoginView()
                .environmentObject(vm)
        }
    }

    private var topHeader: some View {
        HStack {
            Image("GhostMascot")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .padding(6)
                .background(GhostTheme.cardTop)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(GhostTheme.violetGlow.opacity(0.6), lineWidth: 1)
                )

            Spacer()

            VStack(spacing: 2) {
                Text("Ghost Source Manager")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(GhostTheme.textPrimary)
                Text("إدارة مصادر التطبيقات بسهولة")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(GhostTheme.textSecondary)
            }

            Spacer()

            Button {
                vm.showLoginSheet = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(GhostTheme.textPrimary)
                    .frame(width: 42, height: 42)
                    .ghostCard()
            }
        }
    }

    private var customBottomBar: some View {
        HStack(spacing: 0) {
            tabItem(tab: .home, icon: "house", title: "الرئيسية")
            tabItem(tab: .sources, icon: "folder.fill", title: "المصادر")
            addIPATab
            tabItem(tab: .apps, icon: "square.grid.2x2", title: "التطبيقات")
            tabItem(tab: .reports, icon: "chart.bar", title: "التقارير")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 64)
        .background {
            GhostTheme.cardTop
                .overlay(alignment: .top) {
                    Rectangle().fill(GhostTheme.violetGlow.opacity(0.45)).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private var addIPATab: some View {
        Button {
            vm.editingApp = nil
            vm.selectedTab = .addIPA
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [GhostTheme.violetGlow, Color(red: 0.25, green: 0.10, blue: 0.45)],
                            center: .center,
                            startRadius: 4,
                            endRadius: 28
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(Circle().stroke(GhostTheme.violetGlow, lineWidth: 1.5))
                    .shadow(color: GhostTheme.violetGlow.opacity(0.55), radius: 10)
                Image(systemName: "plus")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(vm.selectedTab == .addIPA ? GhostTheme.gold : .clear)
                    .frame(width: 22, height: 2)
                    .padding(.bottom, 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.addIPA")
    }

    private func tabItem(tab: MainTab, icon: String, title: String) -> some View {
        let isSelected = vm.selectedTab == tab
        return Button {
            vm.selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Capsule()
                    .fill(isSelected ? GhostTheme.gold : .clear)
                    .frame(width: 22, height: 2)
            }
            .foregroundColor(isSelected ? GhostTheme.gold : GhostTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(tab.accessibilityKey)")
    }
}

private extension MainTab {
    var accessibilityKey: String {
        switch self {
        case .home: return "home"
        case .sources: return "sources"
        case .addIPA: return "addIPA"
        case .apps: return "apps"
        case .reports: return "reports"
        }
    }
}
