class_name Stages
extends RefCounted
## The endless map. Each node is a stage spec composed of blocks; one generator
## turns a spec into a spawn timeline. Nodes 1–5 are authored; every later node
## is forged (forge.gd) at the intensity recorded in assets/map/forged.json,
## and past the forged range at the plateau intensity, unverified.
##
## Spec fields, by block:
##   name, theme, character              title, time of day, what the stage leans on
##   plan:    plan                        the deck's layout, a key of PLANS
##            formations                  the shapes its waves are drawn from, keys of FORMATIONS
##            pickups                     how pickups are laid out, a key of PICKUPS
##            start                       the squad it opens with: [weapon id, count] pairs
##            surges                      when a surge pickup comes, as shares of the stage (0..1)
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

const WAVE_START := 2.0
const FORGED := "res://assets/map/forged.json"
const NO_LUCK := &"none"                ## build without surges: the stage as verified
const JITTER := 0.15                    ## metres a soldier may shift in formation between attempts
const SPACE := 0.85                     ## metres between soldiers in a formation
const MARGIN := 0.45                    ## a formation keeps this far inside its area

## The deck's layouts. walls: x of each low wall, which keeps enemies to their
## lane until they near the squad. areas: where a wave may march, [from x, to x],
## one drawn per wave; none means any stretch of the open deck. slots: the x
## positions pickups arrive at.
const PLANS := {
	lanes = {walls = [-3.25, 3.25], areas = [[-3.25, 3.25]], slots = [4.75, -4.75]},
	split = {walls = [0.0], areas = [[-6.0, 0.0], [0.0, 6.0]], slots = [4.5, -1.5, 1.5, -4.5]},
	open = {walls = [], areas = [], slots = [4.5, -2.0, 2.0, -4.5]},
}
const FORMATIONS := [&"block", &"line", &"wedge", &"columns", &"stream"]
## alternate: each slot in turn. pairs: two slots at once, then a double gap.
## bursts: three in a row at one slot. scatter: any slot.
const PICKUPS := [&"alternate", &"pairs", &"bursts", &"scatter"]

