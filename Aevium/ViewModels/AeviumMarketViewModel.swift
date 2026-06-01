import Foundation
import SwiftUI

@MainActor
final class AeviumMarketViewModel: ObservableObject {
    @Published var selectedInstrument: InstrumentMetadata
    @Published var points: [LinePoint] = []
    @Published var syncState: SyncState
    @Published var searchQuery = ""
    @Published var searchResults: [InstrumentMetadata] = []
    @Published var isSearching = false
    @Published var errorMessage: String?

    private var repository: MarketDataRepository?
    private var selectedRange: MarketTimeRange = .week
    private var liveTask: Task<Void, Never>?
    private var backfillTask: Task<Void, Never>?
    private var searchTask: Task<Void, Never>?
    private var settingsObserver: NSObjectProtocol?

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
        liveTask?.cancel()
        backfillTask?.cancel()
        searchTask?.cancel()
        if let settingsObserver {
            NotificationCenter.default.removeObserver(settingsObserver)
        }
    }

    func attach(repository: MarketDataRepository) {
        guard self.repository == nil else { return }
        self.repository = repository

        Task {
            let instrument = await repository.defaultInstrument()
            await MainActor.run {
                self.selectInstrument(instrument)
            }
        }
    }

    func setRange(_ range: MarketTimeRange) {
        guard selectedRange != range else { return }
        selectedRange = range
        restartStreams()
    }

    func reloadProviderConfiguration() {
        errorMessage = nil
        restartStreams()
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        searchTask?.cancel()

        guard query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
            searchResults = []
            return
        }

        searchTask = Task {
            guard let repository else { return }
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }

            await MainActor.run { self.isSearching = true }
            do {
                let results = try await repository.searchInstruments(query: query)
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
        guard !trimmed.isEmpty, let repository else { return }

        if let first = searchResults.first {
            selectInstrument(first)
            return
        }

        Task {
            let inferred = await repository.resolveInstrument(query: trimmed)
            await MainActor.run {
                self.selectInstrument(inferred)
            }
        }
    }

    func selectInstrument(_ instrument: InstrumentMetadata) {
        selectedInstrument = instrument
        searchQuery = instrument.compactTitle
        searchResults = []
        syncState = .idle(for: instrument.id)
        errorMessage = nil
        points = []
        restartStreams()
    }

    private func restartStreams() {
        liveTask?.cancel()
        backfillTask?.cancel()

        guard let repository else { return }
        let instrument = selectedInstrument
        let viewport = MarketViewport(range: selectedRange)

        liveTask = Task {
            do {
                for try await snapshot in await repository.subscribeLive(instrument: instrument, viewport: viewport) {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.syncState = snapshot.state
                        self.merge(points: snapshot.points, cap: viewport.visiblePointTarget)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
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

        guard viewport.usesHistoricalBackfill else {
            backfillTask = nil
            return
        }

        backfillTask = Task {
            for await event in await repository.startBackfill(instrument: instrument, viewport: viewport) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self.syncState = event.state
                    self.merge(points: event.insertedPoints, cap: viewport.visiblePointTarget)
                }
            }
        }
    }

    private func merge(points incoming: [LinePoint], cap: Int) {
        guard !incoming.isEmpty else { return }

        let boundedIncoming = sampleLinePoints(incoming, limit: cap)
        guard !points.isEmpty else {
            points = boundedIncoming
            return
        }

        var merged: [LinePoint] = []
        merged.reserveCapacity(min(points.count + boundedIncoming.count, cap * 2))

        var existingIndex = 0
        var incomingIndex = 0

        while existingIndex < points.count || incomingIndex < boundedIncoming.count {
            if existingIndex >= points.count {
                merged.append(boundedIncoming[incomingIndex])
                incomingIndex += 1
            } else if incomingIndex >= boundedIncoming.count {
                merged.append(points[existingIndex])
                existingIndex += 1
            } else {
                let existing = points[existingIndex]
                let incomingPoint = boundedIncoming[incomingIndex]

                if existing.timestamp == incomingPoint.timestamp {
                    merged.append(incomingPoint)
                    existingIndex += 1
                    incomingIndex += 1
                } else if existing.timestamp < incomingPoint.timestamp {
                    merged.append(existing)
                    existingIndex += 1
                } else {
                    merged.append(incomingPoint)
                    incomingIndex += 1
                }
            }
        }

        points = sampleLinePoints(merged, limit: cap)
    }

    private func sampleLinePoints(_ source: [LinePoint], limit: Int) -> [LinePoint] {
        guard source.count > limit, limit > 2 else { return source }

        let step = Double(source.count - 1) / Double(limit - 1)
        return (0..<limit).map { index in
            let sourceIndex = min(max(Int((Double(index) * step).rounded()), 0), source.count - 1)
            return source[sourceIndex]
        }
    }
}
