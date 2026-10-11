# Kingshot — Road to the Keep

A native iOS (SpriteKit + SwiftUI) recreation of the crowd-runner "gate" minigame from
Kingshot, Century Games' kingdom-strategy title. You drive a horde of orange soldiers up a
winding sandy road between grey cliffs, pick the better of two number gates, dodge red
ambush formations, let the heroes on their pedestals thin the enemy out, and arrive at the
keep with more soldiers than the boss.

<p align="center"><img src="docs/reference.webp" width="320" alt="Reference frame from the original"></p>

## Play it in a browser

A single-file HTML port of the same game lives in [`web/index.html`](web/index.html) and is
published at **https://claude.ai/artifact/DksLCaJZkScSABvMM6zN1C**. It runs on any phone or
desktop browser: tap to start, hold and drag (or use the arrow keys) to steer. It shares the
rules engine and the measured level generator with the Swift app, so a level plays the same
way in both, and it has no build step: open the file or drop it on any static host. The
browser build carries the current look: a tilted pseudo-3D camera, a cinematic opening in
which the king rides out of the gatehouse ahead of his troops, animated soldiers, and the
king leading the column during play. The SpriteKit scene still uses the first flat art pass.

## Running the iOS app

1. Open `Kingshot.xcodeproj` in Xcode 16 or newer (the project uses file-system-synchronised
   groups, so new files dropped into `Kingshot/` or `KingshotTests/` are picked up
   automatically).
2. Select the `Kingshot` scheme and an iPhone simulator or device, then **Run**.
3. For a device build, set your team under *Signing & Capabilities*.

Run the unit tests with **Product ▸ Test** (⌘U). They cover the rules engine, the level
generator and the track geometry, including a greedy pilot that proves the first 25
generated levels are winnable and that passive play is not enough.

## How to play

| Action | Result |
|---|---|
| Tap | Start the level |
| Hold and drag left / right | Steer the army across the road |
| Green gate (`+20`, `x2`) | Adds to or multiplies your headcount |
| Red gate (`-15`, `÷2`) | Shrinks your headcount |
| Red formation | One-for-one battle; win it by outnumbering them |
| Hero pedestal | Fires at any formation within range, before and during a fight |
| Boss at the keep | Finish with more soldiers than the boss to clear the level |

Coins are earned for every formation destroyed and every soldier that survives. Progress is
stored on-device.

## Project layout

```
Kingshot/
  App/        SwiftUI entry point, on-device progress store
  Core/       Pure-Swift rules engine (no UIKit): models, seeded RNG, track spline,
              level generator, GameSimulation
  Game/       SpriteKit presentation: scene, nodes, textures drawn with Core Graphics,
              HUD, terrain builder
  Assets.xcassets
KingshotTests/  XCTest suites for Core
web/            Browser port: one HTML file, canvas renderer, same rules and generator
docs/           Design notes reconstructed from the reference footage
```

The simulation is deliberately separated from rendering. `GameSimulation.update(dt:)`
returns a list of `SimEvent`s (gate passed, battle started, units traded, hero fired, won,
lost) and `GameScene` turns those into animation. Every level is generated deterministically
from its number, and the generator sizes each obstacle by replaying the level so far with a
greedy pilot, so difficulty is measured rather than guessed.

See [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md) for the breakdown of the original game's
mechanics and how each one is implemented here.
