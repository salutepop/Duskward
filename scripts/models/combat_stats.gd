class_name CombatStats
extends RefCounted
## Pure stat derivation and mitigation formulas.

static func derived_stats(heroes: Dictionary, items: Dictionary, for_hero: String, for_level: int, equipment: Array) -> Dictionary:
	var derived: Dictionary = heroes[for_hero].base.duplicate(true)
	for key in heroes[for_hero].growth:
		derived[key] = float(derived.get(key, 0)) + float(heroes[for_hero].growth[key]) * (for_level - 1)
	for id in equipment:
		if not items.has(id):
			continue
		for key in items[id].stats:
			if key == "lifesteal":
				derived[key] = maxf(float(derived.get(key, 0)), float(items[id].stats[key]))
			else:
				derived[key] = float(derived.get(key, 0)) + float(items[id].stats[key])
	derived.crit_chance = clampf(float(derived.get("crit_chance", 0)), 0, 0.4)
	derived.attack_speed_bonus = clampf(float(derived.get("attack_speed_bonus", 0)), -0.5, 2.0)
	derived.cooldown_reduction = clampf(float(derived.get("cooldown_reduction", 0)), 0, 0.3)
	derived.armor = clampf(float(derived.armor), -50, 300)
	derived.magic_resist = clampf(float(derived.magic_resist), -50, 300)
	derived.lifesteal = float(derived.get("lifesteal", 0))
	return derived

static func mitigation(defense: float) -> float:
	defense = clampf(defense, -50, 300)
	return 100.0 / (100.0 + defense) if defense >= 0 else 2.0 - 100.0 / (100.0 - defense)
