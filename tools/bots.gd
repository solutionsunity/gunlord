extends RefCounted
## The reference players that judge every stage: the forge verifies with them,
## the tests and CI replay with them. One definition, so all three agree.
##   sweep   strafes the whole deck in a slow sine: a decent, mindless player
##   idle    stands in the middle: a stage this player wins is broken
##   greedy  chases the best pickup unless the horde is close

const DT := 1.0 / 60.0
const TIME_LIMIT := 300.0


## Plays one battle to its end. Returns {won, margin, survivors, peak, time, wave}.
## margin = survivors / capacity, 0 on a loss.
static func play(level: Level, policy: StringName) -> Dictionary:
	var b := Battle.create(Content.weapons(), Content.arms(), Content.objects(), Content.SURGES, level)
	while b.state == Battle.State.RUNNING and b.time < TIME_LIMIT:
		steer(policy, b)
		b.tick(DT)
		b.events.clear()
	var won := b.state == Battle.State.WON
	return {
		won = won, survivors = b.squad.total(), peak = b.peak_units, time = b.time, wave = b.wave,
		margin = float(b.squad.total()) / level.capacity if won else 0.0, battle = b,
	}


static func steer(policy: StringName, b: Battle) -> void:
	match policy:
		&"idle":
			b.squad.target_x = 0.0
		&"sweep":
			b.squad.target_x = sin(b.time * 0.8) * Squad.EDGE
		&"greedy":
			b.squad.target_x = _greedy_x(b)


## Hold the centre while enemies are close; otherwise stand under the best
## pickup in reach, skipping lanes led by a trap.
static func _greedy_x(b: Battle) -> float:
	var lane := b.lane
	var x := lane.x
	var z := lane.z
	var defs: Array[ObjectDef] = []
	for i in lane.size():
		defs.append(lane.def_of(i))
		if defs[i].enemy and z[i] > -22.0:
			return 0.0
	var amount := lane.amount
	var hp := lane.hp
	var best_x := 0.0
	var best := 0.0
	for i in lane.size():
		var d := defs[i]
		if d.enemy or d.is_trap() or z[i] < -45.0:
			continue
		if _trap_ahead(defs, x, z, i):
			continue
		var value := amount[i] / maxf(hp[i], 1.0)
		if value > best:
			best = value
			best_x = x[i]
	return best_x


static func _trap_ahead(defs: Array[ObjectDef], x: PackedFloat32Array, z: PackedFloat32Array, i: int) -> bool:
	for k in defs.size():
		if defs[k].is_trap() and absf(x[k] - x[i]) < 0.5 and z[k] > z[i]:
			return true
	return false
