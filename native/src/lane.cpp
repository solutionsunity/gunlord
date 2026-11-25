#include "lane.h"

#include "gd.h"

#include <algorithm>

using namespace godot;

namespace gunlord {

PackedFloat32Array packed(const std::vector<float> &v) {
	PackedFloat32Array out;
	out.resize(int64_t(v.size()));
	std::copy(v.begin(), v.end(), out.ptrw());
	return out;
}

PackedInt32Array packed(const std::vector<int> &v) {
	PackedInt32Array out;
	out.resize(int64_t(v.size()));
	std::copy(v.begin(), v.end(), out.ptrw());
	return out;
}

int Lane::kind_of(const Ref<Resource> &d) {
	for (size_t k = 0; k < kinds.size(); k++) {
		if (kinds[k].def == d) {
			return int(k);
		}
	}
	kinds.push_back(ObjectSpec::of(d));
	return int(kinds.size()) - 1;
}

void Lane::spawn(int k, double px, double pz, double php, double pamount) {
	kind.push_back(k);
	serial.push_back(next_serial++);
	x.push_back(float(px));
	z.push_back(float(pz));
	hp.push_back(float(php));
	max_hp.push_back(float(php));
	amount.push_back(float(pamount));
	hit_age.push_back(99.0f);
	alive.push_back(1);
}

void Lane::advance(double dt, double lane_speed, double squad_x) {
	const int n = size();
	for (int i = 0; i < n; i++) {
		if (!alive[i]) {
			continue;
		}
		const ObjectSpec &d = def(i);
		hit_age[i] += dt;
		z[i] += speed_of(i, lane_speed) * dt;
		if (d.enemy) {
			if (z[i] > WALL_END_Z) {
				x[i] = float(godot::Math::move_toward(double(x[i]), squad_x, d.seek * dt));
			} else {
				x[i] = float(keep_in_lane(x[i], d.radius));
			}
		} else if (z[i] > WALL_END_Z) {
			alive[i] = 0;   // a pickup that reaches the end of its lane is lost
		}
	}
}

double Lane::keep_in_lane(double px, double r) const {
	double lo = -HALF_WIDTH;
	double hi = HALF_WIDTH;
	for (const float w : walls) {
		if (w < px) {
			lo = gd::max<double>(lo, w);
		} else {
			hi = gd::min<double>(hi, w);
		}
	}
	return hi - lo > 2.0 * r ? gd::clamp(px, lo + r, hi - r) : (lo + hi) / 2.0;
}

void Lane::damage(int i, double dmg) {
	if (!alive[i]) {
		return;
	}
	hp[i] -= dmg;
	hit_age[i] = 0.0f;
	if (hp[i] <= 0.0f) {
		alive[i] = 0;
		destroyed.push_back(i);
	}
}

// Area damage never touches traps: traps are claimed only by a direct straight shot.
void Lane::splash(double px, double pz, double r, double dmg, int skip) {
	const int n = size();
	for (int i = 0; i < n; i++) {
		if (i == skip || !alive[i] || def(i).is_trap()) {
			continue;
		}
		const double reach = r + def(i).radius;
		if (gd::pow2(x[i] - px) + gd::pow2(z[i] - pz) <= reach * reach) {
			damage(i, dmg);
		}
	}
}

// Nearest live object an auto-aim weapon may pick, ahead of p. Traps are
// never picked; with enemies_only, nor are pickups.
int Lane::nearest_target(Vector2 p, double reach, bool enemies_only) const {
	int best = -1;
	double best_d = reach * reach;
	const int n = size();
	for (int i = 0; i < n; i++) {
		if (!alive[i] || def(i).is_trap() || z[i] > p.y || (enemies_only && !def(i).enemy)) {
			continue;
		}
		const double d2 = gd::pow2(double(x[i]) - double(p.x)) + gd::pow2(double(z[i]) - double(p.y));
		if (d2 < best_d) {
			best_d = d2;
			best = i;
		}
	}
	return best;
}

// Up to n live enemies nearest (px, pz) within r, nearest first, never `skip`.
// Distances are kept as 32-bit floats, as the GDScript original kept them.
std::vector<int> Lane::enemies_near(double px, double pz, double r, int n, int skip) const {
	std::vector<int> found;
	std::vector<float> dist;
	const int count = size();
	for (int i = 0; i < count; i++) {
		if (i == skip || !alive[i] || !def(i).enemy) {
			continue;
		}
		const double d2 = gd::pow2(x[i] - px) + gd::pow2(z[i] - pz);
		if (d2 > r * r) {
			continue;
		}
		const auto at = std::lower_bound(dist.begin(), dist.end(), float(d2)) - dist.begin();
		dist.insert(dist.begin() + at, float(d2));
		found.insert(found.begin() + at, i);
	}
	if (int(found.size()) > n) {
		found.resize(n);
	}
	return found;
}

void Lane::compact() {
	int j = 0;
	const int n = size();
	for (int i = 0; i < n; i++) {
		if (!alive[i]) {
			continue;
		}
		if (i != j) {
			kind[j] = kind[i];
			serial[j] = serial[i];
			x[j] = x[i];
			z[j] = z[i];
			hp[j] = hp[i];
			max_hp[j] = max_hp[i];
			amount[j] = amount[i];
			hit_age[j] = hit_age[i];
			alive[j] = 1;
		}
		j++;
	}
	kind.resize(j);
	serial.resize(j);
	x.resize(j);
	z.resize(j);
	hp.resize(j);
	max_hp.resize(j);
	amount.resize(j);
	hit_age.resize(j);
	alive.resize(j);
	destroyed.clear();
}

int Lane::nearest_boss(double beyond) const {
	int best = -1;
	for (int i = 0; i < size(); i++) {
		if (alive[i] && def(i).persistent && z[i] > beyond && (best < 0 || z[i] > z[best])) {
			best = i;
		}
	}
	return best;
}

Ref<Resource> Lane::def_of(int i) const {
	ERR_FAIL_INDEX_V(i, size(), Ref<Resource>());
	return def(i).def;
}

PackedFloat32Array Lane::get_x() const { return packed(x); }
PackedFloat32Array Lane::get_z() const { return packed(z); }
PackedFloat32Array Lane::get_hp() const { return packed(hp); }
PackedFloat32Array Lane::get_max_hp() const { return packed(max_hp); }
PackedFloat32Array Lane::get_amount() const { return packed(amount); }
PackedFloat32Array Lane::get_hit_age() const { return packed(hit_age); }
PackedInt32Array Lane::get_serial() const { return packed(serial); }

PackedByteArray Lane::get_alive() const {
	PackedByteArray out;
	out.resize(int64_t(alive.size()));
	std::copy(alive.begin(), alive.end(), out.ptrw());
	return out;
}

void Lane::_bind_methods() {
	ClassDB::bind_method(D_METHOD("size"), &Lane::size);
	ClassDB::bind_method(D_METHOD("def_of", "i"), &Lane::def_of);
	ClassDB::bind_method(D_METHOD("nearest_boss", "beyond"), &Lane::nearest_boss);
	ClassDB::bind_method(D_METHOD("get_x"), &Lane::get_x);
	ClassDB::bind_method(D_METHOD("get_z"), &Lane::get_z);
	ClassDB::bind_method(D_METHOD("get_hp"), &Lane::get_hp);
	ClassDB::bind_method(D_METHOD("get_max_hp"), &Lane::get_max_hp);
	ClassDB::bind_method(D_METHOD("get_amount"), &Lane::get_amount);
	ClassDB::bind_method(D_METHOD("get_hit_age"), &Lane::get_hit_age);
	ClassDB::bind_method(D_METHOD("get_serial"), &Lane::get_serial);
	ClassDB::bind_method(D_METHOD("get_alive"), &Lane::get_alive);
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "x"), "", "get_x");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "z"), "", "get_z");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "hp"), "", "get_hp");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "max_hp"), "", "get_max_hp");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "amount"), "", "get_amount");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_FLOAT32_ARRAY, "hit_age"), "", "get_hit_age");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_INT32_ARRAY, "serial"), "", "get_serial");
	ADD_PROPERTY(PropertyInfo(Variant::PACKED_BYTE_ARRAY, "alive"), "", "get_alive");
	ClassDB::bind_integer_constant(get_class_static(), "", "SPAWN_Z", int64_t(SPAWN_Z));
	ClassDB::bind_integer_constant(get_class_static(), "", "WALL_END_Z", int64_t(WALL_END_Z));
	ClassDB::bind_integer_constant(get_class_static(), "", "HALF_WIDTH", int64_t(HALF_WIDTH));
}

} // namespace gunlord
