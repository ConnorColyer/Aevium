import Foundation

final class CompositeStockProvider: @unchecked Sendable, MarketDataProvider {
    let id = "stocks"
    let supportedType: InstrumentType = .equity

    private let primary: (any MarketDataProvider)?
    private let fallback: any MarketDataProvider

    init(primary: (any MarketDataProvider)?, fallback: any MarketDataProvider = YahooStockProvider()) {
        self.primary = primary
        self.fallback = fallback
    }

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        if let primary {
            do {
                let results = try await primary.searchInstruments(query: query)
                if !results.isEmpty {
                    return results
                }
            } catch {
                // Fall through to the public provider when Finnhub search is unavailable.
            }
        }

        return try await fallback.searchInstruments(query: query)
    }

    func latestQuote(for instrument: InstrumentMetadata) async throws -> LinePoint {
        if let primary {
            do {
                return try await primary.latestQuote(for: instrument)
            } catch {
                // A restricted Finnhub key should not block stock charts.
            }
        }

        return try await fallback.latestQuote(for: instrument)
    }

    func liveQuotes(for instrument: InstrumentMetadata) -> AsyncThrowingStream<LinePoint, Error> {
        fallback.liveQuotes(for: instrument)
    }

    func historicalPoints(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        resolution: SeriesResolution,
        maxPoints: Int
    ) async throws -> [LinePoint] {
        if let primary {
            do {
                let points = try await primary.historicalPoints(
                    for: instrument,
                    from: from,
                    to: to,
                    resolution: resolution,
                    maxPoints: maxPoints
                )
                if !points.isEmpty {
                    return points
                }
            } catch {
                // Fall through to Yahoo when Finnhub rejects the candle resource.
            }
        }

        return try await fallback.historicalPoints(
            for: instrument,
            from: from,
            to: to,
            resolution: resolution,
            maxPoints: maxPoints
        )
    }
}

final class YahooStockProvider: @unchecked Sendable, MarketDataProvider {
    let id = "yahoo"
    let supportedType: InstrumentType = .equity

