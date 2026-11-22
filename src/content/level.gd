class_name Level
extends RefCounted
## One level as data: its spawn timeline and the rules that frame it.

var index := 0
var name := ""
var theme: StringName                  ## the stage's time of day
var timeline: Array[Dictionary] = []   ## spawn events sorted by time
var waves := 0
var capacity := 0                      ## the squad's maximum size
var duration := 90.0                   ## the clock; it paces the waves, it does not decide the result
var speed := 3.0                       ## lane speed at the start, m/s
var accel := 0.02                      ## lane speed added per second: the main difficulty dial
var walls := PackedFloat32Array([-3.25, 3.25])   ## x of each low wall along the deck: the stage's plan
var start := [[&"crossbow", 10]]       ## the squad it opens with: [weapon id, count] pairs
var loadout := {}                      ## relic id -> level the squad brings (see Relics)


func _init(p_timeline: Array[Dictionary], p_waves: int, p_capacity: int) -> void:
	timeline = p_timeline
	waves = p_waves
	capacity = p_capacity
