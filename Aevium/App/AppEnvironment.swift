import Foundation

struct InstrumentSelectionRequest: Identifiable {
    let id = UUID()
    let instrument: InstrumentMetadata
}

@MainActor
final class AppEnvironment: ObservableObject {
    let repository: MarketDataRepository
    @Published var instrumentSelectionRequest: InstrumentSelectionRequest?

    init() {
        do {
            let dbURL = try Self.databaseURL()
            repository = try MarketDataRepository(databaseURL: dbURL)
        } catch {
            fatalError("Failed to bootstrap data layer: \(error)")
        }
    }

    func openInstrument(_ instrument: InstrumentMetadata) {
        instrumentSelectionRequest = InstrumentSelectionRequest(instrument: instrument)
    }

    private static func databaseURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let dir = base.appendingPathComponent("Aevium", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("market-data.sqlite")
    }
}
