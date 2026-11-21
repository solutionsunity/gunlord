class_name Screens
extends CanvasLayer
## The screens around a battle: the map, the pause overlay and the results.
## They only report choices through signals; the game loop decides.

signal level_chosen(index: int)
signal resume_chosen
signal menu_chosen

const FONT := preload("res://assets/third_party/lilita-one/LilitaOne-Regular.ttf")
const INK := Color(0.07, 0.09, 0.16)
const GOLD := Color("f5c542")
const BLUE := Color("2f6fe0")

const AHEAD := 4             ## locked nodes shown beyond the frontier
const BEHIND := 40           ## finished nodes shown behind it
const ROW := 150.0           ## vertical distance between nodes on the map
const SWAY := 170.0          ## how far the path winds left and right
const STRIP := 720.0         ## the map is drawn in a strip this wide, centred on any screen

var _menu: Control
var _scroll: ScrollContainer
var _path: VBoxContainer
var _pause: Control
var _result: Control
var _result_title: Label
var _result_line: Label
var _result_buttons: HBoxContainer


func _ready() -> void:
	layer = 10
	_menu = _overlay(0.35)
	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scroll.offset_top = 230
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_menu.add_child(_scroll)
	_path = VBoxContainer.new()
	_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_path.add_theme_constant_override("separation", 0)
	_scroll.add_child(_path)
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_top = 40
	_menu.add_child(head)
	_label(head, "GUNLORD", 110, GOLD)
	_label(head, "hold the bridge", 34, Color.WHITE)

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


## The map: a winding line of nodes climbing from the first at the bottom,
## scrolled so the frontier (the first unbeaten node) is in view.
func show_map(progress: Progress) -> void:
	hide_all()
	for child in _path.get_children():
		_path.remove_child(child)
		child.queue_free()
	var frontier := progress.unlocked - 1
	var first := maxi(0, frontier - BEHIND)
	var last := frontier + AHEAD
	var frontier_row: Control
	for node in range(last, first - 1, -1):
		var row := _map_node(node, progress, frontier)
		if node == frontier:
			frontier_row = row
	_menu.visible = true
	await get_tree().process_frame
	if is_instance_valid(frontier_row):
		_scroll.scroll_vertical = int(frontier_row.position.y - _scroll.size.y * 0.55)


func _map_node(node: int, progress: Progress, frontier: int) -> Control:
	var row := Control.new()
	row.custom_minimum_size = Vector2(STRIP, ROW)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_path.add_child(row)
	var x := sin(node * 0.9) * SWAY
	var open := node <= frontier
	var boss := Forge.is_boss(node)
	var spec := Stages.spec(node)
	# The trail down to the previous node.
	if node > 0:
		var below := sin((node - 1) * 0.9) * SWAY
		for k in range(1, 4):
			var dot := ColorRect.new()
			dot.color = Color(1, 1, 1, 0.55 if open else 0.2)
			dot.size = Vector2(12, 12)
			dot.position = Vector2(360 + lerpf(x, below, k / 4.0) - 6, ROW * 0.5 + ROW * k / 4.0 - 6)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(dot)
	var color := GOLD.darkened(0.2) if boss else BLUE
	var b := _button(row, str(node + 1), color if open else Color(INK, 0.75), func() -> void: level_chosen.emit(node))
	b.disabled = not open
	b.custom_minimum_size = Vector2(104, 104)
	b.size = b.custom_minimum_size
	b.position = Vector2(360 + x - 52, ROW * 0.5 - 52)
	if node == frontier:
		var ring := b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		ring.border_color = GOLD
		ring.set_border_width_all(7)
		b.add_theme_stylebox_override("normal", ring)
	var caption: String = spec.name
	if boss:
		caption = "BOSS · " + caption
	if progress.best.has(node):
		caption += "\nbest %d" % progress.best[node]
	var label := _label(row, caption, 26, Color.WHITE if open else Color(1, 1, 1, 0.45))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if x < 0 else HORIZONTAL_ALIGNMENT_RIGHT
	label.size = Vector2(300, 80)
	label.position = Vector2(360 + x + 66, ROW * 0.5 - 30) if x < 0 else Vector2(360 + x - 366, ROW * 0.5 - 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return row


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
