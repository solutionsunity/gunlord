class_name Synth
extends RefCounted
## In-house sounds, generated at startup: the weapons' shots and the surges.
## Built from decaying noise and sines, so they ship as code, not files.

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


## Rocket: a hiss of air that rises as it leaves.
static func rocket() -> AudioStreamWAV:
	var low := _Lowpass.new(0.25)
	return _render(0.5, func(t: float, n: float) -> float:
		var hiss := low.step(n) * (1.0 - exp(-t * 30.0)) * exp(-t * 5.0)
		var tone := sin(TAU * (300.0 + 500.0 * t) * t) * exp(-t * 8.0) * 0.25
		return (hiss * 1.4 + tone) * 0.6)


## Zap: a buzzing crackle, brief.
static func zap() -> AudioStreamWAV:
	return _render(0.14, func(t: float, n: float) -> float:
		var buzz := signf(sin(TAU * 110.0 * t)) * 0.35 + n * 0.5
		return buzz * exp(-t * 28.0) * 0.6)


## Surge: three quick rising chimes.
static func surge() -> AudioStreamWAV:
	return _render(0.7, func(t: float, _n: float) -> float:
		var v := 0.0
		for k in 3:
			var at := t - k * 0.09
			if at > 0.0:
				var f := 660.0 * pow(1.26, k)
				v += (sin(TAU * f * at) + 0.4 * sin(TAU * f * 2.0 * at)) * exp(-at * 7.0)
		return v * 0.3)


## Shield: a blow turned aside, a dull knock under a bright glassy ring.
static func shield() -> AudioStreamWAV:
	var low := _Lowpass.new(0.15)
	return _render(0.45, func(t: float, n: float) -> float:
		var knock := low.step(n) * exp(-t * 40.0)
		var ring := (sin(TAU * 1180.0 * t) + 0.6 * sin(TAU * 1730.0 * t)) * exp(-t * 11.0)
		return (knock * 1.2 + ring * 0.35) * 0.6)


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
