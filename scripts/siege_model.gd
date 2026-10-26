class_name SiegeModel
extends RefCounted
## Authoritative offline solo simulation. Presentation has no combat authority.
## Coordinates use meters; callers advance at 30 Hz. RNG is explicitly seeded.
const CASTLE = Vector2(8, 24)
const START = Vector2(16, 24)
const SAVE_PATH = "user://emberwatch_checkpoint.json"
const BUILD = "0.3.0"
const SAVE_SCHEMA = 4
var data: Dictionary = {}
var ruleset: String = "fast"
var tempo: Dictionary = {}
var items: Dictionary = {}
var heroes: Dictionary = {}
var abilities: Dictionary = {}
var enemy_types: Dictionary = {}
var hero_id = "guardian"
var phase = "Preparation"
var wave = 0
var completed_wave = 0
var max_base_hp = 6000.0
var base_hp = 6000.0
var gold = 300
var xp = 0
var level = 1
var stats: Dictionary = {}
var hp = 900.0
var energy = 100.0
var shield = 0.0
var shield_left = 0.0
var pos = START
var facing = Vector2.RIGHT
var inventory: Array = []
var potions = 0
var cooldowns: Dictionary = {"Q":0.0,"W":0.0,"E":0.0,"R":0.0,"F":0.0}
var respawn_left = 0.0
var invulnerable_left = 0.0
var elapsed = 0.0
var prep_left = 0.0
var boss_pattern = ""
var boss_pattern_left = 0.0
var boss_elapsed = 0.0
var boss_phase = 1
var mini_boss_spawned = false
var notice = "Prepare your loadout, then begin the siege."
var notice_left = 8.0
var enemies: Array = []
var projectiles: Array = []
var effects: Array = []
var hazards: Array = []
var pending_casts: Array = []
var energy_reserved = 0.0
var cast_buffer: Dictionary = {}
var shield_groups: Dictionary = {}
var potion_tick_left = 0.0
var potion_ticks = 0
var potion_tick_heal = 0.0
var spawn_queue: Array = []
var event_log: Array = []
var metrics: Dictionary = {}
## Independent streams keep combat decisions from changing future spawn layouts.
var seed_value = 12345
var next_entity_id = 1
var auto_attack_enabled = true
var selected_target_id = -1
var auto_timer = 0.0
var spawn_timer = 0.0
var spawn_was_capped: bool = false
var pulse_zones: Array = []
var traps: Array = []
var potion_cd = 0.0
var potion_heal_left = 0.0
var ranger_buff = 0.0
var ranger_ultimate = 0.0
var ranger_target = -1
var ranger_hits = 0
var arcanist_passive_cd = 0.0
var sanctuary_cd = 0.0
var lifesteal_history: Array = []
var boss_cooldowns = {"cannon":5.0,"smash":3.0,"debris":9.0}
var boss_pattern_data: Dictionary = {}
var boss_thresholds: Array = []
var boss_add_queue = 0
var boss_add_timer = 0.0
var content_hash = ""
var defenders: Array = []
var allies: Array = []
var special_event: Dictionary = {}
var wave_modifier: String = ""
var hero_switch_cooldown: float = 0.0
var inactive_heroes: Dictionary = {}
var enhanced_items: Dictionary = {}
var _active_set_effects: Dictionary = {}
var hunt: Dictionary = {}
var wave_reinforcement_timer: float = 0.0
var wave_reinforcement_count: int = 0
var endless_active: bool = false
var endless_best_wave: int = 0
var _combat_stats = preload("res://scripts/models/combat_stats.gd")
var rng = RandomNumberGenerator.new() # Combat stream; retained public name for QA.
var spawn_rng = RandomNumberGenerator.new()
var camp_rng = RandomNumberGenerator.new()

func _init(selected_ruleset: String = "fast"):
	var source = FileAccess.get_file_as_string("res://data/balance.json")
	data = JSON.parse_string(source)
	ruleset = "classic" if selected_ruleset=="classic" else "fast"
	var tempo_source = FileAccess.get_file_as_string("res://data/tempo_profile.json")
	tempo = JSON.parse_string(tempo_source)
	content_hash = (source+tempo_source+ruleset).sha256_text()
	for item in data.items: items[item.id] = item
	for hero in data.heroes: heroes[hero.id] = hero
	for a in data.abilities: abilities[a.id] = a
	for e in data.enemies: enemy_types[e.id] = e
	reset("guardian")

func reset(new_hero: String, new_seed: int = 12345):
	hero_id = new_hero if heroes.has(new_hero) else "guardian"
	seed_value = new_seed
	rng.seed = new_seed ^ 0x434F4D424154
	spawn_rng.seed = new_seed ^ 0x535041574E
	camp_rng.seed = new_seed ^ 0x43414D50
	phase = "Preparation"
	wave = 0
	completed_wave = 0
	base_hp = max_base_hp
	gold = int(data.rewards.starting_gold)
	xp = 0
	level = 1
	inventory = []
	potions = 0
	cooldowns = {"Q":0.0,"W":0.0,"E":0.0,"R":0.0,"F":0.0}
	pos = START
	facing = Vector2.RIGHT
	shield = 0
	shield_left = 0
	respawn_left = 0
	invulnerable_left = 0
	elapsed = 0
	prep_left = 0
	enemies = []
	projectiles = []
	effects = []
	hazards = []
	pending_casts = []
	energy_reserved = 0
	cast_buffer = {}
	shield_groups = {}
	potion_ticks = 0
	potion_tick_left = 0
	spawn_queue = []
	pulse_zones = []
	traps = []
	event_log = []
	next_entity_id = 1
	auto_timer = 0
	auto_attack_enabled = true
	selected_target_id = -1
	spawn_timer = 0
	spawn_was_capped = false
	potion_cd = 0
	potion_heal_left = 0
	ranger_buff = 0
	ranger_ultimate = 0
	ranger_hits = 0
	ranger_target = -1
	arcanist_passive_cd = 0
	sanctuary_cd = 0
	lifesteal_history = []
	boss_pattern = ""
	boss_pattern_left = 0
	boss_elapsed = 0
	boss_phase = 1
	mini_boss_spawned = false
	boss_cooldowns = {"cannon":5.0,"smash":3.0,"debris":9.0}
	boss_pattern_data = {}
	boss_thresholds = []
	boss_add_queue = 0
	boss_add_timer = 0
	metrics = {"kills":0,"deaths":0,"damage_dealt":0.0,"damage_taken":0.0,"base_damage":0.0,"casts":0,"weaknesses_destroyed":0,"cannons_cancelled":0,"gold_earned":300,"waves":[],"boss_seconds":0.0,"casts_by_slot":{},"damage_by_source":{},"hits_by_source":{},"base_damage_by_kind":{},"hero_damage_by_kind":{},"defender_damage":0.0,"defender_deaths":0,"defender_kills":0,"hunt_attempts":0,"hunt_successes":0,"hunt_gold":0,"hunt_xp":0,"hunt_seconds":0.0,"lane_gold":0,"lane_xp":0,"hero_lane_gold":0,"hero_lane_xp":0,"defender_lane_gold":0,"defender_lane_xp":0,"wave_gold":0,"wave_xp":0,"peak_enemies":0,"peak_nearby_8m":0,"first_hit_at":0.0,"level_times":{"1":0.0},"purchase_times":{},"total_kills":0,"wave_kills":0}
	recalculate_stats()
	hp = stats.max_hp
	energy = stats.max_energy
	hunt = {}
	_reset_defenders()
	_reset_allies()
	special_event = {}
	wave_modifier = ""
	wave_reinforcement_timer = 0.0
	wave_reinforcement_count = 0
	endless_active = false
	endless_best_wave = 0
	announce("Choose your gear. The first wave starts when you are ready.")

func recalculate_stats():
	stats = _combat_stats.derived_stats(heroes, items, hero_id, level, inventory)
	# Set effects
	_active_set_effects = {}
	var set_counts: Dictionary = {}
	for id in inventory:
		var item = items.get(id, {})
		var group = item.get("unique_group", "none")
		if group != "none":
			set_counts[group] = int(set_counts.get(group, 0)) + 1
	# 2-piece and 4-piece set bonuses
	if set_counts.get("lifesteal_highest", 0) >= 2:
		_active_set_effects["lifesteal_highest"] = true
		if not stats.has("lifesteal"): stats.lifesteal = 0
		stats.lifesteal = float(stats.lifesteal) + 0.15
	if set_counts.get("berserker_rage", 0) >= 2:
		_active_set_effects["berserker_rage"] = true
		if not stats.has("ad"): stats.ad = 0
		stats.ad = float(stats.ad) * 1.2
	if set_counts.get("berserker_rage", 0) >= 4:
		_active_set_effects["berserker_rage_4"] = true
		# 4-piece: kills reset Q cooldown (applied in _on_kill)
	if set_counts.get("arcane_surge", 0) >= 2:
		_active_set_effects["arcane_surge"] = true
		if not stats.has("sp"): stats.sp = 0
		stats.sp = float(stats.sp) * 1.15
	if set_counts.get("guardian_aegis", 0) >= 2:
		_active_set_effects["guardian_aegis"] = true
		if not stats.has("damage_reduction"): stats.damage_reduction = 0
		stats.damage_reduction = float(stats.damage_reduction) + 0.12
	if set_counts.get("sanctuary_ward", 0) >= 2:
		_active_set_effects["sanctuary_ward"] = true
		if not stats.has("max_hp"): stats.max_hp = 0
		stats.max_hp = int(float(stats.max_hp) * 1.2)
	hp = minf(hp, stats.max_hp)
	energy = minf(energy, stats.max_energy)

func derived_stats(for_hero: String, for_level: int, equipment: Array) -> Dictionary:
	return _combat_stats.derived_stats(heroes, items, for_hero, for_level, equipment)

static func mitigation(defense: float) -> float:
	return CombatStats.mitigation(defense)

func ability(slot: String) -> Dictionary:
	return abilities.get(hero_id+"."+slot,{})

func switch_hero(new_hero: String) -> Dictionary:
	if hero_switch_cooldown > 0: return {"ok":false, "reason":"Switch on cooldown"}
	if not heroes.has(new_hero): return {"ok":false, "reason":"Unknown hero"}
	if new_hero == hero_id: return {"ok":false, "reason":"Already active"}
	# Store current hero state
	inactive_heroes[hero_id] = {
		"pos": pos,
		"hp": hp,
		"energy": energy,
		"respawn_left": respawn_left,
		"cooldowns": cooldowns.duplicate(),
		"potion_cd": potion_cd,
		"potion_ticks": potion_ticks,
		"potion_tick_left": potion_tick_left,
		"shield": shield,
		"shield_left": shield_left,
		"invulnerable_left": 2.0  # Brief invulnerability on switch
	}
	# Switch to new hero
	hero_id = new_hero
	var saved = inactive_heroes.get(new_hero, {})
	pos = saved.get("pos", START)
	hp = saved.get("hp", stats.max_hp)
	energy = saved.get("energy", stats.max_energy)
	respawn_left = saved.get("respawn_left", 0.0)
	cooldowns = saved.get("cooldowns", {"Q":0.0,"W":0.0,"E":0.0,"R":0.0,"F":0.0})
	potion_cd = saved.get("potion_cd", 0.0)
	potion_ticks = saved.get("potion_ticks", 0)
	potion_tick_left = saved.get("potion_tick_left", 0.0)
	shield = saved.get("shield", 0)
	shield_left = saved.get("shield_left", 0)
	invulnerable_left = maxf(invulnerable_left, 2.0)
	recalculate_stats()
	hero_switch_cooldown = 3.0
	announce("Switched to %s" % heroes[hero_id].get("name", hero_id))
	log_event("hero_switch", {"hero": hero_id})
	return {"ok":true, "reason":"Switched"}

