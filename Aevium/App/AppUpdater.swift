import Foundation
import Sparkle

@MainActor
final class AppUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private let updaterController: SPUStandardUpdaterController
    private var canCheckObservation: NSKeyValueObservation?
    private let isConfigured: Bool

    init(bundle: Bundle = .main) {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        isConfigured = !Self.isRunningTests && Self.hasRequiredConfiguration(in: bundle)

        guard isConfigured else {
            return
        }

        let updater = updaterController.updater
        canCheckObservation = updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor [weak self] in
                self?.canCheckForUpdates = updater.canCheckForUpdates
            }
        }

        do {
            try updater.start()

            if updater.automaticallyChecksForUpdates {
                updater.checkForUpdatesInBackground()
            }
        } catch {
            NSLog("Sparkle failed to start: \(error.localizedDescription)")
        }
    }

    func checkForUpdates() {
        guard isConfigured else {
            return
        }

        updaterController.updater.checkForUpdates()
    }

    private static func hasRequiredConfiguration(in bundle: Bundle) -> Bool {
        guard
            let feedURL = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else {
            return false
        }

        let sanitizedFeedURL = feedURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedPublicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let parsedFeedURL = URL(string: sanitizedFeedURL),
            let host = parsedFeedURL.host,
            !host.isEmpty
        else {
            return false
        }

        return !sanitizedFeedURL.isEmpty &&
            !sanitizedPublicKey.isEmpty &&
            !sanitizedPublicKey.contains("REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY")
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
