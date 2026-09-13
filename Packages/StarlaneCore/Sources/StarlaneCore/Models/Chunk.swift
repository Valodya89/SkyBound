import Foundation

/// Everything that can exist on the track.
public enum EntityKind: String, Sendable, Codable, CaseIterable {
    case wall, low, beam, laser, coin, gem, orb

    public var isObstacle: Bool {
        switch self {
        case .wall, .low, .beam, .laser: true
        case .coin, .gem, .orb: false
        }
    }

    public var isPickup: Bool { !isObstacle }
}

/// One placement inside a hand-authored chunk. `z` is metres ahead of the chunk start.
public struct ChunkItem: Sendable, Hashable {
    public let kind: EntityKind
    public let lane: Int
    public let z: Double

    public init(_ kind: EntityKind, lane: Int, z: Double) {
        self.kind = kind
        self.lane = lane
        self.z = z
    }
}

/// A hand-authored obstacle/pickup pattern. Higher tiers only appear later in a run.
public struct Chunk: Sendable, Hashable, Identifiable {
    public let name: String
    public let length: Double
    public let tier: Int
    public let items: [ChunkItem]

    public var id: String { name }

    public init(name: String, length: Double, tier: Int, items: [ChunkItem]) {
        self.name = name
        self.length = length
        self.tier = tier
        self.items = items
    }
}

