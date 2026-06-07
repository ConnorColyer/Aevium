import Foundation

struct InstrumentSelectionRequest: Identifiable {
    let id = UUID()
    let instrument: InstrumentMetadata
}

struct WorkspacePreferences: Codable, Equatable {
    var selectedTabRawValue: String?
    var selectedInstrument: InstrumentMetadata?
    var selectedRangeRawValue: String?
    var selectedForesightRawValue: String?
    var selectedIndicatorRawValues: [String]
    var isInspectorOpen: Bool?
    var selectedInspectorPanelRawValue: String?
    var chartSmoothness: Double?

    init(
        selectedTabRawValue: String? = nil,
        selectedInstrument: InstrumentMetadata? = nil,
        selectedRangeRawValue: String? = nil,
        selectedForesightRawValue: String? = nil,
        selectedIndicatorRawValues: [String] = [],
        isInspectorOpen: Bool? = nil,
        selectedInspectorPanelRawValue: String? = nil,
        chartSmoothness: Double? = nil
    ) {
        self.selectedTabRawValue = selectedTabRawValue
        self.selectedInstrument = selectedInstrument
        self.selectedRangeRawValue = selectedRangeRawValue
        self.selectedForesightRawValue = selectedForesightRawValue
        self.selectedIndicatorRawValues = selectedIndicatorRawValues
        self.isInspectorOpen = isInspectorOpen
        self.selectedInspectorPanelRawValue = selectedInspectorPanelRawValue
        self.chartSmoothness = chartSmoothness
    }
}

@MainActor
final class WorkspacePreferencesStore: ObservableObject {
    nonisolated static let defaultStorageKey = "Aevium.workspacePreferences.v1"

    @Published private(set) var preferences: WorkspacePreferences {
        didSet {
            persist()
        }
    }

    private let defaults: UserDefaults
    private let storageKey: String

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = WorkspacePreferencesStore.defaultStorageKey
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.preferences = Self.load(defaults: defaults, storageKey: storageKey)
        persist()
    }

    func update(_ mutate: (inout WorkspacePreferences) -> Void) {
        var next = preferences
        mutate(&next)
        preferences = next
    }

    func replace(with preferences: WorkspacePreferences) {
        self.preferences = preferences
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func load(defaults: UserDefaults, storageKey: String) -> WorkspacePreferences {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(WorkspacePreferences.self, from: data)
        else {
            return WorkspacePreferences()
        }
        return decoded
    }
}

enum AppCommandAction {
    case focusSearch
    case showHome
    case showMarket
    case toggleInspector
    case toggleWatchlist
}

struct AppCommandRequest: Identifiable {
    let id = UUID()
    let action: AppCommandAction
}

@MainActor
final class AppEnvironment: ObservableObject {
    let marketDataEngine: MarketDataEngine
    let watchlist: InstrumentWatchlistStore
    let recentInstruments: RecentInstrumentStore
    let workspacePreferences: WorkspacePreferencesStore
    @Published var instrumentSelectionRequest: InstrumentSelectionRequest?
    @Published var commandRequest: AppCommandRequest?

    init() {
        watchlist = InstrumentWatchlistStore()
        recentInstruments = RecentInstrumentStore()
        workspacePreferences = WorkspacePreferencesStore()

        do {
            let dbURL = try Self.databaseURL()
            marketDataEngine = try MarketDataEngine(databaseURL: dbURL)
        } catch {
            fatalError("Failed to bootstrap data layer: \(error)")
        }
    }

    func openInstrument(_ instrument: InstrumentMetadata) {
        instrumentSelectionRequest = InstrumentSelectionRequest(instrument: instrument)
    }

    func requestCommand(_ action: AppCommandAction) {
        commandRequest = AppCommandRequest(action: action)
    }

    private static func databaseURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let dir = base.appendingPathComponent("Aevium", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("crypto-market-v2.sqlite")
    }
}
