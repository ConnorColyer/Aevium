import Foundation

@MainActor
final class InstrumentWatchlistStore: ObservableObject {
    nonisolated static let defaultStorageKey = "Aevium.instrumentWatchlist.v1"

    @Published private(set) var instruments: [InstrumentMetadata] {
        didSet {
            persist()
        }
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private let maxItems: Int

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = InstrumentWatchlistStore.defaultStorageKey,
        maxItems: Int = 24,
        seed: [InstrumentMetadata] = InstrumentWatchlistStore.defaultInstruments
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.maxItems = max(1, maxItems)
        self.instruments = Self.load(
            defaults: defaults,
            storageKey: storageKey,
            maxItems: max(1, maxItems),
            seed: seed
        )

        persist()
    }

    func contains(_ instrument: InstrumentMetadata) -> Bool {
        contains(id: instrument.id)
    }

    func contains(id: InstrumentID) -> Bool {
        instruments.contains { $0.id == id }
    }

    func toggle(_ instrument: InstrumentMetadata) {
        if contains(instrument) {
            remove(id: instrument.id)
        } else {
            add(instrument)
        }
    }

    func add(_ instrument: InstrumentMetadata) {
        var next = instruments.filter { $0.id != instrument.id }
        next.insert(instrument, at: 0)
        instruments = Array(next.prefix(maxItems))
    }

    func remove(id: InstrumentID) {
        instruments.removeAll { $0.id == id }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source
            .sorted()
            .compactMap { index in instruments.indices.contains(index) ? instruments[index] : nil }
        guard !moving.isEmpty else { return }

        var next = instruments
        for index in source.sorted().reversed() where next.indices.contains(index) {
            next.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let insertionIndex = min(max(0, destination - removedBeforeDestination), next.count)
        next.insert(contentsOf: moving, at: insertionIndex)
        instruments = next
    }

    func clear() {
        instruments = []
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(instruments) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func load(
        defaults: UserDefaults,
        storageKey: String,
        maxItems: Int,
        seed: [InstrumentMetadata]
    ) -> [InstrumentMetadata] {
        if
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([InstrumentMetadata].self, from: data)
        {
            return unique(decoded, maxItems: maxItems)
        }

        return unique(seed, maxItems: maxItems)
    }

    private static func unique(_ instruments: [InstrumentMetadata], maxItems: Int) -> [InstrumentMetadata] {
        var seen = Set<InstrumentID>()
        var result: [InstrumentMetadata] = []
        result.reserveCapacity(min(maxItems, instruments.count))

        for instrument in instruments where !seen.contains(instrument.id) {
            seen.insert(instrument.id)
            result.append(instrument)
            if result.count == maxItems {
                break
            }
        }

        return result
    }

    nonisolated private static let defaultInstruments: [InstrumentMetadata] = [
        InstrumentMetadata(
            id: InstrumentID(type: .crypto, symbol: "BTCUSDT"),
            displaySymbol: "BTC / USDT",
            name: "Bitcoin",
            exchange: "Binance",
            currency: "USDT",
            provider: "binance",
            session: "24/7"
        ),
        InstrumentMetadata(
            id: InstrumentID(type: .crypto, symbol: "ETHUSDT"),
            displaySymbol: "ETH / USDT",
            name: "Ethereum",
            exchange: "Binance",
            currency: "USDT",
            provider: "binance",
            session: "24/7"
        ),
        InstrumentMetadata(
            id: InstrumentID(type: .crypto, symbol: "SOLUSDT"),
            displaySymbol: "SOL / USDT",
            name: "Solana",
            exchange: "Binance",
            currency: "USDT",
            provider: "binance",
            session: "24/7"
        )
    ]
}
