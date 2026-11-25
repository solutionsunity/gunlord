#include "shots.h"

#include "gd.h"
#include "grid.h"
#include "lane.h"

using namespace godot;

namespace gunlord {

Shots::Shots() {
	rng.instantiate();
	rng->set_seed(1);
}

void Shots::fire(const WeaponSpec &wd, int w, Vector2 p, Vector2 dir, double mult) {
	fired.push_back(p.x);
	fired.push_back(p.y);
	fired.push_back(float(w));
	const int n = wd.spread_count;
	for (int s = 0; s < n; s++) {
		double a = 0.0;
		if (n > 1) {
			a = godot::Math::deg_to_rad(wd.spread_angle) * (double(s) / (n - 1) - 0.5);
		}
		if (wd.jitter > 0.0) {
			a += godot::Math::deg_to_rad(double(rng->randf_range(-wd.jitter, wd.jitter)));   // the generator gives a 32-bit float; script math is 64-bit
		}
		const Vector2 v = dir.rotated(real_t(a)) * real_t(wd.projectile_speed);
		x.push_back(p.x);
		z.push_back(p.y);
		vx.push_back(v.x);
		vz.push_back(v.y);
		damage.push_back(float(wd.damage * mult));
		splash.push_back(float(wd.splash));
		life.push_back(float(wd.reach / wd.projectile_speed));
		pierce.push_back(wd.pierce);
		weapon.push_back(w);
		last_hit.push_back(-1);
		hits_traps.push_back(wd.aim == WeaponSpec::STRAIGHT ? 1 : 0);
		homing.push_back(wd.homing ? 1 : 0);
	}
}

void Shots::advance(double dt, Lane &lane, const Grid &grid) {
	int i = 0;
	while (i < size()) {
		life[i] -= dt;
		if (homing[i]) {
			steer(i, dt, lane);
		}
		x[i] += vx[i] * dt;
		z[i] += vz[i] * dt;
		bool spent = life[i] <= 0.0f;
		if (!spent) {
			const int hit = grid.first_hit(lane, x[i], z[i], last_hit[i], hits_traps[i] == 1);
			if (hit >= 0) {
				lane.damage(hit, damage[i]);
				impacts.insert(impacts.end(), { x[i], z[i], float(weapon[i]), splash[i], float(hit) });
				if (splash[i] > 0.0f) {
					lane.splash(lane.x[hit], lane.z[hit], splash[i], damage[i] * 0.5, hit);
				}
				if (chain > 0.0 && lane.def(hit).enemy) {
					arc(hit, damage[i] * chain, lane);
				}
				last_hit[i] = lane.serial[hit];
				pierce[i] -= 1;
				spent = pierce[i] < 0;
			}
		}
		if (spent) {
			swap_remove(i);
		} else {
			i++;
		}
	}
}

// Turns a homing shot toward the nearest enemy ahead of it.
void Shots::steer(int i, double dt, const Lane &lane) {
	const int t = lane.nearest_target(Vector2(x[i], z[i]), 25.0, true);
	if (t < 0) {
		return;
	}
	Vector2 v(vx[i], vz[i]);
	const double want = (Vector2(lane.x[t], lane.z[t]) - Vector2(x[i], z[i])).angle();
	const double turn = gd::clamp(godot::Math::angle_difference(double(v.angle()), want), -TURN * dt, TURN * dt);
	v = v.rotated(real_t(turn));
	vx[i] = v.x;
	vz[i] = v.y;
}

// A chain arc: the hit enemy's nearest neighbours take a share of the hit.
void Shots::arc(int hit, double dmg, Lane &lane) {
	for (const int j : lane.enemies_near(lane.x[hit], lane.z[hit], ARC_REACH, ARCS, hit)) {
		lane.damage(j, dmg);
		zaps.insert(zaps.end(), { lane.x[hit], lane.z[hit], lane.x[j], lane.z[j] });
	}
}

void Shots::swap_remove(int i) {
	const int last = size() - 1;
	x[i] = x[last];
	z[i] = z[last];
	vx[i] = vx[last];
	vz[i] = vz[last];
	damage[i] = damage[last];
	splash[i] = splash[last];
	life[i] = life[last];
	pierce[i] = pierce[last];
	weapon[i] = weapon[last];
	last_hit[i] = last_hit[last];
	hits_traps[i] = hits_traps[last];
	homing[i] = homing[last];
	x.pop_back();
	z.pop_back();
	vx.pop_back();
	vz.pop_back();
	damage.pop_back();
	splash.pop_back();
	life.pop_back();
	pierce.pop_back();
	weapon.pop_back();
	last_hit.pop_back();
	hits_traps.pop_back();
	homing.pop_back();
}

PackedFloat32Array Shots::get_x() const { return packed(x); }
PackedFloat32Array Shots::get_z() const { return packed(z); }
PackedFloat32Array Shots::get_vx() const { return packed(vx); }
PackedFloat32Array Shots::get_vz() const { return packed(vz); }
PackedInt32Array Shots::get_weapon() const { return packed(weapon); }

void Shots::_bind_methods() {
	ClassDB::bind_method(D_METHOD("size"), &Shots::size);
	ClassDB::bind_method(D_METHOD("get_x"), &Shots::get_x);
	ClassDB::bind_method(D_METHOD("get_z"), &Shots::get_z);
	ClassDB::bind_method(D_METHOD("get_vx"), &Shots::get_vx);
	ClassDB::bind_method(D_METHOD("get_vz"), &Shots::get_vz);
	ClassDB::bind_method(D_METHOD("get_weapon"), &Shots::get_weapon);
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "x"), "", "get_x");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "z"), "", "get_z");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "vx"), "", "get_vx");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "vz"), "", "get_vz");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "weapon"), "", "get_weapon");
}

} // namespace gunlord
