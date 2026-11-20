extends SceneTree
## Bakes KayKit characters into CrowdBake resources at assets/baked/<id>.res.
##   godot --headless --path . -s tools/bake_crowd.gd
##
## Per character: keep the skinned body plus the named props, sample each clip
## at FPS, skin every vertex on the CPU (weighted bone * bind matrices; the
## engine only skins on a rendering server), and write positions and normals
## into textures, one frame per row. The model is turned to face -Z.

const FPS := 15.0
const MAX_WIDTH := 4096
const SOURCE := "res://assets/third_party/kaykit-adventurers/characters/%s.glb"
const ATLAS := "res://assets/third_party/kaykit-adventurers/props/%s_texture.png"
const ATLAS_GRID := Vector2i(8, 4)
const OUT := "res://assets/baked/%s.res"

## The grip KayKit uses for a one-handed crossbow in the right hand slot; our
## own weapons (tools/props.gd, forward +Z) mount the same way.
const GRIP := Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3(-0.105, -0.01, 0))

## source: a KayKit character, or "" for a static model made only of `builds`.
## props: KayKit meshes to keep from bone attachments. builds: in-house props,
## each a name (held in the right hand) or [name, bone, offset] (sitting on that bone).
## team: atlas cells that take the team colour.
## clips: role -> [KayKit animation, loops]; a static model holds one pose per role.
const MANIFEST := [
	{
		id = &"crossbowman", source = "Rogue_Hooded", atlas = "rogue",
		props = ["1H_Crossbow", "Rogue_Cape"],
		team = [Vector2i(0, 1), Vector2i(1, 1)],
		clips = {shoot = ["1H_Ranged_Shooting", true], cheer = ["Cheer", true], death = ["Death_A", false]},
	},
	{
		id = &"gunner", source = "Knight", atlas = "knight",
		props = ["Knight_Helmet", "Knight_Cape"], builds = ["musket"],
		team = [Vector2i(3, 0), Vector2i(0, 1)],
		clips = {shoot = ["2H_Ranged_Shooting", true], cheer = ["Cheer", true], death = ["Death_B", false]},
	},
	{
		id = &"gatlinger", source = "Barbarian", atlas = "barbarian",
		props = ["Barbarian_Hat", "Barbarian_Cape"], builds = ["gatling"],
		team = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		clips = {shoot = ["2H_Ranged_Shooting", true], cheer = ["Cheer", true], death = ["Death_A", false]},
	},
	{
		id = &"cannon", source = "", atlas = "knight", builds = ["cannon"], team = [],
		clips = {shoot = [], death = []},
	},
	{
		id = &"knight", source = "Knight", atlas = "knight",
		props = ["1H_Sword", "Knight_Helmet", "Knight_Cape"],
		team = [Vector2i(3, 0), Vector2i(0, 1)],
		clips = {advance = ["Running_A", true], attack = ["1H_Melee_Attack_Chop", true], death = ["Death_A", false]},
	},
	{
		id = &"rogue", source = "Rogue", atlas = "rogue",
		props = ["Knife"],
		team = [Vector2i(0, 1), Vector2i(1, 1)],
		clips = {advance = ["Running_B", true], attack = ["1H_Melee_Attack_Stab", true], death = ["Death_B", false]},
	},
	{
		id = &"barbarian", source = "Barbarian", atlas = "barbarian",
		props = ["2H_Axe", "Barbarian_Hat", "Barbarian_Cape"],
		team = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)],
		clips = {advance = ["Walking_A", true], attack = ["2H_Melee_Attack_Chop", true], death = ["Death_A", false]},
	},
	{
		id = &"warlord", source = "Barbarian", atlas = "barbarian",
		props = ["2H_Axe", "Barbarian_Cape"], builds = [["crown", "head", Vector3(0, 0.95, 0)]],
		team = [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(7, 0)],
		clips = {advance = ["Walking_A", true], attack = ["2H_Melee_Attack_Chop", true], death = ["Death_A", false]},
	},
]

