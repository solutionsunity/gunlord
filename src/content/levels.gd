class_name Levels
extends RefCounted
## The campaign. Each level is a spec; one generator turns a spec into a spawn
## timeline. Challenge grows linearly (horde size, block toughness, lane speed);
## rewards grow exponentially (block payouts), per the pacing rule in DESIGN.md.

const SIDE_X := 4.75
const WAVE_START := 2.0

## Spec fields:
##   name, theme                   title and the stage's time of day
##   waves, gap                    wave count and seconds between waves
##   horde, growth                 soldiers in wave 1, extra soldiers per wave
##   runners_from, runners         first wave with runners, runners added per wave after it
##   brute_every, brute_hp, brute_step   a brute every N waves, its hp, hp added per brute
##   warlord_hp                    the final boss
##   capacity                      the squad's maximum
##   speed, accel                  lane speed at start (m/s), added per second
##   pickup_gap                    seconds between side-lane pickups
##   reward, reward_growth         first block's payout, payout growth per second (exponential)
##   tough, tough_growth           first block's hp, hp added per second (linear)
##   multiplier_every, trap_every  every Nth pickup is a ×1.5 block; every Nth a trap shielding a fat block
##   crates                        [seconds, crate id] in order
const SPECS := [
	{
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


static func count() -> int:
	return SPECS.size()


static func build(index: int) -> Level:
	var spec: Dictionary = SPECS[index]
	var events: Array[Dictionary] = []
	_waves(spec, events)
	var last_wave: float = WAVE_START + (spec.waves - 1) * spec.gap
	_pickups(spec, events, last_wave)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	var level := Level.new(events, spec.waves, spec.capacity)
	level.index = index
	level.name = spec.name
	level.theme = spec.theme
	level.duration = last_wave + 8.0
	level.speed = spec.speed
	level.accel = spec.accel
	return level


static func _waves(spec: Dictionary, events: Array[Dictionary]) -> void:
	var brutes := 0
	for i in spec.waves:
		var t: float = WAVE_START + i * spec.gap
		var soldiers: int = spec.horde + spec.growth * i
		for k in soldiers:
			events.append({t = t, id = &"soldier", x = -2.55 + (k % 7) * 0.85, z = -(k / 7) * 0.85, wave = i + 1})
		if i + 1 >= spec.runners_from:
			for k in (i + 2 - spec.runners_from) * spec.runners:
				events.append({t = t + 1.5, id = &"runner", x = -2.4 + (k % 7) * 0.8, z = -(k / 7) * 0.8})
		if i == spec.waves - 1:
			events.append({t = t, id = &"warlord", x = 0.0, z = -8.0, hp = spec.warlord_hp})
		elif (i + 1) % spec.brute_every == 0:
			events.append({t = t, id = &"brute", x = 0.0, z = -7.0, hp = spec.brute_hp + spec.brute_step * brutes})
			brutes += 1


static func _pickups(spec: Dictionary, events: Array[Dictionary], until: float) -> void:
	var crates: Array = spec.crates.duplicate()
	var j := 0
	var t := 0.5
	while t < until:
		var side := SIDE_X if j % 2 == 0 else -SIDE_X
		var value := roundf(spec.reward * pow(spec.reward_growth, t))
		var toughness: float = spec.tough + t * spec.tough_growth
		if not crates.is_empty() and t >= crates[0][0]:
			events.append({t = t, id = crates.pop_front()[1], x = side})
		elif j % spec.multiplier_every == spec.multiplier_every / 2:
			events.append({t = t, id = &"multiplier", x = side, hp = 40.0 + t * 1.5})
		elif j % spec.trap_every == spec.trap_every - 2:
			# Risk for reward: a fat block shielded by a trap in front of it.
			events.append({t = t, id = &"recruits", x = side, amount = roundf(value * 1.8), hp = toughness})
			events.append({t = t, id = &"trap", x = side, z = 2.5, amount = roundf(3.0 + t / 10.0)})
		else:
			events.append({t = t, id = &"recruits", x = side, amount = value, hp = toughness})
		j += 1
		t += spec.pickup_gap
