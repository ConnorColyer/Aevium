import Foundation
import SwiftUI

@MainActor
final class AeviumMarketViewModel: ObservableObject {
    enum StartupState: Equatable {
        case loading
        case ready
        case failed
    }

    @Published var selectedInstrument: InstrumentMetadata
    @Published var points: [LinePoint] = []
    @Published private(set) var analytics: MarketSeriesAnalytics = .empty
    @Published var computeSummary: AeviumComputeSummary = .cpu
    @Published var syncState: SyncState
    @Published private(set) var startupState: StartupState = .loading
    @Published private(set) var displayedRange: MarketTimeRange = .week
    @Published private(set) var isRangeTransitioning = false
    @Published var searchQuery = ""
    @Published var searchResults: [InstrumentMetadata] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var engine: MarketDataEngine?
    private var selectedRange: MarketTimeRange = .week
    private let seriesProcessor = MarketSeriesProcessor()
    private var streamTask: Task<Void, Never>?
    private var processingTask: Task<Void, Never>?
    private var pendingSeriesUpdates: [PendingSeriesUpdate] = []
    private var processingGeneration = 0
    private var searchTask: Task<Void, Never>?
    private var settingsObserver: NSObjectProtocol?

    private struct PendingSeriesUpdate {
        let points: [LinePoint]
        let state: SyncState
        let range: MarketTimeRange
        let cap: Int
        let fromTimestamp: Int64
        let stableBucketSeconds: Int
        let completesStartup: Bool
    }

