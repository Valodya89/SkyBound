import Testing
@testable import StarlaneCore

/// A player model with a reaction delay and correct timing for jumps/slides, used to measure fairness.
enum BotPlayer {
    /// Lane with the least danger ahead, weighting near obstacles more and preferring a single-lane move.
    static func safestLane(in sim: RunSimulation, from lane: Int, sight: Double) -> Int {
        var danger = [0.0, 0.0, 0.0]
        let range = sight + 60
        for e in sim.entities where e.kind.isObstacle && e.z > -20 && e.z < range {
            let w = e.kind == .wall || e.kind == .laser ? 1.0 : 0.35
            danger[e.lane] += w * (1 + (range - e.z) / range)
        }
        for l in 0..<3 { danger[l] += Double(abs(l - lane)) * 0.05 }
        return danger.indices.min { danger[$0] < danger[$1] } ?? lane
    }

    struct Result {
        var distance: Double
        var crashed: Bool
        var killer: String
        var seconds: Double = 0
    }

    static func play(seed: UInt32, mode: GameMode = .classic, reactionFrames: Int, sightDepth: Double = 650, maxFrames: Int = 60 * 240, verbose: Bool = false) -> Result {
        var config = RunConfig(mode: mode, viewportWidth: 390, viewportHeight: 844)
        config.seed = seed
        var sim = RunSimulation(config: config)
        sim.begin()
        var noticedAt: [Int: Int] = [:]
        var handled: Set<Int> = []
        var lastLaneChange = -999
        var desiredLane: Int? = nil
        for frame in 0..<maxFrames {
            let lane = sim.ship.targetLane
            let perFrame = sim.speed * 2.6
            for e in sim.entities where e.kind.isObstacle && e.lane == lane && e.z < sightDepth && noticedAt[e.id] == nil {
                noticedAt[e.id] = frame
            }
            let ready = sim.entities.filter { e in
                e.kind.isObstacle && e.lane == lane && !handled.contains(e.id) && (noticedAt[e.id].map { frame - $0 >= reactionFrames } ?? false)
            }.sorted { $0.z < $1.z }
            if let t = ready.first {
                switch t.kind {
                case .low:
                    if t.z < perFrame * 14 + 34 { handled.insert(t.id); _ = sim.jump() } // queued if airborne
                case .beam:
                    if t.z < perFrame * 16 + 34 { handled.insert(t.id); _ = sim.duck() }
                default:
                    handled.insert(t.id)
                    desiredLane = safestLane(in: sim, from: lane, sight: sightDepth)
                }
            }
            if let d = desiredLane, d != sim.ship.targetLane, frame - lastLaneChange >= 2 {
                _ = sim.moveLane(d > sim.ship.targetLane ? 1 : -1)
                lastLaneChange = frame
            }
            if desiredLane == sim.ship.targetLane { desiredLane = nil }
            let before = sim
            let events = sim.step(dt: 1)
            if events.contains(.crashed) {
                let dead = before.entities.filter { $0.kind.isObstacle && $0.z > -50 && $0.z < 90 }
                let desc = dead.map { "\($0.kind.rawValue)@lane\($0.lane) z=\(Int($0.z))" }.joined(separator: ", ")
                let ship = before.ship
                let killer = "\(Int(sim.distance))m f\(frame) spd \(String(format: "%.1f", before.speed)) target \(ship.targetLane) x=\(Int(ship.x)) laneX=\(Int(before.projector.laneX(ship.targetLane))) yOff=\(Int(ship.yOffset)) air=\(ship.isAirborne) duck=\(Int(ship.duckFrames)) | \(desc)"
                if verbose { print("CRASH \(killer)") }
                return Result(distance: sim.distance, crashed: true, killer: killer, seconds: Double(frame) / 60)
            }
        }
        return Result(distance: sim.distance, crashed: false, killer: "", seconds: Double(maxFrames) / 60)
    }
}

@Suite("Playability")
struct PlayabilityTests {
    @Test("Report: survival distance by reaction time")
    func report() {
        for (reaction, label) in [(0, "instant"), (12, "200 ms"), (20, "330 ms"), (30, "500 ms")] {
            var distances: [Double] = []
            var seconds: [Double] = []
            var crashes = 0
            for seed in 1...20 {
                let r = BotPlayer.play(seed: UInt32(seed), reactionFrames: reaction)
                distances.append(r.distance)
                seconds.append(r.seconds)
                if r.crashed { crashes += 1 }
            }
            let avg = distances.reduce(0, +) / Double(distances.count)
            let avgS = seconds.reduce(0, +) / Double(seconds.count)
            print("REPORT reaction \(label): avg \(Int(avg))m / \(Int(avgS))s  min \(Int(distances.min() ?? 0))m / \(Int(seconds.min() ?? 0))s  crashes \(crashes)/20 (cap 240 s)")
        }
        for seed in 1...6 {
            _ = BotPlayer.play(seed: UInt32(seed), reactionFrames: 30, verbose: true)
        }
        #expect(true)
    }

    @Test("A 500 ms player lasts minutes")
    func casualPlayerLastsMinutes() {
        var ok = 0
        var total = 0.0
        for seed in 1...20 {
            let r = BotPlayer.play(seed: UInt32(seed), reactionFrames: 30)
            total += r.seconds
            if r.seconds >= 90 { ok += 1 }
        }
        print("REPORT 500ms lasts ≥90 s in \(ok)/20 seeds, avg \(Int(total / 20)) s")
        #expect(ok >= 16)
        #expect(total / 20 >= 120)
    }
}
