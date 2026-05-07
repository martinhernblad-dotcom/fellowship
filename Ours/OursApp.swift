import SwiftUI

@main
struct FellowshipApp: App {
    @StateObject private var viewModel = AppViewModel()

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
            .fontDesign(.rounded)
        }
    }
}
