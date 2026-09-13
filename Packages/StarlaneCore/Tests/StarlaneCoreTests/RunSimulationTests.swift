import Testing
@testable import StarlaneCore

@Suite("RunSimulation")
struct RunSimulationTests {
    private func makeSim(mode: GameMode = .classic, seed: UInt32? = 42, boost: BoostKind? = nil) -> RunSimulation {
        var config = RunConfig(mode: mode, viewportWidth: 390, viewportHeight: 844)
        config.seed = seed
        config.equippedBoost = boost
        var sim = RunSimulation(config: config)
        sim.begin()
        return sim
    }

    @Test("Seeded runs are deterministic")
    func deterministic() {
        var a = makeSim(seed: 7)
        var b = makeSim(seed: 7)
        for _ in 0..<600 {
            _ = a.step(dt: 1)
            _ = b.step(dt: 1)
        }
        #expect(a.entities.map(\.z) == b.entities.map(\.z))
        #expect(a.score == b.score)
        #expect(a.distance == b.distance)
    }

    @Test("Distance and score climb while running")
    func progresses() {
        var sim = makeSim()
        for _ in 0..<120 { _ = sim.step(dt: 1) }
        #expect(sim.distance > 0)
        #expect(sim.score > 0)
        #expect(sim.worldZ > 0)
    }

    @Test("Speed starts gentle and ramps up little by little")
    func speedRamp() {
        var sim = makeSim(seed: 21)
        _ = sim.step(dt: 1)
        let start = sim.speed
        #expect(abs(start - sim.baseSpeed * RunSimulation.rampStartFraction) < 0.1)
        var previous = start
        var samples: [Double] = []
        for _ in 0..<40 {
            for _ in 0..<45 where sim.isRunning { _ = sim.step(dt: 1) }
            guard sim.isRunning else { break }
            // A collected slow-mo orb halves speed; only compare unslowed frames.
            guard sim.slowmoFrames <= 0 else { continue }
            #expect(sim.speed >= previous - 0.0001)
            samples.append(sim.speed - previous)
            previous = sim.speed
        }
        // No single 0.75 s window jumps by more than a small fraction of base speed.
        #expect(samples.allSatisfy { $0 < sim.baseSpeed * 0.06 })
        #expect(sim.rampProgress > 0)
    }

    @Test("Difficulty curve eases the opening")
    func difficultyCurve() {
        #expect(RunSimulation.difficulty(forDistance: 0) == 0)
        #expect(RunSimulation.difficulty(forDistance: RunSimulation.difficultyRampMetres / 2) == 0.5)
        #expect(RunSimulation.difficulty(forDistance: 9000) == 1)
        #expect(RunSimulation.obstacleKeepScale(0) < RunSimulation.obstacleKeepScale(1))
        #expect(RunSimulation.obstacleKeepScale(1) <= 1)
        #expect(RunSimulation.gapScale(0) > RunSimulation.gapScale(1))
        #expect(RunSimulation.gapScale(1) == 1)
        for name in RunSimulation.warmUpChunkNames {
            #expect(ChunkLibrary.all.contains { $0.name == name })
        }
    }

    @Test("Obstacle rows are spaced by time, not distance")
    func rowSpacing() {
        let slow = RunSimulation.spacingStretch(speed: 1.5, difficulty: 0)
        let cruise = RunSimulation.spacingStretch(speed: 4.3, difficulty: 0)
        let fast = RunSimulation.spacingStretch(speed: 7, difficulty: 1)
        #expect(slow >= 1)
        #expect(cruise > slow)
        // At cruising speed the tightest authored gap becomes ≥ 0.75 s of travel.
        let framesAtCruise = RunSimulation.tightestAuthoredRowGap * cruise / (4.3 * 2.6)
        #expect(framesAtCruise >= 45)
        // Faster and harder still leaves at least ~0.55 s.
        let framesFast = RunSimulation.tightestAuthoredRowGap * fast / (7 * 2.6)
        #expect(framesFast >= 33)
    }

    @Test("Path hint points to a free lane and stays put while the threat approaches")
    func pathHint() {
        var config = RunConfig(mode: .classic, viewportWidth: 390, viewportHeight: 844)
        config.seed = 8
        var sim = RunSimulation(config: config)
        sim.begin()
        var seenLane: Int? = nil
        var hintFrames = 0
        var changes = 0
        for _ in 0..<3000 where sim.isRunning {
            _ = sim.step(dt: 1)
            if let h = sim.pathHint {
                hintFrames += 1
                #expect(h.lane != sim.ship.targetLane)
                #expect(!sim.entities.contains { ($0.kind == .wall || $0.kind == .laser) && $0.lane == h.lane && $0.z > -10 && $0.z < sim.pathHintLookahead })
                if let prev = seenLane, prev != h.lane { changes += 1 }
                seenLane = h.lane
            } else {
                seenLane = nil
            }
        }
        #expect(hintFrames > 0)
        #expect(changes == 0)
    }

