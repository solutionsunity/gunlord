class_name CrowdBake
extends Resource
## A character baked for crowd rendering. The rest mesh only fixes vertex order
## and topology. The crowd shader replaces each vertex with its position in
## the current animation frame, sampled from `positions` by VERTEX_ID.
## Produced by tools/bake_crowd.gd.

@export var mesh: ArrayMesh
@export var positions: ImageTexture      ## RGB8, position within `bounds`; a frame spans rows_per_frame rows of `width` texels
@export var bounds := AABB()             ## every position the character takes, over all its clips
@export var normals: ImageTexture        ## RGB8, normal * 0.5 + 0.5, same layout
@export var albedo: Texture2D
@export var team_mask: ImageTexture      ## one texel per atlas cell; 1 = takes the team colour
@export var width := 0
@export var rows_per_frame := 1
@export var clips := {}                  ## role -> Vector4(first frame, frame count, fps, loops 1/0)
@export var height := 0.0                ## standing height in model units


func material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://src/view/crowd.gdshader")
	m.set_shader_parameter(&"albedo", albedo)
	m.set_shader_parameter(&"team_mask", team_mask)
	m.set_shader_parameter(&"positions", positions)
	m.set_shader_parameter(&"normals", normals)
	m.set_shader_parameter(&"width", width)
	m.set_shader_parameter(&"rows_per_frame", rows_per_frame)
	m.set_shader_parameter(&"bounds_min", bounds.position)
	m.set_shader_parameter(&"bounds_size", bounds.size)
	return m
