# Gunlord — Design

A portrait mobile crowd shooter. Your squad holds the bottom of a lane while
everything else comes down it toward you. You drag the squad left and right,
and where you stand decides what you shoot. Every second is a choice between
two things. You can shoot the horde that will kill you, or shoot the objects
that make you stronger.

The reference is the combat mode of an existing mobile strategy game. We take
the format and the mechanics. Name, art, characters and levels are our own.

## Scope

Decision: combat only. There is no base building, no resources, no heroes, and
nothing that carries over from one run to the next. A level is a self-contained
run. Meta-progression is left out on purpose until the combat proves fun alone.

**v1** is a single-player game made of the systems in this document.
**Later**, and deliberately out of v1: multiplayer, meta-progression, and
monetization. v1 keeps one extension point visible for them: the simulation
is deterministic in fixed ticks. Nothing beyond that is built for them yet.

## Camera and input

- Portrait screen. A tilted top-down camera looks up the lane toward the
  horizon, and the world moves toward the player.
- The only input is a horizontal drag that moves the squad left and right
  across the deck. The squad does not move forward or back.
- The player never aims or fires. Units fire on their own, aimed by their
  weapon (see Weapons).

## Lane objects

Everything that comes down the lane is one concept: a **lane object**. It has
a position, a speed, hit points and two effects.

| Field        | Meaning                                                          |
|--------------|------------------------------------------------------------------|
| `hp`         | Hits needed to destroy it. Shown as a number or a health bar.    |
| `on_destroy` | Payout when its `hp` reaches 0 (add units, apply a modifier…).   |
| `on_contact` | What happens when it reaches the squad (it fights, or it passes) |

Kinds are just data that fill in these fields:

| Kind           | `on_destroy`                      | `on_contact`               |
|----------------|-----------------------------------|----------------------------|
| Soldier        | nothing                           | melee: kills squad units   |
| Runner         | nothing                           | fast, low hp, melee        |
| Brute (boss)   | add units (bounty)                | heavy melee, keeps coming  |
| Manpower block | add N units with the base weapon  | passes, payout lost        |
| Multiplier     | multiply the base-weapon units ×N | passes, payout lost        |
| Trap block     | remove N units (or ÷N)            | passes harmlessly          |
| Weapon crate   | add N units carrying that weapon  | passes, payout lost        |
| Modifier gate  | apply a modifier (e.g. ATK +20%)  | passes, payout lost        |

Pickups pay out only when shot down. The squad never walks into one: the only
way to claim it is to shoot it, and anything that gets past you is lost.
Where pickups and enemies arrive is the stage's plan (see Endless map); on a
plan with lanes, low walls hold enemies to their lane until they near the
squad.

Traps punish standing in the wrong place, because `straight` weapons hit
whatever is in front of them. `auto` weapons never target traps. Otherwise
auto-aim would become a liability.

## Squad

- The squad is a mix of units. Each unit carries its own weapon, so the squad
  is a count of units per weapon (e.g. 30 bows, 8 guns, 2 cannons).
- Every pickup adds units or modifies a stat. Pickups convert existing units
  in one case only: when the squad is full, a weapon crate replaces rim units
  (the base weapon) one-for-one, so a full squad can still upgrade. Heavy weapons come in small numbers (+1 cannon), light ones in large
  numbers (+20 bows).
- Formation: the units form a tight blob that moves together. Melee contact
  kills units from the front rows first.
- The squad's rim stops at the edge of the deck, so a bigger squad moves less
  far sideways and covers the side lanes with its rim instead.
- The run is lost when the unit count reaches 0.
- The squad has a **maximum size** (the level sets it, 120 in Level 1). Payouts
  above the cap are lost and announced as "MAX". The cap keeps the late game
  readable and the crowd inside the bridge. A strong run fills it; a weak run
  doesn't.

## Weapons

A weapon is one data record. Each new weapon is a new record, not new code.

| Field       | Meaning                                                |
|-------------|--------------------------------------------------------|
| `damage`    | hp removed per hit                                     |
| `fire_rate` | shots per second, per unit                             |
| `aim`       | `straight` (fires up the lane) or `auto` (nearest target) |
| `spread`    | projectiles per shot and their angle spread            |
| `pierce`    | how many objects one projectile passes through         |
| `splash`    | blast radius on impact (0 = none)                      |

`aim` is fixed per weapon. A `straight` weapon hits whatever is directly ahead
of it, so the player's drag is what aims it. An `auto` weapon picks its own
target within range, so its value lies in covering what the drag cannot.

