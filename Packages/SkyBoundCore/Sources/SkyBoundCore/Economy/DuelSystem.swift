import Foundation

public enum DuelSystem {
    /// Rivals offered on the challenge list.
    public static var challengeable: [String] { Array(RivalNames.all.prefix(6)) }

    public static func hasOpenDuel(with rival: String, profile: PlayerProfile) -> Bool {
        profile.duels.contains { $0.rivalName == rival && $0.status == .open }
    }

    /// Posts a rival score scaled around the player's best. Returns the duel that was created.
    @discardableResult
    public static func challenge(rival: String, profile: inout PlayerProfile, rng: inout some RandomSource) -> Duel? {
        guard !hasOpenDuel(with: rival, profile: profile) else { return nil }
        let base = Double(profile.bestOverall > 0 ? profile.bestOverall : 900)
        let target = max(600, Int(base * rng.next(in: 0.85...1.35)))
        let index = RivalNames.all.firstIndex(of: rival) ?? 0
        let duel = Duel(rivalName: rival, hue: RivalNames.hue(forIndex: index), rivalScore: target)
        profile.duels.append(duel)
        return duel
    }

    /// Applies a finished run to every open duel. Returns the duels that were just won.
    @discardableResult
    public static func resolve(score: Int, profile: inout PlayerProfile) -> [Duel] {
        var won: [Duel] = []
        for i in profile.duels.indices where profile.duels[i].status == .open {
            profile.duels[i].triesLeft -= 1
            profile.duels[i].yourBest = max(profile.duels[i].yourBest, score)
            if profile.duels[i].yourBest > profile.duels[i].rivalScore {
                profile.duels[i].status = .won
                profile.gems += Duel.winReward
                won.append(profile.duels[i])
            } else if profile.duels[i].triesLeft <= 0 {
                profile.duels[i].status = .lost
            }
        }
        return won
    }
}
