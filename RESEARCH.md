# Gunlord — Research

Collected 2026-11-19. This is a snapshot: versions, prices and licenses change,
so check them again before relying on them. Claims are labelled **verified**
(the source was read) or **inferred**.

## 1. The genre

### Closest shipped games

| Game | Where | Closeness | Mechanics worth noting |
|---|---|---|---|
| Last War: Survival, "Frontline Breakthrough" | iOS/Android mode inside a 4X game | closest high-budget match | strafe only; ±N barriers; soldier barrels and weapon barrels (flamethrower, rockets); fast "dog" units; 40–48 stages; max 60 soldiers converted per stage |
| Real War (Not Fake) | iOS/Android | standalone version of the ad | on rails; shoot fields to grow count and firepower; negative fields; shoot weapons lying on the field to upgrade; boss each level; Endless and Adventure modes |
| Gatefire | web | very close | bridge; shooting a gate raises its value; ×2/×3 gates, a ÷2 gate; tire stacks hold upgrades, airstrikes, vehicles; bosses at set stages |
| Horde Breaker | web | **our side-lane mechanic** | fires up whichever lane it stands in; a prize behind a counter in one lane while the horde advances in the other |
| Zombie Bridge | web | close | blue gates add, red gates remove; blow up a span under a horde or brute; frozen mechs in the side lanes |
| Zombie Gates / Squad Gates / Squad Rush | small Google Play developers | close, cheap | +, ×, − gates; explosive barrels; a boss every few levels; up to about 1,500 soldiers (from listing snippets) |
| Mob Control (Voodoo) | iOS/Android | the same format turned sideways | aimed cannon fires units through multiplier gates; destroy the base; revenue about 85% ads |
| Count Masters | iOS/Android | ancestor, no shooting | add/multiply gates; crowds cancel out one-for-one |

