#include "battle.h"

#include "gd.h"

#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

using namespace godot;

namespace gunlord {

Ref<Battle> Battle::create(const Array &roster, const Array &arms, const Dictionary &objects,
		const Dictionary &surges, const Ref<RefCounted> &p_level) {
	Ref<Battle> b;
	b.instantiate();
	b->level = p_level;
	b->waves = p_level->get("waves");
	b->speed = p_level->get("speed");
	b->accel = p_level->get("accel");
	for (int64_t w = 0; w < roster.size(); w++) {
		b->weapon_index[Ref<Resource>(roster[w])->get("id")] = w;
	}
	b->arsenal_defs = roster.duplicate();
	b->arsenal_defs.append_array(arms);
	for (int64_t w = 0; w < b->arsenal_defs.size(); w++) {
		b->arsenal.push_back(WeaponSpec::of(b->arsenal_defs[w]));
	}
	b->squad.instantiate();
	b->squad->setup(roster, p_level->get("capacity"));
	b->arms.instantiate();
	b->arms->setup(b->squad, b->arsenal, p_level->get("loadout"), surges);
	const Array start = p_level->get("start");
	for (int64_t k = 0; k < start.size(); k++) {
		const Array s = start[k];
		b->squad->add(b->weapon_index[s[0]], s[1]);
	}
	b->peak_units = b->squad->total();
	b->lane.instantiate();
	const PackedFloat32Array walls = p_level->get("walls");
	b->lane->walls.assign(walls.ptr(), walls.ptr() + walls.size());
	b->shots.instantiate();
	// The timeline, resolved once: a stage may bring its own variant of an object.
	const Array timeline = p_level->get("timeline");
	for (int64_t k = 0; k < timeline.size(); k++) {
		const Dictionary e = timeline[k];
		const Ref<Resource> d = e.has("def") ? e["def"] : objects[e["id"]];
		const int kind = b->lane->kind_of(d);
		const ObjectSpec &spec = b->lane->kinds[kind];
		b->timeline.push_back({ e["t"], kind, e["x"], e.get("z", 0.0), e.get("hp", spec.hp),
				e.get("amount", spec.amount), e.get("wave", 0) });
	}
	return b;
}

// The lane's own speed is the main difficulty dial.
double Battle::lane_speed() const {
	return speed + time * accel;
}

void Battle::tick(double dt) {
	if (state != RUNNING) {
		return;
	}
	const bool frozen = arms->frozen();
	if (!frozen) {
		time += dt;
		spawn();
	}
	squad->move(dt);
	if (!frozen) {
		lane->advance(dt, lane_speed(), squad->x);
		contacts(dt);
	}
	grid.build(**lane);
	squad->fire(dt, **lane, **shots, frozen ? 0.0 : lane_speed());
	arms->tick(dt, **lane, **shots);
	shots->chain = arms->chain();
	shots->advance(dt, **lane, grid);
	shot_events();
	payouts();
	lane->compact();
	peak_units = gd::max(peak_units, squad->total());
	if (state == RUNNING && squad->total() == 0) {
		state = LOST;
	}
	if (state != RUNNING) {
		Dictionary e;
		e["kind"] = StringName("end");
		e["won"] = state == WON;
		events.append(e);
	}
}

void Battle::spawn() {
	while (next < timeline.size() && timeline[next].t <= time) {
		const Spawn &e = timeline[next];
		lane->spawn(e.kind, e.x, Lane::SPAWN_Z + e.z, e.hp, e.amount);
		wave = gd::max(wave, e.wave);
		next++;
	}
}

void Battle::contacts(double dt) {
	const double r = squad->radius();
	const int n = lane->size();
	for (int i = 0; i < n; i++) {
		const ObjectSpec &d = lane->def(i);
		if (!lane->alive[i] || !d.enemy) {
			continue;
		}
		const double front = Squad::Z - r - d.radius;
		const bool touching = lane->z[i] >= front && std::abs(lane->x[i] - squad->x) < r + d.radius;
		const bool breached = lane->z[i] > Squad::Z + 1.0;
		if (!touching && !breached) {
			continue;
		}
		if (d.persistent) {
			lane->z[i] = float(gd::min<double>(lane->z[i], front));
			struck(squad->wound(d.contact_kills * dt));
		} else {
			struck(int(d.contact_kills));
			lane->alive[i] = 0;
			enemy_died(i);
		}
	}
}

void Battle::payouts() {
	const std::vector<int> destroyed = lane->destroyed;
	for (const int i : destroyed) {
		const ObjectSpec &d = lane->def(i);
		if (d.enemy) {
			enemy_died(i);
		}
		const double n = lane->amount[i];
		const Vector3 at(lane->x[i], 1.5f, lane->z[i]);
		switch (d.payout) {
			case ObjectSpec::ADD_UNITS: {
				const int added = squad->enlist(weapon_index[d.weapon], int(n));
				const bool full = added < int(n);
				callout(at, full ? String("MAX") : String(d.def->call("caption_for", n)), d.color, full ? "max" : "gain");
			} break;
			case ObjectSpec::MULTIPLY: {
				const int grown = squad->multiply(weapon_index[d.weapon], n);
				const bool full = grown == 0 && squad->total() >= squad->capacity;
				callout(at, full ? String("MAX") : "+" + String::num_int64(grown), d.color, full ? "max" : "gain");
			} break;
			case ObjectSpec::REMOVE_UNITS:
				lose(int(n));
				callout(at, d.def->call("caption_for", n), d.color, "loss");
				break;
			case ObjectSpec::DAMAGE_BONUS:
				squad->damage_mult += n;
				callout(at, d.def->call("caption_for", n), d.color, "boost");
				break;
			case ObjectSpec::SURGE:
				arms->grant(d.surge);
				callout(at, d.caption, d.color, "surge");
				break;
			default:
				break;
		}
		if (d.final) {
			state = WON;
		}
	}
}

void Battle::shot_events() {
	const std::vector<float> &f = shots->fired;
	for (size_t k = 0; k + 2 < f.size(); k += 3) {
		Dictionary e;
		e["kind"] = StringName("fire");
		e["at"] = Vector3(f[k], 0.0f, f[k + 1]);
		e["weapon"] = int(f[k + 2]);
		events.append(e);
	}
	const std::vector<float> &h = shots->impacts;
	for (size_t k = 0; k + 4 < h.size(); k += 5) {
		Dictionary e;
		e["kind"] = StringName("hit");
		e["at"] = Vector3(h[k], 0.0f, h[k + 1]);
		e["weapon"] = int(h[k + 2]);
		e["splash"] = double(h[k + 3]);
		e["target"] = lane->def(int(h[k + 4])).def;
		events.append(e);
	}
	const std::vector<float> &z = shots->zaps;
	for (size_t k = 0; k + 3 < z.size(); k += 4) {
		Dictionary e;
		e["kind"] = StringName("zap");
		e["at"] = Vector3(z[k], 0.6f, z[k + 1]);
		e["to"] = Vector3(z[k + 2], 0.6f, z[k + 3]);
		events.append(e);
	}
	shots->fired.clear();
	shots->impacts.clear();
	shots->zaps.clear();
}

// The front line takes n blows: the shield saves what it can, the rest fall.
void Battle::struck(int n) {
	const int saved = arms->absorb(n);
	if (saved > 0) {
		Dictionary e;
		e["kind"] = StringName("shielded");
		e["count"] = saved;
		events.append(e);
	}
	lose(n - saved);
}

// Removes n units from the rim of the squad, announcing each one's death.
void Battle::lose(int n) {
	const int total = squad->total();
	for (int k = total - 1; k > gd::max(total - n, 0) - 1; k--) {
		const Vector2 p = squad->unit_position(k);
		const WeaponSpec &wd = squad->weapons[squad->weapon_at(k)];
		Dictionary e;
		e["kind"] = StringName("death");
		e["at"] = Vector3(p.x, 0.0f, p.y);
		e["model"] = wd.model;
		e["size"] = wd.size;
		e["enemy"] = false;
		e["tint"] = Color(0, 0, 0, 0);
		events.append(e);
	}
	squad->remove_outer(n);
}

void Battle::enemy_died(int i) {
	const ObjectSpec &d = lane->def(i);
	Dictionary e;
	e["kind"] = StringName("death");
	e["at"] = Vector3(lane->x[i], 0.0f, lane->z[i]);
	e["model"] = d.model;
	e["size"] = d.size;
	e["enemy"] = true;
	e["tint"] = d.tint;
	events.append(e);
}

void Battle::callout(Vector3 at, const String &text, Color color, const StringName &tone) {
	Dictionary e;
	e["kind"] = StringName("payout");
	e["at"] = at;
	e["text"] = text;
	e["color"] = color;
	e["tone"] = tone;
	events.append(e);
}

void Battle::_bind_methods() {
	ClassDB::bind_static_method("Battle", D_METHOD("create", "roster", "arms", "objects", "surges", "level"), &Battle::create);
	ClassDB::bind_method(D_METHOD("tick", "dt"), &Battle::tick);
	ClassDB::bind_method(D_METHOD("lane_speed"), &Battle::lane_speed);
	ClassDB::bind_method(D_METHOD("get_state"), &Battle::get_state);
	ClassDB::bind_method(D_METHOD("set_state", "state"), &Battle::set_state);
	ClassDB::bind_method(D_METHOD("get_time"), &Battle::get_time);
	ClassDB::bind_method(D_METHOD("get_wave"), &Battle::get_wave);
	ClassDB::bind_method(D_METHOD("get_waves"), &Battle::get_waves);
	ClassDB::bind_method(D_METHOD("get_peak_units"), &Battle::get_peak_units);
	ClassDB::bind_method(D_METHOD("get_level"), &Battle::get_level);
	ClassDB::bind_method(D_METHOD("get_squad"), &Battle::get_squad);
	ClassDB::bind_method(D_METHOD("get_lane"), &Battle::get_lane);
	ClassDB::bind_method(D_METHOD("get_shots"), &Battle::get_shots);
	ClassDB::bind_method(D_METHOD("get_arms"), &Battle::get_arms);
	ClassDB::bind_method(D_METHOD("get_arsenal"), &Battle::get_arsenal);
	ClassDB::bind_method(D_METHOD("get_events"), &Battle::get_events);
	ADD_PROPERTY(PropertyInfo(Variant::INT, "state", PROPERTY_HINT_ENUM, "Running,Won,Lost", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_CLASS_IS_ENUM, "Battle.State"), "set_state", "get_state");
	ADD_PROPERTY(PropertyInfo(Variant::FLOAT, "time"), "", "get_time");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "wave"), "", "get_wave");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "waves"), "", "get_waves");
	ADD_PROPERTY(PropertyInfo(Variant::INT, "peak_units"), "", "get_peak_units");
	ADD_PROPERTY(PropertyInfo(Variant::NIL, "level", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_NIL_IS_VARIANT), "", "get_level");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "squad", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT, "Squad"), "", "get_squad");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "lane", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT, "Lane"), "", "get_lane");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "shots", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT, "Shots"), "", "get_shots");
	ADD_PROPERTY(PropertyInfo(Variant::OBJECT, "arms", PROPERTY_HINT_NONE, "", PROPERTY_USAGE_DEFAULT, "Arms"), "", "get_arms");
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "arsenal"), "", "get_arsenal");
	ADD_PROPERTY(PropertyInfo(Variant::ARRAY, "events"), "", "get_events");
	BIND_ENUM_CONSTANT(RUNNING);
	BIND_ENUM_CONSTANT(WON);
	BIND_ENUM_CONSTANT(LOST);
}

} // namespace gunlord
