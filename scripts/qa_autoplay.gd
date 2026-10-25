extends Node
## Opt-in debug-only runtime QA controller. Never grants resources or calls model
## combat/economy/step methods. All actions pass through the Viewport input pipeline.
## This is synthetic in-app touch dispatch, NOT physical touchscreen/Android OS QA.
var ui: Node
var hero = "guardian"
var policy = "priority"
var active = false
var stage = "choose_hero"
var delay = 0.4
var action_clock = 0.0
var wall_start = 0
var event_count = 0
var transitions: Array = []
var errors: Array = []
var last_phase = ""
var selected_purchase = ""
var purchase_gold = 0
var purchase_inventory: Array = []
var previous_stick = Vector2.ZERO
var last_heartbeat = 0.0
var source_commit = "development-unbound"
var result_path = ""
var last_model_time = 0.0
var stalled_seconds = 0.0
const CONTROLLER_REVISION = 3
var hunt_visits: Dictionary = {}
var hunt_decisions: Array = []
var hunt_purchase_stage: int = 0
var escape_model_id: int = 0
var escape_until: float = -1.0
var escape_direction: Vector2 = Vector2.ZERO

static func valid_request(request: String) -> bool:
	var parts = request.split(":")
	return parts.size()==2 and parts[0] in ["guardian","ranger","arcanist"] and parts[1] in ["aggressive","priority","hunt"]

func configure(scene: Node, request: String) -> bool:
	if not OS.is_debug_build() or not valid_request(request): return false
	ui = scene
	var parts = request.split(":")
	hero = parts[0]
	policy = parts[1]
	active = true
	return true

func _ready():
	if not active or ui==null:
		set_process(false)
		return
	wall_start = Time.get_ticks_msec()
	result_path = "user://qa_autoplay_%s_%s.json" % [hero,policy]
	if FileAccess.file_exists("res://data/build_info.json"):
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://data/build_info.json"))==OK and parser.data is Dictionary:
			source_commit = str(parser.data.get("source_commit",source_commit))
	print("QA_AUTOPLAY_START ",JSON.stringify({"hero":hero,"policy":policy,"controller_revision":CONTROLLER_REVISION,"tempo_version":ui.model.tempo.version,"hunt_contract":"explicit_nearby_start_one_trip_8s_approach_10s_active" if policy=="hunt" else "none","combat_policy":"close_guardian_assisted_locked_smash_arcanist_body_reach" if policy=="hunt" else "legacy","seed":12345,"engine":Engine.get_version_info().string,"build":ui.model.BUILD,"source_commit":source_commit,"debug_build":OS.is_debug_build(),"explicit_launch_flag_required":true,"real_time":true,"realtime_performance_claim":false,"clock_policy":"fixed_30hz_active_delta_capped_150ms","no_model_state_or_resource_injection":true,"input_route":"Viewport.push_input(InputEventScreenTouch/Drag, true)","physical_touch_test":false}))

