class_name Arms
extends RefCounted
## What fights beside the squad's own weapons: the surge running now, if any.
## The battle calls tick once per step; the arms reach into the squad, lane and
## shots only through their interfaces.

const CHAIN := 0.8            ## share of a hit's damage each arc carries
const FLAME_DEPTH := 7.0      ## metres of fire ahead of the squad's front
const FLAME_DPS := 8.0        ## plus FLAME_PER_UNIT for every unit in the squad
const FLAME_PER_UNIT := 0.3
const ROCKETS_PER_S := 1.0    ## plus one more per ROCKET_UNITS units
const ROCKET_UNITS := 25.0

var surge: StringName         ## the surge running, or empty
var surge_left := 0.0         ## its seconds left
var _arsenal: Array[WeaponDef]
var _rocket := -1             ## the rocket's index in the arsenal
var _rocket_acc := 0.0


func _init(arsenal: Array[WeaponDef]) -> void:
	_arsenal = arsenal
	for i in arsenal.size():
		if arsenal[i].id == &"rocket":
			_rocket = i


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