public enum ChunkLibrary {
    public static let all: [Chunk] = [
        Chunk(name: "zigzag", length: 820, tier: 0, items: [
            .init(.wall, lane: 0, z: 0), .init(.wall, lane: 1, z: 0),
            .init(.coin, lane: 2, z: 60), .init(.coin, lane: 2, z: 120), .init(.coin, lane: 2, z: 180),
            .init(.wall, lane: 2, z: 340), .init(.wall, lane: 1, z: 340),
            .init(.coin, lane: 0, z: 400), .init(.coin, lane: 0, z: 460), .init(.coin, lane: 0, z: 520),
            .init(.wall, lane: 0, z: 660), .init(.wall, lane: 2, z: 660),
        ]),
        Chunk(name: "hurdles", length: 760, tier: 0, items: [
            .init(.low, lane: 0, z: 0), .init(.low, lane: 1, z: 0), .init(.low, lane: 2, z: 0),
            .init(.coin, lane: 1, z: 40),
            .init(.low, lane: 0, z: 260), .init(.low, lane: 1, z: 260), .init(.low, lane: 2, z: 260),
            .init(.coin, lane: 1, z: 300),
            .init(.low, lane: 0, z: 520), .init(.low, lane: 1, z: 520), .init(.low, lane: 2, z: 520),
            .init(.gem, lane: 1, z: 560),
        ]),
        Chunk(name: "lowbridge", length: 720, tier: 1, items: [
            .init(.beam, lane: 0, z: 0), .init(.beam, lane: 1, z: 0), .init(.beam, lane: 2, z: 0),
            .init(.coin, lane: 1, z: 70), .init(.coin, lane: 1, z: 130),
            .init(.beam, lane: 0, z: 340), .init(.beam, lane: 1, z: 340), .init(.beam, lane: 2, z: 340),
            .init(.coin, lane: 1, z: 410), .init(.gem, lane: 1, z: 470),
        ]),
        Chunk(name: "pinch", length: 700, tier: 1, items: [
            .init(.wall, lane: 0, z: 0), .init(.wall, lane: 2, z: 0),
            .init(.coin, lane: 1, z: 70), .init(.coin, lane: 1, z: 130), .init(.coin, lane: 1, z: 190),
            .init(.wall, lane: 1, z: 330), .init(.low, lane: 0, z: 330), .init(.low, lane: 2, z: 330),
            .init(.coin, lane: 0, z: 400), .init(.coin, lane: 2, z: 400),
        ]),
        Chunk(name: "staircase", length: 900, tier: 1, items: [
            .init(.low, lane: 0, z: 0), .init(.wall, lane: 1, z: 0), .init(.wall, lane: 2, z: 0),
            .init(.wall, lane: 0, z: 220), .init(.low, lane: 1, z: 220), .init(.wall, lane: 2, z: 220),
            .init(.wall, lane: 0, z: 440), .init(.wall, lane: 1, z: 440), .init(.low, lane: 2, z: 440),
            .init(.coin, lane: 2, z: 520), .init(.coin, lane: 2, z: 580), .init(.gem, lane: 2, z: 640),
        ]),
        Chunk(name: "coinsnake", length: 860, tier: 0, items: [
            .init(.coin, lane: 0, z: 0), .init(.coin, lane: 0, z: 60), .init(.coin, lane: 1, z: 120), .init(.coin, lane: 1, z: 180),
            .init(.coin, lane: 2, z: 240), .init(.coin, lane: 2, z: 300), .init(.gem, lane: 2, z: 360),
            .init(.coin, lane: 1, z: 420), .init(.coin, lane: 1, z: 480), .init(.coin, lane: 0, z: 540), .init(.coin, lane: 0, z: 600),
            .init(.wall, lane: 1, z: 700), .init(.wall, lane: 2, z: 700),
        ]),
        Chunk(name: "gauntlet", length: 1000, tier: 2, items: [
            .init(.wall, lane: 0, z: 0), .init(.wall, lane: 1, z: 0),
            .init(.beam, lane: 2, z: 170),
            .init(.wall, lane: 2, z: 340), .init(.wall, lane: 1, z: 340),
            .init(.low, lane: 0, z: 500),
            .init(.wall, lane: 0, z: 660), .init(.wall, lane: 2, z: 660),
            .init(.beam, lane: 1, z: 820), .init(.coin, lane: 1, z: 880), .init(.gem, lane: 1, z: 930),
        ]),
        Chunk(name: "slalom", length: 960, tier: 2, items: [
            .init(.wall, lane: 1, z: 0), .init(.wall, lane: 2, z: 0), .init(.coin, lane: 0, z: 40),
            .init(.wall, lane: 0, z: 200), .init(.wall, lane: 1, z: 200), .init(.coin, lane: 2, z: 240),
            .init(.wall, lane: 1, z: 400), .init(.wall, lane: 2, z: 400), .init(.coin, lane: 0, z: 440),
            .init(.wall, lane: 0, z: 600), .init(.wall, lane: 1, z: 600), .init(.coin, lane: 2, z: 640),
            .init(.wall, lane: 0, z: 800), .init(.wall, lane: 2, z: 800), .init(.gem, lane: 1, z: 850),
        ]),
        Chunk(name: "orbdrop", length: 640, tier: 0, items: [
            .init(.orb, lane: 1, z: 0), .init(.wall, lane: 0, z: 220), .init(.wall, lane: 2, z: 220),
            .init(.coin, lane: 1, z: 300), .init(.coin, lane: 1, z: 360), .init(.low, lane: 1, z: 500),
        ]),
        Chunk(name: "hoprun", length: 880, tier: 2, items: [
            .init(.low, lane: 1, z: 0), .init(.coin, lane: 1, z: 60),
            .init(.low, lane: 1, z: 180), .init(.coin, lane: 1, z: 240),
            .init(.low, lane: 1, z: 360), .init(.coin, lane: 1, z: 420),
            .init(.low, lane: 1, z: 540), .init(.gem, lane: 1, z: 600),
            .init(.wall, lane: 0, z: 740), .init(.wall, lane: 2, z: 740),
        ]),
        Chunk(name: "crossfire", length: 1040, tier: 3, items: [
            .init(.wall, lane: 0, z: 0), .init(.beam, lane: 1, z: 0), .init(.wall, lane: 2, z: 0),
            .init(.coin, lane: 1, z: 80),
            .init(.low, lane: 0, z: 250), .init(.wall, lane: 1, z: 250), .init(.low, lane: 2, z: 250),
            .init(.wall, lane: 0, z: 480), .init(.wall, lane: 1, z: 480), .init(.beam, lane: 2, z: 480),
            .init(.coin, lane: 2, z: 560), .init(.coin, lane: 2, z: 620),
            .init(.beam, lane: 0, z: 780), .init(.wall, lane: 1, z: 780), .init(.wall, lane: 2, z: 780),
            .init(.gem, lane: 0, z: 860),
        ]),
        Chunk(name: "breather", length: 600, tier: 0, items: [
            .init(.coin, lane: 0, z: 0), .init(.coin, lane: 1, z: 0), .init(.coin, lane: 2, z: 0),
            .init(.coin, lane: 0, z: 120), .init(.coin, lane: 1, z: 120), .init(.coin, lane: 2, z: 120),
            .init(.wall, lane: 1, z: 340),
        ]),
        Chunk(name: "needle", length: 900, tier: 3, items: [
            .init(.wall, lane: 0, z: 0), .init(.wall, lane: 1, z: 0),
            .init(.wall, lane: 1, z: 190), .init(.wall, lane: 2, z: 190),
            .init(.wall, lane: 0, z: 380), .init(.wall, lane: 1, z: 380),
            .init(.beam, lane: 2, z: 560), .init(.low, lane: 2, z: 700),
            .init(.gem, lane: 2, z: 790),
        ]),
        Chunk(name: "tunnelrun", length: 1020, tier: 3, items: [
            .init(.beam, lane: 0, z: 0), .init(.beam, lane: 1, z: 0), .init(.beam, lane: 2, z: 0),
            .init(.coin, lane: 1, z: 70),
            .init(.low, lane: 0, z: 230), .init(.low, lane: 1, z: 230), .init(.low, lane: 2, z: 230),
            .init(.coin, lane: 1, z: 300),
            .init(.beam, lane: 0, z: 460), .init(.beam, lane: 1, z: 460), .init(.beam, lane: 2, z: 460),
            .init(.coin, lane: 1, z: 530),
            .init(.wall, lane: 0, z: 700), .init(.wall, lane: 2, z: 700),
            .init(.gem, lane: 1, z: 780), .init(.orb, lane: 1, z: 900),
        ]),
    ]

    /// Chunks eligible at a given distance.
    public static func pool(forDistance distance: Double) -> [Chunk] {
        let tier = min(max(Int(distance / 1400), 0), 3)
        return all.filter { $0.tier <= tier }
    }
}