const Props := preload("res://tools/props.gd")

var _pending: Array[Dictionary] = []
var _rigs := {}   # id -> instantiated character, added to the tree in _init


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/baked"))
	for entry in MANIFEST:
		var rig: Node3D = Node3D.new() if entry.source == "" else load(SOURCE % entry.source).instantiate()
		get_root().add_child(rig)
		_rigs[entry.id] = rig
		_pending.append(entry)


## The animation players need a frame inside the tree before they can seek.
func _process(_delta: float) -> bool:
	for entry in _pending:
		var started := Time.get_ticks_msec()
		var bake := _bake(entry, _rigs[entry.id])
		var err := ResourceSaver.save(bake, OUT % entry.id)
		print("%-12s verts=%d frames=%d tex=%dx%d height=%.2f  %d ms  %s" % [
			entry.id, bake.mesh.surface_get_array_len(0), bake.positions.get_height() / bake.rows_per_frame,
			bake.positions.get_width(), bake.positions.get_height(), bake.height,
			Time.get_ticks_msec() - started, error_string(err)])
	return true


func _bake(entry: Dictionary, rig: Node3D) -> CrowdBake:
	var skel: Skeleton3D = rig.find_child("Skeleton3D")
	var player: AnimationPlayer = rig.find_child("AnimationPlayer")
	var parts := _parts(skel, entry)
	var turn := Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO)
	if skel != null:
		turn *= rig.global_transform.affine_inverse() * skel.global_transform

	# Topology: every part's vertices concatenated, in a fixed order.
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var count := 0
	for part in parts:
		var arrays: Array = part.arrays
		for i in arrays[Mesh.ARRAY_INDEX]:
			indices.append(i + count)
		uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		count += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

	# Frames: every clip sampled at FPS; loops exclude their end pose.
	var frames: Array[Array] = []   # [positions, normals]
	var clips := {}
	for role in entry.clips:
		if skel == null:
			clips[role] = Vector4(frames.size(), 1, FPS, 1.0)
			frames.append(_pose(skel, parts, turn))
			continue
		var anim_name: String = entry.clips[role][0]
		var loops: bool = entry.clips[role][1]
		var length := player.get_animation(anim_name).length
		var n := maxi(1, roundi(length * FPS)) + (0 if loops else 1)
		clips[role] = Vector4(frames.size(), n, FPS, 1.0 if loops else 0.0)
		player.play(anim_name)
		for f in n:
			player.seek(minf(f / FPS, length), true)
			frames.append(_pose(skel, parts, turn))

	var width := mini(count, MAX_WIDTH)
	var rows := ceili(float(count) / width)
	# Positions are stored as 8 bits per axis within the bounds of every pose:
	# a few millimetres of error at crowd scale, half the size of half floats.
	var bounds := AABB((frames[0][0] as PackedVector3Array)[0], Vector3.ZERO)
	for f in frames.size():
		for p in frames[f][0] as PackedVector3Array:
			bounds = bounds.expand(p)
	bounds = bounds.grow(0.001)
	var pos_img := Image.create_empty(width, rows * frames.size(), false, Image.FORMAT_RGB8)
	var nrm_img := Image.create_empty(width, rows * frames.size(), false, Image.FORMAT_RGB8)
	for f in frames.size():
		var p: PackedVector3Array = frames[f][0]
		var nn: PackedVector3Array = frames[f][1]
		for v in count:
			var at := Vector2i(v % width, f * rows + v / width)
			var q := (p[v] - bounds.position) / bounds.size
			pos_img.set_pixelv(at, Color(q.x, q.y, q.z, 1.0))
			var n3 := nn[v] * 0.5 + Vector3(0.5, 0.5, 0.5)
			nrm_img.set_pixelv(at, Color(n3.x, n3.y, n3.z, 1.0))

	var rest := []
	rest.resize(Mesh.ARRAY_MAX)
	rest[Mesh.ARRAY_VERTEX] = frames[0][0]
	rest[Mesh.ARRAY_NORMAL] = frames[0][1]
	rest[Mesh.ARRAY_TEX_UV] = uvs
	rest[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rest)
	mesh.custom_aabb = bounds

	var mask := Image.create_empty(ATLAS_GRID.x, ATLAS_GRID.y, false, Image.FORMAT_R8)
	for cell in entry.team:
		mask.set_pixelv(cell, Color(1, 0, 0))

	var bake := CrowdBake.new()
	bake.mesh = mesh
	bake.positions = ImageTexture.create_from_image(pos_img)
	bake.normals = ImageTexture.create_from_image(nrm_img)
	bake.albedo = load(ATLAS % entry.atlas)
	bake.team_mask = ImageTexture.create_from_image(mask)
	bake.width = width
	bake.rows_per_frame = rows
	bake.clips = clips
	bake.bounds = bounds
	bake.height = bounds.end.y
	return bake


