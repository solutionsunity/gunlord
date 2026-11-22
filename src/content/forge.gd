class_name Forge
extends RefCounted
## Composes a stage spec for a map node from the blocks: plan, horde, runners,
## brutes, boss, pacing, economy and theme. Deterministic in (node, variant, intensity):
## the node's seed (and variant, if the first draw would not tune) draws the
## stage's character and its numbers; intensity scales every threat. tools/forge_map.gd finds, per node, the intensity at which the
## sweeping bot's margin lands on target(node).
##
## Spec fields are documented in stages.gd.
##
## Every forged stage opens fairly, whatever its character: no brute before
## OPENING_WAVES, and a weapon crate at about ten seconds, so the squad can
## grow before the first heavy hitter arrives. Which crate, and the squad it
## grows from, are the stage's own.

const CHARACTERS := [&"horde", &"rush", &"siege", &"elite", &"mixed"]
## Threat weights per character: horde, runners, brutes, crate pool.
const WEIGHTS := {
	horde = [1.4, 0.6, 0.8, [&"gatling_crate", &"cannon_crate", &"gun_crate"]],
	rush = [0.7, 1.8, 0.7, [&"gatling_crate", &"gatling_crate", &"gun_crate", &"war_drum"]],
	siege = [0.8, 0.6, 1.6, [&"cannon_crate", &"cannon_crate", &"gun_crate", &"war_drum"]],
	elite = [1.0, 1.0, 1.2, [&"gun_crate", &"cannon_crate", &"war_drum", &"war_drum"]],
	mixed = [1.0, 1.0, 1.0, [&"gun_crate", &"gatling_crate", &"cannon_crate", &"war_drum"]],
}
## The wave shapes each character leans on (see Stages.FORMATIONS).
const SHAPES := {
	horde = [&"block", &"line", &"wedge"],
	rush = [&"stream", &"columns", &"line"],
	siege = [&"block", &"wedge"],
	elite = [&"wedge", &"columns", &"block"],
	mixed = [&"block", &"line", &"wedge", &"columns", &"stream"],
}
const PLANS := [&"lanes", &"lanes", &"open", &"open", &"split"]
const STARTS := [
	[[&"crossbow", 10]], [[&"crossbow", 10]], [[&"crossbow", 16]],
	[[&"gun", 6]], [[&"crossbow", 6], [&"gun", 3]],
]
const OPENING_CRATES := [&"gun_crate", &"gun_crate", &"gatling_crate", &"cannon_crate"]
const THEMES := [&"dawn", &"noon", &"afternoon", &"dusk", &"night"]
const FIRST := ["Ashen", "Iron", "Raven", "Thorn", "Grey", "Storm", "Hollow", "Red", "Wolf", "Frost",
		"Silent", "Broken", "High", "Old", "Black", "Golden", "Bitter", "Lantern", "Salt", "Ember"]
const SECOND := ["Ford", "Crossing", "Span", "Gate", "Causeway", "Arch", "Bridge", "Pass", "Weir",
		"Rampart", "Landing", "Narrows"]
const BOSS_EVERY := 5
const OPENING_WAVES := 5
const OPENING_AT := 10.0


## The sweeping bot's target margin at a node: from 60% at the first forged
## node falling towards 15%. Boss nodes sit below the curve, the node after a
## boss above it.
static func target(node: int) -> float:
	var t := 0.15 + 0.45 * exp(-(node - Stages.AUTHORED.size()) / 12.0)
	if is_boss(node):
		t -= 0.08
	elif node % BOSS_EVERY == 0:
		t += 0.06
	return clampf(t, 0.08, 0.7)


static func is_boss(node: int) -> bool:
	return node % BOSS_EVERY == BOSS_EVERY - 1


