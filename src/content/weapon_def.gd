class_name WeaponDef
extends Resource
## One weapon. A unit carries exactly one; the squad is a count per weapon.

enum Aim { STRAIGHT, AUTO }

@export var id: StringName
@export var label: String
@export var damage := 1.0
@export var fire_rate := 1.0          ## shots per second, per unit
@export var aim := Aim.STRAIGHT
@export var spread_count := 1         ## projectiles per shot
@export var spread_angle := 0.0       ## degrees across the whole fan
@export var jitter := 0.0             ## degrees of random deviation per projectile
@export var pierce := 0               ## extra objects one projectile passes through
@export var splash := 0.0             ## blast radius on impact, 0 = none
@export var homing := false           ## turns toward the nearest enemy in flight
@export var reach := 70.0             ## metres before the projectile expires
@export var projectile_speed := 35.0
@export var color := Color.WHITE
@export var model: StringName          ## baked character carrying it (assets/baked/<model>.res); empty = placeholder
@export var size := 1.0               ## visual scale of the unit carrying it
@export var projectile: StringName     ## how its shots look: bolt, tracer or ball
