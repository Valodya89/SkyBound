import Foundation

/// Banks a finished run into the profile: bests, ghosts, XP, pass progress, missions, achievements, duels.
public enum RunResolver {
    public static func bank(_ run: RunSummary, into profile: inout PlayerProfile) -> RunOutcome {
        var outcome = RunOutcome()
        let mode = run.mode
        let payout = mode.config.payout

        profile.coins += run.coins
        profile.gems += run.gems
        profile.totalRuns += 1
        profile.totalDistance += run.distance
        profile.totalCoins += run.coins
        profile.totalNearMisses += run.nearMisses
        profile.bossKills += run.bossesDefeated

        let previousBest = profile.best(for: mode)
        outcome.isNewModeBest = run.score > previousBest
        profile.bestByMode[mode] = max(previousBest, run.score)
        if outcome.isNewModeBest, run.ghost.count > 4 {
            profile.ghosts[mode] = run.ghost
        }
        outcome.isPersonalBest = run.score > profile.bestOverall
        profile.bestOverall = max(profile.bestOverall, run.score)

        outcome.xpEarned = run.score / 8 + run.coins
        outcome.levelsGained = Progression.addXP(outcome.xpEarned, to: &profile)
        outcome.passXPEarned = Int(Double(run.score) / 6 * payout) + run.coins
        profile.passXP += outcome.passXPEarned

        profile.advanceMission(Mission.coinsID, by: run.coins)
        profile.advanceMission(Mission.distanceID, by: run.distance)
        profile.advanceMission(Mission.nearMissID, by: run.nearMisses)

        profile.bumpAchievement(Achievement.firstRun, by: 1)
        profile.bumpAchievement(Achievement.kilometreClub, by: run.distance)
        profile.bumpAchievement(Achievement.grazer, by: run.nearMisses)
        profile.bumpAchievement(Achievement.bossHunter, by: run.bossesDefeated)
        if run.bestCombo >= 5 { profile.raiseAchievement(Achievement.comboArtist, to: 5) }
        profile.raiseAchievement(Achievement.cartographer, to: min(6, run.zonesReached))

        if mode == .daily {
            profile.dailyChallengeDone = true
            profile.dailyChallengeScore = max(profile.dailyChallengeScore, run.score)
        }
        outcome.duelsWon = DuelSystem.resolve(score: run.score, profile: &profile)
        return outcome
    }
}
