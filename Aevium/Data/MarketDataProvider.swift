import Foundation

protocol MarketDataProvider: Sendable {
    var id: String { get }
    var supportedType: InstrumentType { get }

    func searchInstruments(query: String) async throws -> [InstrumentMetadata]
    func latestQuote(for instrument: InstrumentMetadata) async throws -> LinePoint
    func liveQuotes(for instrument: InstrumentMetadata) -> AsyncThrowingStream<LinePoint, Error>
    func historicalPoints(
        for instrument: InstrumentMetadata,
        from: Date,
        to: Date,
        resolution: SeriesResolution,
        maxPoints: Int
    ) async throws -> [LinePoint]
}

protocol MarketDataRouting: Sendable {
    func provider(for instrument: InstrumentMetadata) throws -> any MarketDataProvider
    func searchEquities(query: String) async throws -> [InstrumentMetadata]
    func resolveEquity(query: String) async throws -> InstrumentMetadata
}

enum ProviderError: LocalizedError, Sendable {
    case unsupportedInstrument
    case missingAPIKey(provider: String)
    case rateLimited(provider: String)
    case badResponse(provider: String, detail: String)
    case emptyResponse(provider: String)

    var errorDescription: String? {
        switch self {
        case .unsupportedInstrument:
            return "Unsupported instrument"
        case .missingAPIKey(let provider):
            return "\(provider) API key required"
        case .rateLimited(let provider):
            return "\(provider) rate limit reached"
        case .badResponse(let provider, let detail):
            return "\(provider) response error: \(detail)"
        case .emptyResponse(let provider):
            return "\(provider) returned no data"
        }
    }
}

struct MarketDataConfiguration: Sendable {
    let finnhubAPIKey: String?

    static var current: MarketDataConfiguration {
        let environmentKey = ProcessInfo.processInfo.environment["FINNHUB_API_KEY"]
        let localKey = AeviumAPIKeyStore.finnhubAPIKey()
        let key = [environmentKey, localKey]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }

        return MarketDataConfiguration(finnhubAPIKey: key)
    }
}

struct ProviderRouter: MarketDataRouting {
    let binance: BinanceProvider
    private let configurationOverride: MarketDataConfiguration?

    init(configuration: MarketDataConfiguration? = nil) {
        self.binance = BinanceProvider()
        self.configurationOverride = configuration
    }

    func provider(for instrument: InstrumentMetadata) throws -> any MarketDataProvider {
        switch instrument.id.type {
        case .crypto:
            return binance
        case .equity:
            return stockProvider()
        }
    }

    func defaultInstrument() -> InstrumentMetadata {
        InstrumentMetadata(
            id: InstrumentID(type: .crypto, symbol: "BTCUSDT"),
            displaySymbol: "BTC / USDT",
            name: "Bitcoin",
            exchange: "Binance",
            currency: "USDT",
            provider: binance.id,
            session: "24/7"
        )
    }

    func search(query: String) async -> [InstrumentMetadata] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [defaultInstrument()] }

        async let cryptoResults = try? binance.searchInstruments(query: normalized)
        async let stockResults = try? searchEquities(query: normalized)

        let combined = (await cryptoResults ?? []) + (await stockResults ?? [])
        return Array(combined.prefix(12))
    }

    func searchEquities(query: String) async throws -> [InstrumentMetadata] {
        try await stockProvider().searchInstruments(query: query)
    }

    func resolveEquity(query: String) async throws -> InstrumentMetadata {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let results = try await searchEquities(query: query)

        if let exact = results.first(where: { $0.id.symbol == normalized }) {
            return exact
        }

        guard let first = results.first else {
            throw ProviderError.emptyResponse(provider: stockProvider().id)
        }

        return first
    }

    func topMovers(limit: Int = 80) async throws -> [MarketMover] {
        try await binance.topMovers(limit: limit)
    }

    private func stockProvider() -> any MarketDataProvider {
        let configuration = configurationOverride ?? .current
        let finnhubKey = configuration.finnhubAPIKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finnhub = finnhubKey?.isEmpty == false
            ? FinnhubStockProvider(apiKey: finnhubKey)
            : nil

        return CompositeStockProvider(primary: finnhub)
    }

}
