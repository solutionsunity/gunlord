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
	return ProjectSettings.get_setting("application/config/version", "dev")


static func icon(name: String) -> Texture2D:
	return load(KENNEY % name)


## The portrait of a weapon's unit, or the attack-bonus sword ("attack").
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
	_states(b, color, 22, 3)
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
	_states(b, color, int(px * 0.25), 0)
	b.pressed.connect(pressed)
	parent.add_child(b)
	return b


static func _states(b: Button, color: Color, radius: int, border: int) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := color.lightened(0.12) if state == "hover" else (color.darkened(0.15) if state == "pressed" else color)
		var s := box(c, radius, border, Color(1, 1, 1, 0.75) if state != "disabled" else Color(1, 1, 1, 0.2))
		s.content_margin_left = 10
		s.content_margin_right = 10
		if state == "focus":
			s.draw_center = false
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


static func bar(parent: Node, size: Vector2, color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = size
	b.show_percentage = false
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.add_theme_stylebox_override("background", box(Color(INK, 0.7), int(size.y / 2), 2, Color(1, 1, 1, 0.8)))
	b.add_theme_stylebox_override("fill", box(color, int(size.y / 2)))
	parent.add_child(b)
	return b
