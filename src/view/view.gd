class_name View
extends Node3D
## Draws a Battle. Reads simulation state, never writes it. Each kind of thing
## on screen is one Crowd: a single batched draw call.

const UNIT_HEIGHT := 1.1           ## metres; a baked character is scaled to this, times its size
const PLAYER_TEAM := Color("2f6fe0")
const ENEMY_TEAM := Color("c8302c")
const FLASH := 0.08
const CHARACTERS := 1200           ## instance capacity per character kind
const LABELS := 48
const BADGES := 16
const CALLOUTS := 24
const CALLOUT_LIFE := 0.9
const BAKED := "res://assets/baked/%s.res"
const CORPSES := 400
const CORPSE_REST := 1.4           ## seconds a body lies still before sinking
const CORPSE_SINK := 0.8           ## seconds to sink out of sight
const PANEL := Vector3(1.9, 1.25, 0.14)
const PANEL_LIFT := 0.15
const PEDESTAL := Vector3(1.5, 0.95, 1.5)
const SPIN := TAU / 4.0            ## rad/s; a whole number of turns per clock wrap, so the wrap is seamless
const FONT := "res://assets/third_party/lilita-one/LilitaOne-Regular.ttf"
const FX := 1200                   ## live flashes, sparks and blasts
const BOSS_SIZE := 2.0             ## enemies this big shake the screen when they fall
const SHIELD_PANES := 9            ## glass panes in the shield's arc
const SHIELD_SPAN := 1.9           ## radians the arc covers, centred ahead of the squad
const DRONE_HEIGHT := 1.8          ## metres a drone hovers at
const DRONE_SCALE := 1.3
const DRONE_TILT := -0.14          ## radians nose-down, leaning into the advance
const MOTORS := [Vector3(0.38, 0.1, 0.38), Vector3(-0.38, 0.1, 0.38), Vector3(0.38, 0.1, -0.38), Vector3(-0.38, 0.1, -0.38)]
const BLADE_HEIGHT := 0.9
const BLADE_TRAIL := Color(0.7, 0.88, 1.0, 0.55)

var stage := Stage.new()
var _characters := {}              ## model -> {crowd: Crowd, bake: CrowdBake, scale: float}
var _shadows: Crowd                ## one soft blob under every character
var _placeholder: Crowd            ## characters without a baked model
var _frames: Crowd                 ## solid rims of the glass panels
var _panels: Crowd                 ## translucent panel faces
var _pedestals: Crowd
var _projectiles := {}             ## projectile look -> Crowd
var _streaks: Crowd                ## a glowing trail behind every projectile, so shots read at phone size
var _shot_looks: Array[Dictionary] = []   ## per arsenal index: {crowd, color, trail, wide, homing}; built once a battle
var _blades: Crowd                 ## the relics: orbiting swords, hovering drones, the shield's honeycomb
var _drones: Crowd
var _rotors: Crowd                 ## each drone's four two-bladed props
var _discs: Crowd                  ## and the blur they spin into
var _shield: Crowd
var _shield_flash := 0.0           ## 1 when the shield has just taken a blow; fades
var _font: FontFile
var _glow: Crowd                   ## every flash, spark and blast: additive billboards
var _fx_at := PackedVector3Array()   ## live sparks as parallel arrays
var _fx_color := PackedColorArray()
var _fx_from := PackedFloat32Array()
var _fx_to := PackedFloat32Array()
var _fx_life := PackedFloat32Array()
var _fx_age := PackedFloat32Array()
var _trauma := 0.0                 ## screen shake, 0..1; decays
var _shake_time := 0.0
var freeze := 0.0                  ## seconds of hit-stop requested; the game loop pauses the simulation
var _labels: Array[Label3D] = []
var _badges: Array[Sprite3D] = []  ## a pedestal's icon, above its numbers
var _callouts: Array[Label3D] = []
var _callout_age := PackedFloat32Array()
var _next_callout := 0
var _clock := 0.0
var _corpses: Array[Dictionary] = []   ## {model, at, yaw, size, color, age}


