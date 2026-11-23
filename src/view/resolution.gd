class_name Resolution
extends Node
## How many pixels the 3D scene is rendered at. The HUD and text are drawn
## apart, at the screen's full resolution, so only the scene is scaled.
##
## A budget, not a device list: the game is laid out for a 720x1280 frame,
## and the scene looks crisp at about 1.25 times that (BUDGET pixels). The
## window's real pixel count is known before the first frame, so the scene
## starts at sqrt(BUDGET / pixels), never above 1. A phone browser can report
## several times what the eye can use (5.6 M pixels on a 2.6 M-pixel screen).
##
## Then it adapts: over each SPAN of frames, if the average frame is slower
## than SLOW_MS the scale steps down, to FLOOR at least; with headroom (under
## FAST_MS) it steps back up, never past the budget's start. That absorbs what
## a count of pixels can't know: a weaker GPU, a hot phone, a battery saver.

const BUDGET := 900.0 * 1600.0
const FLOOR := 0.35
const SLOW_MS := 33.0         ## below 30 frames a second
const FAST_MS := 22.0
const DOWN := 0.9
const UP := 1.05
const SPAN := 1.0             ## seconds of frames each decision averages
const HITCH := 0.25           ## a frame this long is a stall (a hidden tab, a load), not load: the span starts over

var ceiling := 1.0            ## the budget's scale for this window
var scale := 1.0
var _time := 0.0
var _frames := 0


func _ready() -> void:
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().size_changed.connect(_fit)
	_fit()


## Restarts from the budget for the window's present size.
func _fit() -> void:
	var size := get_viewport().get_texture().get_size()
	ceiling = minf(1.0, sqrt(BUDGET / maxf(size.x * size.y, 1.0)))
	_apply(ceiling)


func _process(delta: float) -> void:
	if delta > HITCH:
		_time = 0.0
		_frames = 0
		return
	_time += delta
	_frames += 1
	if _time < SPAN:
		return
	var frame := _time / _frames * 1000.0
	_time = 0.0
	_frames = 0
	if frame > SLOW_MS and scale > FLOOR:
		_apply(maxf(scale * DOWN, FLOOR))
	elif frame < FAST_MS and scale < ceiling:
		_apply(minf(scale * UP, ceiling))


func _apply(s: float) -> void:
	scale = s
	get_viewport().scaling_3d_scale = s
