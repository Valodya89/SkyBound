import Foundation

/// Something on the track.
public struct Entity: Identifiable, Sendable, Hashable {
    public let id: Int
    public let kind: EntityKind
    public var lane: Int
    public var z: Double
    public var spin: Double
    public let boost: BoostKind?
    public let isBossLaser: Bool
    public var isDead = false
    public var hasPassed = false
}

public struct ShipState: Sendable, Hashable {
    public var x: Double
    public var targetLane = 1
    public var tilt: Double = 0
    /// Vertical offset in points; negative is up.
    public var yOffset: Double = 0
    public var verticalVelocity: Double = 0
    public var duckFrames: Double = 0
    public var isAirborne = false
    /// A jump or slide requested while airborne is executed the moment the ship lands.
    public var queuedJump = false
    public var queuedDuck = false
    public var isDucking: Bool { duckFrames > 0 }
    public var trail: [TrailPoint] = []

    public struct TrailPoint: Sendable, Hashable {
        public let x: Double
        public let y: Double
    }
}

public struct BossState: Sendable, Hashable {
    public let name: String
    public var hitPoints: Int
    public let maxHitPoints: Int
    public var cooldown: Double = 70
    public var telegraph: Double = 0
    public var telegraphLane = 1
    public var shotsFired = 0

    public var healthFraction: Double { Double(hitPoints) / Double(maxHitPoints) }
    public var isTelegraphing: Bool { telegraph > 0 }
}

public struct GhostPosition: Sendable, Hashable {
    public let lane: Int
    public let z: Double
}

/// "Go here": the safest lane to move into and the depth of the threat that makes it necessary.
public struct PathHint: Sendable, Hashable {
    public let lane: Int
    public let z: Double
    /// Entity id of the obstacle the hint is answering; the lane choice is locked until it passes.
    public let threatID: Int
}

/// Discrete things that happened during a `step`, for audio, haptics and particles.
public enum RunEvent: Sendable, Hashable {
    case coinCollected(lane: Int, z: Double, value: Int)
    case gemCollected(lane: Int, z: Double)
    case orbCollected(lane: Int, z: Double, boost: BoostKind)
    case nearMiss(points: Int)
    case shieldBlocked
    case crashed
    case timeUp
    case bossSpawned(name: String)
    case bossTelegraph(lane: Int)
    case bossFired(lane: Int)
    case bossDamaged(remaining: Int, max: Int)
    case bossDefeated(bonus: Int)
    case biomeChanged(index: Int)
    case jumped
    case ducked
    case laneChanged(Int)
    case comboChanged(Int)
    case lightning
}

/// Inputs that describe one run before it starts.
public struct RunConfig: Sendable, Hashable {
    public var mode: GameMode
    public var viewportWidth: Double
    public var viewportHeight: Double
    public var upgrades: [UpgradeKind: Int] = [:]
    public var isVIP = false
    public var equippedBoost: BoostKind? = nil
    public var startsWithShield = false
    public var ghost: [GhostSample] = []
    public var ghostEnabled = true
    /// When set, the course is generated deterministically (Daily Challenge).
    public var seed: UInt32? = nil

    public init(mode: GameMode, viewportWidth: Double, viewportHeight: Double) {
        self.mode = mode
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
    }
}