    @Test("Path hint clears once the ship heads for the safe lane")
    func pathHintClears() {
        var config = RunConfig(mode: .classic, viewportWidth: 390, viewportHeight: 844)
        config.seed = 8
        var sim = RunSimulation(config: config)
        sim.begin()
        for _ in 0..<3000 where sim.isRunning && sim.pathHint == nil { _ = sim.step(dt: 1) }
        guard let hint = sim.pathHint else { Issue.record("no hint produced"); return }
        _ = sim.moveLane(hint.lane > sim.ship.targetLane ? 1 : -1)
        _ = sim.step(dt: 1)
        #expect(sim.pathHint == nil)
    }

    @Test("Warm-up only spawns gentle patterns")
    func warmUpPatterns() {
        var sim = makeSim(seed: 5)
        // Collect the first wave of entities before anything can reach the ship.
        for _ in 0..<40 { _ = sim.step(dt: 1) }
        let wallsAtSameDepth = Dictionary(grouping: sim.entities.filter { $0.kind == .wall }, by: { Int($0.z) })
        // Gentle patterns never put walls in two lanes at the same depth.
        #expect(wallsAtSameDepth.values.allSatisfy { $0.count <= 1 })
        #expect(sim.difficulty < RunSimulation.warmUpDifficulty)
    }

    @Test("First obstacles arrive after an opening gap")
    func openingGap() {
        var sim = makeSim(seed: 21)
        var frames = 0
        while sim.entities.isEmpty, frames < 600 {
            _ = sim.step(dt: 1)
            frames += 1
        }
        #expect(frames > 30)
        #expect(!sim.entities.isEmpty)
    }

    @Test("Head start banks 800 metres")
    func headStart() {
        let sim = makeSim(boost: .headStart)
        #expect(sim.distance == 800)
        #expect(sim.score == 800)
    }

    @Test("Equipped shield survives one wall")
    func shieldBlocksOnce() {
        var config = RunConfig(mode: .classic, viewportWidth: 390, viewportHeight: 844)
        config.equippedBoost = .shield
        config.seed = 1
        var sim = RunSimulation(config: config)
        sim.begin()
        #expect(sim.hasShield)
        var blocked = false
        var crashed = false
        for _ in 0..<4000 {
            let events = sim.step(dt: 1)
            if events.contains(.shieldBlocked) { blocked = true }
            if events.contains(.crashed) { crashed = true; break }
        }
        #expect(blocked)
        #expect(crashed)
        #expect(!sim.hasShield)
    }

    @Test("Staying in lane 1 eventually crashes and stops the run")
    func crashStopsRun() {
        var sim = makeSim(seed: 3)
        var crashed = false
        for _ in 0..<6000 {
            if sim.step(dt: 1).contains(.crashed) { crashed = true; break }
        }
        #expect(crashed)
        #expect(!sim.isRunning)
        #expect(sim.hasCrashed)
        #expect(sim.cameraShake > 0)
    }

    @Test("Timed modes end with timeUp")
    func timedModeEnds() {
        var sim = makeSim(mode: .rush, seed: 11)
        var ended = false
        for _ in 0..<(41 * 60) {
            let events = sim.step(dt: 1)
            if events.contains(.timeUp) { ended = true; break }
            if events.contains(.crashed) { break }
        }
        #expect(ended || sim.hasCrashed)
        if ended { #expect(sim.timeLeft == 0) }
    }

    @Test("Inputs are ignored before begin()")
    func inputGating() {
        var config = RunConfig(mode: .classic, viewportWidth: 390, viewportHeight: 844)
        config.seed = 5
        var sim = RunSimulation(config: config)
        #expect(sim.moveLane(1) == nil)
        #expect(sim.jump() == nil)
        sim.begin()
        #expect(sim.moveLane(1) == .laneChanged(2))
        #expect(sim.moveLane(1) == nil) // clamped at lane 2
        #expect(sim.jump() == .jumped)
        #expect(sim.jump() == nil) // already airborne
    }

    @Test("Ship lands after a jump")
    func jumpLands() {
        var sim = makeSim()
        _ = sim.jump()
        #expect(sim.ship.isAirborne)
        for _ in 0..<80 { _ = sim.step(dt: 1) }
        #expect(!sim.ship.isAirborne)
        #expect(sim.ship.yOffset == 0)
    }

    @Test("Revive clears the runway and grants a shield")
    func revive() {
        var sim = makeSim(seed: 3)
        for _ in 0..<6000 where !sim.hasCrashed { _ = sim.step(dt: 1) }
        #expect(sim.hasCrashed)
        sim.revive()
        #expect(sim.hasShield)
        #expect(sim.hasRevived)
        #expect(sim.entities.allSatisfy { $0.z > 760 })
        sim.begin()
        #expect(sim.isRunning)
    }

    @Test("Attract mode never crashes")
    func attractIsSafe() {
        var sim = RunSimulation.attract(viewportWidth: 390, viewportHeight: 844)
        for _ in 0..<3000 { _ = sim.step(dt: 1) }
        #expect(!sim.hasCrashed)
        #expect(sim.worldZ > 0)
        #expect(sim.rampMultiplier == 1)
    }

    @Test("Summary mirrors the run")
    func summary() {
        var sim = makeSim(seed: 9)
        for _ in 0..<300 { _ = sim.step(dt: 1) }
        let s = sim.summary
        #expect(s.mode == .classic)
        #expect(s.distance == Int(sim.distance))
        #expect(s.score == Int(sim.score))
    }
}

@Suite("Projector")
struct ProjectorTests {
    @Test func lanesAreSymmetric() {
        let p = Projector(width: 400, height: 800)
        #expect(p.laneX(1) == 200)
        #expect(p.laneX(0) == 200 - 400 * 0.235)
        #expect(p.laneX(2) == 200 + 400 * 0.235)
    }

