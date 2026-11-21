extends SceneTree
## Map input, headless: a drag that starts on a node scrolls the map and does
## not open the node; a tap opens it; the mouse wheel scrolls.
##   godot --headless --path . -s tests/map_input.gd     (prints PASS or FAIL lines)

var _main: Node
var _chosen := -1
var _step := 0


func _init() -> void:
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()
	_main._progress.path = ""
	_main._progress.unlocked = 20
	_main._settings = Settings.new()
	_main._settings.path = ""
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_step += 1
	var screens: Screens = _main._screens
	match _step:
		3:
			_main._show_menu()
		6:
			screens.level_chosen.disconnect(_main.start_level)
			screens.level_chosen.connect(func(i: int) -> void: _chosen = i)
			var b := _frontier_button(screens)
			var from: float = screens._offset
			var at := b.get_global_rect().get_center()
			_press(at, true)
			for k in 10:
				_move(at + Vector2(0, 12.0 * (k + 1)), Vector2(0, 12))
			_press(at + Vector2(0, 120), false)
			_check("drag scrolls the map", screens._offset != from, "offset %.0f -> %.0f" % [from, screens._offset])
			_check("drag does not open a node", _chosen == -1, "chosen %d" % _chosen)
		8:
			var b := _frontier_button(screens)
			var at := b.get_global_rect().get_center()
			_press(at, true)
			_press(at, false)
		10:
			_check("tap opens the node", _chosen == 19, "chosen %d" % _chosen)
			var from: float = screens._offset
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN   # the drag left the map at its top
			wheel.pressed = true
			wheel.position = _window(screens._window.get_global_rect().get_center())
			Input.parse_input_event(wheel)
			Input.flush_buffered_events()
			_check("wheel scrolls the map", screens._offset != from, "offset %.0f -> %.0f" % [from, screens._offset])
			return true
	return false


func _frontier_button(screens: Screens) -> Button:
	for row in screens._path.get_children():
		for c in row.get_children():
			if c is Button and c.text == "20":
				return c
	return null


## Input arrives in window pixels; the UI lays out in its 720×1280 design space.
func _window(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _press(at: Vector2, down: bool) -> void:
	at = _window(at)
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _move(at: Vector2, rel: Vector2) -> void:
	at = _window(at)
	rel = root.get_final_transform().basis_xform(rel)
	var e := InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  (%s)" % ["PASS" if ok else "FAIL", what, detail])
