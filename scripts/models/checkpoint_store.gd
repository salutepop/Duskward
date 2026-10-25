class_name CheckpointStore
extends RefCounted
## Checkpoint validation and schema helpers.

static func schema_for(path: String) -> int:
	if not FileAccess.file_exists(path):
		return 0
	var text = FileAccess.get_file_as_string(path)
	if text.length() > 2000000:
		return 0
	var parser = JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return 0
	var schema = parser.data.get("schema", 0)
	return int(schema) if schema is int or schema is float else 0

static func valid_metrics(metrics: Dictionary, known_template: Dictionary) -> bool:
	if not metrics is Dictionary:
		return false
	for key in known_template:
		if not metrics.has(key):
			continue
		var entry = metrics[key]
		if known_template[key] is Dictionary:
			if not entry is Dictionary or entry.size() > 128:
				return false
			for counter in entry:
				if not counter is String or counter.length() > 80:
					return false
				if not _valid_nonnegative_number(entry[counter]):
					return false
				if key in ["casts_by_slot", "hits_by_source"] and float(entry[counter]) != floorf(float(entry[counter])):
					return false
		elif key == "waves":
			if not entry is Array or entry.size() > 10:
				return false
			for cleared in entry:
				if not cleared is Dictionary:
					return false
				for field in ["wave", "time", "base_hp", "level", "gold_earned"]:
					if not _valid_nonnegative_number(cleared.get(field)):
						return false
				if cleared.wave < 1 or cleared.wave > 10 or cleared.wave != floorf(float(cleared.wave)):
					return false
				if cleared.level < 1 or cleared.level > 12 or cleared.level != floorf(float(cleared.level)):
					return false
				if cleared.base_hp > 6000.0:
					return false
		elif not _valid_nonnegative_number(entry):
			return false
		elif known_template[key] is int and float(entry) != floorf(float(entry)):
			return false
	return true

static func valid_save_dict(save: Dictionary, content_hash: String, heroes: Dictionary, derived_stats_func: Callable) -> bool:
	if save.get("schema", 0) != 4 or save.get("content_hash", "") != content_hash:
		return false
	if not save.get("hero") is String or not heroes.has(save.hero):
		return false
	if save.get("phase", "") not in ["Preparation", "FinalPreparation"]:
		return false
	for key in ["seed", "completed_wave", "base_hp", "hp", "energy", "gold", "xp", "level", "potions", "elapsed", "potion_cd", "sanctuary_cd"]:
		if not (save.get(key) is float or save.get(key) is int):
			return false
		if not is_finite(float(save[key])):
			return false
	for key in ["seed", "completed_wave", "gold", "xp", "level", "potions"]:
		if float(save[key]) != floorf(float(save[key])):
			return false
	if save.completed_wave < 0 or save.completed_wave > 10:
		return false
	if save.phase == "FinalPreparation" and save.completed_wave != 10:
		return false
	if save.phase == "Preparation" and save.completed_wave == 10:
		return false
	if save.base_hp <= 0 or save.base_hp > 6000.0:
		return false
	if save.gold < 0 or save.gold > 1000000000 or save.xp < 0 or save.xp > 1000000000:
		return false
	if save.level < 1 or save.level > 12 or save.potions < 0 or save.potions > 3 or save.elapsed < 0:
		return false
	if save.potion_cd < 0 or save.potion_cd > 30 or save.sanctuary_cd < 0 or save.sanctuary_cd > 30:
		return false
	if not save.get("rng_state") is String or not save.rng_state.is_valid_int():
		return false
	if not save.get("spawn_rng_state") is String or not save.spawn_rng_state.is_valid_int():
		return false
	if not save.get("camp_rng_state") is String or not save.camp_rng_state.is_valid_int():
		return false
	if save.get("ruleset", "") != "fast" and save.get("ruleset", "") != "classic":
		return false
	if not save.get("inventory") is Array or save.inventory.size() > 6:
		return false
	for id in save.inventory:
		if not id is String or not heroes.has(id) or id == "healing_potion":
			return false
	var saved_stats: Dictionary = derived_stats_func.call(save.hero, int(save.level), save.inventory)
	if save.hp <= 0 or save.hp > saved_stats.max_hp or save.energy < 0 or save.energy > saved_stats.max_energy:
		return false
	if not save.get("cooldowns") is Dictionary or save.cooldowns.size() != 4:
		return false
	for slot in ["Q", "W", "E", "R"]:
		var cd = save.cooldowns.get(slot)
		if not (cd is float or cd is int) or not is_finite(float(cd)) or cd < 0 or cd > 3600:
			return false
	if not valid_metrics(save.get("metrics", {}), {}):
		return false
	return true

static func read_valid(path: String, content_hash: String, heroes: Dictionary, derived_stats_func: Callable) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text = FileAccess.get_file_as_string(path)
	if text.length() > 2000000:
		return {}
	var parser = JSON.new()
	if parser.parse(text) != OK:
		return {}
	var parsed = parser.data
	if not parsed is Dictionary:
		return {}
	var save: Dictionary = parsed
	if not valid_save_dict(save, content_hash, heroes, derived_stats_func):
		return {}
	return save

static func _valid_nonnegative_number(value, upper: float = 1000000000000.0) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= 0 and float(value) <= upper