func _process(delta: float):
	if not active or not is_instance_valid(ui): return
	var m = ui.model
	if policy=="hunt" and ui.mode=="game": _observe_hunt_end()
	if ui.mode=="game" and m.phase in ["Victory","Defeat"]:
		_finish(m.phase)
		return
	delay -= delta
	if delay>0: return
	var key = str(m.phase)+":"+str(m.wave)
	if ui.mode=="game" and key!=last_phase:
		last_phase = key
		var transition = {"time":m.elapsed,"phase":m.phase,"wave":m.wave,"base_hp":m.base_hp,"gold":m.gold,"level":m.level}
		transitions.append(transition)
		print("QA_AUTOPLAY_PHASE ",JSON.stringify(transition))
	if ui.mode=="game" and m.elapsed-last_heartbeat>=30:
		last_heartbeat = m.elapsed
		print("QA_AUTOPLAY_HEARTBEAT ",JSON.stringify({"time":m.elapsed,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,"phase":m.phase,"wave":m.wave,"base_hp":m.base_hp,"hero_hp":m.hp,"events":event_count,"fps":Engine.get_frames_per_second(),"clock":_clock_snapshot()}))
	if m.elapsed>=1800:
		_finish("TIME_LIMIT_INCONCLUSIVE")
		return
	match stage:
		"choose_hero":
			if _tap_hit("hero",hero): stage="start"; delay=0.2
		"start":
			if _tap_hit("start"): stage="play"; delay=0.3
		"open_shop":
			_move(Vector2.ZERO)
			if ui.modal=="shop": stage="choose_purchase"; delay=0.15
			elif _tap_hit("modal","shop"): delay=0.2
		"choose_purchase":
			selected_purchase = _next_purchase()
			if selected_purchase=="": stage="close_shop"
			elif _tap_hit("item",selected_purchase): stage="purchase"; delay=0.15
			else:
				var wanted_page = 0
				for i in m.data.items.size():
					if m.data.items[i].id==selected_purchase: wanted_page=i/12
				if not _tap_hit("shop_page",str(wanted_page)):
					_abort("Expected catalog/page hitbox absent: "+selected_purchase)
				delay=0.2
		"purchase":
			purchase_gold = m.gold
			purchase_inventory = m.inventory.duplicate()
			if _tap_hit("buy"): stage="verify_purchase"; delay=0.2
			else: _abort("Expected affordable purchase button absent: "+selected_purchase)
		"verify_purchase":
			if m.gold==purchase_gold and m.inventory==purchase_inventory:
				_abort("UI purchase produced no transaction: "+selected_purchase)
			else: stage="choose_purchase"; delay=0.15
		"close_shop":
			if _tap_hit("close"): stage="ready"; delay=0.2
		"ready":
			if _tap_hit("next"): stage="play"; delay=0.2
		"play":
			if m.phase in ["Preparation","FinalPreparation"]:
				stage="open_shop"
				return
			if ui.modal!="":
				# Deliberate human/lifecycle pause is not silently dismissed by QA.
				_move(Vector2.ZERO)
				return
			if m.respawn_left>0 or m.phase not in ["Combat","Boss"]:
				_move(Vector2.ZERO)
				return
			var hunt_movement_handled: bool = _hunt_control() if policy=="hunt" else false
			var target = _target()
			if not hunt_movement_handled:
				if target.is_empty(): _move(Vector2.ZERO)
				else: _move(_movement(target))
			if not target.is_empty() and m.hunt.get("state","")!="returning":
				action_clock += delta
				if action_clock>=0.1:
					action_clock=0
					_skills(target)

func _dispatch(event: InputEvent):
	event_count += 1
	ui.get_viewport().push_input(event,true)

func _touch(index: int, at: Vector2, pressed: bool):
	var event = InputEventScreenTouch.new()
	event.index=index
	event.position=at
	event.pressed=pressed
	_dispatch(event)

func _tap(at: Vector2):
	_touch(1,at,true)
	_touch(1,at,false)

func _tap_hit(action: String, value: String = "") -> bool:
	for hit in ui.hits:
		if str(hit.action)==action and str(hit.get("value",""))==value:
			_tap(hit.rect.get_center())
			return true
	return false

func _move(direction: Vector2):
	if direction.length()<0.05:
		if ui.joystick_id==0: _touch(0,ui.joystick_center,false)
		previous_stick=Vector2.ZERO
		return
	var ratio = (ui.MAP.size.x/48.0)/(ui.MAP.size.y/24.0)
	var screen = Vector2(direction.x,direction.y/ratio).normalized()
	var point: Vector2 = ui.joystick_center+screen*60
	if ui.joystick_id!=0: _touch(0,point,true)
	else:
		var drag = InputEventScreenDrag.new()
		drag.index=0
		drag.position=point
		drag.relative=point-previous_stick
		_dispatch(drag)
	previous_stick=point

func _next_purchase() -> String:
	var m = ui.model
	if policy=="hunt": return _hunt_next_purchase()
	var route: Array = []
	if hero=="guardian":
		route=[{"after_wave":0,"inventory":["iron_blade"]},{"after_wave":2,"inventory":["storm_blade"]},{"after_wave":5,"inventory":["tempest_glaive"]},{"after_wave":7,"inventory":["tempest_glaive","guard_armor"]},{"after_wave":9,"inventory":["tempest_glaive","fortress"]},{"after_wave":10,"inventory":["tempest_glaive","fortress","guard_armor"]}]
	else:
		for entry in m.data.purchase_routes:
			if entry.hero==hero: route=entry.steps
	var desired: Array = []
	for milestone in route:
		if m.completed_wave>=milestone.after_wave: desired=milestone.inventory
	var counts: Dictionary = {}
	for id in desired: counts[id]=int(counts.get(id,0))+1
	for id in counts:
		if m.inventory.count(id)<counts[id]: return id
	return ""

