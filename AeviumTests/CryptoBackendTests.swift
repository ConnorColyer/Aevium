import XCTest
@testable import Aevium

final class CryptoBackendTests: XCTestCase {
    func testSearchRanksExactAndUSDTSymbolsFirst() async throws {
        let engine = try makeEngine()

        let btcResults = try await engine.searchInstruments(query: "BTC")
        XCTAssertEqual(btcResults.first?.id.symbol, "BTCUSDT")
        XCTAssertTrue(btcResults.map(\.id.symbol).contains("BTCUSDC"))

        let ethbtc = try await engine.resolveInstrument(query: "ETHBTC")
        XCTAssertEqual(ethbtc.id.symbol, "ETHBTC")

        let solResults = try await engine.searchInstruments(query: "SOL")
        XCTAssertEqual(solResults.first?.id.symbol, "SOLUSDT")

        let bnbResults = try await engine.searchInstruments(query: "BNB")
        XCTAssertEqual(bnbResults.first?.id.symbol, "BNBETH")
    }

    func testStoreCreatesFreshSchemaAndDoesNotTouchOldDatabase() async throws {
        let directory = temporaryDirectory()
        let oldURL = directory.appendingPathComponent("market-data.sqlite")
        let newURL = directory.appendingPathComponent("crypto-market-v2.sqlite")
        let oldData = Data("legacy database marker".utf8)
        FileManager.default.createFile(atPath: oldURL.path, contents: oldData)

        let store = try CryptoMarketDataStore(databaseURL: newURL)
        try await store.upsertSymbols([Self.btcRecord])

        let symbols = try await store.allSymbols()
        XCTAssertEqual(symbols.map(\.symbol), ["BTCUSDT"])
        XCTAssertEqual(try Data(contentsOf: oldURL), oldData)
    }

    func testStoreUpsertsAndQueriesCandlesWithoutDuplicates() async throws {
        let store = try CryptoMarketDataStore(databaseURL: temporaryDatabaseURL())
        let timestamp = Int64(Date().timeIntervalSince1970) - 120
        let original = CryptoCandle(
            symbol: "BTCUSDT",
            interval: .oneMinute,
            openTime: timestamp,
            closeTime: timestamp + 59,
            open: 100,
            high: 102,
            low: 99,
            close: 101,
            volume: 10
        )
        let replacement = CryptoCandle(
            symbol: "BTCUSDT",
            interval: .oneMinute,
            openTime: timestamp,
            closeTime: timestamp + 59,
            open: 100,
            high: 105,
            low: 98,
            close: 104,
            volume: 12
        )

        try await store.upsertCandles([original, replacement])
        let candles = try await store.candles(
            symbol: "BTCUSDT",
            interval: .oneMinute,
            from: timestamp - 60,
            limit: 10
        )

        XCTAssertEqual(candles.count, 1)
        XCTAssertEqual(candles[0].close, 104)
        XCTAssertEqual(candles[0].high, 105)
    }

    func testEngineEmitsCachedBackfilledAndLiveUpdatesThenCleansUpStream() async throws {
        let store = try CryptoMarketDataStore(databaseURL: temporaryDatabaseURL())
        try await store.upsertSymbols([Self.btcRecord])
        let cachedCandles = shiftedFixtureCandles(startOffset: -240)
        try await store.upsertCandles([cachedCandles[0]])

        let liveCandle = CryptoCandle(
            symbol: "BTCUSDT",
            interval: .oneMinute,
            openTime: Int64(Date().timeIntervalSince1970),
            closeTime: Int64(Date().timeIntervalSince1970) + 59,
            open: 104,
            high: 106,
            low: 103,
            close: 105,
            volume: 14,
            isClosed: false
        )
        let httpClient = FixtureHTTPClient(klines: cachedCandles)
        let webSocketClient = FixtureWebSocketClient(candles: [liveCandle])
        let engine = MarketDataEngine(
            store: store,
            httpClient: httpClient,
            webSocketClient: webSocketClient,
            symbolDirectoryTTL: 3_600
        )
        let stream = await engine.observeSeries(
            instrument: Self.btcRecord.instrument,
            viewport: MarketViewport(range: .hour, resolution: .oneMinute)
        )

        let updates = try await collectFirst(5, from: stream)
        XCTAssertTrue(updates[0].stale)
        XCTAssertEqual(updates[0].state.state, .connecting)
        XCTAssertEqual(updates[1].state.state, .backfilling)
        XCTAssertEqual(updates[2].state.state, .connected)
        XCTAssertFalse(updates[2].stale)
        XCTAssertGreaterThanOrEqual(updates[2].points.count, 3)
        XCTAssertEqual(updates[4].state.state, .connected)
        XCTAssertEqual(updates[4].points.last?.price, 105)

        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertTrue(webSocketClient.streamTerminated)
    }

