class_name Settings
extends RefCounted
## The player's settings, kept on the device: overall, music and effects
## volumes (each 0 to 1, where 0 is silence), and which side of the screen
## the weapon badges sit on. Volumes act through the audio buses: Master, and
## Music and SFX under it.

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"
const SIDES := [&"right", &"left"]

var path := PATH           ## where settings are kept; empty keeps them in memory only (tests)
var master := 1.0          ## 0..1
var music := 1.0           ## 0..1
var sound := 1.0           ## 0..1, the effects
var badges: StringName = &"right"   ## the side of the screen the weapon badges sit on


static func load_saved() -> Settings:
	var s := Settings.new()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		s.master = cfg.get_value("audio", "master", 1.0)
		s.music = cfg.get_value("audio", "music_volume", 1.0)
		s.sound = cfg.get_value("audio", "sound_volume", 1.0)
		s.badges = StringName(cfg.get_value("hud", "badges", "right"))
	return s


## Applies the settings to the audio buses, creating Music and SFX on first use.
func apply() -> void:
	_set_bus(0, master)
	_set_bus(_bus(MUSIC_BUS), music)
	_set_bus(_bus(SFX_BUS), sound)


func save() -> void:
	apply()
	if path.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master)
	cfg.set_value("audio", "music_volume", music)
	cfg.set_value("audio", "sound_volume", sound)
	cfg.set_value("hud", "badges", String(badges))
	cfg.save(path)


static func _set_bus(i: int, level: float) -> void:
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(level, 0.0001)))
	AudioServer.set_bus_mute(i, level <= 0.0)


static func _bus(name: StringName) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		i = AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, &"Master")
	return i
