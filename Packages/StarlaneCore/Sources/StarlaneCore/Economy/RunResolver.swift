import Foundation

/// Banks a finished run into the profile: bests, ghosts, XP, pass progress, missions, achievements, duels.
public enum RunResolver {
    /// Applies `run` to the profile. When the same run was already banked once (it ended, was revived and
    /// ended again), pass that earlier summary as `previouslyBanked`: additive rewards are then credited only
    /// for what happened since, while bests keep using the full totals.
    public static func bank(_ run: RunSummary, previouslyBanked previous: RunSummary? = nil, into profile: inout PlayerProfile) -> RunOutcome {
        var outcome = RunOutcome()
        let mode = run.mode
        let payout = mode.config.payout
        let isContinuation = previous != nil
        let coins = max(0, run.coins - (previous?.coins ?? 0))
        let gems = max(0, run.gems - (previous?.gems ?? 0))
        let distance = max(0, run.distance - (previous?.distance ?? 0))
        let nearMisses = max(0, run.nearMisses - (previous?.nearMisses ?? 0))
        let bosses = max(0, run.bossesDefeated - (previous?.bossesDefeated ?? 0))
        let scoreGain = max(0, run.score - (previous?.score ?? 0))

        outcome.coinsEarned = coins
        profile.coins += coins
        profile.gems += gems
        if !isContinuation { profile.totalRuns += 1 }
        profile.totalDistance += distance
        profile.totalCoins += coins
        profile.totalNearMisses += nearMisses
        profile.bossKills += bosses

        let previousBest = profile.best(for: mode)
        outcome.isNewModeBest = run.score > previousBest
        profile.bestByMode[mode] = max(previousBest, run.score)
        if outcome.isNewModeBest, run.ghost.count > 4 {
            profile.ghosts[mode] = run.ghost
        }
        outcome.isPersonalBest = run.score > profile.bestOverall
        profile.bestOverall = max(profile.bestOverall, run.score)

        outcome.xpEarned = scoreGain / 8 + coins
        outcome.levelsGained = Progression.addXP(outcome.xpEarned, to: &profile)
        outcome.passXPEarned = Int(Double(scoreGain) / 6 * payout) + coins
        profile.passXP += outcome.passXPEarned

        profile.advanceMission(Mission.coinsID, by: coins)
        profile.advanceMission(Mission.distanceID, by: run.distance)
        profile.advanceMission(Mission.nearMissID, by: nearMisses)

        if !isContinuation { profile.bumpAchievement(Achievement.firstRun, by: 1) }
        profile.bumpAchievement(Achievement.kilometreClub, by: distance)
        profile.bumpAchievement(Achievement.grazer, by: nearMisses)
        profile.bumpAchievement(Achievement.bossHunter, by: bosses)
        profile.raiseAchievement(Achievement.comboArtist, to: run.bestCombo)
        profile.raiseAchievement(Achievement.cartographer, to: min(6, run.zonesReached))

        if mode == .daily {
            profile.dailyChallengeDone = true
            profile.dailyChallengeScore = max(profile.dailyChallengeScore, run.score)
        }
        outcome.duelsWon = DuelSystem.resolve(score: run.score, consumesAttempt: !isContinuation, profile: &profile)
        return outcome
    }
}