func _ready() -> void:
	add_child(stage)
	_shadows = _blob_shadows(CHARACTERS * 3)
	_placeholder = _primitive(_capsule(0.3, 1.0), CHARACTERS, false)
	_placeholder.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_font = load(FONT)
	_glow = _billboards(FX)
	_streaks = _trails(4000)
	_frames = _primitive(_box(Vector3(PANEL.x + 0.16, PANEL.y + 0.16, PANEL.z * 0.6)), 200, false)
	_panels = _glass(_box(PANEL), 200)
	_pedestals = _kit_crowd("tower-square-base", 64)
	_blades = _swords(8)
	_drones = Crowd.new(_quadcopter(), 8, null)
	add_child(_drones)
	_rotors = _primitive(_box(Vector3(0.56, 0.014, 0.05)), 32, false)
	var blur := _hexagon(0.3)
	blur.radial_segments = 20
	blur.height = 0.008
	_discs = _glass(blur, 32)
	(_discs.material_override as StandardMaterial3D).emission_enabled = false
	_shield = _glass(_reshaped(_hexagon(0.42), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)), SHIELD_PANES * 2)
	_projectiles = {
		bolt = _arrows(4000),
		rocket = _primitive(_reshaped(_capsule(0.13, 0.75), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3.ZERO)), 200, false),
		tracer = _primitive(_box(Vector3(0.14, 0.14, 1.4)), 4000, true),
		ball = _primitive(_sphere(0.32), 400, false),
	}
	for look in _projectiles:   # too many and too small to be worth drawing into the shadow map
		_projectiles[look].cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in LABELS:
		_labels.append(_label(40))
	for i in BADGES:
		var s := Sprite3D.new()
		s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		s.no_depth_test = true
		s.pixel_size = 0.0055
		s.render_priority = 1
		s.visible = false
		add_child(s)
		_badges.append(s)
	for i in CALLOUTS:
		_callouts.append(_label(56))
		_callout_age.append(CALLOUT_LIFE)


## Instances handed to the GPU this frame, and how many of them are drawn.
func instances() -> Vector2i:
	var out := Vector2i.ZERO
	for c in get_children():
		if c is Crowd:
			out += Vector2i(c.room(), c.count)
	return out


## Clears everything that belongs to a battle: crowds, corpses, effects, labels.
func reset() -> void:
	_corpses.clear()
	_shot_looks.clear()
	_fx_keep(0)
	_trauma = 0.0
	freeze = 0.0
	for c in get_children():
		if c is Crowd:
			c.begin()
			c.end()
	for l in _labels + _callouts:
		l.visible = false
	for s in _badges:
		s.visible = false
	for i in CALLOUTS:
		_callout_age[i] = CALLOUT_LIFE


## Loads every character kind up front, so none loads mid-battle.
func prepare(models: Array[StringName]) -> void:
	for model in models:
		_character_kind(model)


func draw(b: Battle, delta: float) -> void:
	_clock = fposmod(_clock + delta, CrowdClock.WRAP)
	_placeholder.begin()
	_shadows.begin()
	for model in _characters:
		var entry: Dictionary = _characters[model]
		entry.crowd.begin()
		(entry.crowd.material_override as ShaderMaterial).set_shader_parameter(&"clock", _clock)
	_draw_units(b.squad)
	_draw_lane(b.lane, b.squad)
	_draw_shots(b.shots, b.arsenal)
	_draw_relics(b, delta)
	_drain_events(b)
	if b.arms.surge == &"flame":
		_flames(b.squad)
	_draw_corpses(delta)
	_draw_callouts(delta)
	_draw_fx(delta)
	_shake(delta)
	_placeholder.end()
	_shadows.end()
	for model in _characters:
		_characters[model].crowd.end()


