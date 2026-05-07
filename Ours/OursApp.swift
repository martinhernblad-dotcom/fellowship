import SwiftUI
import CoreText
import FirebaseCore

@main
struct FellowshipApp: App {
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        FirebaseApp.configure()
        if let url = Bundle.main.url(forResource: "CormorantGaramond-SemiBold", withExtension: "ttf") {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if viewModel.isProfileSetup {
                    HomeView()
                } else {
                    ProfileSetupView()
                }
            }
            .environmentObject(viewModel)
            .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, viewModel.coupleID != nil {
                Task { await viewModel.syncFromCloud() }
            }
        }
    }
}