    private let baseURL = URL(string: "https://query1.finance.yahoo.com")!
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [] }

        let url = baseURL
            .appendingPathComponent("/v1/finance/search")
            .aeviumAppendingYahooQueryItems([
                URLQueryItem(name: "q", value: normalized),
                URLQueryItem(name: "quotesCount", value: "10"),
                URLQueryItem(name: "newsCount", value: "0")
            ])

        let payload: YahooSearchResponse = try await fetch(url: url)
        return payload.quotes
            .filter(Self.isSupportedQuote)
            .prefix(10)
            .map { quote in
                InstrumentMetadata(
                    id: InstrumentID(type: .equity, symbol: quote.symbol),
                    displaySymbol: quote.symbol,
                    name: quote.longname ?? quote.shortname ?? quote.symbol,
                    exchange: quote.exchangeDisplayName ?? quote.exchange ?? "Yahoo",
                    currency: "USD",
                    provider: id,
                    session: "Market hours"
                )
            }
    }

    func latestQuote(for instrument: InstrumentMetadata) async throws -> LinePoint {
        let result = try await chartResult(
            for: instrument,
            from: Date().addingTimeInterval(-24 * 60 * 60),
            to: Date(),
            interval: "1m",
            includePrePost: false
        )

        if let latest = pointFromLatestClose(result: result, instrument: instrument, resolutionSeconds: SeriesResolution.oneMinute.seconds) {
            return latest
        }

        guard let price = result.meta.regularMarketPrice, price > 0 else {
            throw ProviderError.emptyResponse(provider: id)
        }

        return LinePoint(
            instrumentID: instrument.id,
            timestamp: result.meta.regularMarketTime ?? Int64(Date().timeIntervalSince1970),
            price: price,
            volume: result.meta.regularMarketVolume,
            source: id,
            quality: .delayed,
            resolutionSeconds: SeriesResolution.oneMinute.seconds
        )
    }

    func liveQuotes(for instrument: InstrumentMetadata) -> AsyncThrowingStream<LinePoint, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    while !Task.isCancelled {
                        continuation.yield(try await self.latestQuote(for: instrument))
                        try await Task.sleep(nanoseconds: 15_000_000_000)
                    }
                    continuation.finish()
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func historicalPoints(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        resolution: SeriesResolution,
        maxPoints: Int
    ) async throws -> [LinePoint] {
        let requestedDuration = max(to.timeIntervalSince(from), TimeInterval(resolution.seconds))
        let request = Self.yahooRequest(for: resolution, requestedDuration: requestedDuration)

        let directPoints = try await pointsFromChart(
            for: instrument,
            from: from,
            to: to,
            interval: request.interval,
            includePrePost: false,
            resolution: request.resolution
        )

        if let usable = usableHistoricalPoints(
            directPoints,
            requestedDuration: requestedDuration,
            maxPoints: maxPoints
        ) {
            return usable
        }

        let recentPoints = try await pointsFromRecentRange(
            for: instrument,
            interval: request.interval,
            resolution: request.resolution,
            requestedDuration: requestedDuration
        )

        guard let usable = usableHistoricalPoints(
            recentPoints,
            requestedDuration: requestedDuration,
            maxPoints: maxPoints
        ) else {
            throw ProviderError.emptyResponse(provider: id)
        }

        return usable
    }

    private func chartResult(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        interval: String,
        includePrePost: Bool
    ) async throws -> YahooChartResult {
        guard instrument.id.type == .equity else { throw ProviderError.unsupportedInstrument }

        let url = baseURL
            .appendingPathComponent("/v8/finance/chart/\(instrument.id.symbol)")
            .aeviumAppendingYahooQueryItems([
                URLQueryItem(name: "period1", value: "\(Int64(from.timeIntervalSince1970))"),
                URLQueryItem(name: "period2", value: "\(Int64(to.timeIntervalSince1970))"),
                URLQueryItem(name: "interval", value: interval),
                URLQueryItem(name: "includePrePost", value: includePrePost ? "true" : "false"),
                URLQueryItem(name: "events", value: "history")
            ])

        return try await chartResult(url: url)
    }

    private func chartResult(
        for instrument: InstrumentMetadata,
        range: String,
        interval: String,
        includePrePost: Bool
    ) async throws -> YahooChartResult {
        guard instrument.id.type == .equity else { throw ProviderError.unsupportedInstrument }

        let url = baseURL
            .appendingPathComponent("/v8/finance/chart/\(instrument.id.symbol)")
            .aeviumAppendingYahooQueryItems([
                URLQueryItem(name: "range", value: range),
                URLQueryItem(name: "interval", value: interval),
                URLQueryItem(name: "includePrePost", value: includePrePost ? "true" : "false"),
                URLQueryItem(name: "events", value: "history")
            ])

        return try await chartResult(url: url)
    }

    private func chartResult(url: URL) async throws -> YahooChartResult {
        let payload: YahooChartResponse = try await fetch(url: url)
        if let error = payload.chart.error {
            throw ProviderError.badResponse(provider: id, detail: error.description)
        }

        guard let result = payload.chart.result?.first else {
            throw ProviderError.emptyResponse(provider: id)
        }

        return result
    }

    private func pointsFromChart(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        interval: String,
        includePrePost: Bool,
        resolution: SeriesResolution
    ) async throws -> [LinePoint] {
        let result = try await chartResult(
            for: instrument,
            from: from,
            to: to,
            interval: interval,
            includePrePost: includePrePost
        )
        return points(from: result, instrument: instrument, resolution: resolution)
    }

    private func pointsFromRecentRange(
        for instrument: InstrumentMetadata,
        interval: String,
        resolution: SeriesResolution,
        requestedDuration: TimeInterval
    ) async throws -> [LinePoint] {
        let result = try await chartResult(
            for: instrument,
            range: Self.fallbackYahooRange(for: resolution, requestedDuration: requestedDuration),
            interval: interval,
            includePrePost: false
        )
        return points(from: result, instrument: instrument, resolution: resolution)
    }

    private func points(
        from result: YahooChartResult,
        instrument: InstrumentMetadata,
        resolution: SeriesResolution
    ) -> [LinePoint] {
        let quote = result.indicators.quote.first
        let closes = quote?.close ?? []
        let volumes = quote?.volume ?? []

        return result.timestamp.enumerated().compactMap { index, timestamp -> LinePoint? in
            guard index < closes.count, let price = closes[index], price > 0 else {
                return nil
            }

            return LinePoint(
                instrumentID: instrument.id,
                timestamp: timestamp,
                price: price,
                volume: index < volumes.count ? volumes[index] : nil,
                source: id,
                quality: .backfill,
                resolutionSeconds: resolution.seconds
            )
        }
    }

    private func usableHistoricalPoints(
        _ points: [LinePoint],
        requestedDuration: TimeInterval,
        maxPoints: Int
    ) -> [LinePoint]? {
        let ordered = deduplicatedLinePointsByTimestamp(points)
        guard let latest = ordered.last else { return nil }

        let lowerBound = latest.timestamp - Int64(ceil(requestedDuration))
        let visible = ordered.filter { $0.timestamp >= lowerBound }
        let source = visible.isEmpty ? ordered : visible
        let capped = Array(source.suffix(maxPoints))
        return capped.isEmpty ? nil : capped
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Aevium/1.0",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json,text/plain,*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 429 {
            throw ProviderError.rateLimited(provider: id)
        }

        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ProviderError.badResponse(provider: id, detail: detail)
        }
    }

    private func pointFromLatestClose(
        result: YahooChartResult,
        instrument: InstrumentMetadata,
        resolutionSeconds: Int
    ) -> LinePoint? {
        guard let quote = result.indicators.quote.first else { return nil }

        for index in result.timestamp.indices.reversed() {
            guard index < quote.close.count, let price = quote.close[index], price > 0 else {
                continue
            }

            return LinePoint(
                instrumentID: instrument.id,
                timestamp: result.timestamp[index],
                price: price,
                volume: index < quote.volume.count ? quote.volume[index] : nil,
                source: id,
                quality: .delayed,
                resolutionSeconds: resolutionSeconds
            )
        }

        return nil
    }

    private static func isSupportedQuote(_ quote: YahooSearchQuote) -> Bool {
        let type = (quote.quoteType ?? quote.typeDisplay ?? "").lowercased()
        return type == "equity"
            || type == "etf"
            || type.contains("stock")
            || type.contains("equity")
            || type.contains("etf")
    }

    private static func yahooRequest(
        for resolution: SeriesResolution,
        requestedDuration: TimeInterval
    ) -> (interval: String, resolution: SeriesResolution) {
        if requestedDuration <= 8 * 24 * 60 * 60 {
            switch resolution {
            case .tick, .realtime, .oneMinute, .fiveMinute:
                return ("1m", .oneMinute)
            case .fifteenMinute, .hourly, .daily:
                break
            }
        }

        if requestedDuration <= 60 * 24 * 60 * 60 {
            switch resolution {
            case .tick, .realtime, .oneMinute, .fiveMinute, .fifteenMinute:
                return ("5m", .fiveMinute)
            case .hourly, .daily:
                break
            }
        }

        switch resolution {
        case .tick, .realtime, .oneMinute:
            return ("1m", .oneMinute)
        case .fiveMinute:
            return ("5m", .fiveMinute)
        case .fifteenMinute:
            return ("15m", .fifteenMinute)
        case .hourly:
            return ("60m", .hourly)
        case .daily:
            return ("1d", .daily)
        }
    }

    private static func fallbackYahooRange(
        for resolution: SeriesResolution,
        requestedDuration: TimeInterval
    ) -> String {
        if requestedDuration <= 24 * 60 * 60 {
            return "5d"
        }

        if resolution == .oneMinute, requestedDuration <= 8 * 24 * 60 * 60 {
            return "7d"
        }

        switch resolution {
        case .tick, .realtime, .oneMinute, .fiveMinute:
            return "1mo"
        case .fifteenMinute:
            return "3mo"
        case .hourly:
            return "6mo"
        case .daily:
            return "2y"
        }
    }
}