    func testEquityInstrumentUsesStockProviderInsteadOfBinance() async throws {
        let store = try CryptoMarketDataStore(databaseURL: temporaryDatabaseURL())
        let stockProvider = FixtureStockProvider()
        let webSocketClient = FixtureWebSocketClient(candles: [])
        let engine = MarketDataEngine(
            store: store,
            httpClient: FixtureHTTPClient(klines: []),
            webSocketClient: webSocketClient,
            router: FixtureMarketRouter(stockProvider: stockProvider)
        )

        let stream = await engine.observeSeries(
            instrument: FixtureStockProvider.apple,
            viewport: MarketViewport(range: .hour, resolution: .oneMinute)
        )

        let updates = try await collectFirst(5, from: stream)
        XCTAssertEqual(updates[0].instrument.id.type, .equity)
        XCTAssertEqual(updates[2].instrument.id.symbol, "AAPL")
        XCTAssertEqual(updates[2].points.last?.price, 103)
        XCTAssertEqual(updates[4].points.last?.price, 104)
        XCTAssertFalse(webSocketClient.streamTerminated)
    }

    func testEquityShortWindowKeepsMostRecentTradingSamples() async throws {
        let store = try CryptoMarketDataStore(databaseURL: temporaryDatabaseURL())
        let stockProvider = PreviousSessionStockProvider()
        let engine = MarketDataEngine(
            store: store,
            httpClient: FixtureHTTPClient(klines: []),
            webSocketClient: FixtureWebSocketClient(candles: []),
            router: FixtureMarketRouter(stockProvider: stockProvider)
        )

        let stream = await engine.observeSeries(
            instrument: PreviousSessionStockProvider.apple,
            viewport: MarketViewport(range: .twentyFiveMinutes, resolution: .oneMinute)
        )

        let updates = try await collectFirst(4, from: stream)
        XCTAssertEqual(updates[2].state.state, .connected)
        XCTAssertEqual(updates[2].points.map(\.price), [198, 199, 200])
        XCTAssertLessThan(updates[2].points.last?.timestamp ?? 0, MarketViewport(range: .twentyFiveMinutes).fromTimestamp)
        XCTAssertEqual(updates[3].points.map(\.price), [198, 199, 200])
    }

    func testCompositeStockProviderFallsBackWhenPrimaryRejectsHistory() async throws {
        let provider = CompositeStockProvider(
            primary: RejectingStockProvider(),
            fallback: FixtureStockProvider()
        )

        let results = try await provider.searchInstruments(query: "AAPL")
        XCTAssertEqual(results.first?.id.symbol, "AAPL")

        let latest = try await provider.latestQuote(for: FixtureStockProvider.apple)
        XCTAssertEqual(latest.price, 103)

        let history = try await provider.historicalPoints(
            for: FixtureStockProvider.apple,
            from: Date().addingTimeInterval(-3_600),
            to: Date(),
            resolution: .oneMinute,
            maxPoints: 10
        )
        XCTAssertEqual(history.map(\.price), [101, 102])
    }