func _target() -> Dictionary:
	var m = ui.model
	var best: Dictionary = {}
	var best_score = INF
	for e in m.enemies:
		if e.hp<=0: continue
		var score = m.pos.distance_to(e.pos)
		if policy in ["priority","hunt"]:
			if e.kind=="weakness": score-=1000
			elif e.kind=="siege": score-=70
			elif e.kind=="shooter": score-=15
			if e.kind!="boss": score+=e.pos.x*0.3
		if policy=="hunt" and m.hunt.get("state","")=="active" and e.get("hunt_enemy",false): score-=2000
		if score<best_score: best_score=score; best=e
	return best

func _movement(target: Dictionary) -> Vector2:
	var m = ui.model
	var delta: Vector2 = target.pos-m.pos
	var distance = delta.length()
	var direction = delta.normalized()
	var reach = 0.8 if policy=="hunt" and hero=="guardian" else float(m.stats.attack_range)+float(target.radius)-0.35
	if policy=="hunt":
		var danger: Dictionary = _visible_danger_escape()
		if danger.active: return danger.direction
	if policy=="priority":
		if m.boss_pattern=="smash" and m.boss_pattern_left>0 and distance<7:
			return Vector2(-direction.y,direction.x)
		for hazard in m.hazards:
			if m.pos.distance_to(hazard.pos)<float(hazard.radius)+0.7:
				return (m.pos-hazard.pos).normalized() if m.pos!=hazard.pos else Vector2.UP
	if hero=="guardian": return direction if distance>reach else Vector2.ZERO
	if policy in ["priority","hunt"]:
		var closest = 1000.0
		var escape = Vector2.ZERO
		for e in m.enemies:
			if e.kind in ["boss","weakness","siege"]: continue
			var d = m.pos.distance_to(e.pos)
			if d<closest: closest=d; escape=(m.pos-e.pos).normalized()
		if closest<3.2 and m.pos.x<43: return escape
	if policy=="hunt" and hero=="arcanist" and target.kind=="boss" and m.level>=int(m.ability("R").unlock_level) and m.cooldowns.R<=0 and m.energy-m.energy_reserved>=float(m.ability("R").energy_cost) and m.pending_casts.is_empty():
		if distance>minf(8.45,7.0+float(target.radius)-0.25): return direction
	if distance>reach: return direction
	if policy in ["priority","hunt"] and distance<reach-2: return -direction
	return Vector2.ZERO

func _skills(target: Dictionary):
	var m = ui.model
	var distance = m.pos.distance_to(target.pos)
	var count = 0
	for e in m.enemies:
		if e.hp>0 and m.pos.distance_to(e.pos)<=5: count+=1
	var slots: Array = []
	var escaping: bool = policy=="hunt" and _visible_danger_escape().active
	if hero=="guardian":
		if distance<=4.5: slots.append("Q")
		if count>0 or m.hp<m.stats.max_hp*0.7: slots.append("W")
		if distance>4 and distance<10: slots.append("E")
		if distance<=5 and (count>=2 or target.kind=="boss"): slots.append("R")
	elif hero=="ranger":
		if distance<=14: slots.append("Q")
		if distance<=5: slots.append("W")
		if distance<=4: slots.append("E")
		if distance<=m.stats.attack_range+target.radius and (count>=2 or target.kind in ["boss","siege"]): slots.append("R")
	else:
		if distance<=12: slots.append("Q")
		if count>0 or m.hp<m.stats.max_hp*0.7: slots.append("W")
		if distance<=12: slots.append("E")
		var ultimate_reach: float = 7.0+float(target.radius) if policy=="hunt" else 7.0
		if distance<=ultimate_reach and (count>=3 or target.kind=="boss" or m.hp<m.stats.max_hp*0.45): slots.append("R")
	for slot in slots:
		if escaping and hero in ["guardian","ranger"] and slot=="E": continue
		if policy=="hunt" and slot=="E" and hunt_visits.get(str(m.wave),{}).get("stage","")=="approach": continue
		if m.cooldowns[slot]>0 or m.level<m.ability(slot).unlock_level: continue
		if policy in ["priority","hunt"] and slot=="R" and m.energy<75 and target.kind!="boss": continue
		_tap(ui.skill_center(["Q","W","E","R"].find(slot)))

