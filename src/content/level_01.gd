class_name Level01
extends RefCounted
## The first level as a timeline of spawn events, sorted by time.
## Challenge grows linearly (horde size, block hp); rewards grow exponentially
## (block payouts), per the pacing rule in DESIGN.md.

const WAVES := 20
const CAPACITY := 120
const WAVE_START := 2.0
const WAVE_GAP := 4.2
const PICKUP_GAP := 1.7
const PICKUP_END := 80.0
const SIDE_X := 4.75
const CRATES := [
	[10.0, &"gun_crate"], [24.0, &"gatling_crate"], [40.0, &"war_drum"], [46.0, &"cannon_crate"],
	[58.0, &"gatling_crate"], [66.0, &"war_drum"], [72.0, &"cannon_crate"],
]


static func build() -> Level:
	var events: Array[Dictionary] = []
	_waves(events)
	_pickups(events)
	events.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.t < b.t)
	return Level.new(events, WAVES, CAPACITY)


static func _waves(events: Array[Dictionary]) -> void:
	var brutes := 0
	for i in WAVES:
		var t := WAVE_START + i * WAVE_GAP
		var soldiers := 8 + 4 * i
		for k in soldiers:
			var col := k % 7
			var row := k / 7
			events.append({t = t, id = &"soldier", x = -2.55 + col * 0.85, z = -row * 0.85, wave = i + 1})
		if i >= 6:
			for k in (i - 5) * 2:
				events.append({t = t + 1.5, id = &"runner", x = -2.4 + (k % 7) * 0.8, z = -(k / 7) * 0.8})
		if i == WAVES - 1:
			events.append({t = t, id = &"warlord", x = 0.0, z = -8.0})
		elif i % 5 == 4:
			events.append({t = t, id = &"brute", x = 0.0, z = -7.0, hp = 300.0 + 250.0 * brutes})
			brutes += 1


static func _pickups(events: Array[Dictionary]) -> void:
	var crates := CRATES.duplicate()
	var j := 0
	var t := 0.5
	while t < PICKUP_END:
		var side := SIDE_X if j % 2 == 0 else -SIDE_X
		var value := roundf(1.5 * pow(1.025, t))
		var toughness := 4.0 + t * 0.7
		if not crates.is_empty() and t >= crates[0][0]:
			events.append({t = t, id = crates.pop_front()[1], x = side})
		elif j % 17 == 8:
			events.append({t = t, id = &"multiplier", x = side, hp = 40.0 + t * 1.5})
		elif j % 7 == 5:
			# Risk for reward: a fat block shielded by a trap in front of it.
			events.append({t = t, id = &"recruits", x = side, amount = roundf(value * 1.8), hp = toughness})
			events.append({t = t, id = &"trap", x = side, z = 2.5, amount = roundf(3.0 + t / 10.0)})
		else:
			events.append({t = t, id = &"recruits", x = side, amount = value, hp = toughness})
		j += 1
		t += PICKUP_GAP
