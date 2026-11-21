class_name Stages
extends RefCounted
## The endless map. Each node is a stage spec composed of blocks; one generator
## turns a spec into a spawn timeline. Nodes 1–5 are authored; every later node
## is forged (forge.gd) at the intensity recorded in assets/map/forged.json,
## and past the forged range at the plateau intensity, unverified.
##
## Spec fields, by block:
##   name, theme, character              title, time of day, what the stage leans on
##   pacing:  waves, gap                  wave count, seconds between waves
##            speed, accel                lane speed at start (m/s), added per second
##   horde:   horde, growth               soldiers in wave 1, soldiers added per wave
##   runners: runners_from, runners       first wave with runners, runners added per wave after it
##   brutes:  brute_every, brute_hp, brute_step   a brute every N waves, its hp, hp added per brute
##            brutes_from                 no brute before this wave
##   boss:    warlord_hp, boss_scale      the final boss's hp and size
##            companions                  [object id, count] marching beside it
##   economy: capacity                    the squad's maximum
##            pickup_gap                  seconds between side-lane pickups
##            reward, reward_growth       first block's payout, payout growth per second (exponential)
##            tough, tough_growth         first block's hp, hp added per second (linear)
##            multiplier_every, trap_every  every Nth pickup is ×1.5; every Nth a trap shielding a fat block
##            crates                      [seconds, crate id], in any order
## Challenge grows linearly (horde, toughness, speed); rewards exponentially.

const SIDE_X := 4.75
const WAVE_START := 2.0
const FORGED := "res://assets/map/forged.json"
const JITTER := 0.15                    ## metres a soldier may shift in formation between attempts

const AUTHORED := [
	{
		boss_scale = 1.0, companions = [], brutes_from = 1,
		name = "Riverbridge", theme = &"dawn",
		waves = 12, gap = 4.5, horde = 5, growth = 2,
		runners_from = 99, runners = 0,
		brute_every = 99, brute_hp = 0.0, brute_step = 0.0, warlord_hp = 500.0,
		capacity = 60, speed = 2.8, accel = 0.01,
		pickup_gap = 1.7, reward = 1.5, reward_growth = 1.03, tough = 3.0, tough_growth = 0.5,
		multiplier_every = 99, trap_every = 99,
		crates = [[12.0, &"gun_crate"], [30.0, &"gatling_crate"]],
	},
	{
		boss_scale = 1.0, companions = [], brutes_from = 1,
		name = "Old Crossing", theme = &"noon",
		waves = 20, gap = 4.2, horde = 8, growth = 4,
		runners_from = 7, runners = 2,
		brute_every = 5, brute_hp = 300.0, brute_step = 250.0, warlord_hp = 2000.0,
		capacity = 120, speed = 3.0, accel = 0.02,
		pickup_gap = 1.7, reward = 1.5, reward_growth = 1.025, tough = 4.0, tough_growth = 0.7,
		multiplier_every = 17, trap_every = 7,
		crates = [[10.0, &"gun_crate"], [24.0, &"gatling_crate"], [40.0, &"war_drum"], [46.0, &"cannon_crate"],
				[58.0, &"gatling_crate"], [66.0, &"war_drum"], [72.0, &"cannon_crate"]],
	},
	{
		boss_scale = 1.0, companions = [], brutes_from = 1,
		name = "Runners' Gauntlet", theme = &"afternoon",
		waves = 20, gap = 4.0, horde = 5, growth = 2,
		runners_from = 5, runners = 2,
		brute_every = 7, brute_hp = 400.0, brute_step = 250.0, warlord_hp = 2400.0,
		capacity = 130, speed = 3.1, accel = 0.022,
		pickup_gap = 1.6, reward = 1.7, reward_growth = 1.026, tough = 4.0, tough_growth = 0.7,
		multiplier_every = 13, trap_every = 7,
		crates = [[10.0, &"gatling_crate"], [20.0, &"gun_crate"], [34.0, &"gatling_crate"], [48.0, &"war_drum"],
				[56.0, &"cannon_crate"], [66.0, &"gatling_crate"]],
	},
	{
		boss_scale = 1.0, companions = [], brutes_from = 1,
		name = "Brute Bridge", theme = &"dusk",
		waves = 21, gap = 4.2, horde = 8, growth = 3,
		runners_from = 8, runners = 2,
		brute_every = 4, brute_hp = 300.0, brute_step = 220.0, warlord_hp = 3000.0,
		capacity = 140, speed = 3.0, accel = 0.022,
		pickup_gap = 1.6, reward = 1.8, reward_growth = 1.027, tough = 4.0, tough_growth = 0.75,
		multiplier_every = 15, trap_every = 9,
		crates = [[9.0, &"gun_crate"], [22.0, &"cannon_crate"], [32.0, &"cannon_crate"], [44.0, &"war_drum"],
				[54.0, &"gatling_crate"], [64.0, &"cannon_crate"], [74.0, &"war_drum"]],
	},
	{
		boss_scale = 1.0, companions = [], brutes_from = 1,
		name = "Warlord's Gate", theme = &"night",
		waves = 24, gap = 3.9, horde = 8, growth = 5,
		runners_from = 6, runners = 3,
		brute_every = 4, brute_hp = 380.0, brute_step = 300.0, warlord_hp = 5200.0,
		capacity = 160, speed = 3.3, accel = 0.024,
		pickup_gap = 1.5, reward = 1.8, reward_growth = 1.027, tough = 4.5, tough_growth = 0.8,
		multiplier_every = 11, trap_every = 7,
		crates = [[8.0, &"gun_crate"], [18.0, &"gatling_crate"], [28.0, &"cannon_crate"], [38.0, &"war_drum"],
				[48.0, &"gatling_crate"], [58.0, &"cannon_crate"], [68.0, &"war_drum"], [78.0, &"cannon_crate"]],
	},
]