    func testInvalidSymbolAndRateLimitFixturesMapToErrors() async throws {
        let engine = try makeEngine()

        do {
            _ = try await engine.resolveInstrument(query: "NOPEUSDT")
            XCTFail("Expected invalid symbol to throw")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("No Binance symbol"))
        }

        let rateLimitResponse = HTTPURLResponse(
            url: URL(string: "https://api.binance.com/api/v3/klines")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertThrowsError(
            try BinanceHTTPClient.validate(
                response: rateLimitResponse,
                data: fixtureData("rateLimit")
            )
        ) { error in
            guard case ProviderError.rateLimited = error else {
                return XCTFail("Expected rate limit error, got \(error)")
            }
        }

        let invalidResponse = HTTPURLResponse(
            url: URL(string: "https://api.binance.com/api/v3/klines")!,
            statusCode: 400,
            httpVersion: nil,
            headerFields: nil
        )!
        XCTAssertThrowsError(
            try BinanceHTTPClient.validate(
                response: invalidResponse,
                data: fixtureData("invalidSymbol")
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("Invalid symbol"))
        }
    }

    private func makeEngine() throws -> MarketDataEngine {
        MarketDataEngine(
            store: try CryptoMarketDataStore(databaseURL: temporaryDatabaseURL()),
            httpClient: FixtureHTTPClient(klines: shiftedFixtureCandles(startOffset: -180)),
            webSocketClient: FixtureWebSocketClient(candles: [])
        )
    }

    private static var btcRecord: BinanceSymbolRecord {
        BinanceSymbolRecord(
            symbol: "BTCUSDT",
            baseAsset: "BTC",
            quoteAsset: "USDT",
            status: "TRADING",
            isSpotTradingAllowed: true
        )
    }
}

private final class FixtureHTTPClient: @unchecked Sendable, BinanceHTTPClientProtocol {
    private let klinesResult: [CryptoCandle]
    private let decoder = JSONDecoder()

    init(klines: [CryptoCandle]) {
        self.klinesResult = klines
    }

    func exchangeInfo() async throws -> BinanceExchangeInfoResponse {
        try decoder.decode(BinanceExchangeInfoResponse.self, from: fixtureData("exchangeInfo"))
    }

    func klines(
        symbol: String,
        interval: BinanceKlineInterval,
        startTime: Int64,
        endTime: Int64,
        limit: Int
    ) async throws -> [CryptoCandle] {
        klinesResult
            .filter { $0.symbol == symbol.uppercased() && $0.openTime >= startTime && $0.openTime <= endTime }
            .prefix(limit)
            .map { candle in
                CryptoCandle(
                    symbol: candle.symbol,
                    interval: interval,
                    openTime: candle.openTime,
                    closeTime: candle.closeTime,
                    open: candle.open,
                    high: candle.high,
                    low: candle.low,
                    close: candle.close,
                    volume: candle.volume,
                    quoteVolume: candle.quoteVolume,
                    tradeCount: candle.tradeCount,
                    isClosed: candle.isClosed
                )
            }
    }

    func twentyFourHourTickers() async throws -> [BinanceTicker24h] {
        try decoder.decode([BinanceTicker24h].self, from: fixtureData("ticker24hr"))
    }
}

private final class FixtureWebSocketClient: @unchecked Sendable, BinanceWebSocketClientProtocol {
    private let candles: [CryptoCandle]
    private let lock = NSLock()
    private var terminated = false

    var streamTerminated: Bool {
        lock.withLock { terminated }
    }

    init(candles: [CryptoCandle]) {
        self.candles = candles
    }

    func klineStream(symbol: String, interval: BinanceKlineInterval) -> AsyncThrowingStream<CryptoCandle, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                for candle in candles {
                    guard !Task.isCancelled else { break }
                    continuation.yield(candle)
                }
                continuation.finish()
            }

            continuation.onTermination = { _ in
                task.cancel()
                self.lock.withLock {
                    self.terminated = true
                }
            }
        }
    }
}

