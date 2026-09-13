import Foundation
import Observation
import StarlaneCore

/// What the in-run HUD shows. Rebuilt every frame; equality prevents redundant SwiftUI updates.
struct HUDSnapshot: Equatable {
    var score = 0
    var combo = 1
    var timerText = ""
    var timerWarning = false
    var hasShield = false
    var magnetSeconds = 0
    var slowmoSeconds = 0
    var doubleCoins = false
    var isVIP = false
    var bossName: String?
    var bossHealth: Double = 1
    var distance = 0
    var coins = 0
    /// Full magnet duration for this run, so the HUD bar drains from 1 to 0.
    var magnetTotalSeconds = 8
}

/// Lifecycle of one run: countdown → playing → paused/crashed → results. Also hosts the hub's attract backdrop.
///
/// The SpriteKit scene calls `advance(now:)` every frame and renders whatever `simulation` contains.
@Observable
final class RunController {
    enum Phase: Equatable {
        case attract, countdown, playing, paused, crashed, results
    }

    private(set) var phase: Phase = .attract
    private(set) var hud = HUDSnapshot()
    private(set) var countdownLabel: String?
    private(set) var biomeBanner: Biome?
    private(set) var showControlHint = false
    private(set) var reviveFraction: Double = 0
    private(set) var isReviveOpen = false
    /// While true (an ad is showing, the app is inactive) the revive window stops counting down.
    @ObservationIgnored var reviveSuspended = false
    static let reviveWindowSeconds: Double = 6
    /// True once a revive was offered this run, so the results layout can stay stable after it expires.
    private(set) var reviveWasOffered = false
    /// When the countdown released the ship; taps (not swipes) are ignored briefly after this so a double-tap
    /// on PLAY can't move the ship.
    @ObservationIgnored private var playingSince: Date? = nil
    static let tapGraceSeconds: TimeInterval = 0.6

    var acceptsTaps: Bool {
        guard phase == .playing, let since = playingSince else { return false }
        return Date().timeIntervalSince(since) >= Self.tapGraceSeconds
    }
    private(set) var summary: RunSummary?
    private(set) var outcome: RunOutcome?
    private(set) var viewport = CGSize(width: 390, height: 844)

    /// Read by the scene each frame. Not observed: it changes 60 times a second.
    @ObservationIgnored private(set) var simulation: RunSimulation
    @ObservationIgnored private var lastFrameTime: TimeInterval?
    @ObservationIgnored private var countdownTask: Task<Void, Never>?
    @ObservationIgnored private var reviveTask: Task<Void, Never>?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var crashTask: Task<Void, Never>?
    @ObservationIgnored private let audio: any AudioService
    @ObservationIgnored private let haptics: any HapticsService
    @ObservationIgnored private var screenShakeEnabled = true
    @ObservationIgnored private var quitRequested = false

    /// Called when the simulation reports the run is over (crash settled, timer expired or quit). The second
    /// argument is the summary that was already banked for this run before a revive, or nil the first time.
    @ObservationIgnored var onRunEnded: (@MainActor (RunSummary, RunSummary?) -> Void)?
    /// Summary handed to `onRunEnded` the last time this run ended; a revive continues the same run.
    @ObservationIgnored private var bankedSummary: RunSummary?
    @ObservationIgnored private var hintTask: Task<Void, Never>?

    init(audio: any AudioService, haptics: any HapticsService) {
        self.audio = audio
        self.haptics = haptics
        simulation = .attract(viewportWidth: 390, viewportHeight: 844)
    }

    var isInRun: Bool { phase != .attract }
    var shakeEnabled: Bool { screenShakeEnabled }

    // MARK: - Viewport

    func viewportChanged(_ size: CGSize) {
        guard size.width > 0, size.height > 0, size != viewport else { return }
        viewport = size
        simulation.resize(width: size.width, height: size.height)
    }

    // MARK: - Attract

    func startAttract() {
        cancelTimers()
        phase = .attract
        summary = nil
        outcome = nil
        simulation = .attract(viewportWidth: viewport.width, viewportHeight: viewport.height)
        audio.stopMusic()
    }

    // MARK: - Run lifecycle

