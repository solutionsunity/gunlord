class_name VolumeButton
extends Button
## The one sound control outside Settings: a speaker that, when tapped, opens
## a vertical volume slider beneath it, topped by a mute button. The bottom of
## the slider is silence. Tapped while silent, the mute button gives back the
## last level heard. Tapping the speaker again, or anywhere else, or Escape,
## closes it. From the keyboard, the slider takes focus as it opens.

signal changed(value: float)

const LENGTH := 240.0
const MUTE := 56.0


var _panel: PanelContainer
var _slider: Slider
var _mute: Button
var _before := 1.0         ## the last level above silence, which unmute gives back
var _catcher: Control      ## covers the screen while open; a tap on it closes the slider


func _init(px: float, color: Color) -> void:
	icon = Ui.icon("audioOn")
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	custom_minimum_size = Vector2(px, px)
	add_theme_constant_override("icon_max_width", int(px * 0.62))
	Ui.states(self, color, int(px * 0.25), 0)
	pressed.connect(func() -> void: _open(not _panel.visible))

	_catcher = Control.new()
	_catcher.top_level = true
	_catcher.visible = false
	_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_catcher.z_index = 99      # above the rest of the screen while open
	_catcher.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed:
			_open(false))
	add_child(_catcher)

	_panel = PanelContainer.new()
	_panel.top_level = true
	_panel.visible = false
	_panel.z_index = 100
	var s := Ui.box(Color(Ui.INK, 0.88), 18, 2, Color(1, 1, 1, 0.5))
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	_panel.add_theme_stylebox_override("panel", s)
	add_child(_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_panel.add_child(column)
	_mute = Ui.icon_button(column, "audioOn", MUTE, Ui.INK.lightened(0.2), _toggle_mute)
	_mute.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_slider = Ui.slider(column, LENGTH, _choose, true)
	_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed(&"ui_cancel"):
		_open(false)
		get_viewport().set_input_as_handled()


func is_open() -> bool:
	return _panel.visible


## Shows a level without sending it back: the icon, and the slider if open.
func set_level(v: float) -> void:
	_slider.set_value_no_signal(v)
	_show_level(v)


func _choose(v: float) -> void:
	_show_level(v)
	changed.emit(v)


## Silences, or gives back the level silenced, and closes: two taps from the speaker.
func _toggle_mute() -> void:
	_slider.set_value_no_signal(0.0 if _slider.value > 0.0 else _before)
	_choose(_slider.value)
	_open(false)


## The speaker shows the state; the mute button shows what it will do. Silence
## is always the struck-through speaker, so it reads at a glance.
func _show_level(v: float) -> void:
	if v > 0.0:
		_before = v
	var muted := Ui.unit_icon(&"mute")
	var sounding := Ui.icon("audioOn")
	icon = muted if v <= 0.0 else sounding
	_mute.icon = sounding if v <= 0.0 else muted


func _open(open: bool) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if not open and focused and _panel.is_ancestor_of(focused):
		grab_focus()   # the keyboard returns to the speaker
	_panel.visible = open
	_catcher.visible = open
	if open:
		var r := get_global_rect()
		_catcher.position = Vector2.ZERO
		_catcher.size = get_viewport_rect().size
		_panel.reset_size()
		_panel.global_position = Vector2(r.get_center().x - _panel.size.x / 2.0, r.end.y + 10)
		if has_focus(true):   # opened from the keyboard: up and down set the level
			_slider.grab_focus()
