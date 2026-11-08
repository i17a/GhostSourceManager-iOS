import SwiftUI

struct MainTabContainerView: View {
    @EnvironmentObject private var vm: SourceManagerViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            GhostTheme.background.ignoresSafeArea()

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

            customBottomBar
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
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
        HStack(alignment: .bottom, spacing: 0) {
            tabItem(tab: .home, icon: "house", title: "الرئيسية")
            tabItem(tab: .sources, icon: "folder.fill", title: "المصادر")

            Button {
                vm.editingApp = nil
                vm.selectedTab = .addIPA
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [GhostTheme.violetGlow, Color(red: 0.25, green: 0.10, blue: 0.45)],
                                    center: .center,
                                    startRadius: 4,
                                    endRadius: 30
                                )
                            )
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(GhostTheme.violetGlow, lineWidth: 1.5))
                            .shadow(color: GhostTheme.violetGlow.opacity(0.65), radius: 14)

                        Image(systemName: "plus")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .offset(y: -14)

                    Text("إضافة IPA")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(vm.selectedTab == .addIPA ? GhostTheme.gold : GhostTheme.textSecondary)
                        .offset(y: -10)
                }
                .frame(maxWidth: .infinity)
            }

            tabItem(tab: .apps, icon: "square.grid.2x2", title: "التطبيقات")
            tabItem(tab: .reports, icon: "chart.bar", title: "التقارير")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .ghostCard()
    }

    private func tabItem(tab: MainTab, icon: String, title: String) -> some View {
        let isSelected = vm.selectedTab == tab
        return Button {
            vm.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                Capsule()
                    .fill(isSelected ? GhostTheme.gold : .clear)
                    .frame(width: 24, height: 2.5)
            }
            .foregroundColor(isSelected ? GhostTheme.gold : GhostTheme.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }
}
