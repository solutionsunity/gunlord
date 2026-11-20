extends SceneTree
## Plays the real scene under the sweeping bot until time T, then saves a
## close-up of the squad to build/closeup_<T>.png. Renders only that frame.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 -s tests/closeup.gd -- 60

var _main: Node
var _at := 13.0
var _armed := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_at = float(args[0])
	DirAccess.make_dir_recursive_absolute("res://build")
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()   # tests start fresh and never save
	_main._progress.path = ""
	root.add_child(_main)
	RenderingServer.render_loop_enabled = false


func _process(_delta: float) -> bool:
	if _main._battle == null:
		_main.start_level(1)   # the game opens on the menu
		return false
	var b: Battle = _main._battle
	b.squad.target_x = sin(b.time * 0.8) * Squad.EDGE
	if _armed:
		root.get_texture().get_image().save_png("res://build/closeup_%d.png" % int(_at))
		print("closeup at t=%.1f units=%d" % [b.time, b.squad.total()])
		return true
	if b.time >= _at or b.state != Battle.State.RUNNING:
		_main._view.stage.camera.look_at_from_position(Vector3(b.squad.x, 4.5, 5.0), Vector3(b.squad.x, 0.4, -2.5))
		_main._view.stage.camera_home = _main._view.stage.camera.transform
		_armed = true
		RenderingServer.render_loop_enabled = true
	return false