## A part is one mesh moving as a unit: skinned (skin set), carried by a bone
## (bone >= 0), or fixed to the model (neither).
## Parts: skinned meshes under the skeleton, the named KayKit props on bone
## attachments, and in-house builds in the right hand (or fixed, for a static model).
func _parts(skel: Skeleton3D, entry: Dictionary) -> Array[Dictionary]:
	var parts: Array[Dictionary] = []
	var hand := -1
	if skel != null:
		hand = skel.find_bone("handslot.r")
		for child in skel.get_children():
			if child is MeshInstance3D and child.skin != null:
				parts.append({skin = child.skin, bone = -1, local = Transform3D(), arrays = child.mesh.surface_get_arrays(0)})
			elif child is BoneAttachment3D:
				for prop in child.get_children():
					if prop is MeshInstance3D and entry.get("props", []).has(String(prop.name)):
						parts.append({skin = null, bone = skel.find_bone(child.bone_name), local = prop.transform,
								arrays = prop.mesh.surface_get_arrays(0)})
	for build in entry.get("builds", []):
		if build is Array:
			parts.append({skin = null, bone = skel.find_bone(build[1]), local = Transform3D(Basis(), build[2]),
					arrays = Props.build(build[0], entry.atlas)})
		else:
			parts.append({skin = null, bone = hand, local = GRIP if hand >= 0 else Transform3D(),
					arrays = Props.build(build, entry.atlas)})
	return parts


## The whole character in the current pose: [positions, normals] in model space.
func _pose(skel: Skeleton3D, parts: Array[Dictionary], turn: Transform3D) -> Array:
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	for part in parts:
		var verts: PackedVector3Array = part.arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = part.arrays[Mesh.ARRAY_NORMAL]
		if part.skin == null:
			var carried: Transform3D = skel.get_bone_global_pose(part.bone) if part.bone >= 0 else Transform3D()
			var xf: Transform3D = turn * carried * part.local
			for v in verts.size():
				pos.append(xf * verts[v])
				nrm.append((xf.basis * normals[v]).normalized())
			continue
		var skin: Skin = part.skin
		var mats: Array[Transform3D] = []
		for b in skin.get_bind_count():
			var bone := skin.get_bind_bone(b)
			if bone < 0:
				bone = skel.find_bone(skin.get_bind_name(b))
			mats.append(turn * skel.get_bone_global_pose(bone) * skin.get_bind_pose(b))
		var bones: PackedInt32Array = part.arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = part.arrays[Mesh.ARRAY_WEIGHTS]
		var k := bones.size() / verts.size()   # influences per vertex: 4 or 8
		for v in verts.size():
			var p := Vector3.ZERO
			var n := Vector3.ZERO
			for j in k:
				var w := weights[v * k + j]
				if w == 0.0:
					continue
				var m := mats[bones[v * k + j]]
				p += (m * verts[v]) * w
				n += (m.basis * normals[v]) * w
			pos.append(p)
			nrm.append(n.normalized())
	return [pos, nrm]