func announce(text: String):
	notice = text
	notice_left = 5.0

func log_event(kind: String, detail: Dictionary = {}):
	var entry = detail.duplicate(true)
	entry["time"] = snappedf(elapsed,0.001)
	entry["kind"] = kind
	event_log.append(entry)
	if event_log.size() > 2000: event_log.pop_front()

func start_next_wave() -> bool:
	if phase == "FinalPreparation":
		save_checkpoint()
		phase = "BossIntro"
		prep_left = 5
		announce("RAMPART BREAKER  •  Destroy its glowing cannon core!")
		return true
	if phase != "Preparation": return false
	save_checkpoint()
	wave = completed_wave+1
	if wave > 50: return false
	phase = "Combat"
	_prepare_hunt()
	# Special event after wave 3 and 7
	if completed_wave in [3,7] and not special_event.get("active",false):
		_trigger_special_event()
	var w = data.waves[clampi(wave-1,0,data.waves.size()-1)]
	wave_modifier = str(w.get("modifier",""))
	# Fallback: apply a random modifier every 3 waves after wave 10
	if wave_modifier == "" and wave > 10 and (wave - 10) % 3 == 0:
		var modifiers = ["elite_rush","healer_wave","siege_priority","speed_rush","shield_wall","mixed_assault","ambush"]
		wave_modifier = modifiers[rng.randi() % modifiers.size()]
	spawn_queue = []
	var explicit_counts: bool = ruleset=="fast" and tempo.has("wave_counts")
	var counts: Dictionary = tempo.wave_counts[wave-1] if explicit_counts else w.solo_counts
	for kind in counts:
		var count = int(counts[kind])
		if ruleset=="fast" and not explicit_counts: count = maxi(1,roundi(count*float(tempo.wave_count_multiplier)))
		for i in count: spawn_queue.append(kind)
	# Seeded Fisher-Yates avoids engine global RNG and keeps replay order stable.
	for i in range(spawn_queue.size()-1,0,-1):
		var j = spawn_rng.randi_range(0,i)
		var tmp = spawn_queue[i]
		spawn_queue[i] = spawn_queue[j]
		spawn_queue[j] = tmp
	spawn_timer = 0
	spawn_was_capped = false
	if ruleset=="fast":
		for i in mini(int(tempo.initial_spawn_count),spawn_queue.size()):
			spawn_enemy(spawn_queue.pop_front(),_spawn_position())
		spawn_timer = float(tempo.spawn_interval_seconds)
	# Elite variant: 10% chance to upgrade a crawler to elite in later waves
	if wave >= 5:
		for i in range(spawn_queue.size()):
			if spawn_queue[i]=="crawler" and rng.randf() < 0.1:
				spawn_queue[i] = "elite"
	# register elite in enemy_types for rendering
	announce("WAVE %d  •  %d invaders incoming" % [wave,spawn_queue.size()+enemies.size()])
	# Apply wave modifiers
	if wave_modifier == "elite_rush":
		var elite_count = 0
		for i in range(spawn_queue.size()):
			if spawn_queue[i] == "crawler" and elite_count < 4:
				spawn_queue[i] = "elite"
				elite_count += 1
		if elite_count > 0:
			announce("ELITE RUSH  •  %d elites incoming!" % elite_count)
	elif wave_modifier == "healer_wave":
		for i in 3: spawn_queue.append("healer")
		announce("HEALER WAVE  •  Enemy healers deployed!")
	elif wave_modifier == "siege_priority":
		var siege_count = 0
		for i in range(spawn_queue.size()):
			if spawn_queue[i] == "crawler" and siege_count < 2:
				spawn_queue[i] = "siege"
				siege_count += 1
		if siege_count > 0:
			announce("SIEGE PRIORITY  •  %d siege units incoming!" % siege_count)
	elif wave_modifier == "speed_rush":
		var skirmish_count = 0
		for i in range(spawn_queue.size()):
			if spawn_queue[i] == "crawler" and skirmish_count < 5:
				spawn_queue[i] = "skirmisher"
				skirmish_count += 1
		if skirmish_count > 0:
			announce("SPEED RUSH  •  Fast skirmishers incoming!")
	elif wave_modifier == "shield_wall":
		for i in 4: spawn_queue.append("guard")
		announce("SHIELD WALL  •  Heavy guards deployed!")
	elif wave_modifier == "mixed_assault":
		var mixed_elite = 0
		var mixed_siege = 0
		for i in range(spawn_queue.size()):
			if spawn_queue[i] == "crawler" and mixed_elite < 2:
				spawn_queue[i] = "elite"
				mixed_elite += 1
			elif spawn_queue[i] == "crawler" and mixed_siege < 2:
				spawn_queue[i] = "siege"
				mixed_siege += 1
		if mixed_elite + mixed_siege > 0:
			announce("MIXED ASSAULT  •  Elites and siege units incoming!")
	elif wave_modifier == "ambush":
		for i in range(spawn_queue.size()):
			if spawn_queue[i] in ["crawler","skirmisher","shooter"]:
				spawn_queue[i] = "crawler"  # keep as crawler but spawn hidden
		announce("AMBUSH  •  Hidden enemies approaching!")
		# All enemies in this wave spawn hidden
		for i in 5: spawn_queue.append("crawler")
	log_event("wave_start",{"wave":wave,"base_hp":base_hp,"modifier":wave_modifier})
	return true

func _step_wave_reinforcements(dt: float) -> void:
	if phase != "Combat" or wave_modifier == "": return
	if wave_modifier == "elite_rush" or wave_modifier == "siege_priority":
		wave_reinforcement_timer -= dt
		if wave_reinforcement_timer <= 0 and wave_reinforcement_count < 2:
			wave_reinforcement_timer = 12.0
			wave_reinforcement_count += 1
			var kind = "elite" if wave_modifier == "elite_rush" else "siege"
			spawn_enemy(kind, _spawn_position(), false)
			announce("Reinforcement incoming!")
		if spawn_queue.is_empty() and enemies.size() == 0:
			wave_reinforcement_timer = 0.0
			wave_reinforcement_count = 0

func _spawn_position() -> Vector2:
	var roll: float = spawn_rng.randf()
	if roll < 0.33:
		return Vector2(44,spawn_rng.randf_range(4,20))
	if roll < 0.66:
		return Vector2(spawn_rng.randf_range(4,42),2)
	return Vector2(spawn_rng.randf_range(4,42),22)

func spawn_enemy(kind: String, at: Vector2, reward: bool = true, random_stream: RandomNumberGenerator = null) -> Dictionary:
	var e: Dictionary
	if kind == "boss":
		e = {"hp":18000.0,"damage":180.0,"interval":7.0,"speed":1.8,"armor":20.0,"magic_resist":20.0,"castle_multiplier":1.0,"cost":0}
	elif kind == "weakness":
		e = {"hp":120.0,"damage":0.0,"interval":99.0,"speed":0.0,"armor":0.0,"magic_resist":0.0,"castle_multiplier":0.0,"cost":0}
	elif kind == "elite":
		e = enemy_types["crawler"].duplicate(true)
		e.hp *= 3.0
		e.damage *= 1.5
		e.speed *= 0.9
		e.cost = 3
		var w = data.waves[clampi(wave-1,0,data.waves.size()-1)]
		e.hp *= float(w.hp_wave_multiplier)
		e.damage *= float(w.damage_wave_multiplier)
	else:
		e = enemy_types[kind].duplicate(true)
		var w2 = data.waves[clampi(wave-1,0,data.waves.size()-1)]
		e.hp *= float(w2.hp_wave_multiplier)
		e.damage *= float(w2.damage_wave_multiplier)
	e.id = next_entity_id
	next_entity_id += 1
	e.kind = kind
	e.pos = at
	e.max_hp = float(e.hp)
	e.radius = 1.7 if kind == "boss" else (0.85 if kind == "siege" else 0.5)
	var timer_rng: RandomNumberGenerator = spawn_rng if random_stream==null else random_stream
	e.attack_timer = timer_rng.randf_range(0.1,0.8)
	e.telegraph = 0.0
	e.attack_target = ""
	e.attack_pos = Vector2.ZERO
	e.slow = 0.0
	e.slow_left = 0.0
	e.slow_effects = {}
	e.taunt_left = 0.0
	e.chase_left = 0.0
	e.chasing = false
	e.leash_left = 0.0
	e.reward = reward
	e.retreated = false
	e.flash = 0.0
	e.hidden = false
	e.stun_left = 0.0
	if kind in ["crawler", "skirmisher"] and rng.randf() < 0.15:
		e.hidden = true
		e.reveal_distance = 4.0
	enemies.append(e)
	return e

func step(dt: float, movement: Vector2 = Vector2.ZERO):
	if phase in ["Victory","Defeat"]: return
	if dt <= 0: return
	dt = minf(dt,0.1)
	elapsed += dt
	notice_left = maxf(0,notice_left-dt)
	for key in cooldowns: cooldowns[key] = maxf(0,cooldowns[key]-dt)
	potion_cd = maxf(0,potion_cd-dt)
	hero_switch_cooldown = maxf(0,hero_switch_cooldown-dt)
	arcanist_passive_cd = maxf(0,arcanist_passive_cd-dt)
	sanctuary_cd = maxf(0,sanctuary_cd-dt)
	ranger_buff = maxf(0,ranger_buff-dt)
	ranger_ultimate = maxf(0,ranger_ultimate-dt)
	invulnerable_left = maxf(0,invulnerable_left-dt)
	if not shield_groups.is_empty():
		for group in shield_groups.keys():
			shield_groups[group].left -= dt
			if shield_groups[group].left<=0: shield_groups.erase(group)
		_sync_shields()
	elif shield_left > 0:
		shield_left = maxf(0,shield_left-dt)
		if shield_left <= 0: shield = 0
	if respawn_left <= 0:
		energy = minf(stats.max_energy,energy+stats.energy_regen*dt)
		if potion_heal_left > 0:
			potion_heal_left = maxf(0,potion_heal_left-dt)
			potion_tick_left -= dt
			if potion_tick_left<=0 and potion_ticks>0:
				hp = minf(stats.max_hp,hp+potion_tick_heal)
				potion_ticks -= 1
				potion_tick_left += 1
		if movement.length() > 0.1 and not _hunt_channeling():
			var dir = movement.limit_length(1)
			pos += dir*float(stats.move_speed)*dt
			pos = clamp_position(pos)
			facing = dir.normalized()
	for e in effects: e.life -= dt
	effects = effects.filter(func(e): return e.life > 0)
	if phase in ["Preparation","FinalPreparation"]:
		if prep_left > 0:
			prep_left -= dt
			if prep_left <= 0: start_next_wave()
		return
	if phase == "BossIntro":
		prep_left -= dt
		if prep_left <= 0:
			phase = "Boss"
			spawn_enemy("boss",Vector2(36,12),false)
			announce("Break the cannon core. Dodge striped ground attacks.")
		return
	if phase == "Combat" and not spawn_queue.is_empty():
		spawn_timer -= dt
		var due_epsilon: float = 0.00000001 if ruleset=="fast" else 0.0
		if enemies.size()>=60 and spawn_timer<=due_epsilon:
			# Cap-blocked time is not a debt to burst-spawn when a slot opens.
			spawn_timer = 0.0
			spawn_was_capped = true
		elif spawn_timer<=due_epsilon and enemies.size()<60:
			spawn_enemy(spawn_queue.pop_front(),_spawn_position())
			if ruleset=="fast":
				var interval: float = float(tempo.spawn_interval_seconds)
				spawn_timer = interval if spawn_was_capped else spawn_timer+interval
			else:
				spawn_timer = 0.9
			spawn_was_capped = false
	if phase == "Boss": _step_boss(dt)
	# 2k kill arena
	if phase == "Combat" and metrics.total_kills >= 2000 and not special_event.get("arena_active",false):
		_trigger_kill_arena()
	if phase == "SpecialEvent": _step_special_event(dt)
	_step_wave_reinforcements(dt)
	_step_hunt_clock(dt)
	_step_defenders(dt)
	_step_allies(dt)
	_observe_pressure()
	_step_casts(dt)
	_step_zones(dt)
	_step_enemies(dt)
	_step_projectiles(dt)
	_step_hazards(dt)
	if respawn_left <= 0:
		auto_timer -= dt
		if auto_timer <= 0 and auto_attack_enabled and pending_casts.is_empty() and not _hunt_channeling(): _basic_attack()
	_resolve_deaths()
	# Castle defeat wins all same-tick ties, before rewards/respawn/victory.
	if base_hp <= 0:
		base_hp = 0
		phase = "Defeat"
		_close_hunt("defeat")
		announce("The Emberwatch has fallen.")
		log_event("defeat",{"wave":wave})
		return
	if respawn_left > 0:
		respawn_left -= dt
		if respawn_left <= 0:
			hp = stats.max_hp
			energy = stats.max_energy
			pos = START
			invulnerable_left = 2
			announce("Returned to the rampart. Two seconds of protection.")
	_settle_hunt()
	if phase == "Boss" and not _has_kind("boss"):
		phase = "Victory"
		metrics.boss_seconds = boss_elapsed
		enemies.clear()
		projectiles.clear()
		hazards.clear()
		announce("EMBERWATCH STANDS")
		log_event("victory",{"base_hp":base_hp,"seconds":elapsed})
	elif phase == "Combat" and spawn_queue.is_empty() and main_enemy_count()==0:
		_clear_wave()

