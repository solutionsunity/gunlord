extends SceneTree
## Where on the lane does combat happen? Plays Level 01 under the sweeping bot
## and reports the distance at which enemies die, and how long each boss lives
## once it is in range of the squad.
##   godot --headless --path . -s tests/engagement.gd -- <level number, default 2>

const DT := 1.0 / 60.0


class Probe extends Battle:
	var kill_z := PackedFloat32Array()
	var bosses := {}   ## serial -> {id, spawned, engaged, died, died_z}

	func _payouts() -> void:
		for i in lane.destroyed:
			if lane.def[i].enemy:
				kill_z.append(lane.z[i])
		super._payouts()


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := int(args[0]) - 1 if not args.is_empty() else 1
	var b := Probe.new(Content.weapons(), Content.objects(), Stages.build(index))
	while b.state == Battle.State.RUNNING and b.time < 240.0:
		b.squad.target_x = sin(b.time * 0.8) * Squad.EDGE
		_track_bosses(b)
		b.tick(DT)
		b.events.clear()
	_track_bosses(b)
	var z := Array(b.kill_z)
	z.sort()
	var n := z.size()
	print("result %s t=%.1f units=%d enemies killed=%d" % [Battle.State.keys()[b.state], b.time, b.squad.total(), n])
	print("enemy death z: p10=%.1f median=%.1f p90=%.1f  (spawn %.0f, squad 0)" % [z[n / 10], z[n / 2], z[n * 9 / 10], Lane.SPAWN_Z])
	for s in b.bosses:
		var e: Dictionary = b.bosses[s]
		print("%-8s spawned %.1fs  in range %.1fs  died %.1fs at z=%.1f  -> %.1fs under fire" % [
			e.id, e.spawned, e.engaged, e.died, e.died_z, e.died - e.engaged])
	quit()


## Bosses are tracked by serial across ticks; "in range" = within base-weapon reach.
func _track_bosses(b: Probe) -> void:
	var seen := {}
	for i in b.lane.size():
		var d := b.lane.def[i]
		if not d.persistent:
			continue
		var s := b.lane.serial[i]
		seen[s] = true
		if not b.bosses.has(s):
			b.bosses[s] = {id = d.id, spawned = b.time, engaged = -1.0, died = -1.0, died_z = 0.0, z = 0.0}
		var e: Dictionary = b.bosses[s]
		e.z = b.lane.z[i]
		if e.engaged < 0.0 and b.lane.z[i] > -_base_reach(b):
			e.engaged = b.time
	for s in b.bosses:
		var e: Dictionary = b.bosses[s]
		if e.died < 0.0 and not seen.has(s):
			e.died = b.time
			e.died_z = e.z


func _base_reach(b: Battle) -> float:
	for w in b.squad.weapons:
		if w.id == &"crossbow":
			return w.reach
	return 0.0
