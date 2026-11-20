class_name Shots
extends RefCounted
## Every projectile in flight, stored as parallel flat arrays. Removal swaps
## the last projectile into the freed index.

var x := PackedFloat32Array()
var z := PackedFloat32Array()
var vx := PackedFloat32Array()
var vz := PackedFloat32Array()
var damage := PackedFloat32Array()
var splash := PackedFloat32Array()
var life := PackedFloat32Array()
var pierce := PackedInt32Array()
var weapon := PackedInt32Array()
var last_hit := PackedInt32Array()   ## serial of the last object hit, so a piercing shot hits each object once
var hits_traps := PackedByteArray()  ## only straight shots can claim a trap
var fired := PackedFloat32Array()    ## this tick's shots: x, z, weapon per shot
var impacts := PackedFloat32Array()  ## this tick's hits: x, z, weapon, splash, lane index per hit
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.seed = 1


func size() -> int:
	return x.size()


func fire(wd: WeaponDef, w: int, p: Vector2, dir: Vector2, mult: float) -> void:
	fired.append_array([p.x, p.y, float(w)])
	var n := wd.spread_count
	for s in n:
		var a := 0.0
		if n > 1:
			a = deg_to_rad(wd.spread_angle) * (float(s) / (n - 1) - 0.5)
		if wd.jitter > 0.0:
			a += deg_to_rad(_rng.randf_range(-wd.jitter, wd.jitter))
		var v := dir.rotated(a) * wd.projectile_speed
		x.append(p.x)
		z.append(p.y)
		vx.append(v.x)
		vz.append(v.y)
		damage.append(wd.damage * mult)
		splash.append(wd.splash)
		life.append(wd.reach / wd.projectile_speed)
		pierce.append(wd.pierce)
		weapon.append(w)
		last_hit.append(-1)
		hits_traps.append(1 if wd.aim == WeaponDef.Aim.STRAIGHT else 0)


func advance(dt: float, lane: Lane, grid: Grid) -> void:
	var i := 0
	while i < size():
		life[i] -= dt
		x[i] += vx[i] * dt
		z[i] += vz[i] * dt
		var spent := life[i] <= 0.0
		if not spent:
			var hit := grid.first_hit(lane, x[i], z[i], last_hit[i], hits_traps[i] == 1)
			if hit >= 0:
				lane.damage(hit, damage[i])
				impacts.append_array([x[i], z[i], float(weapon[i]), splash[i], float(hit)])
				if splash[i] > 0.0:
					lane.splash(lane.x[hit], lane.z[hit], splash[i], damage[i] * 0.5, hit)
				last_hit[i] = lane.serial[hit]
				pierce[i] -= 1
				spent = pierce[i] < 0
		if spent:
			_swap_remove(i)
		else:
			i += 1


func _swap_remove(i: int) -> void:
	var last := size() - 1
	x[i] = x[last]
	z[i] = z[last]
	vx[i] = vx[last]
	vz[i] = vz[last]
	damage[i] = damage[last]
	splash[i] = splash[last]
	life[i] = life[last]
	pierce[i] = pierce[last]
	weapon[i] = weapon[last]
	last_hit[i] = last_hit[last]
	hits_traps[i] = hits_traps[last]
	x.resize(last)
	z.resize(last)
	vx.resize(last)
	vz.resize(last)
	damage.resize(last)
	splash.resize(last)
	life.resize(last)
	pierce.resize(last)
	weapon.resize(last)
	last_hit.resize(last)
	hits_traps.resize(last)