## `boss` multiplies the warlord's hp on top of intensity: the second, gentler
## knob the forge turns when one intensity cannot reach a node's target.
static func forge(node: int, intensity: float, variant := 0, boss := 1.0) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node * 7919 + variant * 15485863 + 104729)
	var character: StringName = CHARACTERS[rng.randi() % CHARACTERS.size()]
	var w: Array = WEIGHTS[character]
	var k := intensity
	var depth := float(node)
	var boss_node := is_boss(node)
	var waves := clampi(16 + int(depth / 4.0) + rng.randi_range(0, 3), 16, 28)
	var gap := rng.randf_range(3.8, 4.4)
	var spec := {
		name = "%s %s" % [FIRST[rng.randi() % FIRST.size()], SECOND[rng.randi() % SECOND.size()]],
		theme = THEMES[rng.randi() % THEMES.size()],
		character = character,
		plan = PLANS[rng.randi() % PLANS.size()],
		formations = SHAPES[character],
		pickups = Stages.PICKUPS[rng.randi() % Stages.PICKUPS.size()],
		start = STARTS[rng.randi() % STARTS.size()],
		waves = waves, gap = gap,
		horde = maxi(3, roundi((5.0 + rng.randf() * 3.0) * w[0] * k)),
		growth = maxi(1, roundi((2.5 + rng.randf() * 1.5) * w[0] * k)),
		runners_from = rng.randi_range(3, 5) if character == &"rush" else rng.randi_range(6, 10),
		runners = maxi(1, roundi(1.6 * w[1] * k)),
		brute_every = rng.randi_range(3, 4) if character == &"siege" else rng.randi_range(5, 7),
		brutes_from = OPENING_WAVES,
		brute_hp = (300.0 + 12.0 * depth) * w[2] * k,
		brute_step = (180.0 + 6.0 * depth) * w[2] * k,
		warlord_hp = (1600.0 + 90.0 * depth) * k * (1.3 if is_boss(node) else 1.0) * boss,
		boss_scale = 1.0 + minf(depth, 60.0) / 150.0 + (0.15 if boss_node else 0.0),
		companions = _companions(character, depth, boss_node),
		capacity = mini(120 + node * 4, 220),
		speed = rng.randf_range(2.9, 3.3), accel = 0.018 + 0.006 * k,
		pickup_gap = rng.randf_range(1.5, 1.8),
		reward = rng.randf_range(1.5, 1.9), reward_growth = rng.randf_range(1.024, 1.028),
		tough = rng.randf_range(3.5, 5.0), tough_growth = rng.randf_range(0.6, 0.85),
		multiplier_every = rng.randi_range(11, 17), trap_every = rng.randi_range(5, 9),
	}
	var opening: StringName = OPENING_CRATES[rng.randi() % OPENING_CRATES.size()]
	spec.crates = _crates(rng, opening, w[3], Stages.WAVE_START + (waves - 1) * gap)
	spec.surges = [rng.randf_range(0.3, 0.5)] if rng.randi() % 2 == 0 else [rng.randf_range(0.25, 0.4), rng.randf_range(0.6, 0.8)]
	return spec


## Who marches beside the warlord: [object id, count] pairs.
static func _companions(character: StringName, depth: float, boss: bool) -> Array:
	var out := []
	match character:
		&"horde":
			out.append([&"soldier", 10 + int(depth / 5.0)])
		&"rush":
			out.append([&"runner", 10 + int(depth / 5.0)])
		&"siege", &"elite":
			out.append([&"brute", 1])
	if boss:
		out.append([&"brute", 1 + int(depth / 20.0)])
	return out


## The opening crate, then crates spread through the stage, drawn from the character's pool.
static func _crates(rng: RandomNumberGenerator, opening: StringName, pool: Array, last_wave: float) -> Array:
	var n := rng.randi_range(4, 7)
	var out := [[OPENING_AT, opening]]
	for i in n:
		var t := lerpf(20.0, last_wave * 0.85, float(i) / (n - 1)) + rng.randf_range(-1.5, 1.5)
		out.append([t, pool[rng.randi() % pool.size()]])
	return out
