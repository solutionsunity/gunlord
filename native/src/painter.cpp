#include "painter.h"

#include "gd.h"

#include <godot_cpp/variant/utility_functions.hpp>

#include <cmath>

using namespace godot;

namespace gunlord {

void Painter::setup(Crowd *p_shadows, Crowd *p_placeholder, Crowd *p_frames, Crowd *p_panels, Crowd *p_pedestals,
		const Dictionary &p_projectiles, Crowd *p_streaks, Crowd *p_glow,
		Vector3 p_panel, double p_panel_lift, Vector3 p_pedestal, Color p_player_team, Color p_enemy_team) {
	shadow_crowd = p_shadows;
	placeholder = p_placeholder;
	frames = p_frames;
	panels = p_panels;
	pedestals = p_pedestals;
	projectiles = p_projectiles;
	streaks = p_streaks;
	glow = p_glow;
	panel = p_panel;
	panel_lift = p_panel_lift;
	pedestal = p_pedestal;
	player_team = p_player_team;
	enemy_team = p_enemy_team;
}

void Painter::add_kind(const StringName &model, Crowd *crowd, double scale) {
	kinds[model] = { crowd, scale };
}

void Painter::reset() {
	looks.clear();
	bodies.clear();
	fx_at.clear();
	fx_color.clear();
	fx_from.clear();
	fx_to.clear();
	fx_life.clear();
	fx_age.clear();
}

// One character standing at `at`, facing `yaw` (0 = up the lane), playing `role`
// from `phase` seconds offset so neighbours don't move in lockstep.
void Painter::character(const StringName &model, Vector3 at, double yaw, double size, Color color,
		const StringName &role, double phase, double shadow) {
	if (shadow > 0.0) {
		shadow_crowd->add(Vector3(at.x, 0.03f, at.z), 0.0, Vector3(1, 1, 1) * real_t(size * 0.75), Color(0, 0, 0, float(shadow)));
	}
	const auto kind = kinds.find(model);
	if (kind == kinds.end()) {
		placeholder->add(at + Vector3(0, real_t(0.5 * size), 0), yaw, Vector3(1, 1, 1) * real_t(size * 0.6), color);
		return;
	}
	Crowd *crowd = kind->second.crowd;
	crowd->add(at, yaw, Vector3(1, 1, 1) * real_t(kind->second.scale * size), color, crowd->custom(role, clock + phase));
}

void Painter::units(const Ref<Battle> &b, double p_clock) {
	clock = p_clock;
	const Squad &squad = **b->squad;
	const Color team(player_team, 0.0f);
	int k = 0;
	for (size_t w = 0; w < squad.weapons.size(); w++) {
		const WeaponSpec &wd = squad.weapons[w];
		const auto kind = kinds.find(wd.model);
		if (kind == kinds.end()) {
			for (int c = 0; c < squad.counts[w]; c++, k++) {
				const Vector2 p = squad.unit_position(k);
				character(wd.model, Vector3(p.x, 0, p.y), 0.0, wd.size, team, SHOOT, -k * 0.137);
			}
			continue;
		}
		// What character does per soldier, with the kind, clip and sizes looked up once.
		Crowd *crowd = kind->second.crowd;
		const Color role = crowd->custom(SHOOT, 0.0);
		const Vector3 body = Vector3(1, 1, 1) * real_t(kind->second.scale * wd.size);
		const Vector3 blob = Vector3(1, 1, 1) * real_t(wd.size * 0.75);
		const Color shade(0, 0, 0, 0.45f);
		for (int c = 0; c < squad.counts[w]; c++, k++) {
			const Vector2 p = squad.unit_position(k);
			shadow_crowd->add(Vector3(p.x, 0.03f, p.y), 0.0, blob, shade);
			const Color custom(role.r, role.g, float(Math::fposmod(clock - k * 0.137, double(Crowd::WRAP))), role.a);
			crowd->add(Vector3(p.x, 0, p.y), 0.0, body, team, custom);
		}
	}
}

PackedInt32Array Painter::lane(const Ref<Battle> &b, double p_clock) {
	clock = p_clock;
	const Lane &lane = **b->lane;
	frames->begin();
	panels->begin();
	pedestals->begin();
	PackedInt32Array labelled;
	const double front = Squad::Z - b->squad->radius();
	for (int i = 0; i < lane.size(); i++) {
		const ObjectSpec &d = lane.def(i);
		const bool hit = lane.hit_age[i] < FLASH;
		const Vector3 at(lane.x[i], 0, lane.z[i]);
		if (d.enemy) {
			// Bosses are under fire for seconds at a time: a full flash would wash them white.
			const Color color(team_of(d.tint), hit ? (d.persistent ? 0.2f : 0.55f) : 0.0f);
			const StringName &role = d.persistent && lane.z[i] >= front - d.radius - 0.05 ? ATTACK : ADVANCE;
			character(d.model, at, Math::PI, d.size, color, role, -lane.serial[i] * 0.29);
		} else {
			pickup(d, at, hit);
		}
		if (!d.caption.is_empty() || d.persistent) {
			labelled.append(i);
		}
	}
	frames->end();
	panels->end();
	pedestals->end();
	return labelled;
}

// A glass panel for unit blocks, multipliers and traps; a stone pedestal
// carrying the unit on offer for weapon crates.
void Painter::pickup(const ObjectSpec &d, Vector3 at, bool hit) {
	const Color tint = hit ? d.color.lerp(Color(1, 1, 1), 0.45f) : d.color;
	if (d.look == ObjectSpec::PANEL) {
		const Vector3 mid = at + Vector3(0, real_t(panel.y / 2.0 + panel_lift), 0);
		frames->add(mid, 0.0, Vector3(1, 1, 1), tint.darkened(0.25f));
		panels->add(mid + Vector3(0, 0, 0.03f), 0.0, Vector3(1, 1, 1), Color(tint.lightened(0.3f), 0.55f));
		return;
	}
	pedestals->add(at, 0.0, pedestal / Vector3(1.0f, 1.01f, 1.0f), Color(1, 1, 1));
	if (d.model != StringName()) {
		character(d.model, at + Vector3(0, pedestal.y, 0), clock * SPIN, 1.3, Color(player_team, 0.0f), CHEER, 0.0);
	}
}

void Painter::shots(const Ref<Battle> &b) {
	const Array crowds = projectiles.values();
	for (int64_t k = 0; k < crowds.size(); k++) {
		Object::cast_to<Crowd>(crowds[k])->begin();
	}
	streaks->begin();
	if (looks.size() != b->arsenal.size()) {
		looks.clear();
		Crowd *tracer = Object::cast_to<Crowd>(projectiles["tracer"]);
		for (const WeaponSpec &wd : b->arsenal) {
			// The trail starts at the projectile and stretches back along its path;
			// a rocket's is a long pale smoke trail.
			Crowd *crowd = projectiles.has(wd.projectile) ? Object::cast_to<Crowd>(projectiles[wd.projectile]) : tracer;
			looks.push_back({ crowd, wd.color.lightened(0.45f),
					wd.homing ? Color(0.85f, 0.85f, 0.88f, 0.7f) : Color(wd.color.lightened(0.15f), 0.95f),
					wd.homing ? Vector3(0.9f, 1.0f, 5.5f) : Vector3(wd.projectile == StringName("ball") ? 1.0f : 0.6f, 1.0f, 3.0f),
					-1.3 * (wd.homing ? 2.2 : 1.0) });
		}
	}
	const Shots &s = **b->shots;
	for (int i = 0; i < s.size(); i++) {
		const Look &look = looks[s.weapon[i]];
		const float vx = s.vx[i];
		const float vz = s.vz[i];
		const Vector3 at(s.x[i], 0.6f, s.z[i]);
		const double yaw = std::atan2(vx, vz);
		look.crowd->add(at, yaw, Vector3(1, 1, 1), look.color);
		const float back = float(look.back / std::sqrt(vx * vx + vz * vz));
		streaks->add(at + Vector3(vx * back, 0, vz * back), yaw, look.size, look.trail);
	}
	streaks->end();
	for (int64_t k = 0; k < crowds.size(); k++) {
		Object::cast_to<Crowd>(crowds[k])->end();
	}
}

void Painter::cuts(const Ref<Battle> &b, Vector2 blade, Vector3 at) {
	const Lane &lane = **b->lane;
	for (int i = 0; i < lane.size(); i++) {
		if (lane.hit_age[i] < FLASH && lane.alive[i] && lane.def(i).enemy && UtilityFunctions::randf() < 0.35
				&& blade.distance_to(Vector2(lane.x[i], lane.z[i])) <= Arms::BLADE_REACH + lane.def(i).radius) {
			const double dx = UtilityFunctions::randf_range(-0.3, 0.3);
			const double dz = UtilityFunctions::randf_range(-0.3, 0.3);
			spark(at + Vector3(real_t(dx), 0.1f, real_t(dz)), Color(1.0f, 0.85f, 0.5f), 0.5, 1.4, 0.2);
		}
	}
}

void Painter::flames(const Ref<Battle> &b) {
	const Squad &squad = **b->squad;
	const double front = Squad::Z - squad.radius();
	for (int k = 0; k < 6; k++) {
		const double ahead = UtilityFunctions::randf() * Arms::FLAME_DEPTH;
		const double half = squad.radius() + 1.0 + ahead * 0.25;
		const double x = squad.x + UtilityFunctions::randf_range(-half, half);
		const double y = 0.4 + UtilityFunctions::randf() * 0.5;
		const double g = 0.45 + UtilityFunctions::randf() * 0.3;
		spark(Vector3(real_t(x), real_t(y), real_t(front - ahead)), Color(1.0f, float(g), 0.1f), 0.6, 1.8, 0.35);
	}
}

void Painter::spark(Vector3 at, Color color, double from, double to, double life) {
	if (int(fx_at.size()) == glow->get_capacity()) {
		return;
	}
	fx_at.push_back(at);
	fx_color.push_back(color);
	fx_from.push_back(float(from));
	fx_to.push_back(float(to));
	fx_life.push_back(float(life));
	fx_age.push_back(0.0f);
}

void Painter::sparks(double delta) {
	glow->begin();
	size_t kept = 0;
	for (size_t i = 0; i < fx_at.size(); i++) {
		const double age = fx_age[i] + delta;
		const double t = age / fx_life[i];
		if (t >= 1.0) {
			continue;
		}
		fx_at[kept] = fx_at[i];
		fx_color[kept] = fx_color[i];
		fx_from[kept] = fx_from[i];
		fx_to[kept] = fx_to[i];
		fx_life[kept] = fx_life[i];
		fx_age[kept] = float(age);
		const float s = float(Math::lerp(double(fx_from[kept]), double(fx_to[kept]), std::sqrt(t)));
		Color c = fx_color[kept];
		c.a = float(1.0 - t * t);
		glow->add(fx_at[kept], 0.0, Vector3(s, s, s), c);
		kept++;
	}
	fx_at.resize(kept);
	fx_color.resize(kept);
	fx_from.resize(kept);
	fx_to.resize(kept);
	fx_life.resize(kept);
	fx_age.resize(kept);
	glow->end();
}

void Painter::corpse(const StringName &model, Vector3 at, bool enemy, double size, Color tint) {
	if (int(bodies.size()) == CORPSES) {
		bodies.pop_front();
	}
	const Color team = enemy ? team_of(tint) : player_team;
	bodies.push_back({ model, at, enemy ? Math::PI : 0.0, size, Color(team, 0.0f), 0.0 });
}

void Painter::corpses(double delta, double p_clock) {
	clock = p_clock;
	size_t kept = 0;
	for (size_t i = 0; i < bodies.size(); i++) {
		Body c = bodies[i];
		c.age += delta;
		const double sink = gd::max(c.age - CORPSE_REST, 0.0) / CORPSE_SINK;
		if (sink >= 1.0) {
			continue;
		}
		bodies[kept++] = c;
		const Vector3 at = c.at - Vector3(0, real_t(sink * 0.6 * c.size), 0);
		character(c.model, at, c.yaw, c.size, c.color, DEATH, -c.age, 0.45 * (1.0 - sink));
	}
	bodies.resize(kept);
}

void Painter::_bind_methods() {
	ClassDB::bind_method(D_METHOD("setup", "shadows", "placeholder", "frames", "panels", "pedestals", "projectiles",
			"streaks", "glow", "panel", "panel_lift", "pedestal", "player_team", "enemy_team"), &Painter::setup);
	ClassDB::bind_method(D_METHOD("add_kind", "model", "crowd", "scale"), &Painter::add_kind);
	ClassDB::bind_method(D_METHOD("reset"), &Painter::reset);
	ClassDB::bind_method(D_METHOD("units", "battle", "clock"), &Painter::units);
	ClassDB::bind_method(D_METHOD("lane", "battle", "clock"), &Painter::lane);
	ClassDB::bind_method(D_METHOD("shots", "battle"), &Painter::shots);
	ClassDB::bind_method(D_METHOD("cuts", "battle", "blade", "at"), &Painter::cuts);
	ClassDB::bind_method(D_METHOD("flames", "battle"), &Painter::flames);
	ClassDB::bind_method(D_METHOD("spark", "at", "color", "from", "to", "life"), &Painter::spark);
	ClassDB::bind_method(D_METHOD("corpse", "model", "at", "enemy", "size", "tint"), &Painter::corpse);
	ClassDB::bind_method(D_METHOD("corpses", "delta", "clock"), &Painter::corpses);
	ClassDB::bind_method(D_METHOD("sparks", "delta"), &Painter::sparks);
}

} // namespace gunlord
