extends SceneTree
## Renders the game's own art from its own scene and models, into assets/art/:
##   icons/<weapon id>.png   a portrait of the unit carrying each weapon (256², transparent)
##   icons/attack.png        KayKit's sword, for the attack bonus (256², transparent)
##   icons/<surge or relic>.png  a bold outlined glyph for each surge and relic (256², transparent)
##   icon.png                the game icon: a crossbowman on a gold-rimmed badge (512²)
##   splash.png              key art: a battle at dusk under the title (1080×1920)
## Needs a GPU context, so it runs under a display (xvfb on a server):
##   xvfb-run godot --path . --rendering-driver opengl3 --resolution 1080x1920 -s tools/render_art.gd
## The outputs are committed: rendering needs a display, which CI does not have.

const Bots := preload("res://tools/bots.gd")
const OUT := "res://assets/art/"
const FONT := preload("res://assets/third_party/lilita-one/LilitaOne-Regular.ttf")
const BLUE := Color("2f6fe0")
const INK := Color(0.07, 0.09, 0.16)
const GOLD := Color("f5c542")

var _frame := 0
var _portraits := {}       ## weapon id -> SubViewport
var _icon: SubViewport
var _main: Node


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "icons"))
	for wd in Content.weapons():
		_portraits[wd.id] = _portrait(wd.model, &"shoot" if wd.model != &"cannon" else &"shoot")
	_portraits[&"attack"] = _sword()
	for id in GLYPHS:
		_portraits[id] = _glyph(GLYPHS[id].call())


func _process(_delta: float) -> bool:
	_frame += 1
	match _frame:
		4:
			for id in _portraits:
				_save(_portraits[id], "icons/%s.png" % id)
			_icon = _badge(_portraits[&"crossbow"].get_texture())
		8:
			_save(_icon, "icon.png")
			_battle()
		16:
			root.get_texture().get_image().save_png(OUT + "splash.png")
			print("saved splash.png")
			return true
	return false


## One unit, in its team colour, framed from the waist up in three-quarter view.
func _portrait(model: StringName, role: StringName) -> SubViewport:
	var vp := _viewport(256)
	var bake: CrowdBake = load("res://assets/baked/%s.res" % model)
	var crowd := Crowd.new(bake.mesh, 1, bake.material())
	vp.add_child(crowd)
	crowd.begin()
	crowd.add(Vector3.ZERO, PI * 0.82, Vector3.ONE / bake.height, Color(BLUE, 0.0), bake.custom(role, -0.35))
	crowd.end()
	(crowd.material_override as ShaderMaterial).set_shader_parameter(&"clock", 0.0)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var static_model := model == &"cannon"
	cam.fov = 34.0 if static_model else 30.0
	var look := Vector3(0, 0.62, 0)
	cam.look_at_from_position(look + (Vector3(0.7, 0.5, 2.9) if static_model else Vector3(0.0, 0.25, 1.7)), look)
	_light(vp)
	return vp


## KayKit's one-handed sword, standing diagonally.
func _sword() -> SubViewport:
	var vp := _viewport(256)
	var knight: Node = load("res://assets/third_party/kaykit-adventurers/characters/Knight.glb").instantiate()
	var sword: MeshInstance3D = knight.find_child("1H_Sword")
	var mi := MeshInstance3D.new()
	mi.mesh = sword.mesh
	mi.rotation_degrees = Vector3(0, 0, -40)
	knight.free()
	vp.add_child(mi)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 40.0
	cam.look_at_from_position(Vector3(0, 0.5, 2.6), Vector3(0, 0.5, 0))
	_light(vp)
	return vp