func clamp_position(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x,2,46),clampf(p.y,2,22))

func _clear_wave():
	if completed_wave >= wave: return
	completed_wave = wave
	_close_hunt("wave_end")
	_reset_defenders()
	var reward_gold = roundi((40+5*wave)*(float(tempo.wave_reward_multiplier) if ruleset=="fast" else 1.0))
	gold += reward_gold
	metrics.gold_earned += reward_gold
	var reward_xp = roundi(25*wave*(float(tempo.wave_reward_multiplier) if ruleset=="fast" else 1.0))
	xp += reward_xp
	metrics.wave_gold += reward_gold
	metrics.wave_xp += reward_xp
	_update_level()
	projectiles.clear()
	hazards.clear()
	pending_casts.clear()
	pulse_zones.clear()
	traps.clear()
	hp = stats.max_hp
	energy = stats.max_energy
	shield = 0
	shield_groups.clear()
	shield_left = 0
	potion_heal_left = 0
	potion_ticks = 0
	cancel_cast()
	respawn_left = 0
	pos = START
	phase = "FinalPreparation" if wave == 10 else "Preparation"
	prep_left = float(tempo.preparation_seconds) if ruleset=="fast" else 15.0
	base_hp = minf(max_base_hp,base_hp+max_base_hp*0.03)
	metrics.waves.append({"wave":wave,"time":elapsed,"base_hp":base_hp,"level":level,"gold_earned":metrics.gold_earned})
	announce("WAVE %d CLEAR  •  +%d gold  •  Forge your next upgrade" % [wave,reward_gold])
	log_event("wave_clear",{"wave":wave,"gold":gold,"xp":xp,"base_hp":base_hp})
	save_checkpoint()

func _update_level():
	var old = level
	for entry in data.level_thresholds:
		if xp >= entry.cumulative_xp: level = int(entry.level)
	if level != old:
		for gained in range(old+1,level+1): metrics.level_times[str(gained)] = elapsed
		var old_max = stats.max_hp
		recalculate_stats()
		if respawn_left <= 0: hp += stats.max_hp-old_max
		announce("LEVEL %d  •  Your power grows" % level)
		log_event("level_up",{"level":level})

func _nearest(origin: Vector2, reach: float, prefer_weakness: bool = true) -> Dictionary:
	var best: Dictionary = {}
	var best_distance = reach+2.0
	for e in enemies:
		if e.hp <= 0: continue
		var d = origin.distance_to(e.pos)-float(e.radius)
		if d > reach: continue
		if prefer_weakness and e.kind == "weakness": return e
		if d < best_distance:
			best_distance = d
			best = e
	return best

func _targets(center: Vector2, radius: float, cap: int) -> Array:
	var result = enemies.filter(func(e): return e.hp>0 and center.distance_to(e.pos) <= radius+float(e.radius))
	result.sort_custom(func(a,b):
		var da = center.distance_squared_to(a.pos)
		var db = center.distance_squared_to(b.pos)
		return a.id < b.id if is_equal_approx(da,db) else da < db)
	return result.slice(0,cap)

func _damage_enemies_in_cone(origin: Vector2, direction: Vector2, radius: float, cap: int, damage: float, damage_type: String, source: String) -> Array:
	var hits: Array = []
	for e in enemies:
		if e.hp <= 0: continue
		var delta: Vector2 = e.pos - origin
		if delta.length_squared() > pow(radius + float(e.radius), 2): continue
		if delta.length_squared() < 0.0001: hits.append(e)
		elif direction.dot(delta.normalized()) >= cos(deg_to_rad(75)): hits.append(e)
	hits.sort_custom(func(a,b):
		return a.id < b.id if is_equal_approx(origin.distance_squared_to(a.pos), origin.distance_squared_to(b.pos)) else origin.distance_squared_to(a.pos) < origin.distance_squared_to(b.pos))
	hits = hits.slice(0,cap)
	for e in hits: _damage_enemy(e,damage,damage_type,false,source)
	return hits

func _basic_attack():
	var target = _nearest(pos,float(stats.attack_range))
	if target.is_empty():
		selected_target_id = -1
		return
	selected_target_id = target.id
	invulnerable_left = 0
	var bonus = minf(2,stats.attack_speed_bonus+(0.25 if ranger_buff>0 else 0))
	auto_timer = 1.0/(float(stats.attack_rate)*(1.0+bonus))
	var attack_direction: Vector2 = target.pos-pos
	if attack_direction.length_squared()>0.000001: facing = attack_direction.normalized()
	if facing==Vector2.ZERO: facing = Vector2.RIGHT
	var critical = rng.randf() < stats.crit_chance
	var amount = float(stats.ad)*(1.5 if critical else 1.0)
	if hero_id == "guardian":
		_damage_enemy(target,amount,"physical",true)
		_effect("slash",pos,2.4,0.18,facing)
	else:
		projectiles.append({"pos":pos,"previous":pos,"velocity":facing*25.0,"hostile":false,"radius":0.2,"life":1.2,"damage":amount,"damage_type":"physical","target_id":target.id,"basic":true,"hero":hero_id,"ad_snapshot":float(stats.ad),"ranger_ultimate":ranger_ultimate>0})
func _ranger_on_hit(target: Dictionary, shot: Dictionary):
	if ranger_target == target.id: ranger_hits += 1
	else:
		ranger_target = target.id
		ranger_hits = 1
	if ranger_hits >= 3:
		ranger_hits = 0
		_damage_enemy(target,float(shot.ad_snapshot)*0.5,"physical",false,"ranger.passive")
	if shot.ranger_ultimate:
		_damage_enemy(target,float(shot.ad_snapshot)*0.6,"physical",false,"ranger.R")
		for secondary in _targets(target.pos,8,20):
			if secondary.id != target.id:
				_damage_enemy(secondary,float(shot.ad_snapshot)*0.3,"physical",false,"ranger.R.secondary")
				_effect("chain",secondary.pos,0.8,0.2)
				break

func _damage_enemy(enemy: Dictionary, raw: float, damage_type: String, basic: bool = false, source: String = "other") -> float:
	if enemy.hp <= 0: return 0
	var defense = float(enemy.magic_resist if damage_type == "magic" else enemy.armor)
	var amount = minf(float(enemy.hp),raw*mitigation(defense))
	enemy.hp -= amount
	enemy.flash = 0.12
	enemy.last_hit_source = source
	if source=="defender":
		metrics.defender_damage += amount
	else:
		if metrics.first_hit_at==0: metrics.first_hit_at = elapsed
		metrics.damage_dealt += amount
		var source_key = "basic" if basic else source
		metrics.damage_by_source[source_key] = float(metrics.damage_by_source.get(source_key,0))+amount
		metrics.hits_by_source[source_key] = int(metrics.hits_by_source.get(source_key,0))+1
	if basic and stats.lifesteal > 0 and respawn_left <= 0:
		lifesteal_history = lifesteal_history.filter(func(h): return elapsed-h.time<1.0)
		var total = 0.0
		for h in lifesteal_history: total += h.amount
		var heal = minf(amount*stats.lifesteal,maxf(0,stats.max_hp*0.08-total))
		hp = minf(stats.max_hp,hp+heal)
		lifesteal_history.append({"time":elapsed,"amount":heal})
	return amount

func damage_hero(raw: float, damage_type: String = "physical", source: String = "unknown"):
	if respawn_left > 0 or invulnerable_left > 0 or hp <= 0: return
	var reduction = 0.0
	if hero_id == "guardian" and pos.distance_to(CASTLE) <= 12: reduction = 0.1
	if inventory.has("fortress"): reduction = 1-(1-reduction)*0.95
	var defense = stats.magic_resist if damage_type == "magic" else stats.armor
	var amount = raw*mitigation(defense)*(1-minf(0.6,reduction))
	var absorbed = minf(shield,amount)
	_consume_shield(absorbed)
	amount -= absorbed
	hp -= amount
	metrics.damage_taken += amount
	metrics.hero_damage_by_kind[source] = float(metrics.hero_damage_by_kind.get(source,0))+amount
	_effect("hit",pos,0.6,0.18)
	if hp > 0 and hp <= stats.max_hp*0.35 and inventory.has("sanctuary") and sanctuary_cd <= 0:
		add_shield("sanctuary",300,4)
		sanctuary_cd = 30
		_effect("shield",pos,1.5,0.5)
	if hp <= 0:
		hp = 0
		respawn_left = minf(20,6+wave)
		shield = 0
		shield_left = 0
		shield_groups.clear()
		cancel_cast()
		cast_buffer.clear()
		traps.clear()
		pulse_zones.clear()
		ranger_buff = 0
		ranger_ultimate = 0
		for e in enemies: e.taunt_left = 0
		potion_heal_left = 0
		potion_ticks = 0
		# A death before the optional camp is chosen must not consume an unseen
		# opportunity. Activated/cleared/returning camps still end on death.
		if hunt.get("state","") in ["active","cleared","returning"]:
			_close_hunt("hero_death")
		metrics.deaths += 1
		announce("Fallen  •  Returning in %d seconds. The siege continues." % int(respawn_left))
		log_event("hero_death",{"wave":wave,"base_hp":base_hp})

func _damage_base(amount: float, source: String = "unknown"):
	base_hp -= amount
	metrics.base_damage += amount
	metrics.base_damage_by_kind[source] = float(metrics.base_damage_by_kind.get(source,0))+amount
	_effect("base_hit",CASTLE,2.0,0.4)

