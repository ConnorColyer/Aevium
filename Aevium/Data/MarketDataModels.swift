import Foundation

struct Candle: Identifiable, Sendable {
    let symbol: String
    let timestamp: Int64
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double

    var id: String { "\(symbol)-\(timestamp)" }

    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
}

struct SymbolSummary: Identifiable, Sendable {
    let symbol: String
    let count: Int
    let lastClose: Double
    let averageVolume: Double
    let minTimestamp: Int64
    let maxTimestamp: Int64

    var id: String { symbol }

    var firstDate: Date {
        Date(timeIntervalSince1970: TimeInterval(minTimestamp))
    }

    var lastDate: Date {
        Date(timeIntervalSince1970: TimeInterval(maxTimestamp))
    }
}

struct DatasetSummary: Sendable {
    let symbolCount: Int
    let rowCount: Int
    let firstTimestamp: Int64?
    let lastTimestamp: Int64?

    static let empty = DatasetSummary(symbolCount: 0, rowCount: 0, firstTimestamp: nil, lastTimestamp: nil)
}

struct IngestionProgress: Sendable, Equatable {
    let processedBytes: Int64
    let totalBytes: Int64
    let importedRows: Int
    let rejectedRows: Int

    var fractionComplete: Double {
        guard totalBytes > 0 else { return 0 }
        return min(1, Double(processedBytes) / Double(totalBytes))
    }
}
