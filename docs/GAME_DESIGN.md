# Kingshot road minigame — design reconstruction

This document records what was inferred from the reference frame (`reference.webp`) and
from how Kingshot's advertised "road" minigame plays, and maps each observation onto the
implementation in this repository.

## What the reference frame shows

| Observation | Interpretation | Implementation |
|---|---|---|
| Sandy, winding road between tall grey cliff walls on a green field | A single track the army follows; the player only controls lateral position | `TrackGeometry` builds a Catmull-Rom spline that always climbs the map; `TerrainBuilder` strokes it as shadow, cliff, cliff highlight, sand |
| Green squares on the road labelled `25` and `20` with a coin icon, one per half of the road | Number gates, placed in pairs so the player chooses a lane | `GateSpec` with `.left` / `.right` lanes; `LevelGenerator` emits pairs at the same `s` |
| A hero in blue with a golden helmet standing on a stone pedestal beside the road | Stationary ally that attacks enemies as the army passes | `HeroSpec` + `HeroNode`; the simulation fires at the nearest live formation in range every `fireInterval` seconds |
| A column of red soldiers at the left edge, engaged with the orange horde | Enemy formations that fight the crowd when touched | `EnemyGroupSpec` laid out in ranks by `EnemyGroupNode`; `GameSimulation` resolves the battle as batched one-for-one trades |
| A dense blob of orange units flowing along the road | The player's crowd; headcount is the score and the hit points | `CrowdNode` draws a phyllotaxis blob of up to 140 sprites with a headcount badge |
| Wooden lumber camp in the corner, trees on the grass | Set dressing | `TerrainBuilder.addStartCamp` and `addTrees` |
| Grey "fortress" where the road ends (implied by the genre) | Boss encounter that decides the level | Full-width `EnemyGroupSpec` with `isBoss`; defeating it wins, equal numbers lose |

## Rules engine

Everything that decides the outcome lives in `Kingshot/Core` and has no UIKit or SpriteKit
dependency, so it can be unit-tested on any Apple platform.

* **Coordinates** – `s` is distance along the road, `x` is lateral position in `-1...1`.
  The crowd advances at `forwardSpeed` units per second and slides towards `targetX` at
  `lateralSpeed`. Its lateral half-width grows with the square root of the headcount, so a
  big army physically cannot hug the wall.
* **Gates** – triggered when the crowd centre crosses the gate's `s`. Half-width gates only
  fire when the centre is on their side, so the choice is binary and readable.
* **Battles** – when a live formation overlaps the crowd's lateral range within
  `engageDistance`, the crowd stops and both sides lose `max(1, min(a, b) / 12)` units every
  `tradeInterval`. The crowd wins with `a - b` survivors; equal numbers wipe both out, which
  counts as a loss.
* **Heroes** – active while the crowd is within `1.5 × range`. Each shot removes `damage`
  units from the closest formation inside `range`, including the one currently fighting.
* **Win / lose** – defeating the boss, or running off the end of the road, wins. Hitting zero
  soldiers at any point loses.

## Level generation

`LevelGenerator.makeLevel(n)` is deterministic: the seed is derived from `n`, so the same
level always plays the same way. It walks the road dropping segments:

* **Gate pair** (42 %) – either two buffs of different value or a buff beside a trap.
  The first segment of every level is always two buffs so the mechanic teaches itself.
  Multiplier gates are only offered while doubling would stay under a per-level headcount
  cap, which keeps numbers readable instead of exploding into the thousands.
* **Formation** (30 %) – 25–50 % of the current headcount, either full width or in one lane
  so it can be dodged.
* **Hero ambush** (16 %) – a pedestal six units before a full-width formation. The formation
  is sized as "what the hero will shoot" plus 30–50 % of the current headcount, so the hero
  visibly matters but the player still has to finish the job.
* **Single buff gate** (12 %).

The important part is how "current headcount" is known. Rather than estimating it, the
generator replays the level built so far with `GreedyPilot` (always take the better gate,
otherwise run down the middle) after every segment and reads the real surviving count from
the simulation. Obstacles are sized from that measurement, a segment that turns out lethal
for the pilot is replaced with a recovery gate, and the boss is set to 60–85 % of what the
pilot brings to the keep. The consequences:

* every generated level is provably winnable by sensible play (the unit tests replay the
  first 25 levels with the pilot);
* a passive run that never steers fails most levels;
* dodging lane formations or picking a better gate than the pilot banks extra survivors,
  which is where the score comes from.

The starting army grows by two soldiers per level (10 → 60), road length grows by eight
units per level up to level 25, and hero damage grows by one every three levels.

## Presentation choices

* Sprites are drawn once with Core Graphics (`TextureFactory`), so the app ships with no
  bitmap assets other than the icon.
* The camera stays upright and looks 4.5 units ahead of the crowd, matching the fixed
  isometric-style framing of the reference, while the road winds underneath.
* Haptics: a medium impact for buffs and battles, a warning for traps, success / error for
  the level result.
