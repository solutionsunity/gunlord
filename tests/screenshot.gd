extends SceneTree
## Runs the real game scene under a sweeping bot and saves frames to build/.
## The simulation runs at full speed; the renderer is switched on only for the
## frames being captured, so this is quick even on a software GPU.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 -s tests/screenshot.gd

const SHOTS := [6.0, 20.0, 38.0, 55.0, 72.0, 91.0]

var _main: Node
var _taken := 0
var _armed := false


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()   # tests start fresh and never save
	_main._progress.path = ""
	_main._settings = Settings.new()   # and default settings, never saved
	_main._settings.path = ""
	root.add_child(_main)
	RenderingServer.render_loop_enabled = false


func _process(_delta: float) -> bool:
	if _main._battle == null:
		_main.start_level(1)   # the game opens on the menu
		return false
	var b: Battle = _main._battle
	b.squad.target_x = sin(b.time * 0.8) * Squad.EDGE
	if _armed:
		# Rendering was switched on last frame, so the viewport now holds a fresh image.
		root.get_texture().get_image().save_png("res://build/frame_%02d.png" % _taken)
		print("frame %d at t=%.1f units=%d state=%s" % [_taken, b.time, b.squad.total(), Battle.State.keys()[b.state]])
		_taken += 1
		_armed = false
		RenderingServer.render_loop_enabled = false
	elif _taken < SHOTS.size() and (b.time >= SHOTS[_taken] or b.state != Battle.State.RUNNING):
		_armed = true
		RenderingServer.render_loop_enabled = true
	return _taken >= SHOTS.size() or (b.state != Battle.State.RUNNING and not _armed and _taken > 0)
