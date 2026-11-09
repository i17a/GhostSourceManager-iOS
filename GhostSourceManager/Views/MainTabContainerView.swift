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
                Text("SideSource")
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
            .accessibilityIdentifier("openLogin")
        }
    }

    private var customBottomBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                SideSourceFloatingBarShape()
                    .fill(.ultraThinMaterial)
                    .overlay(SideSourceFloatingBarShape().fill(Color.black.opacity(0.66)))
                    .overlay(SideSourceFloatingBarShape().stroke(Color.white.opacity(0.12), lineWidth: 1))
                    .frame(height: 72)
                    .padding(.top, 18)
                    .shadow(color: .black.opacity(0.38), radius: 18, y: 8)

                HStack(spacing: 0) {
                    tabItem(tab: .home, icon: "house", title: "الرئيسية")
                    tabItem(tab: .sources, icon: "folder.fill", title: "المصادر")
                    Color.clear.frame(maxWidth: .infinity)
                    tabItem(tab: .apps, icon: "square.grid.2x2", title: "التطبيقات")
                    tabItem(tab: .reports, icon: "chart.bar", title: "التقارير")
                }
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .padding(.top, 18)
                .environment(\.layoutDirection, .rightToLeft)

                addIPATab
                    .position(x: geometry.size.width / 2, y: 39)
            }
            .frame(height: 90, alignment: .top)
        }
        .frame(height: 90)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
    }

    private var addIPATab: some View {
        Button {
            vm.editingApp = nil
            vm.selectedTab = .addIPA
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [GhostTheme.violetGlow, Color(red: 0.34, green: 0.12, blue: 0.56), Color(red: 0.12, green: 0.06, blue: 0.25)],
                                center: .center,
                                startRadius: 2,
                                endRadius: 32
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(GhostTheme.gold.opacity(0.75), lineWidth: 1.2))
                        .shadow(color: GhostTheme.violetGlow.opacity(0.7), radius: 13)
                    Image(systemName: "plus")
                        .font(.system(size: 25, weight: .medium))
                        .foregroundColor(.white)
                }
                Text("إضافة IPA")
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundColor(vm.selectedTab == .addIPA ? GhostTheme.gold : GhostTheme.textSecondary)
            }
            .frame(width: 74, height: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.addIPA")
    }

    private func tabItem(tab: MainTab, icon: String, title: String) -> some View {
        let isSelected = vm.selectedTab == tab
        return Button {
            vm.selectedTab = tab
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Capsule()
                    .fill(isSelected ? GhostTheme.gold : .clear)
                    .frame(width: 24, height: 2.5)
            }
            .foregroundColor(isSelected ? GhostTheme.gold : GhostTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tab.\(tab.accessibilityKey)")
    }
}

struct SideSourceFloatingBarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 28
        let center = rect.midX
        let shoulder = min(70, rect.width * 0.18)
        let notchHalf = min(54, rect.width * 0.14)
        var path = Path()

        path.move(to: CGPoint(x: radius, y: 0))
        path.addLine(to: CGPoint(x: center - shoulder, y: 0))
        path.addCurve(
            to: CGPoint(x: center - notchHalf, y: 15),
            control1: CGPoint(x: center - shoulder + 10, y: 0),
            control2: CGPoint(x: center - notchHalf - 8, y: 15)
        )
        path.addCurve(
            to: CGPoint(x: center + notchHalf, y: 15),
            control1: CGPoint(x: center - 24, y: 48),
            control2: CGPoint(x: center + 24, y: 48)
        )
        path.addCurve(
            to: CGPoint(x: center + shoulder, y: 0),
            control1: CGPoint(x: center + notchHalf + 8, y: 15),
            control2: CGPoint(x: center + shoulder - 10, y: 0)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: 0))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: radius), control: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - radius), control: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: radius))
        path.addQuadCurve(to: CGPoint(x: radius, y: 0), control: .zero)
        path.closeSubpath()
        return path
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