## The game icon: a rounded navy badge with a gold rim, the crossbowman in it.
func _badge(portrait: Texture2D) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 512)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var frame := Panel.new()
	frame.size = Vector2(512, 512)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("1d3b8a")
	box.set_corner_radius_all(110)
	box.set_border_width_all(26)
	box.border_color = GOLD
	box.shadow_size = 0
	frame.add_theme_stylebox_override("panel", box)
	vp.add_child(frame)
	var glow := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.colors = PackedColorArray([Color("4d8df7"), Color(0.3, 0.55, 0.97, 0.0)])
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.42)
	g.fill_to = Vector2(0.5, 0.0)
	glow.texture = g
	glow.position = Vector2(40, 30)
	glow.size = Vector2(432, 432)
	vp.add_child(glow)
	var face := TextureRect.new()
	face.texture = portrait
	face.position = Vector2(26, 34)
	face.size = Vector2(460, 460)
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vp.add_child(face)
	return vp


## A real battle at dusk, fast-forwarded to the thick of it, seen low from
## behind the squad, under the title.
func _battle() -> void:
	_main = load("res://main.tscn").instantiate()
	_main._progress = Progress.new()
	_main._progress.path = ""
	_main._settings = Settings.new()   # and default settings, never saved
	_main._settings.path = ""
	root.add_child(_main)
	_main.start_level(3)
	var b: Battle = _main._battle
	while b.time < 58.0 and b.state == Battle.State.RUNNING:
		Bots.steer(&"sweep", b)
		b.tick(1.0 / 60.0)
		b.events.clear()
	b.squad.target_x = b.squad.x
	_main._hud.visible = false
	_main.set_physics_process(false)
	await process_frame   # let the game loop draw the battle, then hold it still
	await process_frame
	_main.set_process(false)
	for label in _main._view._labels + _main._view._callouts:
		label.visible = false
	var stage: Stage = _main._view.stage
	stage.camera.look_at_from_position(Vector3(b.squad.x + 1.5, 3.4, 6.5), Vector3(b.squad.x * 0.5, 1.2, -18.0))
	stage.camera_home = stage.camera.transform
	var layer := CanvasLayer.new()
	layer.layer = 30
	root.add_child(layer)
	var shade := TextureRect.new()
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.colors = PackedColorArray([Color(INK, 0.85), Color(INK, 0.0)])
	g.fill_from = Vector2(0.5, 0.0)
	g.fill_to = Vector2(0.5, 1.0)
	shade.texture = g
	shade.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	shade.offset_bottom = 520
	layer.add_child(shade)
	# Laid out in the UI's 720-wide design space, which stretches to the window.
	_title(layer, "GUNLORD", 140, GOLD, 100)
	_title(layer, "hold the bridge", 44, Color.WHITE, 270)


func _title(layer: CanvasLayer, text: String, size: int, color: Color, y: float) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", size / 8)
	l.add_theme_color_override("font_outline_color", INK)
	layer.add_child(l)
	l.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	l.offset_top = y
	l.offset_bottom = y + size * 1.4


