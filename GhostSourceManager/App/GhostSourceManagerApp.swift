import SwiftUI

@main
struct GhostSourceManagerApp: App {
    @StateObject private var viewModel = SourceManagerViewModel()
    @AppStorage("appLanguageDirectionRTL") private var isRTL: Bool = true

    var body: some Scene {
        WindowGroup {
            MainTabContainerView()
                .environmentObject(viewModel)
                .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
                .preferredColorScheme(.dark)
        }
    }
}
