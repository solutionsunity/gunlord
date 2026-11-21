extends SceneTree
## Forges map nodes into assets/map/forged.json. For each node, searches the
## intensity at which the sweeping bot's margin lands on Forge.target(node),
## and checks that the idle bot loses. A stage with a cliff (won easily just
## below some intensity, lost just above it) cannot be tuned; then the next
## variant of the node is tried, up to VARIANTS, keeping the closest.
## Appends to what is already forged.
##   godot --headless --path . -s tools/forge_map.gd -- <nodes to add, default 20>

const Bots := preload("res://tools/bots.gd")
const STEPS := 8              ## bisection steps on intensity
const TOLERANCE := 0.03       ## close enough to the target margin
const LOW := 0.15
const HIGH := 3.5
const VARIANTS := 4
const GOOD_ENOUGH := 0.1      ## stop trying variants once this close


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if not args.is_empty() else 20
	var nodes: Array = []
	if FileAccess.file_exists(Stages.FORGED):
		nodes = JSON.parse_string(FileAccess.get_file_as_string(Stages.FORGED)).nodes
	var start := Stages.AUTHORED.size() + nodes.size()
	for node in range(start, start + count):
		var started := Time.get_ticks_msec()
		var entry := _forge(node)
		nodes.append(entry)
		_save(nodes)
		var spec := Forge.forge(node, entry.intensity, entry.variant)
		print("node %3d v%d %-9s %-20s k=%.3f margin %.2f (target %.2f)  idle %s  %.1fs" % [
			node + 1, entry.variant, spec.character, spec.name,
			entry.intensity, entry.margin, entry.target, "lost" if not entry.idle_won else "WON",
			(Time.get_ticks_msec() - started) / 1000.0])
	quit()


func _forge(node: int) -> Dictionary:
	var goal := Forge.target(node)
	var best := {}
	for variant in VARIANTS:
		var tuned := _tune(node, variant, goal)
		if best.is_empty() or absf(tuned.margin - goal) < absf(best.margin - goal):
			best = tuned
		if absf(best.margin - goal) < GOOD_ENOUGH:
			break
	var idle: Dictionary = Bots.play(Stages.build_spec(Forge.forge(node, best.intensity, best.variant), node), &"idle")
	return {node = node, variant = best.variant, intensity = best.intensity,
			margin = snappedf(best.margin, 0.001), target = snappedf(goal, 0.001), idle_won = idle.won}


## Bisects intensity (on a log scale: it multiplies threats) towards the goal margin.
func _tune(node: int, variant: int, goal: float) -> Dictionary:
	var lo := LOW
	var hi := HIGH
	var best := {}
	for step in STEPS:
		# Snapped as stored, so a replay from the file runs at exactly this intensity.
		var k := snappedf(sqrt(lo * hi), 0.0001)
		var margin: float = Bots.play(Stages.build_spec(Forge.forge(node, k, variant), node), &"sweep").margin
		if best.is_empty() or absf(margin - goal) < absf(best.margin - goal):
			best = {variant = variant, intensity = k, margin = margin}
		if absf(margin - goal) < TOLERANCE:
			break
		if margin > goal:
			lo = k
		else:
			hi = k
	return best


func _save(nodes: Array) -> void:
	var f := FileAccess.open(Stages.FORGED, FileAccess.WRITE)
	f.store_string(JSON.stringify({version = 1, nodes = nodes}, "\t", true, true))
