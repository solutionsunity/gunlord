class_name Settings
extends RefCounted
## The player's settings, kept on the device: music and sound effects on or
## off. They act through two audio buses, so muting is one switch per bus.

const PATH := "user://settings.cfg"
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

var path := PATH           ## where settings are kept; empty keeps them in memory only (tests)
var music := true
var sound := true


static func load_saved() -> Settings:
	var s := Settings.new()
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		s.music = cfg.get_value("audio", "music", true)
		s.sound = cfg.get_value("audio", "sound", true)
	return s


func muted() -> bool:
	return not music and not sound


## Applies the settings to the audio buses, creating the buses on first use.
func apply() -> void:
	AudioServer.set_bus_mute(_bus(MUSIC_BUS), not music)
	AudioServer.set_bus_mute(_bus(SFX_BUS), not sound)


func save() -> void:
	apply()
	if path.is_empty():
		return
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music)
	cfg.set_value("audio", "sound", sound)
	cfg.save(path)


static func _bus(name: StringName) -> int:
	var i := AudioServer.get_bus_index(name)
	if i < 0:
		i = AudioServer.bus_count
		AudioServer.add_bus(i)
		AudioServer.set_bus_name(i, name)
		AudioServer.set_bus_send(i, &"Master")
	return i