/// The complete, deterministic gameplay model for one run. No rendering, no timers, no I/O.
///
/// Time is measured in 60 Hz "frames" (`dt == 1` means one sixtieth of a second) to match the tuned
/// constants; callers convert wall-clock seconds with `RunSimulation.frames(forSeconds:)`.
public struct RunSimulation: Sendable {
    public static let jumpVelocity: Double = -11.2
    public static let gravity: Double = 0.62
    public static let duckFrames: Double = 34
    public static let maxFrameStep: Double = 3
    /// Runs start at this fraction of the mode's base speed…
    public static let rampStartFraction: Double = 0.35
    /// …and reach full base speed after this many frames (2 min). Distance-based acceleration is applied on top.
    public static let rampFrames: Double = 120 * 60
    /// Fraction of the ramp restored after a revive so the player gets a moment to settle.
    public static let reviveRampFraction: Double = 0.5
    /// Track distance before the first obstacle chunk is emitted.
    public static let openingGap: Double = 600
    /// Extra speed gained per metre travelled (the prototype used 0.00095).
    public static let accelerationPerMetre: Double = 0.00022
    /// Speed never exceeds this multiple of the mode's base speed, so late runs stay readable.
    public static let maxSpeedMultiplier: Double = 1.6
    /// Metres over which obstacle density and chunk spacing climb from "warm-up" to the mode's real values.
    public static let difficultyRampMetres: Double = 9000
    /// Below this difficulty only gentle chunk patterns are used.
    public static let warmUpDifficulty: Double = 0.3
    /// The first boss never appears before this many metres, whatever the mode's interval.
    public static let firstBossMinimumMetres: Double = 3500
    /// Boss lasers travel at this multiple of world speed (the prototype used 1.55).
    public static let laserSpeedMultiplier: Double = 1.0
    /// Frames the target lane glows before a laser is fired.
    public static let bossTelegraphFrames: Double = 84
    /// Boss shot cadence: starts at this cooldown and never drops below the floor.
    public static let bossCooldownStart: Double = 150
    public static let bossCooldownFloor: Double = 96

    /// 0…1 difficulty for a given distance.
    public static func difficulty(forDistance metres: Double) -> Double {
        min(max(metres / difficultyRampMetres, 0), 1)
    }

    /// Multiplier on the chance an obstacle is kept: 35% at the start, 85% once difficulty is full.
    public static func obstacleKeepScale(_ difficulty: Double) -> Double { 0.30 + 0.55 * difficulty }

    /// Multiplier on the empty track between chunks: 1.3× at the start, 1× once difficulty is full.
    public static func gapScale(_ difficulty: Double) -> Double { 1 + 0.3 * (1 - difficulty) }

    /// The tightest spacing between obstacle rows in the authored patterns (track units).
    public static let tightestAuthoredRowGap: Double = 190
    /// Frames a player gets between consecutive obstacle rows: 90 (1.5 s) at the start, 66 (1.1 s) at full difficulty.
    public static func framesBetweenRows(_ difficulty: Double) -> Double { 90 - 24 * difficulty }

    /// Stretch applied to pattern depths so the *time* between rows stays playable at any speed.
    public static func spacingStretch(speed: Double, difficulty: Double) -> Double {
        let perFrame = speed * 2.6
        return max(1, perFrame * framesBetweenRows(difficulty) / tightestAuthoredRowGap)
    }

    /// Patterns that only ever ask for a single swipe at a time; used while warming up.
    public static let warmUpChunkNames: Set<String> = ["breather", "coinsnake", "orbdrop"]
    /// The ship must be within this fraction of the viewport width from a lane's centre to collide with it.
    /// Leaving a lane is instant (the moment you swipe); arriving is judged by where the ship really is.
    public static let laneEntryFraction: Double = 0.10
    /// Frames the on-track ▲/▼ hint is shown before an obstacle reaches the ship (~1.3 s).
    public static let hintLeadFrames: Double = 80

    // MARK: Configuration
    public let config: RunConfig
    public private(set) var projector: Projector
    private var rng: any RandomSource
    private var nextEntityID = 0

    // MARK: Run stats
    public private(set) var score: Double = 0
    public private(set) var distance: Double = 0
    public private(set) var coins = 0
    public private(set) var gems = 0
    public private(set) var combo = 1
    public private(set) var bestCombo = 1
    public private(set) var streak = 0
    public private(set) var timeLeft: Double = 0
    public private(set) var nearMisses = 0
    public private(set) var bossesDefeated = 0
    public private(set) var zonesReached = 1

    // MARK: Buffs
    public private(set) var hasShield = false
    public private(set) var magnetFrames: Double = 0
    public private(set) var slowmoFrames: Double = 0
    public private(set) var doubleCoins = false
    public private(set) var hasRevived = false
    public private(set) var hasDoubledPayout = false

