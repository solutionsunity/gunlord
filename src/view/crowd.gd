class_name Crowd
extends MultiMeshInstance3D
## One batched draw: a MultiMesh whose whole instance buffer is rewritten every
## frame and pushed to the renderer in a single call.

const STRIDE := 20   ## floats per instance: 3x4 transform, colour, custom

var capacity := 0
var count := 0
var _buf := PackedFloat32Array()


func _init(mesh: Mesh, p_capacity: int, material: Material) -> void:
	capacity = p_capacity
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	mm.custom_aabb = AABB(Vector3(-12, -2, -60), Vector3(24, 14, 70))
	multimesh = mm
	material_override = material
	_buf.resize(capacity * STRIDE)


func begin() -> void:
	count = 0


## One instance: turned by `yaw` about Y (local +Z ends up along (sin, 0, cos)),
## scaled per axis, then placed at `pos`.
func add(pos: Vector3, yaw: float, scale: Vector3, color: Color, custom := Color()) -> void:
	if count == capacity:
		return
	var c := cos(yaw)
	var s := sin(yaw)
	var o := count * STRIDE
	_buf[o] = c * scale.x;   _buf[o + 1] = 0.0;      _buf[o + 2] = s * scale.z;  _buf[o + 3] = pos.x
	_buf[o + 4] = 0.0;       _buf[o + 5] = scale.y;  _buf[o + 6] = 0.0;          _buf[o + 7] = pos.y
	_buf[o + 8] = -s * scale.x; _buf[o + 9] = 0.0;   _buf[o + 10] = c * scale.z; _buf[o + 11] = pos.z
	_buf[o + 12] = color.r;  _buf[o + 13] = color.g; _buf[o + 14] = color.b;     _buf[o + 15] = color.a
	_buf[o + 16] = custom.r; _buf[o + 17] = custom.g; _buf[o + 18] = custom.b;   _buf[o + 19] = custom.a
	count += 1


func end() -> void:
	RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buf)
	multimesh.visible_instance_count = count
