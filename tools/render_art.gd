extends SceneTree
## Renders the game's own art from its own scene and models, into assets/art/:
##   icons/<weapon id>.png   a portrait of the unit carrying each weapon (256², transparent)
##   icons/attack.png        KayKit's sword, for the attack bonus (256², transparent)
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
