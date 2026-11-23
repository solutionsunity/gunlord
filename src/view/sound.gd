class_name Sound
extends Node
## Plays the battle. Reads simulation events, never writes them. Each sound is
## one player with a few overlapping voices, a little random pitch, and a
## minimum gap between starts, so a hundred crossbows read as a volley, not noise.
## A battle can still ask for dozens of sounds at once, and summed they clip,
## dragging the music down with them. So all sounds share a budget of voices:
## the busy ones (rapid fire, hits) start only while few voices play, the loud
## ones (cannon, blasts, the fallen) while some do, and the ones that tell the
## player something (pickups, jingles) always. Many of one sound asked for in
## the same frame start once, a little louder.

const KENNEY := "res://assets/third_party/kenney-%s/%s.ogg"
const BOSS_SIZE := 2.0
const MUSIC := "res://assets/third_party/opengameart-music/%s.ogg"
const FADE := 1.2                 ## seconds a track takes to fade in or out
const VOICES := [99, 10, 6]       ## per tier (0 tells, 1 loud, 2 busy): voices playing at most before a start is dropped
const GROUP_DB := 2.0             ## louder per doubling of one sound asked for in a frame
const GROUP_MAX_DB := 6.0

## track -> [file, volume dB]
const TRACKS := {
	battle = ["determined_pursuit_loop", -10.0],
	map = ["fantasy_orchestral_theme", -9.0],
}

## key -> [streams, volume dB, voices, minimum gap in seconds, tier]
var _kit := {}
var _players := {}
var _last := {}
var _length := {}                 ## key -> seconds its longest stream lasts
var _playing := PackedFloat32Array()   ## when each voice started by the budget ends
var _tracks := {}                 ## track -> AudioStreamPlayer
var _track: StringName            ## the track playing, or empty


func _ready() -> void:
	_kit = {
		fire_crossbow = [[Synth.crossbow()], -14.0, 6, 0.05, 2],
		fire_gun = [[Synth.musket()], -12.0, 4, 0.07, 2],
		fire_gatling = [[Synth.gatling()], -16.0, 4, 0.05, 2],
		fire_cannon = [[Synth.cannon()], -6.0, 3, 0.2, 1],
		fire_rocket = [[Synth.rocket()], -14.0, 3, 0.12, 1],
		fire_drone = [[Synth.gatling()], -22.0, 2, 0.1, 2],
		zap = [[Synth.zap()], -14.0, 3, 0.06, 2],
		surge = [[Synth.surge()], -4.0, 1, 0.3, 0],
		shield = [[Synth.shield()], -10.0, 2, 0.12, 1],
		hit_flesh = [_kenney("impact-sounds", "impactPunch_medium_%03d", 5), -16.0, 4, 0.05, 2],
		hit_glass = [_kenney("impact-sounds", "impactGlass_light_%03d", 5), -12.0, 4, 0.06, 2],
		hit_stone = [_kenney("impact-sounds", "impactMining_%03d", 5), -14.0, 3, 0.08, 2],
		blast = [[_load("sci-fi-sounds", "lowFrequency_explosion_000"), _load("sci-fi-sounds", "lowFrequency_explosion_001")], -6.0, 3, 0.12, 1],
		wounded = [_kenney("impact-sounds", "impactPunch_heavy_%03d", 2), -12.0, 3, 0.08, 1],
		gain = [[_load("interface-sounds", "confirmation_001")], -6.0, 3, 0.05, 0],
		loss = [[_load("interface-sounds", "error_004")], -4.0, 2, 0.1, 0],
		max = [[_load("interface-sounds", "maximize_006")], -8.0, 2, 0.15, 0],
		boost = [[_load("interface-sounds", "bong_001")], -4.0, 2, 0.1, 0],
		boss_down = [[_load("music-jingles", "jingles_HIT10")], -2.0, 1, 0.5, 0],
		victory = [[_load("music-jingles", "jingles_STEEL03")], -2.0, 1, 1.0, 0],
		defeat = [[_load("music-jingles", "jingles_STEEL01")], -2.0, 1, 1.0, 0],
		start = [[_load("music-jingles", "jingles_PIZZI15")], -4.0, 1, 1.0, 0],
		click = [[_load("interface-sounds", "click_002")], -6.0, 2, 0.05, 0],
	}
	for key in _kit:
		var spec: Array = _kit[key]
		var pool := AudioStreamRandomizer.new()
		_length[key] = 0.0
		for s in spec[0]:
			pool.add_stream(-1, s)
			_length[key] = maxf(_length[key], s.get_length())
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


## Starts `key`, asked for `asked` times this frame, if its gap and the budget allow.
func play(key: StringName, asked := 1) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var spec: Array = _kit[key]
	if now - _last.get(key, -10.0) < spec[3]:
		return
	var still := PackedFloat32Array()
	for end in _playing:
		if end > now:
			still.append(end)
	_playing = still
	if _playing.size() >= VOICES[spec[4]]:
		return
	_last[key] = now
	_playing.append(now + _length[key])
	_players[key].volume_db = spec[1] + minf(GROUP_DB * log(asked) / log(2.0), GROUP_MAX_DB)
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
	var asked := {}   # key -> times asked this frame, in the order first asked
	for e in b.events:
		var key := _key(e, b)
		if key != &"":
			asked[key] = asked.get(key, 0) + 1
	for key in asked:
		play(key, asked[key])
		if key == &"victory" or key == &"defeat":
			music(&"")


## The sound an event makes, or empty.
func _key(e: Dictionary, b: Battle) -> StringName:
	match e.kind:
		&"fire":
			return StringName("fire_" + String(b.arsenal[e.weapon].id))
		&"zap":
			return &"zap"
		&"shielded":
			return &"shield"
		&"hit":
			if e.splash > 0.0:
				return &"blast"
			var target: ObjectDef = e.target
			if target.enemy:
				return &"hit_flesh"
			return &"hit_glass" if target.look == ObjectDef.Look.PANEL else &"hit_stone"
		&"payout":
			return e.tone
		&"death":
			if not e.enemy:
				return &"wounded"
			if e.size >= BOSS_SIZE:
				return &"boss_down"
		&"end":
			return &"victory" if e.won else &"defeat"
	return &""


func _kenney(pack: String, pattern: String, count: int) -> Array:
	var out := []
	for i in count:
		out.append(_load(pack, pattern % i))
	return out


func _load(pack: String, name: String) -> AudioStream:
	return load(KENNEY % [pack, name])
