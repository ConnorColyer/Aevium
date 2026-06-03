import Foundation

actor MarketDataRepository {
    private let engine: MarketDataEngine

    init(databaseURL: URL) throws {
        self.engine = try MarketDataEngine(databaseURL: databaseURL)
    }

    func defaultInstrument() async -> InstrumentMetadata {
        await engine.defaultInstrument()
    }

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        try await engine.searchInstruments(query: query)
    }

    func resolveInstrument(query: String) async throws -> InstrumentMetadata {
        try await engine.resolveInstrument(query: query)
    }

    func observeSeries(
        instrument: InstrumentMetadata,
        viewport: MarketViewport
    ) async -> AsyncThrowingStream<MarketSeriesUpdate, Error> {
        await engine.observeSeries(instrument: instrument, viewport: viewport)
    }

    func topMovers(limit: Int = 80) async throws -> [MarketMover] {
        try await engine.topMovers(limit: limit)
    }
}