Starting set:

| Weapon  | Aim      | Character                                        |
|---------|----------|--------------------------------------------------|
| Bow     | straight | base unit, cheap, slow                           |
| Gun     | straight | faster, pierces 1                                |
| Gatling | auto     | very high rate, low damage, slight spread        |
| Cannon  | auto     | slow, heavy, splash; for brutes and big counters |

Modifiers apply to the whole squad or to one weapon type (`ATK +20%`,
`Gatling rate +50%`).

## Level structure

- A level is a scripted timeline of waves (target: about 20 waves over about
  90 seconds), with a brute every few waves and one final brute.
- The script also schedules the pickups. Their size and toughness grow
  further up the lane and later in the run: +1 blocks early and near, +99
  blocks late and tough.
- Themed lanes (bridge, towers…) change the setting, not the rules; the
  layout is the stage's plan (see Endless map).
- The campaign is five levels, each a spec turned into a timeline by one
  generator (`src/content/levels.gd`). Each level has its own time of day:

  | # | Level | Time | Character |
  |---|---|---|---|
  | 1 | Riverbridge | dawn | 12 waves, no runners or brutes; learn the lanes |
  | 2 | Old Crossing | noon | the full mix: 20 waves, a brute every 5 |
  | 3 | Runners' Gauntlet | afternoon | lighter horde, many runners, more traps |
  | 4 | Brute Bridge | dusk | a brute every 4 waves, cannons early |
  | 5 | Warlord's Gate | night | everything, faster, a 5,200 hp warlord |

  Calibration (`tests/simulate.gd`): on every level the sweeping bot wins and
  the careless bots lose. The sweeper keeps 87%, 72%, 55%, 35% and 21% of
  capacity on levels 1–5.
- Flow: the level menu, then the battle (with pause), then results with next,
  replay or retry, and levels. Winning a level unlocks the next. Progress and
  the best result per level stay on the device (`user://progress.cfg`).
- Win: kill the final brute. Lose: the unit count reaches 0. The clock sets the
  pace of the waves; it does not decide the result.
- Pacing rule: challenge grows linearly and rewards grow exponentially. Lane
  speed is the main difficulty setting. Current values: brute hp 300 + 250 per
  tier, a bounty of +30 units per brute kill, warlord hp 2000.
- Combat happens on screen. Weapon reach (18–40 m, each weapon its own: gatling close, crossbow middle, cannon far, gun farthest) is shorter than the visible
  lane (50 m), so enemies are fought mid-screen, not at the horizon.
- What the store shows is what you play. Marketing material shows only real
  gameplay.

## Endless map

Stages are composed, not authored. A stage is a set of **blocks**, and each
block has its own tunable numbers:

| Block | Numbers |
|---|---|
| Plan | the deck's layout, the wave formations it draws from, the pickup pattern, the opening squad |
| Horde | soldiers in the first wave, soldiers added per wave |
| Runners | first wave they appear, runners added per wave |
| Brutes | a brute every N waves, hp, hp added per brute |
| Boss | the warlord's hp and scale, and companions who march with it |
| Pacing | waves, seconds between waves, lane speed and its rise |
| Economy | block payout and its growth, block toughness and its growth, pickup gap, multiplier and trap frequency, the crates on offer |
| Theme | time of day |

**Map.** An endless line of nodes. Nodes 1–5 are the original levels,
rewritten in blocks. Every later node is forged from its own seed.

**Generate, then verify.** For each node the forge draws a character
(horde, rush, siege, elite or mixed). It then scales all the threats with one
intensity knob until the sweeping bot's margin (squad left over capacity) lands
on that node's target, and it checks that the idle bot loses. The target falls
from 60% at node 6 towards 15%. Every fifth node is a boss node, harder than
the curve; the node after it is a breather, easier.

**Plans.** A stage's layout is its own, not a fixed centre lane flanked by
pickups. Three plans (`Stages.PLANS`): *lanes*, a middle lane for enemies
between low walls and side lanes for pickups; *split*, one wall down the
middle and both lanes carrying both; *open*, no walls, with each wave on any
stretch of the deck and pickups among the enemies. Each wave takes a
formation drawn from the stage's character: block, line, wedge, columns or
stream. Pickups arrive alternating, in pairs, in bursts or scattered. The
opening squad is the stage's own too: ten crossbows, sixteen, six guns, or a
mix. These draws depend on the node alone, so every attempt plays the
verified stage. The five authored nodes use all three plans: lanes, split,
open, open, lanes.