private struct FixtureMarketRouter: MarketDataRouting {
    let stockProvider: any MarketDataProvider

    func provider(for instrument: InstrumentMetadata) throws -> any MarketDataProvider {
        switch instrument.id.type {
        case .crypto:
            throw ProviderError.unsupportedInstrument
        case .equity:
            return stockProvider
        }
    }

    func searchEquities(query: String) async throws -> [InstrumentMetadata] {
        try await stockProvider.searchInstruments(query: query)
    }

    func resolveEquity(query: String) async throws -> InstrumentMetadata {
        let results = try await searchEquities(query: query)
        guard let first = results.first else {
            throw ProviderError.emptyResponse(provider: stockProvider.id)
        }
        return first
    }
}

private final class PreviousSessionStockProvider: @unchecked Sendable, MarketDataProvider {
    let id = "previous-session-stocks"
    let supportedType: InstrumentType = .equity

    static let apple = InstrumentMetadata(
        id: InstrumentID(type: .equity, symbol: "AAPL"),
        displaySymbol: "AAPL",
        name: "Apple Inc.",
        exchange: "NASDAQ",
        currency: "USD",
        provider: "previous-session-stocks",
        session: "Market hours"
    )

    private let baseTimestamp = (Int64(Date().addingTimeInterval(-7_200).timeIntervalSince1970) / 60) * 60

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        query.uppercased().contains("AAPL") ? [Self.apple] : []
    }

    func latestQuote(for instrument: InstrumentMetadata) async throws -> LinePoint {
        LinePoint(
            instrumentID: instrument.id,
            timestamp: baseTimestamp + 120,
            price: 200,
            volume: 1_200,
            source: id,
            quality: .delayed,
            resolutionSeconds: SeriesResolution.oneMinute.seconds
        )
    }

    func liveQuotes(for instrument: InstrumentMetadata) -> AsyncThrowingStream<LinePoint, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func historicalPoints(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        resolution: SeriesResolution,
        maxPoints: Int
    ) async throws -> [LinePoint] {
        [
            LinePoint(
                instrumentID: instrument.id,
                timestamp: baseTimestamp,
                price: 198,
                volume: 900,
                source: id,
                quality: .backfill,
                resolutionSeconds: resolution.seconds
            ),
            LinePoint(
                instrumentID: instrument.id,
                timestamp: baseTimestamp + 60,
                price: 199,
                volume: 950,
                source: id,
                quality: .backfill,
                resolutionSeconds: resolution.seconds
            ),
            LinePoint(
                instrumentID: instrument.id,
                timestamp: baseTimestamp + 120,
                price: 200,
                volume: 980,
                source: id,
                quality: .backfill,
                resolutionSeconds: resolution.seconds
            )
        ]
    }
}

private final class FixtureStockProvider: @unchecked Sendable, MarketDataProvider {
    let id = "fixture-stocks"
    let supportedType: InstrumentType = .equity

    static let apple = InstrumentMetadata(
        id: InstrumentID(type: .equity, symbol: "AAPL"),
        displaySymbol: "AAPL",
        name: "Apple Inc.",
        exchange: "NASDAQ",
        currency: "USD",
        provider: "fixture-stocks",
        session: "Market hours"
    )

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        query.uppercased().contains("AAPL") ? [Self.apple] : []
    }

    func latestQuote(for instrument: InstrumentMetadata) async throws -> LinePoint {
        LinePoint(
            instrumentID: instrument.id,
            timestamp: Int64(Date().timeIntervalSince1970),
            price: 103,
            volume: nil,
            source: id,
            quality: .delayed,
            resolutionSeconds: SeriesResolution.oneMinute.seconds
        )
    }

    func liveQuotes(for instrument: InstrumentMetadata) -> AsyncThrowingStream<LinePoint, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(
                LinePoint(
                    instrumentID: instrument.id,
                    timestamp: Int64(Date().timeIntervalSince1970) + 60,
                    price: 104,
                    volume: 1_200,
                    source: self.id,
                    quality: .live,
                    resolutionSeconds: SeriesResolution.oneMinute.seconds
                )
            )
            continuation.finish()
        }
    }

    func historicalPoints(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        resolution: SeriesResolution,
        maxPoints: Int
    ) async throws -> [LinePoint] {
        let start = Int64(Date().addingTimeInterval(-120).timeIntervalSince1970)
        return [
            LinePoint(
                instrumentID: instrument.id,
                timestamp: start,
                price: 101,
                volume: 900,
                source: id,
                quality: .backfill,
                resolutionSeconds: resolution.seconds
            ),
            LinePoint(
                instrumentID: instrument.id,
                timestamp: start + 60,
                price: 102,
                volume: 950,
                source: id,
                quality: .backfill,
                resolutionSeconds: resolution.seconds
            )
        ]
    }
}