    /// Builds the simulation for a run and starts the 3-2-1 countdown.
    func start(config: RunConfig, screenShake: Bool) {
        cancelTimers()
        screenShakeEnabled = screenShake
        var cfg = config
        cfg.viewportWidth = viewport.width
        cfg.viewportHeight = viewport.height
        simulation = RunSimulation(config: cfg)
        summary = nil
        outcome = nil
        bankedSummary = nil
        quitRequested = false
        reviveWasOffered = false
        hud = HUDSnapshot()
        showControlHint = true
        hintTask?.cancel()
        hintTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.showControlHint = false
        }
        beginCountdown()
    }

    func beginCountdown() {
        countdownTask?.cancel()
        phase = .countdown
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for label in ["3", "2", "1", "GO"] {
                guard !Task.isCancelled else { return }
                countdownLabel = label
                audio.play(label == "GO" ? .countdownGo : .countdownTick)
                try? await Task.sleep(for: .milliseconds(600))
            }
            guard !Task.isCancelled else { return }
            countdownLabel = nil
            simulation.begin()
            phase = .playing
            playingSince = Date()
            lastFrameTime = nil
            audio.startMusic()
        }
    }

    func pause() {
        guard phase == .playing else { return }
        phase = .paused
        simulation.pause()
        audio.stopMusic()
    }

    func resume() {
        guard phase == .paused else { return }
        beginCountdown()
    }

    /// Quits from the pause menu: the run is banked as-is.
    func quit() {
        guard phase == .paused || phase == .playing else { return }
        quitRequested = true
        finish()
    }

    func revive() {
        guard phase == .results, simulation.mode.allowsRevive, !simulation.hasRevived, !quitRequested,
              !(summary?.endedByTimer ?? false) else { return }
        cancelReviveTimer()
        reviveWasOffered = false
        simulation.revive()
        beginCountdown()
    }

    func doublePayout() {
        simulation.markPayoutDoubled()
        refreshHUD()
    }

    private func finish() {
        cancelTimers()
        phase = .results
        audio.stopMusic()
        let s = simulation.summary
        summary = s
        if simulation.mode.allowsRevive, !simulation.hasRevived, !s.endedByTimer, !quitRequested {
            startReviveTimer()
        }
        let previous = bankedSummary
        bankedSummary = s
        onRunEnded?(s, previous)
    }

    func recordOutcome(_ outcome: RunOutcome) {
        self.outcome = outcome
        if outcome.isPersonalBest { audio.play(.win) }
    }

    var canRevive: Bool {
        phase == .results && isReviveOpen && simulation.mode.allowsRevive && !simulation.hasRevived && !(summary?.endedByTimer ?? false)
    }

    var canDoublePayout: Bool {
        phase == .results && !simulation.hasDoubledPayout && simulation.coins > 0
    }

    private func startReviveTimer() {
        isReviveOpen = true
        reviveWasOffered = true
        reviveFraction = 1
        reviveSuspended = false
        reviveTask = Task { [weak self] in
            var elapsed: Double = 0
            var last = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled, let self else { return }
                let now = Date()
                // Time spent suspended (ad on screen, app inactive) does not count against the window.
                if !reviveSuspended { elapsed += min(now.timeIntervalSince(last), 0.5) }
                last = now
                reviveFraction = max(0, 1 - elapsed / Self.reviveWindowSeconds)
                if elapsed >= Self.reviveWindowSeconds {
                    isReviveOpen = false
                    return
                }
            }
        }
    }

    /// The app is leaving the foreground: a countdown becomes a pause so the ship never launches unattended.
    func appWillResignActive() {
        switch phase {
        case .playing:
            pause()
        case .countdown:
            countdownTask?.cancel()
            countdownTask = nil
            countdownLabel = nil
            phase = .paused
            simulation.pause()
        case .results:
            reviveSuspended = true
        case .attract, .paused, .crashed:
            break
        }
    }

    func appDidBecomeActive() {
        reviveSuspended = false
    }

    func cancelReviveTimer() {
        reviveTask?.cancel()
        reviveTask = nil
        isReviveOpen = false
    }

    private func cancelTimers() {
        countdownTask?.cancel()
        countdownTask = nil
        crashTask?.cancel()
        crashTask = nil
        hintTask?.cancel()
        hintTask = nil
        bannerTask?.cancel()
        bannerTask = nil
        biomeBanner = nil
        cancelReviveTimer()
        countdownLabel = nil
    }

    // MARK: - Input

    func moveLane(_ direction: Int) {
        if let e = simulation.moveLane(direction) { react(to: e) }
    }

    func jump() {
        if let e = simulation.jump() { react(to: e) }
    }

    func duck() {
        if let e = simulation.duck() { react(to: e) }
    }

    // MARK: - Frame

    /// Steps the world for one rendered frame and returns the events for the scene's visuals.
    func advance(now: TimeInterval) -> [RunEvent] {
        defer { lastFrameTime = now }
        let seconds = lastFrameTime.map { now - $0 } ?? (1 / 60)
        let dt = RunSimulation.frames(forSeconds: seconds)

        switch phase {
        case .attract:
            return simulation.step(dt: dt)
        case .playing, .crashed:
            let events = simulation.step(dt: dt)
            for e in events { react(to: e) }
            refreshHUD()
            return events
        case .countdown, .paused, .results:
            // The world is frozen; only shake/flash settle so the still frame looks calm.
            if simulation.cameraShake > 0 || simulation.flash > 0 || simulation.strobe > 0 {
                simulation.decayEffects(dt: dt)
            }
            return []
        }
    }

    private func refreshHUD() {
        let s = simulation
        var h = HUDSnapshot()
        h.score = Int(s.score)
        h.combo = s.combo
        if s.mode.isTimed {
            h.timerText = "\(Int(ceil(s.timeLeft)))s"
            h.timerWarning = s.timeLeft < 10
        } else {
            h.timerText = "\(Int(s.distance))m"
        }
        h.hasShield = s.hasShield
        h.magnetSeconds = Int(ceil(s.magnetFrames / 60))
        h.magnetTotalSeconds = 8 + Int(Double(s.upgradeLevel(.magnetField)) * 1.5)
        h.slowmoSeconds = Int(ceil(s.slowmoFrames / 60))
        h.doubleCoins = s.doubleCoins
        h.isVIP = s.config.isVIP
        h.bossName = s.boss?.name
        h.bossHealth = s.boss?.healthFraction ?? 1
        h.distance = Int(s.distance)
        h.coins = s.coins
        if h != hud { hud = h }
    }

    private func react(to event: RunEvent) {
        switch event {
        case .coinCollected:
            audio.play(.coin)
        case .gemCollected:
            audio.play(.gem)
            haptics.light()
        case .orbCollected:
            audio.play(.gem)
            haptics.medium()
        case .nearMiss:
            audio.play(.nearMiss)
            haptics.light()
        case .shieldBlocked:
            audio.play(.shieldBlock)
            haptics.medium()
        case .crashed:
            phase = .crashed
            audio.play(.hit)
            audio.stopMusic()
            haptics.heavy()
            crashTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(620))
                guard !Task.isCancelled else { return }
                self?.finish()
            }
        case .timeUp:
            finish()
        case .bossSpawned:
            audio.play(.boss)
            haptics.medium()
        case .bossTelegraph:
            audio.play(.bossTelegraph)
        case .bossFired:
            audio.play(.bossShot)
        case .bossDamaged:
            audio.play(.bossHit)
        case .bossDefeated:
            audio.play(.win)
            haptics.success()
        case .biomeChanged(let index):
            audio.play(.biome)
            showBanner(BiomeCatalog.biome(forZone: index))
        case .jumped:
            audio.play(.jump)
        case .ducked:
            audio.play(.duck)
        case .laneChanged:
            audio.play(.tap)
        case .comboChanged(let combo):
            audio.updateMusic(intensity: combo, slowMotion: simulation.slowmoFrames > 0, biomeIndex: simulation.biomeIndex)
        case .lightning:
            audio.play(.lightning)
        }
    }

    private func showBanner(_ biome: Biome) {
        bannerTask?.cancel()
        biomeBanner = biome
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(2100))
            guard !Task.isCancelled else { return }
            self?.biomeBanner = nil
        }
    }
}
