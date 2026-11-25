#pragma once

#include <godot_cpp/classes/material.hpp>
#include <godot_cpp/classes/mesh.hpp>
#include <godot_cpp/classes/multi_mesh_instance3d.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector3.hpp>
#include <godot_cpp/variant/vector4.hpp>

#include <cmath>
#include <vector>

namespace gunlord {

// One batched draw: a MultiMesh whose instance buffer is rewritten every frame
// and pushed to the renderer in a single call. The renderer repacks and
// re-uploads every instance the MultiMesh holds, drawn or not, so it holds
// only room for what is drawn: a power of two that grows at once and shrinks
// lazily, up to `capacity`. An empty crowd that was already empty sends nothing.
//
// A crowd of baked characters also knows their clips (CrowdBake.clips), and
// turns a clip and a start time into the instance's custom data.
class Crowd : public godot::MultiMeshInstance3D {
	GDCLASS(Crowd, godot::MultiMeshInstance3D)

public:
	static constexpr int STRIDE = 20;   // floats per instance: 3x4 transform, colour, custom
	static constexpr int ROOM_MIN = 16;
	// The clock crowd animations play against. It wraps, because per-instance
	// data is only 16-bit on the Compatibility renderer: start times stay small
	// and precise, and the shader measures elapsed time modulo WRAP
	// (crowd.gdshader holds the same number). No clip may be longer.
	static constexpr int WRAP = 64;

	static Crowd *create(const godot::Ref<godot::Mesh> &mesh, int capacity, const godot::Ref<godot::Material> &material);

	// The renderer may still share last frame's buffer: writing takes it back.
	void begin() {
		count = 0;
		w = buf.is_empty() ? nullptr : buf.ptrw();
	}

	// One instance: turned by `yaw` about Y (local +Z ends up along (sin, 0, cos)),
	// scaled per axis, then placed at `pos`.
	void add(godot::Vector3 pos, double yaw, godot::Vector3 scale, godot::Color color, godot::Color custom = godot::Color()) {
		if (count == capacity) {
			return;
		}
		if ((count + 1) * STRIDE > int(buf.size())) {
			grow();
		}
		const float c = float(std::cos(yaw));
		const float s = float(std::sin(yaw));
		float *o = w + count * STRIDE;
		o[0] = c * scale.x;  o[1] = 0.0f;     o[2] = s * scale.z;   o[3] = pos.x;
		o[4] = 0.0f;         o[5] = scale.y;  o[6] = 0.0f;          o[7] = pos.y;
		o[8] = -s * scale.x; o[9] = 0.0f;     o[10] = c * scale.z;  o[11] = pos.z;
		o[12] = color.r;  o[13] = color.g;  o[14] = color.b;  o[15] = color.a;
		o[16] = custom.r; o[17] = custom.g; o[18] = custom.b; o[19] = custom.a;
		count++;
	}

	int room() const { return shown_room; }
	void end();

	// Custom data that plays `role` from `start` (seconds on the crowd clock);
	// a role the character lacks plays its first clip.
	godot::Color custom(const godot::StringName &role, double start) const;
	void set_clips(const godot::Dictionary &p_clips);
	godot::Dictionary get_clips() const { return clips; }

	int get_capacity() const { return capacity; }
	int get_count() const { return count; }

protected:
	static void _bind_methods();

private:
	struct Clip {
		godot::StringName role;
		godot::Vector4 v;   // first frame, frame count, fps, loops 1/0
	};

	int capacity = 0;   // the most instances it will ever draw
	int count = 0;
	godot::PackedFloat32Array buf;   // room * STRIDE floats
	float *w = nullptr;              // buf's storage, written in place
	int shown_room = 0;              // instances the MultiMesh holds now
	int shown = 0;                   // instances drawn by the last upload
	godot::Dictionary clips;
	std::vector<Clip> table;

	void grow();
};

} // namespace gunlord
