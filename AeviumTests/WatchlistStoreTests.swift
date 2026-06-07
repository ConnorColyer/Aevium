import XCTest
@testable import Aevium

final class WatchlistStoreTests: XCTestCase {
    @MainActor
    func testWatchlistPersistsOrderingAndReplacesDuplicates() throws {
        let defaults = try makeDefaults()
        let store = InstrumentWatchlistStore(defaults: defaults, storageKey: "watchlist", maxItems: 4, seed: [])

        store.add(Self.btc)
        store.add(Self.eth)
        store.add(Self.btcRenamed)

        XCTAssertEqual(store.instruments.map(\.id.symbol), ["BTCUSDT", "ETHUSDT"])
        XCTAssertEqual(store.instruments.first?.name, "Bitcoin Reloaded")

        let reloaded = InstrumentWatchlistStore(defaults: defaults, storageKey: "watchlist", maxItems: 4, seed: [])
        XCTAssertEqual(reloaded.instruments.map(\.id.symbol), ["BTCUSDT", "ETHUSDT"])
        XCTAssertEqual(reloaded.instruments.first?.name, "Bitcoin Reloaded")
    }

    @MainActor
    func testWatchlistToggleRemoveAndMaxItems() throws {
        let defaults = try makeDefaults()
        let store = InstrumentWatchlistStore(defaults: defaults, storageKey: "watchlist", maxItems: 3, seed: [])

        store.add(Self.btc)
        store.add(Self.eth)
        store.add(Self.sol)
        store.add(Self.bnb)

        XCTAssertEqual(store.instruments.map(\.id.symbol), ["BNBUSDT", "SOLUSDT", "ETHUSDT"])
        XCTAssertFalse(store.contains(Self.btc))

        store.toggle(Self.sol)
        XCTAssertEqual(store.instruments.map(\.id.symbol), ["BNBUSDT", "ETHUSDT"])
        XCTAssertFalse(store.contains(Self.sol))

        store.toggle(Self.btc)
        XCTAssertEqual(store.instruments.map(\.id.symbol), ["BTCUSDT", "BNBUSDT", "ETHUSDT"])
        XCTAssertTrue(store.contains(Self.btc))
    }

    @MainActor
    func testRecentInstrumentsPersistAndRefreshOrdering() throws {
        let defaults = try makeDefaults()
        let store = RecentInstrumentStore(defaults: defaults, storageKey: "recents", maxItems: 3)

        store.remember(Self.btc)
        store.remember(Self.eth)
        store.remember(Self.btcRenamed)
        store.remember(Self.sol)

        XCTAssertEqual(store.instruments.map(\.id.symbol), ["SOLUSDT", "BTCUSDT", "ETHUSDT"])
        XCTAssertEqual(store.instruments[1].name, "Bitcoin Reloaded")

        let reloaded = RecentInstrumentStore(defaults: defaults, storageKey: "recents", maxItems: 3)
        XCTAssertEqual(reloaded.instruments.map(\.id.symbol), ["SOLUSDT", "BTCUSDT", "ETHUSDT"])
        XCTAssertEqual(reloaded.instruments[1].name, "Bitcoin Reloaded")
    }

    func testMergedQuickAccessDedupesAndExcludesCurrentInstrument() {
        let merged = InstrumentCollection.mergedUnique(
            primary: [Self.btc, Self.eth, Self.sol],
            secondary: [Self.eth, Self.bnb, Self.btcRenamed],
            excluding: Self.eth.id,
            limit: 4
        )

        XCTAssertEqual(merged.map(\.id.symbol), ["BTCUSDT", "SOLUSDT", "BNBUSDT"])
        XCTAssertEqual(merged.first?.name, "Bitcoin")
    }

    @MainActor
    func testWorkspacePreferencesPersistAndRestoreDefaults() throws {
        let defaults = try makeDefaults()
        let store = WorkspacePreferencesStore(defaults: defaults, storageKey: "workspace")

        XCTAssertEqual(store.preferences, WorkspacePreferences())

        store.update { preferences in
            preferences.selectedTabRawValue = "market"
            preferences.selectedInstrument = Self.eth
            preferences.selectedRangeRawValue = "1M"
            preferences.selectedForesightRawValue = "1H"
            preferences.selectedIndicatorRawValues = ["EMA 20", "VWAP"]
            preferences.isInspectorOpen = false
            preferences.selectedInspectorPanelRawValue = "Risk"
            preferences.chartSmoothness = 0.4
        }

        let reloaded = WorkspacePreferencesStore(defaults: defaults, storageKey: "workspace")
        XCTAssertEqual(reloaded.preferences.selectedTabRawValue, "market")
        XCTAssertEqual(reloaded.preferences.selectedInstrument?.id.symbol, "ETHUSDT")
        XCTAssertEqual(reloaded.preferences.selectedRangeRawValue, "1M")
        XCTAssertEqual(reloaded.preferences.selectedForesightRawValue, "1H")
        XCTAssertEqual(reloaded.preferences.selectedIndicatorRawValues, ["EMA 20", "VWAP"])
        XCTAssertEqual(reloaded.preferences.isInspectorOpen, false)
        XCTAssertEqual(reloaded.preferences.selectedInspectorPanelRawValue, "Risk")
        XCTAssertEqual(reloaded.preferences.chartSmoothness, 0.4)
    }

    @MainActor
    func testWorkspacePreferencesFallbackToDefaultOnInvalidPayload() throws {
        let defaults = try makeDefaults()
        defaults.set(Data("not-json".utf8), forKey: "workspace")

        let reloaded = WorkspacePreferencesStore(defaults: defaults, storageKey: "workspace")
        XCTAssertEqual(reloaded.preferences, WorkspacePreferences())
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "AeviumWatchlistTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private static let btc = instrument("BTCUSDT", display: "BTC / USDT", name: "Bitcoin")
    private static let btcRenamed = instrument("BTCUSDT", display: "BTC / USDT", name: "Bitcoin Reloaded")
    private static let eth = instrument("ETHUSDT", display: "ETH / USDT", name: "Ethereum")
    private static let sol = instrument("SOLUSDT", display: "SOL / USDT", name: "Solana")
    private static let bnb = instrument("BNBUSDT", display: "BNB / USDT", name: "BNB")

    private static func instrument(_ symbol: String, display: String, name: String) -> InstrumentMetadata {
        InstrumentMetadata(
            id: InstrumentID(type: .crypto, symbol: symbol),
            displaySymbol: display,
            name: name,
            exchange: "Binance",
            currency: "USDT",
            provider: "binance",
            session: "24/7"
        )
    }
}