func _resolve_deaths():
	var alive: Array = []
	for e in enemies:
		if e.hp > 0:
			alive.append(e)
			continue
		_effect("death",e.pos,e.radius+0.4,0.35)
		if e.kind == "weakness" and not e.get("expired",false): metrics.weaknesses_destroyed += 1
		if e.reward and e.cost > 0:
			var reward = int(e.cost)*(int(tempo.kill_gold_per_cost) if ruleset=="fast" else 6)
			gold += reward
			metrics.gold_earned += reward
			var reward_xp = int(e.cost)*(int(tempo.kill_xp_per_cost) if ruleset=="fast" else 12)
			xp += reward_xp
			metrics.lane_gold += reward
			metrics.lane_xp += reward_xp
			if e.get("last_hit_source","")=="defender":
				metrics.defender_kills += 1
				metrics.defender_lane_gold += reward
				metrics.defender_lane_xp += reward_xp
			else:
				metrics.hero_lane_gold += reward
				metrics.hero_lane_xp += reward_xp
			metrics.kills += 1
			metrics.total_kills += 1
			metrics.wave_kills += 1
			_update_level()
			# Berserker Rage 4-piece: kills reset Q cooldown
			if _active_set_effects.get("berserker_rage_4", false):
				cooldowns["Q"] = 0.0
			# 아이템 드롭 (레벨/웨이브 제한 있음)
			var drop_chance: float = 0.12
			if rng.randf() < drop_chance:
				var max_drop_tier: int = 1
				if level >= 5 and completed_wave >= 3: max_drop_tier = 2
				if level >= 10 and completed_wave >= 7: max_drop_tier = 3
				var allowed_tiers: Array = []
				for t in range(1, max_drop_tier + 1): allowed_tiers.append(t)
				var drop_tier: int = allowed_tiers[rng.randi() % allowed_tiers.size()]
				var tier_items: Array = []
				for id in items:
					if items[id].get("tier", 0) == drop_tier and id != "healing_potion" and level >= int(items[id].get("unlock_level", 1)) and completed_wave >= int(items[id].get("unlock_after_wave", 0)):
						tier_items.append(id)
				if not tier_items.is_empty():
					var drop_id: String = tier_items[rng.randi() % tier_items.size()]
					if not inventory.has(drop_id) and inventory.size() < 6:
						inventory.append(drop_id)
						announce("획득: " + (items[drop_id].get("name_ko", drop_id)))
	enemies = alive

func cast(slot: String, aim: Vector2 = Vector2.ZERO) -> bool:
	if phase not in ["Combat","Boss"] or respawn_left > 0 or _hunt_channeling(): return false
	var a = ability(slot)
	if a.is_empty() or level < a.unlock_level:
		announce("%s unlocks at level %d" % [slot,int(a.get("unlock_level",99))])
		return false
	if cooldowns[slot]>0 or energy-energy_reserved<a.energy_cost: return false
	if not pending_casts.is_empty():
		cast_buffer = {"slot":slot,"aim":aim,"expires":elapsed+0.15}
		return true
	var point = aim
	if point == Vector2.ZERO: point = assisted_aim(slot)
	var dir = (point-pos).normalized()
	if dir == Vector2.ZERO: dir = facing if facing!=Vector2.ZERO else Vector2.RIGHT
	energy_reserved = float(a.energy_cost)
	facing = dir
	pending_casts.append({"slot":slot,"aim":point,"dir":dir,"origin":pos,"left":a.windup_seconds})
	return true

func cancel_cast():
	pending_casts.clear()
	energy_reserved = 0
	cast_buffer.clear()

func _step_casts(dt: float):
	if pending_casts.is_empty(): return
	var c = pending_casts[0]
	c.left -= dt
	if c.left>0: return
	pending_casts.clear()
	energy_reserved = 0
	if respawn_left>0: return
	var a = ability(c.slot)
	energy -= a.energy_cost
	invulnerable_left = 0
	cooldowns[c.slot] = ceilf(float(a.cooldown_seconds)*(1-stats.cooldown_reduction)*30)/30.0
	metrics.casts += 1
	metrics.casts_by_slot[c.slot] = int(metrics.casts_by_slot.get(c.slot,0))+1
	log_event("cast",{"slot":c.slot,"hero":hero_id})
	_execute_cast(c)
	if not cast_buffer.is_empty():
		var buffered = cast_buffer.duplicate()
		cast_buffer.clear()
		if elapsed<=buffered.expires: cast(buffered.slot,buffered.aim)

func _execute_cast(c: Dictionary):
	var a = ability(c.slot)
	var damage = float(a.base_damage)+stats.ad*float(a.ad_coefficient)+stats.sp*float(a.sp_coefficient)
	var hits: Array = []
	var center: Vector2 = c.aim
	var dist = c.origin.distance_to(center)
	if dist > 12: center = c.origin+c.dir*12
	match hero_id+"."+c.slot:
		"guardian.Q":
			for e in _targets(c.origin,4,60):
				var delta: Vector2 = e.pos-c.origin
				if delta.length()<1 or c.dir.dot(delta.normalized()) >= cos(PI/4): hits.append(e)
			_effect("cleave",c.origin,4,0.35,c.dir)
		"guardian.W":
			if respawn_left <= 0:
				add_shield("guardian_w",180+stats.max_hp*0.12,4)
			for e in _targets(pos,5,60):
				if e.kind not in ["siege","boss","weakness"]: e.taunt_left = 2
			_effect("taunt",pos,5,0.5)
		"guardian.E":
			if respawn_left <= 0: pos = clamp_position(c.origin+c.dir*minf(6,dist))
			center = pos
			hits = _targets(center,2.5,8)
			for e in hits: _slow(e,0.35,2,"guardian.E")
			_effect("impact",center,2.5,0.4)
		"guardian.R":
			pulse_zones.append({"pos":pos,"follow":true,"left":1.0,"life":8.0,"count":8,"damage":damage,"type":"physical","radius":4.0,"cap":8,"slow":0.0,"source":"guardian.R"})
			_effect("ultimate",pos,4,0.5)
		"ranger.Q":
			for e in _targets(c.origin,15,60):
				var delta: Vector2 = e.pos-c.origin
				if delta.dot(c.dir)>=0 and delta.dot(c.dir)<=14 and absf(delta.cross(c.dir))<=0.75+e.radius: hits.append(e)
			_effect("pierce",c.origin,14,0.35,c.dir)
		"ranger.W":
			if traps.size() >= 2: traps.pop_front()
			var p: Vector2 = c.origin+c.dir*minf(5,dist)
			traps.append({"pos":clamp_position(p),"arm":0.5,"life":30.0,"damage":damage,"radius":3.0})
		"ranger.E":
			if respawn_left <= 0: pos = clamp_position(c.origin-c.dir*4)
			ranger_buff = 3
			_effect("dash",pos,1.5,0.3,c.dir)
		"ranger.R":
			ranger_ultimate = 6
			_effect("ultimate",pos,3,0.5)
		"arcanist.Q":
			hits = _targets(center,3.5,10)
			_effect("nova",center,3.5,0.5)
		"arcanist.W":
			if respawn_left <= 0:
				add_shield("arcanist_w",160+stats.sp*1.2,4)
			_effect("shield",pos,2,0.5)
		"arcanist.E":
			pulse_zones.append({"pos":center,"follow":false,"left":1.0,"life":4.0,"count":4,"damage":damage,"type":"magic","radius":4.0,"cap":8,"slow":0.35,"source":"arcanist.E"})
		"arcanist.R":
			hits = _targets(pos,7,12)
			if respawn_left <= 0: hp = minf(stats.max_hp,hp+150+stats.sp)
			_effect("sunburst",pos,7,0.65)
		"guardian.F":
			var stun_targets = _targets(c.origin,2.0,8)
			for enemy in stun_targets: _stun(enemy,1.5)
			_damage_enemies_in_cone(c.origin, c.dir, 2.0, 8, damage, "physical", "guardian.F")
			_effect("stun_blast",c.origin,2.0,0.5,c.dir)
		"ranger.F":
			var base_dir = c.dir if c.dir!=Vector2.ZERO else facing
			for i in 3:
				var angle = -15 + i*15
				var rotated = base_dir.rotated(deg_to_rad(angle))
				projectiles.append({"pos":c.origin,"previous":c.origin,"velocity":rotated*25.0,"hostile":false,"radius":0.15,"life":1.2,"damage":damage,"damage_type":"physical","basic":false,"hero":"ranger","source":"ranger.F"})
			_effect("volley",c.origin,3.5,0.35,base_dir)
		"arcanist.F":
			var dot_zone = {"pos":c.origin,"follow":false,"left":0.5,"life":4.0,"count":8,"damage":float(a.extra.get("dot_damage_per_second",15)),"type":"magic","radius":float(a.extra.get("radius",2.5)),"cap":8,"slow":0.0,"source":"arcanist.F","dot":true}
			pulse_zones.append(dot_zone)
			_effect("void_field",c.origin,float(a.extra.get("radius",2.5)),0.6)
	hits = hits.slice(0,int(a.target_cap))
	for e in hits: _damage_enemy(e,damage,str(a.damage_type),false,hero_id+"."+c.slot)
	_caster_passive(hits.size())

func _caster_passive(hit_count: int):
	if hero_id=="arcanist" and hit_count>=3 and arcanist_passive_cd<=0 and respawn_left<=0:
		energy = minf(stats.max_energy,energy+8)
		arcanist_passive_cd = 4

func _slow(e: Dictionary, fraction: float, duration: float, source: String = ""):
	if e.kind == "weakness": return
	fraction = minf(fraction,0.2) if e.kind=="boss" else fraction
	if not e.has("slow_effects"): e.slow_effects = {}
	var group = source if source!="" else str(fraction)
	var old = e.slow_effects.get(group,{"fraction":fraction,"left":0.0})
	e.slow_effects[group] = {"fraction":fraction,"left":maxf(old.left,duration)}
	_refresh_slow(e)

func _stun(e: Dictionary, duration: float):
	if e.kind in ["boss", "weakness"]: return
	if not e.has("stun_effects"): e.stun_effects = []
	e.stun_effects.append(duration)
	e.stun_left = maxf(e.stun_left, duration)
	e.telegraph = 0
	e.chase_left = 0

func _refresh_slow(e: Dictionary):
	e.slow = 0.0
	e.slow_left = 0.0
	for effect in e.get("slow_effects",{}).values():
		e.slow = maxf(float(e.slow),float(effect.fraction))
		e.slow_left = maxf(float(e.slow_left),float(effect.left))

func _tick_stun(e: Dictionary, dt: float):
	if not e.has("stun_effects"): return
	e.stun_left = maxf(0,e.stun_left-dt)
	var remaining: Array = []
	for s in e.stun_effects:
		var left = s-dt
		if left>0: remaining.append(left)
		else: _effect("stun",e.pos,0.6,0.18)
	e.stun_effects = remaining

func _tick_slow(e: Dictionary, dt: float):
	if e.get("slow_effects",{}).is_empty():
		e.slow_left = maxf(0,e.slow_left-dt)
		if e.slow_left<=0: e.slow = 0
		return
	for key in e.slow_effects.keys():
		e.slow_effects[key].left -= dt
		if e.slow_effects[key].left<=0.000001: e.slow_effects.erase(key)
	_refresh_slow(e)