func _draw_units(squad: Squad) -> void:
	var k := 0
	var team := Color(PLAYER_TEAM, 0.0)
	for w in squad.weapons.size():
		var wd := squad.weapons[w]
		var entry := _character_kind(wd.model)
		if entry.is_empty():
			for c in squad.counts[w]:
				var p := squad.unit_position(k)
				_character(wd.model, Vector3(p.x, 0.0, p.y), 0.0, wd.size, team, &"shoot", -k * 0.137)
				k += 1
			continue
		# What _character does per soldier, with the kind, clip and sizes looked up once.
		var crowd: Crowd = entry.crowd
		var bake: CrowdBake = entry.bake
		var role: StringName = &"shoot" if bake.clips.has(&"shoot") else bake.clips.keys()[0]
		var body: Vector3 = Vector3.ONE * entry.scale * wd.size
		var blob := Vector3.ONE * wd.size * 0.75
		var shade := Color(0, 0, 0, 0.45)
		for c in squad.counts[w]:
			var p := squad.unit_position(k)
			_shadows.add(Vector3(p.x, 0.03, p.y), 0.0, blob, shade)
			crowd.add(Vector3(p.x, 0.0, p.y), 0.0, body, team, bake.custom(role, _clock - k * 0.137))
			k += 1


func _draw_lane(lane: Lane, squad: Squad) -> void:
	_frames.begin()
	_panels.begin()
	_pedestals.begin()
	var nl := 0
	var nb := 0
	var front := Squad.Z - squad.radius()
	for i in lane.size():
		var d := lane.def[i]
		var hit := lane.hit_age[i] < FLASH
		if d.enemy:
			# Bosses are under fire for seconds at a time: a full flash would wash them white.
			var color := Color(_enemy_team(d.tint), (0.2 if d.persistent else 0.55) if hit else 0.0)
			var role := &"attack" if d.persistent and lane.z[i] >= front - d.radius - 0.05 else &"advance"
			_character(d.model, Vector3(lane.x[i], 0.0, lane.z[i]), PI, d.size, color, role, -lane.serial[i] * 0.29)
		else:
			_pickup(d, Vector3(lane.x[i], 0.0, lane.z[i]), hit)
		if (d.caption != "" or d.persistent) and nl < LABELS:
			var label := _labels[nl]
			label.visible = true
			var top := d.size * UNIT_HEIGHT + 0.4
			if not d.enemy:
				top = PANEL.y + PANEL_LIFT + 0.5 if d.look == ObjectDef.Look.PANEL else PEDESTAL.y + 1.6
			label.position = Vector3(lane.x[i], top, lane.z[i])
			var hp := "%d" % ceili(lane.hp[i])
			label.text = hp if d.enemy else "%s\n%s" % [d.caption_for(lane.amount[i]), hp]
			label.modulate = Color.WHITE if d.enemy else d.color.lightened(0.5)
			nl += 1
			if d.icon != &"" and nb < BADGES:
				_badges[nb].texture = Ui.unit_icon(d.icon)
				_badges[nb].position = label.position + Vector3(0, 1.6, 0)
				_badges[nb].visible = true
				nb += 1
	_frames.end()
	_panels.end()
	_pedestals.end()
	for i in range(nl, LABELS):
		_labels[i].visible = false
	for i in range(nb, BADGES):
		_badges[i].visible = false


func _enemy_team(tint: Color) -> Color:
	return tint if tint.a > 0.0 else ENEMY_TEAM


## A glass panel for unit blocks, multipliers and traps; a stone pedestal
## carrying the unit on offer for weapon crates.
func _pickup(d: ObjectDef, at: Vector3, hit: bool) -> void:
	var tint := d.color.lerp(Color.WHITE, 0.45) if hit else d.color
	if d.look == ObjectDef.Look.PANEL:
		var mid := at + Vector3(0, PANEL.y / 2.0 + PANEL_LIFT, 0)
		_frames.add(mid, 0.0, Vector3.ONE, tint.darkened(0.25))
		_panels.add(mid + Vector3(0, 0, 0.03), 0.0, Vector3.ONE, Color(tint.lightened(0.3), 0.55))
		return
	_pedestals.add(at, 0.0, PEDESTAL / Vector3(1.0, 1.01, 1.0), Color.WHITE)
	if d.model != &"":
		_character(d.model, at + Vector3(0, PEDESTAL.y, 0), _clock * SPIN, 1.3, Color(PLAYER_TEAM, 0.0), &"cheer", 0.0)


