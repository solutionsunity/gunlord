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
	var b := Battle.new(Content.weapons(), Content.objects(), level)
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
	for i in lane.size():
		if lane.def[i].enemy and lane.z[i] > -22.0:
			return 0.0
	var best_x := 0.0
	var best := 0.0
	for i in lane.size():
		var d := lane.def[i]
		if d.enemy or d.is_trap() or lane.z[i] < -45.0:
			continue
		if _trap_ahead(lane, i):
			continue
		var value := lane.amount[i] / maxf(lane.hp[i], 1.0)
		if value > best:
			best = value
			best_x = lane.x[i]
	return best_x


static func _trap_ahead(lane: Lane, i: int) -> bool:
	for k in lane.size():
		if lane.def[k].is_trap() and absf(lane.x[k] - lane.x[i]) < 0.5 and lane.z[k] > lane.z[i]:
			return true
	return false
