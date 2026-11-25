extends SceneTree
## Renders every baked model side by side, front and back, in both team colours,
## playing the role given (default: its first clip), to build/gallery.png.
##   xvfb-run godot --path . --audio-driver Dummy --rendering-driver opengl3 --resolution 1280x720 -s tests/gallery.gd -- shoot 0.3

const MODELS := [&"crossbowman", &"gunner", &"gatlinger", &"cannon", &"knight", &"rogue", &"barbarian", &"warlord"]
const WARLORD_TINT := Color("5c0d18")
const TEAMS := [Color("2f6fe0"), Color("c8302c")]

var _frames := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var role := StringName(args[0]) if args.size() > 0 else &""
	var at := float(args[1]) if args.size() > 1 else 0.3
	var stage := Node3D.new()
	root.add_child(stage)
	for row in 2:
		for i in MODELS.size():
			var bake: CrowdBake = load("res://assets/baked/%s.res" % MODELS[i])
			var crowd := Crowd.create(bake.mesh, 1, bake.material())
			crowd.clips = bake.clips
			stage.add_child(crowd)
			crowd.begin()
			crowd.add(Vector3((i - 3.5) * 1.5, 0, row * 2.2), PI * row, Vector3.ONE / bake.height * 1.3,
					Color(WARLORD_TINT if MODELS[i] == &"warlord" and row == 1 else TEAMS[row], 0.0), crowd.custom(role, -at))
			crowd.end()
			(crowd.material_override as ShaderMaterial).set_shader_parameter(&"clock", 0.0)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.look_at_from_position(Vector3(0, 2.6, 7.5), Vector3(0, 0.6, 1.0))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	stage.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("d8e4ec")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.5
	stage.add_child(env)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	root.get_texture().get_image().save_png("res://build/gallery.png")
	return true