Sources: [lastwartutorial](https://www.lastwartutorial.com/operation-falcon-frontline-breakthrough-wallkthrough-videos),
[buffbuff](https://buffbuff.com/blog/last-war-frontline-breakthrough-guide),
[Notebookcheck](https://www.notebookcheck.net/Someone-actually-made-one-of-those-fake-ad-games-and-it-s-pretty-good.1188256.0.html),
[ArcadeWhale](https://arcadewhale.com/blog/games-that-are-actually-like-their-ads/),
[PocketGamer.biz](https://www.pocketgamer.biz/comment-and-opinion/79857/mob-control-hybridising-a-hypercasual-hit/),
[MAF](https://maf.ad/en/blog/mob-control-analysis-hybrid-casual/).

### Open space (inferred)

No shipped game found combines all three of these: a **mixed squad where each
weapon fires straight or auto-aims**, **timed waves**, and **side lanes as the
main pickup system**. The shared loop is commodity; that combination is what
sets us apart.

### Shared vocabulary (verified across the games above)

- **Squad:** the unit count is also your hit points. The squad moves sideways only and fires on its own.
- **Gates:** +N, −N, ×N, ÷N. Some you walk through, some you shoot to raise their value.
- **Counter pickups:** barrels or tire stacks with a hit counter; shoot it to zero to claim units, a weapon or a special.
- **Weapons:** pistol → SMG → rifle → minigun, plus flamethrower and rockets.
- **Enemies:** a melee horde, fast "dog" units, and a brute or boss at the end of the stage.

### What players reward and punish

- **Rewarded:** delivering what the ad shows ("exactly as advertised"), the satisfying moment when the crowd multiplies, and ads the player chooses to watch for a reward.
- **Punished:**
  - Ads that misrepresent the game. The UK advertising regulator (ASA) has banned some ([DigitalToday](https://www.digitaltoday.co.kr/en/view/124411/mobile-game-hit-formula-under-fire-as-ads-differ-from-gameplay)).
  - Paywalls and daily play caps ([Orcz](https://orcz.com/last-war-survival-game-review-is-it-actually-fun-or-just-aggressively-monetized/)).
  - Too many ads (low confidence).
  - Repetitiveness. Gate runners must differ through their mechanics and theme because the core loop is shared ([Supersonic](https://supersonic.com/learn/blog/how-to-design-a-hit-gate-runner-the-basics-and-best-practices/)).

### Pacing

- **Challenge grows linearly, rewards grow exponentially.** Start very easy, treat the points where players quit as places to ease off, and use speed as the simplest difficulty dial ([Supersonic](https://supersonic.com/learn/blog/how-to-design-a-hit-gate-runner-the-basics-and-best-practices/)).
- **Reference numbers** from an open Unity clone ([tanishdt/endless-crowd-runner](https://github.com/tanishdt/endless-crowd-runner)):
  - speed 11 → 22 m/s, +0.5 every 100 m;
  - enemy groups start at 8, +3 every 100 m;
  - a boss about every 60 s, HP 250 + 160 per tier;
  - each boss kill gives +30 squad.
- **Negative gates hurt more as the squad grows**, and pickups compete with the horde for the same fire. That competition is the main source of tension (inferred).

### Clones to study

- **Unity:**
  - [tanishdt/endless-crowd-runner](https://github.com/tanishdt/endless-crowd-runner): most complete, all balance values in one config. No license, so read it but don't copy from it.
  - [dendritaDev/Hyper-Casual-CrowdRunner-Unity](https://github.com/dendritaDev/Hyper-Casual-CrowdRunner-Unity)
  - [hardartcore Crowd Runner Framework](https://hardartcore.itch.io/crowd-runner-framework-math-gates-crowd-battles-finish-stairs)
- **Three.js:** [crowd-forge](https://github.com/build-flutterauth/crowd-forge).
- **Godot:** no clone of this format exists.

## 2. Technology

**Decision confirmed:** flat-array simulation, uniform grid, one MultiMesh per
mesh kind. Animation is the only part that needed a decision.

1. **Engine:** Godot **4.7.x** stable (4.7.2, August 2026), Mobile renderer, with Compatibility as the low-end Android fallback. 4.8 is in beta ([4.7.1 notes](https://godotengine.org/article/maintenance-release-godot-4-7-1/), [renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)).
2. **Animation via vertex animation textures (VAT), not skinned meshes.**
   - About 300 rigged units already reach only 36 fps on a desktop integrated GPU ([forum](https://forum.godotengine.org/t/performance-of-crowds-of-animated-rigged-characters-in-3d/130409)).
   - Pick: [antzGames VAT plugin](https://github.com/antzGames/Godot_Vertex_Animation_Textures_Plugin) (MIT, Godot 4.5+). Its benchmark: 5,000 instances on the Mobile renderer at 216 fps on desktop. It leaves `color.a` free, which we can use for hit flash.
   - Bake with Blender **4.5 LTS**; Blender 5.x breaks OpenVAT.
   - Alternative that bakes inside Godot, with no Blender step: [shadecoredev AnimatedMultimeshInstance3D](https://github.com/shadecoredev/AnimatedMultimeshInstance3D).
3. **MultiMesh rules** (verified, [docs](https://docs.godotengine.org/en/stable/classes/class_multimesh.html)):
   - Each instance is 20 floats in the buffer: 12 transform, 4 color, 4 custom data.
   - Allocate once at peak size and control what's drawn with `visible_instance_count`.
   - Set `custom_aabb` to the lane bounds.
   - Push each kind's buffer once per tick with `RenderingServer.multimesh_set_buffer` (inferred to be the fastest path).
   - In Compatibility, custom data drops to 16-bit precision.
4. **Language:** typed GDScript over packed arrays.
   - Survivors Kit runs 700 enemies in about 3 ms per frame in plain GDScript ([forum](https://forum.godotengine.org/t/survivors-kit-a-complete-survivors-like-template-for-godot-4-700-enemies-in-plain-gdscript-web-demo/146090)).
   - Benchmarks show calls into the engine and node overhead dominate cost, not the scripting language ([benchmark](https://github.com/jerryshell/godot-survivors-benchmark)).
   - Our estimate on a phone: 6–12 ms (inferred).
   - **Checkpoint:** profile on a mid-range Android phone in week 1. If the tick takes more than about 8 ms, port only the tick and the grid to a C++ GDExtension. Avoid C#, because iOS support for it is newer.
5. **Feedback effects:**
   - **Hit flash and death fade:** driven through per-instance data, so they cost no extra draw calls.
   - **Damage numbers:** one MultiMesh of camera-facing quads that each draw one digit from a texture atlas.
   - **Particles:** pooled particle emitters (GPUParticles3D), reused rather than created.
   - **Screen shake:** shake strength (trauma) × noise, plus a 30–60 ms pause on big hits ([forum](https://forum.godotengine.org/t/tutorial-hit-stop-and-screen-shake-in-godot-4-autoload-trauma-camera-mit/145240)).
   - **References:** [BlastBullets2D](https://github.com/nikoladevelops/godot-blast-bullets-2d) and [PerfBullets](https://github.com/Moonzel/Godot-PerfBullets) for projectile pooling, [Minos Damage Numbers](https://github.com/Minoqi/minos-damage-numbers-for-godot).

## 3. Assets

### Minimal set for the first playable (about $0–45)

| Need | Pick | License |
|---|---|---|
| Squad + horde characters | [KayKit Adventurers](https://kaylousberg.itch.io/kaykit-adventurers) (+ Extra $7.95 for the Barbarian), [KayKit Skeletons](https://kaylousberg.itch.io/kaykit-skeletons) | CC0 ✔ |
| Animations | [KayKit Character Animations](https://kaylousberg.itch.io/kaykit-character-animations): 161 animations on Rig_Medium and Rig_Large | CC0 ✔ |
| Brute | Barbarian (Adventurers Extra) or Golem (Skeletons Extra) on Rig_Large | CC0 ✔ |
| Lane / castle | [Kenney Castle Kit](https://www.kenney.nl/assets/castle-kit), [Pirate Kit](https://kenney.nl/assets/pirate-kit) (barrels, crates) | CC0 ✔ |
| Water, bridge deck | made in-house (a shader and a simple mesh) | ours |
| Bow / crossbow | KayKit accessories | CC0 ✔ |
| Gatling, cannon | **made in-house**; no verified CC0 model exists, and these are the signature visuals | ours |
| Visual effects | [Binbun](https://binbun3d.itch.io/explosion-fx) Explosion, Muzzle Flash, Hit FX (Godot 4) | CC0 (✔ Explosion; others from snippets) |
| UI | [Kenney UI Pack](https://kenney.nl/assets/ui-pack) + a font under the SIL Open Font License (Lilita One / Luckiest Guy) | CC0 ✔ / OFL |
| Audio | Kenney Impact, Interface, Sci-fi and Music Jingles packs; [Sonniss GDC](https://sonniss.com/gdc-bundle-license/) for heavy weapons | CC0 ✔ / Sonniss ✔ |

### License watch-outs

1. **Quaternius** moved from CC0 to its own "Quaternius Asset License v1.0" on its site, while its itch pages still say CC0. Record the license text and date when downloading.
2. **Mixamo** forbids redistributing the raw files, which conflicts with an open repo. Avoid it.
3. **Synty** is licensed per seat, bans AI use, and has the most recognizable asset-flip look. Avoid it.
4. **Sonniss** sounds can't be redistributed as sound effects. Keep them out of a public repo.
5. **Asset-flip look:** recolor the atlas to our own palette, use one shared toon shader with rim lighting, and make the hero weapons in-house.
6. **Rigs:** KayKit's Rig_Medium/Rig_Large and Quaternius's animation library are different rigs. Stay inside one family.
7. Poly counts are **unverified**. Measure them on import; the target is 1–2k vertices per soldier for VAT.
