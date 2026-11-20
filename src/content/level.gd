class_name Level
extends RefCounted
## One level as data: its spawn timeline and the rules that frame it.

var timeline: Array[Dictionary] = []   ## spawn events sorted by time
var waves := 0
var capacity := 0                      ## the squad's maximum size


func _init(p_timeline: Array[Dictionary], p_waves: int, p_capacity: int) -> void:
	timeline = p_timeline
	waves = p_waves
	capacity = p_capacity