func _step_zones(dt: float):
	var remaining: Array = []
	for z in pulse_zones:
		z.left -= dt
		z.life -= dt
		if z.follow: z.pos = pos
		if z.slow>0:
			for e in _targets(z.pos,z.radius,z.cap): _slow(e,z.slow,dt*2,z.get("source","zone"))
		if z.left <= 0.000001:
			var hits = _targets(z.pos,z.radius,z.cap)
			if z.get("dot",false):
				for e in hits: _damage_enemy(e,z.damage*dt,z.type,false,z.get("source","zone"))
			else:
				for e in hits: _damage_enemy(e,z.damage,z.type,false,z.get("source","zone"))
				_caster_passive(hits.size())
				_effect("pulse",z.pos,z.radius,0.7)
				z.count -= 1
				z.left += 1
		if z.count>0 and z.life>0.000001: remaining.append(z)
	pulse_zones = remaining
	remaining = []
	for t in traps:
		t.arm -= dt
		t.life -= dt
		var hits = _targets(t.pos,3,8)
		if t.arm <= 0 and not hits.is_empty():
			for e in hits:
				_damage_enemy(e,t.damage,"physical",false,"ranger.W")
				_slow(e,0.4,3,"ranger.W")
			_effect("trap",t.pos,3,0.5)
		elif t.life>0: remaining.append(t)
	traps = remaining

func _effect(kind: String, at: Vector2, radius: float, life: float, dir: Vector2 = Vector2.RIGHT):
	effects.append({"kind":kind,"pos":at,"radius":radius,"life":life,"max_life":life,"dir":dir})
	if effects.size()>120: effects.pop_front()

func _step_enemies(dt: float):
	for e in enemies:
		if e.hp <= 0 or e.kind in ["boss","weakness"]: continue
		e.flash = maxf(0,e.flash-dt)
		_tick_stun(e,dt)
		if e.stun_left > 0:
			e.telegraph = 0
			continue
		e.attack_timer -= dt
		_tick_slow(e,dt)
		e.taunt_left = maxf(0,e.taunt_left-dt)
		if e.taunt_left>0 and e.pos.distance_to(pos)>10: e.taunt_left = 0
		e.leash_left = maxf(0,e.leash_left-dt)
		if e.get("hunt_enemy",false):
			_step_hunt_enemy(e,dt)
			continue
		if e.get("hidden",false) and e.pos.distance_to(pos) <= float(e.get("reveal_distance",4.0)):
			e.hidden = false
			announce("Hidden enemy revealed!")
		if e.kind == "healer":
			e.heal_timer = maxf(0, float(e.get("heal_timer",0.0)) - dt)
			if e.heal_timer <= 0:
				e.heal_timer = 3.0
				for other in enemies:
					if other.id != e.id and other.hp > 0 and other.pos.distance_to(e.pos) <= 6:
						other.hp = minf(other.max_hp, other.hp + 20)
						_effect("heal", other.pos, 1.0, 0.4)
				_effect("heal", e.pos, 2.0, 0.5)
		if e.kind == "summoner":
			e.summon_timer = maxf(0, float(e.get("summon_timer",0.0)) - dt)
			if e.summon_timer <= 0 and enemies.size() < 55:
				e.summon_timer = 5.0
				spawn_enemy("crawler", clamp_position(e.pos + Vector2(1,0)), false)
				_effect("summon", e.pos, 2.0, 0.6)
		if e.kind == "healer":
			e.heal_timer = maxf(0, float(e.get("heal_timer",0.0)) - dt)
			if e.heal_timer <= 0:
				e.heal_timer = 3.0
				for other in enemies:
					if other.id != e.id and other.hp > 0 and other.pos.distance_to(e.pos) <= 6:
						other.hp = minf(other.max_hp, other.hp + 15)
						_effect("heal", other.pos, 1.0, 0.4)
				_effect("heal", e.pos, 2.0, 0.5)
		if e.kind == "shooter":
			if target_name == "hero" and distance < 4 and not e.retreated:
				e.pos = clamp_position(e.pos + (e.pos - pos).normalized() * 1.5)
				e.retreated = true
				distance = e.pos.distance_to(target)
			elif distance > 7 and e.retreated:
				e.retreated = false
		if e.kind == "skirmisher" and e.attack_timer <= 0 and target_name == "hero" and distance < 3:
			e.retreated = true
			e.retreat_left = 0.6
		if e.get("retreated", false) and e.retreat_left > 0:
			e.pos = clamp_position(e.pos + (e.pos - target).normalized() * float(e.speed) * 1.2 * dt)
			e.retreat_left -= dt
			if e.retreat_left <= 0:
				e.retreated = false
			e.telegraph -= dt
			if e.telegraph<=0: _enemy_attack(e)
			continue
		var hero_distance = e.pos.distance_to(pos)
		var target = CASTLE
		var target_name = "base"
		var reach = 1.5
		if e.kind=="shooter": reach = 8
		if e.kind=="siege": reach = 9
		if e.kind!="siege" and respawn_left<=0 and hp>0 and e.leash_left<=0:
			if e.taunt_left>0 or (hero_distance<=7 and not e.chasing):
				e.chasing = true
				e.chase_left = 3
			if e.chasing:
				e.chase_left -= dt
				if hero_distance>10 or e.chase_left<=0:
					e.chasing = false
					e.leash_left = 2
				else:
					target = pos
					target_name = "hero"
		if e.taunt_left>0 and e.kind!="siege" and respawn_left<=0:
			target = pos
			target_name = "hero"
		if target_name=="base" and e.kind!="siege":
			var ally = _nearest_defender(e.pos,5.0)
			if not ally.is_empty():
				target = ally.pos
				target_name = "defender"
				e.defender_target_id = ally.id
		var distance = e.pos.distance_to(target)
		if distance <= reach:
			if e.attack_timer<=0:
				e.telegraph = 0.9 if e.kind=="siege" else (0.45 if e.kind=="shooter" else 0.32)
				e.attack_target = target_name
				e.attack_pos = target
				e.attack_timer = float(e.interval)
				e.chase_left = 3
		else:
			var dir: Vector2 = (target-e.pos).normalized()
			var separation = Vector2.ZERO
			for other in enemies:
				if other.id==e.id: continue
				var offset: Vector2 = e.pos-other.pos
				var d2 = offset.length_squared()
				if d2>0.001 and d2<0.7: separation += offset.normalized()*(0.7-sqrt(d2))*1.4
			e.pos += (dir*float(e.speed)*(1-float(e.slow))+separation)*dt
			e.pos = clamp_position(e.pos)

func _enemy_attack(e: Dictionary):
	var damage = float(e.damage)
	if e.attack_target=="base": damage *= float(e.castle_multiplier)
	if e.kind in ["shooter","siege"]:
		var dir: Vector2 = (e.attack_pos-e.pos).normalized()
		projectiles.append({"pos":e.pos,"previous":e.pos,"velocity":dir*(12.0 if e.kind=="siege" else 15.0),"hostile":true,"radius":0.4 if e.kind=="siege" else 0.2,"life":3.0,"damage":damage,"damage_type":"physical","target":e.attack_target,"kind":e.kind,"defender_target_id":e.get("defender_target_id",-1)})
	elif e.attack_target=="defender":
		var ally = _defender_by_id(int(e.get("defender_target_id",-1)))
		if not ally.is_empty() and ally.hp>0 and ally.pos.distance_to(e.attack_pos)<1.8 and ally.pos.distance_to(e.pos)<2.5:
			_damage_defender(ally,damage)
	elif e.attack_target=="base":
		_damage_base(damage,e.kind)
	elif respawn_left<=0 and pos.distance_to(e.attack_pos)<1.8 and pos.distance_to(e.pos)<2.5:
		damage_hero(damage,"physical",e.kind)
		_effect("enemy_slash",e.pos,1.8,0.18,(e.attack_pos-e.pos).normalized())

static func segment_distance(point: Vector2, a: Vector2, b: Vector2) -> float:
	var delta = b-a
	var t = clampf((point-a).dot(delta)/maxf(delta.length_squared(),0.000001),0,1)
	return point.distance_to(a+delta*t)

func _step_projectiles(dt: float):
	var remaining: Array = []
	for p in projectiles:
		p.life -= dt
		p.previous = p.pos
		p.pos += p.velocity*dt
		var hit = false
		if p.hostile:
			if p.target=="base" and segment_distance(CASTLE,p.previous,p.pos)<1.5:
				_damage_base(p.damage,p.get("kind","projectile"))
				hit = true
			elif p.target=="defender":
				var ally = _defender_by_id(int(p.get("defender_target_id",-1)))
				if not ally.is_empty() and ally.hp>0 and segment_distance(ally.pos,p.previous,p.pos)<0.6+float(p.radius):
					_damage_defender(ally,p.damage)
					hit = true
			elif p.target=="hero" and respawn_left<=0 and segment_distance(pos,p.previous,p.pos)<0.6+float(p.radius):
				damage_hero(p.damage,p.damage_type,p.get("kind","projectile"))
				hit = true
		else:
			var first: Dictionary = {}
			var first_distance = INF
			for e in enemies:
				if e.hp<=0 or (p.get("source","")=="defender" and e.get("hunt_enemy",false)): continue
				if segment_distance(e.pos,p.previous,p.pos)<=float(e.radius)+float(p.radius):
					var distance: float = p.previous.distance_squared_to(e.pos)
					if distance<first_distance:
						first = e
						first_distance = distance
			if not first.is_empty():
				_damage_enemy(first,p.damage,p.damage_type,p.basic,p.get("source","other"))
				if p.get("hero","")=="ranger" and p.basic: _ranger_on_hit(first,p)
				_effect("spark",first.pos,0.6,0.18)
				hit = true
		if p.life>0 and not hit: remaining.append(p)
	projectiles = remaining

func _has_kind(kind: String) -> bool:
	for e in enemies:
		if e.kind==kind and e.hp>0: return true
	return false

func _boss() -> Dictionary:
	for e in enemies:
		if e.kind=="boss" and e.hp>0: return e
	return {}

