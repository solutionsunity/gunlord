extends SceneTree
## Renders the map, a battle on each authored node's stage, and the results
## screen, to build/menu.png, build/level_<n>.png and build/result.png.
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 720x1280 --fixed-fps 60 -s tests/screens.gd

var _main: Node
var _step := 0
var _frames := 0


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://build")
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()   # tests start fresh and never save
	_main._progress.path = ""
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	_frames = 0
	if _step == 0:
		_save("menu")
	elif _step <= Stages.AUTHORED.size():
		if _main._battle == null or _main._battle.level.index != _step - 1:
			_main.start_level(_step - 1)
			_frames = -40   # let the first wave walk on screen
			return false
		_save("level_%d" % _step)
	elif _step == Stages.AUTHORED.size() + 1:
		_main._battle.state = Battle.State.WON
		_main._finish()
	else:
		_save("result")
		return true
	_step += 1
	return false


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://build/%s.png" % name)
	print("saved ", name)