    // MARK: World
    public private(set) var isRunning = false
    public private(set) var isAttract = false
    public private(set) var hasCrashed = false
    public private(set) var entities: [Entity] = []
    public private(set) var ship: ShipState
    public private(set) var boss: BossState? = nil
    public private(set) var ghostPosition: GhostPosition? = nil
    /// Safe-lane suggestion when the current lane is blocked ahead (nil when no lane change is needed).
    public private(set) var pathHint: PathHint? = nil
    private var hintThreatID: Int? = nil
    private var hintLane: Int? = nil
    public private(set) var biomeIndex = 0
    public private(set) var worldZ: Double = 0
    public private(set) var cameraX: Double = 0
    public private(set) var windX: Double = 0
    public private(set) var strobe: Double = 0
    public private(set) var fogPulse: Double = 0
    public private(set) var cameraShake: Double = 0
    public private(set) var flash: Double = 0
    public private(set) var speed: Double = 0
    public private(set) var recording: [GhostSample] = []
    /// 0…1 progress of the opening speed ramp.
    public private(set) var rampProgress: Double = 0

    private var spawnCursor: Double = 0
    private var bossNextDistance: Double = 1500
    private var gustTimer: Double = 0
    private var gustDirection: Double = 1
    private var recordTimer: Double = 0
    private var autopilotTimer: Double = 0

    public var biome: Biome { BiomeCatalog.biome(forZone: biomeIndex) }
    public var mode: ModeConfig { config.mode.config }

    // MARK: - Lifecycle

    public init(config: RunConfig) {
        self.config = config
        projector = Projector(width: config.viewportWidth, height: config.viewportHeight)
        if let seed = config.seed {
            rng = Mulberry32(seed: seed)
        } else {
            rng = SystemRandomSource()
        }
        ship = ShipState(x: projector.laneX(1))
        reset()
    }

    /// Creates a simulation used purely as the hub backdrop: an autopilot flies forever.
    public static func attract(viewportWidth: Double, viewportHeight: Double) -> RunSimulation {
        var sim = RunSimulation(config: RunConfig(mode: .classic, viewportWidth: viewportWidth, viewportHeight: viewportHeight))
        sim.isAttract = true
        sim.spawnCursor = 0
        sim.rampProgress = 1
        return sim
    }

    public static func frames(forSeconds seconds: Double) -> Double {
        min(max(seconds * 60, 0), maxFrameStep)
    }

    private mutating func reset() {
        entities = []
        boss = nil
        ghostPosition = nil
        pathHint = nil
        hintThreatID = nil
        hintLane = nil
        ship = ShipState(x: projector.laneX(1))
        spawnCursor = Self.openingGap
        rampProgress = 0
        worldZ = 0
        cameraShake = 0
        flash = 0
        windX = 0
        strobe = 0
        gustTimer = 0
        fogPulse = 0
        hasCrashed = false

        let headStart = config.equippedBoost == .headStart
        score = headStart ? 800 : 0
        distance = headStart ? 800 : 0
        coins = 0
        gems = 0
        combo = 1
        bestCombo = 1
        streak = 0
        timeLeft = mode.timeLimit
        nearMisses = 0
        bossesDefeated = 0
        zonesReached = 1
        hasShield = config.startsWithShield
        magnetFrames = 0
        slowmoFrames = 0
        doubleCoins = false
        hasRevived = false
        hasDoubledPayout = false
        isRunning = false
        recording = []
        recordTimer = 0
        bossNextDistance = max(mode.bossInterval, Self.firstBossMinimumMetres)
        speed = baseSpeed * Self.rampStartFraction
        biomeIndex = Int(distance / 1000)

        switch config.equippedBoost {
        case .magnet: magnetFrames = (8 + Double(upgradeLevel(.magnetField)) * 1.5) * 60
        case .slowmo: slowmoFrames = 8 * 60
        case .doubleCoin: doubleCoins = true
        case .shield: hasShield = true
        case .headStart, nil: break
        }
    }

    /// Called when the viewport changes; keeps the ship on its lane.
    public mutating func resize(width: Double, height: Double) {
        let lane = ship.targetLane
        projector = Projector(width: width, height: height)
        ship.x = projector.laneX(lane)
    }

