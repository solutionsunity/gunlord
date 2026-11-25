#pragma once

#include "specs.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/vector2.hpp>

#include <vector>

namespace gunlord {

class Lane;
class Shots;

// The player's squad: a count of units per weapon, laid out as a sunflower
// disc around one centre. Unit k sits at slot k; weapons fill slots in roster
// order, so the first weapons sit in the middle and the last ones on the rim.
class Squad : public godot::RefCounted {
	GDCLASS(Squad, godot::RefCounted)

public:
	static constexpr double Z = 0.0;
	static constexpr double SPACING = 0.36;
	static constexpr double EDGE = 6.0;   // half-width of the deck: the rim of the squad stops here
	static constexpr double MAX_SPEED = 30.0;
	static constexpr double GOLDEN_ANGLE = 2.39996323;

	std::vector<WeaponSpec> weapons;
	godot::Array weapon_defs;
	int capacity = 0;   // maximum unit count; payouts beyond it are lost
	std::vector<int> counts;
	double damage_mult = 1.0;
	double x = 0.0;
	double target_x = 0.0;

	void setup(const godot::Array &roster, int p_capacity);
	int total() const;
	double radius() const;
	static godot::Vector2 slot(int k);
	godot::Vector2 unit_position(int k) const;
	double limit() const;
	void steer(double dx);
	void move(double dt);
	int add(int w, int n);
	int enlist(int w, int n);
	int multiply(int w, double f);
	void remove_outer(int n);
	int wound(double units);
	int weapon_at(int k) const;
	void fire(double dt, const Lane &lane, Shots &shots, double lane_speed);

	double get_x() const { return x; }
	double get_target_x() const { return target_x; }
	void set_target_x(double v) { target_x = v; }
	int get_capacity() const { return capacity; }
	double get_damage_mult() const { return damage_mult; }
	godot::Array get_weapons() const { return weapon_defs; }
	godot::PackedInt32Array get_counts() const;

protected:
	static void _bind_methods();

private:
	std::vector<float> acc;   // shots owed per weapon
	std::vector<int> rr;      // round-robin cursor per weapon
	double wounds = 0.0;      // fractional losses from persistent attackers
};

} // namespace gunlord
