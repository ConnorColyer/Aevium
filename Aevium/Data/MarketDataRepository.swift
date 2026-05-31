import Foundation

actor MarketDataRepository {
    private let store: SQLiteMarketDataStore
    private let ingestor: CSVMarketDataIngestor

    init(databaseURL: URL) throws {
        self.store = try SQLiteMarketDataStore(databaseURL: databaseURL)
        self.ingestor = CSVMarketDataIngestor()
    }

    func ingestCSV(at fileURL: URL, onProgress: CSVMarketDataIngestor.ProgressHandler? = nil) throws -> IngestionProgress {
        try store.beginTransaction()

        do {
            let progress = try ingestor.ingest(from: fileURL, commitBatch: { [store] batch in
                try store.insert(records: batch)
            }, onProgress: onProgress)
            try store.commitTransaction()
            return progress
        } catch {
            store.rollbackTransaction()
            throw error
        }
    }

    func datasetSummary() throws -> DatasetSummary {
        try store.datasetSummary()
    }

    func symbolSummaries(limit: Int = 200) throws -> [SymbolSummary] {
        try store.symbolSummaries(limit: limit)
    }

    func candles(for symbol: String, limit: Int = 600) throws -> [Candle] {
        try store.candles(for: symbol, limit: limit)
    }
}
