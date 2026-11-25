#pragma once

#include "battle.h"
#include "crowd.h"

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/string_name.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <deque>
#include <unordered_map>
#include <vector>

namespace gunlord {

// The View's hands for everything a battle has hundreds of: soldiers, lane
// objects, projectiles, the fallen and sparks. It reads the battle's arrays in
// place and writes the View's crowds; the View keeps the crowds, the few
// things there are only a handful of, and the order of the frame.
class Painter : public godot::RefCounted {
	GDCLASS(Painter, godot::RefCounted)

public:
	static constexpr double FLASH = 0.08;          // seconds an object shows a hit
	static constexpr int CORPSES = 400;
	static constexpr double CORPSE_REST = 1.4;     // seconds a body lies still before sinking
	static constexpr double CORPSE_SINK = 0.8;     // seconds to sink out of sight
	static constexpr double SPIN = godot::Math::TAU / 4.0;   // rad/s; a whole number of turns per clock wrap, so the wrap is seamless

	// The crowds it draws into, and the View's measures and colours.
	void setup(Crowd *shadows, Crowd *placeholder, Crowd *frames, Crowd *panels, Crowd *pedestals,
			const godot::Dictionary &projectiles, Crowd *streaks, Crowd *glow,
			godot::Vector3 panel, double panel_lift, godot::Vector3 pedestal,
			godot::Color player_team, godot::Color enemy_team);
	// A character kind: its crowd, and the scale that makes it stand a unit tall.
	void add_kind(const godot::StringName &model, Crowd *crowd, double scale);
	// Forgets everything that belonged to the last battle.
	void reset();

	void units(const godot::Ref<Battle> &b, double clock);
	// Returns the lane objects that carry a label, in lane order.
	godot::PackedInt32Array lane(const godot::Ref<Battle> &b, double clock);
	void shots(const godot::Ref<Battle> &b);
	// Sparks where a blade at `blade` cuts an enemy that was just hit.
	void cuts(const godot::Ref<Battle> &b, godot::Vector2 blade, godot::Vector3 at);
	// The flame surge: tongues of fire licking out over the ground ahead of the squad.
	void flames(const godot::Ref<Battle> &b);
	// A glowing billboard that grows from `from` to `to` metres and fades over `life` seconds.
	void spark(godot::Vector3 at, godot::Color color, double from, double to, double life);
	void corpse(const godot::StringName &model, godot::Vector3 at, bool enemy, double size, godot::Color tint);
	// Fallen soldiers play their death once, lie still, then sink into the deck.
	void corpses(double delta, double clock);
	void sparks(double delta);

protected:
	static void _bind_methods();

private:
	struct Kind {
		Crowd *crowd;
		double scale;
	};
	struct Look {
		Crowd *crowd;
		godot::Color color, trail;
		godot::Vector3 size;
		double back;
	};
	struct Body {
		godot::StringName model;
		godot::Vector3 at;
		double yaw, size;
		godot::Color color;
		double age;
	};
	struct StringNameHash {
		size_t operator()(const godot::StringName &s) const { return s.hash(); }
	};

	Crowd *shadow_crowd = nullptr;
	Crowd *placeholder = nullptr;
	Crowd *frames = nullptr;
	Crowd *panels = nullptr;
	Crowd *pedestals = nullptr;
	Crowd *streaks = nullptr;
	Crowd *glow = nullptr;
	godot::Dictionary projectiles;   // look -> Crowd
	godot::Vector3 panel, pedestal;
	double panel_lift = 0.0;
	godot::Color player_team, enemy_team;
	std::unordered_map<godot::StringName, Kind, StringNameHash> kinds;
	std::vector<Look> looks;   // per arsenal index; built once a battle
	std::deque<Body> bodies;
	std::vector<godot::Vector3> fx_at;   // live sparks as parallel arrays
	std::vector<godot::Color> fx_color;
	std::vector<float> fx_from, fx_to, fx_life, fx_age;
	double clock = 0.0;
	const godot::StringName SHOOT = "shoot";   // the roles characters play
	const godot::StringName ATTACK = "attack";
	const godot::StringName ADVANCE = "advance";
	const godot::StringName CHEER = "cheer";
	const godot::StringName DEATH = "death";

	void character(const godot::StringName &model, godot::Vector3 at, double yaw, double size, godot::Color color,
			const godot::StringName &role, double phase, double shadow = 0.45);
	void pickup(const ObjectSpec &d, godot::Vector3 at, bool hit);
	godot::Color team_of(godot::Color tint) const { return tint.a > 0.0f ? tint : enemy_team; }
};

} // namespace gunlord
