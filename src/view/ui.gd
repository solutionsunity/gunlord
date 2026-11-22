class_name Ui
extends RefCounted
## The game's interface style, in one place: font, palette, and the builders
## for labels, buttons, icon buttons, chips and bars that the HUD and the
## screens share.

const FONT := preload("res://assets/third_party/lilita-one/LilitaOne-Regular.ttf")
const INK := Color(0.07, 0.09, 0.16)
const GOLD := Color("f5c542")
const BLUE := Color("2f6fe0")
const SKY := Color("4d8df7")
const KENNEY := "res://assets/third_party/kenney-game-icons/%s.png"
const UNIT_ICON := "res://assets/art/icons/%s.png"


## The game's version: the build writes it into the project from its git
## tag (see .github/workflows/build.yml); a local run says "dev".
static func version() -> String:
	var v: String = ProjectSettings.get_setting("application/config/version", "")
	return v if not v.is_empty() else "dev"   # Godot declares the setting, empty, in every project


static func icon(name: String) -> Texture2D:
	return load(KENNEY % name)


## One of our own icons (tools/render_art.gd): a weapon's unit portrait, the
## attack-bonus sword ("attack"), a surge's or relic's glyph, or "mute".
static func unit_icon(id: StringName) -> Texture2D:
	return load(UNIT_ICON % id)


static func style(l: Label, size: int, color: Color, outline := 10) -> void:
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", INK)


static func label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	style(l, size, color, 14 if size >= 60 else 10)
	parent.add_child(l)
	return l


static func box(color: Color, radius: int, border := 0, border_color := Color.WHITE) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_border_width_all(border)
	b.border_color = border_color
	return b


## A labelled button in a colour, with hover, press and disabled states.
static func button(parent: Node, text: String, color: Color, pressed: Callable) -> Button:
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
	states(b, color, 22, 3)
	b.pressed.connect(pressed)
	parent.add_child(b)
	return b


## A square button showing one of Kenney's icons.
static func icon_button(parent: Node, icon_name: String, px: float, color: Color, pressed: Callable) -> Button:
	var b := Button.new()
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(px, px)
	b.add_theme_constant_override("icon_max_width", int(px * 0.62))
	states(b, color, int(px * 0.25), 0)
	b.pressed.connect(pressed)
	parent.add_child(b)
	return b


static func states(b: Button, color: Color, radius: int, border: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := color.lightened(0.12) if state == "hover" else (color.darkened(0.15) if state == "pressed" else color)
		var s := box(c, radius, border, Color(1, 1, 1, 0.75) if state != "disabled" else Color(1, 1, 1, 0.2))
		s.content_margin_left = 10
		s.content_margin_right = 10
		if state == "focus":   # keyboard only: pointer presses leave no ring
			s.draw_center = false
			s.set_border_width_all(5)
			s.border_color = GOLD
			s.set_expand_margin_all(4)
		b.add_theme_stylebox_override(state, s)


## A rounded panel holding an icon and a number: the HUD's weapon badges.
static func icon_chip(parent: Node, texture: Texture2D, icon_px: float, size: int) -> HBoxContainer:
	var panel := PanelContainer.new()
	var s := box(Color(INK, 0.6), 16)
	s.content_margin_left = 6
	s.content_margin_right = 14
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", s)
	parent.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	panel.add_child(row)
	var pic := TextureRect.new()
	pic.texture = texture
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pic.custom_minimum_size = Vector2(icon_px, icon_px)
	row.add_child(pic)
	var l := Label.new()
	style(l, size, Color.WHITE)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return row


## A volume slider, 0..1: gold fill on a dark track, a round thumb-sized grabber.
## `changed` receives the new value as the player drags. Vertical sliders fill
## from the bottom, so the bottom is silence.
static func slider(parent: Node, length: float, changed: Callable, vertical := false) -> Slider:
	var sl: Slider = VSlider.new() if vertical else HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.custom_minimum_size = Vector2(48, length) if vertical else Vector2(length, 48)
	if not vertical:
		sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var track := box(Color(INK, 0.75), 8, 2, Color(1, 1, 1, 0.6))
	if vertical:
		track.content_margin_left = 8
		track.content_margin_right = 8
	else:
		track.content_margin_top = 8
		track.content_margin_bottom = 8
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", box(GOLD, 8))
	sl.add_theme_stylebox_override("grabber_area_highlight", box(GOLD.lightened(0.2), 8))
	sl.add_theme_icon_override("grabber", _knob(34, Color.WHITE))
	sl.add_theme_icon_override("grabber_highlight", _knob(34, GOLD.lightened(0.5)))
	sl.value_changed.connect(changed)
	parent.add_child(sl)
	return sl


static var _knobs := {}


## A filled circle with a dark rim, drawn once per size and colour.
static func _knob(px: int, color: Color) -> Texture2D:
	var key := "%d %s" % [px, color]
	if _knobs.has(key):
		return _knobs[key]
	var img := Image.create_empty(px, px, false, Image.FORMAT_RGBA8)
	var r := px / 2.0
	for y in px:
		for x in px:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			var a := clampf(r - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(INK if d > r - 3.0 else color, a))
	_knobs[key] = ImageTexture.create_from_image(img)
	return _knobs[key]


static func bar(parent: Node, size: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("background", box(Color(INK, 0.7), int(size.y / 2), 2, Color(1, 1, 1, 0.8)))
	b.add_theme_stylebox_override("fill", box(color, int(size.y / 2)))
	parent.add_child(b)
	return b
