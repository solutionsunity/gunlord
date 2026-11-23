class_name Hud
extends CanvasLayer
## Pause, the volume button, timer and wave chips, squad size with its
## capacity bar, the weapon mix as unit badges in a column at one side (clear
## of the steering thumb), the nearest boss's health bar, a gear row on the
## badges' side holding the relics the squad brings (each glyph with its
## level) and the running surge with its countdown (and a frost over the
## screen while the lane is frozen), the stage's title as a battle opens, and,
## when the settings ask for it, a performance readout under the pause button.

signal pause_pressed
signal master_changed(value: float)

const BOSS_RANGE := -40.0           ## a boss's bar shows once it is this close
const BUTTON := 64.0
const STATS_EVERY := 0.5            ## seconds between readout refreshes; the worst frame is over that span

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
var _gear: HBoxContainer            ## the relics, then the surge, on the badges' side
var _relics: HBoxContainer
var _surge: Control
var _surge_icon: TextureRect
var _surge_bar: ProgressBar
var _frost: ColorRect
var _title: Label
var _title_age := 9.0
var _stats: Label
var _stats_age := 0.0
var _stats_frames := 0
var _stats_time := 0.0
var _stats_worst := 0.0


func _ready() -> void:
	_frost = ColorRect.new()
	_frost.color = Color(0.75, 0.9, 1.0, 0.2)
	_frost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_frost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frost)
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

	_gear = HBoxContainer.new()   # under the boss bar
	_gear.add_theme_constant_override("separation", 16)
	add_child(_gear)
	_relics = HBoxContainer.new()
	_relics.add_theme_constant_override("separation", 8)
	_gear.add_child(_relics)
	_surge = HBoxContainer.new()
	_surge.add_theme_constant_override("separation", 10)
	_gear.add_child(_surge)
	_surge_icon = TextureRect.new()
	_surge_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_surge_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_surge_icon.custom_minimum_size = Vector2(64, 64)
	_surge.add_child(_surge_icon)
	_surge_bar = Ui.bar(_surge, Vector2(200, 18), Color.WHITE)
	_surge_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	_title = Ui.label(self, "", 52, Color.WHITE)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_title.grow_vertical = Control.GROW_DIRECTION_BOTH
	_title.offset_top = -260

	_stats = Ui.label(self, "", 20, Color.WHITE)
	_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_stats.position = Vector2(20, 100)
	_stats.visible = false

	_mix = VBoxContainer.new()
	_mix.add_theme_constant_override("separation", 10)
	add_child(_mix)
	_place_badges(&"right")


## Reflects the settings: the volume button, the badges' side.
func show_settings(settings: Settings) -> void:
	_volume.set_level(settings.master)
	_place_badges(settings.badges)
	_stats.visible = settings.stats
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), settings.stats)


## The badge column hugs one edge, a little above the middle of the screen;
## the gear row hugs the same edge up top, the relics outermost.
func _place_badges(side: StringName) -> void:
	var right := side == &"right"
	_gear.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT)
	_gear.grow_horizontal = Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END
	_gear.offset_right = -20 if right else 0
	_gear.offset_left = 0 if right else 20
	_gear.offset_top = 278
	_gear.move_child(_relics, -1 if right else 0)
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


## The relics this battle brings: a glyph and a level for each.
func show_relics(loadout: Dictionary) -> void:
	for child in _relics.get_children():
		child.queue_free()
	for id in Relics.LABELS:
		if loadout.has(id):
			var row := Ui.icon_chip(_relics, Ui.unit_icon(id), 40.0, 24)
			(row.get_child(1) as Label).text = Relics.NUMERALS[loadout[id]]


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
	_draw_surge(b.arms)


## The performance readout, refreshed every STATS_EVERY seconds: frames per
## second and the average and worst frame; the scripts' time in the
## simulation (physics) and the drawing (process) callbacks, and the
## renderer's CPU time (GPU time too, where the platform measures it); the
## and the instances sent to the GPU against those drawn.
func draw_stats(view: View) -> void:
	if not _stats.visible:
		return
	var dt := get_process_delta_time()
	_stats_age += dt
	_stats_frames += 1
	_stats_time += dt
	_stats_worst = maxf(_stats_worst, dt)
	if _stats_age < STATS_EVERY:
		return
	var vp := get_viewport().get_viewport_rid()
	var render := RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
	var gpu := RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var counts := view.instances()
	_stats.text = "FPS %d  frame %.0f ms\nworst %.0f ms\nsim %.1f  draw %.1f\nrender %.1f%s\nsent %.1fk  drawn %.1fk" % [
		roundi(_stats_frames / _stats_time), _stats_time / _stats_frames * 1000.0, _stats_worst * 1000.0,
		Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0,
		render, "  gpu %.1f" % gpu if gpu > 0.0 else "",
		counts.x / 1000.0, counts.y / 1000.0]
	_stats_age = 0.0
	_stats_frames = 0
	_stats_time = 0.0
	_stats_worst = 0.0


## The running surge: its icon and the time it has left; frost while frozen.
func _draw_surge(arms: Arms) -> void:
	_frost.visible = arms.frozen()
	_surge.visible = arms.surge != &""
	if not _surge.visible:
		return
	var s: Dictionary = Content.SURGES[arms.surge]
	_surge_icon.texture = Ui.unit_icon(arms.surge)
	_surge_bar.max_value = s.seconds
	_surge_bar.value = arms.surge_left
	(_surge_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = s.color


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
