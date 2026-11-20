class_name Screens
extends CanvasLayer
## The screens around a battle: the level menu, the pause overlay and the
## results. They only report choices through signals; the game loop decides.

signal level_chosen(index: int)
signal resume_chosen
signal menu_chosen

const FONT := preload("res://assets/third_party/lilita-one/LilitaOne-Regular.ttf")
const INK := Color(0.07, 0.09, 0.16)
const GOLD := Color("f5c542")
const BLUE := Color("2f6fe0")

var _menu: Control
var _levels: VBoxContainer
var _pause: Control
var _result: Control
var _result_title: Label
var _result_line: Label
var _result_buttons: HBoxContainer


func _ready() -> void:
	layer = 10
	_menu = _overlay(0.35)
	var col := _column(_menu)
	_label(col, "GUNLORD", 110, GOLD)
	_label(col, "hold the bridge", 34, Color.WHITE)
	_space(col, 30)
	_levels = VBoxContainer.new()
	_levels.add_theme_constant_override("separation", 14)
	col.add_child(_levels)

	_pause = _overlay(0.55)
	var p := _column(_pause)
	_label(p, "PAUSED", 80, Color.WHITE)
	_space(p, 20)
	_button(p, "RESUME", BLUE, func() -> void: resume_chosen.emit())
	_button(p, "LEVELS", Color(INK, 0.9), func() -> void: menu_chosen.emit())

	_result = _overlay(0.55)
	var r := _column(_result)
	_result_title = _label(r, "", 96, GOLD)
	_result_line = _label(r, "", 36, Color.WHITE)
	_space(r, 24)
	_result_buttons = HBoxContainer.new()
	_result_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_buttons.add_theme_constant_override("separation", 16)
	r.add_child(_result_buttons)
	hide_all()


func show_menu(progress: Progress, names: Array[String]) -> void:
	hide_all()
	for child in _levels.get_children():
		child.queue_free()
	for i in names.size():
		var open := i < progress.unlocked
		var done := progress.best.has(i)
		var text := "%d  %s" % [i + 1, names[i]]
		if done:
			text += "   best %d" % progress.best[i]
		elif not open:
			text += "   locked"
		var b := _button(_levels, text, BLUE if open else Color(INK, 0.7), func() -> void: level_chosen.emit(i))
		b.disabled = not open
		b.custom_minimum_size = Vector2(560, 92)
	_menu.visible = true


func show_pause() -> void:
	hide_all()
	_pause.visible = true


## The battle's outcome, with the choices that follow it.
func show_result(won: bool, line: String, index: int, has_next: bool) -> void:
	hide_all()
	_result_title.text = "VICTORY" if won else "DEFEAT"
	_result_title.add_theme_color_override("font_color", GOLD if won else Color("ff8a7a"))
	_result_line.text = line
	for child in _result_buttons.get_children():
		child.queue_free()
	if won and has_next:
		_button(_result_buttons, "NEXT", BLUE, func() -> void: level_chosen.emit(index + 1))
	_button(_result_buttons, "REPLAY" if won else "RETRY", BLUE if not won else Color(INK, 0.9),
			func() -> void: level_chosen.emit(index))
	_button(_result_buttons, "LEVELS", Color(INK, 0.9), func() -> void: menu_chosen.emit())
	_result.visible = true


func hide_all() -> void:
	_menu.visible = false
	_pause.visible = false
	_result.visible = false


func _overlay(dim: float) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(INK, dim)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	return bg


func _column(parent: Control) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(col)
	return col


func _label(parent: Control, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 14)
	l.add_theme_color_override("font_outline_color", INK)
	parent.add_child(l)
	return l


func _space(parent: Control, height: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	parent.add_child(c)


func _button(parent: Control, text: String, color: Color, pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(220, 88)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", 38)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_constant_override("outline_size", 8)
	b.add_theme_color_override("font_outline_color", INK)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = color.lightened(0.12) if state == "hover" else (color.darkened(0.15) if state == "pressed" else color)
		box.set_corner_radius_all(22)
		box.set_border_width_all(3)
		box.border_color = Color(1, 1, 1, 0.75) if state != "disabled" else Color(1, 1, 1, 0.2)
		if state == "focus":
			box.draw_center = false
		b.add_theme_stylebox_override(state, box)
	b.pressed.connect(pressed)
	parent.add_child(b)
	return b
