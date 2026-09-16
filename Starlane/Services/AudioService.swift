import Foundation

/// Every sound the game makes, expressed as synth recipes so designers can tune them in one place.
protocol AudioService: AnyObject {
    var soundEnabled: Bool { get set }
    var musicEnabled: Bool { get set }
    func warmUp()
    /// Silences the game while a full-screen ad owns the speakers, and lets it speak again after.
    func suspend()
    func resume()
    func play(_ sound: GameSound)
    func startMusic()
    func stopMusic()
    func updateMusic(intensity: Int, slowMotion: Bool, biomeIndex: Int)
}

enum GameSound: Sendable {
    case coin, gem, hit, jump, duck, tap, ui, nearMiss, win, boss, bossShot, bossTelegraph, bossHit, shieldBlock
    case biome, lightning, countdownTick, countdownGo, wheelSpin, pull(Int)
}

@Observable
final class SynthAudioService: AudioService {
    var soundEnabled = true
    var musicEnabled = true {
        didSet { if !musicEnabled { stopMusic() } }
    }

    private let synth = SynthEngine()
    private var musicTask: Task<Void, Never>?
    private var step = 0
    private var intensity = 1
    private var slowMotion = false
    private var biomeIndex = 0
    private var isSuspended = false
    private static let scale: [Double] = [0, 3, 5, 7, 10, 12, 15, 19]

    init() {}

    func warmUp() { synth.start() }

    func suspend() {
        guard !isSuspended else { return }
        isSuspended = true
        stopMusic()
        // Silencing the voices is enough — the session is `.ambient` and mixes with the ad's audio.
        // Tearing the engine down here would join the render thread from the main actor.
        synth.silence()
    }

    func resume() {
        guard isSuspended else { return }
        isSuspended = false
        synth.start()
    }

    private func tone(_ f: Double, _ d: Double = 0.08, _ w: SynthEngine.Wave = .square, _ v: Double = 0.05, slide: Double = 0) {
        synth.play(frequency: f, duration: d, wave: w, volume: v, slide: slide)
    }

    private func later(_ ms: Int, _ body: @escaping @MainActor () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(ms))
            body()
        }
    }

    func play(_ sound: GameSound) {
        guard soundEnabled, !isSuspended else { return }
        synth.start()
        switch sound {
        case .coin: tone(880, 0.06, .square, 0.035, slide: 300)
        case .gem:
            tone(1200, 0.1, .sine, 0.055, slide: 600)
            later(70) { self.tone(1600, 0.12, .sine, 0.045) }
        case .hit: tone(140, 0.32, .sawtooth, 0.09, slide: -95)
        case .jump: tone(520, 0.08, .triangle, 0.035, slide: 320)
        case .duck: tone(300, 0.08, .triangle, 0.03, slide: -140)
        case .tap: tone(420, 0.04, .triangle, 0.028)
        case .ui: tone(620, 0.05, .sine, 0.032)
        case .nearMiss: tone(1500, 0.05, .sine, 0.03, slide: -600)
        case .win:
            for (i, f) in [523.0, 659, 784, 1046].enumerated() {
                later(i * 80) { self.tone(f, 0.14, .triangle, 0.05) }
            }
        case .boss:
            for (i, f) in [110.0, 98, 87].enumerated() {
                later(i * 180) { self.tone(f, 0.4, .sawtooth, 0.07) }
            }
        case .bossShot: tone(900, 0.18, .sawtooth, 0.055, slide: -600)
        case .bossTelegraph: tone(220, 0.12, .square, 0.04, slide: 180)
        case .bossHit: tone(1100, 0.09, .square, 0.045, slide: -500)
        case .shieldBlock: tone(300, 0.2, .sine, 0.07, slide: 400)
        case .biome: tone(660, 0.25, .triangle, 0.05, slide: 220)
        case .lightning: tone(90, 0.35, .sawtooth, 0.045, slide: -40)
        case .countdownTick: tone(420, 0.04, .triangle, 0.028)
        case .countdownGo: tone(880, 0.16, .triangle, 0.06, slide: 220)
        case .wheelSpin: tone(300, 0.5, .square, 0.03, slide: 600)
        case .pull(let rank): tone(rank >= 3 ? 1400 : rank == 2 ? 1000 : 700, 0.09, .triangle, 0.045)
        }
    }

    func startMusic() {
        guard musicEnabled, !isSuspended, musicTask == nil else { return }
        synth.start()
        step = 0
        musicTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.musicTick()
                try? await Task.sleep(for: .milliseconds(135))
            }
        }
    }

    func stopMusic() {
        musicTask?.cancel()
        musicTask = nil
    }

    func updateMusic(intensity: Int, slowMotion: Bool, biomeIndex: Int) {
        self.intensity = min(max(intensity, 1), 6)
        self.slowMotion = slowMotion
        self.biomeIndex = biomeIndex
    }

    /// Four layers keyed to the combo: bass, arpeggio, hats, lead.
    private func musicTick() {
        guard musicEnabled else { return }
        let slow = slowMotion ? 0.5 : 1
        let rootBase: Double = biomeIndex % 3 == 0 ? 55 : biomeIndex % 3 == 1 ? 49 : 58
        let root = rootBase * slow
        let s = Self.scale
        if step % 4 == 0 { tone(root, 0.30, .sawtooth, 0.030) }
        if intensity >= 2, step % 2 == 0 {
            tone(root * 4 * pow(2, s[(step / 2) % 8] / 12), 0.10, .square, 0.016)
        }
        if intensity >= 3, step % 2 == 1 { tone(7800, 0.02, .square, 0.007) }
        if intensity >= 5, step % 8 == 2 {
            tone(root * 8 * pow(2, s[step % 8] / 12), 0.20, .triangle, 0.017)
        }
        step += 1
    }
}

/// No-op audio for tests and previews.
final class SilentAudioService: AudioService {
    var soundEnabled = false
    var musicEnabled = false
    func warmUp() {}
    func suspend() {}
    func resume() {}
    func play(_ sound: GameSound) {}
    func startMusic() {}
    func stopMusic() {}
    func updateMusic(intensity: Int, slowMotion: Bool, biomeIndex: Int) {}
}