private final class RejectingStockProvider: @unchecked Sendable, MarketDataProvider {
    let id = "rejecting-stocks"
    let supportedType: InstrumentType = .equity

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        throw ProviderError.badResponse(provider: id, detail: "No access")
    }

    func latestQuote(for instrument: InstrumentMetadata) async throws -> LinePoint {
        throw ProviderError.badResponse(provider: id, detail: "No access")
    }

    func liveQuotes(for instrument: InstrumentMetadata) -> AsyncThrowingStream<LinePoint, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: ProviderError.badResponse(provider: self.id, detail: "No access"))
        }
    }

    func historicalPoints(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        resolution: SeriesResolution,
        maxPoints: Int
    ) async throws -> [LinePoint] {
        throw ProviderError.badResponse(provider: id, detail: "No access")
    }
}

private func collectFirst(
    _ count: Int,
    from stream: AsyncThrowingStream<MarketSeriesUpdate, Error>
) async throws -> [MarketSeriesUpdate] {
    try await withThrowingTaskGroup(of: [MarketSeriesUpdate].self) { group in
        group.addTask {
            var updates: [MarketSeriesUpdate] = []
            for try await update in stream {
                updates.append(update)
                if updates.count == count {
                    break
                }
            }
            return updates
        }
        group.addTask {
            try await Task.sleep(nanoseconds: 3_000_000_000)
            throw XCTestError(.timeoutWhileWaiting)
        }

        let updates = try await group.next() ?? []
        group.cancelAll()
        return updates
    }
}

private func shiftedFixtureCandles(startOffset: Int64) -> [CryptoCandle] {
    let raw = try! BinanceHTTPClient.decodeKlines(
        data: fixtureData("klines"),
        symbol: "BTCUSDT",
        interval: .oneMinute
    )
    let base = Int64(Date().timeIntervalSince1970) + startOffset

    return raw.enumerated().map { index, candle in
        let openTime = base + Int64(index * 60)
        return CryptoCandle(
            symbol: candle.symbol,
            interval: candle.interval,
            openTime: openTime,
            closeTime: openTime + 59,
            open: candle.open,
            high: candle.high,
            low: candle.low,
            close: candle.close,
            volume: candle.volume,
            quoteVolume: candle.quoteVolume,
            tradeCount: candle.tradeCount,
            isClosed: candle.isClosed
        )
    }
}

private func fixtureData(_ name: String) -> Data {
    let bundle = Bundle(for: CryptoBackendTests.self)
    let url = bundle.url(
        forResource: name,
        withExtension: "json",
        subdirectory: "Fixtures"
    ) ?? bundle.url(forResource: name, withExtension: "json")!
    return try! Data(contentsOf: url)
}

private func temporaryDatabaseURL() -> URL {
    temporaryDirectory().appendingPathComponent("crypto-market-v2.sqlite")
}

private func temporaryDirectory() -> URL {
    let url = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("AeviumTests-\(UUID().uuidString)", isDirectory: true)
    try! FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
