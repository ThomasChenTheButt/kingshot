# Kingshot opening — design reconstruction

## What the game actually is (corrected)

The first pass read the reference frame as a crowd-runner through number gates, the format
Kingshot's ads are known for. That was wrong. Re-reading the frame together with the trade
coverage of the game's onboarding gives a consistent picture:

| In the frame | What it is |
|---|---|
| Dense blob of orange round creatures on the road, pink sparks at the edges | The enemy horde, in melee with the player's knights (first read as coins; the enlarged crop shows eyes and legs) |
| Green squares with a coin icon and 20 / 25 | Build-site price signs painted on the ground |
| Hero in blue with a golden helmet on a stone pillar | A built hero tower |
| Column of chunky red knights with boxy great-helms, a silver one among them | The player's own knights following the king, who is a silver plate knight on foot |
| Sandy road between grey cliffs, lumber hut, trees | The map the raiders come up at night |

Sources (page bodies are blocked from this environment; these are from search summaries):

* Gamigion's funnel analysis says Kingshot's early loop borrows Thronefall's
  joystick-controlled wave defense, placed inside a medieval 4X, and that "3 waves of
  enemies hit within the first 8 minutes".
* The GameDiscover newsletter says Kingshot "starts with real-time Thronefall-clone gameplay"
  as the hook that onboards players into the 4X game.
* PocketGamer's hands-on describes a small king on horseback riding across terrain and
  placing towers to hold off enemies.
* Thronefall community threads say the Kingshot footage reuses Thronefall's camera, hero
  and music.
* Thronefall's own rules (Wikipedia, fan wikis): gold is the only resource, buildings go on
  fixed spots, each level alternates a day build phase and a night defense phase, the
  monarch fights alongside barracks troops, and only buildings that survive the night pay
  out the next morning.

## Rules as implemented (browser build)

* **Movement.** Virtual joystick or keys. The king (a plate knight on foot, drawn at 1.35× a soldier) can walk the road and the plaza in front
  of the keep; the cliffs are walls.
* **Gold.** A count, drawn as a trail of up to sixty coins following the king's breadcrumb
  path. Loose coins are picked up within about one unit and are pulled in from two.
* **Building.** Within 1.6 units of an unbuilt site, one coin leaves the trail every 0.07 s
  and flies into the sign; the sign fills from the bottom and counts down. Sites: hero tower
  (range 7.5, a shot every 0.65 s for 2), palisade (40 hp, blocks the road, repaired every
  morning), farm (+6 gold a morning), barracks (five soldiers, replenished every morning).
* **Day.** A countdown (60 s on level 1, 45 s after) or the "Call the night" button.
* **Night.** Raiders (3 hp, speed 2.1) and brutes (9 hp, slower, hit harder) spawn about 34
  units down the road and walk up it. A standing palisade just ahead stops them; otherwise a
  soldier or the king within one unit; otherwise, at the gate, the keep (30 hp). Towers,
  soldiers and the king's sword (3 damage, reach 1.45) kill them; each drops a coin.
* **Morning.** Income (10 + 2 per level, plus farms) pours out of the gate as loose coins;
  walls and the king heal; barracks refill.
* **Levels.** Wave count 3 to 5, wave size 4 + 2w + 2(level - 1), more sites unlock at
  levels 2, 3, 4 and 5, starting gold and income rise with the level.

## Opening cinematic

The camera starts a little way up the raiders' road and eases to the keep under a
"LEVEL n / HOLD THE KEEP" banner with a horn fanfare; the king then rides out of the gate
with his starting gold streaming behind him; "DAY 1" and the first hint follow. A tap skips
to the ride-out.

---

## Earlier (superseded) reconstruction: the gate runner

The material below documents the first build, which is kept as `web/road-runner.html` and as
the SpriteKit app.


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

## What the research turned up

Direct page fetches are blocked from the build environment, so this comes from search
summaries of the following: PocketGamer's hands-on, the Gamigion and AdMapix ad teardowns,
the fakeadgames.com archive, and the Thronefall community threads.

* Kingshot's ads are low-poly 3D Thronefall-style scenes wrapped around door-runner "math
  gate" mechanics (`+50`, `x3`), with a small king on horseback riding across the terrain
  as the recurring opening hook; other hooks are a cinematic king posing a question and a
  battlefield pan.
* The in-game tutorial is tower-defence-led; the closest real mode to the ad is the Mystic
  Trials.
* Community posts say the ad footage borrows Thronefall's camera, hero and music.

## Presentation choices (browser version)

* **Tilted pseudo-3D camera.** World y is foreshortened by 0.84, cliffs are drawn as a dark
  face at ground level with a lifted top ring (outer polygon minus road polygon, even-odd
  fill), trees and the keep are lifted the same way, and every actor stands on an ellipse
  shadow. Terrain polygons are culled to the visible sample range each frame.
* **Opening cinematic.** On "Tap to play" the camera starts at the keep and eases down the
  road over two seconds under a "LEVEL n" banner; the king then rides out of the wooden
  gatehouse behind the start with the soldiers streaming after him into formation; "GO!"
  hands over control. A tap skips to the ride-out.
* **King on horseback** leads the column during play, gallop-bobbing while the army moves.
* **Soldiers** are two-frame run cycles with squash and stretch, rotated to the road
  direction; enemies face back down the road and jitter when engaged.
* **Feedback.** Screen shake on contact, white clash sparks during trades, arcing arrows
  from heroes, coin bursts on kills and victory, a progress bar with the keep at its end,
  and a short synth palette (fanfare, GO sting, gate chimes, clash ticks).

## Presentation choices (iOS version)

* Sprites are drawn once with Core Graphics (`TextureFactory`), so the app ships with no
  bitmap assets other than the icon.
* The camera stays upright and looks 4.5 units ahead of the crowd, matching the fixed
  isometric-style framing of the reference, while the road winds underneath.
* Haptics: a medium impact for buffs and battles, a warning for traps, success / error for
  the level result.
