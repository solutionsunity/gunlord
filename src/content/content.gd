class_name Content
extends RefCounted
## The roster. Weapons are listed centre-first: the formation places earlier
## weapons in the middle of the squad, so contact losses take later ones first.


static func weapons() -> Array[WeaponDef]:
	var list: Array[WeaponDef] = [
		_weapon(&"cannon", "Cannon", {
			damage = 10.0, fire_rate = 0.5, aim = WeaponDef.Aim.AUTO, splash = 2.2,
			reach = 26.0, projectile_speed = 24.0, color = Color("f2a516"), size = 1.5, model = &"cannon", projectile = &"ball",
		}),
		_weapon(&"gatling", "Gatling", {
			damage = 1.0, fire_rate = 9.0, aim = WeaponDef.Aim.AUTO, jitter = 4.0,
			reach = 22.0, projectile_speed = 45.0, color = Color("b05cf0"), size = 1.15, model = &"gatlinger", projectile = &"tracer",
		}),
		_weapon(&"gun", "Gun", {
			damage = 2.0, fire_rate = 2.5, pierce = 1,
			reach = 30.0, projectile_speed = 50.0, color = Color("3fd1c9"), model = &"gunner", projectile = &"tracer",
		}),
		_weapon(&"crossbow", "Crossbow", {
			damage = 1.0, fire_rate = 1.5, reach = 28.0, projectile_speed = 32.0, color = Color("4d8df7"),
			model = &"crossbowman", projectile = &"bolt",
		}),
	]
	return list


static func objects() -> Dictionary:
	var list: Array[ObjectDef] = [
		_object(&"soldier", {
			enemy = true, hp = 3.0, radius = 0.35, walk = 1.0, seek = 3.0, contact_kills = 1.0,
			color = Color("d8423a"), size = 1, model = &"knight",
		}),
		_object(&"runner", {
			enemy = true, hp = 1.0, radius = 0.3, walk = 5.0, seek = 6.0, contact_kills = 1.0,
			color = Color("f07a2a"), size = 0.85, model = &"rogue",
		}),
		_object(&"brute", {
			enemy = true, hp = 250.0, radius = 1.3, walk = 0.3, seek = 2.0, contact_kills = 4.0,
			persistent = true, payout = ObjectDef.Payout.ADD_UNITS, amount = 30.0, weapon = &"crossbow",
			caption = "+{n}", color = Color("7a1f1f"), size = 2.6, model = &"barbarian",
		}),
		_object(&"warlord", {
			enemy = true, hp = 2000.0, radius = 1.6, walk = 0.2, seek = 2.0, contact_kills = 6.0,
			persistent = true, final = true, color = Color("3a0d0d"), size = 3.4, model = &"warlord",
			tint = Color("5c0d18"),
		}),
		_object(&"recruits", {
			hp = 4.0, radius = 0.9, payout = ObjectDef.Payout.ADD_UNITS, amount = 3.0, weapon = &"crossbow",
			caption = "+{n}", color = Color("4d8df7"),
		}),
		_object(&"multiplier", {
			hp = 40.0, radius = 0.9, payout = ObjectDef.Payout.MULTIPLY, amount = 1.5, weapon = &"crossbow",
			caption = "×{x}", color = Color("f5d142"),
		}),
		_object(&"trap", {
			hp = 3.0, radius = 0.9, payout = ObjectDef.Payout.REMOVE_UNITS, amount = 5.0,
			caption = "−{n}", color = Color("e0303a"),
		}),
		_object(&"gun_crate", {
			hp = 25.0, radius = 0.9, payout = ObjectDef.Payout.ADD_UNITS, amount = 4.0, weapon = &"gun",
			caption = "GUN +{n}", look = ObjectDef.Look.PEDESTAL, model = &"gunner", color = Color("3fd1c9"),
		}),
		_object(&"gatling_crate", {
			hp = 45.0, radius = 0.9, payout = ObjectDef.Payout.ADD_UNITS, amount = 3.0, weapon = &"gatling",
			caption = "GATLING +{n}", look = ObjectDef.Look.PEDESTAL, model = &"gatlinger", color = Color("b05cf0"),
		}),
		_object(&"cannon_crate", {
			hp = 70.0, radius = 0.9, payout = ObjectDef.Payout.ADD_UNITS, amount = 1.0, weapon = &"cannon",
			caption = "CANNON +{n}", look = ObjectDef.Look.PEDESTAL, model = &"cannon", color = Color("f2a516"),
		}),
		_object(&"war_drum", {
			hp = 40.0, radius = 0.9, payout = ObjectDef.Payout.DAMAGE_BONUS, amount = 0.2,
			caption = "ATK +{p}%", look = ObjectDef.Look.PEDESTAL, color = Color("f0f0f0"),
		}),
	]
	var by_id := {}
	for d in list:
		by_id[d.id] = d
	return by_id


static func _weapon(id: StringName, label: String, props: Dictionary) -> WeaponDef:
	var w := WeaponDef.new()
	w.id = id
	w.label = label
	for key in props:
		w.set(key, props[key])
	return w


static func _object(id: StringName, props: Dictionary) -> ObjectDef:
	var d := ObjectDef.new()
	d.id = id
	for key in props:
		d.set(key, props[key])
	return d
