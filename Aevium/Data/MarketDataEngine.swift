import Foundation

actor MarketDataEngine {
    private let store: CryptoMarketDataStore
    private let httpClient: any BinanceHTTPClientProtocol
    private let webSocketClient: any BinanceWebSocketClientProtocol
    private let router: any MarketDataRouting
    private let symbolDirectoryTTL: TimeInterval

    init(
        databaseURL: URL,
        httpClient: any BinanceHTTPClientProtocol = BinanceHTTPClient(),
        webSocketClient: any BinanceWebSocketClientProtocol = BinanceWebSocketClient(),
        router: any MarketDataRouting = ProviderRouter(),
        symbolDirectoryTTL: TimeInterval = 12 * 60 * 60
    ) throws {
        self.store = try CryptoMarketDataStore(databaseURL: databaseURL)
        self.httpClient = httpClient
        self.webSocketClient = webSocketClient
        self.router = router
        self.symbolDirectoryTTL = symbolDirectoryTTL
    }

    init(
        store: CryptoMarketDataStore,
        httpClient: any BinanceHTTPClientProtocol,
        webSocketClient: any BinanceWebSocketClientProtocol,
        router: any MarketDataRouting = ProviderRouter(),
        symbolDirectoryTTL: TimeInterval = 12 * 60 * 60
    ) {
        self.store = store
        self.httpClient = httpClient
        self.webSocketClient = webSocketClient
        self.router = router
        self.symbolDirectoryTTL = symbolDirectoryTTL
    }

    func defaultInstrument() -> InstrumentMetadata {
        BinanceSymbolRecord(
            symbol: "BTCUSDT",
            baseAsset: "BTC",
            quoteAsset: "USDT",
            status: "TRADING",
            isSpotTradingAllowed: true
        ).instrument
    }

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        let normalized = Self.normalizedSymbol(query)
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty || !trimmed.isEmpty else { return [defaultInstrument()] }

        async let cryptoResults = searchCryptoInstruments(query: normalized)
        async let equityResults = searchEquityInstruments(query: trimmed)

        return deduplicatedInstruments((await cryptoResults) + (await equityResults))
            .prefix(12)
            .map { $0 }
    }

    func resolveInstrument(query: String) async throws -> InstrumentMetadata {
        let normalized = Self.normalizedSymbol(query)

        if Self.shouldPreferCryptoResolution(for: normalized) {
            return try await resolveSymbolRecord(query: query).instrument
        }

        do {
            return try await router.resolveEquity(query: query)
        } catch ProviderError.missingAPIKey {
            throw ProviderError.missingAPIKey(provider: "finnhub")
        } catch {
            return try await resolveSymbolRecord(query: query).instrument
        }
    }

    func topMovers(limit: Int = 80) async throws -> [MarketMover] {
        let tickers = try await httpClient.twentyFourHourTickers()
        let directory = try await symbolDirectory()
        let recordsBySymbol = Dictionary(uniqueKeysWithValues: directory.map { ($0.symbol, $0) })

        let movers = tickers.compactMap { ticker -> MarketMover? in
            guard
                ticker.symbol.hasSuffix("USDT"),
                !Self.excludedSymbolFragments.contains(where: ticker.symbol.contains),
                let record = recordsBySymbol[ticker.symbol],
                record.status == "TRADING",
                record.isSpotTradingAllowed,
                let lastPrice = Double(ticker.lastPrice),
                let priceChange = Double(ticker.priceChange),
                let percentChange = Double(ticker.priceChangePercent),
                let highPrice = Double(ticker.highPrice),
                let lowPrice = Double(ticker.lowPrice),
                let baseVolume = Double(ticker.volume),
                let quoteVolume = Double(ticker.quoteVolume),
                lastPrice > 0,
                quoteVolume > 750_000
            else {
                return nil
            }

            return MarketMover(
                instrument: record.instrument,
                lastPrice: lastPrice,
                priceChange: priceChange,
                percentChange: percentChange,
                highPrice: highPrice,
                lowPrice: lowPrice,
                baseVolume: baseVolume,
                quoteVolume: quoteVolume,
                tradeCount: ticker.count
            )
        }

        return Array(
            movers
                .sorted { abs($0.percentChange) > abs($1.percentChange) }
                .prefix(limit)
        )
    }

    func observeSeries(
        symbol: String,
        viewport: MarketViewport
    ) -> AsyncThrowingStream<MarketSeriesUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.runSeries(symbol: symbol, viewport: viewport, continuation: continuation)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func observeSeries(
        instrument: InstrumentMetadata,
        viewport: MarketViewport
    ) -> AsyncThrowingStream<MarketSeriesUpdate, Error> {
        switch instrument.id.type {
        case .crypto:
            return observeSeries(symbol: instrument.id.symbol, viewport: viewport)
        case .equity:
            return observeProviderSeries(instrument: instrument, viewport: viewport)
        }
    }

    private func observeProviderSeries(
        instrument: InstrumentMetadata,
        viewport: MarketViewport
    ) -> AsyncThrowingStream<MarketSeriesUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.runProviderSeries(
                    instrument: instrument,
                    viewport: viewport,
                    continuation: continuation
                )
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func runSeries(
        symbol rawSymbol: String,
        viewport: MarketViewport,
        continuation: AsyncThrowingStream<MarketSeriesUpdate, Error>.Continuation
    ) async {
        let fallbackInstrument = Self.fallbackInstrument(for: rawSymbol)

        do {
            let record = try await resolveSymbolRecord(query: rawSymbol)
            let instrument = record.instrument
            let interval = BinanceKlineInterval(resolution: viewport.resolution)
            let from = viewport.fromTimestamp
            let queryLimit = max(viewport.storageFetchLimit, viewport.chartPointTarget * 3)

            try await store.upsertSymbols([record])

            var candles = try await store.candles(
                symbol: record.symbol,
                interval: interval,
                from: from,
                limit: queryLimit
            )
            var points = linePoints(from: candles, instrument: instrument)

            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: points,
                state: .connecting,
                progress: points.isEmpty ? 0.05 : 0.22,
                message: points.isEmpty ? "Loading Binance history" : "Using cached Binance history",
                stale: !points.isEmpty,
                errorMessage: nil
            )

            guard !Task.isCancelled else {
                continuation.finish()
                return
            }

            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: points,
                state: .backfilling,
                progress: points.isEmpty ? 0.20 : 0.45,
                message: "Backfilling Binance \(interval.rawValue)",
                stale: !points.isEmpty,
                errorMessage: nil
            )

            let fetched = try await fetchHistory(
                symbol: record.symbol,
                interval: interval,
                from: from,
                to: Int64(Date().timeIntervalSince1970),
                viewport: viewport
            )

            if !fetched.isEmpty {
                try await store.upsertCandles(fetched)
            }

            candles = try await store.candles(
                symbol: record.symbol,
                interval: interval,
                from: from,
                limit: queryLimit
            )
            points = linePoints(from: candles, instrument: instrument)

            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: points,
                state: .connected,
                progress: 1,
                message: "History current",
                stale: false,
                errorMessage: nil
            )

            await runLiveLoop(
                instrument: instrument,
                interval: interval,
                viewport: viewport,
                points: points,
                continuation: continuation
            )
        } catch {
            yield(
                continuation,
                instrument: fallbackInstrument,
                viewport: viewport,
                points: [],
                state: error.connectionState,
                progress: 0,
                message: error.localizedDescription,
                stale: false,
                errorMessage: error.localizedDescription
            )
            continuation.finish()
        }
    }

    private func runProviderSeries(
        instrument: InstrumentMetadata,
        viewport: MarketViewport,
        continuation: AsyncThrowingStream<MarketSeriesUpdate, Error>.Continuation
    ) async {
        var points: [LinePoint] = []

        do {
            let provider = try router.provider(for: instrument)
            let providerName = Self.providerDisplayName(provider.id)
            let to = Date()
            let from = providerHistoryStart(for: viewport, instrument: instrument, now: to)

            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: [],
                state: .connecting,
                progress: 0.08,
                message: "Loading \(providerName) history",
                stale: false,
                errorMessage: nil
            )

            guard !Task.isCancelled else {
                continuation.finish()
                return
            }

            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: [],
                state: .backfilling,
                progress: 0.34,
                message: "Backfilling \(providerName)",
                stale: false,
                errorMessage: nil
            )

            points = try await provider.historicalPoints(
                for: instrument,
                from: from,
                to: to,
                resolution: viewport.resolution,
                maxPoints: viewport.historicalFetchLimit
            )
            points = trimmedProviderPoints(
                points,
                viewport: viewport,
                anchorsToLatestPoint: instrument.id.type == .equity
            )

            do {
                let latest = try await provider.latestQuote(for: instrument)
                merge(
                    point: normalizedProviderPoint(latest, resolutionSeconds: viewport.resolution.seconds),
                    into: &points,
                    limit: viewport.storageFetchLimit
                )
            } catch {
                if points.isEmpty {
                    throw error
                }
            }

            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: points,
                state: .connected,
                progress: 1,
                message: "\(providerName) ready",
                stale: false,
                errorMessage: nil
            )

            await runProviderLiveLoop(
                provider: provider,
                instrument: instrument,
                viewport: viewport,
                points: points,
                continuation: continuation
            )
        } catch ProviderError.missingAPIKey(let provider) {
            let message = "\(Self.providerDisplayName(provider)) API key required"
            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: points,
                state: .failed,
                progress: 0,
                message: message,
                stale: !points.isEmpty,
                errorMessage: message
            )
            continuation.finish()
        } catch ProviderError.rateLimited(let provider) {
            let message = "\(Self.providerDisplayName(provider)) rate limit reached"
            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: points,
                state: .rateLimited,
                progress: 0,
                message: message,
                stale: !points.isEmpty,
                errorMessage: message
            )
            continuation.finish()
        } catch {
            yield(
                continuation,
                instrument: instrument,
                viewport: viewport,
                points: points,
                state: error.connectionState,
                progress: 0,
                message: error.localizedDescription,
                stale: !points.isEmpty,
                errorMessage: error.localizedDescription
            )
            continuation.finish()
        }
    }

    private func runProviderLiveLoop(
        provider: any MarketDataProvider,
        instrument: InstrumentMetadata,
        viewport: MarketViewport,
        points initialPoints: [LinePoint],
        continuation: AsyncThrowingStream<MarketSeriesUpdate, Error>.Continuation
    ) async {
        var points = initialPoints
        var retry = 0
        let providerName = Self.providerDisplayName(provider.id)

        while !Task.isCancelled {
            do {
                retry = 0
                yield(
                    continuation,
                    instrument: instrument,
                    viewport: viewport,
                    points: points,
                    state: .connected,
                    progress: 1,
                    message: "Live \(providerName)",
                    stale: false,
                    errorMessage: nil
                )

                let stream = provider.liveQuotes(for: instrument)
                for try await rawPoint in stream {
                    guard !Task.isCancelled else { break }

                    let point = normalizedProviderPoint(rawPoint, resolutionSeconds: viewport.resolution.seconds)
                    merge(point: point, into: &points, limit: viewport.storageFetchLimit)

                    yield(
                        continuation,
                        instrument: instrument,
                        viewport: viewport,
                        points: points,
                        state: .connected,
                        progress: 1,
                        message: "Live \(providerName)",
                        stale: false,
                        errorMessage: nil
                    )
                }

                if !Task.isCancelled {
                    throw ProviderError.emptyResponse(provider: provider.id)
                }
            } catch ProviderError.missingAPIKey(let provider) {
                let message = "\(Self.providerDisplayName(provider)) API key required"
                yield(
                    continuation,
                    instrument: instrument,
                    viewport: viewport,
                    points: points,
                    state: .failed,
                    progress: 0,
                    message: message,
                    stale: !points.isEmpty,
                    errorMessage: message
                )
                continuation.finish()
                return
            } catch ProviderError.rateLimited(let provider) {
                let message = "\(Self.providerDisplayName(provider)) rate limit reached"
                yield(
                    continuation,
                    instrument: instrument,
                    viewport: viewport,
                    points: points,
                    state: .rateLimited,
                    progress: 0,
                    message: message,
                    stale: !points.isEmpty,
                    errorMessage: message
                )
                try? await Task.sleep(nanoseconds: 45_000_000_000)
            } catch {
                retry += 1
                let delay = min(45, max(2, retry * 2))
                yield(
                    continuation,
                    instrument: instrument,
                    viewport: viewport,
                    points: points,
                    state: .disconnected,
                    progress: 0,
                    message: "Reconnecting \(providerName) in \(delay)s",
                    stale: !points.isEmpty,
                    errorMessage: error.localizedDescription
                )
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            }
        }

        continuation.finish()
    }

    private func runLiveLoop(
        instrument: InstrumentMetadata,
        interval: BinanceKlineInterval,
        viewport: MarketViewport,
        points initialPoints: [LinePoint],
        continuation: AsyncThrowingStream<MarketSeriesUpdate, Error>.Continuation
    ) async {
        var points = initialPoints
        var retry = 0

        while !Task.isCancelled {
            do {
                retry = 0
                yield(
                    continuation,
                    instrument: instrument,
                    viewport: viewport,
                    points: points,
                    state: .connected,
                    progress: 1,
                    message: "Live Binance \(interval.rawValue)",
                    stale: false,
                    errorMessage: nil
                )

                let stream = webSocketClient.klineStream(symbol: instrument.id.symbol, interval: interval)
                for try await candle in stream {
                    guard !Task.isCancelled else { break }

                    try await store.upsertCandles([candle])
                    let point = candle.linePoint(for: instrument.id)
                    merge(point: point, into: &points, limit: viewport.storageFetchLimit)

                    yield(
                        continuation,
                        instrument: instrument,
                        viewport: viewport,
                        points: points,
                        state: .connected,
                        progress: 1,
                        message: "Live Binance \(interval.rawValue)",
                        stale: false,
                        errorMessage: nil
                    )
                }

                if !Task.isCancelled {
                    throw BinanceStreamError.ended
                }
            } catch ProviderError.rateLimited {
                yield(
                    continuation,
                    instrument: instrument,
                    viewport: viewport,
                    points: points,
                    state: .rateLimited,
                    progress: 0,
                    message: "Binance rate limit reached",
                    stale: !points.isEmpty,
                    errorMessage: ProviderError.rateLimited(provider: "binance").localizedDescription
                )
                try? await Task.sleep(nanoseconds: 45_000_000_000)
            } catch {
                retry += 1
                let delay = min(45, max(2, retry * 2))
                yield(
                    continuation,
                    instrument: instrument,
                    viewport: viewport,
                    points: points,
                    state: .disconnected,
                    progress: 0,
                    message: "Reconnecting Binance in \(delay)s",
                    stale: !points.isEmpty,
                    errorMessage: error.localizedDescription
                )
                try? await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
            }
        }

        continuation.finish()
    }

    private func fetchHistory(
        symbol: String,
        interval: BinanceKlineInterval,
        from: Int64,
        to: Int64,
        viewport: MarketViewport
    ) async throws -> [CryptoCandle] {
        let idealPointCount = Int(ceil(Double(max(to - from, 0)) / Double(interval.seconds))) + 4
        let maxPoints = min(
            12_000,
            max(idealPointCount, viewport.historicalFetchLimit, viewport.storageFetchLimit)
        )

        var results: [CryptoCandle] = []
        var start = from
        let step = Int64(interval.seconds)

        while start < to, results.count < maxPoints, !Task.isCancelled {
            let pageLimit = min(1_000, maxPoints - results.count)
            let page = try await httpClient.klines(
                symbol: symbol,
                interval: interval,
                startTime: start,
                endTime: to,
                limit: pageLimit
            )

            guard !page.isEmpty else { break }
            results.append(contentsOf: page)

            let next = (page.last?.openTime ?? start) + step
            if next <= start { break }
            start = next
        }

        return results
    }

    private func symbolDirectory() async throws -> [BinanceSymbolRecord] {
        if let cached = try await store.cachedSymbolDirectory(maxAge: symbolDirectoryTTL) {
            return cached
        }

        do {
            let response = try await httpClient.exchangeInfo()
            let records = response.symbols.compactMap(\.record)
            try await store.upsertSymbols(records)
            return records
        } catch {
            let cached = try await store.allSymbols()
            if !cached.isEmpty {
                return cached
            }
            throw error
        }
    }

    private func resolveSymbolRecord(query: String) async throws -> BinanceSymbolRecord {
        let normalized = Self.normalizedSymbol(query)
        guard !normalized.isEmpty else { return Self.btcRecord }

        let records = try await symbolDirectory()
        if let exact = records.first(where: { $0.symbol == normalized }) {
            return exact
        }

        if !Self.knownQuoteAssets.contains(where: normalized.hasSuffix),
           let usdt = records.first(where: { $0.symbol == "\(normalized)USDT" }) {
            return usdt
        }

        if let first = rankedSymbols(matching: normalized, in: records).first {
            return first
        }

        throw ProviderError.badResponse(provider: "binance", detail: "No Binance symbol found for \(query)")
    }

    private func rankedSymbols(
        matching query: String,
        in records: [BinanceSymbolRecord]
    ) -> [BinanceSymbolRecord] {
        records
            .compactMap { record -> (record: BinanceSymbolRecord, score: Int)? in
                let symbol = record.symbol
                let base = record.baseAsset
                let quote = record.quoteAsset
                let score: Int

                if symbol == query {
                    score = 0
                } else if symbol == "\(query)USDT" {
                    score = 1
                } else if base == query && quote == "USDT" {
                    score = 2
                } else if base == query {
                    score = 3
                } else if symbol.hasPrefix(query) && quote == "USDT" {
                    score = 4
                } else if symbol.contains(query) && quote == "USDT" {
                    score = 5
                } else if symbol.hasPrefix(query) {
                    score = 6
                } else if symbol.contains(query) || base.contains(query) || quote.contains(query) {
                    score = 7
                } else {
                    return nil
                }

                return (record, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score < rhs.score }
                if lhs.record.quoteAsset == "USDT", rhs.record.quoteAsset != "USDT" { return true }
                if lhs.record.quoteAsset != "USDT", rhs.record.quoteAsset == "USDT" { return false }
                return lhs.record.symbol < rhs.record.symbol
            }
            .map(\.record)
    }

    private func searchCryptoInstruments(query: String) async -> [InstrumentMetadata] {
        guard !query.isEmpty else { return [] }

        do {
            let records = try await symbolDirectory()
            return rankedSymbols(matching: query, in: records).map(\.instrument)
        } catch {
            return []
        }
    }

    private func searchEquityInstruments(query: String) async -> [InstrumentMetadata] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }

        do {
            return try await router.searchEquities(query: query)
        } catch {
            return []
        }
    }

    private func deduplicatedInstruments(_ instruments: [InstrumentMetadata]) -> [InstrumentMetadata] {
        var seen: Set<String> = []
        var results: [InstrumentMetadata] = []
        results.reserveCapacity(instruments.count)

        for instrument in instruments {
            guard seen.insert(instrument.id.rawValue).inserted else { continue }
            results.append(instrument)
        }

        return results
    }

    private func linePoints(from candles: [CryptoCandle], instrument: InstrumentMetadata) -> [LinePoint] {
        candles.map { $0.linePoint(for: instrument.id) }
    }

    private func trimmedProviderPoints(
        _ source: [LinePoint],
        viewport: MarketViewport,
        anchorsToLatestPoint: Bool
    ) -> [LinePoint] {
        let ordered = deduplicatedLinePointsByTimestamp(source)
        let lowerBound: Int64
        if anchorsToLatestPoint, let latest = ordered.last {
            lowerBound = latest.timestamp - Int64(ceil(providerHistoryDuration(for: viewport, includesIndicatorContext: true)))
        } else {
            lowerBound = viewport.fromTimestamp
        }

        let points = ordered.filter { $0.timestamp >= lowerBound }

        if points.count > viewport.storageFetchLimit {
            return Array(points.suffix(viewport.storageFetchLimit))
        }

        return points
    }

    private func providerHistoryStart(
        for viewport: MarketViewport,
        instrument: InstrumentMetadata,
        now: Date
    ) -> Date {
        let duration = providerHistoryDuration(
            for: viewport,
            includesIndicatorContext: instrument.id.type == .equity
        )
        return now.addingTimeInterval(-duration)
    }

    private func providerHistoryDuration(
        for viewport: MarketViewport,
        includesIndicatorContext: Bool
    ) -> TimeInterval {
        guard includesIndicatorContext else {
            return viewport.range.duration
        }

        let warmupSamples = 260
        let cadenceWarmup = TimeInterval(viewport.resolution.seconds * warmupSamples)
        let intradayMinimum = 4 * 60 * 60.0
        return viewport.range.duration + max(cadenceWarmup, intradayMinimum)
    }

    private func normalizedProviderPoint(_ point: LinePoint, resolutionSeconds: Int) -> LinePoint {
        let bucketSeconds = max(resolutionSeconds, 1)
        let timestamp = (point.timestamp / Int64(bucketSeconds)) * Int64(bucketSeconds)

        return LinePoint(
            instrumentID: point.instrumentID,
            timestamp: timestamp,
            price: point.price,
            volume: point.volume,
            source: point.source,
            quality: point.quality,
            resolutionSeconds: bucketSeconds
        )
    }

    private func merge(point: LinePoint, into points: inout [LinePoint], limit: Int) {
        if let lastIndex = points.indices.last, points[lastIndex].timestamp == point.timestamp {
            points[lastIndex] = point
        } else {
            points.append(point)
            points.sort { $0.timestamp < $1.timestamp }
        }

        if points.count > limit {
            points.removeFirst(points.count - limit)
        }
    }

    private func yield(
        _ continuation: AsyncThrowingStream<MarketSeriesUpdate, Error>.Continuation,
        instrument: InstrumentMetadata,
        viewport: MarketViewport,
        points: [LinePoint],
        state connectionState: IngestionConnectionState,
        progress: Double,
        message: String,
        stale: Bool,
        errorMessage: String?
    ) {
        let syncState = SyncState(
            instrumentID: instrument.id,
            state: connectionState,
            progress: min(max(progress, 0), 1),
            message: message,
            updatedAt: Int64(Date().timeIntervalSince1970)
        )

        try? Task.checkCancellation()
        try? storeStatus(
            instrument: instrument,
            viewport: viewport,
            state: syncState,
            stale: stale
        )

        continuation.yield(
            MarketSeriesUpdate(
                instrument: instrument,
                points: points,
                state: syncState,
                viewport: viewport,
                stale: stale,
                errorMessage: errorMessage
            )
        )
    }

    private func storeStatus(
        instrument: InstrumentMetadata,
        viewport: MarketViewport,
        state: SyncState,
        stale: Bool
    ) throws {
        Task {
            try? await store.upsertFeedStatus(
                symbol: instrument.id.symbol,
                interval: BinanceKlineInterval(resolution: viewport.resolution),
                rangeKey: viewport.range.rawValue,
                state: state,
                stale: stale
            )
        }
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

    private static func normalizedSymbol(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func shouldPreferCryptoResolution(for symbol: String) -> Bool {
        guard !symbol.isEmpty else { return true }

        if commonCryptoBases.contains(symbol) {
            return true
        }

        return knownQuoteAssets.contains { quote in
            symbol.hasSuffix(quote) && symbol.count > quote.count
        }
    }

    private static func providerDisplayName(_ provider: String) -> String {
        switch provider.lowercased() {
        case "finnhub":
            return "Finnhub"
        case "stocks":
            return "Stocks"
        case "yahoo":
            return "Yahoo"
        case "binance":
            return "Binance"
        default:
            return provider.uppercased()
        }
    }

    private static func fallbackInstrument(for rawSymbol: String) -> InstrumentMetadata {
        let symbol = normalizedSymbol(rawSymbol)
        for quote in knownQuoteAssets where symbol.hasSuffix(quote) && symbol.count > quote.count {
            let base = String(symbol.dropLast(quote.count))
            return BinanceSymbolRecord(
                symbol: symbol,
                baseAsset: base,
                quoteAsset: quote,
                status: "TRADING",
                isSpotTradingAllowed: true
            ).instrument
        }

        return BinanceSymbolRecord(
            symbol: symbol.isEmpty ? "BTCUSDT" : symbol,
            baseAsset: symbol.isEmpty ? "BTC" : symbol,
            quoteAsset: symbol.isEmpty ? "USDT" : "",
            status: "TRADING",
            isSpotTradingAllowed: true
        ).instrument
    }

    private static let knownQuoteAssets = [
        "USDT", "USDC", "FDUSD", "BTC", "ETH", "BNB", "EUR", "GBP", "TRY", "BRL", "JPY"
    ]

    private static let commonCryptoBases: Set<String> = [
        "BTC", "ETH", "BNB", "SOL", "XRP", "DOGE", "ADA", "AVAX", "LINK", "LTC",
        "TRX", "DOT", "MATIC", "BCH", "UNI", "ATOM", "ETC", "XLM", "FIL", "APT",
        "ARB", "OP", "NEAR", "SUI", "PEPE", "SHIB"
    ]

    private static let excludedSymbolFragments = [
        "UPUSDT", "DOWNUSDT", "BULLUSDT", "BEARUSDT"
    ]
}

private extension Error {
    var connectionState: IngestionConnectionState {
        if let providerError = self as? ProviderError,
           case .rateLimited = providerError {
            return .rateLimited
        }
        return .failed
    }
}
