class_name Crowd
extends MultiMeshInstance3D
## One batched draw: a MultiMesh whose instance buffer is rewritten every frame
## and pushed to the renderer in a single call. The renderer repacks and
## re-uploads every instance the MultiMesh holds, drawn or not (on the web it
## does so inside the frame's scripts), so it holds only room for what is
## drawn: a power of two that grows at once and shrinks lazily, up to
## `capacity`. An empty crowd that was already empty sends nothing.

const STRIDE := 20   ## floats per instance: 3x4 transform, colour, custom
const ROOM_MIN := 16

var capacity := 0    ## the most instances it will ever draw
var count := 0
var _buf := PackedFloat32Array()   ## room * STRIDE floats
var _room := 0       ## instances the MultiMesh holds now
var _shown := 0      ## instances drawn by the last upload


func _init(mesh: Mesh, p_capacity: int, material: Material) -> void:
	capacity = p_capacity
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.custom_aabb = AABB(Vector3(-12, -2, -60), Vector3(24, 14, 70))
	multimesh = mm
	material_override = material


func begin() -> void:
	count = 0


## One instance: turned by `yaw` about Y (local +Z ends up along (sin, 0, cos)),
## scaled per axis, then placed at `pos`.
func add(pos: Vector3, yaw: float, scale: Vector3, color: Color, custom := Color()) -> void:
	if count == capacity:
		return
	if (count + 1) * STRIDE > _buf.size():
		_buf.resize(mini(maxi(ROOM_MIN, _buf.size() / STRIDE * 2), capacity) * STRIDE)
	var c := cos(yaw)
	var s := sin(yaw)
	var o := count * STRIDE
	_buf[o] = c * scale.x;   _buf[o + 1] = 0.0;      _buf[o + 2] = s * scale.z;  _buf[o + 3] = pos.x
	_buf[o + 4] = 0.0;       _buf[o + 5] = scale.y;  _buf[o + 6] = 0.0;          _buf[o + 7] = pos.y
	_buf[o + 8] = -s * scale.x; _buf[o + 9] = 0.0;   _buf[o + 10] = c * scale.z; _buf[o + 11] = pos.z
	_buf[o + 12] = color.r;  _buf[o + 13] = color.g; _buf[o + 14] = color.b;     _buf[o + 15] = color.a
	_buf[o + 16] = custom.r; _buf[o + 17] = custom.g; _buf[o + 18] = custom.b;   _buf[o + 19] = custom.a
	count += 1


## Instances the GPU is sent each frame: the room the MultiMesh holds.
func room() -> int:
	return _room


func end() -> void:
	if count == 0 and _shown == 0:
		return
	var room := _buf.size() / STRIDE
	if count * 4 < room and room > ROOM_MIN:   # shrink only when well under, so a crowd near a boundary doesn't churn
		room = mini(maxi(ROOM_MIN, nearest_po2(maxi(count, 1))), capacity)
		_buf.resize(room * STRIDE)
	if room != _room:
		multimesh.instance_count = room   # reallocates; set only when the room changes
		_room = room
	if _room > 0:
		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buf)
	multimesh.visible_instance_count = count
	_shown = count