func _draw_shots(shots: Shots, weapons: Array[WeaponDef]) -> void:
	for look in _projectiles:
		_projectiles[look].begin()
	_streaks.begin()
	if _shot_looks.size() != weapons.size():
		_shot_looks.clear()
		for wd in weapons:
			# The trail starts at the projectile and stretches back along its path;
			# a rocket's is a long pale smoke trail.
			_shot_looks.append({crowd = _projectiles.get(wd.projectile, _projectiles.tracer),
					color = wd.color.lightened(0.45),
					trail = Color(0.85, 0.85, 0.88, 0.7) if wd.homing else Color(wd.color.lightened(0.15), 0.95),
					size = Vector3(0.9, 1.0, 5.5) if wd.homing else Vector3(1.0 if wd.projectile == &"ball" else 0.6, 1.0, 3.0),
					back = -1.3 * (2.2 if wd.homing else 1.0)})
	for i in shots.size():
		var look := _shot_looks[shots.weapon[i]]
		var vx := shots.vx[i]
		var vz := shots.vz[i]
		var at := Vector3(shots.x[i], 0.6, shots.z[i])
		var yaw := atan2(vx, vz)
		look.crowd.add(at, yaw, Vector3.ONE, look.color)
		var back: float = look.back / sqrt(vx * vx + vz * vz)
		_streaks.add(at + Vector3(vx * back, 0.0, vz * back), yaw, look.size, look.trail)
	_streaks.end()
	for look in _projectiles:
		_projectiles[look].end()


## One character standing at `at`, facing `yaw` (0 = up the lane), playing `role`
## from `phase` seconds offset so neighbours don't move in lockstep.
func _character(model: StringName, at: Vector3, yaw: float, size: float, color: Color,
		role: StringName, phase: float, shadow := 0.45) -> void:
	var entry: Dictionary = _characters.get(model, {})
	if entry.is_empty():
		entry = _character_kind(model)
	if shadow > 0.0:
		_shadows.add(Vector3(at.x, 0.03, at.z), 0.0, Vector3.ONE * size * 0.75, Color(0, 0, 0, shadow))
	if entry.is_empty():
		_placeholder.add(at + Vector3(0, 0.5 * size, 0), yaw, Vector3.ONE * size * 0.6, color)
		return
	var bake: CrowdBake = entry.bake
	if not bake.clips.has(role):
		role = bake.clips.keys()[0]
	entry.crowd.add(at, yaw, Vector3.ONE * entry.scale * size, color, bake.custom(role, _clock + phase))


func _character_kind(model: StringName) -> Dictionary:
	if _characters.has(model):
		return _characters[model]
	if model == &"" or not ResourceLoader.exists(BAKED % model):
		return {}
	var bake: CrowdBake = load(BAKED % model)
	var crowd := Crowd.new(bake.mesh, CHARACTERS, bake.material())
	# Hundreds of characters drawn again into the shadow map cost the GPU more
	# than the rest of the frame on a phone; each has a soft blob shadow instead.
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	crowd.begin()
	(crowd.material_override as ShaderMaterial).set_shader_parameter(&"clock", _clock)
	_characters[model] = {crowd = crowd, bake = bake, scale = UNIT_HEIGHT / bake.height}
	return _characters[model]


