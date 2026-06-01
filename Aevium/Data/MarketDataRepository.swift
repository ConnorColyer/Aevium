import Foundation

actor MarketDataRepository {
    private let store: SQLiteMarketDataStore
    private let router: ProviderRouter
    private let liveIngestion: LiveIngestionService
    private let backfillService: BackfillService

    init(databaseURL: URL) throws {
        self.store = try SQLiteMarketDataStore(databaseURL: databaseURL)
        self.router = ProviderRouter()
        self.liveIngestion = LiveIngestionService(store: store, router: router)
        self.backfillService = BackfillService(store: store, router: router)
    }

    func defaultInstrument() -> InstrumentMetadata {
        router.defaultInstrument()
    }

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        let cached = try store.cachedInstruments(matching: query)
        let remote = await router.search(query: query)
        let merged = mergeInstruments(cached + remote)

        for instrument in merged {
            try? store.upsertInstrument(instrument)
        }

        return merged
    }

    func resolveInstrument(query: String) -> InstrumentMetadata {
        router.inferInstrument(from: query)
    }

    func subscribeLive(
        instrument: InstrumentMetadata,
        viewport: MarketViewport
    ) async -> AsyncThrowingStream<MarketSeriesSnapshot, Error> {
        await liveIngestion.subscribeLive(instrument: instrument, viewport: viewport)
    }

    func startBackfill(
        instrument: InstrumentMetadata,
        viewport: MarketViewport
    ) async -> AsyncStream<BackfillEvent> {
        await backfillService.startBackfill(instrument: instrument, viewport: viewport)
    }

    func series(instrument: InstrumentMetadata, viewport: MarketViewport) throws -> [LinePoint] {
        try store.linePoints(
            for: instrument.id,
            from: viewport.fromTimestamp,
            limit: viewport.visiblePointTarget,
            minimumResolution: viewport.resolution
        )
    }

    func syncState(instrument: InstrumentMetadata) throws -> SyncState {
        try store.syncState(for: instrument.id)
    }

    func topMovers(limit: Int = 80) async throws -> [MarketMover] {
        let movers = try await router.topMovers(limit: limit)
        for mover in movers {
            try? store.upsertInstrument(mover.instrument)
        }
        return movers
    }

    private func mergeInstruments(_ instruments: [InstrumentMetadata]) -> [InstrumentMetadata] {
        var seen: Set<InstrumentID> = []
        var results: [InstrumentMetadata] = []

        for instrument in instruments where !seen.contains(instrument.id) {
            seen.insert(instrument.id)
            results.append(instrument)
        }

        return Array(results.prefix(12))
    }
}