**Protected opening.** Every forged stage opens fairly, whatever its
character: no brute before wave 5, and a weapon crate (gun, gatling or
cannon, the stage's draw) at about ten seconds.
Without it, a siege stage's early brute meets a squad of crossbows that cannot
hit it, and no intensity setting rescues the stage.

**Variants.** A stage with a cliff (won easily just below some intensity, lost
just above it) cannot be tuned to a target. The forge then tries the node's
next variant (a different draw from the same node), up to four, and keeps the
closest. The variant is stored with the intensity.

**Forged offline.** One verification runs a whole battle, so verifying
dozens of candidates on a phone would take minutes. `tools/forge_map.gd` forges
nodes ahead of time into `assets/map/forged.json`, committed as content: it is
expensive to regenerate, and it is the level data. Only the variant, intensity
and measured margin per node are stored; the stage itself is re-derived. Nodes past the forged range
are generated on the device with the plateau intensity; they are deliberately
unverified.

**Fixed per node, varied per attempt.** A node is the same stage for everyone
and on every retry, so a lost stage can be learned. Each attempt varies only
in ways that keep it fair: the whole stage may be mirrored left-to-right, and
the horde's formation shifts slightly.

**Drift check.** Forged margins are recorded. CI replays a sample of nodes, and
a change to the simulation that moves a margin out of tolerance fails the
build. The map is then re-forged on purpose, never silently.

**Next blocks.** A block only adds variety if it plays differently. Planned:
enemies that fire back (boss arms, archers), and tougher elite soldiers drawn
at a larger size.

## Technology

- **Godot 4**: open source, exports to Android and iOS.
- The simulation keeps units, lane objects and projectiles in flat arrays, and
  updates them in one tick that the game scene owns.
- Rendering draws each mesh kind in one batched draw call (`MultiMeshInstance3D`),
  so drawing a few hundred bodies costs a handful of draw calls.
- Hit checks run on a uniform grid laid over the lane. Projectiles only test
  objects in their own grid cell.
- Weapons, lane objects and levels are data resources, kept separate from the
  simulation code.

## Visuals

Bright, stylized low-poly fantasy-medieval look, with firearms in it. The
player's side is blue/teal and the enemy is crimson, so the sides read at a
glance even in a crowd of hundreds.

### Art sources

| Role | Source | Notes |
|---|---|---|
| Squad, crossbow | KayKit Rogue_Hooded + `crossbow_1handed` | recoloured to the player team |
| Squad, gun | KayKit Knight + in-house musket | |
| Squad, gatling | KayKit Barbarian + in-house gatling | |
| Squad, cannon | in-house wheeled cannon, no crew | static mesh with a recoil kick |
| Soldier | KayKit Knight | recoloured crimson |
| Runner | KayKit Rogue | crimson, smaller |
| Brute / Warlord | KayKit Barbarian, scaled ×2.6 / ×3.4 | the warlord has its own bake: bareheaded, an in-house gold crown, darker crimson |
| Bridge, walls, towers | Kenney Castle Kit + in-house deck | |
| Water, sky | in-house shaders | |
| Pickups | in-house glass panels (+N, ×N, −N) and stone pedestals carrying the weapon model | |
| Projectiles | KayKit arrow (as a bolt), in-house tracer and cannonball | |
| VFX | in-house particle pools | muzzle flash, hit sparks, blast, dust, payout burst |
| Font | Lilita One (SIL OFL) | |

All third-party files live under `assets/third_party/<pack>/`, together with
the pack's license and source URL. `CREDITS.md` lists them.

### Crowd animation

- Characters are drawn as vertex-animated MultiMeshes. One draw call covers
  each character kind, and the CPU does no per-unit skinning.
- **The baker** (`tools/bake_crowd.gd`, run headless) works per character:
  1. Load the glTF and keep only the body plus one weapon.
  2. For each clip, step through frames at 15 fps. At each frame, skin the mesh
     on the CPU (`bake_mesh_from_current_skeleton_pose`) and transform any
     bone-attached props.
  3. Write vertex positions (8 bits per axis within the character's bounds,
     a few millimetres of error at crowd scale) and normals into textures,
     one texture row per frame.
  4. Output the rest mesh, the textures and a clip table as resources.
- **The shader** reads the clip and phase for each instance from
  `INSTANCE_CUSTOM`, and the team colour and hit flash from `COLOR`. It blends
  between neighbouring frames.
- **Clips:**
  - squad: `shoot`, `strafe`, `cheer`
  - enemies: `run`, `attack`, `death`
  - bosses: `walk`, `attack`, `death`

### Presentation events

The simulation appends events to one feed, and the view drains it each frame.
Event kinds:
- `payout`
- `death`, carrying position and kind
- `fire`, carrying weapon and origin
- `hit`
- `contact`
- `max`

Corpses, muzzle flashes, sparks and screen shake all come from this feed. The
view never infers them from diffs of the simulation state.

### Stage and lighting

- Stone bridge over animated water, with castle walls and towers along the
  edges. The lane dividers are low stone walls, drawn where the stage's plan
  puts them, or none.
- One sun, with real shadows only on static set pieces. Crowds get one
  blob-shadow quad per unit, drawn as another MultiMesh.

### Feedback

- Damage flash and death fade on every unit.
- A boss health bar, and the boss's number above its head.
- Screen shake on brute contact and on cannon blasts.
- A short pause (hit-stop) when a boss dies.
- Payout callouts that pop and fade.

### Interface

- The HUD shows pause, the volume button, the clock and
  wave, the squad count with its capacity bar, the boss bar, and one badge
  per weapon (that unit's portrait and its count). The badges stand in a
  column at one edge, a little above the middle, clear of the steering
  thumb; the side (right by default, or left) is a setting.
- Pedestals show the unit's icon above their payout and hit points.
- The volume button is the one sound control outside Settings, in the battle
  bar, on the map and in the pause overlay: a speaker that, tapped, opens a
  vertical slider beneath it, whose bottom is silence (the speaker then shows
  muted). Tapping the speaker again, or anywhere else, closes it; while it is
  open, a drag is the slider's, never the map's.
- Settings are overall volume, music volume, effects volume, the badges'
  side, and reset progress (tap twice); kept on the device in
  `user://settings.cfg`, acting through the audio buses Master, Music and SFX.
- The map scrolls by dragging (finger or mouse) or the mouse wheel. A press
  that travels more than 14 px is a scroll, never a tap on the node beneath it.
- Escape, or Android's back button, pauses a battle.
- Music: "Determined Pursuit" (Emma_MA) loops through a battle; "Fantasy
  Orchestral Theme" (Joth) plays on the map. Tracks crossfade over 1.2 s, and
  the battle track fades out as the battle is decided, under its jingle.
- On the web, effects play as samples (handed to the browser: low latency),
  but music streams through Godot's mixer, decoded a little at a time.
  Sample playback decodes a whole track at once (about 105 MB for both
  tracks), which phones can fail to play. Streaming needs the game to keep
  the mixer fed, so the web audio buffer is 120 ms; only music pays that
  latency.
- Shared style (font, palette, buttons, chips, bars) lives in `src/view/ui.gd`.

### Own art and loading

- `tools/render_art.gd` renders the unit icons, the game icon (a crossbowman
  on a gold-rimmed badge) and the key art (a battle at dusk under the title)
  from the game's own scene and models. The outputs are committed, because
  rendering needs a display, which CI does not have.
- The key art is the engine's boot splash and the web loading page's
  background. The web page (`web/shell.html`) is Godot's shell restyled: the
  art fills a portrait screen, and on wider screens stands whole over a
  blurred copy, with a gold progress bar. The game icon is the favicon and
  the Android launcher icon.

### Versions and updates

- The version is the git tag; a build between tags describes itself from the
  last one (`0.2.0-3-gab12cd3`). CI writes that one string into the game
  (shown on the map and in settings), the Android package, the web page and
  `version.json`.
- GitHub Pages lets browsers cache every file for ten minutes. The loading
  page tags its requests for the game's own files with `?v=<version>`, so a
  new release is never answered from an old cache entry, and a cached page
  stays consistent with its own files.
- Each time the map appears (at most every two minutes), the web build
  fetches `version.json` past every cache. If a different version is
  published, the map offers "New version … tap to update", which reloads the
  page. It never interrupts a battle; local and native builds do not check.

### Budget

Peak scene: 120 squad + ~300 enemies + ~1,500 projectiles.

| Target | Measured (desktop CPU, `tests/frame_cost.gd`) | Status |
|---|---|---|
| Simulation tick under 8 ms on a mid-range phone | 0.44 ms median, 1.6 ms max | met with margin (estimated ×4 on a phone) |
| View buffer writes | 1.3 ms median, 4.3 ms max | met |
| Under 30 draw calls for crowds and projectiles | 7 characters + 3 projectile kinds + shadows + effects + pickups ≈ 16 | met |
| Under ~2.5k vertices per baked character | 3.7k–4.6k | **open**: about 1.4M vertices per frame at peak; needs a device test, and mesh simplification (index-only, VAT unchanged) if it is too heavy |
| Web download (gzip, as GitHub Pages serves it) | 8.4 MB data + 10.1 MB engine = 18.5 MB | met for now: positions are 8-bit within each character's bounds; the engine is the remaining bulk |

### Phases

| Phase | Delivers | Status |
|---|---|---|
| V0 | Squad maximum (gameplay) | done |
| V1 | Asset intake and CREDITS | done |
| V2 | The baker and the VAT shader; the soldier horde animated on screen; a performance check | done |
| V3 | All characters, team colours, the event feed, corpses | done |
| V4 | Stage: bridge, walls, towers, water, sky, lighting, blob shadows | done |
| V5 | Pickups and projectiles | done |
| V6 | VFX, screen shake, boss bar, HUD styling and font | done |
| V7 | Web build and review | done; review is with the user |

## Decision ledger

| # | Decision                                                  | Status |
|---|-----------------------------------------------------------|--------|
| 1 | Combat only; no meta systems                              | Active |
| 2 | Squad is a mix of units; each unit carries its weapon     | Active |
| 3 | Pickups add units or modifiers; they never convert units  | Refined by 19 |
| 4 | Aim mode (`straight` / `auto`) belongs to the weapon      | Active |
| 5 | Low-poly 3D, portrait, tilted top-down camera             | Active |
| 6 | Godot 4; flat-array simulation; batched rendering         | Active |
| 7 | Win: kill the final brute; the clock sets the pace only   | Active |
| 8 | Multiplier and trap blocks; `auto` aim never targets traps | Active |
| 9 | Runner enemy type                                          | Active |
| 10 | Linear challenge, exponential reward; speed is the dial  | Active |
| 11 | v1 single player; multiplayer and meta are later          | Active |
| 12 | Store and ad material shows real gameplay only            | Active |
| 13 | Squad has a level-set maximum; overflow is lost ("MAX")   | Active |
| 14 | Crowd animation via an in-house VAT baker inside Godot    | Active |
| 15 | Base art: KayKit (CC0) characters and Kenney (CC0) set pieces; signature weapons are ours | Active |
| 16 | The simulation emits presentation events; the view only reads them | Active |
| 17 | Crowds cast blob shadows, not real shadows               | Active |
| 18 | The base weapon is a crossbow (matches the art); id `bow` is renamed `crossbow` | Active |
| 19 | At capacity, weapon crates swap base units one-for-one   | Active |
| 20 | Five-level campaign from one generator; a time of day per level | Refined by 23 |
| 21 | Progress (unlocks, best result) is the only state kept between runs, on the device | Active |
| 22 | Sound: weapons and drums synthesized in code; impacts, UI and jingles from Kenney (CC0) | Refined by 32 |
| 23 | Endless map of composed stages; the five levels become nodes 1–5 | Active; refines 20 |
| 24 | Each node forged from a seed and verified by the bots against a margin target | Active |
| 25 | The map is forged offline and committed; nodes beyond it are generated unverified | Active |
| 26 | Fixed stage per node; per-attempt variation is only mirroring and formation jitter | Active |
| 27 | CI replays sampled nodes and fails on margin drift | Active |
| 28 | A second forge knob, the warlord's hp, tunes stages that one intensity cannot | Active |
| 29 | Icons over text: unit portraits rendered from our models; UI glyphs from Kenney (CC0) | Active |
| 30 | Settings (music, sound) and progress are the only state kept on the device | Active; refines 21 |
| 31 | Own art (icon, key art, loading page) rendered from the game itself and committed | Active |
| 32 | Music: two CC0 tracks from OpenGameArt, chosen by ear (battle loop, map theme), crossfaded; the synthesized drums are retired | Active |
| 33 | Volumes (overall, music, effects) as sliders; mute keeps the levels | Active; refines 30 |
| 34 | Weapon badges in a side column (right or left, a setting), clear of the steering thumb | Active |
| 35 | Web updates: version-tagged file requests, and a version.json check offering a reload on the map | Active |
| 36 | One volume button (a speaker opening a vertical slider; its bottom is mute) replaces mute plus inline slider | Active; refines 33 |
| 37 | The plan is a block: each stage draws its layout (lanes, split, open), wave formations, pickup pattern and opening squad; walls are stage data | Active; refines 23 |
