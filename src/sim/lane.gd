class_name Lane
extends RefCounted
## Every lane object, stored as parallel flat arrays (one index = one object).
## Removal is deferred: objects are flagged dead during a tick and compacted at
## its end, so indices stay valid for the whole tick.

const SPAWN_Z := -50.0
const WALL_END_Z := -5.0     ## where the walls between lanes stop
const HALF_WIDTH := 6.0

var walls := PackedFloat32Array()    ## x of each wall; an enemy keeps to the lane between two, or a wall and the edge

var def: Array[ObjectDef] = []
var serial := PackedInt32Array()     ## stable identity across compaction
var x := PackedFloat32Array()
var z := PackedFloat32Array()
var hp := PackedFloat32Array()
var max_hp := PackedFloat32Array()
var amount := PackedFloat32Array()
var hit_age := PackedFloat32Array()  ## seconds since last hit, drives the hit flash
var alive := PackedByteArray()
var destroyed := PackedInt32Array()  ## shot down this tick, awaiting payout
var _next_serial := 0


func size() -> int:
	return x.size()


func spawn(d: ObjectDef, px: float, pz: float, php: float, pamount: float) -> void:
	def.append(d)
	serial.append(_next_serial)
	_next_serial += 1
	x.append(px)
	z.append(pz)
	hp.append(php)
	max_hp.append(php)
	amount.append(pamount)
	hit_age.append(99.0)
	alive.append(1)


func speed_of(i: int, lane_speed: float) -> float:
	return lane_speed + def[i].walk


func advance(dt: float, lane_speed: float, squad_x: float) -> void:
	for i in size():
		if not alive[i]:
			continue
		var d := def[i]
		hit_age[i] += dt
		z[i] += speed_of(i, lane_speed) * dt
		if d.enemy:
			if z[i] > WALL_END_Z:
				x[i] = move_toward(x[i], squad_x, d.seek * dt)
			else:
				x[i] = _keep_in_lane(x[i], d.radius)
		elif z[i] > WALL_END_Z:
			alive[i] = 0  # a pickup that reaches the end of its lane is lost


func _keep_in_lane(px: float, r: float) -> float:
	var lo := -HALF_WIDTH
	var hi := HALF_WIDTH
	for w in walls:
		if w < px:
			lo = maxf(lo, w)
		else:
			hi = minf(hi, w)
	return clampf(px, lo + r, hi - r) if hi - lo > 2.0 * r else (lo + hi) / 2.0


func damage(i: int, dmg: float) -> void:
	if not alive[i]:
		return
	hp[i] -= dmg
	hit_age[i] = 0.0
	if hp[i] <= 0.0:
		alive[i] = 0
		destroyed.append(i)


## Area damage never touches traps: traps are claimed only by a direct straight shot.
func splash(px: float, pz: float, r: float, dmg: float, skip: int) -> void:
	for i in size():
		if i == skip or not alive[i] or def[i].is_trap():
			continue
		var reach := r + def[i].radius
		if (x[i] - px) ** 2 + (z[i] - pz) ** 2 <= reach * reach:
			damage(i, dmg)


## Nearest live object an auto-aim weapon may pick. Traps are never picked.
func nearest_target(p: Vector2, reach: float) -> int:
	var best := -1
	var best_d := reach * reach
	for i in size():
		if not alive[i] or def[i].is_trap() or z[i] > p.y:
			continue
		var d2 := (x[i] - p.x) ** 2 + (z[i] - p.y) ** 2
		if d2 < best_d:
			best_d = d2
			best = i
	return best


func compact() -> void:
	var j := 0
	for i in size():
		if not alive[i]:
			continue
		if i != j:
			def[j] = def[i]
			serial[j] = serial[i]
			x[j] = x[i]
			z[j] = z[i]
			hp[j] = hp[i]
			max_hp[j] = max_hp[i]
			amount[j] = amount[i]
			hit_age[j] = hit_age[i]
			alive[j] = 1
		j += 1
	def.resize(j)
	serial.resize(j)
	x.resize(j)
	z.resize(j)
	hp.resize(j)
	max_hp.resize(j)
	amount.resize(j)
	hit_age.resize(j)
	alive.resize(j)
	destroyed.clear()
