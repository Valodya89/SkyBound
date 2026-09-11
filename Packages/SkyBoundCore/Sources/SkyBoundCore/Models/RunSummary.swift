import Foundation

/// The immutable result of a finished run, handed from the simulation to the economy.
public struct RunSummary: Sendable, Hashable, Codable {
    public let mode: GameMode
    public let score: Int
    public let distance: Int
    public let coins: Int
    public let gems: Int
    public let bestCombo: Int
    public let nearMisses: Int
    public let bossesDefeated: Int
    public let zonesReached: Int
    public let endedByTimer: Bool
    public let ghost: [GhostSample]

    public init(mode: GameMode, score: Int, distance: Int, coins: Int, gems: Int, bestCombo: Int,
                nearMisses: Int, bossesDefeated: Int, zonesReached: Int, endedByTimer: Bool, ghost: [GhostSample]) {
        self.mode = mode
        self.score = score
        self.distance = distance
        self.coins = coins
        self.gems = gems
        self.bestCombo = bestCombo
        self.nearMisses = nearMisses
        self.bossesDefeated = bossesDefeated
        self.zonesReached = zonesReached
        self.endedByTimer = endedByTimer
        self.ghost = ghost
    }
}

/// What changed in the profile after a run was banked.
public struct RunOutcome: Sendable, Hashable {
    public var isNewModeBest = false
    public var isPersonalBest = false
    public var levelsGained: [Int] = []
    public var duelsWon: [Duel] = []
    public var xpEarned = 0
    public var passXPEarned = 0

    public init() {}
}
