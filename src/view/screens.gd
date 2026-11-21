class_name Screens
extends CanvasLayer
## The screens around a battle: the map, the pause overlay, the settings and
## the results. They only report choices through signals; the game loop decides.

signal level_chosen(index: int)
signal resume_chosen
signal menu_chosen
signal mute_pressed
signal setting_changed(key: StringName, value: Variant)   ## a Settings field and its new value
signal reset_chosen
signal update_chosen

const AHEAD := 4             ## locked nodes shown beyond the frontier
const BEHIND := 40           ## finished nodes shown behind it
const ROW := 150.0           ## vertical distance between nodes on the map
const SWAY := 170.0          ## how far the path winds left and right
const STRIP := 720.0         ## the map is drawn in a strip this wide, centred on any screen
const DRAG := 14.0           ## pixels a press may travel and still count as a tap
const WHEEL := 90.0          ## pixels one mouse-wheel notch scrolls
const BUTTON := 72.0

var _menu: Control
var _window: Control         ## the map's visible area; the path scrolls inside it
var _path: VBoxContainer
var _offset := 0.0           ## how far the path is scrolled, 0 = its top at the window's top
var _drag_from := 0.0
var _dragging := false
var _dragged := false        ## this press became a scroll: the button it started on must not fire
var _pause: Control
var _settings: Control
var _settings_back: Control  ## the overlay the settings return to
var _volume: HSlider
var _music: HSlider
var _sound: HSlider
var _badges: Button
var _badge_side: StringName = &"right"
var _master_sliders: Array[HSlider] = []
var _reset: Button
var _armed := false          ## reset asks twice
var _mute_buttons: Array[Button] = []
var _update: Button         ## on the map, when a newer build is out
var _result: Control
var _result_title: Label
var _result_line: Label
var _result_buttons: HBoxContainer


func _ready() -> void:
	layer = 10
	_build_map()
	_build_pause()
	_build_settings()
	_build_result()
	hide_all()


## ---- map --------------------------------------------------------------

func _build_map() -> void:
	_menu = _overlay(0.35)
	_window = Control.new()
	_window.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window.offset_top = 290
	_window.clip_contents = true
	_window.mouse_filter = Control.MOUSE_FILTER_PASS
	_menu.add_child(_window)
	_path = VBoxContainer.new()
	_path.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_path.add_theme_constant_override("separation", 0)
	_path.mouse_filter = Control.MOUSE_FILTER_PASS
	_window.add_child(_path)
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	head.offset_top = 100   # below the corner buttons, which sit at the top on narrow phones
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(head)
	Ui.label(head, "GUNLORD", 110, Ui.GOLD)
	Ui.label(head, "hold the bridge", 34, Color.WHITE)
	var corner := HBoxContainer.new()
	corner.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	corner.offset_top = 20
	corner.offset_right = -20
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.add_theme_constant_override("separation", 10)
	_menu.add_child(corner)
	_controls(corner)
	_update = Ui.button(_menu, "", Ui.GOLD.darkened(0.15), func() -> void: update_chosen.emit())
	_update.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_update.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_update.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_update.offset_bottom = -54
	_update.custom_minimum_size = Vector2(560, 84)
	_update.add_theme_font_size_override("font_size", 30)
	_update.visible = false
	var version := Ui.label(_menu, "v" + Ui.version(), 22, Color(1, 1, 1, 0.6))
	version.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	version.offset_left = 16
	version.offset_bottom = -10
	version.grow_vertical = Control.GROW_DIRECTION_BEGIN


## A newer build is out: the map offers to load it.
func show_update(version: String) -> void:
	_update.text = "NEW VERSION %s · TAP TO UPDATE" % version
	_update.visible = true


## The map: a winding line of nodes climbing from the first at the bottom,
## scrolled so the frontier (the first unbeaten node) is in view.
func show_map(progress: Progress) -> void:
	hide_all()
	_menu.visible = true
	refresh_map(progress)


## Rebuilds the map's nodes, wherever it is showing or not (e.g. after a reset).
func refresh_map(progress: Progress) -> void:
	for child in _path.get_children():
		_path.remove_child(child)
		child.queue_free()
	var frontier := progress.unlocked - 1
	var first := maxi(0, frontier - BEHIND)
	var last := frontier + AHEAD
	for node in range(last, first - 1, -1):
		_map_node(node, progress, frontier)
	await get_tree().process_frame
	_offset = -((last - frontier) * ROW + ROW * 0.5 - _window.size.y * 0.55)
	_scroll_by(0.0)


