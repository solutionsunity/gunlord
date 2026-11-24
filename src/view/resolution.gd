class_name Resolution
extends Node
## How many pixels the 3D scene is rendered at. The HUD and text are drawn
## apart, at the screen's full resolution, so only the scene is scaled.
##
## A budget, not a device list: the game is laid out for a 720x1280 frame,
## and the scene looks crisp at about 1.25 times that (BUDGET pixels). The
## window's real pixel count is known before the first frame, so the scene
## renders at sqrt(BUDGET / pixels), never above 1. A phone browser can report
## several times what the eye can use (5.6 M pixels on a 2.6 M-pixel screen).
##
## The scale is fixed for a window size; it does not adapt to load. A browser
## gives no GPU timer, and the frame time left after the game's own work also
## holds the wait for the screen's refresh, so no figure the game can read
## says whether pixels are the cost. Weaker devices choose Graphics: light.

const BUDGET := 900.0 * 1600.0


func _ready() -> void:
	get_viewport().scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().size_changed.connect(_fit)
	_fit()


func _fit() -> void:
	var size := get_viewport().get_texture().get_size()
	get_viewport().scaling_3d_scale = minf(1.0, sqrt(BUDGET / maxf(size.x * size.y, 1.0)))