    /// Releases the ship after the countdown.
    public mutating func begin() {
        isRunning = true
    }

    public mutating func pause() {
        isRunning = false
    }

    /// Continues after a crash with a fresh shield and a cleared runway.
    public mutating func revive() {
        hasRevived = true
        hasShield = true
        hasCrashed = false
        rampProgress = min(rampProgress, Self.reviveRampFraction)
        entities.removeAll { $0.z <= 760 }
        if var b = boss {
            b.cooldown = max(b.cooldown, 90)
            boss = b
        }
        cameraShake = 0
        flash = 0
    }

    public mutating func markPayoutDoubled() {
        hasDoubledPayout = true
        coins *= 2
    }

    public func upgradeLevel(_ kind: UpgradeKind) -> Int { config.upgrades[kind] ?? 0 }

    /// Global cruising-speed scale. The prototype ran at 1.0; 0.7 keeps runs relaxed and minutes long.
    public static let cruiseScale: Double = 0.62

    /// The mode's cruising speed before ramp and distance scaling.
    public var baseSpeed: Double { 6.2 * Self.cruiseScale * mode.speed }

    /// Current 0…1 difficulty from distance travelled.
    public var difficulty: Double { Self.difficulty(forDistance: distance) }

    /// Current speed multiplier from the opening ramp: eases in so the first seconds feel calm.
    public var rampMultiplier: Double {
        let t = min(max(rampProgress, 0), 1)
        let eased = t * t * (3 - 2 * t) // smoothstep
        return Self.rampStartFraction + (1 - Self.rampStartFraction) * eased
    }

    public var summary: RunSummary {
        RunSummary(mode: config.mode, score: Int(score), distance: Int(distance), coins: coins, gems: gems,
                   bestCombo: bestCombo, nearMisses: nearMisses, bossesDefeated: bossesDefeated,
                   zonesReached: zonesReached, endedByTimer: mode.isTimed && timeLeft <= 0 && !hasCrashed,
                   ghost: Array(recording.prefix(4000)))
    }

    // MARK: - Input

    public mutating func moveLane(_ direction: Int) -> RunEvent? {
        guard isRunning else { return nil }
        let next = min(max(ship.targetLane + direction, 0), 2)
        guard next != ship.targetLane else { return nil }
        ship.targetLane = next
        return .laneChanged(next)
    }

    public mutating func jump() -> RunEvent? {
        guard isRunning else { return nil }
        if ship.isAirborne {
            ship.queuedJump = true
            ship.queuedDuck = false
            return nil
        }
        ship.verticalVelocity = Self.jumpVelocity
        ship.isAirborne = true
        ship.duckFrames = 0
        return .jumped
    }

    public mutating func duck() -> RunEvent? {
        guard isRunning else { return nil }
        if ship.isAirborne {
            ship.queuedDuck = true
            ship.queuedJump = false
            return nil
        }
        ship.duckFrames = Self.duckFrames
        return .ducked
    }

    /// How far ahead (track units) the path hint looks for a blocked lane: ~1.5 s of travel.
    public var pathHintLookahead: Double { max(520, speed * 2.6 * 90) }

    /// Computes `pathHint`. The lane choice is made once per threat so the marker never flickers between
    /// lanes while the obstacle approaches; it disappears as soon as the ship is heading for the safe lane.
    private mutating func updatePathHint() {
        guard config.ghostEnabled, isRunning else {
            pathHint = nil
            hintThreatID = nil
            hintLane = nil
            return
        }
        let lane = ship.targetLane
        let look = pathHintLookahead
        let blocking = entities
            .filter { ($0.kind == .wall || $0.kind == .laser) && $0.lane == lane && $0.z > -10 && $0.z < look }
            .min { $0.z < $1.z }
        guard let threat = blocking else {
            pathHint = nil
            hintThreatID = nil
            hintLane = nil
            return
        }
        if hintThreatID != threat.id {
            hintThreatID = threat.id
            hintLane = safestLane(from: lane, lookahead: look)
        }
        if let target = hintLane, target != lane {
            pathHint = PathHint(lane: target, z: max(threat.z - 30, 20), threatID: threat.id)
        } else {
            pathHint = nil
        }
    }

