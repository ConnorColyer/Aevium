import Foundation

protocol BinanceHTTPClientProtocol: Sendable {
    func exchangeInfo() async throws -> BinanceExchangeInfoResponse
    func klines(
        symbol: String,
        interval: BinanceKlineInterval,
        startTime: Int64,
        endTime: Int64,
        limit: Int
    ) async throws -> [CryptoCandle]
    func twentyFourHourTickers() async throws -> [BinanceTicker24h]
}

protocol BinanceWebSocketClientProtocol: Sendable {
    func klineStream(symbol: String, interval: BinanceKlineInterval) -> AsyncThrowingStream<CryptoCandle, Error>
}

struct BinanceExchangeInfoResponse: Decodable, Sendable {
    let symbols: [BinanceExchangeSymbol]
}

struct BinanceExchangeSymbol: Decodable, Sendable, Hashable {
    let symbol: String
    let status: String
    let baseAsset: String
    let quoteAsset: String
    let isSpotTradingAllowed: Bool?

    var record: BinanceSymbolRecord? {
        guard status == "TRADING", isSpotTradingAllowed != false else { return nil }
        return BinanceSymbolRecord(
            symbol: symbol,
            baseAsset: baseAsset,
            quoteAsset: quoteAsset,
            status: status,
            isSpotTradingAllowed: isSpotTradingAllowed ?? true
        )
    }
}

struct BinanceTicker24h: Decodable, Sendable, Hashable {
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

enum BinanceStreamError: LocalizedError, Sendable {
    case connectionExpired
    case ended

    var errorDescription: String? {
        switch self {
        case .connectionExpired:
            return "Binance stream connection expired"
        case .ended:
            return "Binance stream ended"
        }
    }
}

final class BinanceHTTPClient: @unchecked Sendable, BinanceHTTPClientProtocol {
    private let session: URLSession
    private let baseURL: URL
    private let decoder = JSONDecoder()

    init(
        session: URLSession = .shared,
        baseURL: URL = URL(string: "https://api.binance.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
    }

    func exchangeInfo() async throws -> BinanceExchangeInfoResponse {
        try await fetch(
            path: "/api/v3/exchangeInfo",
            queryItems: [
                URLQueryItem(name: "symbolStatus", value: "TRADING"),
                URLQueryItem(name: "showPermissionSets", value: "false")
            ]
        )
    }

    func klines(
        symbol: String,
        interval: BinanceKlineInterval,
        startTime: Int64,
        endTime: Int64,
        limit: Int
    ) async throws -> [CryptoCandle] {
        let data = try await fetchData(
            path: "/api/v3/klines",
            queryItems: [
                URLQueryItem(name: "symbol", value: symbol.uppercased()),
                URLQueryItem(name: "interval", value: interval.rawValue),
                URLQueryItem(name: "startTime", value: "\(startTime * 1_000)"),
                URLQueryItem(name: "endTime", value: "\(endTime * 1_000)"),
                URLQueryItem(name: "limit", value: "\(min(max(limit, 1), 1_000))")
            ]
        )
        return try Self.decodeKlines(data: data, symbol: symbol, interval: interval)
    }

    func twentyFourHourTickers() async throws -> [BinanceTicker24h] {
        try await fetch(path: "/api/v3/ticker/24hr", queryItems: [])
    }

    private func fetch<T: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> T {
        let data = try await fetchData(path: path, queryItems: queryItems)
        return try decoder.decode(T.self, from: data)
    }

    private func fetchData(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        let url = baseURL
            .appendingPathComponent(path)
            .aeviumAppendingBinanceQueryItems(queryItems)
        var request = URLRequest(url: url)
        request.timeoutInterval = 12

        let (data, response) = try await session.data(for: request)
        try Self.validate(response: response, data: data)
        return data
    }

    static func decodeKlines(
        data: Data,
        symbol: String,
        interval: BinanceKlineInterval
    ) throws -> [CryptoCandle] {
        guard let rows = try JSONSerialization.jsonObject(with: data) as? [[Any]] else {
            throw ProviderError.badResponse(provider: "binance", detail: "Invalid kline payload")
        }

        return rows.compactMap { row in
            guard
                row.count >= 6,
                let openTimeMs = numericInt64(row[0]),
                let open = numericDouble(row[1]),
                let high = numericDouble(row[2]),
                let low = numericDouble(row[3]),
                let close = numericDouble(row[4]),
                let volume = numericDouble(row[5])
            else {
                return nil
            }

            let closeTime = row.count > 6 ? (numericInt64(row[6]) ?? openTimeMs) : openTimeMs
            let quoteVolume = row.count > 7 ? numericDouble(row[7]) : nil
            let tradeCount = row.count > 8 ? numericInt(row[8]) : nil

            return CryptoCandle(
                symbol: symbol,
                interval: interval,
                openTime: openTimeMs / 1_000,
                closeTime: closeTime / 1_000,
                open: open,
                high: high,
                low: low,
                close: close,
                volume: volume,
                quoteVolume: quoteVolume,
                tradeCount: tradeCount,
                isClosed: true
            )
        }
    }

    static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }

