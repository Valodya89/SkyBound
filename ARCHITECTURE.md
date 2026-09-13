# Architecture

Starlane is split into a **platform-neutral core** and a **thin native shell**. The core owns every rule of
the game and the economy; the shell owns rendering, input, persistence wiring and presentation.

```
┌──────────────────────────────── Starlane (app) ────────────────────────────────┐
│ SwiftUI views ──▶ GameCoordinator (intents) ──▶ PlayerStore / RunController     │
│      ▲                        │                       │            │           │
│      │ @Observable state      │ ads, purchases        │ profile    │ simulation │
│ UIRouter (sheets, toasts,     ▼                       ▼            ▼           │
│  rewards, ads)         Services (protocols)      ProfileStore   RunScene (SK)  │
└────────────────────────────────────────────────────────────────────────────────┘
                                   │ imports
┌──────────────────────────── StarlaneCore (SwiftPM) ────────────────────────────┐
│ Models · Engine (RunSimulation, Projector, RNG) · Economy systems · Persistence │
└────────────────────────────────────────────────────────────────────────────────┘
```

## StarlaneCore

Pure Swift, no UIKit, value types everywhere.

| Area | Types | Notes |
| --- | --- | --- |
| Models | `GameMode`, `Skin`, `BoostKind`, `UpgradeKind`, `Biome` (a space sector), `Chunk`, `Mission`, `Achievement`, `Duel`, `PlayerProfile` | Catalogs are static data; `PlayerProfile` is the single `Codable` save file. |
| Engine | `RunSimulation`, `Projector`, `RandomSource` (`Mulberry32`, `SystemRandomSource`) | `RunSimulation` is a `struct` stepped in 60 Hz frames. Speed starts at half the mode's base speed and eases to full over the first 30 s (`rampStartFraction`, `rampFrames`), then keeps climbing with distance. A separate difficulty curve (`difficulty(forDistance:)`) thins obstacles, widens chunk gaps and restricts patterns to gentle ones over the first 2,500 m; the first boss waits until at least 2,400 m.

Fairness rules baked into the simulation (each one was found with the bot in `PlayabilityTests`): leaving a lane is instant but you only collide with the lane you have physically reached (`laneEntryFraction`); any airborne frame clears a hurdle; a jump or slide requested while airborne is queued and fires on landing; on-track ▲/▼ hints are timed to the current speed (`hintDepth`); warm-up patterns never ask for more than one swipe at a time; authored patterns are stretched with speed (`spacingStretch`) so consecutive obstacle rows are always ~0.6–0.8 s apart regardless of how fast the world moves.

Pacing is tuned for relaxed, minutes-long runs: cruising speed is 62% of the prototype's (`cruiseScale`), the opening ramp takes two minutes, speed is capped at 1.6× base, difficulty unfolds over 9 km, and boss lasers move at world speed with a long telegraph. `PlayabilityTests` prints a survival report per reaction time; the enforced bar is that a 500 ms-reaction bot lasts ≥ 90 s in most seeds and ≥ 2 minutes on average. It returns `[RunEvent]` per step; callers turn events into sound, haptics and particles. Seeded runs are bit-for-bit reproducible (Daily Challenge). |
| Economy | `Progression`, `EnergySystem`, `GachaSystem`, `SeasonPass`, `DuelSystem`, `DailySystem`, `ShopSystem`, `UpgradeSystem`, `RunResolver` | Stateless enums operating on `inout PlayerProfile`. `RunResolver.bank` applies a `RunSummary` (bests, ghosts, XP, pass, missions, achievements, duels); a run that ends, is revived and ends again is banked as a delta against the summary already credited, so nothing is paid twice. |
| Persistence | `ProfileStore` protocol, `FileProfileStore` (atomic JSON in Application Support), `InMemoryProfileStore` | `PlayerProfile` decodes tolerantly (missing keys fall back to defaults) and a file that fails to decode is moved aside as `profile.corrupt-<time>.json` rather than overwritten. Swappable for CloudKit/Keychain later. |
| Support | `Clock`, `ManualClock`, `DaySeed`, `GameFormat` | Injected time keeps daily resets testable. |

## App layer

