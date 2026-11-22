class_name Relics
extends RefCounted
## Relics: gear the squad keeps from stage to stage. Beating a boss node (every
## fifth) earns the next step of SCHEDULE: a new relic, or a level on one held.
## A node can only be reached by beating every boss before it, so the loadout
## at a node is fixed by the map itself: everyone arrives with the same, the
## forge verifies each stage with exactly it, and nothing needs storing.
##   blades   blades circling the squad, cutting the enemies they touch
##   drone    drones beside the squad, firing at the nearest enemy
##   shield   an arc ahead of the squad that takes the front line's blows

const SCHEDULE := [&"blades", &"drone", &"shield", &"blades", &"drone", &"shield", &"blades", &"drone", &"shield"]
const LABELS := {blades = "ORBITING BLADES", drone = "DRONES", shield = "SHIELD"}
const MAX_LEVEL := 3
const NUMERALS := ["", "I", "II", "III"]


## relic id -> level, for a battle at `node` (0-based).
static func at(node: int) -> Dictionary:
	var out := {}
	for step in mini(node / Forge.BOSS_EVERY, SCHEDULE.size()):
		var id: StringName = SCHEDULE[step]
		out[id] = mini(out.get(id, 0) + 1, MAX_LEVEL)
	return out


## What beating `node` earns: [relic id, its new level], or empty.
static func earned(node: int) -> Array:
	var before := at(node)
	var after := at(node + 1)
	for id in after:
		if after[id] != before.get(id, 0):
			return [id, after[id]]
	return []
