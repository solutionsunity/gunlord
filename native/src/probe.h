#pragma once

#include <godot_cpp/classes/ref_counted.hpp>

namespace gunlord {

// Times, in native code, the work a Crowd does per instance: one transform,
// colour and custom record written into a float buffer. The readout sets it
// beside the same work in GDScript, to measure on the device what moving the
// hot loops to native code would gain (issue #21).
class NativeProbe : public godot::RefCounted {
	GDCLASS(NativeProbe, godot::RefCounted)

protected:
	static void _bind_methods();

public:
	// Microseconds to write `count` instances, averaged over `rounds`.
	static double add_usec(int count, int rounds);
};

} // namespace gunlord
