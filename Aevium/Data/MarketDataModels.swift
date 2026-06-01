import Foundation

enum InstrumentType: String, Codable, CaseIterable, Sendable {
    case crypto
    case equity
}

struct InstrumentID: Hashable, Codable, Sendable, CustomStringConvertible {
    let type: InstrumentType
    let symbol: String

    init(type: InstrumentType, symbol: String) {
        self.type = type
        self.symbol = symbol.uppercased().replacingOccurrences(of: "/", with: "")
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ":", maxSplits: 1).map(String.init)
        guard
            parts.count == 2,
            let type = InstrumentType(rawValue: parts[0])
        else {
            return nil
        }
        self.init(type: type, symbol: parts[1])
    }

    var rawValue: String {
        "\(type.rawValue):\(symbol)"
    }

    var description: String {
        rawValue
    }
}

struct InstrumentMetadata: Identifiable, Codable, Sendable, Hashable {
    let id: InstrumentID
    let displaySymbol: String
    let name: String
    let exchange: String
    let currency: String
    let provider: String
    let session: String

    var compactTitle: String {
        displaySymbol.isEmpty ? id.symbol : displaySymbol
    }
}

enum LinePointQuality: String, Codable, Sendable {
    case live
    case backfill
    case sampled
    case compacted
    case delayed
    case fallback
}

struct LinePoint: Identifiable, Codable, Sendable, Hashable {
    let instrumentID: InstrumentID
    let timestamp: Int64
    let price: Double
    let volume: Double?
    let source: String
    let quality: LinePointQuality
    let resolutionSeconds: Int

    var id: String {
        "\(instrumentID.rawValue)-\(timestamp)-\(source)-\(resolutionSeconds)"
    }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

enum SeriesResolution: Int, Codable, CaseIterable, Sendable {
    case tick = 1
    case realtime = 5
    case oneMinute = 60
    case fiveMinute = 300
    case fifteenMinute = 900
    case hourly = 3600
    case daily = 86400

    var seconds: Int {
        rawValue
    }

    var binanceInterval: String {
        switch self {
        case .tick, .realtime, .oneMinute:
            return "1m"
        case .fiveMinute:
            return "5m"
        case .fifteenMinute:
            return "15m"
        case .hourly:
            return "1h"
        case .daily:
            return "1d"
        }
    }

    var finnhubResolution: String {
        switch self {
        case .tick, .realtime, .oneMinute:
            return "1"
        case .fiveMinute:
            return "5"
        case .fifteenMinute:
            return "15"
        case .hourly:
            return "60"
        case .daily:
            return "D"
        }
    }
}

enum MarketTimeRange: String, Codable, CaseIterable, Sendable {
    case twentyFiveMinutes = "25m"
    case hour = "1H"
    case day = "1D"
    case week = "1W"
    case month = "1M"
    case quarter = "3M"
    case year = "1Y"

    var duration: TimeInterval {
        switch self {
        case .twentyFiveMinutes: return 25 * 60
        case .hour: return 60 * 60
        case .day: return 24 * 60 * 60
        case .week: return 7 * 24 * 60 * 60
        case .month: return 30 * 24 * 60 * 60
        case .quarter: return 90 * 24 * 60 * 60
        case .year: return 365 * 24 * 60 * 60
        }
    }

    var preferredResolution: SeriesResolution {
        switch self {
        case .twentyFiveMinutes: return .tick
        case .hour: return .realtime
        case .day: return .oneMinute
        case .week: return .fiveMinute
        case .month: return .fifteenMinute
        case .quarter: return .hourly
        case .year: return .daily
        }
    }

    var maxVisiblePoints: Int {
        switch self {
        case .twentyFiveMinutes: return 1_500
        case .hour: return 360
        case .day: return 480
        case .week: return 640
        case .month: return 720
        case .quarter: return 620
        case .year: return 520
        }
    }

    var usesHistoricalBackfill: Bool {
        switch self {
        case .twentyFiveMinutes:
            return false
        case .hour, .day, .week, .month, .quarter, .year:
            return true
        }
    }
}

struct MarketViewport: Codable, Sendable, Hashable {
    let range: MarketTimeRange
    let resolution: SeriesResolution
    let visiblePointTarget: Int

    init(range: MarketTimeRange, resolution: SeriesResolution? = nil, visiblePointTarget: Int? = nil) {
        self.range = range
        self.resolution = resolution ?? range.preferredResolution
        self.visiblePointTarget = visiblePointTarget ?? range.maxVisiblePoints
    }

    var fromTimestamp: Int64 {
        Int64(Date().addingTimeInterval(-range.duration).timeIntervalSince1970)
    }

    var usesHistoricalBackfill: Bool {
        range.usesHistoricalBackfill
    }
}

enum IngestionConnectionState: String, Codable, Sendable {
    case idle
    case connecting
    case connected
    case backfilling
    case rateLimited
    case delayed
    case disconnected
    case failed
}

struct SyncState: Codable, Equatable, Sendable {
    let instrumentID: InstrumentID
    let state: IngestionConnectionState
    let progress: Double
    let message: String
    let updatedAt: Int64

    static func idle(for instrumentID: InstrumentID) -> SyncState {
        SyncState(
            instrumentID: instrumentID,
            state: .idle,
            progress: 0,
            message: "Idle",
            updatedAt: Int64(Date().timeIntervalSince1970)
        )
    }
}

struct SyncCheckpoint: Codable, Sendable {
    let instrumentID: InstrumentID
    let provider: String
    let rangeKey: String
    let fromTimestamp: Int64
    let toTimestamp: Int64
    let status: IngestionConnectionState
    let progress: Double
    let errorMessage: String?
    let updatedAt: Int64
}

struct MarketSeriesSnapshot: Sendable {
    let instrument: InstrumentMetadata
    let points: [LinePoint]
    let state: SyncState
    let viewport: MarketViewport
}

struct BackfillEvent: Sendable {
    let instrument: InstrumentMetadata
    let insertedPoints: [LinePoint]
    let state: SyncState
}

struct MarketMover: Identifiable, Codable, Sendable, Hashable {
    let instrument: InstrumentMetadata
    let lastPrice: Double
    let priceChange: Double
    let percentChange: Double
    let highPrice: Double
    let lowPrice: Double
    let baseVolume: Double
    let quoteVolume: Double
    let tradeCount: Int

    var id: String {
        instrument.id.rawValue
    }

    var isUp: Bool {
        percentChange >= 0
    }

    var moveMagnitude: Double {
        min(abs(percentChange) / 18, 1)
    }
}
