#include "crowd.h"

#include "gd.h"

#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/variant/aabb.hpp>

using namespace godot;

namespace gunlord {

Crowd *Crowd::create(const Ref<Mesh> &mesh, int capacity, const Ref<Material> &material) {
	Crowd *crowd = memnew(Crowd);
	crowd->capacity = capacity;
	Ref<MultiMesh> mm;
	mm.instantiate();
	mm->set_transform_format(MultiMesh::TRANSFORM_3D);
	mm->set_use_colors(true);
	mm->set_use_custom_data(true);
	mm->set_mesh(mesh);
	mm->set_custom_aabb(AABB(Vector3(-12, -2, -60), Vector3(24, 14, 70)));
	crowd->set_multimesh(mm);
	crowd->set_material_override(material);
	return crowd;
}

void Crowd::grow() {
	const int room = gd::min(gd::max(ROOM_MIN, int(buf.size()) / STRIDE * 2), capacity);
	buf.resize(room * STRIDE);
	w = buf.ptrw();
}

void Crowd::end() {
	if (count == 0 && shown == 0) {
		return;
	}
	int room = int(buf.size()) / STRIDE;
	if (count * 4 < room && room > ROOM_MIN) {   // shrink only when well under, so a crowd near a boundary doesn't churn
		room = gd::min(gd::max(ROOM_MIN, int(Math::next_power_of_2(uint32_t(gd::max(count, 1))))), capacity);
		buf.resize(room * STRIDE);
		w = buf.ptrw();
	}
	const Ref<MultiMesh> mm = get_multimesh();
	if (room != shown_room) {
		mm->set_instance_count(room);   // reallocates; set only when the room changes
		shown_room = room;
	}
	if (shown_room > 0) {
		RenderingServer::get_singleton()->multimesh_set_buffer(mm->get_rid(), buf);
	}
	mm->set_visible_instance_count(count);
	shown = count;
}

Color Crowd::custom(const StringName &role, double start) const {
	ERR_FAIL_COND_V_MSG(table.empty(), Color(), "This crowd has no clips.");
	const Clip *clip = &table[0];
	for (const Clip &c : table) {
		if (c.role == role) {
			clip = &c;
			break;
		}
	}
	const Vector4 &c = clip->v;
	const float fps = c.w > 0.5f ? c.z : -c.z;
	return Color(c.x, c.y, float(Math::fposmod(start, double(WRAP))), fps);
}

void Crowd::set_clips(const Dictionary &p_clips) {
	clips = p_clips;
	table.clear();
	const Array roles = clips.keys();
	for (int64_t k = 0; k < roles.size(); k++) {
		table.push_back({ roles[k], clips[roles[k]] });
	}
}

void Crowd::_bind_methods() {
	ClassDB::bind_static_method("Crowd", D_METHOD("create", "mesh", "capacity", "material"), &Crowd::create);
	ClassDB::bind_method(D_METHOD("begin"), &Crowd::begin);
	ClassDB::bind_method(D_METHOD("add", "pos", "yaw", "scale", "color", "custom"), &Crowd::add, DEFVAL(Color()));
	ClassDB::bind_method(D_METHOD("end"), &Crowd::end);
	ClassDB::bind_method(D_METHOD("room"), &Crowd::room);
	ClassDB::bind_method(D_METHOD("custom", "role", "start"), &Crowd::custom);
	ClassDB::bind_method(D_METHOD("set_clips", "clips"), &Crowd::set_clips);
	ClassDB::bind_method(D_METHOD("get_clips"), &Crowd::get_clips);
	ClassDB::bind_method(D_METHOD("get_capacity"), &Crowd::get_capacity);
	ClassDB::bind_method(D_METHOD("get_count"), &Crowd::get_count);
	ADD_PROPERTY(PropertyInfo(Variant::DICTIONARY, "clips"), "set_clips", "get_clips");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "capacity"), "", "get_capacity");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "count"), "", "get_count");
	BIND_CONSTANT(WRAP);
}

} // namespace gunlord