# Matches the independently audited visible-geometry policy, not future boss data.
# Holding the chosen exit until this warning resolves avoids oscillating back in.
func _visible_danger_escape() -> Dictionary:
	var m = ui.model
	if m.boss_pattern=="smash" and m.boss_pattern_left>0:
		if escape_model_id==m.get_instance_id() and m.elapsed<=escape_until+0.05:
			return {"active":true,"direction":escape_direction,"reason":"hold_until_visible_smash_resolves"}
		var origin: Vector2 = m.boss_pattern_data.pos
		var axis: Vector2 = Vector2(m.boss_pattern_data.dir).normalized()
		if axis==Vector2.ZERO: axis=Vector2.LEFT
		var delta: Vector2 = m.pos-origin
		var distance = delta.length()
		var radius = float(m.boss_pattern_data.get("radius",7))+0.6
		var angle = absf(axis.angle_to(delta.normalized())) if distance>0 else 0.0
		if distance<=radius and (distance<=0.6 or angle<=PI/3):
			if distance<=0.6: return _remember_smash_escape(-axis,"smash_apex")
			var side = Vector2(-axis.y,axis.x)*(1.0 if axis.cross(delta)>=0 else -1.0)
			var outward = delta.normalized()
			var radial_distance = radius+0.2-distance
			var side_distance = distance*sin(PI/3-angle)+0.2
			return _remember_smash_escape(outward if radial_distance<side_distance else side,"locked_smash_geometry")
	else:
		escape_model_id=0; escape_until=-1; escape_direction=Vector2.ZERO
	for hazard in m.hazards:
		if m.pos.distance_to(hazard.pos)<float(hazard.get("radius",3))+0.7:
			return {"active":true,"direction":(m.pos-hazard.pos).normalized() if m.pos!=hazard.pos else Vector2.UP,"reason":"visible_debris_zone"}
	return {"active":false,"direction":Vector2.ZERO}

func _remember_smash_escape(direction: Vector2, reason: String) -> Dictionary:
	var m = ui.model
	escape_model_id=m.get_instance_id(); escape_until=m.elapsed+m.boss_pattern_left; escape_direction=direction
	return {"active":true,"direction":direction,"reason":reason}

func _hunt_log(decision: String, detail: Dictionary = {}) -> void:
	var m = ui.model
	var row: Dictionary = {"decision":decision,"time":m.elapsed,"wave":m.wave,"castle_hp":m.base_hp,"hero_hp":m.hp,"state":str(m.hunt.get("state",""))}
	row.merge(detail,true)
	hunt_decisions.append(row)
	print("QA_AUTOPLAY_HUNT ",JSON.stringify(row))

func _observe_hunt_end() -> void:
	var m = ui.model
	var key: String = str(m.hunt.get("wave",-1))
	if not hunt_visits.has(key): return
	var visit: Dictionary = hunt_visits[key]
	if str(m.hunt.get("state",""))=="closed" and visit.stage in ["approach","active","returning"]:
		var prior: String = visit.stage
		visit.stage="finished"
		_hunt_log("return_finished" if prior=="returning" else "camp_closed",{"reason":str(m.hunt.get("outcome",""))})
	elif m.respawn_left>0 and visit.stage=="approach":
		visit.stage="aborted"
		_hunt_log("abort_approach",{"reason":"hero_death"})

func _hunt_control() -> bool:
	# Read-only model observation. Actions are the same painted touch targets and
	# joystick events available to a player; no phase, resources or clock grants.
	var m = ui.model
	if m.phase!="Combat": return false
	var key: String = str(m.wave)
	var state: String = str(m.hunt.get("state",""))
	if state=="available" and not hunt_visits.has(key):
		var safe: bool = m.base_hp>m.max_base_hp*0.60 and m.hp>=m.stats.max_hp*0.55
		hunt_visits[key]={"stage":"approach" if safe else "skipped","approach_at":m.elapsed,"activation_at":-1.0,"return_at":-1.0}
		_hunt_log("approach" if safe else "skip_unsafe_entry")
	if not hunt_visits.has(key): return false
	var visit: Dictionary = hunt_visits[key]
	if visit.stage=="approach":
		if state!="available":
			visit.stage="finished"
			_hunt_log("offer_ended_before_start")
			return false
		if m.elapsed-float(visit.approach_at)>=8.0 or m.base_hp<=m.max_base_hp*0.60 or m.hp<m.stats.max_hp*0.55:
			visit.stage="aborted"
			_hunt_log("abort_approach",{"reason":"time_limit" if m.elapsed-float(visit.approach_at)>=8.0 else "safety"})
			return false
		if ui.hunt_summary().can_start:
			_move(Vector2.ZERO)
			if _tap_hit("hunt_start") and m.hunt.get("state","")=="active":
				visit.stage="active"
				visit.activation_at=m.elapsed
				_hunt_log("start_accepted")
			return true
		_move((Vector2(m.hunt.pos)-m.pos).normalized())
		return true
	if visit.stage=="active":
		if state=="closed":
			visit.stage="finished"
			_hunt_log("camp_closed",{"reason":str(m.hunt.get("outcome",""))})
			return false
		var reason: String = ""
		if state=="cleared": reason="clear"
		elif m.base_hp<=m.max_base_hp*0.60: reason="castle_safety"
		elif m.hp<=m.stats.max_hp*0.35: reason="hero_safety"
		elif m.elapsed-float(visit.activation_at)>=10.0: reason="active_time_limit"
		if reason!="":
			_move(Vector2.ZERO)
			if _tap_hit("hunt_return") and m.hunt.get("state","") in ["returning","closed"]:
				visit.stage="returning"
				visit.return_at=m.elapsed
				_hunt_log("return_accepted",{"reason":reason})
			return true
	if visit.stage=="returning":
		_move(Vector2.ZERO)
		if state=="closed":
			visit.stage="finished"
			_hunt_log("return_finished",{"reason":str(m.hunt.get("outcome",""))})
		return true
	return false

