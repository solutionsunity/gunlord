extends SceneTree
## Where on the lane does combat happen? Plays Level 01 under the sweeping bot
## and reports the distance at which enemies die, and how long each boss lives
## once it is in range of the squad.
##   godot --headless --path . -s tests/engagement.gd -- <level number, default 2>

const DT := 1.0 / 60.0


var _kill_z := PackedFloat32Array()   ## where each enemy fell
var _bosses := {}   ## serial -> {id, spawned, engaged, died, died_z}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var index := int(args[0]) - 1 if not args.is_empty() else 1
	var b := Battle.create(Content.weapons(), Content.arms(), Content.objects(), Content.SURGES, Stages.build(index))
	while b.state == Battle.State.RUNNING and b.time < 240.0:
		b.squad.target_x = sin(b.time * 0.8) * Squad.EDGE
		_track_bosses(b)
		b.tick(DT)
		for e in b.events:
			if e.kind == &"death" and e.enemy:
				_kill_z.append(e.at.z)
		b.events.clear()
	_track_bosses(b)
	var z := Array(_kill_z)
	z.sort()
	var n := z.size()
	print("result %s t=%.1f units=%d enemies killed=%d" % [ClassDB.class_get_enum_constants(&"Battle", &"State")[b.state], b.time, b.squad.total(), n])
	print("enemy death z: p10=%.1f median=%.1f p90=%.1f  (spawn %.0f, squad 0)" % [z[n / 10], z[n / 2], z[n * 9 / 10], Lane.SPAWN_Z])
	for s in _bosses:
		var e: Dictionary = _bosses[s]
		print("%-8s spawned %.1fs  in range %.1fs  died %.1fs at z=%.1f  -> %.1fs under fire" % [
			e.id, e.spawned, e.engaged, e.died, e.died_z, e.died - e.engaged])
	quit()


## Bosses are tracked by serial across ticks; "in range" = within base-weapon reach.
func _track_bosses(b: Battle) -> void:
	var seen := {}
	var serial := b.lane.serial
	var z := b.lane.z
	for i in b.lane.size():
		var d: ObjectDef = b.lane.def_of(i)
		if not d.persistent:
			continue
		var s := serial[i]
		seen[s] = true
		if not _bosses.has(s):
			_bosses[s] = {id = d.id, spawned = b.time, engaged = -1.0, died = -1.0, died_z = 0.0, z = 0.0}
		var e: Dictionary = _bosses[s]
		e.z = z[i]
		if e.engaged < 0.0 and z[i] > -_base_reach(b):
			e.engaged = b.time
	for s in _bosses:
		var e: Dictionary = _bosses[s]
		if e.died < 0.0 and not seen.has(s):
			e.died = b.time
			e.died_z = e.z


func _base_reach(b: Battle) -> float:
	for w in b.squad.weapons:
		if w.id == &"crossbow":
			return w.reach
	return 0.0
