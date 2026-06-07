import Foundation
import Sparkle

@MainActor
final class AppUpdater: NSObject, ObservableObject, SPUUpdaterDelegate {
    static let feedURLString = "https://connorcolyer.github.io/Aevium/appcast.xml"

    @Published private(set) var canCheckForUpdates = false

    private lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil
    )
    private var canCheckObservation: NSKeyValueObservation?
    private let isConfigured: Bool

    init(bundle: Bundle = .main) {
        isConfigured = !Self.isRunningTests && Self.hasRequiredConfiguration(in: bundle)
        super.init()

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

    func feedURLString(for updater: SPUUpdater) -> String? {
        Self.feedURLString
    }

    private static func hasRequiredConfiguration(in bundle: Bundle) -> Bool {
        guard
            let publicKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        else {
            return false
        }

        let sanitizedPublicKey = publicKey.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let parsedFeedURL = URL(string: feedURLString),
            let host = parsedFeedURL.host,
            !host.isEmpty
        else {
            return false
        }

        return !sanitizedPublicKey.isEmpty &&
            !sanitizedPublicKey.contains("REPLACE_WITH_SPARKLE_PUBLIC_ED_KEY")
    }

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
