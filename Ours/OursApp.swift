import SwiftUI
import CoreText
import FirebaseCore
import UIKit

final class FellowshipAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions:
                     [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        if let url = Bundle.main.url(forResource: "CormorantGaramond-SemiBold", withExtension: "ttf") {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
        return true
    }
}

@main
struct FellowshipApp: App {
    @UIApplicationDelegateAdaptor(FellowshipAppDelegate.self) var appDelegate
    @StateObject private var viewModel = AppViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var didSeeInitialActive = false

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
            guard phase == .active else { return }
            // First .active on launch is handled by HomeView.task → loadAll().
            // Only sync on subsequent foregrounding to avoid a redraw storm.
            guard didSeeInitialActive else {
                didSeeInitialActive = true
                return
            }
            if viewModel.coupleID != nil {
                Task { await viewModel.syncFromCloud() }
            }
        }
    }
}
