#pragma once
// The content the simulation and painter read: WeaponDef and ObjectDef
// (src/content/), copied once out of their GDScript resources into plain
// structs, so the hot loops never cross into the engine for a field.

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>

namespace gunlord {

struct WeaponSpec {
	enum Aim { STRAIGHT, AUTO };

	godot::Ref<godot::Resource> def;
	godot::StringName id;
	double damage = 1.0;
	double fire_rate = 1.0;
	int aim = STRAIGHT;
	int spread_count = 1;
	double spread_angle = 0.0;
	double jitter = 0.0;
	int pierce = 0;
	double splash = 0.0;
	bool homing = false;
	double reach = 70.0;
	double projectile_speed = 35.0;
	godot::Color color;
	godot::StringName model;
	double size = 1.0;
	godot::StringName projectile;

	static WeaponSpec of(const godot::Ref<godot::Resource> &def) {
		WeaponSpec w;
		w.def = def;
		w.id = def->get("id");
		w.damage = def->get("damage");
		w.fire_rate = def->get("fire_rate");
		w.aim = int(def->get("aim"));
		w.spread_count = int(def->get("spread_count"));
		w.spread_angle = def->get("spread_angle");
		w.jitter = def->get("jitter");
		w.pierce = int(def->get("pierce"));
		w.splash = def->get("splash");
		w.homing = def->get("homing");
		w.reach = def->get("reach");
		w.projectile_speed = def->get("projectile_speed");
		w.color = def->get("color");
		w.model = def->get("model");
		w.size = def->get("size");
		w.projectile = def->get("projectile");
		return w;
	}
};

struct ObjectSpec {
	enum Payout { NONE, ADD_UNITS, MULTIPLY, REMOVE_UNITS, DAMAGE_BONUS, SURGE };
	enum Look { PANEL, PEDESTAL };

	godot::Ref<godot::Resource> def;
	godot::StringName id;
	bool enemy = false;
	double hp = 1.0;
	double radius = 0.35;
	double walk = 0.0;
	double seek = 0.0;
	double contact_kills = 0.0;
	bool persistent = false;
	int payout = NONE;
	double amount = 0.0;
	godot::StringName weapon;
	godot::StringName surge;
	bool final = false;
	godot::String caption;
	godot::StringName model;
	godot::StringName icon;
	int look = PANEL;
	double size = 1.0;
	godot::Color color;
	godot::Color tint;

	bool is_trap() const { return payout == REMOVE_UNITS; }

	static ObjectSpec of(const godot::Ref<godot::Resource> &def) {
		ObjectSpec o;
		o.def = def;
		o.id = def->get("id");
		o.enemy = def->get("enemy");
		o.hp = def->get("hp");
		o.radius = def->get("radius");
		o.walk = def->get("walk");
		o.seek = def->get("seek");
		o.contact_kills = def->get("contact_kills");
		o.persistent = def->get("persistent");
		o.payout = int(def->get("payout"));
		o.amount = def->get("amount");
		o.weapon = def->get("weapon");
		o.surge = def->get("surge");
		o.final = def->get("final");
		o.caption = def->get("caption");
		o.model = def->get("model");
		o.icon = def->get("icon");
		o.look = int(def->get("look"));
		o.size = def->get("size");
		o.color = def->get("color");
		o.tint = def->get("tint");
		return o;
	}
};

} // namespace gunlord
