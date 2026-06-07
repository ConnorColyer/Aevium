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

            CommandMenu("Navigate") {
                Button("Home") {
                    environment.requestCommand(.showHome)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Market") {
                    environment.requestCommand(.showMarket)
                }
                .keyboardShortcut("2", modifiers: .command)

                Divider()

                Button("Focus Search") {
                    environment.requestCommand(.focusSearch)
                }
                .keyboardShortcut("l", modifiers: .command)
            }

            CommandMenu("Workspace") {
                Button("Toggle Watchlist") {
                    environment.requestCommand(.toggleWatchlist)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Toggle Inspector") {
                    environment.requestCommand(.toggleInspector)
                }
                .keyboardShortcut("i", modifiers: .command)
            }
        }

        Settings {
            AeviumSettingsView()
                .preferredColorScheme(.dark)
        }
    }
}
