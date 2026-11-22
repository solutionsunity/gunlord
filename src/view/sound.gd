class_name Sound
extends Node
## Plays the battle. Reads simulation events, never writes them. Each sound is
## one player with a few overlapping voices, a little random pitch, and a
## minimum gap between starts, so a hundred crossbows read as a volley, not noise.

const KENNEY := "res://assets/third_party/kenney-%s/%s.ogg"
const BOSS_SIZE := 2.0

## key -> [streams, volume dB, voices, minimum gap in seconds]
var _kit := {}
var _players := {}
var _last := {}
const MUSIC := "res://assets/third_party/opengameart-music/%s.ogg"
const FADE := 1.2                 ## seconds a track takes to fade in or out

## track -> [file, volume dB]
const TRACKS := {
	battle = ["determined_pursuit_loop", -10.0],
	map = ["fantasy_orchestral_theme", -9.0],
}

var _tracks := {}                 ## track -> AudioStreamPlayer
var _track: StringName            ## the track playing, or empty


func _ready() -> void:
	_kit = {
		fire_crossbow = [[Synth.crossbow()], -14.0, 6, 0.05],
		fire_gun = [[Synth.musket()], -12.0, 4, 0.07],
		fire_gatling = [[Synth.gatling()], -16.0, 4, 0.05],
		fire_cannon = [[Synth.cannon()], -6.0, 3, 0.2],
		fire_rocket = [[Synth.rocket()], -14.0, 3, 0.12],
		fire_drone = [[Synth.gatling()], -22.0, 2, 0.1],
		zap = [[Synth.zap()], -14.0, 3, 0.06],
		surge = [[Synth.surge()], -4.0, 1, 0.3],
		hit_flesh = [_kenney("impact-sounds", "impactPunch_medium_%03d", 5), -16.0, 4, 0.05],
		hit_glass = [_kenney("impact-sounds", "impactGlass_light_%03d", 5), -12.0, 4, 0.06],
		hit_stone = [_kenney("impact-sounds", "impactMining_%03d", 5), -14.0, 3, 0.08],
		blast = [[_load("sci-fi-sounds", "lowFrequency_explosion_000"), _load("sci-fi-sounds", "lowFrequency_explosion_001")], -6.0, 3, 0.12],
		wounded = [_kenney("impact-sounds", "impactPunch_heavy_%03d", 2), -12.0, 3, 0.08],
		gain = [[_load("interface-sounds", "confirmation_001")], -6.0, 3, 0.05],
		loss = [[_load("interface-sounds", "error_004")], -4.0, 2, 0.1],
		max = [[_load("interface-sounds", "maximize_006")], -8.0, 2, 0.15],
		boost = [[_load("interface-sounds", "bong_001")], -4.0, 2, 0.1],
		boss_down = [[_load("music-jingles", "jingles_HIT10")], -2.0, 1, 0.5],
		victory = [[_load("music-jingles", "jingles_STEEL03")], -2.0, 1, 1.0],
		defeat = [[_load("music-jingles", "jingles_STEEL01")], -2.0, 1, 1.0],
		start = [[_load("music-jingles", "jingles_PIZZI15")], -4.0, 1, 1.0],
		click = [[_load("interface-sounds", "click_002")], -6.0, 2, 0.05],
	}
	for key in _kit:
		var spec: Array = _kit[key]
		var pool := AudioStreamRandomizer.new()
		for s in spec[0]:
			pool.add_stream(-1, s)
		pool.random_pitch = 1.08
		pool.random_volume_offset_db = 1.5
		var player := AudioStreamPlayer.new()
		player.bus = Settings.SFX_BUS
		player.stream = pool
		player.volume_db = spec[1]
		player.max_polyphony = spec[2]
		add_child(player)
		_players[key] = player
	for track in TRACKS:
		var stream: AudioStreamOggVorbis = load(MUSIC % TRACKS[track][0])
		stream.loop = true
		var player := AudioStreamPlayer.new()
		player.stream = stream
		player.bus = Settings.MUSIC_BUS
		# Streamed, decoded a little at a time. On the web Godot defaults to
		# "sample" playback, which hands the browser the whole track decoded at
		# once: tens of megabytes for minutes of music, which phones can fail to
		# play. Short effects stay samples, for low latency.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player)
		_tracks[track] = player


func play(key: StringName) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last.get(key, -10.0) < _kit[key][3]:
		return
	_last[key] = now
	_players[key].play()


## Crossfades to `track` (battle or map); an empty track fades to silence.
func music(track: StringName) -> void:
	if track == _track:
		return
	if _track != &"":
		var old: AudioStreamPlayer = _tracks[_track]
		var out := create_tween()
		out.tween_property(old, "volume_db", -60.0, FADE)
		out.tween_callback(old.stop)
	_track = track
	if track == &"":
		return
	var player: AudioStreamPlayer = _tracks[track]
	player.volume_db = -60.0
	player.play()
	create_tween().tween_property(player, "volume_db", TRACKS[track][1], FADE)


func hear(b: Battle) -> void:
	for e in b.events:
		match e.kind:
			&"fire":
				play(StringName("fire_" + String(b.arsenal[e.weapon].id)))
			&"zap":
				play(&"zap")
			&"hit":
				if e.splash > 0.0:
					play(&"blast")
				else:
					var target: ObjectDef = e.target
					if target.enemy:
						play(&"hit_flesh")
					elif target.look == ObjectDef.Look.PANEL:
						play(&"hit_glass")
					else:
						play(&"hit_stone")
			&"payout":
				play(e.tone)
			&"death":
				if not e.enemy:
					play(&"wounded")
				elif e.size >= BOSS_SIZE:
					play(&"boss_down")
			&"end":
				music(&"")
				play(&"victory" if e.won else &"defeat")


func _kenney(pack: String, pattern: String, count: int) -> Array:
	var out := []
	for i in count:
		out.append(_load(pack, pattern % i))
	return out


func _load(pack: String, name: String) -> AudioStream:
	return load(KENNEY % [pack, name])
