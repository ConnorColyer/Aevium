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
        resolution: SeriesResolution
    ) async throws -> [LinePoint]
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

struct ProviderRouter: Sendable {
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

    func inferInstrument(from rawQuery: String) -> InstrumentMetadata {
        let cleaned = rawQuery
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: "/", with: "")
            .replacingOccurrences(of: "-", with: "")

        if cleaned.hasSuffix("USDT") || cleaned.hasSuffix("USDC") || cleaned.hasSuffix("BTC") || cleaned.hasSuffix("ETH") || Self.commonCryptoBases.contains(cleaned) {
            let symbol = Self.commonCryptoBases.contains(cleaned) ? "\(cleaned)USDT" : cleaned
            return InstrumentMetadata(
                id: InstrumentID(type: .crypto, symbol: symbol),
                displaySymbol: prettyCryptoSymbol(symbol),
                name: symbol,
                exchange: "Binance",
                currency: symbol.hasSuffix("USDT") ? "USDT" : "",
                provider: binance.id,
                session: "24/7"
            )
        }

        return InstrumentMetadata(
            id: InstrumentID(type: .equity, symbol: cleaned),
            displaySymbol: cleaned,
            name: cleaned,
            exchange: "Global",
            currency: "USD",
            provider: stockProvider().id,
            session: "Market hours"
        )
    }

    func search(query: String) async -> [InstrumentMetadata] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return [defaultInstrument()] }

        async let cryptoResults = try? binance.searchInstruments(query: normalized)
        async let stockResults = try? stockProvider().searchInstruments(query: normalized)

        let combined = (await cryptoResults ?? []) + (await stockResults ?? [])
        if combined.isEmpty {
            return [inferInstrument(from: normalized)]
        }
        return Array(combined.prefix(12))
    }

    func topMovers(limit: Int = 80) async throws -> [MarketMover] {
        try await binance.topMovers(limit: limit)
    }

    private func stockProvider() -> FinnhubStockProvider {
        let configuration = configurationOverride ?? .current
        return FinnhubStockProvider(apiKey: configuration.finnhubAPIKey)
    }

    private func prettyCryptoSymbol(_ symbol: String) -> String {
        for quote in ["USDT", "USDC", "BTC", "ETH"] where symbol.hasSuffix(quote) {
            let base = String(symbol.dropLast(quote.count))
            return "\(base) / \(quote)"
        }
        return symbol
    }

    private static let commonCryptoBases: Set<String> = [
        "BTC", "ETH", "BNB", "SOL", "XRP", "DOGE", "ADA", "AVAX", "LINK", "LTC",
        "TRX", "DOT", "MATIC", "BCH", "UNI", "ATOM", "ETC", "XLM", "FIL", "APT",
        "ARB", "OP", "NEAR", "SUI", "PEPE", "SHIB"
    ]
}
