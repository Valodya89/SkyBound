import Foundation
import Observation
import StarlaneCore

/// Owns the `PlayerProfile`, persists it with a debounce, and runs the one-second economy tick.
///
/// All mutations go through `update(_:)` so persistence and observation stay consistent.
@Observable
final class PlayerStore {
    private(set) var profile: PlayerProfile
    /// Seconds left on the launch offer (session-only, like the prototype).
    private(set) var offerSecondsLeft = ShopSystem.offerDurationSeconds
    /// Leaderboard rivals are rolled once per session.
    private(set) var weeklyBoard: [DailySystem.BoardRow] = []

    @ObservationIgnored private let store: any ProfileStore
    @ObservationIgnored let clock: any Clock
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var rng = SystemRandomSource()
    /// Wall-clock moment the live economy was last advanced (tick or catch-up). Not the save time: at cold launch
    /// the offline window is already credited by `prepare`.
    @ObservationIgnored private var lastAdvancedAt: Date

    init(store: any ProfileStore, clock: any Clock = SystemClock()) {
        self.store = store
        self.clock = clock
        lastAdvancedAt = clock.now
        var loaded = (try? store.load()) ?? PlayerProfile()
        Self.prepare(&loaded, now: clock.now)
        profile = loaded
        weeklyBoard = Self.rollWeeklyBoard(rng: &rng)
        scheduleSave()
    }

    /// Day rollover plus energy that regenerated while the app was closed.
    private static func prepare(_ p: inout PlayerProfile, now: Date) {
        DailySystem.rollover(&p, now: now)
        if p.lastSavedAt > 0 {
            let elapsed = Int(now.timeIntervalSince1970 - p.lastSavedAt)
            EnergySystem.tick(&p, seconds: min(max(elapsed, 0), 86_400))
        }
        if p.selectedMode.config.isHidden { p.selectedMode = .classic }
        // Definitions come from the catalog, progress from the save, so new or retuned entries reach old profiles.
        p.missions = Mission.dailySet.map { def in
            guard let old = p.missions.first(where: { $0.id == def.id }) else { return def }
            var m = def
            m.progress = min(def.goal, old.progress)
            m.isDone = old.isDone || m.progress >= def.goal
            m.isClaimed = old.isClaimed
            return m
        }
        p.achievements = Achievement.defaults.map { def in
            guard let old = p.achievements.first(where: { $0.id == def.id }) else { return def }
            var a = def
            a.progress = min(def.goal, max(def.progress, old.progress))
            return a
        }
    }

    private static func rollWeeklyBoard(rng: inout SystemRandomSource) -> [DailySystem.BoardRow] {
        RivalNames.all.enumerated().map { i, name in
            DailySystem.BoardRow(id: name, name: name, score: Int(5200 - Double(i) * 370 + rng.next(in: -90...90)), isPlayer: false)
        }
    }

    // MARK: - Mutation & persistence

    func update(_ body: (inout PlayerProfile) -> Void) {
        body(&profile)
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    func saveNow() {
        saveTask?.cancel()
        profile.lastSavedAt = clock.now.timeIntervalSince1970
        try? store.save(profile)
    }

    func wipe() {
        saveTask?.cancel()
        try? store.wipe()
        var fresh = PlayerProfile()
        Self.prepare(&fresh, now: clock.now)
        profile = fresh
        offerSecondsLeft = ShopSystem.offerDurationSeconds
        scheduleSave()
    }

    // MARK: - Ticking

    func startTicking() {
        guard tickTask == nil else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                tick()
            }
        }
    }

    func stopTicking() {
        tickTask?.cancel()
        tickTask = nil
    }

    /// One second of wall-clock time. Only a whole energy point earns a disk write; the running timer is
    /// recovered from `lastSavedAt` on the next launch, so writing it every second would just wear the disk.
    func tick() {
        advance(seconds: 1)
    }

    /// Credits the time the process spent suspended (the tick task sleeps with it). Called on activation.
    func catchUp() {
        let elapsed = Int(clock.now.timeIntervalSince(lastAdvancedAt))
        // The regular tick covers anything under a couple of seconds; only real suspensions are credited.
        guard elapsed > 2 else { return }
        advance(seconds: min(elapsed, 86_400))
    }

    private func advance(seconds: Int) {
        lastAdvancedAt = clock.now
        var gained = false
        if profile.energy < profile.maxEnergy {
            let before = profile.energy
            EnergySystem.tick(&profile, seconds: seconds)
            gained = profile.energy != before
        }
        if offerSecondsLeft > 0, !profile.founderBundleOwned { offerSecondsLeft = max(0, offerSecondsLeft - seconds) }
        if gained { scheduleSave() }
    }

    /// Re-checks the calendar day (call when the app returns to the foreground).
    func refreshDay() {
        var p = profile
        if DailySystem.rollover(&p, now: clock.now) {
            profile = p
            scheduleSave()
        }
    }

    // MARK: - Derived

    var isOfferVisible: Bool { !profile.founderBundleOwned && offerSecondsLeft > 0 }

    var leaderboard: [DailySystem.BoardRow] {
        var rows = weeklyBoard
        rows.append(DailySystem.BoardRow(id: "you", name: "YOU", score: profile.bestOverall, isPlayer: true))
        return rows.sorted { $0.score > $1.score }
    }

    var energyLabel: String {
        profile.isEnergyFull ? "\(profile.energy)/\(profile.maxEnergy) FULL"
            : "\(profile.energy)/\(profile.maxEnergy) · \(GameFormat.clock(profile.energyTimer))"
    }
}
