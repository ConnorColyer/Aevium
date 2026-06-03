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
            CREATE TABLE IF NOT EXISTS instruments (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                symbol TEXT NOT NULL,
                display_symbol TEXT NOT NULL,
                name TEXT NOT NULL,
                exchange_name TEXT NOT NULL,
                currency TEXT NOT NULL,
                provider TEXT NOT NULL,
                session TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            );
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS line_points (
                instrument_id TEXT NOT NULL,
                timestamp INTEGER NOT NULL,
                price REAL NOT NULL,
                volume REAL,
                source TEXT NOT NULL,
                quality TEXT NOT NULL,
                resolution_seconds INTEGER NOT NULL,
                PRIMARY KEY(instrument_id, timestamp, resolution_seconds)
            );
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS line_rollups (
                instrument_id TEXT NOT NULL,
                bucket_start INTEGER NOT NULL,
                resolution_seconds INTEGER NOT NULL,
                price_open REAL NOT NULL,
                price_high REAL NOT NULL,
                price_low REAL NOT NULL,
                price_close REAL NOT NULL,
                point_count INTEGER NOT NULL,
                source TEXT NOT NULL,
                PRIMARY KEY(instrument_id, bucket_start, resolution_seconds)
            );
            """
        )

        try execute(
            """
            CREATE TABLE IF NOT EXISTS sync_checkpoints (
                instrument_id TEXT NOT NULL,
                provider TEXT NOT NULL,
                range_key TEXT NOT NULL,
                from_timestamp INTEGER NOT NULL,
                to_timestamp INTEGER NOT NULL,
                status TEXT NOT NULL,
                progress REAL NOT NULL,
                error_message TEXT,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY(instrument_id, provider, range_key)
            );
            """
        )

        try execute("CREATE INDEX IF NOT EXISTS idx_line_points_instrument_timestamp ON line_points(instrument_id, timestamp);")
        try execute("CREATE INDEX IF NOT EXISTS idx_line_rollups_instrument_timestamp ON line_rollups(instrument_id, bucket_start);")
        try execute("CREATE INDEX IF NOT EXISTS idx_line_points_lookup ON line_points(instrument_id, resolution_seconds, timestamp);")
        try execute("CREATE INDEX IF NOT EXISTS idx_line_rollups_lookup ON line_rollups(instrument_id, resolution_seconds, bucket_start);")
        try execute("CREATE INDEX IF NOT EXISTS idx_instruments_symbol ON instruments(symbol);")
        try execute("CREATE INDEX IF NOT EXISTS idx_sync_checkpoints_instrument_updated ON sync_checkpoints(instrument_id, updated_at DESC);")
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

    func upsertInstrument(_ instrument: InstrumentMetadata) throws {
        let sql =
            """
            INSERT INTO instruments (
                id, type, symbol, display_symbol, name, exchange_name, currency, provider, session, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                type = excluded.type,
                symbol = excluded.symbol,
                display_symbol = excluded.display_symbol,
                name = excluded.name,
                exchange_name = excluded.exchange_name,
                currency = excluded.currency,
                provider = excluded.provider,
                session = excluded.session,
                updated_at = excluded.updated_at;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (instrument.id.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (instrument.id.type.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (instrument.id.symbol as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 4, (instrument.displaySymbol as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 5, (instrument.name as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 6, (instrument.exchange as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 7, (instrument.currency as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 8, (instrument.provider as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 9, (instrument.session as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 10, Int64(Date().timeIntervalSince1970))

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
    }

    func cachedInstruments(matching query: String, limit: Int = 12) throws -> [InstrumentMetadata] {
        let sql =
            """
            SELECT id, type, symbol, display_symbol, name, exchange_name, currency, provider, session
            FROM instruments
            WHERE symbol LIKE ? COLLATE NOCASE
                OR display_symbol LIKE ? COLLATE NOCASE
                OR name LIKE ? COLLATE NOCASE
            ORDER BY updated_at DESC
            LIMIT ?;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        let pattern = "%\(query.trimmingCharacters(in: .whitespacesAndNewlines))%"
        sqlite3_bind_text(statement, 1, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (pattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(statement, 4, Int32(limit))

        var results: [InstrumentMetadata] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            guard
                let idRaw = sqlite3_column_text(statement, 0).map({ String(cString: $0) }),
                let id = InstrumentID(rawValue: idRaw)
            else {
                continue
            }

            results.append(
                InstrumentMetadata(
                    id: id,
                    displaySymbol: String(cString: sqlite3_column_text(statement, 3)),
                    name: String(cString: sqlite3_column_text(statement, 4)),
                    exchange: String(cString: sqlite3_column_text(statement, 5)),
                    currency: String(cString: sqlite3_column_text(statement, 6)),
                    provider: String(cString: sqlite3_column_text(statement, 7)),
                    session: String(cString: sqlite3_column_text(statement, 8))
                )
            )
        }

        return results
    }

    func insertLinePoints(_ points: [LinePoint]) throws {
        guard !points.isEmpty else { return }

        let sql =
            """
            INSERT INTO line_points (instrument_id, timestamp, price, volume, source, quality, resolution_seconds)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(instrument_id, timestamp, resolution_seconds) DO UPDATE SET
                price = excluded.price,
                volume = excluded.volume,
                source = excluded.source,
                quality = excluded.quality;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        for point in points {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)

            sqlite3_bind_text(statement, 1, (point.instrumentID.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(statement, 2, point.timestamp)
            sqlite3_bind_double(statement, 3, point.price)
            if let volume = point.volume {
                sqlite3_bind_double(statement, 4, volume)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_text(statement, 5, (point.source as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(statement, 6, (point.quality.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int(statement, 7, Int32(point.resolutionSeconds))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw StoreError.sqliteError(message: lastErrorMessage())
            }
        }
    }

    func linePoints(for instrumentID: InstrumentID, from: Int64, limit: Int, minimumResolution: SeriesResolution? = nil) throws -> [LinePoint] {
        let minResolution = minimumResolution?.seconds ?? 0
        let effectiveLimit = min(max(limit * 2, limit + 48), 5_000)
        let sql =
            """
            SELECT timestamp, price, volume, source, quality, resolution_seconds
            FROM (
                SELECT timestamp, price, volume, source, quality, resolution_seconds, 0 AS source_rank
                FROM line_points
                WHERE instrument_id = ? AND timestamp >= ? AND resolution_seconds >= ?
                UNION ALL
                SELECT bucket_start AS timestamp, price_close AS price, NULL AS volume, source, 'compacted' AS quality, resolution_seconds, 1 AS source_rank
                FROM line_rollups
                WHERE instrument_id = ? AND bucket_start >= ? AND resolution_seconds >= ?
            )
            ORDER BY timestamp DESC, source_rank ASC, resolution_seconds ASC
            LIMIT ?;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (instrumentID.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 2, from)
        sqlite3_bind_int(statement, 3, Int32(minResolution))
        sqlite3_bind_text(statement, 4, (instrumentID.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 5, from)
        sqlite3_bind_int(statement, 6, Int32(minResolution))
        sqlite3_bind_int(statement, 7, Int32(effectiveLimit))

        var results: [LinePoint] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let timestamp = sqlite3_column_int64(statement, 0)
            if results.last?.timestamp == timestamp {
                continue
            }

            let price = sqlite3_column_double(statement, 1)
            let volume = sqlite3_column_type(statement, 2) == SQLITE_NULL ? nil : sqlite3_column_double(statement, 2)
            let source = String(cString: sqlite3_column_text(statement, 3))
            let qualityRaw = String(cString: sqlite3_column_text(statement, 4))
            let resolution = Int(sqlite3_column_int(statement, 5))

            results.append(
                LinePoint(
                    instrumentID: instrumentID,
                    timestamp: timestamp,
                    price: price,
                    volume: volume,
                    source: source,
                    quality: LinePointQuality(rawValue: qualityRaw) ?? .sampled,
                    resolutionSeconds: resolution
                )
            )
        }

        return results.reversed()
    }

    func upsertCheckpoint(_ checkpoint: SyncCheckpoint) throws {
        let sql =
            """
            INSERT INTO sync_checkpoints (
                instrument_id, provider, range_key, from_timestamp, to_timestamp, status, progress, error_message, updated_at
            )
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(instrument_id, provider, range_key) DO UPDATE SET
                from_timestamp = excluded.from_timestamp,
                to_timestamp = excluded.to_timestamp,
                status = excluded.status,
                progress = excluded.progress,
                error_message = excluded.error_message,
                updated_at = excluded.updated_at;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (checkpoint.instrumentID.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 2, (checkpoint.provider as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(statement, 3, (checkpoint.rangeKey as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int64(statement, 4, checkpoint.fromTimestamp)
        sqlite3_bind_int64(statement, 5, checkpoint.toTimestamp)
        sqlite3_bind_text(statement, 6, (checkpoint.status.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_double(statement, 7, checkpoint.progress)
        if let errorMessage = checkpoint.errorMessage {
            sqlite3_bind_text(statement, 8, (errorMessage as NSString).utf8String, -1, SQLITE_TRANSIENT)
        } else {
            sqlite3_bind_null(statement, 8)
        }
        sqlite3_bind_int64(statement, 9, checkpoint.updatedAt)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
    }

    func syncState(for instrumentID: InstrumentID) throws -> SyncState {
        let sql =
            """
            SELECT status, progress, IFNULL(error_message, ''), updated_at
            FROM sync_checkpoints
            WHERE instrument_id = ?
            ORDER BY updated_at DESC
            LIMIT 1;
            """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, (instrumentID.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return .idle(for: instrumentID)
        }

        let statusRaw = String(cString: sqlite3_column_text(statement, 0))
        let progress = sqlite3_column_double(statement, 1)
        let message = String(cString: sqlite3_column_text(statement, 2))
        let updatedAt = sqlite3_column_int64(statement, 3)

        return SyncState(
            instrumentID: instrumentID,
            state: IngestionConnectionState(rawValue: statusRaw) ?? .idle,
            progress: progress,
            message: message.isEmpty ? statusRaw : message,
            updatedAt: updatedAt
        )
    }

    func compactLinePoints(for instrumentID: InstrumentID, now: Int64 = Int64(Date().timeIntervalSince1970)) throws {
        let thirtyDaysAgo = now - 30 * 24 * 60 * 60
        let bucketSeconds = SeriesResolution.hourly.seconds

        let rollupSQL =
            """
            INSERT OR REPLACE INTO line_rollups (
                instrument_id, bucket_start, resolution_seconds, price_open, price_high, price_low, price_close, point_count, source
            )
            WITH bucketed AS (
                SELECT
                    instrument_id,
                    (timestamp / ?) * ? AS bucket_start,
                    timestamp,
                    price,
                    FIRST_VALUE(price) OVER (
                        PARTITION BY instrument_id, (timestamp / ?) * ?
                        ORDER BY timestamp ASC
                    ) AS price_open,
                    FIRST_VALUE(price) OVER (
                        PARTITION BY instrument_id, (timestamp / ?) * ?
                        ORDER BY timestamp DESC
                    ) AS price_close
                FROM line_points
                WHERE instrument_id = ? AND timestamp < ? AND resolution_seconds < ?
            )
            SELECT
                instrument_id,
                bucket_start,
                ? AS resolution_seconds,
                MAX(price_open) AS price_open,
                MAX(price) AS price_high,
                MIN(price) AS price_low,
                MAX(price_close) AS price_close,
                COUNT(*) AS point_count,
                'local-rollup' AS source
            FROM bucketed
            GROUP BY instrument_id, bucket_start;
            """

        try runStatement(rollupSQL) { statement in
            sqlite3_bind_int(statement, 1, Int32(bucketSeconds))
            sqlite3_bind_int(statement, 2, Int32(bucketSeconds))
            sqlite3_bind_int(statement, 3, Int32(bucketSeconds))
            sqlite3_bind_int(statement, 4, Int32(bucketSeconds))
            sqlite3_bind_int(statement, 5, Int32(bucketSeconds))
            sqlite3_bind_int(statement, 6, Int32(bucketSeconds))
            sqlite3_bind_text(statement, 7, (instrumentID.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(statement, 8, thirtyDaysAgo)
            sqlite3_bind_int(statement, 9, Int32(bucketSeconds))
            sqlite3_bind_int(statement, 10, Int32(bucketSeconds))
        }

        let deleteSQL =
            """
            DELETE FROM line_points
            WHERE instrument_id = ? AND timestamp < ? AND resolution_seconds < ?;
            """

        try runStatement(deleteSQL) { statement in
            sqlite3_bind_text(statement, 1, (instrumentID.rawValue as NSString).utf8String, -1, SQLITE_TRANSIENT)
            sqlite3_bind_int64(statement, 2, thirtyDaysAgo)
            sqlite3_bind_int(statement, 3, Int32(bucketSeconds))
        }
    }

    private func runStatement(_ sql: String, bind: (OpaquePointer?) -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
        defer { sqlite3_finalize(statement) }

        bind(statement)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw StoreError.sqliteError(message: lastErrorMessage())
        }
    }

    private func lastErrorMessage() -> String {
        if let db {
            return String(cString: sqlite3_errmsg(db))
        }
        return "Unknown SQLite error"
    }
}
