class_name Hud
extends CanvasLayer
## Timer and wave chips, squad size with its capacity bar, the weapon mix,
## the nearest boss's health bar, and the end-of-run banner.

const FONT := preload("res://assets/third_party/lilita-one/LilitaOne-Regular.ttf")
const INK := Color(0.07, 0.09, 0.16)
const BOSS_RANGE := -40.0           ## a boss's bar shows once it is this close

var _clock: Label
var _wave: Label
var _units: Label
var _fill: ProgressBar
var _mix: HBoxContainer
var _boss: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _banner: Label


func _ready() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 20
	add_child(top)
	_clock = _chip(top, 36)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_wave = _chip(top, 36)

	var squad := VBoxContainer.new()
	squad.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	squad.offset_top = 86
	squad.grow_horizontal = Control.GROW_DIRECTION_BOTH
	squad.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(squad)
	_units = _text(squad, 64, Color.WHITE)
	_fill = _bar(squad, Vector2(220, 14), Color("4d8df7"))

	_boss = VBoxContainer.new()
	_boss.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss.offset_top = 200
	_boss.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_boss)
	_boss_name = _text(_boss, 30, Color("ffd0c8"))
	_boss_bar = _bar(_boss, Vector2(420, 22), Color("d8423a"))

	_mix = HBoxContainer.new()
	_mix.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_mix.offset_bottom = -36
	_mix.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_mix.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_mix.add_theme_constant_override("separation", 10)
	add_child(_mix)

	_banner = Label.new()
	_style(_banner, 76, Color.WHITE)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(_banner)


func draw(b: Battle) -> void:
	var left := maxf(Battle.DURATION - b.time, 0.0)
	_clock.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	_wave.text = "WAVE %d/%d" % [b.wave, b.waves]
	var total := b.squad.total()
	_units.text = "%d" % total
	_fill.max_value = b.squad.capacity
	_fill.value = total
	(_fill.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("f5c542") if total >= b.squad.capacity else Color("4d8df7")
	_draw_mix(b.squad)
	_draw_boss(b.lane)
	match b.state:
		Battle.State.WON:
			_banner.text = "VICTORY\npeak %d\ntap to replay" % b.peak_units
		Battle.State.LOST:
			_banner.text = "DEFEAT\nwave %d\ntap to retry" % b.wave
		_:
			_banner.text = ""


func _draw_mix(squad: Squad) -> void:
	var shown := 0
	for w in squad.weapons.size():
		if squad.counts[w] == 0:
			continue
		var chip: Label
		if shown < _mix.get_child_count():
			chip = _mix.get_child(shown)
		else:
			chip = _chip(_mix, 26)
		var wd := squad.weapons[w]
		chip.text = "%s %d" % [wd.label, squad.counts[w]]
		(chip.get_theme_stylebox("normal") as StyleBoxFlat).bg_color = Color(wd.color.darkened(0.35), 0.85)
		chip.visible = true
		shown += 1
	for i in range(shown, _mix.get_child_count()):
		_mix.get_child(i).visible = false


## The nearest boss on the lane, once it comes within range.
func _draw_boss(lane: Lane) -> void:
	var best := -1
	for i in lane.size():
		if lane.alive[i] and lane.def[i].persistent and lane.z[i] > BOSS_RANGE:
			if best < 0 or lane.z[i] > lane.z[best]:
				best = i
	_boss.visible = best >= 0
	if best < 0:
		return
	_boss_name.text = String(lane.def[best].id).to_upper()
	_boss_bar.max_value = lane.max_hp[best]
	_boss_bar.value = lane.hp[best]


func _chip(parent: Control, size: int) -> Label:
	var l := Label.new()
	_style(l, size, Color.WHITE)
	var box := StyleBoxFlat.new()
	box.bg_color = Color(INK, 0.6)
	box.set_corner_radius_all(14)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", box)
	parent.add_child(l)
	return l


func _text(parent: Control, size: int, color: Color) -> Label:
	var l := Label.new()
	_style(l, size, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


func _bar(parent: Control, size: Vector2, color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(INK, 0.7)
	bg.set_corner_radius_all(int(size.y / 2))
	bg.set_border_width_all(2)
	bg.border_color = Color(1, 1, 1, 0.8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(int(size.y / 2))
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _style(l: Label, size: int, color: Color) -> void:
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", INK)
