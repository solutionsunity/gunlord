extends SceneTree
## CPU cost per frame of the real game scene under the sweeping bot, headless:
## the simulation tick and the view's buffer writes. GPU cost is not measured
## here; that needs a device.
##   godot --headless --path . -s tests/frame_cost.gd

var _main: Node
var _sim := PackedFloat32Array()
var _view := PackedFloat32Array()
var _sizes := PackedInt32Array()


func _init() -> void:
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()   # tests start fresh and never save
	_main._progress.path = ""
	_main._settings = Settings.new()   # and default settings, never saved
	_main._settings.path = ""
	root.add_child(_main)
	_main.set_physics_process(false)
	_main.set_process(false)


func _process(delta: float) -> bool:
	if _main._battle == null:
		_main.start_level(4)   # the game opens on the menu
		return false
	var b: Battle = _main._battle
	b.squad.target_x = sin(b.time * 0.8) * Squad.EDGE
	var t0 := Time.get_ticks_usec()
	b.tick(1.0 / 60.0)
	var t1 := Time.get_ticks_usec()
	_main._view.draw(b, 1.0 / 60.0)
	var t2 := Time.get_ticks_usec()
	_sim.append((t1 - t0) / 1000.0)
	_view.append((t2 - t1) / 1000.0)
	_sizes.append(b.squad.total() + b.lane.size() + b.shots.size())
	if b.state == Battle.State.RUNNING and b.time < 200.0:
		return false
	print("frames=%d  sim ms: %s  view ms: %s  peak entities=%d" % [_sim.size(), _stats(_sim), _stats(_view), _max(_sizes)])
	return true


func _stats(a: PackedFloat32Array) -> String:
	var s := Array(a)
	s.sort()
	return "median %.2f p95 %.2f max %.2f" % [s[s.size() / 2], s[s.size() * 95 / 100], s[-1]]


func _max(a: PackedInt32Array) -> int:
	var m := 0
	for v in a:
		m = maxi(m, v)
	return m
