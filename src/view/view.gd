class_name View
extends Node3D
## Draws a Battle. Reads simulation state, never writes it. Each kind of thing
## on screen is one Crowd: a single batched draw call.

const UNIT_HEIGHT := 0.95          ## metres; a baked character is scaled to this, times its size
const PLAYER_TEAM := Color("2f6fe0")
const ENEMY_TEAM := Color("c8302c")
const FLASH := 0.08
const CHARACTERS := 1200           ## instance capacity per character kind
const LABELS := 48
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

var stage := Stage.new()
var _characters := {}              ## model -> {crowd: Crowd, bake: CrowdBake, scale: float}
var _shadows: Crowd                ## one soft blob under every character
var _placeholder: Crowd            ## characters without a baked model
var _frames: Crowd                 ## solid rims of the glass panels
var _panels: Crowd                 ## translucent panel faces
var _pedestals: Crowd
var _projectiles := {}             ## projectile look -> Crowd
var _streaks: Crowd                ## a glowing trail behind every projectile, so shots read at phone size
var _font: FontFile
var _glow: Crowd                   ## every flash, spark and blast: additive billboards
var _fx: Array[Dictionary] = []    ## {at, color, from, to, life, age}
var _trauma := 0.0                 ## screen shake, 0..1; decays
var _shake_time := 0.0
var freeze := 0.0                  ## seconds of hit-stop requested; the game loop pauses the simulation
var _labels: Array[Label3D] = []
var _callouts: Array[Label3D] = []
var _callout_age := PackedFloat32Array()
var _next_callout := 0
var _clock := 0.0
var _corpses: Array[Dictionary] = []   ## {model, at, yaw, size, color, age}


func _ready() -> void:
	add_child(stage)
	_shadows = _blob_shadows(CHARACTERS * 3)
	_placeholder = _primitive(_capsule(0.3, 1.0), CHARACTERS, false)
	_font = load(FONT)
	_glow = _billboards(FX)
	_streaks = _trails(4000)
	_frames = _primitive(_box(Vector3(PANEL.x + 0.16, PANEL.y + 0.16, PANEL.z * 0.6)), 200, false)
	_panels = _glass(_box(PANEL), 200)
	_pedestals = _kit_crowd("tower-square-base", 64)
	_projectiles = {
		bolt = _arrows(4000),
		tracer = _primitive(_box(Vector3(0.14, 0.14, 1.4)), 4000, true),
		ball = _primitive(_sphere(0.32), 400, false),
	}
	for i in LABELS:
		_labels.append(_label(40))
	for i in CALLOUTS:
		_callouts.append(_label(56))
		_callout_age.append(CALLOUT_LIFE)


## Clears everything that belongs to a battle: crowds, corpses, effects, labels.
func reset() -> void:
	_corpses.clear()
	_fx.clear()
	_trauma = 0.0
	freeze = 0.0
	for c in get_children():
		if c is Crowd:
			c.begin()
			c.end()
	for l in _labels + _callouts:
		l.visible = false
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
	_draw_shots(b.shots, b.squad.weapons)
	_drain_events(b)
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
	for w in squad.weapons.size():
		var wd := squad.weapons[w]
		for c in squad.counts[w]:
			var p := squad.unit_position(k)
			_character(wd.model, Vector3(p.x, 0.0, p.y), 0.0, wd.size, Color(PLAYER_TEAM, 0.0), &"shoot", -k * 0.137)
			k += 1