func _step_boss(dt: float):
	boss_elapsed += dt
	var b = _boss()
	if b.is_empty(): return
	b.flash = maxf(0,b.flash-dt)
	_tick_slow(b,dt)
	# Boss phase transitions
	var prev_phase: int = boss_phase
	if b.hp <= b.max_hp*0.3:
		boss_phase = 3
	elif b.hp <= b.max_hp*0.6:
		boss_phase = 2
	else:
		boss_phase = 1
	if boss_phase > prev_phase:
		if boss_phase == 2:
			announce("BOSS PHASE 2  •  The breaker grows desperate!")
			boss_add_queue += 1
			_effect("phase",b.pos,5,0.6)
		elif boss_phase == 3:
			announce("BOSS PHASE 3  •  Final stand!")
			spawn_enemy("elite",clamp_position(b.pos+Vector2(-4,0)),false)
			spawn_enemy("elite",clamp_position(b.pos+Vector2(4,0)),false)
			boss_add_queue += 1
			_effect("phase",b.pos,6,0.8)
	# Phase-based cooldown speed
	var cd_mult: float = 1.0
	if boss_phase == 2: cd_mult = 0.75
	elif boss_phase == 3: cd_mult = 0.55
	for key in boss_cooldowns: boss_cooldowns[key] = maxf(0,boss_cooldowns[key]-dt*cd_mult)
	# Mini-boss spawns at phase thresholds
	for threshold in [0.6,0.3]:
		if b.hp<=b.max_hp*threshold and not boss_thresholds.has(threshold):
			boss_thresholds.append(threshold)
			boss_add_queue += 1
	boss_add_timer -= dt
	if boss_add_queue>0 and boss_add_timer<=0:
		boss_add_queue -= 1
		boss_add_timer = 3
		for i in 4: spawn_enemy("crawler",clamp_position(b.pos+Vector2(3,i*1.5-2.25)),false)
		announce("The breaker calls reinforcements!")
	if boss_pattern!="":
		boss_pattern_left -= dt
		if boss_pattern=="cannon" and not _has_kind("weakness"):
			metrics.cannons_cancelled += 1
			boss_pattern = ""
			boss_pattern_left = 0
			announce("CANNON INTERRUPTED  •  Core destroyed")
			_effect("interrupt",b.pos,3,0.5)
		elif boss_pattern_left<=0:
			_resolve_boss_pattern(b)
		return
	if boss_cooldowns.cannon<=0:
		boss_pattern = "cannon"
		boss_pattern_left = 4
		boss_cooldowns.cannon = 14
		spawn_enemy("weakness",clamp_position(b.pos+Vector2(-2,0)),false)
		boss_pattern_data = {"pos":CASTLE,"dir":Vector2.LEFT,"radius":2.0,"duration":4.0}
		announce("CANNON LOCK  •  Break the gold core in 4 seconds!")
	elif boss_cooldowns.smash<=0 and respawn_left<=0 and b.pos.distance_to(pos)<12:
		boss_pattern = "smash"
		boss_pattern_left = 1.2
		boss_cooldowns.smash = 7
		var locked_direction: Vector2 = (pos-b.pos).normalized()
		if locked_direction==Vector2.ZERO: locked_direction = Vector2.LEFT
		boss_pattern_data = {"pos":b.pos,"dir":locked_direction,"radius":7.0,"duration":1.2}
	elif boss_cooldowns.debris<=0:
		boss_pattern = "debris"
		boss_pattern_left = 1
		boss_cooldowns.debris = 12
		boss_pattern_data = {"pos":pos,"dir":Vector2.RIGHT,"radius":2.2,"duration":1.0}
		for offset in [Vector2.ZERO,Vector2(4,3),Vector2(-4,-3)]:
			hazards.append({"pos":clamp_position(pos+offset),"radius":2.2,"warning":1.0,"life":5.0,"damage":35.0*_enrage_multiplier(),"kind":"debris"})
	else:
		# Phase 3 adds charge attack when close enough
		if boss_phase >= 3 and boss_cooldowns.get("charge",0)<=0 and b.pos.distance_to(pos)<15:
			boss_pattern = "charge"
			boss_pattern_left = 0.8
			boss_cooldowns.charge = 10
			boss_pattern_data = {"pos":b.pos,"dir":(pos-b.pos).normalized(),"radius":3.0,"duration":0.8}
		else:
			var destination = Vector2(12,12)
			b.pos = b.pos.move_toward(destination,float(b.speed)*(1-float(b.slow))*dt)

func _enrage_multiplier() -> float:
	return 1.0+minf(0.6,maxf(0,floorf((boss_elapsed-180)/20)+1)*0.15) if boss_elapsed>=180 else 1.0

func _resolve_boss_pattern(b: Dictionary):
	var pattern = boss_pattern
	if pattern=="cannon":
		_damage_base(240*_enrage_multiplier(),"boss_cannon")
		for e in enemies:
			if e.kind=="weakness":
				e.hp = 0
				e.expired = true
		_effect("cannon",CASTLE,4,0.7)
	elif pattern=="smash":
		var delta: Vector2 = pos-boss_pattern_data.pos
		if delta.length()<=7.6 and (delta.length()<=0.6 or delta.normalized().dot(boss_pattern_data.dir)>=0.5):
			damage_hero(180*_enrage_multiplier(),"physical","boss_smash")
		for ally in defenders:
			var ally_delta: Vector2 = ally.pos-boss_pattern_data.pos
			if ally.hp>0 and ally_delta.length()<=7.6 and (ally_delta.length()<=0.6 or ally_delta.normalized().dot(boss_pattern_data.dir)>=0.5):
				_damage_defender(ally,180*_enrage_multiplier())
		_effect("smash",boss_pattern_data.pos,7,0.45,boss_pattern_data.dir)
	elif pattern=="charge":
		var delta: Vector2 = pos-boss_pattern_data.pos
		if delta.length()<=3.5 and (delta.length()<=0.6 or delta.normalized().dot(boss_pattern_data.dir)>=0.5):
			damage_hero(200*_enrage_multiplier(),"physical","boss_charge")
		_effect("charge",boss_pattern_data.pos+boss_pattern_data.dir*4,3,0.5,boss_pattern_data.dir)
	boss_pattern = ""
	boss_pattern_left = 0
	log_event("boss_pattern",{"pattern":pattern,"base_hp":base_hp})

func _step_hazards(dt: float):
	var remaining: Array = []
	for h in hazards:
		if h.warning>0: h.warning -= dt
		else:
			h.life -= dt
			if respawn_left<=0 and pos.distance_to(h.pos)<=h.radius+0.5:
				damage_hero(h.damage*dt,"magic","boss_debris")
			for ally in defenders:
				if ally.hp>0 and ally.pos.distance_to(h.pos)<=h.radius+0.5:
					_damage_defender(ally,h.damage*dt)
		if h.life>0: remaining.append(h)
	hazards = remaining

func _recipe_cost(id: String, available: Array, consume: Array) -> int:
	var item: Dictionary = items[id]
	var cost = int(item.craft_fee)
	for component in item.recipe:
		for i in int(item.recipe[component]):
			var found = -1
			for index in available:
				if inventory[index]==component:
					found = index
					break
			if found>=0:
				available.erase(found)
				consume.append(found)
			else: cost += _recipe_cost(component,available,consume)
	return cost

func get_buy_quote(id: String) -> Dictionary:
	var result = {"ok":false,"reason":"Unknown item","cost":0,"consume":[]}
	if not items.has(id): return result
	var item: Dictionary = items[id]
	var available: Array = []
	for i in inventory.size(): available.append(i)
	var consume: Array = []
	var cost = _recipe_cost(id,available,consume)
	result.cost = cost
	result.consume = consume
	if phase not in ["Preparation","FinalPreparation"]: result.reason = "Forge opens between waves"
	elif completed_wave < item.unlock_after_wave: result.reason = "Unlocks after wave %d" % int(item.unlock_after_wave)
	elif id=="healing_potion" and potions>=3: result.reason = "Potion reserve full (3)"
	elif id!="healing_potion" and inventory.size()-consume.size()>=6: result.reason = "All six equipment slots are full"
	elif gold<cost: result.reason = "Need %d more gold" % (cost-gold)
	else:
		result.ok = true
		result.reason = "Ready"
	return result

func buy(id: String) -> Dictionary:
	var quote = get_buy_quote(id)
	if not quote.ok:
		announce(quote.reason)
		return quote
	# Validate everything before the first mutation. Components consume atomically.
	var consume: Array = quote.consume.duplicate()
	consume.sort()
	consume.reverse()
	for index in consume: inventory.remove_at(index)
	gold -= int(quote.cost)
	if id=="healing_potion": potions += 1
	else: inventory.append(id)
	recalculate_stats()
	announce("Forged %s" % items[id].name_ko)
	if not metrics.purchase_times.has(id): metrics.purchase_times[id] = elapsed
	log_event("purchase",{"item":id,"cost":quote.cost,"gold":gold})
	save_checkpoint()
	return quote

func sell(index: int) -> Dictionary:
	if phase not in ["Preparation","FinalPreparation"]: return {"ok":false,"reason":"Forge opens between waves"}
	if index<0 or index>=inventory.size(): return {"ok":false,"reason":"Invalid equipment slot"}
	var id: String = inventory[index]
	var refund = int(items[id].sell_price)
	inventory.remove_at(index)
	gold += refund
	recalculate_stats()
	announce("Sold %s  •  +%d gold" % [items[id].name_ko,refund])
	log_event("sale",{"item":id,"refund":refund,"gold":gold})
	save_checkpoint()
	return {"ok":true,"reason":"Sold","refund":refund}

func enhance(index: int) -> Dictionary:
	if phase not in ["Preparation","FinalPreparation"]: return {"ok":false,"reason":"Forge opens between waves"}
	if index<0 or index>=inventory.size(): return {"ok":false,"reason":"Invalid slot"}
	var id: String = inventory[index]
	var item = items[id]
	var tier = int(item.get("tier",0))
	if tier < 1 or tier > 2: return {"ok":false,"reason":"Cannot enhance"}
	var cost = tier * 50 + 30
	if gold < cost: return {"ok":false,"reason":"Not enough gold"}
	gold -= cost
	# 강화 레벨 저장 (item_id + enhancement level)
	var enhanced_id = id + "+1"
	if not enhanced_items.has(enhanced_id):
		enhanced_items[enhanced_id] = item.duplicate(true)
		enhanced_items[enhanced_id].id = enhanced_id
		enhanced_items[enhanced_id].name_ko = item.name_ko + " +1"
		# 스탯 +15%
		for key in enhanced_items[enhanced_id].stats:
			enhanced_items[enhanced_id].stats[key] = int(float(enhanced_items[enhanced_id].stats[key]) * 1.15)
	inventory[index] = enhanced_id
	# items에 등록
	if not items.has(enhanced_id):
		items[enhanced_id] = enhanced_items[enhanced_id]
	announce("Enhanced %s  •  +%d gold spent" % [item.name_ko, cost])
	log_event("enhance",{"item":id,"cost":cost,"gold":gold})
	save_checkpoint()
	return {"ok":true,"reason":"Enhanced","cost":cost}

func use_potion() -> bool:
	if potions<=0 or potion_cd>0 or respawn_left>0 or phase not in ["Combat","Boss"]: return false
	if hp>=stats.max_hp: return false
	potions -= 1
	potion_cd = 30
	potion_heal_left = 3.01
	potion_ticks = 3
	potion_tick_left = 1
	potion_tick_heal = stats.max_hp*0.1
	_effect("heal",pos,1.8,0.7)
	return true

func save_checkpoint() -> bool:
	if phase not in ["Preparation","FinalPreparation"]: return false
	var save = {"schema":SAVE_SCHEMA,"build":BUILD,"content_hash":content_hash,"hero":hero_id,"seed":seed_value,"rng_state":str(rng.state),"spawn_rng_state":str(spawn_rng.state),"camp_rng_state":str(camp_rng.state),"ruleset":ruleset,"tempo_version":str(tempo.version),"phase":phase,"completed_wave":completed_wave,"base_hp":base_hp,"hp":hp,"energy":energy,"gold":gold,"xp":xp,"level":level,"inventory":inventory,"potions":potions,"elapsed":elapsed,"metrics":metrics,"cooldowns":cooldowns,"potion_cd":potion_cd,"sanctuary_cd":sanctuary_cd}
	var temporary = SAVE_PATH+".tmp"
	var file = FileAccess.open(temporary,FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify(save))
	file.flush()
	file.close()
	if _read_valid_checkpoint(temporary).is_empty(): return false
	var path = ProjectSettings.globalize_path(SAVE_PATH)
	# A recovered run may still have a damaged primary on disk. Never overwrite
	# its known-good backup with that same damaged file on the next save.
	if not _read_valid_checkpoint(SAVE_PATH).is_empty():
		if DirAccess.copy_absolute(path,path+".bak")!=OK: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary),path)==OK

func has_checkpoint() -> bool:
	return FileAccess.file_exists(SAVE_PATH) or FileAccess.file_exists(SAVE_PATH+".bak")