func _map_node(node: int, progress: Progress, frontier: int) -> void:
	var row := Control.new()
	row.custom_minimum_size = Vector2(STRIP, ROW)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
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
			dot.position = Vector2(STRIP / 2 + lerpf(x, below, k / 4.0) - 6, ROW * 0.5 + ROW * k / 4.0 - 6)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(dot)
	var color := Ui.GOLD.darkened(0.2) if boss else Ui.BLUE
	var b := Ui.button(row, str(node + 1), color if open else Color(Ui.INK, 0.75), func() -> void:
		if not _dragged:
			level_chosen.emit(node))
	b.disabled = not open
	b.mouse_filter = Control.MOUSE_FILTER_PASS
	b.custom_minimum_size = Vector2(104, 104)
	b.size = b.custom_minimum_size
	b.position = Vector2(STRIP / 2 + x - 52, ROW * 0.5 - 52)
	if node == frontier:
		var ring := b.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		ring.border_color = Ui.GOLD
		ring.set_border_width_all(7)
		b.add_theme_stylebox_override("normal", ring)
	var caption: String = spec.name
	if boss:
		caption = "BOSS · " + caption
	if progress.best.has(node):
		caption += "\nbest %d" % progress.best[node]
	var label := Ui.label(row, caption, 26, Color.WHITE if open else Color(1, 1, 1, 0.45))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if x < 0 else HORIZONTAL_ALIGNMENT_RIGHT
	label.size = Vector2(300, 80)
	label.position = Vector2(STRIP / 2 + x + 66, ROW * 0.5 - 30) if x < 0 else Vector2(STRIP / 2 + x - 366, ROW * 0.5 - 30)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Dragging (finger or mouse) and the mouse wheel scroll the map. Read here,
## before the buttons see the input, so a drag that starts on a node scrolls
## instead of choosing it. Touch reaches this as emulated mouse input.
func _input(event: InputEvent) -> void:
	if not _menu.visible:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_dragging = _window.get_global_rect().has_point(event.position)
					_dragged = false
					_drag_from = event.position.y
				else:
					_dragging = false
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_scroll_by(WHEEL)
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_scroll_by(-WHEEL)
	elif event is InputEventMouseMotion and _dragging:
		if not _dragged and absf(event.position.y - _drag_from) > DRAG:
			_dragged = true
		if _dragged:
			_scroll_by(event.relative.y)


func _scroll_by(dy: float) -> void:
	var height := _path.get_combined_minimum_size().y
	var lowest := minf(0.0, _window.size.y - height)
	_offset = clampf(_offset + dy, lowest, 0.0)
	_path.offset_top = _offset
	_path.offset_bottom = _offset + height


## ---- pause and settings ------------------------------------------------

func _build_pause() -> void:
	_pause = _overlay(0.55)
	var p := _column(_pause)
	Ui.label(p, "PAUSED", 80, Color.WHITE)
	_space(p, 20)
	Ui.button(p, "RESUME", Ui.BLUE, func() -> void: resume_chosen.emit())
	Ui.button(p, "LEVELS", Color(Ui.INK, 0.9), func() -> void: menu_chosen.emit())
	_space(p, 10)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	p.add_child(row)
	_controls(row)


## Mute, overall volume and the settings gear, as on the map and the pause overlay.
func _controls(parent: Control) -> void:
	_mute_buttons.append(Ui.icon_button(parent, "audioOn", BUTTON, Color(Ui.INK, 0.7), func() -> void: mute_pressed.emit()))
	_master_sliders.append(Ui.slider(parent, 170.0, func(v: float) -> void: setting_changed.emit(&"master", v)))
	Ui.icon_button(parent, "gear", BUTTON, Color(Ui.INK, 0.7), func() -> void: _open_settings())