    /// Lane with the least danger ahead; nil when the current lane is already the safest (or all are blocked).
    public func safestLane(from lane: Int, lookahead: Double) -> Int? {
        var danger = [0.0, 0.0, 0.0]
        for e in entities where e.kind.isObstacle && e.z > -10 && e.z < lookahead {
            let weight = (e.kind == .wall || e.kind == .laser) ? 1.0 : 0.3
            danger[e.lane] += weight * (1 + (lookahead - e.z) / lookahead)
        }
        for l in 0..<3 { danger[l] += Double(abs(l - lane)) * 0.05 }
        guard let best = danger.indices.min(by: { danger[$0] < danger[$1] }), best != lane else { return nil }
        // Only suggest a lane that is actually free of walls/lasers.
        let blocked = entities.contains { ($0.kind == .wall || $0.kind == .laser) && $0.lane == best && $0.z > -10 && $0.z < lookahead }
        return blocked ? nil : best
    }

    /// Depth at which ▲/▼ hints should appear for the current speed.
    public var hintDepth: Double { max(520, speed * 2.6 * Self.hintLeadFrames) }

    // MARK: - Stepping

    /// Advances the world by `dt` frames and returns everything that happened.
    public mutating func step(dt rawDT: Double) -> [RunEvent] {
        let dt = min(max(rawDT, 0), Self.maxFrameStep)
        if isAttract { return attractStep(dt: dt) }
        var events: [RunEvent] = []

        let slow: Double = slowmoFrames > 0 ? 0.5 : 1
        if slowmoFrames > 0 { slowmoFrames -= dt }
        if magnetFrames > 0 { magnetFrames -= dt }
        if ship.duckFrames > 0 { ship.duckFrames -= dt }
        stepHazards(dt: dt, events: &events)

        if isRunning {
            rampProgress = min(1, rampProgress + dt / Self.rampFrames)
            let unclamped = baseSpeed * rampMultiplier + distance * Self.accelerationPerMetre * mode.speed
            speed = min(unclamped, baseSpeed * Self.maxSpeedMultiplier) * slow
            let mv = speed * dt * 2.6
            worldZ += mv
            let gain = mv * 0.16 * (1 + Double(upgradeLevel(.scoreCore)) * 0.08)
            distance += mv * 0.16
            score += gain

            if mode.isTimed {
                timeLeft -= dt / 60
                if timeLeft <= 0 {
                    timeLeft = 0
                    isRunning = false
                    events.append(.timeUp)
                    return events
                }
            }

            let zone = Int(distance / 1000)
            if zone != biomeIndex, zone < 99 {
                biomeIndex = zone
                zonesReached = max(zonesReached, zone + 1)
                events.append(.biomeChanged(index: zone))
            }

            if mode.hasBosses, boss == nil, distance >= bossNextDistance {
                spawnBoss(events: &events)
            }
            if boss != nil {
                stepBoss(dt: dt, events: &events)
            } else {
                spawnCursor -= mv
                if spawnCursor <= 0 { emitChunk() }
            }

            recordTimer += dt
            if recordTimer > 6 {
                recordTimer = 0
                recording.append(GhostSample(distance: Int(distance.rounded()), lane: ship.targetLane))
            }
            updatePathHint()
        }

        stepShip(dt: dt)

        let laserSpeed = speed * Self.laserSpeedMultiplier
        let magnetReach = 640 + Double(upgradeLevel(.magnetField)) * 60
        for i in entities.indices {
            let isLaser = entities[i].kind == .laser
            entities[i].z -= (isLaser ? laserSpeed : speed) * dt * 2.6
            entities[i].spin += dt * 0.13
            if entities[i].kind.isPickup, magnetFrames > 0, entities[i].z < magnetReach, entities[i].z > -30 {
                entities[i].lane = ship.targetLane
            }
        }

        if isRunning { collide(events: &events) }

        // Near misses & pass-through bookkeeping
        for i in entities.indices where !entities[i].hasPassed && !entities[i].isDead {
            guard entities[i].z < 0, entities[i].kind.isObstacle else { continue }
            entities[i].hasPassed = true
            if entities[i].kind == .laser, boss != nil {
                damageBoss(events: &events)
            }
            if isRunning, abs(ship.x - projector.laneX(entities[i].lane)) < projector.width * 0.20 {
                let pts = 25 + upgradeLevel(.grazer) * 12
                score += Double(pts)
                nearMisses += 1
                events.append(.nearMiss(points: pts))
            }
        }
        entities.removeAll { $0.isDead || $0.z <= -110 }

        if cameraShake > 0 { cameraShake = max(0, cameraShake - 0.028 * dt) }
        if flash > 0 { flash = max(0, flash - 0.05 * dt) }
        return events
    }

