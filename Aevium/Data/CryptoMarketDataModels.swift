import Foundation

enum BinanceKlineInterval: String, Codable, CaseIterable, Sendable {
    case oneSecond = "1s"
    case oneMinute = "1m"
    case fiveMinute = "5m"
    case fifteenMinute = "15m"
    case hourly = "1h"
    case daily = "1d"

    init(resolution: SeriesResolution) {
        switch resolution {
        case .tick, .realtime:
            self = .oneSecond
        case .oneMinute:
            self = .oneMinute
        case .fiveMinute:
            self = .fiveMinute
        case .fifteenMinute:
            self = .fifteenMinute
        case .hourly:
            self = .hourly
        case .daily:
            self = .daily
        }
    }

    var seconds: Int {
        switch self {
        case .oneSecond:
            return 1
        case .oneMinute:
            return 60
        case .fiveMinute:
            return 300
        case .fifteenMinute:
            return 900
        case .hourly:
            return 3_600
        case .daily:
            return 86_400
        }
    }
}

struct BinanceSymbolRecord: Codable, Sendable, Hashable {
    let symbol: String
    let baseAsset: String
    let quoteAsset: String
    let status: String
    let isSpotTradingAllowed: Bool
    let updatedAt: Int64

    init(
        symbol: String,
        baseAsset: String,
        quoteAsset: String,
        status: String,
        isSpotTradingAllowed: Bool,
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.symbol = symbol.uppercased()
        self.baseAsset = baseAsset.uppercased()
        self.quoteAsset = quoteAsset.uppercased()
        self.status = status
        self.isSpotTradingAllowed = isSpotTradingAllowed
        self.updatedAt = updatedAt
    }

    var instrument: InstrumentMetadata {
        InstrumentMetadata(
            id: InstrumentID(type: .crypto, symbol: symbol),
            displaySymbol: "\(baseAsset) / \(quoteAsset)",
            name: "\(baseAsset)\(quoteAsset)",
            exchange: "Binance",
            currency: quoteAsset,
            provider: "binance",
            session: "24/7"
        )
    }
}

struct CryptoCandle: Codable, Sendable, Hashable {
    let symbol: String
    let interval: BinanceKlineInterval
    let openTime: Int64
    let closeTime: Int64
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double
    let quoteVolume: Double?
    let tradeCount: Int?
    let isClosed: Bool
    let source: String
    let updatedAt: Int64

    init(
        symbol: String,
        interval: BinanceKlineInterval,
        openTime: Int64,
        closeTime: Int64,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double,
        quoteVolume: Double? = nil,
        tradeCount: Int? = nil,
        isClosed: Bool = true,
        source: String = "binance",
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970)
    ) {
        self.symbol = symbol.uppercased()
        self.interval = interval
        self.openTime = openTime
        self.closeTime = closeTime
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
        self.quoteVolume = quoteVolume
        self.tradeCount = tradeCount
        self.isClosed = isClosed
        self.source = source
        self.updatedAt = updatedAt
    }

    func linePoint(for instrumentID: InstrumentID) -> LinePoint {
        LinePoint(
            instrumentID: instrumentID,
            timestamp: openTime,
            price: close,
            volume: volume,
            source: source,
            quality: isClosed ? .backfill : .live,
            resolutionSeconds: interval.seconds
        )
    }
}

struct MarketSeriesUpdate: Sendable {
    let instrument: InstrumentMetadata
    let points: [LinePoint]
    let state: SyncState
    let viewport: MarketViewport
    let stale: Bool
    let errorMessage: String?
}
