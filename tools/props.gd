extends RefCounted
## In-house props (weapons, the warlord's crown), built from boxes and cylinders. Every face samples
## one cell of a KayKit atlas, so the weapons share the characters' palette and
## bake through the same pipeline. Forward is +Z, the hand grip is at the origin.

const GRID := Vector2(8, 4)
const WOOD := Vector2i(6, 0)
const STEEL := Vector2i(3, 1)
const IRON := Vector2i(4, 0)
const DARK := Vector2i(2, 0)
const GEM := Vector2i(0, 2)       ## silver-white in the knight and barbarian atlases; never team-coloured
## Gold sits in a different cell of each KayKit atlas (sampled: #eac253, #d09745, #ff7c1b).
const GOLD_BY_ATLAS := {knight = Vector2i(4, 1), barbarian = Vector2i(1, 2), rogue = Vector2i(1, 3)}


## `atlas` is the KayKit atlas the prop will be textured from.
static func build(name: String, atlas: String) -> Array:
	var GOLD: Vector2i = GOLD_BY_ATLAS[atlas]
	var m := Builder.new()
	match name:
		"musket":
			m.box(Vector3(0, -0.06, -0.3), Vector3(0.18, 0.26, 0.6), WOOD)    # stock
			m.box(Vector3(0, 0.02, 0.3), Vector3(0.15, 0.14, 0.6), WOOD)      # fore-end
			m.cylinder(Vector3(0, 0.1, -0.05), Vector3(0, 0.1, 1.25), 0.075, 8, IRON)
			m.cylinder(Vector3(0, 0.1, 0.55), Vector3(0, 0.1, 0.65), 0.1, 8, GOLD)   # band
			m.box(Vector3(0, 0.02, 0.0), Vector3(0.08, 0.18, 0.12), STEEL)    # lock
		"gatling":
			m.box(Vector3(0, 0.0, -0.25), Vector3(0.5, 0.45, 0.6), IRON)      # housing
			m.box(Vector3(0, -0.32, -0.2), Vector3(0.14, 0.3, 0.16), WOOD)    # grip
			for k in 6:
				var a := TAU * k / 6.0
				var o := Vector3(cos(a), sin(a), 0) * 0.15
				m.cylinder(o + Vector3(0, 0, 0.05), o + Vector3(0, 0, 1.15), 0.055, 6, STEEL)
			m.cylinder(Vector3(0, 0, 0.35), Vector3(0, 0, 0.45), 0.24, 10, GOLD)  # barrel clamps
			m.cylinder(Vector3(0, 0, 0.98), Vector3(0, 0, 1.06), 0.24, 10, GOLD)
		"cannon":
			m.cylinder(Vector3(0, 0.8, -0.8), Vector3(0, 0.95, 1.0), 0.24, 12, IRON)   # barrel, raised
			m.cylinder(Vector3(0, 0.94, 0.95), Vector3(0, 0.96, 1.12), 0.3, 12, GOLD)  # muzzle ring
			m.cylinder(Vector3(0, 0.79, -0.85), Vector3(0, 0.79, -0.7), 0.27, 12, GOLD) # breech ring
			m.box(Vector3(0, 0.45, -0.3), Vector3(0.62, 0.32, 1.5), WOOD)              # carriage
			for side in [-1.0, 1.0]:
				m.cylinder(Vector3(side * 0.36, 0.42, 0.15), Vector3(side * 0.5, 0.42, 0.15), 0.42, 14, WOOD)
				m.cylinder(Vector3(side * 0.34, 0.42, 0.15), Vector3(side * 0.52, 0.42, 0.15), 0.12, 8, STEEL)
		"crown":
			# Sits on the head: a gold band with five spikes, each tipped with a gem.
			m.cylinder(Vector3(0, 0.0, 0), Vector3(0, 0.22, 0), 0.42, 14, GOLD)
			for k in 5:
				var a := TAU * k / 5.0
				var o := Vector3(cos(a), 0.0, sin(a)) * 0.36
				m.box(o + Vector3(0, 0.34, 0), Vector3(0.13, 0.26, 0.13), GOLD)
				m.box(o + Vector3(0, 0.52, 0), Vector3(0.11, 0.11, 0.11), GEM)
		_:
			push_error("unknown prop %s" % name)
	return m.arrays()


class Builder:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	func arrays() -> Array:
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = verts
		a[Mesh.ARRAY_NORMAL] = normals
		a[Mesh.ARRAY_TEX_UV] = uvs
		a[Mesh.ARRAY_INDEX] = indices
		return a

	func _uv(cell: Vector2i) -> Vector2:
		return (Vector2(cell) + Vector2(0.5, 0.5)) / GRID

	func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, cell: Vector2i) -> void:
		var i := verts.size()
		for p in [a, b, c, d]:
			verts.append(p)
			normals.append(n)
			uvs.append(_uv(cell))
		indices.append_array([i, i + 1, i + 2, i, i + 2, i + 3])

	func box(center: Vector3, size: Vector3, cell: Vector2i) -> void:
		var h := size * 0.5
		for axis in 3:
			for sign in [-1.0, 1.0]:
				var n := Vector3.ZERO
				n[axis] = sign
				var u := Vector3.ZERO
				u[(axis + 1) % 3] = h[(axis + 1) % 3]
				var v := Vector3.ZERO
				v[(axis + 2) % 3] = h[(axis + 2) % 3]
				var c := center + n * h[axis]
				if sign > 0:
					_quad(c - u - v, c - u + v, c + u + v, c + u - v, n, cell)
				else:
					_quad(c - u - v, c + u - v, c + u + v, c - u + v, n, cell)

	func cylinder(from: Vector3, to: Vector3, r: float, sides: int, cell: Vector2i) -> void:
		var axis := (to - from).normalized()
		var u := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
		var v := axis.cross(u)
		for k in sides:
			var a0 := TAU * k / sides
			var a1 := TAU * (k + 1) / sides
			var d0 := u * cos(a0) + v * sin(a0)
			var d1 := u * cos(a1) + v * sin(a1)
			_quad(from + d0 * r, from + d1 * r, to + d1 * r, to + d0 * r, (d0 + d1).normalized(), cell)
			_quad(to, to + d0 * r, to + d1 * r, to, axis, cell)              # end cap (fan as degenerate quads)
			_quad(from, from + d1 * r, from + d0 * r, from, -axis, cell)