| Type | Responsibility |
| --- | --- |
| `AppEnvironment` | Composition root. `live()` wires real services; `preview()` wires silent/in-memory ones for previews and tests. |
| `PlayerStore` (`@Observable`) | Owns the profile, debounced saves, the 1-second economy tick (energy regen, launch offer), day rollover and offline energy catch-up. All mutations go through `update(_:)`. |
| `RunController` (`@Observable`) | Run lifecycle state machine: `attract → countdown → playing ⇄ paused → crashed → results`. Steps the simulation once per rendered frame, maps `RunEvent`s to audio/haptics, publishes a `HUDSnapshot`. The simulation itself is `@ObservationIgnored` so 60 Hz mutation never invalidates SwiftUI. |
| `UIRouter` (`@Observable`) | Presentation only: active tab, bottom sheet, reward pop-up queue, ad request, toast, share image. |
| `GameCoordinator` (`@Observable`) | Use-cases the views call: launch, revive, double coins, play again, shop/crate/pass/daily/duel actions. Orchestrates store + controller + router + ads + purchases. No SwiftUI imports. |
| Services | `AudioService` (`SynthAudioService` on `AVAudioSourceNode`, plus an adaptive four-layer music sequencer), `HapticsService`, `AdService` (`MockAdService`), `PurchaseService` (`SimulatedPurchaseService`). Each is a protocol with a production and a silent implementation. |

## Rendering

One `RunScene` (SpriteKit) sits behind every screen. In the hub it renders the autopilot "attract" run; during
play it renders the live run. Each frame it asks the controller to advance, then syncs nodes to the
simulation's state: `BackdropNode` (deep-space gradient crossfades, two nebula fields, stars, a ringed planet,
the launch corridor with scrolling dashes and gates, dust bands, boss telegraph), `EntityNode`s keyed by entity id
(fog-tinted sprites with soft shadows and jump/slide hints; obstacles are 24% of the viewport wide so they sit inside a 26.7%-wide lane, and objects fade out once they pass the ship), `ShipNode` (the rocket), `BossNode`, `GhostNode` (the safe-lane path hint) and an
`EffectsLayer` for particles, rings and floating text. All textures come from `TextureFactory` at launch,
so the app ships with no image assets.

The scene is created once (lazily, on first appearance of `GameSceneView`) and only a presented scene may report its size to the controller; a throwaway `SKScene` created during a SwiftUI re-initialisation also fires `didChangeSize` with its placeholder size, which used to overwrite the real viewport on wider phones.

The perspective is the prototype's single-vanishing-point projection (`Projector`), with every gameplay
threshold expressed relative to viewport width so behaviour is identical across devices.

## UI

SwiftUI over the scene. The deck (home) sits directly on the live attract run; every other destination is a
full-screen page (`GameScreen`) rendered in the same `ZStack`, so ads, reward moments and toasts can layer above
it. `UIRouter.SheetKind` still names eleven destinations, but several share a page and only differ by the
section they open on: crates/upgrades → Hangar (Rockets · Workshop · Archive crates), login/wheel/dailyChallenge
→ Daily, rank/duels → Ranks (Weekly · Duels · Badges).

The design system ("Flight deck", `Starlane/Design`) uses one warm signal colour (flare) for anything the player
can act on, one cold data colour (ice) for gems and information, and gold only as the coin mark and premium.
Type is Big Shoulders Display for every number and title and Instrument Sans for copy; both ship as variable
fonts in `Resources/Fonts` and are resolved through CoreText variation axes (`GameFont`). Motifs instead of
decoration: chamfered primary buttons with a hazard strip, tick rulers as dividers, segment bars for every
quantity, corner brackets on the selected thing, rarity as a corner. Iconography is SF Symbols at medium
weight plus drawn currency marks and a vector `RocketMark`.

## Testing

- `StarlaneCoreTests` (Swift Testing, runs with `swift test`): simulation determinism, collisions, shields,
  timers, revive, attract safety, projection, RNG, progression, energy, gacha pity and guarantees, season
  pass claims, duels, daily rollover/streaks, shop grants, run banking, persistence round-trip.
- `StarlaneTests`: `RunController` state machine (countdown → crash → results → revive, pause/quit),
  `GameCoordinator` flows (launch gating, boosts, pulls, login, reward queue, rewarded ads, purchases,
  settings, reset) and `PlayerStore` (ticks, offline regen, persistence, leaderboard).

## Extending

- **Real ads / IAP**: implement `AdService` / `PurchaseService` (StoreKit 2) and swap them in `AppEnvironment.live()`.
- **Cloud save**: implement `ProfileStore`.
- **New obstacle patterns**: add a `Chunk` to `ChunkLibrary`.
- **New biome**: add a `Biome` to `BiomeCatalog`; textures are generated automatically.
- **New mode**: add a case to `GameMode` with its `ModeConfig`.