func load_checkpoint() -> bool:
	if not has_checkpoint():
		announce("No saved game found.")
		return false
	var save = _read_valid_checkpoint(SAVE_PATH)
	var recovered = false
	if save.is_empty():
		save = _read_valid_checkpoint(SAVE_PATH+".bak")
		recovered = not save.is_empty()
	if save.is_empty():
		var primary_schema: int = _checkpoint_schema(SAVE_PATH)
		var backup_schema: int = _checkpoint_schema(SAVE_PATH+".bak")
		if (primary_schema>0 and primary_schema<SAVE_SCHEMA) or (backup_schema>0 and backup_schema<SAVE_SCHEMA):
			announce("This checkpoint uses an incompatible game version. Start a new game.")
		else:
			announce("Save is damaged or belongs to a different content version.")
		return false
	reset(save.hero,int(save.seed))
	rng.state = int(save.rng_state)
	spawn_rng.state = int(save.spawn_rng_state)
	camp_rng.state = int(save.camp_rng_state)
	phase = save.phase
	completed_wave = int(save.completed_wave)
	wave = completed_wave
	base_hp = clampf(float(save.base_hp),1,max_base_hp)
	gold = maxi(0,int(save.gold))
	xp = maxi(0,int(save.xp))
	level = clampi(int(save.level),1,12)
	inventory = save.inventory.duplicate()
	potions = clampi(int(save.potions),0,3)
	elapsed = float(save.elapsed)
	# Only known, validated fields are restored. Unknown future/debug metadata
	# must not become executable simulation state after a damaged-file recovery.
	for key in metrics:
		if save.metrics.has(key): metrics[key] = save.metrics[key].duplicate(true) if save.metrics[key] is Dictionary or save.metrics[key] is Array else save.metrics[key]
	cooldowns = save.cooldowns.duplicate(true)
	potion_cd = float(save.potion_cd)
	sanctuary_cd = float(save.sanctuary_cd)
	recalculate_stats()
	hp = float(save.hp)
	energy = float(save.energy)
	prep_left = (float(tempo.preparation_seconds) if ruleset=="fast" else 15.0) if phase=="FinalPreparation" else 0
	announce("Previous checkpoint recovered. Prepare before the next battle." if recovered else "Checkpoint restored. Prepare before the next battle.")
	return true

func add_shield(group: String, amount: float, duration: float):
	var current = shield_groups.get(group,{"amount":0.0,"left":0.0})
	shield_groups[group] = {"amount":maxf(current.amount,amount),"left":duration}
	_sync_shields()

func _sync_shields():
	shield = 0
	shield_left = 0
	for group in shield_groups.values():
		shield += group.amount
		shield_left = maxf(shield_left,group.left)

func _consume_shield(amount: float):
	if shield_groups.is_empty():
		shield = maxf(0,shield-amount)
		return
	var groups = shield_groups.keys()
	groups.sort_custom(func(a,b): return shield_groups[a].left<shield_groups[b].left)
	for group in groups:
		var used = minf(amount,shield_groups[group].amount)
		shield_groups[group].amount -= used
		amount -= used
		if shield_groups[group].amount<=0: shield_groups.erase(group)
		if amount<=0: break
	_sync_shields()

func _read_valid_checkpoint(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var text = FileAccess.get_file_as_string(path)
	if text.length()>2000000: return {}
	var parser = JSON.new()
	if parser.parse(text)!=OK: return {}
	var parsed = parser.data
	if not parsed is Dictionary: return {}
	var save: Dictionary = parsed
	if save.get("schema",0)!=SAVE_SCHEMA or save.get("content_hash","")!=content_hash: return {}
	if not save.get("hero") is String or not heroes.has(save.hero): return {}
	if save.get("phase","") not in ["Preparation","FinalPreparation"]: return {}
	for key in ["seed","completed_wave","base_hp","hp","energy","gold","xp","level","potions","elapsed","potion_cd","sanctuary_cd"]:
		if not (save.get(key) is float or save.get(key) is int): return {}
		if not is_finite(float(save[key])): return {}
	for key in ["seed","completed_wave","gold","xp","level","potions"]:
		if float(save[key])!=floorf(float(save[key])): return {}
	if save.completed_wave<0 or save.completed_wave>10: return {}
	if save.phase=="FinalPreparation" and save.completed_wave!=10: return {}
	if save.phase=="Preparation" and save.completed_wave==10: return {}
	if save.base_hp<=0 or save.base_hp>max_base_hp: return {}
	if save.gold<0 or save.gold>1000000000 or save.xp<0 or save.xp>1000000000: return {}
	if save.level<1 or save.level>12 or save.potions<0 or save.potions>3 or save.elapsed<0: return {}
	if save.potion_cd<0 or save.potion_cd>30 or save.sanctuary_cd<0 or save.sanctuary_cd>30: return {}
	if not save.get("rng_state") is String or not save.rng_state.is_valid_int(): return {}
	if not save.get("spawn_rng_state") is String or not save.spawn_rng_state.is_valid_int(): return {}
	if not save.get("camp_rng_state") is String or not save.camp_rng_state.is_valid_int(): return {}
	if save.get("ruleset","")!=ruleset or save.get("tempo_version","")!=str(tempo.version): return {}
	if not save.get("inventory") is Array or save.inventory.size()>6: return {}
	for id in save.inventory:
		if not id is String or not items.has(id) or id=="healing_potion": return {}
	var saved_stats = derived_stats(save.hero,int(save.level),save.inventory)
	if save.hp<=0 or save.hp>saved_stats.max_hp or save.energy<0 or save.energy>saved_stats.max_energy: return {}
	if not save.get("cooldowns") is Dictionary or save.cooldowns.size()!=5: return {}
	for slot in ["Q","W","E","R","F"]:
		var cd = save.cooldowns.get(slot)
		if not (cd is float or cd is int) or not is_finite(float(cd)) or cd<0 or cd>3600: return {}
	if not _valid_checkpoint_metrics(save.get("metrics")): return {}
	return save

static func _valid_nonnegative_number(value, upper: float = 1000000000000.0) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value)>=0 and float(value)<=upper

func _valid_checkpoint_metrics(value) -> bool:
	if not value is Dictionary: return false
	for key in metrics:
		if not value.has(key): continue # Newly added optional counters keep defaults.
		var entry = value[key]
		if metrics[key] is Dictionary:
			if not entry is Dictionary or entry.size()>128: return false
			for counter in entry:
				if not counter is String or counter.length()>80: return false
				if not _valid_nonnegative_number(entry[counter]): return false
				if key in ["casts_by_slot","hits_by_source"] and float(entry[counter])!=floorf(float(entry[counter])): return false
		elif key=="waves":
			if not entry is Array or entry.size()>10: return false
			for cleared in entry:
				if not cleared is Dictionary: return false
				for field in ["wave","time","base_hp","level","gold_earned"]:
					if not _valid_nonnegative_number(cleared.get(field)): return false
				if cleared.wave<1 or cleared.wave>10 or cleared.wave!=floorf(cleared.wave): return false
				if cleared.level<1 or cleared.level>12 or cleared.level!=floorf(cleared.level): return false
				if cleared.base_hp>max_base_hp: return false
		elif not _valid_nonnegative_number(entry): return false
		elif metrics[key] is int and float(entry)!=floorf(float(entry)): return false
	return true

func assisted_aim(slot: String) -> Vector2:
	# Assisted taps use the actual skill geometry, not a universal distant target.
	# Explicit aim points remain untouched for deliberate targeting and replay QA.
	var key = hero_id+"."+slot
	var search = 14.0
	if key=="guardian.Q": search = 4.0
	elif key=="guardian.E": search = 10.0
	elif key=="ranger.W": search = 8.0
	elif key=="arcanist.Q": search = 15.5
	elif key=="arcanist.E": search = 16.0
	var candidates = _targets(pos,search,60)
	if candidates.is_empty(): return pos+facing*4
	var nearest = _nearest(pos,search)
	var best_point: Vector2 = nearest.pos
	if key not in ["guardian.Q","ranger.Q","ranger.W","arcanist.Q","arcanist.E"]: return best_point
	var best_score = -INF
	for candidate in candidates:
		var point: Vector2 = candidate.pos
		var direction: Vector2 = (point-pos).normalized()
		if direction==Vector2.ZERO: direction = facing if facing!=Vector2.ZERO else Vector2.RIGHT
		if key in ["arcanist.Q","arcanist.E"]: point = pos+direction*minf(12,pos.distance_to(point))
		if key=="ranger.W": point = pos+direction*minf(5,pos.distance_to(point))
		var score = -pos.distance_to(point)*0.001
		for e in enemies:
			if e.hp<=0: continue
			var delta: Vector2 = e.pos-pos
			var hit = false
			match key:
				"guardian.Q": hit = delta.length()<=4+float(e.radius) and (delta.length()<1 or delta.normalized().dot(direction)>=cos(PI/4))
				"ranger.Q": hit = delta.dot(direction)>=0 and delta.dot(direction)<=14 and absf(delta.cross(direction))<=0.75+float(e.radius)
				"ranger.W": hit = point.distance_to(e.pos)<=3+float(e.radius)
				"arcanist.Q": hit = point.distance_to(e.pos)<=3.5+float(e.radius)
				"arcanist.E": hit = point.distance_to(e.pos)<=4+float(e.radius)
			if hit: score += 20 if e.kind=="weakness" else (1.2 if e.kind=="siege" else 1.0)
		if score>best_score:
			best_score = score
			best_point = point
	return best_point

func sell_potion() -> Dictionary:
	if phase not in ["Preparation","FinalPreparation"]: return {"ok":false,"reason":"Forge opens between waves"}
	if potions<=0: return {"ok":false,"reason":"No potion to sell"}
	var refund = int(items.healing_potion.sell_price)
	potions -= 1
	gold += refund
	# The shared cooldown persists through inventory changes.
	log_event("sale",{"item":"healing_potion","refund":refund,"gold":gold})
	save_checkpoint()
	return {"ok":true,"reason":"Sold","refund":refund}

func _checkpoint_schema(path: String) -> int:
	if not FileAccess.file_exists(path): return 0
	var text = FileAccess.get_file_as_string(path)
	if text.length()>2000000: return 0
	var parser = JSON.new()
	if parser.parse(text)!=OK or not parser.data is Dictionary: return 0
	var schema = parser.data.get("schema",0)
	return int(schema) if schema is int or schema is float else 0

# Local NPC support and finite optional camps. Neither pauses the main battle.
func _reset_defenders() -> void:
	defenders = []
	if ruleset!="fast" or not tempo.defenders.enabled: return
	for index in int(tempo.defenders.count):
		var point = tempo.defenders.positions[index]
		defenders.append({"id":index+1,"pos":Vector2(point[0],point[1]),"hp":float(tempo.defenders.hp),"max_hp":float(tempo.defenders.hp),"attack_left":0.6,"respawn_left":0.0,"flash":0.0})

func _defender_by_id(id: int) -> Dictionary:
	for ally in defenders:
		if ally.id==id: return ally
	return {}

func _nearest_defender(at: Vector2, radius: float) -> Dictionary:
	var nearest: Dictionary = {}
	var best: float = radius
	for ally in defenders:
		var distance: float = at.distance_to(ally.pos)
		if ally.hp>0 and distance<=best:
			best = distance
			nearest = ally
	return nearest

func _damage_defender(ally: Dictionary, amount: float) -> void:
	if ally.hp<=0: return
	ally.hp = maxf(0,float(ally.hp)-amount)
	ally.flash = 0.15
	if ally.hp<=0:
		ally.respawn_left = float(tempo.defenders.respawn_seconds)
		metrics.defender_deaths += 1
		log_event("defender_death",{"id":ally.id})

