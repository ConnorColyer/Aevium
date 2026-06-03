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