func _draw_lane(lane: Lane, squad: Squad) -> void:
	_frames.begin()
	_panels.begin()
	_pedestals.begin()
	var nl := 0
	var front := Squad.Z - squad.radius()
	for i in lane.size():
		var d := lane.def[i]
		var hit := lane.hit_age[i] < FLASH
		if d.enemy:
			# Bosses are under fire for seconds at a time: a full flash would wash them white.
			var color := Color(ENEMY_TEAM, (0.2 if d.persistent else 0.55) if hit else 0.0)
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
	_frames.end()
	_panels.end()
	_pedestals.end()
	for i in range(nl, LABELS):
		_labels[i].visible = false


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
	for i in shots.size():
		var wd := weapons[shots.weapon[i]]
		var crowd: Crowd = _projectiles.get(wd.projectile, _projectiles.tracer)
		var at := Vector3(shots.x[i], 0.6, shots.z[i])
		var yaw := atan2(shots.vx[i], shots.vz[i])
		crowd.add(at, yaw, Vector3.ONE, wd.color.lightened(0.45))
		# The trail starts at the projectile and stretches back along its path.
		var back := Vector3(shots.vx[i], 0.0, shots.vz[i]).normalized() * -1.3
		var wide := 1.0 if wd.projectile == &"ball" else 0.6
		_streaks.add(at + back, yaw, Vector3(wide, 1.0, 3.0), Color(wd.color.lightened(0.15), 0.95))
	_streaks.end()
	for look in _projectiles:
		_projectiles[look].end()


## One character standing at `at`, facing `yaw` (0 = up the lane), playing `role`
## from `phase` seconds offset so neighbours don't move in lockstep.
func _character(model: StringName, at: Vector3, yaw: float, size: float, color: Color,
		role: StringName, phase: float, shadow := 0.45) -> void:
	var entry := _character_kind(model)
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
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	crowd.begin()
	(crowd.material_override as ShaderMaterial).set_shader_parameter(&"clock", _clock)
	_characters[model] = {crowd = crowd, bake = bake, scale = UNIT_HEIGHT / bake.height}
	return _characters[model]


func _drain_events(b: Battle) -> void:
	var weapons := b.squad.weapons
	for e in b.events:
		match e.kind:
			&"fire":
				var wd: WeaponDef = weapons[e.weapon]
				var big := wd.splash > 0.0
				_spark(e.at + Vector3(0, 0.7, -0.35 * wd.size), wd.color.lightened(0.7), 1.6 if big else 0.8, 0.3, 0.09)
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
			&"death":
				if _corpses.size() == CORPSES:
					_corpses.pop_front()
				var team := ENEMY_TEAM if e.enemy else PLAYER_TEAM
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
	var keep: Array[Dictionary] = []
	for c in _corpses:
		c.age += delta
		var sink := maxf(c.age - CORPSE_REST, 0.0) / CORPSE_SINK
		if sink >= 1.0:
			continue
		keep.append(c)
		var at: Vector3 = c.at - Vector3(0, sink * 0.6 * c.size, 0)
		_character(c.model, at, c.yaw, c.size, c.color, &"death", -c.age, 0.45 * (1.0 - sink))
	_corpses = keep


## A glowing billboard that grows from `from` to `to` metres and fades over `life` seconds.
func _spark(at: Vector3, color: Color, from: float, to: float, life: float) -> void:
	if _fx.size() == FX:
		return
	_fx.append({at = at, color = color, from = from, to = to, life = life, age = 0.0})


func _draw_fx(delta: float) -> void:
	_glow.begin()
	var keep: Array[Dictionary] = []
	for f in _fx:
		f.age += delta
		var t: float = f.age / f.life
		if t >= 1.0:
			continue
		keep.append(f)
		var s: float = lerpf(f.from, f.to, sqrt(t))
		_glow.add(f.at, 0.0, Vector3(s, s, s), Color(f.color, 1.0 - t * t))
	_fx = keep
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


func _primitive(mesh: PrimitiveMesh, capacity: int, unshaded: bool) -> Crowd:
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


## KayKit's arrow, turned from lying along +Y to flying along +Z.
func _arrows(capacity: int) -> Crowd:
	var scene: Node = load("res://assets/third_party/kaykit-adventurers/props/arrow.gltf").instantiate()
	var mi: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var arrays := mi.mesh.surface_get_arrays(0)
	var turn := Basis(Vector3.RIGHT, PI / 2.0).scaled(Vector3.ONE * 1.8)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for k in verts.size():
		verts[k] = turn * verts[k]
		normals[k] = (turn * normals[k]).normalized()
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mi.mesh.surface_get_material(0))
	scene.free()
	var crowd := Crowd.new(mesh, capacity, null)
	crowd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(crowd)
	return crowd


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
