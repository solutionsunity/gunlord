extends SceneTree
## Balance and drift probe.
## Authored nodes: every bot plays each; the sweeping bot must win and the idle
## bot must lose. Forged nodes: every SAMPLE-th is replayed by the sweeping bot
## and must reproduce the margin recorded when it was forged; the simulation is
## deterministic, so any difference means a change moved the balance and the
## map must be re-forged on purpose.
##   godot --headless --path . -s tests/simulate.gd -- [all]   (all: replay every forged node)
## Lines: "L<n> <bot> WON|LOST ..." and "N<n> sweep margin <now> recorded <then> ok|DRIFT".

const Bots := preload("res://tools/bots.gd")
const SAMPLE := 10
const DRIFT := 0.002


func _init() -> void:
	for node in Stages.AUTHORED.size():
		for policy in [&"idle", &"sweep", &"greedy"]:
			var r: Dictionary = Bots.play(Stages.build(node), policy)
			print("L%d %-7s %-5s t=%5.1fs wave=%2d units=%4d peak=%4d margin=%.2f" % [
				node + 1, policy, "WON" if r.won else "LOST", r.time, r.wave, r.survivors, r.peak, r.margin])
	var every := 1 if OS.get_cmdline_user_args().has("all") else SAMPLE
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Stages.FORGED))
	for k in range(0, data.nodes.size(), every):
		var entry: Dictionary = data.nodes[k]
		var node := int(entry.node)
		var r: Dictionary = Bots.play(Stages.build(node), &"sweep")
		var drift := absf(r.margin - float(entry.margin)) > DRIFT
		print("N%d sweep margin %.3f recorded %.3f %s" % [node + 1, r.margin, entry.margin, "DRIFT" if drift else "ok"])
	quit()
