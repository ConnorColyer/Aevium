import Foundation

final class FinnhubStockProvider: @unchecked Sendable, MarketDataProvider {
    let id = "finnhub"
    let supportedType: InstrumentType = .equity

    private let apiKey: String?
    private let restBaseURL = URL(string: "https://finnhub.io/api/v1")!
    private let webSocketBaseURL = URL(string: "wss://ws.finnhub.io")!

    init(apiKey: String?) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func searchInstruments(query: String) async throws -> [InstrumentMetadata] {
        guard let apiKey, !apiKey.isEmpty else {
            throw ProviderError.missingAPIKey(provider: id)
        }

        let url = restBaseURL
            .appendingPathComponent("search")
            .aeviumAppendingFinnhubQueryItems([
                URLQueryItem(name: "q", value: query),
                URLQueryItem(name: "token", value: apiKey)
            ])

        let payload: FinnhubSearchResponse = try await fetch(url: url)
        return payload.result
            .filter { Self.supportsSearchResultType($0.type) }
            .prefix(10)
            .compactMap { item in
            let symbol = item.symbol.uppercased()
            guard !symbol.isEmpty else { return nil }
            return InstrumentMetadata(
                id: InstrumentID(type: .equity, symbol: symbol),
                displaySymbol: symbol,
                name: item.description,
                exchange: item.type ?? "Equity",
                currency: "USD",
                provider: id,
                session: "Market hours"
            )
        }
    }

    func latestQuote(for instrument: InstrumentMetadata) async throws -> LinePoint {
        guard instrument.id.type == .equity else { throw ProviderError.unsupportedInstrument }
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingAPIKey(provider: id) }

        let url = restBaseURL
            .appendingPathComponent("quote")
            .aeviumAppendingFinnhubQueryItems([
                URLQueryItem(name: "symbol", value: instrument.id.symbol),
                URLQueryItem(name: "token", value: apiKey)
            ])

        let quote: FinnhubQuote = try await fetch(url: url)
        guard quote.current > 0 else { throw ProviderError.emptyResponse(provider: id) }

        return LinePoint(
            instrumentID: instrument.id,
            timestamp: quote.timestamp > 0 ? quote.timestamp : Int64(Date().timeIntervalSince1970),
            price: quote.current,
            volume: nil,
            source: id,
            quality: .delayed,
            resolutionSeconds: SeriesResolution.realtime.seconds
        )
    }

    func liveQuotes(for instrument: InstrumentMetadata) -> AsyncThrowingStream<LinePoint, Error> {
        AsyncThrowingStream { continuation in
            guard instrument.id.type == .equity else {
                continuation.finish(throwing: ProviderError.unsupportedInstrument)
                return
            }
            guard let apiKey, !apiKey.isEmpty else {
                continuation.finish(throwing: ProviderError.missingAPIKey(provider: id))
                return
            }

            let url = webSocketBaseURL.aeviumAppendingFinnhubQueryItems([
                URLQueryItem(name: "token", value: apiKey)
            ])
            let task = URLSession.shared.webSocketTask(with: url)
            task.resume()

            let receiveTask = Task {
                do {
                    let subscribe = FinnhubSubscribe(type: "subscribe", symbol: instrument.id.symbol)
                    let subscribeData = try JSONEncoder().encode(subscribe)
                    if let subscribeText = String(data: subscribeData, encoding: .utf8) {
                        try await task.send(.string(subscribeText))
                    }

                    while !Task.isCancelled {
                        let message = try await task.receive()
                        guard let data = message.dataValue else { continue }
                        let envelope = try JSONDecoder().decode(FinnhubTradeEnvelope.self, from: data)
                        guard envelope.type == "trade" else { continue }

                        for trade in envelope.data ?? [] {
                            continuation.yield(
                                LinePoint(
                                    instrumentID: instrument.id,
                                    timestamp: trade.timestamp / 1_000,
                                    price: trade.price,
                                    volume: trade.volume,
                                    source: self.id,
                                    quality: .live,
                                    resolutionSeconds: SeriesResolution.realtime.seconds
                                )
                            )
                        }
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
        resolution: SeriesResolution,
        maxPoints: Int
    ) async throws -> [LinePoint] {
        _ = maxPoints
        guard instrument.id.type == .equity else { throw ProviderError.unsupportedInstrument }
        guard let apiKey, !apiKey.isEmpty else { throw ProviderError.missingAPIKey(provider: id) }

        let url = restBaseURL
            .appendingPathComponent("stock/candle")
            .aeviumAppendingFinnhubQueryItems([
                URLQueryItem(name: "symbol", value: instrument.id.symbol),
                URLQueryItem(name: "resolution", value: resolution.finnhubResolution),
                URLQueryItem(name: "from", value: "\(Int64(from.timeIntervalSince1970))"),
                URLQueryItem(name: "to", value: "\(Int64(to.timeIntervalSince1970))"),
                URLQueryItem(name: "token", value: apiKey)
            ])

        let payload: FinnhubCandleResponse = try await fetch(url: url)
        guard payload.status == "ok", let closes = payload.close, let timestamps = payload.timestamp else {
            throw ProviderError.emptyResponse(provider: id)
        }

        let volumes = payload.volume ?? []
        let points = zip(timestamps.indices, zip(timestamps, closes)).map { index, pair in
            let (timestamp, price) = pair
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

        return Array(points.prefix(maxPoints))
    }

    private func fetch<T: Decodable>(url: URL) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
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

    private static func supportsSearchResultType(_ rawType: String?) -> Bool {
        guard let rawType, !rawType.isEmpty else { return true }

        let normalized = rawType.lowercased()
        return normalized.contains("stock")
            || normalized.contains("equity")
            || normalized.contains("adr")
            || normalized.contains("reit")
            || normalized.contains("etf")
            || normalized.contains("etp")
    }
}

private struct FinnhubSearchResponse: Decodable {
    let result: [FinnhubSearchResult]
}

private struct FinnhubSearchResult: Decodable {
    let description: String
    let symbol: String
    let type: String?
}

private struct FinnhubQuote: Decodable {
    let current: Double
    let timestamp: Int64

    enum CodingKeys: String, CodingKey {
        case current = "c"
        case timestamp = "t"
    }
}

private struct FinnhubCandleResponse: Decodable {
    let close: [Double]?
    let timestamp: [Int64]?
    let volume: [Double]?
    let status: String

    enum CodingKeys: String, CodingKey {
        case close = "c"
        case timestamp = "t"
        case volume = "v"
        case status = "s"
    }
}

private struct FinnhubSubscribe: Encodable {
    let type: String
    let symbol: String
}

private struct FinnhubTradeEnvelope: Decodable {
    let type: String
    let data: [FinnhubTrade]?
}

private struct FinnhubTrade: Decodable {
    let price: Double
    let symbol: String
    let timestamp: Int64
    let volume: Double

    enum CodingKeys: String, CodingKey {
        case price = "p"
        case symbol = "s"
        case timestamp = "t"
        case volume = "v"
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
    func aeviumAppendingFinnhubQueryItems(_ items: [URLQueryItem]) -> URL {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.queryItems = items
        return components?.url ?? self
    }
}
