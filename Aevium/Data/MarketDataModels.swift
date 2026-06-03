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

    var bufferPointTarget: Int {
        switch self {
        case .twentyFiveMinutes: return 1_500
        case .hour: return 1_200
        case .day: return 1_440
        case .week: return 1_200
        case .month: return 1_200
        case .quarter: return 900
        case .year: return 520
        }
    }

    var chartPointTarget: Int {
        switch self {
        case .twentyFiveMinutes: return 900
        case .hour: return 720
        case .day: return 720
        case .week: return 720
        case .month: return 720
        case .quarter: return 640
        case .year: return 420
        }
    }

    var storageFetchLimit: Int {
        switch self {
        case .twentyFiveMinutes:
            return 2_400
        case .hour:
            return 4_200
        case .day:
            return 2_400
        case .week:
            return 3_000
        case .month:
            return 3_800
        case .quarter:
            return 3_200
        case .year:
            return 1_200
        }
    }

    var historicalFetchLimit: Int {
        min(max(bufferPointTarget * 3, chartPointTarget * 4), 6_000)
    }

    var liveEmissionInterval: TimeInterval {
        switch self {
        case .twentyFiveMinutes:
            return 0
        case .hour:
            return 0.25
        case .day:
            return 0.75
        case .week, .month:
            return 1.0
        case .quarter, .year:
            return 1.5
        }
    }

    var usesHistoricalBackfill: Bool {
        switch self {
        case .twentyFiveMinutes:
            return true
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
        self.visiblePointTarget = visiblePointTarget ?? range.bufferPointTarget
    }

    var fromTimestamp: Int64 {
        Int64(Date().addingTimeInterval(-range.duration).timeIntervalSince1970)
    }

    var usesHistoricalBackfill: Bool {
        range.usesHistoricalBackfill
    }

    var chartPointTarget: Int {
        range.chartPointTarget
    }

    var storageFetchLimit: Int {
        range.storageFetchLimit
    }

    var historicalFetchLimit: Int {
        range.historicalFetchLimit
    }

    var liveEmissionInterval: TimeInterval {
        range.liveEmissionInterval
    }
}

func sampleLinePointsPreservingExtrema(_ source: [LinePoint], limit: Int) -> [LinePoint] {
    MarketSeriesCPU.sampleLinePointsPreservingExtrema(source, limit: limit)
}

func cleanedLinePointsForDisplay(_ source: [LinePoint]) -> [LinePoint] {
    let ordered = deduplicatedLinePointsByTimestamp(source)
        .filter { $0.price.isFinite && $0.price > 0 }

    guard ordered.count > 4 else { return ordered }

    let moves = zip(ordered.dropFirst(), ordered).compactMap { current, previous -> Double? in
        guard previous.price > 0 else { return nil }
        return abs((current.price - previous.price) / previous.price)
    }
    let sortedMoves = moves.sorted()
    let medianMove = sortedMoves.isEmpty ? 0 : sortedMoves[sortedMoves.count / 2]
    let isolatedMoveThreshold = min(max(medianMove * 12, 0.006), 0.035)

    var cleaned: [LinePoint] = []
    cleaned.reserveCapacity(ordered.count)
    cleaned.append(ordered[0])

    for index in 1..<(ordered.count - 1) {
        let previous = ordered[index - 1]
        let current = ordered[index]
        let next = ordered[index + 1]

        let previousDelta = relativeMove(from: previous.price, to: current.price)
        let nextDelta = relativeMove(from: next.price, to: current.price)
        let bridgeDelta = relativeMove(from: previous.price, to: next.price)
        let isIsolatedSpike = previousDelta > isolatedMoveThreshold
            && nextDelta > isolatedMoveThreshold
            && bridgeDelta < isolatedMoveThreshold * 0.65

        if !isIsolatedSpike {
            cleaned.append(current)
        }
    }

    cleaned.append(ordered[ordered.count - 1])
    return cleaned
}

func deduplicatedLinePointsByTimestamp(_ source: [LinePoint]) -> [LinePoint] {
    guard !source.isEmpty else { return [] }

    let ordered = source.sorted { lhs, rhs in
        if lhs.timestamp == rhs.timestamp {
            return lhs.resolutionSeconds < rhs.resolutionSeconds
        }
        return lhs.timestamp < rhs.timestamp
    }
    var results: [LinePoint] = []
    results.reserveCapacity(ordered.count)

    for point in ordered {
        if let lastIndex = results.indices.last, results[lastIndex].timestamp == point.timestamp {
            results[lastIndex] = preferredDisplayPoint(results[lastIndex], point)
        } else {
            results.append(point)
        }
    }

    return results
}

private func preferredDisplayPoint(_ lhs: LinePoint, _ rhs: LinePoint) -> LinePoint {
    if lhs.quality == .live && rhs.quality != .live { return lhs }
    if rhs.quality == .live && lhs.quality != .live { return rhs }
    if lhs.resolutionSeconds != rhs.resolutionSeconds {
        return lhs.resolutionSeconds < rhs.resolutionSeconds ? lhs : rhs
    }
    return rhs
}

private func relativeMove(from reference: Double, to value: Double) -> Double {
    guard reference != 0 else { return 0 }
    return abs((value - reference) / reference)
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