func _drain_events(b: Battle) -> void:
	var weapons := b.arsenal
	for e in b.events:
		match e.kind:
			&"fire":
				var wd: WeaponDef = weapons[e.weapon]
				var big := wd.splash > 0.0
				var muzzle := Vector3(0, DRONE_HEIGHT - 0.2, -0.6) if wd.id == &"drone" else Vector3(0, 0.7, -0.35 * wd.size)
				_spark(e.at + muzzle, wd.color.lightened(0.7), 1.6 if big else 0.8, 0.3, 0.09)
			&"shielded":
				_shield_flash = 1.0
				var front := b.squad.radius() + 0.7
				_spark(Vector3(b.squad.x, 0.8, Squad.Z - front), Color(0.6, 0.85, 1.0), 1.0, 2.6, 0.25)
			&"hit":
				if e.splash > 0.0:
					_spark(e.at + Vector3(0, 0.5, 0), Color(1.0, 0.55, 0.15), 0.8, e.splash * 2.2, 0.4)
					_trauma = minf(_trauma + 0.12, 1.0)
				else:
					_spark(e.at + Vector3(0, 0.6, 0), Color(1.0, 0.9, 0.6), 0.5, 1.3, 0.18)
			&"payout":
				_spark(e.at, e.color.lightened(0.4), 0.6, 3.2, 0.45)
				var label := _callouts[_next_callout]
				label.text = e.text
				label.position = e.at
				label.modulate = e.color.lightened(0.3)
				_callout_age[_next_callout] = 0.0
				_next_callout = (_next_callout + 1) % CALLOUTS
			&"zap":
				for k in 6:   # a jagged run of blue-white sparks from one enemy to the next
					var at: Vector3 = e.at.lerp(e.to, (k + 0.5) / 6.0) + Vector3(randf_range(-0.25, 0.25), randf_range(0.2, 0.8), 0)
					_spark(at, Color("d8f6ff"), 1.0, 1.7, 0.18)
			&"death":
				if _corpses.size() == CORPSES:
					_corpses.pop_front()
				var team := _enemy_team(e.tint) if e.enemy else PLAYER_TEAM
				_corpses.append({model = e.model, at = e.at, yaw = PI if e.enemy else 0.0, size = e.size,
						color = Color(team, 0.0), age = 0.0})
				if not e.enemy:
					_trauma = minf(_trauma + 0.03, 1.0)
				elif e.size >= BOSS_SIZE:
					_trauma = 1.0
					freeze = 0.12
					_spark(e.at + Vector3(0, 1.0, 0), Color(1.0, 0.75, 0.3), 1.5, 7.0, 0.6)


## Fallen soldiers play their death once, lie still, then sink into the deck.
func _draw_corpses(delta: float) -> void:
	var kept := 0
	for c in _corpses:
		c.age += delta
		var sink := maxf(c.age - CORPSE_REST, 0.0) / CORPSE_SINK
		if sink >= 1.0:
			continue
		_corpses[kept] = c
		kept += 1
		var at: Vector3 = c.at - Vector3(0, sink * 0.6 * c.size, 0)
		_character(c.model, at, c.yaw, c.size, c.color, &"death", -c.age, 0.45 * (1.0 - sink))
	_corpses.resize(kept)


