import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    let repository: MarketDataRepository

    init() {
        do {
            let dbURL = try Self.databaseURL()
            repository = try MarketDataRepository(databaseURL: dbURL)
        } catch {
            fatalError("Failed to bootstrap data layer: \(error)")
        }
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
