class_name Squad
extends RefCounted
## The player's squad: a count of units per weapon, laid out as a sunflower
## disc around one centre. Unit k sits at slot k; weapons fill slots in roster
## order, so the first weapons sit in the middle and the last ones on the rim.

const Z := 0.0
const SPACING := 0.36
const EDGE := 6.0            ## half-width of the deck: the rim of the squad stops here
const MAX_SPEED := 30.0
const GOLDEN_ANGLE := 2.39996323

var weapons: Array[WeaponDef]
var capacity := 0                  ## maximum unit count; payouts beyond it are lost
var counts := PackedInt32Array()
var damage_mult := 1.0
var x := 0.0
var target_x := 0.0
var _acc := PackedFloat32Array()   ## shots owed per weapon
var _rr := PackedInt32Array()      ## round-robin cursor per weapon
var _wound := 0.0                  ## fractional losses from persistent attackers


func _init(roster: Array[WeaponDef], p_capacity: int) -> void:
	weapons = roster
	capacity = p_capacity
	counts.resize(roster.size())
	_acc.resize(roster.size())
	_rr.resize(roster.size())


func total() -> int:
	var n := 0
	for c in counts:
		n += c
	return n


func radius() -> float:
	return SPACING * sqrt(float(total())) + 0.3


static func slot(k: int) -> Vector2:
	var r := SPACING * sqrt(k + 0.5)
	var a := k * GOLDEN_ANGLE
	return Vector2(cos(a) * r, sin(a) * r)


func unit_position(k: int) -> Vector2:
	return slot(k) + Vector2(x, Z)


## How far the centre may move from the lane axis: a bigger squad keeps more
## of itself on the deck, and covers the side lanes with its rim.
func limit() -> float:
	return maxf(EDGE - radius(), 0.6)


func steer(dx: float) -> void:
	target_x = clampf(target_x + dx, -limit(), limit())


func move(dt: float) -> void:
	target_x = clampf(target_x, -limit(), limit())
	x = clampf(move_toward(x, target_x, MAX_SPEED * dt), -limit(), limit())


## Adds up to n units, never past capacity. Returns how many were added.
func add(w: int, n: int) -> int:
	var added := clampi(n, 0, capacity - total())
	counts[w] += added
	return added


## Like add, but at capacity the remainder replaces rim units (the last weapon
## in roster order) one-for-one, so a full squad can still upgrade its weapons.
func enlist(w: int, n: int) -> int:
	var added := add(w, n)
	var rim := counts.size() - 1
	if w != rim:
		var swapped := mini(n - added, counts[rim])
		counts[rim] -= swapped
		counts[w] += swapped
		added += swapped
	return added


## Grows weapon w by factor f, never past capacity. Returns how many were added.
func multiply(w: int, f: float) -> int:
	return add(w, int(round(counts[w] * f)) - counts[w])


## Losses come off the rim first: the last weapon in roster order.
func remove_outer(n: int) -> void:
	for w in range(counts.size() - 1, -1, -1):
		var take := mini(n, counts[w])
		counts[w] -= take
		n -= take
		if n == 0:
			return


## Accumulates fractional losses; returns how many whole units are now lost.
## The caller removes them.
func wound(units: float) -> int:
	_wound += units
	var n := int(_wound)
	_wound -= n
	return n


## The weapon index of unit k (formation order).
func weapon_at(k: int) -> int:
	for w in counts.size():
		if k < counts[w]:
			return w
		k -= counts[w]
	return -1


## Every unit fires at its weapon's rate. Shots owed accumulate per weapon and
## are paid out round-robin across that weapon's units.
func fire(dt: float, lane: Lane, shots: Shots, lane_speed: float) -> void:
	var offset := 0
	for w in weapons.size():
		var c := counts[w]
		if c == 0:
			_acc[w] = 0.0
			continue
		var wd := weapons[w]
		_acc[w] = minf(_acc[w] + c * wd.fire_rate * dt, float(c))
		while _acc[w] >= 1.0:
			_acc[w] -= 1.0
			var p := unit_position(offset + _rr[w] % c)
			_rr[w] += 1
			var dir := Vector2(0.0, -1.0)
			if wd.aim == WeaponDef.Aim.AUTO:
				var t := lane.nearest_target(p, wd.reach)
				if t < 0:
					continue
				# Lead the target by its travel time.
				var target := Vector2(lane.x[t], lane.z[t])
				var eta := p.distance_to(target) / wd.projectile_speed
				target.y += lane.speed_of(t, lane_speed) * eta
				dir = (target - p).normalized()
			shots.fire(wd, w, p, dir, damage_mult)
		offset += c