## Swords sweeping edge-first around the squad, trailing light and throwing
## sparks where they cut; quadcopters hovering beside it; and the shield's
## honeycomb ahead of it. The lit cells are the shield's charge: they go out
## as it takes blows (each blow flashes it) and light again as it recharges.
func _draw_relics(b: Battle, delta: float) -> void:
	var arms := b.arms
	var squad := b.squad
	var lane := b.lane
	_blades.begin()
	for p in arms.blades(squad):
		var out := p - Vector2(squad.x, Squad.Z)
		var tangent := atan2(-out.y, out.x)        # the way the circle runs here, as a yaw
		var at := Vector3(p.x, BLADE_HEIGHT, p.y)
		_blades.add(at, tangent, Vector3.ONE * 1.35, Color.WHITE)
		_shadows.add(Vector3(p.x, 0.03, p.y), 0.0, Vector3(0.6, 1.0, 1.5), Color(0, 0, 0, 0.3))
		_spark(at, BLADE_TRAIL, 0.8, 0.3, 0.25)   # one a frame: together, a ribbon of light along the path
		for i in lane.size():
			if lane.hit_age[i] < FLASH and lane.alive[i] and lane.def[i].enemy and randf() < 0.35 \
					and p.distance_to(Vector2(lane.x[i], lane.z[i])) <= Arms.BLADE_REACH + lane.def[i].radius:
				_spark(at + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.3, 0.3)), Color(1.0, 0.85, 0.5), 0.5, 1.4, 0.2)
	_blades.end()
	_drones.begin()
	_rotors.begin()
	_discs.begin()
	var tilt := Basis(Vector3.RIGHT, DRONE_TILT).scaled(Vector3.ONE * DRONE_SCALE)
	var k := 0
	for p in arms.drones(squad):
		var at := Vector3(p.x, DRONE_HEIGHT + sin(_clock * 3.0 + k) * 0.12, p.y)
		_drones.add(at, 0.0, Vector3.ONE, Color.WHITE)
		for m in MOTORS.size():
			var hub: Vector3 = at + tilt * (MOTORS[m] + Vector3(0, 0.03, 0))
			var turn := 1.0 if m == 0 or m == 3 else -1.0   # diagonal pairs counter-rotate, as on a real quadcopter
			_rotors.add(hub, _clock * 47.0 * turn, Vector3.ONE * DRONE_SCALE, Color(0.1, 0.1, 0.12))
			_discs.add(hub, 0.0, Vector3.ONE * DRONE_SCALE, Color(0.8, 0.85, 0.9, 0.16))
		_shadows.add(Vector3(p.x, 0.03, p.y), 0.0, Vector3.ONE * 1.3, Color(0, 0, 0, 0.3))
		k += 1
	_discs.end()
	_rotors.end()
	_drones.end()
	_shield_flash = maxf(_shield_flash - delta * 4.0, 0.0)
	_shield.begin()
	if arms.level(&"shield") > 0:
		var lit := ceili(arms.shield / maxf(arms.shield_max(squad), 1.0) * SHIELD_PANES - 0.001)   # of SHIELD_PANES ranks
		var r := squad.radius() + 0.7
		for row in 2:   # two courses of hexagons, the upper set half a cell over
			for i in SHIELD_PANES - row:
				var a := -PI / 2.0 + SHIELD_SPAN * ((i + row * 0.5) / (SHIELD_PANES - 1) - 0.5)
				var at := Vector3(squad.x + cos(a) * r, 0.45 + row * 0.72, Squad.Z + sin(a) * r)
				# Cells go out from the ends of the arc inward, the middle ones last.
				var rank := _shield_rank(i + row * 0.5)
				var color := Color(0.45, 0.75, 1.0, 0.6).lerp(Color(0.9, 0.97, 1.0, 0.9), _shield_flash) \
						if rank < lit else Color(0.2, 0.24, 0.32, 0.35)
				_shield.add(at, PI / 2.0 - a, Vector3.ONE, color)
	_shield.end()


## A cell's rank, 0 to SHIELD_PANES - 1, in the order the cells light: the middle first.
func _shield_rank(slot: float) -> int:
	var from_middle := absf(slot - (SHIELD_PANES - 1) / 2.0)
	return int(roundf(from_middle * 2.0))


## The flame surge: tongues of fire licking out over the ground ahead of the squad.
func _flames(squad: Squad) -> void:
	var front := Squad.Z - squad.radius()
	for k in 6:
		var ahead := randf() * Arms.FLAME_DEPTH
		var half := squad.radius() + 1.0 + ahead * 0.25
		var at := Vector3(squad.x + randf_range(-half, half), 0.4 + randf() * 0.5, front - ahead)
		_spark(at, Color(1.0, 0.45 + randf() * 0.3, 0.1), 0.6, 1.8, 0.35)


## A glowing billboard that grows from `from` to `to` metres and fades over `life` seconds.
func _spark(at: Vector3, color: Color, from: float, to: float, life: float) -> void:
	if _fx_at.size() == FX:
		return
	_fx_at.append(at)
	_fx_color.append(color)
	_fx_from.append(from)
	_fx_to.append(to)
	_fx_life.append(life)
	_fx_age.append(0.0)


func _fx_keep(n: int) -> void:
	_fx_at.resize(n)
	_fx_color.resize(n)
	_fx_from.resize(n)
	_fx_to.resize(n)
	_fx_life.resize(n)
	_fx_age.resize(n)


