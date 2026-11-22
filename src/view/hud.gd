class_name Hud
extends CanvasLayer
## Pause, the volume button, timer and wave chips, squad size with its
## capacity bar, the weapon mix as unit badges in a column at one side (clear
## of the steering thumb), the nearest boss's health bar, and the stage's
## title as a battle opens.

signal pause_pressed
signal master_changed(value: float)

const BOSS_RANGE := -40.0           ## a boss's bar shows once it is this close
const BUTTON := 64.0

var _volume: VolumeButton
var _clock: Label
var _wave: Label
var _units: Label
var _fill: ProgressBar
var _mix: VBoxContainer
var _badges := {}                   ## weapon index -> {chip: Control, count: Label}
var _boss: Control
var _boss_name: Label
var _boss_bar: ProgressBar
var _title: Label
var _title_age := 9.0


func _ready() -> void:
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 20
	top.offset_right = -20
	top.offset_top = 20
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	# Not focusable: in battle the keys steer, and Escape pauses.
	Ui.icon_button(top, "pause", BUTTON, Color(Ui.INK, 0.6), func() -> void: pause_pressed.emit()) \
			.focus_mode = Control.FOCUS_NONE
	_volume = VolumeButton.new(BUTTON, Color(Ui.INK, 0.6))
	_volume.focus_mode = Control.FOCUS_NONE
	_volume.changed.connect(func(v: float) -> void: master_changed.emit(v))
	top.add_child(_volume)
	_clock = _chip(top, 36)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_wave = _chip(top, 36)

	var squad := VBoxContainer.new()
	squad.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	squad.offset_top = 96
	squad.grow_horizontal = Control.GROW_DIRECTION_BOTH
	squad.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(squad)
	_units = Ui.label(squad, "", 64, Color.WHITE)
	_fill = Ui.bar(squad, Vector2(220, 14), Ui.SKY)

	_boss = VBoxContainer.new()
	_boss.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_boss.offset_top = 210
	_boss.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(_boss)
	_boss_name = Ui.label(_boss, "", 30, Color("ffd0c8"))
	_boss_bar = Ui.bar(_boss, Vector2(420, 22), Color("d8423a"))

	_title = Ui.label(self, "", 52, Color.WHITE)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.offset_top = -260

	_mix = VBoxContainer.new()
	_mix.add_theme_constant_override("separation", 10)
	add_child(_mix)
	_place_badges(&"right")


## Reflects the settings: the volume button, the badges' side.
func show_settings(settings: Settings) -> void:
	_volume.set_level(settings.master)
	_place_badges(settings.badges)


## The badge column hugs one edge, a little above the middle of the screen.
func _place_badges(side: StringName) -> void:
	var right := side == &"right"
	_mix.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT if right else Control.PRESET_CENTER_LEFT)
	_mix.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	_mix.grow_vertical = Control.GROW_DIRECTION_BOTH
	_mix.offset_right = -14 if right else 0
	_mix.offset_left = 0 if right else 14
	_mix.offset_top = -120
	_mix.offset_bottom = -120
	_mix.alignment = BoxContainer.ALIGNMENT_CENTER
	for badge in _mix.get_children():
		badge.size_flags_horizontal = Control.SIZE_SHRINK_END if right else Control.SIZE_SHRINK_BEGIN


## The stage's number and name, shown for a moment as the battle opens.
func announce(text: String) -> void:
	_title.text = text
	_title_age = 0.0


func draw(b: Battle) -> void:
	_title_age += get_process_delta_time()
	_title.modulate.a = clampf(2.2 - _title_age, 0.0, 1.0)
	var left := maxf(b.level.duration - b.time, 0.0)
	_clock.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	_wave.text = "WAVE %d/%d" % [b.wave, b.waves]
	var total := b.squad.total()
	_units.text = "%d" % total
	_fill.max_value = b.squad.capacity
	_fill.value = total
	(_fill.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Ui.GOLD if total >= b.squad.capacity else Ui.SKY
	_draw_mix(b.squad)
	_draw_boss(b.lane)


## One badge per weapon the squad carries: the unit's portrait and its count.
func _draw_mix(squad: Squad) -> void:
	for w in squad.weapons.size():
		var wd := squad.weapons[w]
		if not _badges.has(w):
			var row := Ui.icon_chip(_mix, Ui.unit_icon(wd.id), 56.0, 30)
			var panel := row.get_parent() as PanelContainer
			panel.size_flags_horizontal = Control.SIZE_SHRINK_END if _mix.grow_horizontal == Control.GROW_DIRECTION_BEGIN \
					else Control.SIZE_SHRINK_BEGIN
			(panel.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color(wd.color.darkened(0.45), 0.85)
			_badges[w] = {chip = panel, count = row.get_child(1)}
		var badge: Dictionary = _badges[w]
		badge.chip.visible = squad.counts[w] > 0
		badge.count.text = str(squad.counts[w])


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
	Ui.style(l, size, Color.WHITE)
	var s := Ui.box(Color(Ui.INK, 0.6), 14)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", s)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(0, BUTTON)
	parent.add_child(l)
	return l
