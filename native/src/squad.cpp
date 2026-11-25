#include "squad.h"

#include "gd.h"
#include "lane.h"
#include "shots.h"

#include <cmath>

using namespace godot;

namespace gunlord {

void Squad::setup(const Array &roster, int p_capacity) {
	weapon_defs = roster.duplicate();
	for (int64_t w = 0; w < roster.size(); w++) {
		weapons.push_back(WeaponSpec::of(roster[w]));
	}
	capacity = p_capacity;
	counts.assign(weapons.size(), 0);
	acc.assign(weapons.size(), 0.0f);
	rr.assign(weapons.size(), 0);
}

int Squad::total() const {
	int n = 0;
	for (const int c : counts) {
		n += c;
	}
	return n;
}

double Squad::radius() const {
	return SPACING * std::sqrt(double(total())) + 0.3;
}

Vector2 Squad::slot(int k) {
	const double r = SPACING * std::sqrt(k + 0.5);
	const double a = k * GOLDEN_ANGLE;
	return Vector2(real_t(std::cos(a) * r), real_t(std::sin(a) * r));
}

Vector2 Squad::unit_position(int k) const {
	return slot(k) + Vector2(real_t(x), real_t(Z));
}

// How far the centre may move from the lane axis: a bigger squad keeps more
// of itself on the deck, and covers the side lanes with its rim.
double Squad::limit() const {
	return gd::max(EDGE - radius(), 0.6);
}

void Squad::steer(double dx) {
	target_x = gd::clamp(target_x + dx, -limit(), limit());
}

void Squad::move(double dt) {
	target_x = gd::clamp(target_x, -limit(), limit());
	x = gd::clamp(godot::Math::move_toward(x, target_x, MAX_SPEED * dt), -limit(), limit());
}

// Adds up to n units, never past capacity. Returns how many were added.
int Squad::add(int w, int n) {
	const int added = gd::clamp(n, 0, capacity - total());
	counts[w] += added;
	return added;
}

// Like add, but at capacity the remainder replaces rim units (the last weapon
// in roster order) one-for-one, so a full squad can still upgrade its weapons.
int Squad::enlist(int w, int n) {
	int added = add(w, n);
	const int rim = int(counts.size()) - 1;
	if (w != rim) {
		const int swapped = gd::min(n - added, counts[rim]);
		counts[rim] -= swapped;
		counts[w] += swapped;
		added += swapped;
	}
	return added;
}

// Grows weapon w by factor f, never past capacity. Returns how many were added.
int Squad::multiply(int w, double f) {
	return add(w, int(std::round(counts[w] * f)) - counts[w]);
}

// Losses come off the rim first: the last weapon in roster order.
void Squad::remove_outer(int n) {
	for (int w = int(counts.size()) - 1; w >= 0; w--) {
		const int take = gd::min(n, counts[w]);
		counts[w] -= take;
		n -= take;
		if (n == 0) {
			return;
		}
	}
}

// Accumulates fractional losses; returns how many whole units are now lost.
// The caller removes them.
int Squad::wound(double units) {
	wounds += units;
	const int n = int(wounds);
	wounds -= n;
	return n;
}

// The weapon index of unit k (formation order).
int Squad::weapon_at(int k) const {
	for (int w = 0; w < int(counts.size()); w++) {
		if (k < counts[w]) {
			return w;
		}
		k -= counts[w];
	}
	return -1;
}

// Every unit fires at its weapon's rate. Shots owed accumulate per weapon and
// are paid out round-robin across that weapon's units.
void Squad::fire(double dt, const Lane &lane, Shots &shots, double lane_speed) {
	int offset = 0;
	for (int w = 0; w < int(weapons.size()); w++) {
		const int c = counts[w];
		if (c == 0) {
			acc[w] = 0.0f;
			continue;
		}
		const WeaponSpec &wd = weapons[w];
		acc[w] = float(gd::min(acc[w] + c * wd.fire_rate * dt, double(c)));
		while (acc[w] >= 1.0f) {
			acc[w] -= 1.0;
			const Vector2 p = unit_position(offset + rr[w] % c);
			rr[w] += 1;
			Vector2 dir(0.0f, -1.0f);
			if (wd.aim == WeaponSpec::AUTO) {
				const int t = lane.nearest_target(p, wd.reach);
				if (t < 0) {
					continue;
				}
				// Lead the target by its travel time.
				Vector2 target(lane.x[t], lane.z[t]);
				const double eta = p.distance_to(target) / wd.projectile_speed;
				target.y += lane.speed_of(t, lane_speed) * eta;
				dir = (target - p).normalized();
			}
			shots.fire(wd, w, p, dir, damage_mult);
		}
		offset += c;
	}
}

PackedInt32Array Squad::get_counts() const {
	return packed(counts);
}

void Squad::_bind_methods() {
	ClassDB::bind_method(D_METHOD("total"), &Squad::total);
	ClassDB::bind_method(D_METHOD("radius"), &Squad::radius);
	ClassDB::bind_method(D_METHOD("limit"), &Squad::limit);
	ClassDB::bind_method(D_METHOD("steer", "dx"), &Squad::steer);
	ClassDB::bind_method(D_METHOD("unit_position", "k"), &Squad::unit_position);
	ClassDB::bind_method(D_METHOD("weapon_at", "k"), &Squad::weapon_at);
	ClassDB::bind_method(D_METHOD("get_x"), &Squad::get_x);
	ClassDB::bind_method(D_METHOD("get_target_x"), &Squad::get_target_x);
	ClassDB::bind_method(D_METHOD("set_target_x", "v"), &Squad::set_target_x);
	ClassDB::bind_method(D_METHOD("get_capacity"), &Squad::get_capacity);
	ClassDB::bind_method(D_METHOD("get_damage_mult"), &Squad::get_damage_mult);
	ClassDB::bind_method(D_METHOD("get_weapons"), &Squad::get_weapons);
	ClassDB::bind_method(D_METHOD("get_counts"), &Squad::get_counts);
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "x"), "", "get_x");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "target_x"), "set_target_x", "get_target_x");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "capacity"), "", "get_capacity");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "damage_mult"), "", "get_damage_mult");
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "weapons"), "", "get_weapons");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "counts"), "", "get_counts");
	// Whole metres, so they bind as integer constants for the scripts.
	ClassDB::bind_integer_constant(get_class_static(), "", "Z", int64_t(Z));
	ClassDB::bind_integer_constant(get_class_static(), "", "EDGE", int64_t(EDGE));
}

} // namespace gunlord
