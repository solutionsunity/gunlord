#include "arms.h"

#include "gd.h"
#include "lane.h"
#include "shots.h"

#include <cmath>

using namespace godot;

namespace gunlord {

void Arms::setup(const Ref<Squad> &p_squad, const std::vector<WeaponSpec> &p_arsenal,
		const Dictionary &p_loadout, const Dictionary &p_surges) {
	squad = p_squad;
	arsenal = p_arsenal;
	loadout = p_loadout;
	surges = p_surges;
	for (int i = 0; i < int(arsenal.size()); i++) {
		if (arsenal[i].id == StringName("rocket")) {
			rocket = i;
		} else if (arsenal[i].id == StringName("drone")) {
			drone = i;
		}
	}
}

int Arms::level(const StringName &relic) const {
	return int(loadout.get(relic, 0));
}

// Relic strength for a squad of this size: 1 at FULL_STRENGTH units.
double Arms::strength() const {
	return gd::min(squad->total() / FULL_STRENGTH, STRENGTH_MAX);
}

double Arms::shield_max() const {
	return SHIELD_PER_LEVEL * level(SHIELD) * strength();
}

// Where each blade is now.
PackedVector2Array Arms::blades() const {
	PackedVector2Array out;
	const int n = level(BLADES) > 0 ? level(BLADES) + 1 : 0;
	const double r = squad->radius() + BLADE_GAP;
	for (int k = 0; k < n; k++) {
		out.append(Vector2(real_t(squad->x), real_t(Squad::Z)) + Vector2::from_angle(real_t(spin + k * Math::TAU / n)) * real_t(r));
	}
	return out;
}

// Where each drone hovers: alternately right and left of the squad, further back each pair.
PackedVector2Array Arms::drones() const {
	PackedVector2Array out;
	for (int k = 0; k < level(DRONE); k++) {
		const double side = k % 2 == 0 ? 1.0 : -1.0;
		out.append(Vector2(real_t(squad->x + side * (squad->radius() + DRONE_GAP)), real_t(Squad::Z + 0.6 - (k / 2) * 1.4)));
	}
	return out;
}

// Of n units about to fall to the front line, how many the shield saves.
int Arms::absorb(int n) {
	const int saved = gd::min(n, int(shield));
	shield -= saved;
	return saved;
}

// Starts a surge; a running one is replaced, the same one starts over.
void Arms::grant(const StringName &id) {
	surge = id;
	surge_left = Dictionary(surges[id])["seconds"];
}

void Arms::tick(double dt, Lane &lane, Shots &shots) {
	relics(dt, lane, shots);
	if (surge == StringName()) {
		return;
	}
	if (surge == FLAME) {
		flame(dt, lane);
	} else if (surge == ROCKETS) {
		rockets(dt, lane, shots);
	}
	surge_left -= dt;
	if (surge_left <= 0.0) {
		surge = StringName();
	}
}

void Arms::relics(double dt, Lane &lane, Shots &shots) {
	const Squad &s = **squad;
	const double power = strength();
	shield = gd::min(shield + SHIELD_REGEN * level(SHIELD) * power * dt, shield_max());
	if (level(BLADES) > 0) {
		spin = Math::fposmod(spin + BLADE_SPIN * dt, Math::TAU);
		const double hurt = BLADE_DPS * level(BLADES) * power * s.damage_mult * dt;
		const PackedVector2Array cuts = blades();
		const double ring = s.radius() + BLADE_GAP + BLADE_REACH + WIDEST;   // nothing further from the squad can be cut
		const int n = lane.size();
		for (int i = 0; i < n; i++) {
			if (!lane.alive[i] || !lane.def(i).enemy) {
				continue;
			}
			const Vector2 p(lane.x[i], lane.z[i]);
			if (std::abs(p.x - s.x) > ring || std::abs(p.y - Squad::Z) > ring) {
				continue;
			}
			for (const Vector2 &b : cuts) {
				if (p.distance_to(b) <= BLADE_REACH + lane.def(i).radius) {
					lane.damage(i, hurt);
				}
			}
		}
	}
	if (level(DRONE) > 0) {
		const WeaponSpec &wd = arsenal[drone];
		drone_acc += level(DRONE) * wd.fire_rate * power * dt;
		const PackedVector2Array spots = drones();
		while (drone_acc >= 1.0) {
			drone_acc -= 1.0;
			const Vector2 from = spots[drone_turn % spots.size()];
			drone_turn += 1;
			const int t = lane.nearest_target(from, wd.reach, true);
			if (t >= 0) {
				shots.fire(wd, drone, from, (Vector2(lane.x[t], lane.z[t]) - from).normalized(), s.damage_mult);
			}
		}
	}
}

// Burns every enemy in a cone just ahead of the squad, widening with distance.
void Arms::flame(double dt, Lane &lane) {
	const Squad &s = **squad;
	const double front = Squad::Z - s.radius();
	const double dps = (FLAME_DPS + FLAME_PER_UNIT * s.total()) * s.damage_mult;
	const int n = lane.size();
	for (int i = 0; i < n; i++) {
		if (!lane.alive[i] || !lane.def(i).enemy) {
			continue;
		}
		const double ahead = front - lane.z[i];
		if (ahead >= -lane.def(i).radius && ahead <= FLAME_DEPTH
				&& std::abs(lane.x[i] - s.x) < s.radius() + 1.0 + ahead * 0.25) {
			lane.damage(i, dps * dt);
		}
	}
}

// Fires homing rockets from the squad's middle, more as it grows.
void Arms::rockets(double dt, Lane &lane, Shots &shots) {
	const Squad &s = **squad;
	rocket_acc += (ROCKETS_PER_S + s.total() / ROCKET_UNITS) * dt;
	const WeaponSpec &wd = arsenal[rocket];
	while (rocket_acc >= 1.0) {
		rocket_acc -= 1.0;
		const Vector2 from(real_t(s.x), real_t(Squad::Z - s.radius() * 0.5));
		const int t = lane.nearest_target(from, wd.reach, true);
		const Vector2 dir = t < 0 ? Vector2(0.0f, -1.0f) : (Vector2(lane.x[t], lane.z[t]) - from).normalized();
		shots.fire(wd, rocket, from, dir, s.damage_mult);
	}
}

void Arms::_bind_methods() {
	ClassDB::bind_method(D_METHOD("level", "relic"), &Arms::level);
	ClassDB::bind_method(D_METHOD("shield_max"), &Arms::shield_max);
	ClassDB::bind_method(D_METHOD("blades"), &Arms::blades);
	ClassDB::bind_method(D_METHOD("drones"), &Arms::drones);
	ClassDB::bind_method(D_METHOD("frozen"), &Arms::frozen);
	ClassDB::bind_method(D_METHOD("get_shield"), &Arms::get_shield);
	ClassDB::bind_method(D_METHOD("get_surge"), &Arms::get_surge);
	ClassDB::bind_method(D_METHOD("get_surge_left"), &Arms::get_surge_left);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "shield"), "", "get_shield");
	ADD_PROPERTY(PropertyInfo(Variant::STRING_NAME, "surge"), "", "get_surge");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "surge_left"), "", "get_surge_left");
}

} // namespace gunlord
