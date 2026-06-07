import SwiftUI

@main
struct AeviumApp: App {
    @StateObject private var environment = AppEnvironment()
    @StateObject private var updater = AppUpdater()

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
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }

        Settings {
            AeviumSettingsView()
                .preferredColorScheme(.dark)
        }
    }
}
