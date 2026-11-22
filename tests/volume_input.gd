extends SceneTree
## The volume button, headless, on the map: tapping the speaker opens its
## slider; a tap near the slider's bottom silences everything; a tap elsewhere
## closes it; the speaker toggles it; dragging the slider does not scroll the map;
## the mute button silences and closes, and gives the level back.
##   godot --headless --path . -s tests/volume_input.gd     (prints PASS or FAIL lines)

var _main: Node
var _step := 0
var _heard := 0.0


func _init() -> void:
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()
	_main._progress.path = ""
	_main._settings = Settings.new()
	_main._settings.path = ""
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_step += 1
	var screens: Screens = _main._screens
	var button: VolumeButton = screens._volume_buttons[0] if not screens._volume_buttons.is_empty() else null
	match _step:
		4:
			_tap(button.get_global_rect().get_center())
		6:
			_check("tapping the speaker opens the slider", button._panel.visible, "")
			var r := button._slider.get_global_rect()
			_tap(Vector2(r.get_center().x, r.end.y - 2))
		8:
			_check("a tap at the slider's bottom silences everything", _main._settings.master <= 0.05,
					"master %.2f" % _main._settings.master)
			_check("the speaker shows muted", button.icon == Ui.icon("audioOff"), "")
			_check("the master bus is muted", AudioServer.is_bus_mute(0), "")
			_tap(Vector2(360, 900))
		10:
			_check("a tap elsewhere closes the slider", not button._panel.visible, "")
			_tap(button.get_global_rect().get_center())
		12:
			_tap(button.get_global_rect().get_center())
		14:
			_check("the speaker toggles the slider", not button._panel.visible, "")
			_tap(button.get_global_rect().get_center())
		16:
			var from: float = screens._offset
			var r := button._slider.get_global_rect()
			_drag(Vector2(r.get_center().x, r.end.y - 4), Vector2(0, -160))
			_check("dragging the slider sets the volume", _main._settings.master > 0.5, "master %.2f" % _main._settings.master)
			_check("dragging the slider does not scroll the map", screens._offset == from, "offset %.0f -> %.0f" % [from, screens._offset])
			_heard = _main._settings.master
			_tap(button._mute.get_global_rect().get_center())
		18:
			_check("mute silences", _main._settings.master == 0.0 and AudioServer.is_bus_mute(0), "master %.2f" % _main._settings.master)
			_check("mute closes the slider", not button._panel.visible, "")
			_tap(button.get_global_rect().get_center())
		20:
			_tap(button._mute.get_global_rect().get_center())
		22:
			_check("unmute gives the level back", is_equal_approx(_main._settings.master, _heard),
					"%.2f, was %.2f" % [_main._settings.master, _heard])
			return true
	return false


## Input arrives in window pixels; the UI lays out in its 720x1280 design space.
func _tap(at: Vector2) -> void:
	at = root.get_final_transform() * at
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = at
		e.global_position = at
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _drag(from: Vector2, by: Vector2) -> void:
	var t := root.get_final_transform()
	var steps := 8
	_button(t * from, true)
	for k in steps:
		var e := InputEventMouseMotion.new()
		e.position = t * (from + by * (k + 1) / steps)
		e.global_position = e.position
		e.relative = t.basis_xform(by / steps)
		e.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(e)
		Input.flush_buffered_events()
	_button(t * (from + by), false)


func _button(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", what, ("(" + detail + ")") if detail else ""])
