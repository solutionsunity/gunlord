class_name Battle
extends RefCounted
## One run of one level. Owns the order of every step in a tick; the parts it
## coordinates (squad, lane, shots, grid) know nothing about each other's
## timing. The tick is deterministic: same inputs, same run.

enum State { RUNNING, WON, LOST }

const DURATION := 90.0       ## the clock paces the waves; it does not decide the result
const START_UNITS := 10

var state := State.RUNNING
var time := 0.0
var wave := 0
var waves := 0
var peak_units := 0
var squad: Squad
var lane := Lane.new()
var shots := Shots.new()
var grid := Grid.new()
## Presentation events for the view, which drains them each frame. Kinds:
##   payout {at, text, color}
##   death  {at, model, size, enemy}   one per fallen soldier on either side
##   fire   {at, weapon}               one per shot (a spread counts once)
##   hit    {at, weapon, splash}       one per projectile impact
var events: Array[Dictionary] = []

var _objects: Dictionary
var _timeline: Array[Dictionary]
var _next := 0
var _weapon_index := {}


func _init(roster: Array[WeaponDef], objects: Dictionary, level: Level) -> void:
	_objects = objects
	_timeline = level.timeline
	waves = level.waves
	for w in roster.size():
		_weapon_index[roster[w].id] = w
	squad = Squad.new(roster, level.capacity)
	squad.add(_weapon_index[&"crossbow"], START_UNITS)
	peak_units = START_UNITS


## The lane's own speed is the main difficulty dial.
func lane_speed() -> float:
	return 3.0 + time * 0.02


func tick(dt: float) -> void:
	if state != State.RUNNING:
		return
	time += dt
	_spawn()
	squad.move(dt)
	lane.advance(dt, lane_speed(), squad.x)
	_contacts(dt)
	grid.build(lane)
	squad.fire(dt, lane, shots, lane_speed())
	shots.advance(dt, lane, grid)
	_shot_events()
	_payouts()
	lane.compact()
	peak_units = maxi(peak_units, squad.total())
	if state == State.RUNNING and squad.total() == 0:
		state = State.LOST


func _spawn() -> void:
	while _next < _timeline.size() and _timeline[_next].t <= time:
		var e: Dictionary = _timeline[_next]
		var d: ObjectDef = _objects[e.id]
		lane.spawn(d, e.x, Lane.SPAWN_Z + e.get("z", 0.0), e.get("hp", d.hp), e.get("amount", d.amount))
		wave = maxi(wave, e.get("wave", 0))
		_next += 1


func _contacts(dt: float) -> void:
	var r := squad.radius()
	for i in lane.size():
		var d := lane.def[i]
		if not lane.alive[i] or not d.enemy:
			continue
		var front := Squad.Z - r - d.radius
		var touching := lane.z[i] >= front and absf(lane.x[i] - squad.x) < r + d.radius
		var breached := lane.z[i] > Squad.Z + 1.0
		if not touching and not breached:
			continue
		if d.persistent:
			lane.z[i] = minf(lane.z[i], front)
			_lose(squad.wound(d.contact_kills * dt))
		else:
			_lose(int(d.contact_kills))
			lane.alive[i] = 0
			_enemy_died(i)


func _payouts() -> void:
	for i in lane.destroyed:
		var d := lane.def[i]
		if d.enemy:
			_enemy_died(i)
		var n := lane.amount[i]
		var at := Vector3(lane.x[i], 1.5, lane.z[i])
		match d.payout:
			ObjectDef.Payout.ADD_UNITS:
				var added := squad.enlist(_weapon_index[d.weapon], int(n))
				_callout(at, d.caption_for(n) if added == int(n) else "MAX", d.color)
			ObjectDef.Payout.MULTIPLY:
				var grown := squad.multiply(_weapon_index[d.weapon], n)
				_callout(at, "+%d" % grown if grown > 0 or squad.total() < squad.capacity else "MAX", d.color)
			ObjectDef.Payout.REMOVE_UNITS:
				_lose(int(n))
				_callout(at, d.caption_for(n), d.color)
			ObjectDef.Payout.DAMAGE_BONUS:
				squad.damage_mult += n
				_callout(at, d.caption_for(n), d.color)
		if d.final:
			state = State.WON


func _shot_events() -> void:
	for k in range(0, shots.fired.size(), 3):
		events.append({kind = &"fire", at = Vector3(shots.fired[k], 0.0, shots.fired[k + 1]), weapon = int(shots.fired[k + 2])})
	for k in range(0, shots.impacts.size(), 4):
		events.append({kind = &"hit", at = Vector3(shots.impacts[k], 0.0, shots.impacts[k + 1]),
				weapon = int(shots.impacts[k + 2]), splash = shots.impacts[k + 3]})
	shots.fired.clear()
	shots.impacts.clear()


## Removes n units from the rim of the squad, announcing each one's death.
func _lose(n: int) -> void:
	var total := squad.total()
	for k in range(total - 1, maxi(total - n, 0) - 1, -1):
		var p := squad.unit_position(k)
		var wd := squad.weapons[squad.weapon_at(k)]
		events.append({kind = &"death", at = Vector3(p.x, 0.0, p.y), model = wd.model, size = wd.size, enemy = false})
	squad.remove_outer(n)


func _enemy_died(i: int) -> void:
	var d := lane.def[i]
	events.append({kind = &"death", at = Vector3(lane.x[i], 0.0, lane.z[i]), model = d.model, size = d.size, enemy = true})


func _callout(at: Vector3, text: String, color: Color) -> void:
	events.append({kind = &"payout", at = at, text = text, color = color})