    init() {
        let initial = InstrumentMetadata(
            id: InstrumentID(type: .crypto, symbol: "BTCUSDT"),
            displaySymbol: "BTC / USDT",
            name: "Bitcoin",
            exchange: "Binance",
            currency: "USDT",
            provider: "binance",
            session: "24/7"
        )
        self.selectedInstrument = initial
        self.syncState = .idle(for: initial.id)
        self.settingsObserver = NotificationCenter.default.addObserver(
            forName: AeviumAPIKeyStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadProviderConfiguration()
            }
        }
    }

    deinit {
        streamTask?.cancel()
        processingTask?.cancel()
        searchTask?.cancel()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func attach(engine: MarketDataEngine) {
        guard self.engine == nil else { return }
        self.engine = engine

        Task {
            let instrument = await engine.defaultInstrument()
            await MainActor.run {
                self.selectInstrument(instrument)
            }
        }
    }

    func setRange(_ range: MarketTimeRange) {
        guard selectedRange != range else { return }
        selectedRange = range
        isRangeTransitioning = !points.isEmpty
        if points.isEmpty {
            displayedRange = range
        }
        restartStream()
    }

    func reloadProviderConfiguration() {
        errorMessage = nil
        restartStream()
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        searchTask?.cancel()

        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run { self.isSearching = true }
            do {
                guard let engine = await MainActor.run(body: { self.engine }) else { return }
                let results = try await engine.searchInstruments(query: query)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.searchResults = results
                    self.isSearching = false
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }

    func commitSearch() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let engine else { return }

        if let first = searchResults.first {
            selectInstrument(first)
            return
        }

        Task {
            do {
                let resolved = try await engine.resolveInstrument(query: trimmed)
                await MainActor.run {
                    self.selectInstrument(resolved)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func selectInstrument(_ instrument: InstrumentMetadata) {
        selectedInstrument = instrument
        searchQuery = instrument.compactTitle
        searchResults = []
        syncState = .idle(for: instrument.id)
        errorMessage = nil
        resetSeries()
        restartStream()
    }

    private func restartStream() {
        streamTask?.cancel()
        processingTask?.cancel()
        processingTask = nil
        pendingSeriesUpdates.removeAll()
        processingGeneration += 1

        guard let engine else { return }
        let instrument = selectedInstrument
        let viewport = MarketViewport(range: selectedRange)

        streamTask = Task { [weak self] in
            guard let self else { return }

            do {
                var receivedInitialUpdate = false
                let stream = await engine.observeSeries(instrument: instrument, viewport: viewport)

                for try await update in stream {
                    guard !Task.isCancelled else { return }
                    let isInitialUpdate = !receivedInitialUpdate
                    receivedInitialUpdate = true
                    let completesStartup = isInitialUpdate
                        && (!update.points.isEmpty
                            || update.state.state == .connected
                            || update.state.state == .failed
                            || update.state.state == .rateLimited
                            || update.errorMessage != nil)

                    await MainActor.run {
                        self.selectedInstrument = update.instrument
                        self.enqueueSeriesUpdate(
                            points: update.points,
                            state: update.state,
                            range: update.viewport.range,
                            cap: update.viewport.chartPointTarget,
                            fromTimestamp: update.viewport.fromTimestamp,
                            stableBucketSeconds: Self.stableBucketSeconds(for: update.viewport),
                            completesStartup: completesStartup
                        )
                        self.errorMessage = update.errorMessage
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.completeStartupIfNeeded(failed: true)
                    self.syncState = SyncState(
                        instrumentID: instrument.id,
                        state: .failed,
                        progress: 0,
                        message: error.localizedDescription,
                        updatedAt: Int64(Date().timeIntervalSince1970)
                    )
                }
            }
        }
    }

    private func enqueueSeriesUpdate(
        points incoming: [LinePoint],
        state: SyncState,
        range: MarketTimeRange,
        cap: Int,
        fromTimestamp: Int64,
        stableBucketSeconds: Int,
        completesStartup: Bool
    ) {
        pendingSeriesUpdates.append(
            PendingSeriesUpdate(
                points: incoming,
                state: state,
                range: range,
                cap: cap,
                fromTimestamp: fromTimestamp,
                stableBucketSeconds: stableBucketSeconds,
                completesStartup: completesStartup
            )
        )

        guard processingTask == nil else { return }

        let generation = processingGeneration
        processingTask = Task { [weak self] in
            await self?.drainSeriesUpdates(generation: generation)
        }
    }

    private func drainSeriesUpdates(generation: Int) async {
        defer {
            if processingGeneration == generation {
                processingTask = nil
            }
        }

        while !Task.isCancelled, processingGeneration == generation {
            guard !pendingSeriesUpdates.isEmpty else { return }

            let update = pendingSeriesUpdates.removeFirst()
            if update.completesStartup {
                completeStartupIfNeeded()
            }
            syncState = update.state

            let visibleExisting = points.filter { $0.timestamp >= update.fromTimestamp }
            let visibleIncoming = update.points.filter { $0.timestamp >= update.fromTimestamp }

            guard !visibleIncoming.isEmpty else {
                if displayedRange == update.range, visibleExisting.count != points.count {
                    let result = await seriesProcessor.analyticsOnly(for: visibleExisting)
                    guard !Task.isCancelled, processingGeneration == generation else { return }

                    points = result.points
                    analytics = result.analytics
                    computeSummary = result.computeSummary
                } else if update.range == selectedRange, Self.resolvesEmptyRangeTransition(update.state.state) {
                    resetSeries()
                    displayedRange = update.range
                }
                continue
            }

            let result = await seriesProcessor.processSnapshot(
                points: visibleIncoming,
                cap: update.cap,
                stableBucketSeconds: update.stableBucketSeconds
            )
            guard !Task.isCancelled, processingGeneration == generation else { return }

            points = result.points
            analytics = result.analytics
            computeSummary = result.computeSummary
            displayedRange = update.range
            isRangeTransitioning = selectedRange != update.range

            if startupState == .loading && !points.isEmpty {
                startupState = .ready
            }
        }
    }

    private func completeStartupIfNeeded(failed: Bool = false) {
        guard startupState == .loading else { return }
        startupState = failed ? .failed : .ready
    }

    private func resetSeries() {
        points = []
        analytics = .empty
        computeSummary = .cpu
        displayedRange = selectedRange
        isRangeTransitioning = false
    }

    private static func stableBucketSeconds(for viewport: MarketViewport) -> Int {
        let bucketCount = max(1, viewport.chartPointTarget / 4)
        return max(1, Int(ceil(viewport.range.duration / Double(bucketCount))))
    }

    private static func resolvesEmptyRangeTransition(_ state: IngestionConnectionState) -> Bool {
        switch state {
        case .connected, .rateLimited, .failed:
            return true
        case .idle, .connecting, .backfilling, .delayed, .disconnected:
            return false
        }
    }
}
