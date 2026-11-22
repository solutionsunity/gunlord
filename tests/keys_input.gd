extends SceneTree
## The keyboard, headless, through every screen: Enter on the map starts the
## frontier stage; Escape pauses, and on the pause Escape resumes; arrows and
## Enter work the pause, settings and result buttons; Escape steps back from
## settings and the results.
##   godot --headless --path . -s tests/keys_input.gd     (prints PASS or FAIL lines)

var _main: Node
var _step := 0


func _init() -> void:
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()
	_main._progress.path = ""
	_main._settings = Settings.new()
	_main._settings.path = ""
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_step += 1
	var s: Screens = _main._screens
	match _step:
		5:
			_check("the map opens with the frontier in focus", _focus() == s._frontier, _name())
			_key(KEY_ENTER)
		7:
			_check("Enter on the map starts the stage", _main._mode == _main.Mode.BATTLE and _main._battle.level.index == 0, "")
			_key(KEY_ESCAPE)
		9:
			_check("Escape pauses the battle", _main._mode == _main.Mode.PAUSED, "")
			_check("the pause opens on RESUME", _focus() == s._resume, _name())
			_key(KEY_ESCAPE)
		11:
			_check("Escape on the pause resumes", _main._mode == _main.Mode.BATTLE, "")
			_key(KEY_ESCAPE)
		13:
			_key(KEY_DOWN)
		14:
			_check("arrows move through the pause", _name() == "LEVELS", _name())
			_key(KEY_ENTER)
		16:
			_check("Enter on LEVELS returns to the map", _main._mode == _main.Mode.MENU, "")
			s._open_settings()
		18:
			_check("settings open on the volume slider", _focus() == s._volume, _name())
			_key(KEY_ESCAPE)
		20:
			_check("Escape closes settings back to the map", s._menu.visible and not s._settings.visible, "")
			_check("the map takes the keyboard back", _focus() == s._frontier, _name())
			_main.start_level(0)
			_main._battle.state = Battle.State.WON
			_main._finish()
		22:
			_check("the results open on NEXT", _name() == "NEXT", _name())
			_key(KEY_RIGHT)
		23:
			_check("arrows move through the results", _name() == "REPLAY", _name())
			_key(KEY_ENTER)
		25:
			_check("Enter on REPLAY replays the stage", _main._mode == _main.Mode.BATTLE and _main._battle.level.index == 0, "")
			_main._battle.state = Battle.State.LOST
			_main._finish()
		27:
			_key(KEY_ESCAPE)
		29:
			_check("Escape on the results returns to the map", _main._mode == _main.Mode.MENU, "")
			return true
	return false


func _focus() -> Control:
	return root.gui_get_focus_owner()


func _name() -> String:
	var f := _focus()
	return "nothing" if f == null else (f.text if f is Button and f.text else String(f.name))


func _key(code: Key) -> void:
	for down in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		Input.parse_input_event(e)
		Input.flush_buffered_events()


func _check(what: String, ok: bool, detail: String) -> void:
	print("%s  %s  %s" % ["PASS" if ok else "FAIL", what, ("(" + detail + ")") if detail else ""])
