import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

final class SQLiteMarketDataStore {
    enum StoreError: Error {
        case openDatabaseFailed(path: String)
        case sqliteError(message: String)
    }

    private var db: OpaquePointer?

    init(databaseURL: URL) throws {
        try FileManager.default.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let result = sqlite3_open_v2(
            databaseURL.path,
            &db,
            SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard result == SQLITE_OK, db != nil else {
            throw StoreError.openDatabaseFailed(path: databaseURL.path)
        }

        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA synchronous=NORMAL;")
        try execute("PRAGMA temp_store=MEMORY;")
        try execute("PRAGMA cache_size=-50000;")

        try migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    func migrate() throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS candles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                symbol TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                open REAL NOT NULL,
                high REAL NOT NULL,
                low REAL NOT NULL,
                close REAL NOT NULL,
                volume REAL NOT NULL,
                UNIQUE(symbol, timestamp)
            );
            """
        )

        try execute("CREATE INDEX IF NOT EXISTS idx_candles_symbol_timestamp ON candles(symbol, timestamp);")
        try execute("CREATE INDEX IF NOT EXISTS idx_candles_timestamp ON candles(timestamp);")
    }

    func execute(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
    }

    func beginTransaction() throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
    }

    func commitTransaction() throws {
        try execute("COMMIT;")
    }

    func rollbackTransaction() {
        _ = try? execute("ROLLBACK;")
    }

    func insert(records: [Candle]) throws {
        guard !records.isEmpty else { return }

        let sql =
            """
            INSERT INTO candles (symbol, timestamp, open, high, low, close, volume)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(symbol, timestamp) DO UPDATE SET
                open = excluded.open,
                high = excluded.high,
                low = excluded.low,
                close = excluded.close,
                volume = excluded.volume;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }

        defer {
            sqlite3_finalize(statement)
        }

        for record in records {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)

            sqlite3_bind_text(statement, 1, (record.symbol as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(statement, 2, record.timestamp)
            sqlite3_bind_double(statement, 3, record.open)
            sqlite3_bind_double(statement, 4, record.high)
            sqlite3_bind_double(statement, 5, record.low)
            sqlite3_bind_double(statement, 6, record.close)
            sqlite3_bind_double(statement, 7, record.volume)

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sqliteError(message: lastErrorMessage())
            }
        }
    }

    func datasetSummary() throws -> DatasetSummary {
        let sql =
            """
            SELECT
                COUNT(DISTINCT symbol),
                COUNT(*),
                MIN(timestamp),
                MAX(timestamp)
            FROM candles;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }

        defer {
            sqlite3_finalize(statement)
        }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return .empty
        }

        let symbolCount = Int(sqlite3_column_int64(statement, 0))
        let rowCount = Int(sqlite3_column_int64(statement, 1))

        let minValue = sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 2)
        let maxValue = sqlite3_column_type(statement, 3) == SQLITE_NULL ? nil : sqlite3_column_int64(statement, 3)

        return DatasetSummary(
            symbolCount: symbolCount,
            rowCount: rowCount,
            firstTimestamp: minValue,
            lastTimestamp: maxValue
        )
    }

    func symbolSummaries(limit: Int = 200) throws -> [SymbolSummary] {
        let sql =
            """
            WITH symbol_stats AS (
                SELECT
                    symbol,
                    COUNT(*) AS point_count,
                    AVG(volume) AS avg_volume,
                    MIN(timestamp) AS min_ts,
                    MAX(timestamp) AS max_ts
                FROM candles
                GROUP BY symbol
            ),
            latest_close AS (
                SELECT
                    c.symbol,
                    c.close
                FROM candles c
                JOIN (
                    SELECT symbol, MAX(timestamp) AS max_ts
                    FROM candles
                    GROUP BY symbol
                ) t
                ON c.symbol = t.symbol AND c.timestamp = t.max_ts
            )
            SELECT
                s.symbol,
                s.point_count,
                IFNULL(l.close, 0),
                IFNULL(s.avg_volume, 0),
                s.min_ts,
                s.max_ts
            FROM symbol_stats s
            LEFT JOIN latest_close l ON l.symbol = s.symbol
            ORDER BY s.point_count DESC, s.symbol ASC
            LIMIT ?;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }

        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_int(statement, 1, Int32(limit))

        var results: [SymbolSummary] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let symbol = String(cString: sqlite3_column_text(statement, 0))
            let count = Int(sqlite3_column_int64(statement, 1))
            let close = sqlite3_column_double(statement, 2)
            let avgVolume = sqlite3_column_double(statement, 3)
            let minTS = sqlite3_column_int64(statement, 4)
            let maxTS = sqlite3_column_int64(statement, 5)

            results.append(
                SymbolSummary(
                    symbol: symbol,
                    count: count,
                    lastClose: close,
                    averageVolume: avgVolume,
                    minTimestamp: minTS,
                    maxTimestamp: maxTS
                )
            )
        }

        return results
    }

    func candles(for symbol: String, limit: Int = 600) throws -> [Candle] {
        let sql =
            """
            SELECT symbol, timestamp, open, high, low, close, volume
            FROM candles
            WHERE symbol = ?
            ORDER BY timestamp DESC
            LIMIT ?;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }

        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_text(statement, 1, (symbol as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 2, Int32(limit))

        var items: [Candle] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let symbolValue = String(cString: sqlite3_column_text(statement, 0))
            let timestamp = sqlite3_column_int64(statement, 1)
            let open = sqlite3_column_double(statement, 2)
            let high = sqlite3_column_double(statement, 3)
            let low = sqlite3_column_double(statement, 4)
            let close = sqlite3_column_double(statement, 5)
            let volume = sqlite3_column_double(statement, 6)

            items.append(
                Candle(
                    symbol: symbolValue,
                    timestamp: timestamp,
                    open: open,
                    high: high,
                    low: low,
                    close: close,
                    volume: volume
                )
            )
        }

        return items.reversed()
    }

    private func lastErrorMessage() -> String {
        if let db {
            return String(cString: sqlite3_errmsg(db))
        }
        return "Unknown SQLite error"
    }
}
