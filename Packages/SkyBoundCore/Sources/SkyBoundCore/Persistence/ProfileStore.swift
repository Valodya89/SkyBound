import Foundation

/// Where the profile lives. Implementations must be safe to call from the main actor.
public protocol ProfileStore: Sendable {
    func load() throws -> PlayerProfile?
    func save(_ profile: PlayerProfile) throws
    func wipe() throws
}

/// JSON file in Application Support. Writes are atomic.
public final class FileProfileStore: ProfileStore {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    public init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
    }

    /// Default location: `<Application Support>/SkyBound/profile.json`.
    public static func standard(fileManager: FileManager = .default) throws -> FileProfileStore {
        let base = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("SkyBound", isDirectory: true)
        try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return FileProfileStore(fileURL: dir.appendingPathComponent("profile.json"))
    }

    public func load() throws -> PlayerProfile? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(PlayerProfile.self, from: data)
    }

    public func save(_ profile: PlayerProfile) throws {
        let data = try encoder.encode(profile)
        try data.write(to: fileURL, options: [.atomic])
    }

    public func wipe() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}

/// Keeps the profile in memory. Used by tests and previews.
public final class InMemoryProfileStore: ProfileStore, @unchecked Sendable {
    private let lock = NSLock()
    private var stored: PlayerProfile?
    public private(set) var saveCount = 0

    public init(initial: PlayerProfile? = nil) { stored = initial }

    public func load() throws -> PlayerProfile? { lock.withLock { stored } }

    public func save(_ profile: PlayerProfile) throws {
        lock.withLock {
            stored = profile
            saveCount += 1
        }
    }

    public func wipe() throws { lock.withLock { stored = nil } }
}
