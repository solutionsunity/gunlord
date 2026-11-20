extends SceneTree
## Plays Level 01 headless under simple steering policies and prints how each
## run ends. A balance probe: a good policy should win, a careless one lose.
##   godot --headless --path . -s tests/simulate.gd

const DT := 1.0 / 60.0
const TIME_LIMIT := 240.0


func _init() -> void:
	for policy in [&"idle", &"sweep", &"greedy"]:
		var b := Battle.new(Content.weapons(), Content.objects(), Level01.build())
		var started := Time.get_ticks_usec()
		var ticks := 0
		var max_shots := 0
		var max_objects := 0
		while b.state == Battle.State.RUNNING and b.time < TIME_LIMIT:
			_steer(policy, b)
			b.tick(DT)
			b.events.clear()
			ticks += 1
			max_shots = maxi(max_shots, b.shots.size())
			max_objects = maxi(max_objects, b.lane.size())
		var ms := (Time.get_ticks_usec() - started) / 1000.0 / ticks
		print("%-7s %-7s t=%5.1fs wave=%2d units=%4d peak=%4d %s | objs<=%d shots<=%d %.3f ms/tick" % [
			policy, Battle.State.keys()[b.state], b.time, b.wave, b.squad.total(), b.peak_units,
			_mix(b), max_objects, max_shots, ms])
	quit()


func _steer(policy: StringName, b: Battle) -> void:
	match policy:
		&"idle":
			b.squad.target_x = 0.0
		&"sweep":
			b.squad.target_x = sin(b.time * 0.8) * Squad.EDGE
		&"greedy":
			b.squad.target_x = _greedy_x(b)


## Hold the centre while enemies are close; otherwise stand under the best
## pickup in reach, skipping lanes led by a trap.
func _greedy_x(b: Battle) -> float:
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


func _trap_ahead(lane: Lane, i: int) -> bool:
	for k in lane.size():
		if lane.def[k].is_trap() and absf(lane.x[k] - lane.x[i]) < 0.5 and lane.z[k] > lane.z[i]:
			return true
	return false


func _mix(b: Battle) -> String:
	var parts: PackedStringArray = []
	for w in b.squad.weapons.size():
		parts.append("%s:%d" % [b.squad.weapons[w].id, b.squad.counts[w]])
	return " ".join(parts)
