import Foundation

/// Saves and loads the wheel to a JSON file.
public enum ClipStorePersistence {
    private struct Envelope: Codable {
        var version: Int
        var store: ClipStore
    }

    static let currentVersion = 1

    public static func load(from url: URL) throws -> ClipStore? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Envelope.self, from: data).store
    }

    public static func save(_ store: ClipStore, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(Envelope(version: currentVersion, store: store))
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }
}