func _draw_fx(delta: float) -> void:
	_glow.begin()
	var kept := 0
	for i in _fx_at.size():
		var age := _fx_age[i] + delta
		var t := age / _fx_life[i]
		if t >= 1.0:
			continue
		if kept != i:
			_fx_at[kept] = _fx_at[i]
			_fx_color[kept] = _fx_color[i]
			_fx_from[kept] = _fx_from[i]
			_fx_to[kept] = _fx_to[i]
			_fx_life[kept] = _fx_life[i]
		_fx_age[kept] = age
		kept += 1
		var s := lerpf(_fx_from[i], _fx_to[i], sqrt(t))
		var c := _fx_color[i]
		c.a = 1.0 - t * t
		_glow.add(_fx_at[i], 0.0, Vector3(s, s, s), c)
	_fx_keep(kept)
	_glow.end()


## Trauma shakes the camera by trauma squared, so small hits barely register
## and big ones jolt; it decays in under a second.
func _shake(delta: float) -> void:
	_trauma = maxf(_trauma - delta * 1.6, 0.0)
	_shake_time += delta
	var k := _trauma * _trauma * 0.45
	var offset := Vector3(sin(_shake_time * 41.0), sin(_shake_time * 37.0 + 1.3), 0.0) * k
	stage.camera.transform = stage.camera_home.translated_local(offset)


func _draw_callouts(delta: float) -> void:
	for i in CALLOUTS:
		_callout_age[i] += delta
		var t := _callout_age[i] / CALLOUT_LIFE
		var label := _callouts[i]
		label.visible = t < 1.0
		if label.visible:
			label.position.y += delta * 2.5
			label.modulate.a = 1.0 - t * t


func _primitive(mesh: Mesh, capacity: int, unshaded: bool) -> Crowd:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var crowd := Crowd.new(mesh, capacity, mat)
	add_child(crowd)
	return crowd


## Soft round shadows on the deck: crowds are too many for real shadow maps.
func _blob_shadows(capacity: int) -> Crowd:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 64
	tex.height = 64
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var crowd := Crowd.new(quad, capacity, mat)
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	return crowd


func _billboards(capacity: int) -> Crowd:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.billboard_keep_scale = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var quad := QuadMesh.new()
	var crowd := Crowd.new(quad, capacity, mat)
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	return crowd


## Flat streaks lying on the projectile's path: a soft oval, long along +Z.
## Blended, not additive: additive light on the pale deck washes out to white.
func _trails(capacity: int) -> Crowd:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE
	var crowd := Crowd.new(quad, capacity, mat)
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	return crowd


func _glass(mesh: Mesh, capacity: int) -> Crowd:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.3, 0.4)
	var crowd := Crowd.new(mesh, capacity, mat)
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	return crowd


## A Kenney piece drawn as a crowd with its own material.
func _kit_crowd(piece: String, capacity: int) -> Crowd:
	var scene: Node = load(Stage.KIT % piece).instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var crowd := Crowd.new(mi.mesh, capacity, null)
	scene.free()
	add_child(crowd)
	return crowd


## KayKit's arrow, turned so its steel tip (the model's -Y end; the green
## fletching is +Y) leads along +Z, the direction a projectile flies.
func _arrows(capacity: int) -> Crowd:
	var scene: Node = load("res://assets/third_party/kaykit-adventurers/props/arrow.gltf").instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := _reshaped(mi.mesh, Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3.ONE * 1.8), Vector3.ZERO))
	scene.free()
	var crowd := Crowd.new(mesh, capacity, null)
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	return crowd


## The knight's sword, laid flat and centred, its point leading along +Z:
## a relic blade that sweeps edge-first around the squad.
func _swords(capacity: int) -> Crowd:
	var knight: Node = load("res://assets/third_party/kaykit-adventurers/characters/Knight.glb").instantiate()
	var sword: MeshInstance3D = knight.find_child("1H_Sword")
	var lay := Basis(Vector3.FORWARD, 0.35) * Basis(Vector3.RIGHT, PI / 2.0)   # flat, rolled a little to catch the light
	var mesh := _reshaped(sword.mesh, Transform3D(lay.scaled(Vector3.ONE * 1.1), lay * Vector3(0, -0.52, 0) * 1.1))
	knight.free()
	var crowd := Crowd.new(mesh, capacity, null)
	add_child(crowd)
	return crowd


