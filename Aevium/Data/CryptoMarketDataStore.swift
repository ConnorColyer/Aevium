import Foundation
import SQLite3

private let AeviumSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

actor CryptoMarketDataStore {
    enum StoreError: Error {
        case openDatabaseFailed(path: String)
        case sqliteError(message: String)
    }

    private let databaseURL: URL
    private var db: OpaquePointer?

    init(databaseURL: URL) throws {
        self.databaseURL = databaseURL

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

        try Self.execute("PRAGMA journal_mode=WAL;", db: db)
        try Self.execute("PRAGMA synchronous=NORMAL;", db: db)
        try Self.execute("PRAGMA temp_store=MEMORY;", db: db)
        try Self.execute("PRAGMA cache_size=-50000;", db: db)
        try Self.migrate(db: db)
    }

    deinit {
        sqlite3_close(db)
    }

    func upsertSymbols(_ symbols: [BinanceSymbolRecord]) throws {
        guard !symbols.isEmpty else { return }

        try beginTransaction()
        do {
            let sql =
                """
                INSERT INTO symbols (
                    symbol, base_asset, quote_asset, status, is_spot_trading_allowed, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?)
                ON CONFLICT(symbol) DO UPDATE SET
                    base_asset = excluded.base_asset,
                    quote_asset = excluded.quote_asset,
                    status = excluded.status,
                    is_spot_trading_allowed = excluded.is_spot_trading_allowed,
                    updated_at = excluded.updated_at;
                """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqliteError(message: lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            let updatedAt = Int64(Date().timeIntervalSince1970)
            for symbol in symbols {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                sqlite3_bind_text(statement, 1, (symbol.symbol as NSString).utf8String, -1, AeviumSQLiteTransient)
                sqlite3_bind_text(statement, 2, (symbol.baseAsset as NSString).utf8String, -1, AeviumSQLiteTransient)
                sqlite3_bind_text(statement, 3, (symbol.quoteAsset as NSString).utf8String, -1, AeviumSQLiteTransient)
                sqlite3_bind_text(statement, 4, (symbol.status as NSString).utf8String, -1, AeviumSQLiteTransient)
                sqlite3_bind_int(statement, 5, symbol.isSpotTradingAllowed ? 1 : 0)
                sqlite3_bind_int64(statement, 6, updatedAt)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw StoreError.sqliteError(message: lastErrorMessage())
                }
            }

            try commitTransaction()
        } catch {
            rollbackTransaction()
            throw error
        }
    }

    func cachedSymbolDirectory(maxAge: TimeInterval) throws -> [BinanceSymbolRecord]? {
        let symbols = try allSymbols()
        guard !symbols.isEmpty else { return nil }

        let newestUpdate = symbols.map(\.updatedAt).max() ?? 0
        let now = Int64(Date().timeIntervalSince1970)
        guard now - newestUpdate <= Int64(maxAge) else { return nil }
        return symbols
    }

    func allSymbols() throws -> [BinanceSymbolRecord] {
        let sql =
            """
            SELECT symbol, base_asset, quote_asset, status, is_spot_trading_allowed, updated_at
            FROM symbols
            WHERE status = 'TRADING' AND is_spot_trading_allowed = 1
            ORDER BY symbol ASC;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        var results: [BinanceSymbolRecord] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let symbol = columnString(statement, 0),
                let baseAsset = columnString(statement, 1),
                let quoteAsset = columnString(statement, 2),
                let status = columnString(statement, 3)
            else {
                continue
            }

            results.append(
                BinanceSymbolRecord(
                    symbol: symbol,
                    baseAsset: baseAsset,
                    quoteAsset: quoteAsset,
                    status: status,
                    isSpotTradingAllowed: sqlite3_column_int(statement, 4) == 1,
                    updatedAt: sqlite3_column_int64(statement, 5)
                )
            )
        }

        return results
    }

    func upsertCandles(_ candles: [CryptoCandle]) throws {
        guard !candles.isEmpty else { return }

        try beginTransaction()
        do {
            let sql =
                """
                INSERT INTO candles (
                    symbol, interval, open_time, close_time, open, high, low, close, volume,
                    quote_volume, trade_count, is_closed, source, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(symbol, interval, open_time) DO UPDATE SET
                    close_time = excluded.close_time,
                    open = excluded.open,
                    high = excluded.high,
                    low = excluded.low,
                    close = excluded.close,
                    volume = excluded.volume,
                    quote_volume = excluded.quote_volume,
                    trade_count = excluded.trade_count,
                    is_closed = excluded.is_closed,
                    source = excluded.source,
                    updated_at = excluded.updated_at;
                """

            var statement: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
                throw StoreError.sqliteError(message: lastErrorMessage())
            }
            defer { sqlite3_finalize(statement) }

            for candle in candles {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)

                sqlite3_bind_text(statement, 1, (candle.symbol as NSString).utf8String, -1, AeviumSQLiteTransient)
                sqlite3_bind_text(statement, 2, (candle.interval.rawValue as NSString).utf8String, -1, AeviumSQLiteTransient)
                sqlite3_bind_int64(statement, 3, candle.openTime)
                sqlite3_bind_int64(statement, 4, candle.closeTime)
                sqlite3_bind_double(statement, 5, candle.open)
                sqlite3_bind_double(statement, 6, candle.high)
                sqlite3_bind_double(statement, 7, candle.low)
                sqlite3_bind_double(statement, 8, candle.close)
                sqlite3_bind_double(statement, 9, candle.volume)
                if let quoteVolume = candle.quoteVolume {
                    sqlite3_bind_double(statement, 10, quoteVolume)
                } else {
                    sqlite3_bind_null(statement, 10)
                }
                if let tradeCount = candle.tradeCount {
                    sqlite3_bind_int(statement, 11, Int32(tradeCount))
                } else {
                    sqlite3_bind_null(statement, 11)
                }
                sqlite3_bind_int(statement, 12, candle.isClosed ? 1 : 0)
                sqlite3_bind_text(statement, 13, (candle.source as NSString).utf8String, -1, AeviumSQLiteTransient)
                sqlite3_bind_int64(statement, 14, candle.updatedAt)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw StoreError.sqliteError(message: lastErrorMessage())
                }
            }

            try commitTransaction()
        } catch {
            rollbackTransaction()
            throw error
        }
    }

    func candles(
        symbol: String,
        interval: BinanceKlineInterval,
        from: Int64,
        limit: Int
    ) throws -> [CryptoCandle] {
        let sql =
            """
            SELECT symbol, interval, open_time, close_time, open, high, low, close, volume,
                   quote_volume, trade_count, is_closed, source, updated_at
            FROM candles
            WHERE symbol = ? AND interval = ? AND open_time >= ?
            ORDER BY open_time DESC
            LIMIT ?;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (symbol.uppercased() as NSString).utf8String, -1, AeviumSQLiteTransient)
        sqlite3_bind_text(statement, 2, (interval.rawValue as NSString).utf8String, -1, AeviumSQLiteTransient)
        sqlite3_bind_int64(statement, 3, from)
        sqlite3_bind_int(statement, 4, Int32(max(limit, 1)))

        var results: [CryptoCandle] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let rawSymbol = columnString(statement, 0),
                let rawInterval = columnString(statement, 1),
                let interval = BinanceKlineInterval(rawValue: rawInterval),
                let source = columnString(statement, 12)
            else {
                continue
            }

            results.append(
                CryptoCandle(
                    symbol: rawSymbol,
                    interval: interval,
                    openTime: sqlite3_column_int64(statement, 2),
                    closeTime: sqlite3_column_int64(statement, 3),
                    open: sqlite3_column_double(statement, 4),
                    high: sqlite3_column_double(statement, 5),
                    low: sqlite3_column_double(statement, 6),
                    close: sqlite3_column_double(statement, 7),
                    volume: sqlite3_column_double(statement, 8),
                    quoteVolume: columnOptionalDouble(statement, 9),
                    tradeCount: columnOptionalInt(statement, 10),
                    isClosed: sqlite3_column_int(statement, 11) == 1,
                    source: source,
                    updatedAt: sqlite3_column_int64(statement, 13)
                )
            )
        }

        return results.reversed()
    }

    func upsertFeedStatus(
        symbol: String,
        interval: BinanceKlineInterval,
        rangeKey: String,
        state: SyncState,
        stale: Bool
    ) throws {
        let sql =
            """
            INSERT INTO feed_status (
                symbol, interval, range_key, state, progress, message, stale, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(symbol, interval, range_key) DO UPDATE SET
                state = excluded.state,
                progress = excluded.progress,
                message = excluded.message,
                stale = excluded.stale,
                updated_at = excluded.updated_at;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (symbol.uppercased() as NSString).utf8String, -1, AeviumSQLiteTransient)
        sqlite3_bind_text(statement, 2, (interval.rawValue as NSString).utf8String, -1, AeviumSQLiteTransient)
        sqlite3_bind_text(statement, 3, (rangeKey as NSString).utf8String, -1, AeviumSQLiteTransient)
        sqlite3_bind_text(statement, 4, (state.state.rawValue as NSString).utf8String, -1, AeviumSQLiteTransient)
        sqlite3_bind_double(statement, 5, state.progress)
        sqlite3_bind_text(statement, 6, (state.message as NSString).utf8String, -1, AeviumSQLiteTransient)
        sqlite3_bind_int(statement, 7, stale ? 1 : 0)
        sqlite3_bind_int64(statement, 8, state.updatedAt)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
    }

    private static func migrate(db: OpaquePointer?) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS schema_metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            """,
            db: db
        )

        try execute(
            """
            INSERT INTO schema_metadata (key, value)
            VALUES ('schema_version', '2')
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
            """,
            db: db
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS symbols (
                symbol TEXT PRIMARY KEY,
                base_asset TEXT NOT NULL,
                quote_asset TEXT NOT NULL,
                status TEXT NOT NULL,
                is_spot_trading_allowed INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            );
            """,
            db: db
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS candles (
                symbol TEXT NOT NULL,
                interval TEXT NOT NULL,
                open_time INTEGER NOT NULL,
                close_time INTEGER NOT NULL,
                open REAL NOT NULL,
                high REAL NOT NULL,
                low REAL NOT NULL,
                close REAL NOT NULL,
                volume REAL NOT NULL,
                quote_volume REAL,
                trade_count INTEGER,
                is_closed INTEGER NOT NULL,
                source TEXT NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY(symbol, interval, open_time)
            );
            """,
            db: db
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS feed_status (
                symbol TEXT NOT NULL,
                interval TEXT NOT NULL,
                range_key TEXT NOT NULL,
                state TEXT NOT NULL,
                progress REAL NOT NULL,
                message TEXT NOT NULL,
                stale INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY(symbol, interval, range_key)
            );
            """,
            db: db
        )

        try execute("CREATE INDEX IF NOT EXISTS idx_symbols_assets ON symbols(base_asset, quote_asset);", db: db)
        try execute("CREATE INDEX IF NOT EXISTS idx_candles_lookup ON candles(symbol, interval, open_time);", db: db)
        try execute("CREATE INDEX IF NOT EXISTS idx_feed_status_symbol_updated ON feed_status(symbol, updated_at DESC);", db: db)
    }

    private func execute(_ sql: String) throws {
        try Self.execute(sql, db: db)
    }

    private static func execute(_ sql: String, db: OpaquePointer?) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage(db: db))
        }
    }

    private func beginTransaction() throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
    }

    private func commitTransaction() throws {
        try execute("COMMIT;")
    }

    private func rollbackTransaction() {
        _ = try? execute("ROLLBACK;")
    }

    private func lastErrorMessage() -> String {
        Self.lastErrorMessage(db: db)
    }

    private static func lastErrorMessage(db: OpaquePointer?) -> String {
        if let db {
            return String(cString: sqlite3_errmsg(db))
        }
        return "Unknown SQLite error"
    }

    private func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let text = sqlite3_column_text(statement, index) else { return nil }
        return String(cString: text)
    }

    private func columnOptionalDouble(_ statement: OpaquePointer?, _ index: Int32) -> Double? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : sqlite3_column_double(statement, index)
    }

    private func columnOptionalInt(_ statement: OpaquePointer?, _ index: Int32) -> Int? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : Int(sqlite3_column_int(statement, index))
    }
}
