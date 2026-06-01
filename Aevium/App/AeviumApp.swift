import SwiftUI

@main
struct AeviumApp: App {
    init() {
        UserDefaults.standard.register(defaults: [
            "AppleMenuBarVisibleInFullscreen": false
        ])
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 1100, minHeight: 720)
        }
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
    }
}
