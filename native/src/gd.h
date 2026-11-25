#pragma once
// GDScript's numerics, to the bit. The simulation was first written in
// GDScript and its forged map was measured there, so every rounding must land
// where GDScript's did: script floats are doubles, packed arrays and vectors
// hold 32-bit floats. The engine's own helpers come from godot::Math; these
// are the few that need care beyond it.

#include <godot_cpp/core/math.hpp>

#include <cmath>

namespace gunlord::gd {

// clampf, clampi, minf, mini, maxf, maxi: one type in, the same type out.
template <typename T>
inline T clamp(T v, T lo, T hi) { return v < lo ? lo : (v > hi ? hi : v); }
template <typename T>
inline T min(T a, T b) { return a < b ? a : b; }
template <typename T>
inline T max(T a, T b) { return a > b ? a : b; }

// `v ** 2`: a call to pow, which is not always v * v to the last bit. The
// exponent is read at run time so the compiler cannot fold it to v * v.
inline double pow2(double v) {
	static volatile double two = 2.0;
	return std::pow(v, two);
}

} // namespace gunlord::gd
