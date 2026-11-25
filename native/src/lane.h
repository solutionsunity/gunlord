#pragma once

#include "specs.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cstdint>
#include <vector>

namespace gunlord {

// Every lane object, stored as parallel flat arrays (one index = one object).
// Removal is deferred: objects are flagged dead during a tick and compacted at
// its end, so indices stay valid for the whole tick.
class Lane : public godot::RefCounted {
	GDCLASS(Lane, godot::RefCounted)

public:
	// Whole metres, so they bind as integer constants for the scripts.
	static constexpr double SPAWN_Z = -50.0;
	static constexpr double WALL_END_Z = -5.0;   // where the walls between lanes stop
	static constexpr double HALF_WIDTH = 6.0;

	std::vector<float> walls;   // x of each wall; an enemy keeps to the lane between two, or a wall and the edge
	std::vector<ObjectSpec> kinds;   // every kind of object this battle may spawn

	std::vector<int> kind;       // index into kinds
	std::vector<int> serial;     // stable identity across compaction
	std::vector<float> x, z, hp, max_hp, amount;
	std::vector<float> hit_age;  // seconds since last hit, drives the hit flash
	std::vector<uint8_t> alive;
	std::vector<int> destroyed;  // shot down this tick, awaiting payout

	int size() const { return int(x.size()); }
	const ObjectSpec &def(int i) const { return kinds[kind[i]]; }
	int kind_of(const godot::Ref<godot::Resource> &def);

	void spawn(int k, double px, double pz, double php, double pamount);
	double speed_of(int i, double lane_speed) const { return lane_speed + def(i).walk; }
	void advance(double dt, double lane_speed, double squad_x);
	void damage(int i, double dmg);
	void splash(double px, double pz, double r, double dmg, int skip);
	int nearest_target(godot::Vector2 p, double reach, bool enemies_only = false) const;
	std::vector<int> enemies_near(double px, double pz, double r, int n, int skip) const;
	void compact();
	// The live persistent object (a boss) furthest down the lane, past `beyond`; -1 if none.
	int nearest_boss(double beyond) const;

	// For the scripts: copies, read once per frame.
	godot::Ref<godot::Resource> def_of(int i) const;
	godot::PackedFloat32Array get_x() const;
	godot::PackedFloat32Array get_z() const;
	godot::PackedFloat32Array get_hp() const;
	godot::PackedFloat32Array get_max_hp() const;
	godot::PackedFloat32Array get_amount() const;
	godot::PackedFloat32Array get_hit_age() const;
	godot::PackedInt32Array get_serial() const;
	godot::PackedByteArray get_alive() const;

protected:
	static void _bind_methods();

private:
	int next_serial = 0;
	double keep_in_lane(double px, double r) const;
};

godot::PackedFloat32Array packed(const std::vector<float> &v);
godot::PackedInt32Array packed(const std::vector<int> &v);

} // namespace gunlord