const AUTHORED := [
	{
		boss_scale = 1.0, companions = [], brutes_from = 1,
		plan = &"lanes", formations = [&"block"], pickups = &"alternate", start = [[&"crossbow", 10]], surges = [0.55],
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
		plan = &"split", formations = [&"block", &"line", &"wedge"], pickups = &"pairs", start = [[&"crossbow", 10]], surges = [0.5],
		name = "Old Crossing", theme = &"noon",
		waves = 20, gap = 4.2, horde = 6, growth = 3,
		runners_from = 7, runners = 2,
		brute_every = 5, brute_hp = 230.0, brute_step = 191.0, warlord_hp = 1530.0,
		capacity = 120, speed = 3.0, accel = 0.02,
		pickup_gap = 1.7, reward = 1.5, reward_growth = 1.025, tough = 4.0, tough_growth = 0.7,
		multiplier_every = 17, trap_every = 7,
		crates = [[10.0, &"gun_crate"], [24.0, &"gatling_crate"], [40.0, &"war_drum"], [46.0, &"cannon_crate"],
				[58.0, &"gatling_crate"], [66.0, &"war_drum"], [72.0, &"cannon_crate"]],
	},
	{
		boss_scale = 1.0, companions = [], brutes_from = 1,
		plan = &"open", formations = [&"stream", &"line", &"columns"], pickups = &"scatter", start = [[&"crossbow", 10]], surges = [0.4, 0.75],
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
		plan = &"open", formations = [&"block", &"wedge"], pickups = &"bursts", start = [[&"crossbow", 10]], surges = [0.5],
		name = "Brute Bridge", theme = &"dusk",
		waves = 21, gap = 4.2, horde = 6, growth = 2,
		runners_from = 8, runners = 2,
		brute_every = 4, brute_hp = 240.0, brute_step = 176.0, warlord_hp = 3000.0,
		capacity = 140, speed = 3.0, accel = 0.022,
		pickup_gap = 1.6, reward = 1.8, reward_growth = 1.027, tough = 4.0, tough_growth = 0.75,
		multiplier_every = 15, trap_every = 9,
		crates = [[9.0, &"gun_crate"], [22.0, &"cannon_crate"], [32.0, &"cannon_crate"], [44.0, &"war_drum"],
				[54.0, &"gatling_crate"], [64.0, &"cannon_crate"], [74.0, &"war_drum"]],
	},
	{
		boss_scale = 1.0, companions = [], brutes_from = 1,
		plan = &"lanes", formations = [&"block", &"line", &"wedge", &"columns", &"stream"], pickups = &"alternate", start = [[&"crossbow", 10]], surges = [0.35, 0.7],
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
## Everything else (formations, areas, pickup slots) is drawn from the node
## alone, so every attempt plays the stage that was verified.
## `luck` picks what the surge slots hold: empty draws one per slot afresh for
## each attempt (play); NO_LUCK leaves them out (the stage as verified, which
## must be won without luck); a surge id puts that surge in every slot.
static func build(node: int, attempt := 0, luck := &"") -> Level:
	return build_spec(spec(node), node, attempt, luck)


static func build_spec(s: Dictionary, node: int, attempt := 0, luck := &"") -> Level:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(node * 31 + attempt * 1000003)
	var mirror := -1.0 if attempt > 0 and rng.randi() % 2 == 1 else 1.0
	var jitter := JITTER if attempt > 0 else 0.0
	var draw := RandomNumberGenerator.new()
	draw.seed = hash(node * 7727 + 17)
	var plan: Dictionary = PLANS[s.plan]
	var events: Array[Dictionary] = []
	_waves(s, plan, events, draw, rng, jitter)
	var last_wave: float = WAVE_START + (s.waves - 1) * s.gap
	_pickups(s, plan, events, draw, last_wave, _surges(s, last_wave, luck, rng))
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
	level.walls = PackedFloat32Array(plan.walls.map(func(w: float) -> float: return w * mirror))
	level.start = s.start
	return level


static func _waves(s: Dictionary, plan: Dictionary, events: Array[Dictionary], draw: RandomNumberGenerator,
		rng: RandomNumberGenerator, jitter: float) -> void:
	var brutes := 0
	for i in s.waves:
		var t: float = WAVE_START + i * s.gap
		var area := _area(plan, draw)
		var shape: StringName = s.formations[draw.randi() % s.formations.size()]
		for p in _formation(shape, s.horde + s.growth * i, area, s.gap, draw):
			events.append({t = t + p.z, id = &"soldier", x = p.x + rng.randf_range(-jitter, jitter), z = p.y, wave = i + 1})
		if i + 1 >= s.runners_from:
			for p in _formation(&"line", (i + 2 - s.runners_from) * s.runners, area, s.gap, draw):
				events.append({t = t + 1.5, id = &"runner", x = p.x, z = p.y})
		if i == s.waves - 1:
			_boss(s, plan, events, t, draw)
		elif (i + 1) % s.brute_every == 0 and i + 1 >= s.brutes_from:
			events.append({t = t, id = &"brute", x = (area.x + area.y) / 2.0, z = -7.0, hp = s.brute_hp + s.brute_step * brutes})
			brutes += 1


## Where one wave marches: one of the plan's areas, or on the open deck a
## stretch 3.5 to 8 metres wide anywhere across it. Returned as (from x, to x).
static func _area(plan: Dictionary, draw: RandomNumberGenerator) -> Vector2:
	if not plan.areas.is_empty():
		var a: Array = plan.areas[draw.randi() % plan.areas.size()]
		return Vector2(a[0], a[1])
	var w := draw.randf_range(3.5, 8.0)
	var c := draw.randf_range(-Lane.HALF_WIDTH + w / 2.0, Lane.HALF_WIDTH - w / 2.0)
	return Vector2(c - w / 2.0, c + w / 2.0)


## n soldiers in a shape inside an area: each as (x, z behind the front, seconds late).
##   block    tight ranks, up to seven wide   line     loose ranks as wide as the area
##   wedge    a point aimed at the squad      columns  two files down the area's edges
##   stream   small groups at any x, spread through the wave's gap
static func _formation(shape: StringName, n: int, area: Vector2, gap: float, draw: RandomNumberGenerator) -> Array[Vector3]:
	var lo := area.x + MARGIN
	var hi := area.y - MARGIN
	var fit := int((hi - lo) / SPACE) + 1          # soldiers abreast the area holds
	var mid := (lo + hi) / 2.0
	var out: Array[Vector3] = []
	match shape:
		&"block":
			var cols := mini(7, fit)
			for k in n:
				out.append(Vector3(mid + (k % cols - (cols - 1) / 2.0) * SPACE, -(k / cols) * SPACE, 0.0))
		&"line":
			var gap_x := SPACE * 1.5
			var cols := int((hi - lo) / gap_x) + 1
			for k in n:
				out.append(Vector3(mid + (k % cols - (cols - 1) / 2.0) * gap_x, -(k / cols) * SPACE * 2.5, 0.0))
		&"wedge":
			var row := 0
			var k := 0
			while k < n:
				var width := mini(2 * row + 1, fit)
				for c in mini(width, n - k):
					out.append(Vector3(mid + (c - (width - 1) / 2.0) * SPACE, -row * SPACE, 0.0))
				k += width
				row += 1
		&"columns":
			for k in n:
				var side := lo + (k % 2) * SPACE if k % 4 < 2 else hi - (k % 2) * SPACE
				out.append(Vector3(side, -(k / 4) * SPACE, 0.0))
		&"stream":
			var groups := ceili(n / 3.0)
			var every := minf(0.6, gap * 0.8 / groups)
			var x := mid
			for k in n:
				if k % 3 == 0:
					x = draw.randf_range(lo + SPACE, hi - SPACE) if hi - lo > 2.0 * SPACE else mid
				out.append(Vector3(x + (k % 3 - 1) * SPACE, 0.0, (k / 3) * every))
	return out


## The warlord, scaled by boss_scale in size, reach and hp, with its companions
## around it, in the middle of the deck, or of a lane when a wall runs down the middle.
static func _boss(s: Dictionary, plan: Dictionary, events: Array[Dictionary], t: float, draw: RandomNumberGenerator) -> void:
	var at := 0.0
	if plan.walls.has(0.0):
		at = 3.0 if draw.randi() % 2 == 0 else -3.0
	var scale: float = s.boss_scale
	var def: ObjectDef = Content.objects()[&"warlord"].duplicate()
	def.size *= scale
	def.radius *= scale
	events.append({t = t, id = &"warlord", def = def, x = at, z = -8.0, hp = s.warlord_hp * scale})
	for c in s.companions:
		for k in c[1]:
			var side := -1.0 if k % 2 == 0 else 1.0
			var x: float = side * (1.4 + (k / 2 % 3) * 0.6) if c[0] != &"brute" else side * 2.0
			events.append({t = t, id = c[0], x = at + x, z = -6.5 - (k / 6) * 0.9})


## The surge slots as [seconds, pickup id], in order.
static func _surges(s: Dictionary, until: float, luck: StringName, rng: RandomNumberGenerator) -> Array:
	var out := []
	if luck == NO_LUCK:
		return out
	for share: float in s.surges:
		var id: StringName = luck if luck != &"" else Content.SURGES.keys()[rng.randi() % Content.SURGES.size()]
		out.append([share * until, StringName("surge_" + id)])
	return out


static func _pickups(s: Dictionary, plan: Dictionary, events: Array[Dictionary], draw: RandomNumberGenerator,
		until: float, surges: Array) -> void:
	var crates: Array = s.crates.duplicate()
	crates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var slots: Array = plan.slots
	var j := 0
	var t := 0.5
	var x := 0.0
	while t < until:
		match s.pickups:
			&"alternate":
				x = slots[j % slots.size()]
			&"bursts":
				x = slots[(j / 3) % slots.size()]
			&"scatter":
				x = slots[draw.randi() % slots.size()]
			&"pairs":   # the second of a pair takes another slot, at the same moment
				x = slots[draw.randi() % slots.size()] if j % 2 == 0 \
						else slots[(slots.find(x) + 1 + draw.randi() % (slots.size() - 1)) % slots.size()]
		var value := roundf(s.reward * pow(s.reward_growth, t))
		var toughness: float = s.tough + t * s.tough_growth
		if not surges.is_empty() and t >= surges[0][0]:
			events.append({t = t, id = surges.pop_front()[1], x = x, hp = 25.0 + t})
		elif not crates.is_empty() and t >= crates[0][0]:
			events.append({t = t, id = crates.pop_front()[1], x = x})
		elif j % s.multiplier_every == s.multiplier_every / 2:
			events.append({t = t, id = &"multiplier", x = x, hp = 40.0 + t * 1.5})
		elif j % s.trap_every == s.trap_every - 2:
			# Risk for reward: a fat block shielded by a trap in front of it.
			events.append({t = t, id = &"recruits", x = x, amount = roundf(value * 1.8), hp = toughness})
			events.append({t = t, id = &"trap", x = x, z = 2.5, amount = roundf(3.0 + t / 10.0)})
		else:
			events.append({t = t, id = &"recruits", x = x, amount = value, hp = toughness})
		j += 1
		if s.pickups != &"pairs" or j % 2 == 0:
			t += s.pickup_gap * (2.0 if s.pickups == &"pairs" else 1.0)


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