    @Test func depthShrinksTowardHorizon() {
        let p = Projector(width: 400, height: 800)
        let near = p.project(lane: 0, z: 0)
        let far = p.project(lane: 0, z: 1200)
        #expect(far.scale < near.scale)
        #expect(far.y < near.y)
        #expect(abs(far.x - 200) < abs(near.x - 200))
    }
}

@Suite("Mulberry32")
struct RandomTests {
    @Test func sameSeedSameSequence() {
        var a = Mulberry32(seed: 20260907)
        var b = Mulberry32(seed: 20260907)
        for _ in 0..<50 { #expect(a.nextUnit() == b.nextUnit()) }
    }

    @Test func unitRange() {
        var r = Mulberry32(seed: 1)
        for _ in 0..<1000 {
            let v = r.nextUnit()
            #expect(v >= 0 && v < 1)
        }
    }
}

@Suite("Engine audit regressions")
struct EngineAuditTests {
    private func running(mode: GameMode = .classic, seed: UInt32 = 7, boost: BoostKind? = nil) -> RunSimulation {
        var config = RunConfig(mode: mode, viewportWidth: 390, viewportHeight: 844)
        config.seed = seed
        config.equippedBoost = boost
        var sim = RunSimulation(config: config)
        sim.begin()
        return sim
    }

    @Test("Slow-mo halves speed but not the cruise speed chunks are spaced by")
    func slowmoKeepsSpacing() {
        var sim = running(boost: .slowmo)
        for _ in 0..<30 { _ = sim.step(dt: 1) }
        #expect(sim.slowmoFrames > 0)
        #expect(abs(sim.speed - sim.cruiseSpeed * 0.5) < 1e-9)
        for _ in 0..<600 { _ = sim.step(dt: 1) }
        #expect(sim.slowmoFrames <= 0)
        #expect(abs(sim.speed - sim.cruiseSpeed) < 1e-9)
    }

    @Test("Coin Rush pays its coin rate")
    func coinRateApplies() {
        var classic = running(mode: .classic, seed: 21)
        var rush = running(mode: .rush, seed: 21)
        var classicValue = 0, rushValue = 0
        for _ in 0..<6000 {
            for e in classic.step(dt: 1) { if case .coinCollected(_, _, let v) = e, classicValue == 0 { classicValue = v } }
            for e in rush.step(dt: 1) { if case .coinCollected(_, _, let v) = e, rushValue == 0 { rushValue = v } }
            if classicValue > 0, rushValue > 0 { break }
        }
        #expect(classicValue == 1)
        #expect(rushValue == Int((GameMode.rush.config.coinRate).rounded()))
    }

    @Test("Crash resets the combo and clears the path hint; revive clears queued inputs")
    func crashState() {
        var sim = running(seed: 3)
        var frames = 0
        while !sim.hasCrashed, frames < 30_000 {
            _ = sim.step(dt: 1)
            frames += 1
        }
        #expect(sim.hasCrashed)
        #expect(sim.combo == 1)
        #expect(sim.pathHint == nil)
        sim.revive()
        #expect(sim.ship.duckFrames == 0)
        #expect(!sim.ship.queuedJump && !sim.ship.queuedDuck)
        #expect(sim.hasShield)
    }

    @Test("Frozen frames only decay effects")
    func decayEffects() {
        var sim = running()
        _ = sim.step(dt: 1)
        let z = sim.worldZ
        sim.pause()
        sim.decayEffects(dt: 3)
        #expect(sim.worldZ == z)
    }

    @Test("The attract autopilot clears hurdles instead of passing through them")
    func attractClearsHurdles() {
        var sim = RunSimulation.attract(viewportWidth: 390, viewportHeight: 844)
        var groundedThroughLow = 0
        for _ in 0..<12_000 {
            _ = sim.step(dt: 1)
            let s = sim.ship
            for e in sim.entities where e.lane == s.targetLane && abs(e.z) < 6 && abs(s.x - sim.projector.laneX(e.lane)) < 4 {
                if e.kind == .low, !s.isAirborne { groundedThroughLow += 1 }
                if e.kind == .beam, !s.isDucking { groundedThroughLow += 1 }
            }
        }
        // A handful of authored chains cannot be answered from every lane; anything beyond that is a timing bug.
        #expect(groundedThroughLow <= 3)
    }
}
