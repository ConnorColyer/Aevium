import Foundation

final class BinanceProvider: @unchecked Sendable, MarketDataProvider {
    let id = "binance"
    let supportedType: InstrumentType = .crypto

    private let restBaseURL = URL(string: "https://api.binance.com")!
    private let webSocketBaseURL = URL(string: "wss://stream.binance.com:9443/ws")!

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        let normalized = query
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")

        guard !normalized.isEmpty else { return [] }

        let candidates: [String]
        if normalized.hasSuffix("USDT") || normalized.hasSuffix("USDC") || normalized.hasSuffix("BTC") || normalized.hasSuffix("ETH") {
            candidates = [normalized]
        } else if Self.commonCryptoBases.contains(normalized) {
            candidates = ["\(normalized)USDT", "\(normalized)USDC", "\(normalized)BTC"]
        } else {
            candidates = []
        }

        return candidates.map { symbol in
            InstrumentMetadata(
                id: InstrumentID(type: .crypto, symbol: symbol),
                displaySymbol: prettySymbol(symbol),
                name: symbol,
                exchange: "Binance",
                currency: quoteCurrency(for: symbol),
                provider: id,
                session: "24/7"
            )
        }
    }

    func latestQuote(for instrument: InstrumentMetadata) async throws -> LinePoint {
        guard instrument.id.type == .crypto else { throw ProviderError.unsupportedInstrument }

        let url = restBaseURL
            .appendingPathComponent("/api/v3/ticker/price")
            .aeviumAppendingQueryItems([
                URLQueryItem(name: "symbol", value: instrument.id.symbol)
            ])

        let payload: BinanceTickerPrice = try await fetch(url: url)
        guard let price = Double(payload.price) else {
            throw ProviderError.badResponse(provider: id, detail: "Invalid price")
        }

        return LinePoint(
            instrumentID: instrument.id,
            timestamp: Int64(Date().timeIntervalSince1970),
            price: price,
            volume: nil,
            source: id,
            quality: .live,
            resolutionSeconds: SeriesResolution.realtime.seconds
        )
    }

    func liveQuotes(for instrument: InstrumentMetadata) -> AsyncThrowingStream<LinePoint, Error> {
        AsyncThrowingStream { continuation in
            guard instrument.id.type == .crypto else {
                continuation.finish(throwing: ProviderError.unsupportedInstrument)
                return
            }

            let streamName = "\(instrument.id.symbol.lowercased())@trade"
            let url = webSocketBaseURL.appendingPathComponent(streamName)
            let task = URLSession.shared.webSocketTask(with: url)
            task.resume()

            let receiveTask = Task {
                do {
                    while !Task.isCancelled {
                        let message = try await task.receive()
                        guard let data = message.dataValue else { continue }
                        let trade = try JSONDecoder().decode(BinanceTrade.self, from: data)
                        guard let price = Double(trade.price) else { continue }

                        continuation.yield(
                            LinePoint(
                                instrumentID: instrument.id,
                                timestamp: Int64((trade.tradeTime ?? trade.eventTime) / 1_000),
                                price: price,
                                volume: Double(trade.quantity),
                                source: self.id,
                                quality: .live,
                                resolutionSeconds: SeriesResolution.realtime.seconds
                            )
                        )
                    }
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                receiveTask.cancel()
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }

    func historicalPoints(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        resolution: SeriesResolution
    ) async throws -> [LinePoint] {
        guard instrument.id.type == .crypto else { throw ProviderError.unsupportedInstrument }

        var results: [LinePoint] = []
        var startMs = Int64(from.timeIntervalSince1970 * 1_000)
        let endMs = Int64(to.timeIntervalSince1970 * 1_000)
        let stepMs = Int64(resolution.seconds * 1_000)

        while startMs < endMs && results.count < 20_000 {
            let url = restBaseURL
                .appendingPathComponent("/api/v3/klines")
                .aeviumAppendingQueryItems([
                    URLQueryItem(name: "symbol", value: instrument.id.symbol),
                    URLQueryItem(name: "interval", value: resolution.binanceInterval),
                    URLQueryItem(name: "startTime", value: "\(startMs)"),
                    URLQueryItem(name: "endTime", value: "\(endMs)"),
                    URLQueryItem(name: "limit", value: "1000")
                ])

            let page = try await fetchKlines(url: url, instrument: instrument, resolution: resolution)
            guard !page.isEmpty else { break }

            results.append(contentsOf: page)
            let next = ((page.last?.timestamp ?? Int64(startMs / 1_000)) * 1_000) + stepMs
            if next <= startMs { break }
            startMs = next
        }

        return results
    }

    func topMovers(limit: Int = 80) async throws -> [MarketMover] {
        let url = restBaseURL.appendingPathComponent("/api/v3/ticker/24hr")
        let tickers: [Binance24HourTicker] = try await fetch(url: url)

        let movers = tickers.compactMap { ticker -> MarketMover? in
            guard
                ticker.symbol.hasSuffix("USDT"),
                !Self.excludedSymbolFragments.contains(where: ticker.symbol.contains),
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

            let instrument = InstrumentMetadata(
                id: InstrumentID(type: .crypto, symbol: ticker.symbol),
                displaySymbol: prettySymbol(ticker.symbol),
                name: ticker.symbol,
                exchange: "Binance",
                currency: quoteCurrency(for: ticker.symbol),
                provider: id,
                session: "24/7"
            )

            return MarketMover(
                instrument: instrument,
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

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func fetchKlines(url: URL, instrument: InstrumentMetadata, resolution: SeriesResolution) async throws -> [LinePoint] {
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)

        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            throw ProviderError.badResponse(provider: id, detail: "Invalid kline payload")
        }

        return rows.compactMap { row in
            guard
                row.count >= 6,
                let openTime = row[0] as? NSNumber,
                let closeRaw = row[4] as? String,
                let price = Double(closeRaw)
            else {
                return nil
            }

            let volume = (row.count > 5 ? row[5] as? String : nil).flatMap(Double.init)
            return LinePoint(
                instrumentID: instrument.id,
                timestamp: openTime.int64Value / 1_000,
                price: price,
                volume: volume,
                source: id,
                quality: .backfill,
                resolutionSeconds: resolution.seconds
            )
        }
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 429 || http.statusCode == 418 {
            throw ProviderError.rateLimited(provider: id)
        }
        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ProviderError.badResponse(provider: id, detail: detail)
        }
    }

    private func prettySymbol(_ symbol: String) -> String {
        let quote = quoteCurrency(for: symbol)
        guard !quote.isEmpty, symbol.count > quote.count else { return symbol }
        return "\(symbol.dropLast(quote.count)) / \(quote)"
    }

    private func quoteCurrency(for symbol: String) -> String {
        for quote in ["USDT", "USDC", "BUSD", "BTC", "ETH", "EUR", "GBP"] where symbol.hasSuffix(quote) {
            return quote
        }
        return ""
    }

    private static let commonCryptoBases: Set<String> = [
        "BTC", "ETH", "BNB", "SOL", "XRP", "DOGE", "ADA", "AVAX", "LINK", "LTC",
        "TRX", "DOT", "MATIC", "BCH", "UNI", "ATOM", "ETC", "XLM", "FIL", "APT",
        "ARB", "OP", "NEAR", "SUI", "PEPE", "SHIB"
    ]

    private static let excludedSymbolFragments = [
        "UPUSDT", "DOWNUSDT", "BULLUSDT", "BEARUSDT"
    ]
}

private struct BinanceTickerPrice: Decodable {
    let symbol: String
    let price: String
}

private struct Binance24HourTicker: Decodable {
    let symbol: String
    let priceChange: String
    let priceChangePercent: String
    let lastPrice: String
    let highPrice: String
    let lowPrice: String
    let volume: String
    let quoteVolume: String
    let count: Int
}

private struct BinanceTrade: Decodable {
    let eventTime: Int64
    let tradeTime: Int64?
    let price: String
    let quantity: String

    enum CodingKeys: String, CodingKey {
        case eventTime = "E"
        case tradeTime = "T"
        case price = "p"
        case quantity = "q"
    }
}

private extension URLSessionWebSocketTask.Message {
    var dataValue: Data? {
        switch self {
        case .data(let data):
            return data
        case .string(let string):
            return string.data(using: .utf8)
        @unknown default:
            return nil
        }
    }
}

private extension URL {
    func aeviumAppendingQueryItems(_ items: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.queryItems = items
        return components?.url ?? self
    }
}
