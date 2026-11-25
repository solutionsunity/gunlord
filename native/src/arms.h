#pragma once

#include "specs.h"
#include "squad.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_vector2_array.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include <vector>

namespace gunlord {

class Lane;
class Shots;

// What fights beside the squad's own weapons: the relics it brings (blades,
// drones, shield; see Relics) and the surge running now, if any. Relics
// amplify the squad, never replace it: their strength follows its size, so a
// squad that never grows gets little from them. The battle calls tick once
// per step; the arms reach into the squad, lane and shots only through their
// interfaces.
class Arms : public godot::RefCounted {
	GDCLASS(Arms, godot::RefCounted)

public:
	static constexpr double CHAIN = 0.8;            // share of a hit's damage each arc carries
	static constexpr double FLAME_DEPTH = 7.0;      // metres of fire ahead of the squad's front
	static constexpr double FLAME_DPS = 8.0;        // plus FLAME_PER_UNIT for every unit in the squad
	static constexpr double FLAME_PER_UNIT = 0.3;
	static constexpr double ROCKETS_PER_S = 1.0;    // plus one more per ROCKET_UNITS units
	static constexpr double ROCKET_UNITS = 25.0;
	static constexpr double BLADE_REACH = 0.7;      // metres a blade cuts around itself
	static constexpr double WIDEST = 3.0;           // no enemy is wider than this (a scaled warlord)
	static constexpr double BLADE_DPS = 10.0;       // per blade, per relic level
	static constexpr double BLADE_SPIN = 2.4;       // rad/s
	static constexpr double BLADE_GAP = 0.9;        // metres between the squad's rim and the blades' circle
	static constexpr double DRONE_GAP = 1.3;        // metres from the squad's rim to a drone
	static constexpr double SHIELD_PER_LEVEL = 6.0; // blows the shield holds at full charge, per level
	static constexpr double SHIELD_REGEN = 0.5;     // blows recharged per second, per level
	static constexpr double FULL_STRENGTH = 50.0;   // a squad this size gets relics at full strength; they scale with it
	static constexpr double STRENGTH_MAX = 2.0;

	godot::Dictionary loadout;   // relic id -> level
	double spin = 0.0;           // the blades' angle
	double shield = 0.0;         // blows the shield can take now; charges as the squad grows
	godot::StringName surge;     // the surge running, or empty
	double surge_left = 0.0;     // its seconds left

	void setup(const godot::Ref<Squad> &p_squad, const std::vector<WeaponSpec> &p_arsenal,
			const godot::Dictionary &p_loadout, const godot::Dictionary &p_surges);
	int level(const godot::StringName &relic) const;
	double strength() const;
	double shield_max() const;
	godot::PackedVector2Array blades() const;
	godot::PackedVector2Array drones() const;
	int absorb(int n);
	void grant(const godot::StringName &id);
	bool frozen() const { return surge == FREEZE; }
	double chain() const { return surge == CHAIN_SURGE ? CHAIN : 0.0; }
	void tick(double dt, Lane &lane, Shots &shots);

	double get_shield() const { return shield; }
	godot::StringName get_surge() const { return surge; }
	double get_surge_left() const { return surge_left; }

protected:
	static void _bind_methods();

private:
	const godot::StringName FREEZE = "freeze";   // the surges and relics it knows by name
	const godot::StringName CHAIN_SURGE = "chain";
	const godot::StringName FLAME = "flame";
	const godot::StringName ROCKETS = "rockets";
	const godot::StringName BLADES = "blades";
	const godot::StringName DRONE = "drone";
	const godot::StringName SHIELD = "shield";
	godot::Ref<Squad> squad;
	std::vector<WeaponSpec> arsenal;
	godot::Dictionary surges;
	int rocket = -1;   // the rocket's index in the arsenal
	int drone = -1;    // the drone's
	double rocket_acc = 0.0;
	double drone_acc = 0.0;
	int drone_turn = 0;   // which drone fires next: they take turns, across steps

	void relics(double dt, Lane &lane, Shots &shots);
	void flame(double dt, Lane &lane);
	void rockets(double dt, Lane &lane, Shots &shots);
};

} // namespace gunlord
