extends Node3D
## The game loop: owns the flow between the map, a battle, the pause overlay
## and the results, and wires the battle to its view, HUD, sound and
## the player's input. Drag (finger or mouse) or the arrow keys steer the squad.

enum Mode { MENU, BATTLE, PAUSED, RESULT }

const DRAG_GAIN := 0.022    ## metres of steering per pixel dragged
const KEY_SPEED := 14.0     ## metres per second when steering with keys
const RESULT_DELAY := 1.6   ## seconds the decided battle plays on before the results show

var _mode := Mode.MENU
var _battle: Battle
var _progress := Progress.load_saved()
var _settings := Settings.load_saved()
var _view := View.new()
var _hud := Hud.new()
var _sound := Sound.new()
var _screens := Screens.new()
var _updates := Updates.new()
var _since_end := 0.0
var _attempts := {}         ## node -> attempts this session; each retry varies the stage fairly
var _sim_usec := 0          ## the simulation's time since the last drawn frame, for the readout
var _on_visibility: JavaScriptObject   ## the page's visibility callback, held so it stays alive


func _ready() -> void:
	_settings.apply()   # before the sound starts: it creates the audio buses
	add_child(_view)
	add_child(_hud)
	add_child(_sound)
	add_child(_screens)
	add_child(_updates)
	var models: Array[StringName] = []
	for w in Content.weapons():
		models.append(w.model)
	for d in Content.objects().values():
		models.append(d.model)
	_view.prepare(models)
	_screens.level_chosen.connect(start_level)
	_screens.menu_chosen.connect(_show_menu)
	_screens.resume_chosen.connect(_resume)
	_hud.pause_pressed.connect(_pause)
	_hud.master_changed.connect(func(v: float) -> void: _change_setting(&"master", v))
	_screens.setting_changed.connect(_change_setting)
	_screens.reset_chosen.connect(_reset_progress)
	_screens.update_chosen.connect(_updates.reload)
	_updates.available.connect(_screens.show_update)
	_show_settings()
	_show_menu()
	# A browser keeps playing a hidden page's audio and never tells the engine
	# the page was hidden, so the page is asked; native builds are told (below).
	if OS.has_feature("web"):
		_on_visibility = JavaScriptBridge.create_callback(func(_args: Array) -> void:
			_set_away(JavaScriptBridge.eval("document.hidden")))
		JavaScriptBridge.get_interface("document").addEventListener("visibilitychange", _on_visibility)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			_set_away(true)
		NOTIFICATION_APPLICATION_RESUMED:
			_set_away(false)


## Leaving the game (minimised, or another app or tab in front) pauses a
## battle and silences everything. Coming back restores the sound as the
## settings have it; a battle waits on its pause screen.
func _set_away(away: bool) -> void:
	if away:
		_pause()
		AudioServer.set_bus_mute(0, true)
	else:
		_settings.apply()


func start_level(index: int) -> void:
	_sound.play(&"click")
	_attempts[index] = _attempts.get(index, -1) + 1
	var level := Stages.build(index, _attempts[index])
	_battle = Battle.new(Content.weapons(), Content.objects(), level)
	_view.reset()
	_view.stage.apply_theme(level.theme)
	_view.stage.apply_walls(level.walls)
	_screens.hide_all()
	_hud.visible = true
	_since_end = 0.0
	_mode = Mode.BATTLE
	_sound.play(&"start")
	_sound.music(&"battle")
	_hud.announce("%d · %s" % [index + 1, level.name])
	_hud.show_relics(level.loadout)


func _show_menu() -> void:
	_sound.play(&"click")
	_sound.music(&"map")
	_battle = null
	_view.reset()
	_hud.visible = false
	_mode = Mode.MENU
	_screens.show_map(_progress)
	_updates.check()   # the map is the moment to offer a newer build, never mid-battle


func _change_setting(key: StringName, value: Variant) -> void:
	_settings.set(key, value)
	_settings.save()
	_show_settings()


func _show_settings() -> void:
	_view.stage.apply_graphics(_settings.graphics == &"full")
	_hud.show_settings(_settings)
	_screens.show_settings(_settings)


func _reset_progress() -> void:
	_progress.reset()
	_screens.refresh_map(_progress)


func _pause() -> void:
	if _mode != Mode.BATTLE:
		return
	_sound.play(&"click")
	_mode = Mode.PAUSED
	_screens.show_pause()


func _resume() -> void:
	_sound.play(&"click")
	_mode = Mode.BATTLE
	_screens.hide_all()


func _physics_process(delta: float) -> void:
	if _mode != Mode.BATTLE:
		return
	_battle.squad.steer(Input.get_axis(&"ui_left", &"ui_right") * KEY_SPEED * delta)
	if _view.freeze > 0.0:
		_view.freeze -= delta   # hit-stop: the battle holds still for a beat
		return
	var began := Time.get_ticks_usec()
	_battle.tick(delta)
	_sim_usec += Time.get_ticks_usec() - began


func _process(delta: float) -> void:
	if _battle == null or _mode == Mode.PAUSED:
		return
	var began := Time.get_ticks_usec()
	_view.draw(_battle, delta)
	_sound.hear(_battle)
	_battle.events.clear()
	_hud.draw(_battle)
	_hud.draw_stats(_view, _sim_usec, Time.get_ticks_usec() - began)
	_sim_usec = 0
	if _mode == Mode.BATTLE and _battle.state != Battle.State.RUNNING:
		_since_end += delta
		if _since_end >= RESULT_DELAY:
			_finish()


func _finish() -> void:
	_mode = Mode.RESULT
	var won := _battle.state == Battle.State.WON
	var index := _battle.level.index
	if won:
		_progress.record_victory(index, _battle.squad.total())
	var line := "%d · %s\n" % [index + 1, _battle.level.name]
	line += "%d of %d standing" % [_battle.squad.total(), _battle.level.capacity] if won \
			else "fell at wave %d of %d" % [_battle.wave, _battle.waves]
	var relic := Relics.earned(index)
	if won and not relic.is_empty():
		line += "\nRELIC: %s %s" % [Relics.LABELS[relic[0]], Relics.NUMERALS[relic[1]]]
	_screens.show_result(won, line, index, true)


func _unhandled_input(event: InputEvent) -> void:
	if _mode != Mode.BATTLE:
		return
	if event.is_action_pressed(&"ui_cancel"):   # Escape, or Android's back
		_pause()
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_battle.squad.steer(event.relative.x * DRAG_GAIN)