func _step_defenders(dt: float) -> void:
	if phase not in ["Combat","Boss"]: return
	for ally in defenders:
		ally.flash = maxf(0,float(ally.flash)-dt)
		if ally.hp<=0:
			ally.respawn_left -= dt
			if ally.respawn_left<=0:
				ally.hp = ally.max_hp
				ally.attack_left = 0.6
			continue
		ally.attack_left -= dt
		if ally.attack_left>0: continue
		var target: Dictionary = {}
		var distance: float = float(tempo.defenders.range)
		for enemy in enemies:
			if enemy.hp<=0 or enemy.get("hunt_enemy",false): continue
			var candidate: float = ally.pos.distance_to(enemy.pos)
			if candidate<=distance:
				distance = candidate
				target = enemy
		if target.is_empty(): continue
		var direction: Vector2 = (target.pos-ally.pos).normalized()
		if direction==Vector2.ZERO: direction = Vector2.RIGHT
		projectiles.append({"pos":ally.pos,"previous":ally.pos,"velocity":direction*22.0,"hostile":false,"radius":0.15,"life":0.8,"damage":float(tempo.defenders.damage),"damage_type":"physical","target_id":target.id,"basic":false,"hero":"defender","source":"defender"})
		ally.attack_left = float(tempo.defenders.attack_interval_seconds)

func _reset_allies() -> void:
	allies = []
	if ruleset != "fast": return
	# AI 동료 2명: ranger + arcanist
	var ally_defs = [
		{"hero":"ranger","pos":Vector2(12,20),"hp":650.0,"max_hp":650.0,"attack_left":0.5,"respawn_left":0.0,"flash":0.0,"ad":32.0},
		{"hero":"arcanist","pos":Vector2(12,28),"hp":620.0,"max_hp":620.0,"attack_left":0.5,"respawn_left":0.0,"flash":0.0,"ad":24.0}
	]
	for a in ally_defs:
		allies.append(a)

func _step_allies(dt: float) -> void:
	if phase not in ["Combat", "Boss"]: return
	for ally in allies:
		ally.flash = maxf(0,float(ally.flash)-dt)
		if ally.hp<=0:
			ally.respawn_left -= dt
			if ally.respawn_left<=0:
				ally.hp = ally.max_hp
				ally.attack_left = 0.5
			continue
		# Always chase nearest enemy so allies do not stand still.
		var target: Dictionary = {}
		var distance: float = 16.0
		for enemy in enemies:
			if enemy.hp<=0 or enemy.get("hunt_enemy",false): continue
			var candidate: float = ally.pos.distance_to(enemy.pos)
			if candidate<=distance:
				distance = candidate
				target = enemy
		if not target.is_empty():
			var to_target: Vector2 = (target.pos-ally.pos)
			if to_target.length() > 1.2:
				ally.pos += to_target.normalized()*6.5*dt
				ally.pos = clamp_position(ally.pos)
		ally.attack_left -= dt
		if target.is_empty() or ally.attack_left>0: continue
		var direction: Vector2 = (target.pos-ally.pos).normalized()
		if direction==Vector2.ZERO: direction = Vector2.RIGHT
		projectiles.append({"pos":ally.pos,"previous":ally.pos,"velocity":direction*22.0,"hostile":false,"radius":0.15,"life":0.8,"damage":float(ally.get("ad",30)),"damage_type":"physical","target_id":target.id,"basic":false,"hero":ally.hero,"source":"ally"})
		ally.attack_left = float(tempo.defenders.attack_interval_seconds)

func main_enemy_count() -> int:
	var count: int = 0
	for enemy in enemies:
		if enemy.hp>0 and not enemy.get("hunt_enemy",false): count += 1
	return count

func _observe_pressure() -> void:
	var nearby: int = 0
	for enemy in enemies:
		if enemy.hp>0 and enemy.pos.distance_to(pos)<=8: nearby += 1
	metrics.peak_enemies = maxi(int(metrics.peak_enemies),main_enemy_count())
	metrics.peak_nearby_8m = maxi(int(metrics.peak_nearby_8m),nearby)

func _trigger_kill_arena() -> void:
	phase = "SpecialEvent"
	special_event = {"active":true, "arena_active":true, "type":"kill_arena", "timer":0.0, "duration":60.0}
	announce("SPECIAL EVENT - 2000 Kills! 60s Elite Hunt Arena!")
	log_event("special_event_start",{"type":"kill_arena"})
	for i in 5: spawn_enemy("elite",_spawn_position(),false)
	for i in 3: spawn_enemy("healer",_spawn_position(),false)
	spawn_queue.clear()

func _trigger_special_event() -> void:
	phase = "SpecialEvent"
	special_event = {"active":true,"enemies_spawned":0,"max_enemies":20,"timer":0.0,"duration":45.0,"spawn_timer":0.0}
	announce("SPECIAL EVENT - Bonus arena! Kill all enemies for extra rewards!")
	log_event("special_event_start",{"wave":completed_wave})
	for i in 8:
		spawn_enemy("crawler",_spawn_position(),false)
		special_event["enemies_spawned"] += 1
	for i in 4:
		spawn_enemy("shooter",_spawn_position(),false)
		special_event["enemies_spawned"] += 1
	for i in 2:
		spawn_enemy("guard",_spawn_position(),false)
		special_event["enemies_spawned"] += 1

func _step_special_event(dt: float) -> void:
	if phase != "SpecialEvent": return
	special_event["timer"] += dt
	if special_event["timer"] >= special_event["duration"] or enemies.size() == 0:
		var bonus_gold: int = 200 + completed_wave * 50
		var bonus_xp: int = 150 + completed_wave * 30
		gold += bonus_gold
		xp += bonus_xp
		metrics.gold_earned += bonus_gold
		announce("SPECIAL EVENT CLEAR  •  +%d gold, +%d xp" % [bonus_gold, bonus_xp])
		log_event("special_event_end",{"wave":completed_wave,"gold":bonus_gold,"xp":bonus_xp})
		phase = "Preparation"
		special_event = {}
		return
	# Spawn more enemies over time
	special_event["spawn_timer"] -= dt
	if special_event["spawn_timer"] <= 0 and special_event["enemies_spawned"] < special_event["max_enemies"]:
		special_event["spawn_timer"] = 5.0
		var kinds = ["crawler", "crawler", "skirmisher", "shooter"]
		spawn_enemy(kinds[spawn_rng.randi() % kinds.size()], _spawn_position(), false)
		special_event["enemies_spawned"] += 1

func _prepare_hunt() -> void:
	hunt = {}
	if ruleset!="fast" or not tempo.hunt.enabled or not tempo.hunt.waves.map(func(value): return int(value)).has(wave): return
	var point = tempo.hunt.position
	hunt = {"state":"waiting","wave":wave,"pos":Vector2(point[0],point[1]),"offered_at":elapsed+float(tempo.hunt.offer_delay_seconds),"time_left":float(tempo.hunt.window_seconds),"return_left":0.0,"reward_claimed":false,"outcome":"","enemy_ids":[]}

func can_start_hunt() -> bool:
	if phase!="Combat" or hp<=0 or respawn_left>0 or hunt.get("state","")!="available": return false
	if base_hp/max_base_hp<=float(tempo.hunt.min_castle_ratio): return false
	if pos.distance_to(hunt.pos)>float(tempo.hunt.activation_radius): return false
	var needed: int = 0
	for count in tempo.hunt.enemy_counts.values(): needed += int(count)
	return enemies.size()+needed<=60

func start_hunt() -> bool:
	if not can_start_hunt(): return false
	hunt.state = "active"
	metrics.hunt_attempts += 1
	var count: int = 0
	for kind in tempo.hunt.enemy_counts:
		for index in int(tempo.hunt.enemy_counts[kind]):
			var enemy = spawn_enemy(kind,clamp_position(hunt.pos+Vector2((count%2)*1.5-0.75,(count/2)*1.2-0.6)),false,camp_rng)
			enemy.hunt_enemy = true
			enemy.hunt_wave = wave
			enemy.home = hunt.pos
			hunt.enemy_ids.append(enemy.id)
			count += 1
	log_event("hunt_start",{"wave":wave,"base_hp":base_hp})
	announce("HUNT START  •  The castle battle continues.")
	return true

func request_hunt_return() -> bool:
	if phase!="Combat" or hp<=0 or respawn_left>0 or hunt.get("state","") not in ["active","cleared"]: return false
	cancel_cast()
	cast_buffer.clear()
	hunt.outcome = "success" if hunt.reward_claimed else "abandoned"
	hunt.state = "returning"
	hunt.return_left = 0.0 if base_hp/max_base_hp<=float(tempo.hunt.emergency_castle_ratio) else float(tempo.hunt.return_seconds)
	log_event("hunt_return",{"wave":wave,"seconds":hunt.return_left,"emergency":hunt.return_left==0})
	if hunt.return_left<=0:
		_close_hunt(hunt.outcome)
		pos = START
	return true

func _hunt_channeling() -> bool:
	return hunt.get("state","")=="returning"

func _step_hunt_clock(dt: float) -> void:
	if hunt.is_empty() or phase!="Combat": return
	if hunt.state=="waiting" and elapsed>=hunt.offered_at:
		hunt.state = "available"
		announce("OPTIONAL HUNT  •  Leave the road for a one-time bounty.")
		log_event("hunt_available",{"wave":wave})
	if hunt.state=="active":
		hunt.time_left -= dt
		metrics.hunt_seconds += dt
		if hunt.time_left<=0: _close_hunt("timeout")
	elif hunt.state=="returning":
		hunt.return_left -= dt
		metrics.hunt_seconds += dt
		if hunt.return_left<=0:
			_close_hunt(hunt.outcome)
			pos = START

func _settle_hunt() -> void:
	if hunt.get("state","")!="active" or phase!="Combat": return
	if base_hp<=0 or hp<=0 or respawn_left>0:
		_close_hunt("failure")
		return
	for enemy in enemies:
		if enemy.get("hunt_enemy",false) and enemy.hp>0: return
	if hunt.reward_claimed: return
	hunt.reward_claimed = true
	hunt.state = "cleared"
	hunt.outcome = "success"
	var bounty_gold: int = int(tempo.hunt.gold_reward)
	var bounty_xp: int = int(tempo.hunt.xp_reward)
	gold += bounty_gold
	xp += bounty_xp
	metrics.gold_earned += bounty_gold
	metrics.hunt_gold += bounty_gold
	metrics.hunt_xp += bounty_xp
	metrics.hunt_successes += 1
	_update_level()
	log_event("hunt_success",{"wave":wave,"gold":bounty_gold,"xp":bounty_xp,"base_hp":base_hp})
	announce("HUNT CLEAR  •  Return to defend the castle.")

func _close_hunt(reason: String) -> void:
	if hunt.is_empty() or hunt.state=="closed": return
	enemies = enemies.filter(func(enemy): return not enemy.get("hunt_enemy",false))
	hunt.state = "closed"
	hunt.outcome = reason
	hunt.enemy_ids = []
	hunt.return_left = 0.0
	log_event("hunt_closed",{"wave":hunt.wave,"reason":reason,"rewarded":hunt.reward_claimed})

func _step_hunt_enemy(enemy: Dictionary, dt: float) -> void:
	if enemy.telegraph>0:
		enemy.telegraph -= dt
		if enemy.telegraph<=0: _enemy_attack(enemy)
		return
	var destination: Vector2 = enemy.home
	var hero_in_camp: bool = hp>0 and respawn_left<=0 and pos.distance_to(enemy.home)<=float(tempo.hunt.leash_radius)
	if hero_in_camp: destination = pos
	var distance: float = enemy.pos.distance_to(destination)
	if hero_in_camp and distance<=1.5:
		if enemy.attack_timer<=0:
			enemy.telegraph = 0.32
			enemy.attack_target = "hero"
			enemy.attack_pos = pos
			enemy.attack_timer = float(enemy.interval)
	elif distance>0.15:
		enemy.pos = enemy.pos.move_toward(destination,float(enemy.speed)*(1-float(enemy.slow))*dt)
