import Foundation

actor BackfillService {
    private let store: SQLiteMarketDataStore
    private let router: ProviderRouter

    init(store: SQLiteMarketDataStore, router: ProviderRouter) {
        self.store = store
        self.router = router
    }

    func startBackfill(instrument: InstrumentMetadata, viewport: MarketViewport) -> AsyncStream<BackfillEvent> {
        AsyncStream { continuation in
            let task = Task {
                await self.runBackfill(instrument: instrument, viewport: viewport, continuation: continuation)
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    private func runBackfill(
        instrument: InstrumentMetadata,
        viewport: MarketViewport,
        continuation: AsyncStream<BackfillEvent>.Continuation
    ) async {
        guard viewport.usesHistoricalBackfill else {
            continuation.finish()
            return
        }

        do {
            let provider = try router.provider(for: instrument)
            let now = Date()
            let tiers = backfillTiers(for: viewport, now: now)

            try store.upsertInstrument(instrument)

            for (index, tier) in tiers.enumerated() {
                guard !Task.isCancelled else { break }

                let startingState = state(
                    instrument,
                    .backfilling,
                    progress: Double(index) / Double(tiers.count),
                    message: "Backfilling \(tier.label)"
                )
                try writeCheckpoint(startingState, instrument: instrument, provider: provider.id, rangeKey: tier.label, from: tier.from, to: tier.to)
                continuation.yield(BackfillEvent(instrument: instrument, insertedPoints: [], state: startingState))

                let points = try await provider.historicalPoints(
                    for: instrument,
                    from: tier.from,
                    to: tier.to,
                    resolution: tier.resolution,
                    maxPoints: tier.pointLimit
                )

                try store.beginTransaction()
                do {
                    try store.insertLinePoints(points)
                    try store.commitTransaction()
                } catch {
                    store.rollbackTransaction()
                    throw error
                }

                let completedState = state(
                    instrument,
                    .backfilling,
                    progress: Double(index + 1) / Double(tiers.count),
                    message: "Loaded \(tier.label)"
                )
                try writeCheckpoint(completedState, instrument: instrument, provider: provider.id, rangeKey: tier.label, from: tier.from, to: tier.to)
                continuation.yield(
                    BackfillEvent(
                        instrument: instrument,
                        insertedPoints: points,
                        state: completedState
                    )
                )
            }

            try store.compactLinePoints(for: instrument.id)

            let doneState = state(instrument, .connected, progress: 1, message: "History current")
            try writeCheckpoint(doneState, instrument: instrument, provider: instrument.provider, rangeKey: "complete", from: now, to: now)
            continuation.yield(BackfillEvent(instrument: instrument, insertedPoints: [], state: doneState))
            continuation.finish()
        } catch ProviderError.rateLimited {
            yieldFailure(instrument, state: .rateLimited, message: "Provider rate limit reached", continuation: continuation)
        } catch ProviderError.missingAPIKey(let provider) {
            yieldFailure(instrument, state: .failed, message: "\(provider) free API key required", continuation: continuation)
        } catch {
            yieldFailure(instrument, state: .failed, message: error.localizedDescription, continuation: continuation)
        }
    }

    private func backfillTiers(for viewport: MarketViewport, now: Date) -> [BackfillTier] {
        let recentFrom = now.addingTimeInterval(-viewport.range.duration)
        let activeBudget = max(1, Int(Double(viewport.historicalFetchLimit) * 0.72))
        let contextBudget = max(1, viewport.historicalFetchLimit - activeBudget)
        let tiers: [BackfillTier]

        switch viewport.range {
        case .twentyFiveMinutes:
            tiers = [
                BackfillTier(
                    label: "active 25m",
                    from: recentFrom,
                    to: now,
                    resolution: .oneMinute,
                    pointLimit: min(viewport.historicalFetchLimit, max(90, viewport.chartPointTarget))
                )
            ]
        case .hour:
            tiers = [
                BackfillTier(label: "active 1H", from: recentFrom, to: now, resolution: viewport.resolution, pointLimit: viewport.historicalFetchLimit)
            ]
        case .day:
            tiers = [
                BackfillTier(label: "active 1D", from: recentFrom, to: now, resolution: viewport.resolution, pointLimit: activeBudget),
                BackfillTier(label: "recent context", from: now.addingTimeInterval(-3 * 24 * 60 * 60), to: recentFrom, resolution: .fifteenMinute, pointLimit: contextBudget)
            ]
        case .week:
            tiers = [
                BackfillTier(label: "active 1W", from: recentFrom, to: now, resolution: viewport.resolution, pointLimit: activeBudget),
                BackfillTier(label: "monthly context", from: now.addingTimeInterval(-21 * 24 * 60 * 60), to: recentFrom, resolution: .hourly, pointLimit: contextBudget)
            ]
        case .month:
            tiers = [
                BackfillTier(label: "active 1M", from: recentFrom, to: now, resolution: viewport.resolution, pointLimit: activeBudget),
                BackfillTier(label: "six month context", from: now.addingTimeInterval(-120 * 24 * 60 * 60), to: recentFrom, resolution: .hourly, pointLimit: contextBudget)
            ]
        case .quarter:
            tiers = [
                BackfillTier(label: "active 3M", from: recentFrom, to: now, resolution: viewport.resolution, pointLimit: activeBudget),
                BackfillTier(label: "year context", from: now.addingTimeInterval(-365 * 24 * 60 * 60), to: recentFrom, resolution: .daily, pointLimit: contextBudget)
            ]
        case .year:
            tiers = [
                BackfillTier(label: "active 1Y", from: recentFrom, to: now, resolution: viewport.resolution, pointLimit: activeBudget),
                BackfillTier(label: "three year context", from: now.addingTimeInterval(-2 * 365 * 24 * 60 * 60), to: recentFrom, resolution: .daily, pointLimit: contextBudget)
            ]
        }

        return tiers.filter { $0.from < $0.to }
    }

    private func writeCheckpoint(
        _ state: SyncState,
        instrument: InstrumentMetadata,
        provider: String,
        rangeKey: String,
        from: Date,
        to: Date
    ) throws {
        try store.upsertCheckpoint(
            SyncCheckpoint(
                instrumentID: instrument.id,
                provider: provider,
                rangeKey: rangeKey,
                fromTimestamp: Int64(from.timeIntervalSince1970),
                toTimestamp: Int64(to.timeIntervalSince1970),
                status: state.state,
                progress: state.progress,
                errorMessage: state.state == .failed ? state.message : nil,
                updatedAt: state.updatedAt
            )
        )
    }

    private func state(_ instrument: InstrumentMetadata, _ state: IngestionConnectionState, progress: Double, message: String) -> SyncState {
        SyncState(
            instrumentID: instrument.id,
            state: state,
            progress: progress.clamped(to: 0...1),
            message: message,
            updatedAt: Int64(Date().timeIntervalSince1970)
        )
    }

    private func yieldFailure(
        _ instrument: InstrumentMetadata,
        state: IngestionConnectionState,
        message: String,
        continuation: AsyncStream<BackfillEvent>.Continuation
    ) {
        let syncState = SyncState(
            instrumentID: instrument.id,
            state: state,
            progress: 0,
            message: message,
            updatedAt: Int64(Date().timeIntervalSince1970)
        )
        continuation.yield(BackfillEvent(instrument: instrument, insertedPoints: [], state: syncState))
        continuation.finish()
    }
}

private struct BackfillTier {
    let label: String
    let from: Date
    let to: Date
    let resolution: SeriesResolution
    let pointLimit: Int
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