    private mutating func stepShip(dt: Double) {
        if ship.isAirborne || ship.verticalVelocity != 0 {
            ship.verticalVelocity += Self.gravity * dt
            ship.yOffset += ship.verticalVelocity * dt
            if ship.yOffset >= 0 {
                ship.yOffset = 0
                ship.verticalVelocity = 0
                ship.isAirborne = false
                if ship.queuedJump {
                    ship.queuedJump = false
                    ship.verticalVelocity = Self.jumpVelocity
                    ship.isAirborne = true
                } else if ship.queuedDuck {
                    ship.queuedDuck = false
                    ship.duckFrames = Self.duckFrames
                }
            }
        }
        let tx = projector.laneX(ship.targetLane) + windX
        ship.x = lerp(ship.x, tx, 1 - pow(0.001, dt / 60))
        let targetTilt = min(max((tx - ship.x) / projector.laneSpacing * -0.42, -0.42), 0.42)
        ship.tilt = lerp(ship.tilt, targetTilt, 0.18 * dt)
        cameraX = lerp(cameraX, ship.x - projector.width / 2, 0.1 * dt)
        ship.trail.insert(ShipState.TrailPoint(x: ship.x, y: ship.yOffset), at: 0)
        if ship.trail.count > 9 { ship.trail.removeLast() }
    }

    private mutating func stepHazards(dt: Double, events: inout [RunEvent]) {
        switch biome.hazard {
        case .storm:
            windX = sin(worldZ / 220) * projector.width * 0.022
            if rng.chance(0.006 * dt) {
                strobe = 1
                events.append(.lightning)
            }
        case .gust:
            gustTimer -= dt
            if gustTimer <= 0 {
                gustTimer = rng.next(in: 150...300)
                gustDirection = rng.chance(0.5) ? -1 : 1
            }
            let target = gustDirection * projector.width * 0.028 * min(max(gustTimer / 60, 0), 1)
            windX = lerp(windX, target, 0.05 * dt)
        case .fog:
            windX = lerp(windX, 0, 0.08 * dt)
            fogPulse += 0.9 * dt
        case .none:
            windX = lerp(windX, 0, 0.08 * dt)
        }
        if strobe > 0 { strobe = max(0, strobe - 0.06 * dt) }
    }

    // MARK: - Spawning

    private mutating func makeEntity(_ kind: EntityKind, lane: Int, z: Double, boost: BoostKind? = nil, bossLaser: Bool = false) -> Entity {
        nextEntityID += 1
        return Entity(id: nextEntityID, kind: kind, lane: lane, z: z, spin: rng.next(in: 0...6), boost: boost, isBossLaser: bossLaser)
    }

