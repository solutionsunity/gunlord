#pragma once

#include "arms.h"
#include "grid.h"
#include "lane.h"
#include "shots.h"
#include "squad.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <vector>

namespace gunlord {

// One run of one level. Owns the order of every step in a tick; the parts it
// coordinates (squad, lane, shots, grid, arms) know nothing about each other's
// timing. The tick is deterministic: same inputs, same run. While a freeze
// surge runs, the lane and its clock stand still and only the squad acts.
class Battle : public godot::RefCounted {
	GDCLASS(Battle, godot::RefCounted)

public:
	enum State { RUNNING, WON, LOST };

	// roster: the squad's weapons (Content.weapons); arms: the weapons no unit
	// carries (Content.arms); objects: id -> ObjectDef; surges: Content.SURGES.
	static godot::Ref<Battle> create(const godot::Array &roster, const godot::Array &arms,
			const godot::Dictionary &objects, const godot::Dictionary &surges, const godot::Ref<godot::RefCounted> &level);

	void tick(double dt);
	double lane_speed() const;

	State state = RUNNING;
	double time = 0.0;
	int wave = 0;
	int waves = 0;
	int peak_units = 0;
	godot::Ref<godot::RefCounted> level;
	godot::Ref<Squad> squad;
	godot::Ref<Lane> lane;
	godot::Ref<Shots> shots;
	godot::Ref<Arms> arms;
	std::vector<WeaponSpec> arsenal;   // the roster, then the arms no unit carries; shots index into it
	godot::Array arsenal_defs;
	// Presentation events for the view, which drains them each frame. Kinds:
	//   payout {at, text, color, tone}       tone: gain, loss, max, boost or surge
	//   death  {at, model, size, enemy, tint}   one per fallen soldier on either side
	//   fire   {at, weapon}               one per shot (a spread counts once)
	//   hit    {at, weapon, splash, target}  one per projectile impact; target is the ObjectDef hit
	//   end    {won}                         once, when the battle is decided
	//   zap    {at, to}                      one per chain arc
	//   shielded {count}                     the shield took count blows meant for the squad
	godot::Array events;   // cleared by whoever runs the battle, after every reader has seen them

	State get_state() const { return state; }
	void set_state(State s) { state = s; }
	double get_time() const { return time; }
	int get_wave() const { return wave; }
	int get_waves() const { return waves; }
	int get_peak_units() const { return peak_units; }
	godot::Variant get_level() const { return level; }   // a Level (src/content/level.gd)
	godot::Ref<Squad> get_squad() const { return squad; }
	godot::Ref<Lane> get_lane() const { return lane; }
	godot::Ref<Shots> get_shots() const { return shots; }
	godot::Ref<Arms> get_arms() const { return arms; }
	godot::Array get_arsenal() const { return arsenal_defs; }
	godot::Array get_events() const { return events; }

protected:
	static void _bind_methods();

private:
	struct Spawn {
		double t;
		int kind;
		double x, z, hp, amount;
		int wave;
	};

	Grid grid;
	std::vector<Spawn> timeline;
	size_t next = 0;
	godot::Dictionary weapon_index;   // weapon id -> roster index
	double speed = 0.0;
	double accel = 0.0;

	void spawn();
	void contacts(double dt);
	void payouts();
	void shot_events();
	void struck(int n);
	void lose(int n);
	void enemy_died(int i);
	void callout(godot::Vector3 at, const godot::String &text, godot::Color color, const godot::StringName &tone);
};

} // namespace gunlord

VARIANT_ENUM_CAST(gunlord::Battle::State);
