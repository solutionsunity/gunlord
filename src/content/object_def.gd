class_name ObjectDef
extends Resource
## One kind of lane object. Everything that comes down the lane is one of these:
## hit points, a payout when shot down, a behaviour when it reaches the squad.

enum Payout { NONE, ADD_UNITS, MULTIPLY, REMOVE_UNITS, DAMAGE_BONUS }
enum Look { PANEL, PEDESTAL }

@export var id: StringName
@export var enemy := false            ## walks at the squad and fights on contact
@export var hp := 1.0
@export var radius := 0.35
@export var walk := 0.0               ## speed on top of the lane's own speed
@export var seek := 0.0               ## sideways speed toward the squad once out of the walls
@export var contact_kills := 0.0      ## units killed on contact (per second if persistent)
@export var persistent := false       ## stays in contact instead of trading itself
@export var payout := Payout.NONE
@export var amount := 0.0             ## default payout size; spawns may override it
@export var weapon: StringName        ## weapon granted by ADD_UNITS
@export var final := false            ## killing it wins the level
@export var caption := ""             ## "{n}" = amount, "{x}" = amount to one decimal, "{p}" = amount as percent
@export var model: StringName          ## baked character: the enemy itself, or the unit shown on a pedestal
@export var look := Look.PANEL         ## how a pickup stands on the lane: a glass panel or a stone pedestal
@export var size := 1.0               ## visual scale of an enemy (1 = a soldier)
@export var color := Color.WHITE


func is_trap() -> bool:
	return payout == Payout.REMOVE_UNITS


func caption_for(n: float) -> String:
	return caption.format({"n": int(round(n)), "x": snappedf(n, 0.1), "p": int(round(n * 100.0))})