static var _forged := {}                ## node -> {variant, intensity, boss, margin, target}; loaded once
static var _plateau := 1.0


## The spec of a node (0-based).
static func spec(node: int) -> Dictionary:
	if node < AUTHORED.size():
		return AUTHORED[node]
	_load_forged()
	var entry: Dictionary = _forged.get(node, {})
	return Forge.forge(node, entry.get("intensity", _plateau), int(entry.get("variant", 0)), entry.get("boss", 1.0))


static func is_forged(node: int) -> bool:
	_load_forged()
	return node < AUTHORED.size() or _forged.has(node)


## The battle for a node. `attempt` varies it fairly: odd-seeded attempts are
## mirrored left-to-right, and the horde's formation shifts by up to JITTER.
static func build(node: int, attempt := 0) -> Level:
	return build_spec(spec(node), node, attempt)


static func build_spec(s: Dictionary, node: int, attempt := 0) -> Level:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node * 31 + attempt * 1000003)
	var mirror := -1.0 if attempt > 0 and rng.randi() % 2 == 1 else 1.0
	var jitter := JITTER if attempt > 0 else 0.0
	var events: Array[Dictionary] = []
	_waves(s, events, rng, jitter)
	var last_wave: float = WAVE_START + (s.waves - 1) * s.gap
	_pickups(s, events, last_wave)
	for e in events:
		e.x *= mirror
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	var level := Level.new(events, s.waves, s.capacity)
	level.index = node
	level.name = s.name
	level.theme = s.theme
	level.duration = last_wave + 8.0
	level.speed = s.speed
	level.accel = s.accel
	return level


static func _waves(s: Dictionary, events: Array[Dictionary], rng: RandomNumberGenerator, jitter: float) -> void:
	var brutes := 0
	for i in s.waves:
		var t: float = WAVE_START + i * s.gap
		var soldiers: int = s.horde + s.growth * i
		for k in soldiers:
			var x := -2.55 + (k % 7) * 0.85 + rng.randf_range(-jitter, jitter)
			events.append({t = t, id = &"soldier", x = x, z = -(k / 7) * 0.85, wave = i + 1})
		if i + 1 >= s.runners_from:
			for k in (i + 2 - s.runners_from) * s.runners:
				events.append({t = t + 1.5, id = &"runner", x = -2.4 + (k % 7) * 0.8, z = -(k / 7) * 0.8})
		if i == s.waves - 1:
			_boss(s, events, t)
		elif (i + 1) % s.brute_every == 0 and i + 1 >= s.brutes_from:
			events.append({t = t, id = &"brute", x = 0.0, z = -7.0, hp = s.brute_hp + s.brute_step * brutes})
			brutes += 1


## The warlord, scaled by boss_scale in size, reach and hp, with its companions around it.
static func _boss(s: Dictionary, events: Array[Dictionary], t: float) -> void:
	var scale: float = s.boss_scale
	var def: ObjectDef = Content.objects()[&"warlord"].duplicate()
	def.size *= scale
	def.radius *= scale
	events.append({t = t, id = &"warlord", def = def, x = 0.0, z = -8.0, hp = s.warlord_hp * scale})
	for c in s.companions:
		for k in c[1]:
			var side := -1.0 if k % 2 == 0 else 1.0
			var x: float = side * (1.4 + (k / 2 % 3) * 0.6) if c[0] != &"brute" else side * 2.0
			events.append({t = t, id = c[0], x = x, z = -6.5 - (k / 6) * 0.9})


static func _pickups(s: Dictionary, events: Array[Dictionary], until: float) -> void:
	var crates: Array = s.crates.duplicate()
	crates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var j := 0
	var t := 0.5
	while t < until:
		var side := SIDE_X if j % 2 == 0 else -SIDE_X
		var value := roundf(s.reward * pow(s.reward_growth, t))
		var toughness: float = s.tough + t * s.tough_growth
		if not crates.is_empty() and t >= crates[0][0]:
			events.append({t = t, id = crates.pop_front()[1], x = side})
		elif j % s.multiplier_every == s.multiplier_every / 2:
			events.append({t = t, id = &"multiplier", x = side, hp = 40.0 + t * 1.5})
		elif j % s.trap_every == s.trap_every - 2:
			# Risk for reward: a fat block shielded by a trap in front of it.
			events.append({t = t, id = &"recruits", x = side, amount = roundf(value * 1.8), hp = toughness})
			events.append({t = t, id = &"trap", x = side, z = 2.5, amount = roundf(3.0 + t / 10.0)})
		else:
			events.append({t = t, id = &"recruits", x = side, amount = value, hp = toughness})
		j += 1
		t += s.pickup_gap


static func _load_forged() -> void:
	if not _forged.is_empty() or not FileAccess.file_exists(FORGED):
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FORGED))
	var tail := []
	for entry in data.nodes:
		_forged[int(entry.node)] = entry
		tail.append(float(entry.intensity))
	# Past the forged range, play at the plateau: the mean of the last ten forged intensities.
	tail = tail.slice(-10)
	if not tail.is_empty():
		_plateau = tail.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / tail.size()
