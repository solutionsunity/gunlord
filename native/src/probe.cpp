#include "probe.h"

#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/classes/time.hpp>
#include <cmath>

using namespace godot;

namespace gunlord {

void NativeProbe::_bind_methods() {
	ClassDB::bind_static_method("NativeProbe", D_METHOD("add_usec", "count", "rounds"), &NativeProbe::add_usec);
}

double NativeProbe::add_usec(int count, int rounds) {
	// One timed span over every round, averaged: a browser's clock is too
	// coarse to time a single round of native code.
	const int stride = 20;
	PackedFloat32Array buf;
	buf.resize(count * stride);
	float sink = 0.0f;
	const uint64_t began = Time::get_singleton()->get_ticks_usec();
	for (int r = 0; r < rounds; r++) {
		float *b = buf.ptrw();
		for (int i = 0; i < count; i++) {
			// The same record as Crowd.add: a yaw and scale, a position, a colour, a custom.
			const float yaw = 0.3f + (i + r) * 0.001f;
			const float c = std::cos(yaw), s = std::sin(yaw);
			float *o = b + i * stride;
			o[0] = c; o[1] = 0.0f; o[2] = s; o[3] = float(i);
			o[4] = 0.0f; o[5] = 1.0f; o[6] = 0.0f; o[7] = 0.0f;
			o[8] = -s; o[9] = 0.0f; o[10] = c; o[11] = 1.0f;
			o[12] = 1.0f; o[13] = 0.0f; o[14] = 0.0f; o[15] = 1.0f;
			o[16] = 0.0f; o[17] = 0.0f; o[18] = 0.0f; o[19] = 0.0f;
		}
		sink += b[(count - 1) * stride];   // keeps the loop from being optimised away
	}
	const double took = double(Time::get_singleton()->get_ticks_usec() - began);
	return took / rounds + (sink < -1e30f ? 1.0 : 0.0);
}

} // namespace gunlord
