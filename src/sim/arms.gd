class_name Arms
extends RefCounted
## What fights beside the squad's own weapons: the relics it brings (blades,
## drones, shield; see Relics) and the surge running now, if any. The battle
## calls tick once per step; the arms reach into the squad, lane and shots
## only through their interfaces.

const CHAIN := 0.8            ## share of a hit's damage each arc carries
const FLAME_DEPTH := 7.0      ## metres of fire ahead of the squad's front
const FLAME_DPS := 8.0        ## plus FLAME_PER_UNIT for every unit in the squad
const FLAME_PER_UNIT := 0.3
const ROCKETS_PER_S := 1.0    ## plus one more per ROCKET_UNITS units
const ROCKET_UNITS := 25.0
const BLADE_REACH := 0.7      ## metres a blade cuts around itself
const WIDEST := 3.0           ## no enemy is wider than this (a scaled warlord)
const BLADE_DPS := 10.0       ## per blade, per relic level
const BLADE_SPIN := 2.4       ## rad/s
const BLADE_GAP := 0.9        ## metres between the squad's rim and the blades' circle
const DRONE_GAP := 1.3        ## metres from the squad's rim to a drone
const SHIELD_PER_LEVEL := 6.0 ## blows the shield holds at full charge, per level
const SHIELD_REGEN := 0.5     ## blows recharged per second, per level

var loadout := {}             ## relic id -> level
var spin := 0.0               ## the blades' angle
var shield := 0.0             ## blows the shield can take now
var surge: StringName         ## the surge running, or empty
var surge_left := 0.0         ## its seconds left
var _arsenal: Array[WeaponDef]
var _rocket := -1             ## the rocket's index in the arsenal
var _drone := -1              ## the drone's
var _rocket_acc := 0.0
var _drone_acc := 0.0


func _init(arsenal: Array[WeaponDef], p_loadout: Dictionary) -> void:
	_arsenal = arsenal
	loadout = p_loadout
	shield = shield_max()
	for i in arsenal.size():
		match arsenal[i].id:
			&"rocket":
				_rocket = i
			&"drone":
				_drone = i


func level(relic: StringName) -> int:
	return loadout.get(relic, 0)


func shield_max() -> float:
	return SHIELD_PER_LEVEL * level(&"shield")


## Where each blade is now.
func blades(squad: Squad) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := level(&"blades") + 1 if level(&"blades") > 0 else 0
	var r := squad.radius() + BLADE_GAP
	for k in n:
		out.append(Vector2(squad.x, Squad.Z) + Vector2.from_angle(spin + k * TAU / n) * r)
	return out


## Where each drone hovers: alternately right and left of the squad, further back each pair.
func drones(squad: Squad) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in level(&"drone"):
		var side := 1.0 if k % 2 == 0 else -1.0
		out.append(Vector2(squad.x + side * (squad.radius() + DRONE_GAP), Squad.Z + 0.6 - (k / 2) * 1.4))
	return out


## Of n units about to fall to the front line, how many the shield saves.
func absorb(n: int) -> int:
	var saved := mini(n, int(shield))
	shield -= saved
	return saved


## Starts a surge; a running one is replaced, the same one starts over.
func grant(id: StringName) -> void:
	surge = id
	surge_left = Content.SURGES[id].seconds


func frozen() -> bool:
	return surge == &"freeze"


## The share of a hit's damage that arcs onward; 0 when no chain runs.
func chain() -> float:
	return CHAIN if surge == &"chain" else 0.0


func tick(dt: float, squad: Squad, lane: Lane, shots: Shots) -> void:
	_relics(dt, squad, lane, shots)
	if surge == &"":
		return
	match surge:
		&"flame":
			_flame(dt, squad, lane)
		&"rockets":
			_rockets(dt, squad, lane, shots)
	surge_left -= dt
	if surge_left <= 0.0:
		surge = &""


func _relics(dt: float, squad: Squad, lane: Lane, shots: Shots) -> void:
	shield = minf(shield + SHIELD_REGEN * level(&"shield") * dt, shield_max())
	if level(&"blades") > 0:
		spin = fposmod(spin + BLADE_SPIN * dt, TAU)
		var hurt := BLADE_DPS * level(&"blades") * squad.damage_mult * dt
		var cuts := blades(squad)
		var ring := squad.radius() + BLADE_GAP + BLADE_REACH + WIDEST   # nothing further from the squad can be cut
		for i in lane.size():
			if not lane.alive[i] or not lane.def[i].enemy:
				continue
			var p := Vector2(lane.x[i], lane.z[i])
			if absf(p.x - squad.x) > ring or absf(p.y - Squad.Z) > ring:
				continue
			for b in cuts:
				if p.distance_to(b) <= BLADE_REACH + lane.def[i].radius:
					lane.damage(i, hurt)
	if level(&"drone") > 0:
		var wd := _arsenal[_drone]
		_drone_acc += level(&"drone") * wd.fire_rate * dt
		var spots := drones(squad)
		var k := 0
		while _drone_acc >= 1.0:
			_drone_acc -= 1.0
			var from := spots[k % spots.size()]
			k += 1
			var t := lane.nearest_target(from, wd.reach, true)
			if t >= 0:
				shots.fire(wd, _drone, from, (Vector2(lane.x[t], lane.z[t]) - from).normalized(), squad.damage_mult)


## Burns every enemy in a cone just ahead of the squad, widening with distance.
func _flame(dt: float, squad: Squad, lane: Lane) -> void:
	var front := Squad.Z - squad.radius()
	var dps := (FLAME_DPS + FLAME_PER_UNIT * squad.total()) * squad.damage_mult
	for i in lane.size():
		if not lane.alive[i] or not lane.def[i].enemy:
			continue
		var ahead := front - lane.z[i]
		if ahead >= -lane.def[i].radius and ahead <= FLAME_DEPTH \
				and absf(lane.x[i] - squad.x) < squad.radius() + 1.0 + ahead * 0.25:
			lane.damage(i, dps * dt)


## Fires homing rockets from the squad's middle, more as it grows.
func _rockets(dt: float, squad: Squad, lane: Lane, shots: Shots) -> void:
	_rocket_acc += (ROCKETS_PER_S + squad.total() / ROCKET_UNITS) * dt
	var wd := _arsenal[_rocket]
	while _rocket_acc >= 1.0:
		_rocket_acc -= 1.0
		var from := Vector2(squad.x, Squad.Z - squad.radius() * 0.5)
		var t := lane.nearest_target(from, wd.reach, true)
		var dir := Vector2(0.0, -1.0) if t < 0 else (Vector2(lane.x[t], lane.z[t]) - from).normalized()
		shots.fire(wd, _rocket, from, dir, squad.damage_mult)
