# Starlane

A native iOS port of the arcade prototype (originally *SkyBound*) — a fake-3D lane runner set in deep space, with a complete free-to-play
loop (energy, coins/gems, boosts, upgrades, crates, season pass, daily missions, duels, leaderboards and
simulated ads/purchases). Everything economic is simulated locally; no network, ad SDK or payment processor
is involved.

- **iOS 17+**, Swift 6 language mode, MainActor default isolation, Swift Testing.
- **SwiftUI** for every screen, **SpriteKit** for the world, **AVAudioEngine** synth for all audio (no assets).
- Deterministic gameplay core in a local Swift package so the whole game logic runs and tests on macOS too.

## Open in Xcode

```bash
open Starlane.xcodeproj
```

Select the `Starlane` scheme and any iPhone simulator, then Run. Signing is automatic; set your team in
*Signing & Capabilities* to run on a device.

The project file is generated from `project.yml` with [xcodegen](https://github.com/yonaskolb/XcodeGen).
It is committed, so nothing needs to be installed to open it. After adding files, regenerate with:

```bash
xcodegen generate
```

## Run the tests

```bash
xcodebuild -project Starlane.xcodeproj -scheme Starlane -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

or, for the platform-neutral core only (fast, no simulator):

```bash
cd Packages/StarlaneCore && swift test
```

## Controls

| Gesture | Action |
| --- | --- |
| Swipe left / right, or tap a side | Change lane |
| Swipe up | Climb over debris |
| Swipe down | Dive under laser gates |

## Layout

```
Starlane.xcodeproj          generated project (open this)
project.yml                 xcodegen spec
Packages/StarlaneCore/      platform-neutral game logic + tests
Starlane/                   the app
  App/                      entry point, composition root, observable stores, coordinator
  Design/                   "Flight deck" tokens, fonts and components (buttons, panels, marks, chrome)
  Features/                 one folder per screen (Hub/Deck, Run, Results, Shop, Hangar, Pass, Daily, Rank, …)
  Game/                     SpriteKit scene, nodes and procedural textures
  Services/                 audio synth, haptics, mock ads, simulated purchases
  Resources/                asset catalog (app icon, colours) and the two bundled OFL fonts
StarlaneTests/              app-layer tests (controller, coordinator, store)
Scripts/render-app-icon.swift  regenerates the app icon with CoreGraphics
```

See [ARCHITECTURE.md](ARCHITECTURE.md) for how the pieces fit together.