## A camera quadcopter, nose (-Z, up the lane) tipped down: a graphite body
## with a gold spine, four arms out to the motors, skids, a camera on a gimbal
## under the nose, white lights ahead and red behind. Props are drawn apart,
## since they spin. Built from primitives, one surface per material.
func _quadcopter() -> ArrayMesh:
	var graphite := _paint(Color(0.16, 0.17, 0.19), 0.6, 0.35)
	var dark := _paint(Color(0.07, 0.07, 0.08), 0.8, 0.25)
	var gold := _paint(Color("f5c542"), 0.9, 0.3)
	var white := _paint(Color(0.9, 0.95, 1.0), 0.0, 0.5, 2.5)
	var red := _paint(Color(1.0, 0.15, 0.1), 0.0, 0.5, 2.5)
	var parts := [
		[_box(Vector3(0.36, 0.13, 0.52)), Transform3D(), graphite],
		[_sphere(0.2), Transform3D(Basis().scaled(Vector3(0.9, 0.42, 1.25)), Vector3(0, 0.07, 0.02)), graphite],
		[_box(Vector3(0.07, 0.02, 0.44)), Transform3D(Basis(), Vector3(0, 0.15, 0.02)), gold],
		[_sphere(0.075), Transform3D(Basis(), Vector3(0, -0.11, -0.25)), dark],
		[_capsule(0.035, 0.08), Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, -0.11, -0.32)), white],
	]
	for m: Vector3 in MOTORS:
		var arm := Vector3(m.x, 0, m.z)
		parts.append([_box(Vector3(0.06, 0.05, arm.length())), Transform3D(Basis(Vector3.UP, atan2(arm.x, arm.z)), arm * 0.5), graphite])
		var motor := _hexagon(0.065)
		motor.radial_segments = 12
		motor.height = 0.1
		parts.append([motor, Transform3D(Basis(), Vector3(m.x, 0.04, m.z)), dark])
		parts.append([_sphere(0.03), Transform3D(Basis(), Vector3(m.x, -0.04, m.z)), white if m.z < 0.0 else red])
	for side: float in [-0.15, 0.15]:
		parts.append([_box(Vector3(0.02, 0.14, 0.02)), Transform3D(Basis(), Vector3(side, -0.13, 0)), dark])
		parts.append([_box(Vector3(0.025, 0.025, 0.42)), Transform3D(Basis(), Vector3(side, -0.2, 0)), dark])
	var pose := Transform3D(Basis(Vector3.RIGHT, DRONE_TILT).scaled(Vector3.ONE * DRONE_SCALE), Vector3.ZERO)
	var tools := {}   # material -> SurfaceTool
	for part: Array in parts:
		if not tools.has(part[2]):
			tools[part[2]] = SurfaceTool.new()
			tools[part[2]].begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[part[2]].append_from(part[0], 0, pose * part[1])
	var mesh := ArrayMesh.new()
	for material: Material in tools:
		tools[material].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	return mesh


func _paint(color: Color, metallic: float, roughness: float, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat


## A copy of a mesh with every vertex moved by `xform` once, up front: crowds
## only turn their instances about Y, so any other pose is built in here.
static func _reshaped(source: Mesh, xform: Transform3D) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for s in source.get_surface_count():
		var arrays := source.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for k in verts.size():
			verts[k] = xform * verts[k]
			normals[k] = (xform.basis * normals[k]).normalized()
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = null
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(s, source.surface_get_material(s))
	return mesh


func _hexagon(r: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 0.06
	m.radial_segments = 6
	m.rings = 1
	return m


func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 8
	m.rings = 2
	return m


func _label(font_size: int) -> Label3D:
	var l := Label3D.new()
	l.font_size = font_size
	l.outline_size = 12
	l.pixel_size = 0.03
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font = _font
	l.outline_modulate = Color(0.08, 0.1, 0.18)
	l.visible = false
	add_child(l)
	return l