func _build_settings() -> void:
	_settings = _overlay(0.7)
	var c := _column(_settings)
	Ui.label(c, "SETTINGS", 72, Color.WHITE)
	_space(c, 16)
	_volume = _level(c, "audioOn", "VOLUME", &"master")
	_music = _level(c, "musicOn", "MUSIC", &"music")
	_sound = _level(c, "target", "EFFECTS", &"sound")
	_space(c, 12)
	_badges = Ui.button(c, "", Ui.BLUE, func() -> void:
		setting_changed.emit(&"badges", &"left" if _badge_side == &"right" else &"right"))
	_badges.custom_minimum_size = Vector2(460, 88)
	_space(c, 16)
	_reset = Ui.button(c, "", Color("8a2a2a"), func() -> void: _reset_pressed())
	_reset.custom_minimum_size = Vector2(460, 88)
	_space(c, 16)
	Ui.button(c, "BACK", Color(Ui.INK, 0.9), func() -> void: _close_settings())
	_space(c, 12)
	Ui.label(c, "Gunlord v" + Ui.version(), 24, Color(1, 1, 1, 0.6))


## One volume row: an icon, a name, a slider bound to a Settings field.
func _level(parent: Control, icon: String, name: String, key: StringName) -> HSlider:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	var pic := TextureRect.new()
	pic.texture = Ui.icon(icon)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.custom_minimum_size = Vector2(44, 44)
	pic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pic)
	var l := Ui.label(row, name, 34, Color.WHITE)
	l.custom_minimum_size = Vector2(150, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	return Ui.slider(row, 250.0, func(v: float) -> void: setting_changed.emit(key, v))


## Shows the current settings everywhere they appear, without re-sending them.
func show_settings(settings: Settings) -> void:
	for b in _mute_buttons:
		b.icon = Ui.icon("audioOff" if settings.silent() else "audioOn")
	for s in _master_sliders + [_volume]:
		s.set_value_no_signal(settings.master)
	_music.set_value_no_signal(settings.music)
	_sound.set_value_no_signal(settings.sound)
	_badge_side = settings.badges
	_badges.text = "BADGES ON THE %s" % String(settings.badges).to_upper()


func _open_settings() -> void:
	_settings_back = _pause if _pause.visible else _menu
	_settings_back.visible = false
	_armed = false
	_reset.text = "RESET PROGRESS"
	_settings.visible = true


func _close_settings() -> void:
	_settings.visible = false
	_settings_back.visible = true


func _reset_pressed() -> void:
	if not _armed:
		_armed = true
		_reset.text = "TAP AGAIN TO RESET"
		return
	_armed = false
	_reset.text = "PROGRESS RESET"
	reset_chosen.emit()


func show_pause() -> void:
	hide_all()
	_pause.visible = true


## ---- results -----------------------------------------------------------

func _build_result() -> void:
	_result = _overlay(0.55)
	var r := _column(_result)
	_result_title = Ui.label(r, "", 96, Ui.GOLD)
	_result_line = Ui.label(r, "", 36, Color.WHITE)
	_space(r, 24)
	_result_buttons = HBoxContainer.new()
	_result_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_buttons.add_theme_constant_override("separation", 16)
	r.add_child(_result_buttons)


## The battle's outcome, with the choices that follow it.
func show_result(won: bool, line: String, index: int, has_next: bool) -> void:
	hide_all()
	_result_title.text = "VICTORY" if won else "DEFEAT"
	_result_title.add_theme_color_override("font_color", Ui.GOLD if won else Color("ff8a7a"))
	_result_line.text = line
	for child in _result_buttons.get_children():
		child.queue_free()
	if won and has_next:
		Ui.button(_result_buttons, "NEXT", Ui.BLUE, func() -> void: level_chosen.emit(index + 1))
	Ui.button(_result_buttons, "REPLAY" if won else "RETRY", Ui.BLUE if not won else Color(Ui.INK, 0.9),
			func() -> void: level_chosen.emit(index))
	Ui.button(_result_buttons, "LEVELS", Color(Ui.INK, 0.9), func() -> void: menu_chosen.emit())
	_result.visible = true


func hide_all() -> void:
	_menu.visible = false
	_pause.visible = false
	_settings.visible = false
	_result.visible = false


func _overlay(dim: float) -> Control:
	var bg := ColorRect.new()
	bg.color = Color(Ui.INK, dim)
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


func _space(parent: Control, height: float) -> void:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	parent.add_child(c)
