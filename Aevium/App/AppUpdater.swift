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
    private let currentBundleVersion: String
    private let isConfigured: Bool

    init(bundle: Bundle = .main) {
        currentBundleVersion = Self.bundleVersion(in: bundle)
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

    func bestValidUpdate(in appcast: SUAppcast, for updater: SPUUpdater) -> SUAppcastItem? {
        let comparator = SUStandardVersionComparator.default

        let bestItem = appcast.items
            .filter { item in
                item.isMacOsUpdate &&
                item.minimumOperatingSystemVersionIsOK &&
                item.maximumOperatingSystemVersionIsOK &&
                item.minimumUpdateVersionIsOK &&
                !item.isInformationOnlyUpdate &&
                comparator.compareVersion(currentBundleVersion, toVersion: item.versionString) == .orderedAscending
            }
            .max { lhs, rhs in
                comparator.compareVersion(lhs.versionString, toVersion: rhs.versionString) == .orderedAscending
            }

        if let bestItem {
            NSLog("Sparkle selected update %@ over installed build %@", bestItem.versionString, currentBundleVersion)
            return bestItem
        }

        NSLog("Sparkle found no update newer than installed build %@", currentBundleVersion)
        return SUAppcastItem.empty()
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

    private static func bundleVersion(in bundle: Bundle) -> String {
        if let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            let sanitizedBuildVersion = buildVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sanitizedBuildVersion.isEmpty {
                return sanitizedBuildVersion
            }
        }

        if let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            let sanitizedShortVersion = shortVersion.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sanitizedShortVersion.isEmpty {
                return sanitizedShortVersion
            }
        }

        return "0"
    }
}
