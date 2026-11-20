class_name Synth
extends RefCounted
## In-house sounds, generated at startup: the weapons' shots and the battle
## drums. Built from decaying noise and sines, so they ship as code, not files.

const RATE := 22050


## Crossbow: a short plucked string under a whip of air.
static func crossbow() -> AudioStreamWAV:
	return _render(0.22, func(t: float, n: float) -> float:
		var string := sin(TAU * (190.0 - 260.0 * t) * t) * exp(-t * 26.0)
		var whip := n * exp(-t * 60.0) * 0.5
		return (string * 0.8 + whip) * 0.7)


## Musket: a sharp crack of noise over a low thump.
static func musket() -> AudioStreamWAV:
	var low := _Lowpass.new(0.35)
	return _render(0.4, func(t: float, n: float) -> float:
		var crack := low.step(n) * exp(-t * 32.0)
		var thump := sin(TAU * 85.0 * t) * exp(-t * 18.0)
		return (crack * 0.9 + thump * 0.6) * 0.7)


## Gatling: one short, bright rattle; it repeats fast in play.
static func gatling() -> AudioStreamWAV:
	var low := _Lowpass.new(0.5)
	return _render(0.09, func(t: float, n: float) -> float:
		return (low.step(n) * 0.8 + sin(TAU * 140.0 * t) * 0.4) * exp(-t * 55.0))


## Cannon: a deep falling boom with a rumble of filtered noise.
static func cannon() -> AudioStreamWAV:
	var low := _Lowpass.new(0.05)
	var lower := _Lowpass.new(0.05)   # two stages: the rumble must be dark, not hiss
	return _render(1.2, func(t: float, n: float) -> float:
		var boom := sin(TAU * (75.0 - 30.0 * t) * t) * exp(-t * 4.5)
		var rumble := lower.step(low.step(n)) * 12.0 * exp(-t * 3.0)
		return (boom * 0.7 + rumble * 0.5) * 0.7)


## The battle march: war drums at 96 BPM, four bars, looping. Kick on 1 and 3,
## snare on 2 and 4, a snare roll closing the fourth bar. Each drum is rendered
## once and mixed in at its beats.
static func march() -> AudioStreamWAV:
	var beat := 60.0 / 96.0
	var bars := 4
	var low := _Lowpass.new(0.2)
	var kick := _samples(0.5, func(t: float, _n: float) -> float:
		return sin(TAU * (60.0 - 25.0 * t) * t) * exp(-t * 9.0) * 0.9)
	var snare := _samples(0.35, func(t: float, n: float) -> float:
		return (low.step(n) * 1.6 + sin(TAU * 190.0 * t) * 0.4) * exp(-t * 16.0) * 0.7)
	var ghost := _samples(0.15, func(t: float, n: float) -> float:
		return low.step(n) * 1.6 * exp(-t * 30.0) * 0.3)
	var length := bars * 4 * beat
	var mix := PackedFloat32Array()
	mix.resize(int(length * RATE))
	for bar in bars:
		for b in 4:
			var at := (bar * 4 + b) * beat
			_mix_in(mix, kick if b % 2 == 0 else snare, at)
			if b == 1 or b == 3:
				_mix_in(mix, ghost, at + beat * 0.75)
		if bar == bars - 1:
			for k in 6:
				_mix_in(mix, ghost, (bar * 4 + 3) * beat + k * beat / 6.0)
	for i in mix.size():
		mix[i] *= 0.6
	var stream := _encode(mix)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = mix.size()
	return stream


static func _mix_in(mix: PackedFloat32Array, sound: PackedFloat32Array, at: float) -> void:
	var start := int(at * RATE)
	for i in mini(sound.size(), mix.size() - start):
		mix[start + i] += sound[i]


## Samples `voice(t, noise)` for `seconds` into a 16-bit mono stream, with a
## few milliseconds of fade at both ends so nothing clicks.
static func _render(seconds: float, voice: Callable) -> AudioStreamWAV:
	return _encode(_samples(seconds, voice))


static func _samples(seconds: float, voice: Callable) -> PackedFloat32Array:
	var n := int(seconds * RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var out := PackedFloat32Array()
	out.resize(n)
	var fade := int(0.004 * RATE)
	for i in n:
		var v: float = voice.call(float(i) / RATE, rng.randf_range(-1.0, 1.0))
		out[i] = v * minf(1.0, minf(float(i) / fade, float(n - 1 - i) / fade))
	return out


static func _encode(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream


## One-pole low-pass filter: keeps noise from sounding like hiss.
class _Lowpass:
	var _k := 0.0
	var _y := 0.0

	func _init(k: float) -> void:
		_k = k

	func step(x: float) -> float:
		_y += _k * (x - _y)
		return _y
