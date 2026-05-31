import Foundation

final class CSVMarketDataIngestor {
    enum IngestError: Error {
        case invalidFile
    }

    typealias ProgressHandler = @Sendable (IngestionProgress) -> Void

    private let dateFormatterDash: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private let dateFormatterCompact: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    func ingest(
        from fileURL: URL,
        batchSize: Int = 2_000,
        commitBatch: ([Candle]) throws -> Void,
        onProgress: ProgressHandler? = nil
    ) throws -> IngestionProgress {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw IngestError.invalidFile
        }

        let metadata = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let totalBytes = (metadata[.size] as? NSNumber)?.int64Value ?? 0

        let handle = try FileHandle(forReadingFrom: fileURL)
        defer {
            try? handle.close()
        }

        var importedRows = 0
        var rejectedRows = 0
        var processedBytes: Int64 = 0

        var buffer = Data()
        var batch: [Candle] = []
        batch.reserveCapacity(batchSize)

        while true {
            let chunk = try handle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty {
                break
            }

            processedBytes += Int64(chunk.count)
            buffer.append(chunk)

            while let newlineIndex = buffer.firstIndex(of: 0x0A) {
                let lineData = buffer.prefix(upTo: newlineIndex)
                buffer.removeSubrange(...newlineIndex)

                if let candle = parseLine(data: lineData) {
                    batch.append(candle)
                    importedRows += 1
                } else if !isSkippableLine(data: lineData) {
                    rejectedRows += 1
                }

                if batch.count >= batchSize {
                    try commitBatch(batch)
                    batch.removeAll(keepingCapacity: true)
                }
            }

            onProgress?(
                IngestionProgress(
                    processedBytes: processedBytes,
                    totalBytes: totalBytes,
                    importedRows: importedRows,
                    rejectedRows: rejectedRows
                )
            )
        }

        if !buffer.isEmpty {
            if let candle = parseLine(data: buffer) {
                batch.append(candle)
                importedRows += 1
            } else if !isSkippableLine(data: buffer) {
                rejectedRows += 1
            }
        }

        if !batch.isEmpty {
            try commitBatch(batch)
        }

        let result = IngestionProgress(
            processedBytes: max(processedBytes, totalBytes),
            totalBytes: totalBytes,
            importedRows: importedRows,
            rejectedRows: rejectedRows
        )

        onProgress?(result)
        return result
    }

    private func parseLine(data: Data) -> Candle? {
        guard !data.isEmpty else { return nil }
        guard var line = String(data: data, encoding: .utf8) else { return nil }

        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return nil }

        let parts = line.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count >= 7 else { return nil }

        let symbol = String(parts[0]).trimmingCharacters(in: .whitespaces)
        if symbol.caseInsensitiveCompare("symbol") == .orderedSame {
            return nil
        }

        let dateRaw = String(parts[1]).trimmingCharacters(in: .whitespaces)
        guard let timestamp = parseDateToTimestamp(dateRaw) else { return nil }

        guard
            let open = Double(String(parts[2])),
            let high = Double(String(parts[3])),
            let low = Double(String(parts[4])),
            let close = Double(String(parts[5])),
            let volume = Double(String(parts[6]))
        else {
            return nil
        }

        return Candle(
            symbol: symbol.uppercased(),
            timestamp: timestamp,
            open: open,
            high: high,
            low: low,
            close: close,
            volume: volume
        )
    }

    private func parseDateToTimestamp(_ value: String) -> Int64? {
        if let date = dateFormatterDash.date(from: value) {
            return Int64(date.timeIntervalSince1970)
        }

        if let date = dateFormatterCompact.date(from: value) {
            return Int64(date.timeIntervalSince1970)
        }

        return nil
    }

    private func isSkippableLine(data: Data) -> Bool {
        guard let line = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return true
        }

        return line.isEmpty || line.lowercased().hasPrefix("symbol,")
    }
}
