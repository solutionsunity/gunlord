class_name Progress
extends RefCounted
## The player's campaign progress, kept on the device: how far the campaign is
## unlocked, and the best result per level.

const PATH := "user://progress.cfg"

var path := PATH           ## where progress is kept; empty keeps it in memory only (tests)
var unlocked := 1          ## levels playable, counting from the first
var best := {}             ## level index -> most units left at a victory


static func load_saved() -> Progress:
	var p := Progress.new()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		p.unlocked = cfg.get_value("campaign", "unlocked", 1)
		p.best = cfg.get_value("campaign", "best", {})
	return p


func record_victory(index: int, units_left: int) -> void:
	unlocked = maxi(unlocked, index + 2)
	best[index] = maxi(best.get(index, 0), units_left)
	_save()


## Back to the start of the map.
func reset() -> void:
	unlocked = 1
	best = {}
	_save()


func _save() -> void:
	if path.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("campaign", "unlocked", unlocked)
	cfg.set_value("campaign", "best", best)
	cfg.save(path)
