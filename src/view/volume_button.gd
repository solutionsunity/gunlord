class_name VolumeButton
extends Button
## The one sound control outside Settings: a speaker that, when tapped, opens
## a vertical volume slider beneath it. The bottom of the slider is silence.
## Tapping the speaker again, or anywhere else, closes it.

signal changed(value: float)

const LENGTH := 240.0

var _panel: PanelContainer
var _slider: Slider
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
	_slider = Ui.slider(_panel, LENGTH, func(v: float) -> void:
		_show_level(v)
		changed.emit(v), true)


func is_open() -> bool:
	return _panel.visible


## Shows a level without sending it back: the icon, and the slider if open.
func set_level(v: float) -> void:
	_slider.set_value_no_signal(v)
	_show_level(v)


func _show_level(v: float) -> void:
	icon = Ui.icon("audioOff" if v <= 0.0 else "audioOn")


func _open(open: bool) -> void:
	_panel.visible = open
	_catcher.visible = open
	if open:
		var r := get_global_rect()
		_catcher.position = Vector2.ZERO
		_catcher.size = get_viewport_rect().size
		_panel.reset_size()
		_panel.global_position = Vector2(r.get_center().x - _panel.size.x / 2.0, r.end.y + 10)
