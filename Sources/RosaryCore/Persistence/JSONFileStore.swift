import Foundation

/// Small Codable-to-JSON file store. Everything stays on the device; nothing is synced.
public struct JSONFileStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    /// `Application Support/Rosary` (created if needed).
    public static func applicationSupport() throws -> JSONFileStore {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        )
        return JSONFileStore(directory: base.appendingPathComponent("Rosary", isDirectory: true))
    }

    public func load<T: Decodable>(_ type: T.Type, from name: String) throws -> T? {
        let url = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try Self.decoder.decode(T.self, from: data)
    }

    public func save<T: Encodable>(_ value: T, to name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try Self.encoder.encode(value)
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