private struct YahooSearchResponse: Decodable {
    let quotes: [YahooSearchQuote]
}

private struct YahooSearchQuote: Decodable {
    let symbol: String
    let shortname: String?
    let longname: String?
    let quoteType: String?
    let typeDisplay: String?
    let exchange: String?
    let exchangeDisplayName: String?
}

private struct YahooChartResponse: Decodable {
    let chart: YahooChart
}

private struct YahooChart: Decodable {
    let result: [YahooChartResult]?
    let error: YahooChartError?
}

private struct YahooChartError: Decodable {
    let code: String?
    let description: String
}

private struct YahooChartResult: Decodable {
    let meta: YahooChartMeta
    let timestamp: [Int64]
    let indicators: YahooIndicators

    enum CodingKeys: String, CodingKey {
        case meta
        case timestamp
        case indicators
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        meta = try container.decode(YahooChartMeta.self, forKey: .meta)
        timestamp = try container.decodeIfPresent([Int64].self, forKey: .timestamp) ?? []
        indicators = try container.decodeIfPresent(YahooIndicators.self, forKey: .indicators) ?? YahooIndicators(quote: [])
    }
}

private struct YahooChartMeta: Decodable {
    let regularMarketTime: Int64?
    let regularMarketPrice: Double?
    let regularMarketVolume: Double?
}

private struct YahooIndicators: Decodable {
    let quote: [YahooQuote]
}

private struct YahooQuote: Decodable {
    let close: [Double?]
    let volume: [Double?]

    enum CodingKeys: String, CodingKey {
        case close
        case volume
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        close = try container.decodeIfPresent([Double?].self, forKey: .close) ?? []
        volume = try container.decodeIfPresent([Double?].self, forKey: .volume) ?? []
    }
}

private extension URL {
    func aeviumAppendingYahooQueryItems(_ items: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.queryItems = items
        return components?.url ?? self
    }
}
