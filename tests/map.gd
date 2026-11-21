extends SceneTree
## Renders the map with progress part-way along it (build/map.png), then a
## forged boss node fast-forwarded to its warlord fight (build/boss.png).
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 -s tests/map.gd -- [boss node, default 10]

const Bots := preload("res://tools/bots.gd")

var _main: Node
var _node := 9
var _frames := 0
var _stage := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_node = int(args[0]) - 1
	DirAccess.make_dir_recursive_absolute("res://build")
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()   # tests start fresh and never save
	_main._progress.path = ""
	_main._progress.unlocked = 9
	for i in 8:
		_main._progress.best[i] = 40 + i * 3
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	match _stage:
		0:
			if _frames == 4:
				_main._show_menu()   # rebuild the map with the test's progress
			if _frames == 8:
				root.get_texture().get_image().save_png("res://build/map.png")
				print("saved map")
				_main.start_level(_node)
				RenderingServer.render_loop_enabled = false
				_stage = 1
		1:
			# Fast-forward the battle, unrendered, until the warlord is close.
			var b: Battle = _main._battle
			for i in 30:
				Bots.steer(&"sweep", b)
				b.tick(1.0 / 60.0)
				for k in b.lane.size():
					if b.lane.def[k].final and b.lane.z[k] > -16.0:
						_stage = 2
				if _stage == 2 or b.state != Battle.State.RUNNING:
					break
			b.events.clear()
			if _stage == 2 or b.state != Battle.State.RUNNING:
				RenderingServer.render_loop_enabled = true
				_frames = 0
				_stage = 2
		2:
			Bots.steer(&"sweep", _main._battle)
			if _frames == 20:
				root.get_texture().get_image().save_png("res://build/boss.png")
				print("saved boss  state=%s" % Battle.State.keys()[_main._battle.state])
				return true
	return false
