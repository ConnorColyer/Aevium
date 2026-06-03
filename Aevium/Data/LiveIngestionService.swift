import Foundation

actor LiveIngestionService {
    private let store: SQLiteMarketDataStore
    private let router: ProviderRouter

    init(store: SQLiteMarketDataStore, router: ProviderRouter) {
        self.store = store
        self.router = router
    }

    func subscribeLive(
        instrument: InstrumentMetadata,
        viewport: MarketViewport
    ) -> AsyncThrowingStream<MarketSeriesSnapshot, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                await self.runSubscription(
                    instrument: instrument,
                    viewport: viewport,
                    continuation: continuation
                )
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func runSubscription(
        instrument: InstrumentMetadata,
        viewport: MarketViewport,
        continuation: AsyncThrowingStream<MarketSeriesSnapshot, Error>.Continuation
    ) async {
        do {
            let provider = try router.provider(for: instrument)
            try store.upsertInstrument(instrument)

            var points = try store.linePoints(
                for: instrument.id,
                from: viewport.fromTimestamp,
                limit: viewport.storageFetchLimit,
                minimumResolution: viewport.resolution
            )
            if points.count > viewport.storageFetchLimit {
                points = Array(points.suffix(viewport.storageFetchLimit))
            }

            continuation.yield(
                MarketSeriesSnapshot(
                    instrument: instrument,
                    points: points,
                    state: syncState(instrument, .connecting, progress: 0, message: "Connecting \(provider.id)"),
                    viewport: viewport
                )
            )

            if points.isEmpty {
                do {
                    let latest = try await provider.latestQuote(for: instrument)
                    let normalizedLatest = normalizedPoint(latest, resolutionSeconds: viewport.resolution.seconds)
                    points.append(normalizedLatest)
                    try store.insertLinePoints([normalizedLatest])
                } catch {
                    // The stream still attempts live connection; latest quote is just a fast-start hint.
                }
            }

            var pendingWrites: [LinePoint] = []
            pendingWrites.reserveCapacity(32)
            var lastFlush = Date()
            var lastEmission = Date.distantPast
            var lastEmittedTimestamp = points.last?.timestamp

            func flushPendingWrites() throws {
                guard !pendingWrites.isEmpty else { return }

                if pendingWrites.count == 1 {
                    try store.insertLinePoints(pendingWrites)
                } else {
                    try store.beginTransaction()
                    do {
                        try store.insertLinePoints(pendingWrites)
                        try store.commitTransaction()
                    } catch {
                        store.rollbackTransaction()
                        throw error
                    }
                }

                pendingWrites.removeAll(keepingCapacity: true)
                lastFlush = Date()
            }

            var retry = 0
            while !Task.isCancelled {
                do {
                    retry = 0
                    continuation.yield(
                        MarketSeriesSnapshot(
                            instrument: instrument,
                            points: points,
                            state: syncState(instrument, .connected, progress: 1, message: "Live \(provider.id)"),
                            viewport: viewport
                        )
                    )
                    lastEmission = Date()
                    lastEmittedTimestamp = points.last?.timestamp

                    let resolutionSeconds = max(viewport.resolution.seconds, 1)
                    for try await rawPoint in provider.liveQuotes(for: instrument) {
                        guard !Task.isCancelled else { break }
                        let sampled = normalizedPoint(rawPoint, resolutionSeconds: resolutionSeconds)

                        if let last = points.last, last.timestamp == sampled.timestamp {
                            points[points.count - 1] = sampled
                        } else {
                            points.append(sampled)
                            if points.count > viewport.storageFetchLimit {
                                points.removeFirst(points.count - viewport.storageFetchLimit)
                            }
                        }

                        if let lastPending = pendingWrites.last, lastPending.timestamp == sampled.timestamp {
                            pendingWrites[pendingWrites.count - 1] = sampled
                        } else {
                            pendingWrites.append(sampled)
                        }

                        if pendingWrites.count >= 24 || Date().timeIntervalSince(lastFlush) >= 2 {
                            try flushPendingWrites()
                        }

                        let latestTimestamp = points.last?.timestamp
                        let shouldEmitImmediately = latestTimestamp != lastEmittedTimestamp
                        let emissionInterval = viewport.liveEmissionInterval
                        let elapsed = Date().timeIntervalSince(lastEmission)

                        if shouldEmitImmediately || emissionInterval == 0 || elapsed >= emissionInterval {
                            continuation.yield(
                                MarketSeriesSnapshot(
                                    instrument: instrument,
                                    points: points,
                                    state: syncState(instrument, .connected, progress: 1, message: "Live \(provider.id)"),
                                    viewport: viewport
                                )
                            )
                            lastEmission = Date()
                            lastEmittedTimestamp = latestTimestamp
                        }
                    }

                    try flushPendingWrites()
                } catch ProviderError.rateLimited {
                    try? flushPendingWrites()
                    continuation.yield(
                        MarketSeriesSnapshot(
                            instrument: instrument,
                            points: points,
                            state: syncState(instrument, .rateLimited, progress: 0, message: "Rate limited"),
                            viewport: viewport
                        )
                    )
                    try await Task.sleep(nanoseconds: 45_000_000_000)
                } catch ProviderError.missingAPIKey(let provider) {
                    try? flushPendingWrites()
                    continuation.yield(
                        MarketSeriesSnapshot(
                            instrument: instrument,
                            points: points,
                            state: syncState(instrument, .failed, progress: 0, message: "\(provider) key required"),
                            viewport: viewport
                        )
                    )
                    continuation.finish()
                    return
                } catch {
                    try? flushPendingWrites()
                    retry += 1
                    let delay = min(30, max(2, retry * 2))
                    continuation.yield(
                        MarketSeriesSnapshot(
                            instrument: instrument,
                            points: points,
                            state: syncState(instrument, .disconnected, progress: 0, message: "Reconnecting in \(delay)s"),
                            viewport: viewport
                        )
                    )
                    try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000_000)
                }
            }

            try? flushPendingWrites()
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    private func normalizedPoint(_ point: LinePoint, resolutionSeconds: Int) -> LinePoint {
        let bucketSeconds = max(resolutionSeconds, 1)
        let bucketTimestamp = (point.timestamp / Int64(bucketSeconds)) * Int64(bucketSeconds)

        return LinePoint(
            instrumentID: point.instrumentID,
            timestamp: bucketTimestamp,
            price: point.price,
            volume: point.volume,
            source: point.source,
            quality: point.quality,
            resolutionSeconds: bucketSeconds
        )
    }

    private func syncState(
        _ instrument: InstrumentMetadata,
        _ state: IngestionConnectionState,
        progress: Double,
        message: String
    ) -> SyncState {
        SyncState(
            instrumentID: instrument.id,
            state: state,
            progress: progress,
            message: message,
            updatedAt: Int64(Date().timeIntervalSince1970)
        )
    }
}
