import SwiftUI

@main
struct AeviumApp: App {
    @StateObject private var environment = AppEnvironment()

    init() {
        UserDefaults.standard.register(defaults: [
            "AppleMenuBarVisibleInFullscreen": false
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(environment)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)

        Settings {
            AeviumSettingsView()
                .preferredColorScheme(.dark)
        }
    }
}