## Glyphs in a 256-pixel square: [kind, points, colour, line width] parts,
## drawn in order, each with a dark outline. kind: fill (a polygon) or line.
var GLYPHS := {
	chain = func() -> Array: return [
		[&"fill", [Vector2(156, 18), Vector2(66, 142), Vector2(122, 142), Vector2(92, 238),
				Vector2(194, 104), Vector2(138, 104), Vector2(176, 18)], Color("8fe3ff")],
	],
	flame = func() -> Array: return [
		[&"fill", [Vector2(132, 16), Vector2(178, 74), Vector2(204, 136), Vector2(198, 192), Vector2(170, 228),
				Vector2(128, 240), Vector2(86, 228), Vector2(58, 190), Vector2(56, 136), Vector2(82, 92),
				Vector2(100, 128), Vector2(112, 70)], Color("ff7a1a")],
		[&"fill", [Vector2(130, 104), Vector2(156, 152), Vector2(160, 196), Vector2(130, 222), Vector2(100, 200),
				Vector2(100, 164), Vector2(116, 146)], Color("ffd23a")],
	],
	rockets = func() -> Array: return [
		[&"fill", _turned([Vector2(128, 20), Vector2(160, 70), Vector2(160, 170), Vector2(96, 170), Vector2(96, 70)]), Color("f0f0f0")],
		[&"fill", _turned([Vector2(96, 130), Vector2(60, 200), Vector2(96, 182)]), Color("e03a3a")],
		[&"fill", _turned([Vector2(160, 130), Vector2(196, 200), Vector2(160, 182)]), Color("e03a3a")],
		[&"fill", _turned([Vector2(108, 172), Vector2(128, 236), Vector2(148, 172)]), Color("ffb02a")],
		[&"fill", _turned(_circle(Vector2(128, 96), 16)), Color("4d8df7")],
	],
	freeze = func() -> Array:
		var parts := []
		for k in 3:
			var d := Vector2.from_angle(k * PI / 3.0 + PI / 2.0) * 100.0
			parts.append([&"line", [Vector2(128, 128) - d, Vector2(128, 128) + d], Color("bfe8ff"), 20.0])
			for s: float in [-1.0, 1.0]:
				var tip := Vector2(128, 128) + d * 0.62 * s
				var side := d.normalized().orthogonal() * 26.0
				parts.append([&"line", [tip - side + d.normalized() * 24.0 * s, tip, tip + side + d.normalized() * 24.0 * s], Color("bfe8ff"), 14.0])
		return parts,
	blades = func() -> Array:
		var star := PackedVector2Array()
		for k in 8:
			var r := 112.0 if k % 2 == 0 else 34.0
			star.append(Vector2(128, 128) + Vector2.from_angle(k * PI / 4.0 + 0.3) * r)
		return [[&"fill", star, Color("d9dde6")], [&"fill", _circle(Vector2(128, 128), 18), Color("5a6070")]],
	drone = func() -> Array: return [
		[&"line", [Vector2(58, 92), Vector2(198, 92)], Color("8a90a0"), 14.0],
		[&"fill", _ellipse(Vector2(58, 80), 46, 14), Color("d9dde6")],
		[&"fill", _ellipse(Vector2(198, 80), 46, 14), Color("d9dde6")],
		[&"fill", _circle(Vector2(128, 140), 58), Color("f5c542")],
		[&"fill", _circle(Vector2(128, 140), 22), Color("2f6fe0")],
	],
	shield = func() -> Array: return [
		[&"fill", [Vector2(128, 18), Vector2(222, 50), Vector2(214, 140), Vector2(128, 238), Vector2(42, 140), Vector2(34, 50)], Color("f5c542")],
		[&"fill", [Vector2(128, 44), Vector2(196, 68), Vector2(190, 134), Vector2(128, 206), Vector2(66, 134), Vector2(60, 68)], Color("2f6fe0")],
	],
}


func _glyph(parts: Array) -> SubViewport:
	var vp := _viewport(256)
	for part in parts:
		var pts := PackedVector2Array(part[1])
		var width: float = part[3] if part.size() > 3 else 0.0
		var rim := Line2D.new()
		rim.points = pts
		rim.closed = part[0] == &"fill"
		rim.width = (width if width > 0.0 else 0.0) + 16.0
		rim.default_color = INK
		rim.joint_mode = Line2D.LINE_JOINT_ROUND
		rim.begin_cap_mode = Line2D.LINE_CAP_ROUND
		rim.end_cap_mode = Line2D.LINE_CAP_ROUND
		vp.add_child(rim)
		if part[0] == &"fill":
			var poly := Polygon2D.new()
			poly.polygon = pts
			poly.color = part[2]
			vp.add_child(poly)
		else:
			var line := rim.duplicate() as Line2D
			line.width = width
			line.default_color = part[2]
			vp.add_child(line)
	return vp


static func _circle(c: Vector2, r: float) -> PackedVector2Array:
	return _ellipse(c, r, r)


static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in 32:
		var a := k * TAU / 32.0
		out.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## Turns points 40° about the glyph's centre: a rocket climbing to the right.
static func _turned(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(Vector2(128, 128) + (p - Vector2(128, 128)).rotated(deg_to_rad(40)))
	return out


func _viewport(px: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(px, px)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	return vp


func _light(vp: SubViewport) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, -30, 0)
	sun.light_energy = 1.1
	vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	vp.add_child(env)


func _save(vp: SubViewport, name: String) -> void:
	vp.get_texture().get_image().save_png(OUT + name)
	print("saved ", name)
