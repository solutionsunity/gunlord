class_name Grid
extends RefCounted
## Uniform grid over the lane, rebuilt every tick with a counting sort.
## A projectile only tests objects in its own cell and the eight around it,
## so CELL must be at least the largest object radius plus the hit margin.

const CELL := 2.0
const X0 := -8.0
const Z0 := -80.0
const COLS := 8
const ROWS := 46
const HIT_MARGIN := 0.25

var _start := PackedInt32Array()   ## cell c holds _items[_start[c] .. _start[c + 1]]
var _items := PackedInt32Array()
var _cell := PackedInt32Array()


func build(lane: Lane) -> void:
	var n := lane.size()
	_start.resize(COLS * ROWS + 1)
	_start.fill(0)
	_cell.resize(n)
	_items.resize(n)
	for i in n:
		var cx := clampi(int(floor((lane.x[i] - X0) / CELL)), 0, COLS - 1)
		var cz := clampi(int(floor((lane.z[i] - Z0) / CELL)), 0, ROWS - 1)
		var c := cz * COLS + cx
		_cell[i] = c
		_start[c + 1] += 1
	for c in COLS * ROWS:
		_start[c + 1] += _start[c]
	var cursor := _start.duplicate()
	for i in n:
		var c := _cell[i]
		_items[cursor[c]] = i
		cursor[c] += 1


func first_hit(lane: Lane, px: float, pz: float, skip_serial: int, hits_traps: bool) -> int:
	var cx := int(floor((px - X0) / CELL))
	var cz := int(floor((pz - Z0) / CELL))
	for gz in range(cz - 1, cz + 2):
		if gz < 0 or gz >= ROWS or _start[gz * COLS] == _start[gz * COLS + COLS]:
			continue   # off the grid, or a row with nothing in it
		for gx in range(cx - 1, cx + 2):
			if gx < 0 or gx >= COLS:
				continue
			var c := gz * COLS + gx
			for k in range(_start[c], _start[c + 1]):
				var i := _items[k]
				if not lane.alive[i] or lane.serial[i] == skip_serial:
					continue
				var d := lane.def[i]
				if d.is_trap() and not hits_traps:
					continue
				var r := d.radius + HIT_MARGIN
				if (lane.x[i] - px) ** 2 + (lane.z[i] - pz) ** 2 <= r * r:
					return i
	return -1