    private mutating func emitChunk() {
        let difficulty = self.difficulty
        var pool = ChunkLibrary.pool(forDistance: distance)
        if difficulty < Self.warmUpDifficulty {
            let gentle = pool.filter { Self.warmUpChunkNames.contains($0.name) }
            if !gentle.isEmpty { pool = gentle }
        }
        let chunk = pool[rng.nextIndex(count: pool.count)]
        let density = mode.density
        let keepChance = (min(max(density, 0.2), 1.9) * 0.85 + 0.15) * Self.obstacleKeepScale(difficulty)
        // Patterns are authored for a fixed cruising speed; stretch them so rows arrive at a human pace.
        let stretch = Self.spacingStretch(speed: max(speed, baseSpeed * Self.rampStartFraction), difficulty: difficulty)
        for item in chunk.items {
            if config.mode == .rush {
                if (item.kind == .wall || item.kind == .beam), rng.chance(0.62) { continue }
                if item.kind == .low, rng.chance(0.5) { continue }
            }
            if item.kind.isObstacle, rng.nextUnit() > keepChance { continue }
            let boost: BoostKind? = item.kind == .orb ? BoostKind.orbKinds[rng.nextIndex(count: BoostKind.orbKinds.count)] : nil
            entities.append(makeEntity(item.kind, lane: item.lane, z: Projector.maxDepth + item.z * stretch, boost: boost))
        }
        spawnCursor = chunk.length * stretch * (1 / min(max(density, 0.5), 1.8)) * Self.gapScale(difficulty)
    }

    // MARK: - Boss

    private mutating func spawnBoss(events: inout [RunEvent]) {
        let def = BossDefinition.boss(forDistance: distance)
        boss = BossState(name: def.name, hitPoints: def.hitPoints, maxHitPoints: def.hitPoints, cooldown: Self.bossCooldownStart)
        cameraShake = 0.6
        events.append(.bossSpawned(name: def.name))
    }

    private mutating func stepBoss(dt: Double, events: inout [RunEvent]) {
        guard var b = boss else { return }
        if b.telegraph > 0 {
            b.telegraph -= dt
            if b.telegraph <= 0 {
                entities.append(makeEntity(.laser, lane: b.telegraphLane, z: Projector.maxDepth * 0.72, bossLaser: true))
                events.append(.bossFired(lane: b.telegraphLane))
            }
        } else {
            b.cooldown -= dt
            if b.cooldown <= 0 {
                b.telegraph = Self.bossTelegraphFrames
                b.telegraphLane = rng.nextIndex(count: 3)
                b.cooldown = max(Self.bossCooldownFloor, Self.bossCooldownStart - Double(b.shotsFired) * 4)
                b.shotsFired += 1
                events.append(.bossTelegraph(lane: b.telegraphLane))
            }
        }
        boss = b
    }

    private mutating func damageBoss(events: inout [RunEvent]) {
        guard var b = boss else { return }
        b.hitPoints -= 1
        if b.hitPoints <= 0 {
            let bonus = 200 + zonesReached * 60
            coins += bonus
            bossesDefeated += 1
            boss = nil
            cameraShake = 1
            flash = 0.8
            bossNextDistance = distance + mode.bossInterval
            events.append(.bossDefeated(bonus: bonus))
        } else {
            boss = b
            events.append(.bossDamaged(remaining: b.hitPoints, max: b.maxHitPoints))
        }
    }

    // MARK: - Collisions

    private mutating func collide(events: inout [RunEvent]) {
        for i in entities.indices {
            let e = entities[i]
            if e.isDead || e.hasPassed { continue }
            if e.z > 34 || e.z < -46 { continue }
            let sameLane = e.lane == ship.targetLane && abs(ship.x - projector.laneX(e.lane)) < projector.width * Self.laneEntryFraction

            if e.kind.isObstacle {
                guard sameLane else { continue }
                // Any airborne frame clears a hurdle, so a last-instant jump is never punished.
                if e.kind == .low, ship.isAirborne { continue }
                if e.kind == .beam, ship.isDucking, !ship.isAirborne { continue }
                if hasShield {
                    hasShield = false
                    entities[i].isDead = true
                    cameraShake = 0.5
                    events.append(.shieldBlocked)
                    if e.kind == .laser, boss != nil { damageBoss(events: &events) }
                    continue
                }
                entities[i].isDead = true
                crash(events: &events)
                return
            }

            guard sameLane || magnetFrames > 0 else { continue }
            entities[i].isDead = true
            let z = max(e.z, 0)
            switch e.kind {
            case .coin:
                streak += 1
                let newCombo = min(max(1 + streak / 8, 1), 8)
                if newCombo != combo {
                    combo = newCombo
                    events.append(.comboChanged(combo))
                }
                bestCombo = max(bestCombo, combo)
                let multiplier = Double(combo) * (1 + Double(upgradeLevel(.coinValue)) * 0.15) * (doubleCoins ? 2 : 1) * (config.isVIP ? 2 : 1)
                let value = Int(multiplier.rounded())
                coins += value
                events.append(.coinCollected(lane: e.lane, z: z, value: value))
            case .gem:
                gems += 1
                events.append(.gemCollected(lane: e.lane, z: z))
            case .orb:
                let boost = e.boost ?? .shield
                switch boost {
                case .shield: hasShield = true
                case .magnet: magnetFrames = (8 + Double(upgradeLevel(.magnetField)) * 1.5) * 60
                case .slowmo: slowmoFrames = 8 * 60
                default: break
                }
                events.append(.orbCollected(lane: e.lane, z: z, boost: boost))
            default:
                break
            }
        }
    }