        if http.statusCode == 429 || http.statusCode == 418 {
            throw ProviderError.rateLimited(provider: "binance")
        }

        guard (200..<300).contains(http.statusCode) else {
            let detail = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw ProviderError.badResponse(provider: "binance", detail: detail)
        }
    }

    private static func numericDouble(_ value: Any) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        if let value = value as? String { return Double(value) }
        return nil
    }

    private static func numericInt(_ value: Any) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }

    private static func numericInt64(_ value: Any) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        if let value = value as? String { return Int64(value) }
        return nil
    }
}

final class BinanceWebSocketClient: @unchecked Sendable, BinanceWebSocketClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let maximumConnectionAge: TimeInterval

    init(
        baseURL: URL = URL(string: "wss://stream.binance.com:9443/ws")!,
        session: URLSession = .shared,
        maximumConnectionAge: TimeInterval = 23.75 * 60 * 60
    ) {
        self.baseURL = baseURL
        self.session = session
        self.maximumConnectionAge = maximumConnectionAge
    }

    func klineStream(symbol: String, interval: BinanceKlineInterval) -> AsyncThrowingStream<CryptoCandle, Error> {
        AsyncThrowingStream { continuation in
            let streamName = "\(symbol.lowercased())@kline_\(interval.rawValue)"
            let url = baseURL.appendingPathComponent(streamName)
            let task = session.webSocketTask(with: url)
            task.resume()

            let lifetimeTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(maximumConnectionAge * 1_000_000_000))
                guard !Task.isCancelled else { return }
                task.cancel(with: .goingAway, reason: nil)
                continuation.finish(throwing: BinanceStreamError.connectionExpired)
            }

            let receiveTask = Task {
                do {
                    while !Task.isCancelled {
                        let message = try await task.receive()
                        guard let data = message.dataValue else { continue }
                        let payload = try JSONDecoder().decode(BinanceKlineStreamPayload.self, from: data)
                        continuation.yield(payload.candle(interval: interval))
                    }
                } catch {
                    if !Task.isCancelled {
                        continuation.finish(throwing: error)
                    }
                }
            }

            continuation.onTermination = { _ in
                lifetimeTask.cancel()
                receiveTask.cancel()
                task.cancel(with: .goingAway, reason: nil)
            }
        }
    }
}

private struct BinanceKlineStreamPayload: Decodable {
    let eventType: String
    let eventTime: Int64
    let symbol: String
    let kline: BinanceKlinePayload

    enum CodingKeys: String, CodingKey {
        case eventType = "e"
        case eventTime = "E"
        case symbol = "s"
        case kline = "k"
    }

    func candle(interval fallbackInterval: BinanceKlineInterval) -> CryptoCandle {
        CryptoCandle(
            symbol: symbol,
            interval: BinanceKlineInterval(rawValue: kline.interval) ?? fallbackInterval,
            openTime: kline.openTime / 1_000,
            closeTime: kline.closeTime / 1_000,
            open: Double(kline.open) ?? 0,
            high: Double(kline.high) ?? 0,
            low: Double(kline.low) ?? 0,
            close: Double(kline.close) ?? 0,
            volume: Double(kline.volume) ?? 0,
            quoteVolume: Double(kline.quoteVolume),
            tradeCount: kline.tradeCount,
            isClosed: kline.isClosed
        )
    }
}

private struct BinanceKlinePayload: Decodable {
    let openTime: Int64
    let closeTime: Int64
    let symbol: String
    let interval: String
    let open: String
    let close: String
    let high: String
    let low: String
    let volume: String
    let tradeCount: Int
    let isClosed: Bool
    let quoteVolume: String

    enum CodingKeys: String, CodingKey {
        case openTime = "t"
        case closeTime = "T"
        case symbol = "s"
        case interval = "i"
        case open = "o"
        case close = "c"
        case high = "h"
        case low = "l"
        case volume = "v"
        case tradeCount = "n"
        case isClosed = "x"
        case quoteVolume = "q"
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
    func aeviumAppendingBinanceQueryItems(_ items: [URLQueryItem]) -> URL {
        guard !items.isEmpty else { return self }
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.queryItems = items
        return components?.url ?? self
    }
}
