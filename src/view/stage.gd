class_name Stage
extends Node3D
## The static scene the battle plays on: a stone bridge over water, castle
## walls and towers along it, the enemy gatehouse at the far end, sky, sun and
## camera. Built once; repeated pieces are batched into one MultiMesh each.

const KIT := "res://assets/third_party/kenney-castle-kit/%s.glb"
const DECK_HALF := 6.4                  ## the deck is a little wider than the lane
const NEAR_Z := 14.0
const FAR_Z := -60.0
const WATER_Y := -1.8

var camera: Camera3D
var camera_home: Transform3D           ## where the camera rests; shake offsets from here


func _ready() -> void:
	_camera()
	_light()
	_deck()
	_water()
	_parapets()
	_dividers()
	_towers()
	_gatehouse()


func _camera() -> void:
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = 42.0
	add_child(camera)
	camera.look_at_from_position(Vector3(0, 21.0, 11.5), Vector3(0, 0, -15.0))
	camera_home = camera.transform


func _light() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 0.75
	sun.light_color = Color("fff3e0")
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 80.0
	add_child(sun)

	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("4d8fd6")
	sky_mat.sky_horizon_color = Color("bfe0f5")
	sky_mat.ground_horizon_color = Color("bfe0f5")
	sky_mat.ground_bottom_color = Color("2a5d8f")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _deck() -> void:
	var deck := BoxMesh.new()
	deck.size = Vector3(DECK_HALF * 2.0, 2.6, NEAR_Z - FAR_Z)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/view/stone.gdshader")
	deck.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = deck
	mi.position = Vector3(0, -1.3, (NEAR_Z + FAR_Z) / 2.0)
	add_child(mi)


func _water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(160, 200)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://src/view/water.gdshader")
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(0, WATER_Y, -30)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Battlements along both edges of the deck, with the team's banners hung outside.
func _parapets() -> void:
	var walls: Array[Transform3D] = []
	var banners: Array[Transform3D] = []
	var step := 1.6
	var z := NEAR_Z
	var k := 0
	while z > FAR_Z:
		for side: float in [-1.0, 1.0]:
			walls.append(_at(Vector3(side * (DECK_HALF + 0.35), 0, z), 0.0, Vector3(0.7, 0.7, step)))
			if k % 5 == 2:
				banners.append(_at(Vector3(side * (DECK_HALF + 0.72), -0.9, z), 0.0 if side > 0 else PI, Vector3.ONE * 1.1))
		z -= step
		k += 1
	_batch("wall", walls)
	_batch("flag-banner-long", banners)


## Low walls between the middle lane and the side lanes, ending where the squad stands.
func _dividers() -> void:
	var walls: Array[Transform3D] = []
	var step := 1.5
	var z := Lane.WALL_END_Z - step / 2.0
	while z > FAR_Z + 4.0:
		for side: float in [-1.0, 1.0]:
			walls.append(_at(Vector3(side * Lane.WALL_X, 0, z), 0.0, Vector3(0.7, 0.5, step)))
		z -= step
	_batch("wall-narrow", walls)


## Towers standing in the water on both sides, on rocks, flying pennants.
func _towers() -> void:
	var bases: Array[Transform3D] = []
	var mids: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	var hex_bases: Array[Transform3D] = []
	var hex_roofs: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var pennants: Array[Transform3D] = []
	var z := 8.0
	var k := 0
	while z > FAR_Z - 4.0:
		for side: float in [-1.0, 1.0]:
			var x := side * (DECK_HALF + 3.2 + (k % 2) * 0.8)
			var s := 2.4
			rocks.append(_at(Vector3(x, WATER_Y - 0.1, z), k * 1.3, Vector3(3.2, 2.0, 3.2)))
			if (k + int(side > 0)) % 2 == 0:
				bases.append(_at(Vector3(x, WATER_Y + 0.6, z), 0.0, Vector3.ONE * s))
				mids.append(_at(Vector3(x, WATER_Y + 0.6 + 1.01 * s, z), 0.0, Vector3.ONE * s))
				mids.append(_at(Vector3(x, WATER_Y + 0.6 + 2.02 * s, z), 0.0, Vector3.ONE * s))
				roofs.append(_at(Vector3(x, WATER_Y + 0.6 + 3.03 * s, z), 0.0, Vector3.ONE * s))
				pennants.append(_at(Vector3(x, WATER_Y + 0.6 + 4.0 * s, z), PI / 2, Vector3.ONE * 1.8))
			else:
				hex_bases.append(_at(Vector3(x, WATER_Y + 0.6, z), 0.0, Vector3.ONE * s))
				hex_bases.append(_at(Vector3(x, WATER_Y + 0.6 + 1.31 * s, z), 0.0, Vector3.ONE * s))
				hex_roofs.append(_at(Vector3(x, WATER_Y + 0.6 + 2.62 * s, z), 0.0, Vector3.ONE * s))
		z -= 14.0
		k += 1
	_batch("rocks-large", rocks)
	_batch("tower-square-base", bases)
	_batch("tower-square-mid", mids)
	_batch("tower-square-top-roof", roofs)
	_batch("tower-hexagon-base", hex_bases)
	_batch("tower-hexagon-roof", hex_roofs)
	_batch("flag-pennant", pennants)


## The enemy's gatehouse closing the far end of the bridge; the horde pours out of it.
func _gatehouse() -> void:
	var z := FAR_Z + 2.0
	var walls: Array[Transform3D] = []
	var x := -DECK_HALF
	while x <= DECK_HALF:
		if absf(x) > 2.6:
			walls.append(_at(Vector3(x, 0, z), 0.0, Vector3(1.0, 2.6, 1.2)))
		x += 1.0
	_batch("wall", walls)
	var s := 3.0
	var towers: Array[Transform3D] = []
	var roofs: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var tx := side * 3.6
		towers.append(_at(Vector3(tx, 0, z), 0.0, Vector3.ONE * s))
		towers.append(_at(Vector3(tx, 1.31 * s, z), 0.0, Vector3.ONE * s))
		roofs.append(_at(Vector3(tx, 2.62 * s, z), 0.0, Vector3.ONE * s))
	_batch("tower-hexagon-base", towers)
	_batch("tower-hexagon-roof", roofs)


static func _at(pos: Vector3, yaw: float, scale: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw).scaled_local(scale), pos)


## Every transform drawn with one Kenney piece, as a single MultiMesh per mesh.
func _batch(piece: String, transforms: Array[Transform3D]) -> void:
	var scene: Node = load(KIT % piece).instantiate()
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mi.mesh
		mm.instance_count = transforms.size()
		for i in transforms.size():
			mm.set_instance_transform(i, transforms[i] * mi.transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)
	scene.free()