    private mutating func crash(events: inout [RunEvent]) {
        isRunning = false
        hasCrashed = true
        streak = 0
        cameraShake = 1
        flash = 1
        events.append(.crashed)
    }

    // MARK: - Attract autopilot

    private mutating func attractStep(dt: Double) -> [RunEvent] {
        autopilotTimer -= dt
        let mv = 4.2 * dt * 2.6
        worldZ += mv
        spawnCursor -= mv
        if spawnCursor <= 0 {
            let chunk = ChunkLibrary.all[rng.nextIndex(count: ChunkLibrary.all.count)]
            for item in chunk.items {
                entities.append(makeEntity(item.kind, lane: item.lane, z: Projector.maxDepth + item.z,
                                           boost: item.kind == .orb ? .shield : nil))
            }
            spawnCursor = chunk.length
        }
        for i in entities.indices {
            entities[i].z -= 4.2 * dt * 2.6
            entities[i].spin += dt * 0.13
        }

        var need: EntityKind? = nil
        for e in entities where e.lane == ship.targetLane && e.z <= 430 && e.z >= 40 {
            switch e.kind {
            case .low: need = .low
            case .beam: need = .beam
            case .wall: need = .wall
            default: break
            }
        }
        if need == .low, !ship.isAirborne {
            ship.verticalVelocity = Self.jumpVelocity
            ship.isAirborne = true
        }
        if need == .beam, !ship.isAirborne, ship.duckFrames <= 0 {
            ship.duckFrames = Self.duckFrames
        }
        if need == .wall, autopilotTimer <= 0 {
            autopilotTimer = 22
            var danger: [Double] = [0, 0, 0]
            for e in entities where e.z < 720 && e.z > 40 {
                if e.kind == .wall { danger[e.lane] += 2 }
                if e.kind == .coin || e.kind == .gem { danger[e.lane] -= 0.5 }
            }
            var best = 0
            for i in 1..<3 where danger[i] < danger[best] { best = i }
            ship.targetLane = best
        }
        // Pickups vanish under the autopilot so the hub backdrop never looks broken.
        for i in entities.indices where entities[i].kind.isPickup && entities[i].lane == ship.targetLane && abs(entities[i].z) < 20 {
            entities[i].isDead = true
        }

        if ship.duckFrames > 0 { ship.duckFrames -= dt }
        if ship.isAirborne || ship.verticalVelocity != 0 {
            ship.verticalVelocity += Self.gravity * dt
            ship.yOffset += ship.verticalVelocity * dt
            if ship.yOffset >= 0 {
                ship.yOffset = 0
                ship.verticalVelocity = 0
                ship.isAirborne = false
            }
        }
        entities.removeAll { $0.isDead || $0.z <= -110 }
        let tx = projector.laneX(ship.targetLane)
        ship.x = lerp(ship.x, tx, 1 - pow(0.002, dt / 60))
        ship.tilt = lerp(ship.tilt, min(max((tx - ship.x) / projector.laneSpacing * -0.42, -0.42), 0.42), 0.16 * dt)
        ship.trail.insert(ShipState.TrailPoint(x: ship.x, y: ship.yOffset), at: 0)
        if ship.trail.count > 9 { ship.trail.removeLast() }
        return []
    }
}

@inline(__always)
func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double { a + (b - a) * t }
