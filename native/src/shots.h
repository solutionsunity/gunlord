#pragma once

#include "specs.h"

#include <godot_cpp/classes/random_number_generator.hpp>
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <cstdint>
#include <vector>

namespace gunlord {

class Grid;
class Lane;

// Every projectile in flight, stored as parallel flat arrays. Removal swaps
// the last projectile into the freed index.
class Shots : public godot::RefCounted {
	GDCLASS(Shots, godot::RefCounted)

public:
	static constexpr double TURN = 5.0;        // rad/s a homing shot turns
	static constexpr double ARC_REACH = 3.5;   // metres a chain arc jumps
	static constexpr int ARCS = 2;             // enemies one hit arcs to

	std::vector<float> x, z, vx, vz, damage, splash, life;
	std::vector<int> pierce, weapon;
	std::vector<int> last_hit;       // serial of the last object hit, so a piercing shot hits each object once
	std::vector<uint8_t> hits_traps; // only straight shots can claim a trap
	std::vector<uint8_t> homing;     // turns toward the nearest enemy in flight
	double chain = 0.0;              // while a chain surge runs: the share of a hit that arcs onward
	std::vector<float> zaps;         // this tick's arcs: from x, z, to x, z per arc
	std::vector<float> fired;        // this tick's shots: x, z, weapon per shot
	std::vector<float> impacts;      // this tick's hits: x, z, weapon, splash, lane index per hit

	Shots();
	int size() const { return int(x.size()); }
	void fire(const WeaponSpec &wd, int w, godot::Vector2 p, godot::Vector2 dir, double mult);
	void advance(double dt, Lane &lane, const Grid &grid);

	godot::PackedFloat32Array get_x() const;
	godot::PackedFloat32Array get_z() const;
	godot::PackedFloat32Array get_vx() const;
	godot::PackedFloat32Array get_vz() const;
	godot::PackedInt32Array get_weapon() const;

protected:
	static void _bind_methods();

private:
	godot::Ref<godot::RandomNumberGenerator> rng;
	void steer(int i, double dt, const Lane &lane);
	void arc(int hit, double dmg, Lane &lane);
	void swap_remove(int i);
};

} // namespace gunlord
