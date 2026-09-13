import Foundation

/// An asynchronous score battle against a simulated rival.
public struct Duel: Sendable, Hashable, Codable, Identifiable {
    public enum Status: String, Sendable, Codable { case open, won, lost }

    public let id: UUID
    public let rivalName: String
    public let hue: Double
    public let rivalScore: Int
    public var yourBest: Int
    public var triesLeft: Int
    public var status: Status

    public init(id: UUID = UUID(), rivalName: String, hue: Double, rivalScore: Int,
                yourBest: Int = 0, triesLeft: Int = 3, status: Status = .open) {
        self.id = id
        self.rivalName = rivalName
        self.hue = hue
        self.rivalScore = rivalScore
        self.yourBest = yourBest
        self.triesLeft = triesLeft
        self.status = status
    }

    public static let winReward = 40
    public static let attempts = 3
}
