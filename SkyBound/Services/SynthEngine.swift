import AVFoundation
import Foundation

/// A tiny polyphonic synthesiser. Replaces the prototype's WebAudio oscillators so the game has zero audio assets.
///
/// Voices are rendered on the audio thread; the voice list is guarded by a lock so it can be edited from the main actor.
nonisolated final class SynthEngine: @unchecked Sendable {
    enum Wave: Sendable {
        case sine, square, triangle, sawtooth
    }

    private struct Voice {
        let startFrequency: Double
        let endFrequency: Double
        let duration: Double
        let wave: Wave
        let volume: Double
        var phase: Double = 0
        var time: Double = 0
    }

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let lock = NSLock()
    private var voices: [Voice] = []
    private var sampleRate: Double = 44_100
    private var isRunning = false
    private let maxVoices = 24

    init() {}

    /// Starts the engine lazily. Safe to call repeatedly.
    func start() {
        lock.lock(); defer { lock.unlock() }
        guard !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            // Audio is a nice-to-have; keep the game running.
        }
        let format = engine.outputNode.outputFormat(forBus: 0)
        sampleRate = format.sampleRate > 0 ? format.sampleRate : 44_100
        guard let monoFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let node = AVAudioSourceNode(format: monoFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            self.render(frameCount: Int(frameCount), bufferList: audioBufferList)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: monoFormat)
        engine.mainMixerNode.outputVolume = 0.9
        do {
            try engine.start()
            sourceNode = node
            isRunning = true
        } catch {
            engine.detach(node)
        }
    }

    func stop() {
        lock.lock(); defer { lock.unlock() }
        guard isRunning else { return }
        engine.stop()
        isRunning = false
    }

    /// Plays one tone. `slide` is added to the frequency over the note's lifetime (exponential ramp).
    func play(frequency: Double, duration: Double = 0.08, wave: Wave = .square, volume: Double = 0.05, slide: Double = 0) {
        lock.lock(); defer { lock.unlock() }
        guard isRunning else { return }
        if voices.count >= maxVoices { voices.removeFirst() }
        let end = slide == 0 ? frequency : max(40, frequency + slide)
        voices.append(Voice(startFrequency: frequency, endFrequency: end, duration: max(duration, 0.01), wave: wave, volume: volume))
    }

    private func render(frameCount: Int, bufferList: UnsafeMutablePointer<AudioBufferList>) {
        let abl = UnsafeMutableAudioBufferListPointer(bufferList)
        guard let buffer = abl.first, let data = buffer.mData else { return }
        let out = data.assumingMemoryBound(to: Float.self)
        for i in 0..<frameCount { out[i] = 0 }

        lock.lock()
        guard !voices.isEmpty else { lock.unlock(); return }
        var local = voices
        lock.unlock()

        let dt = 1 / sampleRate
        for v in local.indices {
            var voice = local[v]
            let floorGain = 0.0001 / max(voice.volume, 0.0001)
            for i in 0..<frameCount {
                if voice.time >= voice.duration { break }
                let t = voice.time / voice.duration
                let freq = voice.startFrequency * pow(voice.endFrequency / voice.startFrequency, t)
                let gain = voice.volume * pow(floorGain, t)
                voice.phase += freq * dt
                if voice.phase >= 1 { voice.phase -= floor(voice.phase) }
                out[i] += Float(Self.sample(voice.wave, voice.phase) * gain)
                voice.time += dt
            }
            local[v] = voice
        }
        for i in 0..<frameCount { out[i] = max(-1, min(1, out[i])) }

        lock.lock()
        // Keep voices appended while we were rendering.
        let appended = voices.count > local.count ? Array(voices.suffix(voices.count - local.count)) : []
        voices = local.filter { $0.time < $0.duration } + appended
        lock.unlock()
    }

    private static func sample(_ wave: Wave, _ phase: Double) -> Double {
        switch wave {
        case .sine: return sin(phase * 2 * .pi)
        case .square: return phase < 0.5 ? 1 : -1
        case .triangle: return 1 - 4 * abs(phase - 0.5)
        case .sawtooth: return 2 * phase - 1
        }
    }
}