func _hunt_route() -> Array:
	# Registered richer-economy route. Still ordinary quotes, unlocks and slots.
	if hero=="arcanist": return [["focus_stone"],["focuser"],["star_core"],["star_core","focuser"],["star_core","star_core"],["star_core","star_core","guard_armor"],["star_core","star_core","fortress"],["star_core","star_core","fortress","ward_mantle"],["star_core","star_core","fortress","ward_mantle","focuser"]]
	if hero=="ranger": return [["iron_blade"],["storm_blade"],["tempest_glaive"],["tempest_glaive","blood_edge"],["tempest_glaive","sanguine"],["tempest_glaive","sanguine","swift_bow"],["tempest_glaive","sanguine","tempest_glaive"],["tempest_glaive","sanguine","tempest_glaive","crit_scope"],["tempest_glaive","sanguine","tempest_glaive","falcon_eye"]]
	return [["iron_blade"],["storm_blade"],["storm_blade","storm_blade"],["storm_blade","storm_blade","guard_armor"],["storm_blade","storm_blade","storm_blade","guard_armor"],["storm_blade","storm_blade","storm_blade","guard_armor","guard_armor"],["storm_blade","storm_blade","storm_blade","fortress","guard_armor"],["tempest_glaive","storm_blade","storm_blade","fortress","guard_armor"],["tempest_glaive","storm_blade","storm_blade","fortress","guard_armor","blood_edge"]]

func _hunt_next_purchase() -> String:
	var m = ui.model
	var route: Array = _hunt_route()
	while hunt_purchase_stage<route.size():
		var counts: Dictionary = {}
		for id in route[hunt_purchase_stage]: counts[id]=int(counts.get(id,0))+1
		for id in counts:
			if m.inventory.count(id)<counts[id]:
				return id if m.get_buy_quote(id).ok else ""
		hunt_purchase_stage+=1
	return ""

func _abort(reason: String):
	errors.append(reason)
	_finish("QA_BLOCKED")

func _finish(outcome: String):
	if not active: return
	_move(Vector2.ZERO)
	active=false
	var m = ui.model
	var result = {"hero":hero,"policy":policy,"controller_revision":CONTROLLER_REVISION,"tempo_version":m.tempo.version,"hunt_decisions":hunt_decisions,"hunt_visits":hunt_visits,"seed":m.seed_value,"source_commit":source_commit,"outcome":outcome,"simulation_seconds":m.elapsed,"wall_seconds":(Time.get_ticks_msec()-wall_start)/1000.0,"base_hp":m.base_hp,"gold":m.gold,"inventory":m.inventory,"metrics":m.metrics,"transitions":transitions,"errors":errors,"input_event_count":event_count,"real_time_scene_processing":true,"realtime_performance_claim":false,"clock":_clock_snapshot(),"no_model_state_or_resource_injection":true,"synthetic_touch_dispatch":true,"physical_touch_test":false}
	var file = FileAccess.open(result_path,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(result,"  ")); file.close()
	print("QA_AUTOPLAY_RESULT ",JSON.stringify(result))
	set_process(false)

func _clock_snapshot() -> Dictionary:
	return ui.clock_metrics() if is_instance_valid(ui) and ui.has_method("clock_metrics") else {"policy":"diagnostics_unavailable"}
