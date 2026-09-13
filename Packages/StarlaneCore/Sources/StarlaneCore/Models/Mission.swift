import Foundation

public struct MissionReward: Sendable, Hashable, Codable {
    public var coins: Int
    public var gems: Int

    public init(coins: Int = 0, gems: Int = 0) {
        self.coins = coins
        self.gems = gems
    }

    public var label: String { gems > 0 ? "\(gems) gems" : "\(coins) coins" }
}

/// A daily mission. Progress is tracked either additively or as a "best of" value.
public struct Mission: Sendable, Hashable, Codable, Identifiable {
    public enum Tracking: String, Sendable, Codable { case cumulative, best }

    public let id: String
    public let title: String
    public let goal: Int
    public let tracking: Tracking
    public let reward: MissionReward
    public var progress: Int
    public var isDone: Bool
    public var isClaimed: Bool

    public init(id: String, title: String, goal: Int, tracking: Tracking, reward: MissionReward,
                progress: Int = 0, isDone: Bool = false, isClaimed: Bool = false) {
        self.id = id
        self.title = title
        self.goal = goal
        self.tracking = tracking
        self.reward = reward
        self.progress = progress
        self.isDone = isDone
        self.isClaimed = isClaimed
    }

    public var fraction: Double { min(1, Double(progress) / Double(max(goal, 1))) }
    public var canClaim: Bool { isDone && !isClaimed }

    public mutating func advance(by n: Int) {
        guard !isDone else { return }
        switch tracking {
        case .cumulative: progress += n
        case .best: progress = max(progress, n)
        }
        if progress >= goal {
            progress = goal
            isDone = true
        }
    }

    public mutating func reset() {
        progress = 0
        isDone = false
        isClaimed = false
    }

    public static let coinsID = "m1"
    public static let distanceID = "m2"
    public static let nearMissID = "m3"

    public static let dailySet: [Mission] = [
        Mission(id: coinsID, title: "Collect 60 coins in runs", goal: 60, tracking: .cumulative, reward: MissionReward(gems: 15)),
        Mission(id: distanceID, title: "Reach 1500m in a single run", goal: 1500, tracking: .best, reward: MissionReward(coins: 400)),
        Mission(id: nearMissID, title: "Land 10 near misses", goal: 10, tracking: .cumulative, reward: MissionReward(gems: 10)),
    ]
}

/// A permanent achievement.
public struct Achievement: Sendable, Hashable, Codable, Identifiable {
    public let id: String
    public let title: String
    public let detail: String
    public let goal: Int
    public var progress: Int

    public init(id: String, title: String, detail: String, goal: Int, progress: Int = 0) {
        self.id = id
        self.title = title
        self.detail = detail
        self.goal = goal
        self.progress = progress
    }

    public var isDone: Bool { progress >= goal }
    public var fraction: Double { min(1, Double(progress) / Double(max(goal, 1))) }

    public mutating func bump(by n: Int) { progress = min(goal, progress + n) }
    public mutating func raise(to n: Int) { progress = max(progress, min(goal, n)) }

    public static let firstRun = "a1"
    public static let kilometreClub = "a2"
    public static let collector = "a3"
    public static let comboArtist = "a4"
    public static let bossHunter = "a5"
    public static let grazer = "a6"
    public static let cartographer = "a7"

    public static let defaults: [Achievement] = [
        Achievement(id: firstRun, title: "First Blood", detail: "Finish your first run", goal: 1),
        Achievement(id: kilometreClub, title: "Kilometre Club", detail: "Travel 5,000m total", goal: 5000),
        Achievement(id: collector, title: "Collector", detail: "Own 5 rockets", goal: 5, progress: 1),
        Achievement(id: comboArtist, title: "Combo Artist", detail: "Hit a ×5 combo", goal: 5, progress: 1),
        Achievement(id: bossHunter, title: "Boss Hunter", detail: "Destroy 5 wardens", goal: 5),
        Achievement(id: grazer, title: "Grazer", detail: "Land 100 near misses", goal: 100),
        Achievement(id: cartographer, title: "Cartographer", detail: "Reach Sector 06", goal: 6, progress: 1),
    ]
}
