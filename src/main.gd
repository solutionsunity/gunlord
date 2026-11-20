extends Node3D
## Wires one Battle to its View, Hud and the player's input.
## Drag (finger or mouse) or the arrow keys steer the squad.

const DRAG_GAIN := 0.022    ## metres of steering per pixel dragged
const KEY_SPEED := 14.0     ## metres per second when steering with keys

var _battle: Battle
var _view := View.new()
var _hud := Hud.new()


func _ready() -> void:
	add_child(_view)
	add_child(_hud)
	var models: Array[StringName] = []
	for w in Content.weapons():
		models.append(w.model)
	for d in Content.objects().values():
		models.append(d.model)
	_view.prepare(models)
	_start()


func _start() -> void:
	_battle = Battle.new(Content.weapons(), Content.objects(), Level01.build())


func _physics_process(delta: float) -> void:
	_battle.squad.steer(Input.get_axis(&"ui_left", &"ui_right") * KEY_SPEED * delta)
	if _view.freeze > 0.0:
		_view.freeze -= delta   # hit-stop: the battle holds still for a beat
		return
	_battle.tick(delta)


func _process(delta: float) -> void:
	_view.draw(_battle, delta)
	_hud.draw(_battle)


func _unhandled_input(event: InputEvent) -> void:
	if _battle.state != Battle.State.RUNNING:
		if event is InputEventMouseButton and event.pressed:
			_start()
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_battle.squad.steer(event.relative.x * DRAG_GAIN)
