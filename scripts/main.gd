extends Node2D
## Duskward: original, resolution-independent presentation and multitouch interface.
## All gameplay state is owned by SiegeModel; UI never bypasses its transactions.
const Model = preload("res://scripts/siege_model.gd")
const Art = preload("res://scripts/art.gd")
const QAController = preload("res://scripts/qa_autoplay.gd")
const SIZE = Vector2(1280, 720)
const FIXED_STEP_SECONDS = 1.0 / 30.0
const FRAME_DELTA_CAP_SECONDS = 0.15
const MAP = Rect2(0, 40, 1280, 640)
const INK = Color("111615")
const PANEL = Color("1b211e")
const LINE = Color("53584b")
const PAPER = Color("f0e4c8")
const MUTED = Color("b5b9aa")
const GOLD = Color("c6a364")
const TEAL = Color("9ac9ba")
const RED = Color("ed8971")
const BLUE = Color("91b9cf")
const BAR_EMPTY = Color("101710")
const BAR_EDGE = Color("8b9079")
const HP_FILL = Color("576945")
const MANA_FILL = Color("496778")
const CASTLE_FILL = Color("776237")
const DANGER_FILL = Color("99513f")
const OCCLUSION_BACKING_ALPHA = 0.12
const OCCLUSION_INK_ALPHA = 0.45
const OCCLUSION_TEXT_ALPHA = 0.85
const DIAGNOSTIC_FIXTURES = ["corner-lower","corner-upper","left-stick","top-hud"]
const HERO_IDS = ["guardian", "ranger", "arcanist"]
var HERO_NAMES: Dictionary = {}
var HERO_ROLES: Dictionary = {}
var HERO_BLURBS: Dictionary = {}
var SKILL_NAMES: Dictionary = {}
var SKILL_TIPS: Dictionary = {}
var STAT_NAMES: Dictionary = {}
const PERCENT_STATS = ["attack_speed_bonus", "crit_chance", "cooldown_reduction", "lifesteal"]
var copy = preload("res://scripts/ui_copy.gd").new()
var model = Model.new()
var art = Art.new()
var font: Font
var heading_font: Font
var mode: String = "title"
var modal: String = ""
var modal_stack: Array[String] = []
var keyboard_arrows: bool = false
var skill_pointer: Dictionary = {}
var floating_text: Array[Dictionary] = []
var observed_enemy_hp: Dictionary = {}
var base_flash: float = 0.0
var observed_base_hp: float = 6000.0
var observed_hunt_state: String = ""
var observed_hunt_action: String = ""
var siege_cue_seen: bool = false
var boss_cue_seen: bool = false
var coach_title: String = ""
var coach_body: String = ""
var coach_left: float = 0.0
var clock_active_wall: float = 0.0
var clock_active_monotonic: float = 0.0
var clock_admitted: float = 0.0
var clock_dropped: float = 0.0
var clock_steps: int = 0
var clock_step_calls: int = 0
var clock_terminal_noop_steps: int = 0
var clock_menu_pause: float = 0.0
var clock_background_pause: float = 0.0
var clock_title: float = 0.0
var clock_capped_frames: int = 0
var clock_max_delta: float = 0.0
var clock_reset_count: int = 0
var clock_reset_reason: String = "initial"
var clock_reset_discarded: float = 0.0
var clock_model_epoch: float = 0.0
var clock_last_process_usec: int = 0
var clock_last_log_active: float = 0.0
var clock_last_log_dropped: float = 0.0
var clock_background_event_wall: float = 0.0
var clock_background_enter_usec: int = 0
var clock_background: bool = false
var selected_hero: String = "guardian"
var selected_item: String = "iron_blade"
var selected_slot: int = -1
var shop_page: int = 0
var hits: Array[Dictionary] = []
var joystick: Vector2 = Vector2.ZERO
var joystick_id: int = -99
var joystick_center: Vector2 = Vector2(130, 621)
var mouse_joystick: bool = false
var time: float = 0.0
var accumulator: float = 0.0
var toast: String = ""
var toast_time: float = 0.0
var banner: String = ""
var banner_time: float = 0.0
var last_phase: String = ""
var skill_flash: Dictionary = {}
var screen_shake: float = 0.0
var last_hp: float = 0.0
var smoke_stage: String = ""
var smoke_path: String = ""
var smoke_frames: int = 0
var diagnostic_fixture: bool = false
var ui_paint: Vector3 = Vector3.ONE
var paint_regions: Array[Dictionary] = []
var paint_controls: Dictionary = {}
var hover_pos: Vector2 = Vector2(-100, -100)
var help_page: int = 0
var qa_controller: Node = null
var audio: AudioStreamPlayer
var sound_enabled: bool = true

func _ready() -> void:
	_load_copy()
	font = load("res://assets/fonts/Pretendard-Medium.otf") as Font
	heading_font = load("res://assets/fonts/Pretendard-SemiBold.otf") as Font
	model.reset(selected_hero)
	last_phase = model.phase
	clock_last_process_usec = Time.get_ticks_usec()
	_setup_audio()
	var settings: ConfigFile = ConfigFile.new()
	if settings.load("user://duskward_settings.cfg")==OK:
		sound_enabled = bool(settings.get_value("controls","sound",true))
		keyboard_arrows = bool(settings.get_value("controls","arrows",false))
	var qa_request: String = ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-autoplay="):
			qa_request = arg.trim_prefix("--qa-autoplay=")
		if arg.begins_with("--visual-smoke="):
			smoke_stage = arg.trim_prefix("--visual-smoke=")
		if arg.begins_with("--screenshot="):
			smoke_path = arg.trim_prefix("--screenshot=")
	if smoke_stage in DIAGNOSTIC_FIXTURES and not OS.is_debug_build(): smoke_stage=""
	if smoke_stage != "":
		_prepare_smoke(smoke_stage)
	if OS.is_debug_build() and QAController.valid_request(qa_request) and smoke_stage=="":
		var controller = QAController.new()
		if controller.configure(self,qa_request):
			qa_controller = controller
			add_child(controller)
		else:
			controller.free()
	set_process(true)

func _t(key: String, values: Dictionary = {}) -> String:
	return copy.text(key,values)

func _load_copy() -> void:
	for id in HERO_IDS:
		HERO_NAMES[id] = _t("hero."+id+".name")
		HERO_ROLES[id] = _t("hero."+id+".role")
		HERO_BLURBS[id] = _t("hero."+id+".description")
		SKILL_NAMES[id] = []
		SKILL_TIPS[id] = []
		for slot in ["Q","W","E","R"]:
			SKILL_NAMES[id].append(_t("skill."+id+"."+slot+".name"))
			SKILL_TIPS[id].append(_t("skill."+id+"."+slot+".short"))
	for key in ["ad","sp","max_hp","armor","magic_resist","attack_speed_bonus","crit_chance","energy_regen","max_energy","cooldown_reduction","lifesteal","move_speed"]:
		STAT_NAMES[key] = _t("stat."+key)

func _exit_tree() -> void:
	if is_instance_valid(audio):
		audio.stop()
		audio.stream = null
	audio = null

func _process(delta: float) -> void:
	if diagnostic_fixture:
		# Explicit debug screenshot fixture: no simulation, input, save, or QA run.
		smoke_frames += 1
		queue_redraw()
		if smoke_frames==12 and smoke_path!="": _capture_smoke.call_deferred()
		return
	var now_usec: int = Time.get_ticks_usec()
	var monotonic_gap: float = maxf(0,float(now_usec-clock_last_process_usec)/1000000.0) if clock_last_process_usec>0 else 0.0
	clock_last_process_usec = now_usec
	time += delta
	toast_time = maxf(0, toast_time - delta)
	banner_time = maxf(0, banner_time - delta)
	screen_shake = maxf(0, screen_shake - delta * 7)
	base_flash = maxf(0,base_flash-delta)
	for floater in floating_text: floater.life -= delta
	floating_text = floating_text.filter(func(f): return f.life>0)
	for key in skill_flash.keys():
		skill_flash[key] = maxf(0, float(skill_flash[key]) - delta)
	if mode == "game" and modal == "":
		var admitted: float = minf(delta,FRAME_DELTA_CAP_SECONDS)
		clock_active_wall += maxf(0,delta)
		clock_active_monotonic += monotonic_gap
		clock_admitted += admitted
		clock_dropped += maxf(0,delta-admitted)
		clock_max_delta = maxf(clock_max_delta,delta)
		if delta>FRAME_DELTA_CAP_SECONDS: clock_capped_frames += 1
		coach_left = maxf(0,coach_left-admitted)
		accumulator += admitted
		while accumulator >= FIXED_STEP_SECONDS:
			var elapsed_before: float = model.elapsed
			model.step(FIXED_STEP_SECONDS, _movement())
			accumulator -= FIXED_STEP_SECONDS
			clock_step_calls += 1
			if model.elapsed>elapsed_before:
				clock_steps += 1
			else:
				clock_terminal_noop_steps += 1
		if OS.is_debug_build() and clock_active_wall-clock_last_log_active>=5.0 and clock_dropped-clock_last_log_dropped>=0.25:
			print("QA_CLOCK_SLOWDOWN ",JSON.stringify(clock_metrics()))
			clock_last_log_active = clock_active_wall
			clock_last_log_dropped = clock_dropped
		if model.phase != last_phase:
			_phase_changed()
		if model.respawn_left>0 and not skill_pointer.is_empty():
			skill_pointer.clear()
		if model.hp < last_hp:
			screen_shake = 0.55
			_sound(145.0,0.08,0.045)
		last_hp = model.hp
		_update_combat_feedback()
		if model.phase == "Victory" or model.phase == "Defeat":
			_release_controls()
			_sound(740 if model.phase=="Victory" else 155,0.45,0.06)
			modal = "result"
			_invalidate_hits()
	elif clock_background:
		clock_background_pause += maxf(0,delta)
	elif mode=="game":
		clock_menu_pause += maxf(0,delta)
	else:
		clock_title += maxf(0,delta)
	queue_redraw()
	if smoke_stage != "":
		smoke_frames += 1
		if smoke_frames == 12 and smoke_path != "":
			_capture_smoke.call_deferred()

func clock_metrics() -> Dictionary:
	var event_background: float = clock_background_event_wall
	if clock_background and clock_background_enter_usec>0:
		event_background += maxf(0,float(Time.get_ticks_usec()-clock_background_enter_usec)/1000000.0)
	return {
		"policy":"admit_min_delta_150ms_without_backlog_catchup",
		"wall_source":"Godot _process delta; independent monotonic active time is separate",
		"fixed_step_seconds":FIXED_STEP_SECONDS,
		"frame_delta_cap_seconds":FRAME_DELTA_CAP_SECONDS,
		"active_wall_seconds":clock_active_wall,
		"active_monotonic_seconds":clock_active_monotonic,
		"admitted_simulation_seconds":clock_admitted,
		"completed_fixed_steps":clock_steps,
		"fixed_step_calls":clock_step_calls,
		"terminal_noop_steps":clock_terminal_noop_steps,
		"terminal_noop_seconds":clock_terminal_noop_steps*FIXED_STEP_SECONDS,
		"simulated_seconds":maxf(0,model.elapsed-clock_model_epoch),
		"model_elapsed_seconds":maxf(0,model.elapsed-clock_model_epoch),
		"accumulator_seconds":accumulator,
		"dropped_active_seconds":clock_dropped,
		"paused_menu_seconds":clock_menu_pause,
		"paused_background_seconds":clock_background_pause,
		"background_event_wall_seconds":event_background,
		"title_seconds":clock_title,
		"capped_frames":clock_capped_frames,
		"max_active_frame_delta_seconds":clock_max_delta,
		"reset_count":clock_reset_count,
		"reset_reason":clock_reset_reason,
		"discarded_accumulator_seconds":clock_reset_discarded,
		"realtime_performance_claim":false}

func _reset_clock(reason: String) -> void:
	clock_reset_discarded += maxf(0,accumulator)
	clock_reset_count += 1
	clock_reset_reason = reason
	accumulator = 0
	clock_active_wall = 0
	clock_active_monotonic = 0
	clock_admitted = 0
	clock_dropped = 0
	clock_steps = 0
	clock_step_calls = 0
	clock_terminal_noop_steps = 0
	clock_menu_pause = 0
	clock_background_pause = 0
	clock_title = 0
	clock_capped_frames = 0
	clock_max_delta = 0
	clock_model_epoch = model.elapsed
	clock_last_process_usec = Time.get_ticks_usec()
	clock_last_log_active = 0
	clock_last_log_dropped = 0
	clock_background_event_wall = 0
	clock_background_enter_usec = Time.get_ticks_usec() if clock_background else 0

func _capture_smoke() -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var result: Error = img.save_png(smoke_path)
	print("VISUAL_SMOKE ", smoke_stage, " ", smoke_path, " result=", result)
	get_tree().quit(int(result != OK))

func _prepare_smoke(stage: String) -> void:
	# Ordinary smoke traverses normal methods. Corner fixtures explicitly inject
	# a frozen diagnostic state and are restricted to debug builds.
	if stage in DIAGNOSTIC_FIXTURES:
		_prepare_corner_fixture(stage)
		return
	if stage == "title":
		return
	_start_new()
	if stage in ["shop","shop2"]:
		modal = "shop"
		if stage=="shop2":
			shop_page = 1
			selected_item = "crit_scope"
	elif stage == "pause":
		modal = "pause"
	elif stage == "help":
		modal = "help"
	else:
		model.start_next_wave()
		for i in range(300):
			model.step(1.0 / 30.0, Vector2.RIGHT if i < 100 else Vector2.ZERO)
		if stage == "result":
			modal = "result"

func _prepare_corner_fixture(stage: String) -> void:
	if not OS.is_debug_build() or stage not in DIAGNOSTIC_FIXTURES: return
	diagnostic_fixture=true
	set_process_input(false)
	sound_enabled=false
	model.reset("guardian") # reset does not save; this diagnostic is never persisted.
	mode="game"
	modal=""
	modal_stack.clear()
	_release_controls()
	model.phase="Combat"
	model.wave=8
	model.level=12
	model.recalculate_stats()
	model.hp=model.stats.max_hp
	model.energy=model.stats.max_energy
	model.pos={"corner-lower":Vector2(44.2,22.0),"corner-upper":Vector2(44.2,18.3),"left-stick":Vector2(4.875,21.8),"top-hud":Vector2(24,2.5)}[stage]
	model.enemies.clear()
	model.spawn_queue.clear()
	var enemy: Dictionary=model.spawn_enemy("guard",model.pos+Vector2(-1.1,-0.1),false)
	enemy.telegraph=0.7
	enemy.attack_pos=model.pos
	model.hazards=[{"pos":model.pos,"radius":2.2,"warning":0.7,"life":5.0,"damage":30.0,"kind":"debris"}]
	model.cooldowns={"Q":1.2,"W":0.0,"E":3.0,"R":0.0}
	last_phase=model.phase
	banner_time=0
	toast_time=0
	coach_left=0
	queue_redraw()
	print("VISUAL_FIXTURE ",JSON.stringify({"fixture":stage,"state_injected":true,"simulation_frozen":true,"persisted":false,"lawful_match_evidence":false,"hero_world":[model.pos.x,model.pos.y]}))

func _update_combat_feedback() -> void:
	_sync_hunt_presentation()
	if model.base_hp<observed_base_hp:
		base_flash = 0.4
	observed_base_hp = model.base_hp
	var current: Dictionary = {}
	var added: int = 0
	for enemy in model.enemies:
		if str(enemy.kind)=="siege" and not siege_cue_seen:
			siege_cue_seen = true
			_set_coach(_t("combat.siege"),"",8.0)
		var id: int = int(enemy.id)
		var health: float = float(enemy.hp)
		if observed_enemy_hp.has(id):
			var damage: float = float(observed_enemy_hp[id])-health
			if damage>=0.8 and added<8 and floating_text.size()<36:
				floating_text.append({"pos":enemy.pos,"text":"%d" % roundi(damage),"life":0.65,"offset":float(id%3)*8-8})
				added += 1
		current[id] = health
	observed_enemy_hp = current

func _setup_audio() -> void:
	audio = AudioStreamPlayer.new()
	audio.volume_db = -4.0
	add_child(audio)

func _sound(frequency: float = 560.0, duration: float = 0.08, volume: float = 0.055) -> void:
	if not sound_enabled or not is_instance_valid(audio): return
	# Short original PCM cues avoid a permanently running generator/mixer buffer.
	var sample_rate: int = 22050
	var samples: int = maxi(1,int(duration*sample_rate))
	var pcm: PackedByteArray = PackedByteArray()
	pcm.resize(samples*2)
	for i in range(samples):
		var t: float = float(i)/samples
		var envelope: float = minf(1.0,float(i)/110.0)*pow(1.0-t,1.5)
		var sample: float = sin(TAU*frequency*float(i)/sample_rate)*volume*envelope
		pcm.encode_s16(i*2,int(sample*32767))
	var cue: AudioStreamWAV = AudioStreamWAV.new()
	cue.format = AudioStreamWAV.FORMAT_16_BITS
	cue.mix_rate = sample_rate
	cue.data = pcm
	audio.stream = cue
	audio.play()

func _movement() -> Vector2:
	var keyboard: Vector2 = Vector2(float(Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_LEFT)), float(Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_UP)))
	if not keyboard_arrows:
		keyboard += Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var screen_direction: Vector2 = joystick if joystick.length() > 0.05 else keyboard.limit_length()
	# Inverse project input so a diagonal stick points where the hero actually travels.
	var inverse_projected: Vector2 = Vector2(screen_direction.x,screen_direction.y*(MAP.size.x/96.0)/(MAP.size.y/48.0))
	return inverse_projected.normalized()*minf(1.0,screen_direction.length())

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode
		if key == KEY_ESCAPE:
			_go_back()
		elif mode == "game" and modal == "":
			# Avoid overloading W: WASD/1–4 is default, arrows/QWER is selectable.
			if key == KEY_Q or key == KEY_1:
				_cast("Q")
			elif key == KEY_2 or (key == KEY_W and keyboard_arrows):
				_cast("W")
			elif key == KEY_E or key == KEY_3:
				_cast("E")
			elif key == KEY_R or key == KEY_4:
				_cast("R")
			elif key == KEY_SPACE:
				_potion()
			elif key == KEY_B:
				_open_modal("shop")
			elif key == KEY_ENTER and _is_preparation():
				_next_wave()
	elif event is InputEventScreenTouch:
		if event.pressed:
			var slot: String = _skill_at(event.position)
			if slot != "":
				_begin_skill_pointer(event.index,event.position,slot)
			elif mode == "game" and modal == "" and event.position.distance_to(joystick_center) < 100 and joystick_id == -99:
				joystick_id = event.index
				_set_stick(event.position)
			else:
				_press(event.position)
		elif not skill_pointer.is_empty() and int(skill_pointer.id)==event.index:
			_end_skill_pointer(event.position,event.canceled)
		elif event.index == joystick_id:
			joystick_id = -99
			joystick = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if event.index == joystick_id:
			_set_stick(event.position)
		elif not skill_pointer.is_empty() and int(skill_pointer.id)==event.index:
			skill_pointer.position = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if event.pressed:
			var slot: String = _skill_at(event.position)
			if slot != "":
				_begin_skill_pointer(-1,event.position,slot)
			elif mode == "game" and modal == "" and event.position.distance_to(joystick_center) < 100:
				mouse_joystick = true
				_set_stick(event.position)
			else:
				_press(event.position)
		else:
			if not skill_pointer.is_empty() and int(skill_pointer.id)==-1:
				_end_skill_pointer(event.position,false)
			mouse_joystick = false
			joystick = Vector2.ZERO
	elif event is InputEventMouseMotion:
		hover_pos = event.position
		if mouse_joystick:
			_set_stick(event.position)
		elif not skill_pointer.is_empty() and int(skill_pointer.id)==-1:
			skill_pointer.position = event.position

func _notification(what: int) -> void:
	if diagnostic_fixture: return # Already frozen; diagnostic frames never navigate.
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED] and not clock_background:
		clock_background = true
		clock_background_enter_usec = Time.get_ticks_usec()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED] and clock_background:
		clock_background_event_wall += maxf(0,float(Time.get_ticks_usec()-clock_background_enter_usec)/1000000.0)
		clock_background = false
		clock_background_enter_usec = 0
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_release_controls()
		if mode == "game" and modal == "":
			_open_modal("pause")

func _go_back() -> void:
	_release_controls()
	if modal == "result":
		mode = "title"
		modal = ""
		modal_stack.clear()
		_invalidate_hits()
	elif modal != "":
		_close_modal()
	elif mode == "game":
		_open_modal("pause")

func _release_controls() -> void:
	skill_pointer.clear()
	joystick = Vector2.ZERO
	joystick_id = -99
	mouse_joystick = false

func _close_modal() -> void:
	modal = modal_stack.pop_back() if not modal_stack.is_empty() else ""
	_release_controls()
	_invalidate_hits()

func _skill_at(p: Vector2) -> String:
	if mode != "game" or modal != "": return ""
	for hit in hits:
		if str(hit.action)=="skill" and hit.rect.has_point(p): return str(hit.value)
	return ""

func skill_center(slot_or_index: Variant) -> Vector2:
	var index: int = int(slot_or_index) if slot_or_index is int else ["Q","W","E","R"].find(str(slot_or_index))
	index = clampi(index,0,3)
	return Vector2(1056+(index%2)*122,528+(index/2)*110)

func _begin_skill_pointer(id: int, at: Vector2, slot: String) -> void:
	if not skill_pointer.is_empty(): return
	skill_pointer = {"id":id,"slot":slot,"origin":at,"position":at,"center":skill_center(slot)}

func _skill_cancel_rect() -> Rect2:
	if skill_pointer.is_empty(): return Rect2()
	return Rect2(878,506,96,62)

func _aim_range(slot: String) -> float:
	var key: String = model.hero_id+"."+slot
	return float({"guardian.Q":4.0,"guardian.E":6.0,"ranger.Q":14.0,"ranger.W":5.0,"ranger.E":4.0,"arcanist.Q":12.0,"arcanist.E":12.0}.get(key,0.0))

func _skill_target() -> Vector2:
	if skill_pointer.is_empty(): return Vector2.ZERO
	var delta: Vector2 = Vector2(skill_pointer.position)-Vector2(skill_pointer.origin)
	var reach: float = _aim_range(str(skill_pointer.slot))
	if delta.length()<16 or reach==0: return Vector2.ZERO
	var direction: Vector2 = Vector2(delta.x,delta.y*(MAP.size.x/96.0)/(MAP.size.y/48.0)).normalized()
	var directional: bool = model.hero_id+"."+str(skill_pointer.slot) in ["guardian.Q","ranger.Q","ranger.E"]
	var distance: float = reach if directional else reach*clampf(delta.length()/85.0,0,1)
	return model.pos+direction*distance

func _end_skill_pointer(at: Vector2, cancelled: bool) -> void:
	if skill_pointer.is_empty(): return
	skill_pointer.position = at
	var slot: String = str(skill_pointer.slot)
	var aim: Vector2 = _skill_target()
	cancelled = cancelled or _skill_cancel_rect().has_point(at) or not Rect2(Vector2.ZERO,SIZE).has_point(at)
	skill_pointer.clear()
	if not cancelled and modal=="" and mode=="game":
		_cast(slot,aim)

func _set_stick(p: Vector2) -> void:
	var diff: Vector2 = (p - joystick_center) / 61.0
	joystick = Vector2.ZERO if diff.length() < 0.14 else diff.limit_length()

func _press(p: Vector2) -> void:
	for i in range(hits.size() - 1, -1, -1):
		var hit: Dictionary = hits[i]
		if hit.rect.has_point(p):
			_action(str(hit.action), str(hit.get("value", "")))
			return

# Hit targets are a snapshot of the last painted view, never authority to act in
# a new view. Clear them at semantic transitions, without time-based debouncing.
func _invalidate_hits() -> void:
	hits.clear()
	queue_redraw()

func _action_allowed(action: String, value: String) -> bool:
	match action:
		"hero", "start", "continue": return mode == "title" and modal == ""
		"item", "slot", "shop_page", "buy", "sell", "sell_potion": return mode == "game" and modal == "shop"
		"next", "skill", "potion": return mode == "game" and modal == ""
		"hunt_return": return _can_hunt_return()
		"hunt_start": return _can_hunt_start()
		"title", "restart": return mode == "game" and modal in ["pause", "result"]
		"close": return modal in ["shop", "pause", "help", "credits"]
		"sound": return mode == "game" and modal == "pause"
		"keyboard": return modal == "help" and help_page == 0
		"help_page": return modal == "help"
		"modal":
			if mode == "title": return modal == "" and value in ["help", "credits"]
			return (modal == "" and value in ["shop", "help", "pause"]) or (modal == "pause" and value == "help")
	return false

func _shop_quote_signature() -> Dictionary:
	var quote: Dictionary = model.get_buy_quote(selected_item)
	var ingredients: Array[String] = []
	for index in quote.get("consume", []):
		if int(index) >= 0 and int(index) < model.inventory.size():
			ingredients.append(str(model.inventory[int(index)]))
	ingredients.sort()
	return {"cost":quote.get("cost",0), "ingredients":ingredients, "ok":quote.get("ok",false), "reason":quote.get("reason","")}

func _action(action: String, value: String) -> void:
	if not _action_allowed(action,value): return
	_sound()
	match action:
		"hero": selected_hero = value
		"start": _start_new()
		"continue":
			if model.load_checkpoint():
				selected_hero = model.hero_id
				mode = "game"
				modal = ""
				modal_stack.clear()
				_release_controls()
				last_phase = model.phase
				_reset_clock("load")
				observed_hunt_state = str(model.hunt.get("state",""))
				selected_slot = -1
				_select_shop_item(_recommended_item())
				_notify(_t("save.loaded"))
			else:
				_notify(_notice_text(model.notice))
		"modal": _open_modal(value)
		"close": _close_modal()
		"title":
			model.save_checkpoint()
			mode = "title"
			modal = ""
			modal_stack.clear()
			_release_controls()
			_invalidate_hits()
		"restart": _start_new()
		"next": _next_wave()
		"skill": _cast(value)
		"potion": _potion()
		"hunt_start":
			if model.start_hunt():
				_sync_hunt_presentation()
				_invalidate_hits()
		"hunt_return":
			if model.request_hunt_return():
				_release_controls()
				_sync_hunt_presentation()
				_invalidate_hits()
		"shop_page":
			var page: int = clampi(int(value),0,1)
			if page != shop_page:
				shop_page = page
				_invalidate_hits()
		"item":
			_select_shop_item(value)
			selected_slot = -1
		"slot":
			var index: int = int(value)
			if index >= 0 and index < model.inventory.size():
				selected_slot = index
				_select_shop_item(model.inventory[selected_slot])
		"buy":
			if not _is_preparation():
				_notify(_t("shop.not_preparation"))
				return
			var visible_quote: Dictionary = _shop_quote_signature()
			var result: Dictionary = model.buy(selected_item)
			if result.get("ok", false):
				_notify(_t("shop.combined" if not visible_quote.ingredients.is_empty() else "shop.bought",{"item":_item_name(selected_item)}))
				selected_slot = -1
				model.save_checkpoint()
				_sound(820, 0.13)
				# A second tap may reuse an unchanged quote (e.g. another potion),
				# but a consumed recipe must be repainted before another charge.
				if visible_quote != _shop_quote_signature(): _invalidate_hits()
			else:
				_notify(_reason(str(result.get("reason", "구매할 수 없습니다"))))
		"sell_potion":
			if not _is_preparation(): return
			var result: Dictionary = model.sell_potion()
			_notify(_t("shop.potion_sold") if result.get("ok",false) else _reason(str(result.get("reason","판매 불가"))))
			model.save_checkpoint()
			_invalidate_hits()
		"sell":
			if not _is_preparation() or selected_slot < 0:
				return
			var result: Dictionary = model.sell(selected_slot)
			_notify(_t("shop.sell") if result.get("ok", false) else _reason(str(result.get("reason", "판매 불가"))))
			selected_slot = -1
			model.save_checkpoint()
			_invalidate_hits()
		"sound":
			sound_enabled = not sound_enabled
			if not sound_enabled and is_instance_valid(audio): audio.stop()
			_save_settings()
		"keyboard":
			keyboard_arrows = not keyboard_arrows
			_save_settings()
		"help_page":
			var page: int = clampi(int(value),0,3)
			if page != help_page:
				help_page = page
				_invalidate_hits()

func _save_settings() -> void:
	var settings: ConfigFile = ConfigFile.new()
	settings.set_value("controls","sound",sound_enabled)
	settings.set_value("controls","arrows",keyboard_arrows)
	settings.save("user://duskward_settings.cfg")

func _start_new() -> void:
	model.reset(selected_hero)
	_reset_clock("new_game")
	selected_slot = -1
	_select_shop_item("focus_stone" if selected_hero=="arcanist" else "iron_blade")
	floating_text.clear()
	observed_enemy_hp.clear()
	observed_base_hp = model.base_hp
	observed_hunt_state = ""
	observed_hunt_action = ""
	siege_cue_seen = false
	boss_cue_seen = false
	coach_left = 0
	mode = "game"
	modal = ""
	modal_stack.clear()
	_release_controls()
	last_hp = model.hp
	last_phase = model.phase
	banner = _t("banner.start")
	banner_time = 3.0
	model.save_checkpoint()

func _open_modal(value: String) -> void:
	if value == modal:
		return
	modal_stack.append(modal)
	modal = value
	_release_controls()
	model.cancel_cast()
	_invalidate_hits()

func _is_preparation() -> bool:
	return model.phase == "Preparation" or model.phase == "FinalPreparation"

func _next_wave() -> void:
	if model.start_next_wave():
		_sound(270, 0.25, 0.06)
		_phase_changed()

func _phase_changed() -> void:
	_invalidate_hits()
	last_phase = model.phase
	if _is_preparation():
		banner = _t("banner.final_prep") if model.phase == "FinalPreparation" else _t("banner.wave_clear",{"wave":model.completed_wave})
		model.save_checkpoint()
	elif model.phase == "BossIntro" or model.phase == "Boss":
		banner = _t("banner.boss_intro")
		if not boss_cue_seen:
			boss_cue_seen = true
			_set_coach(_t("combat.cannon_intro"),"",8.0)
	else:
		banner = _t("banner.wave_start",{"wave":model.wave})
	banner_time = 2.6

func _cast(slot: String, aim: Vector2 = Vector2.ZERO) -> void:
	if model.cast(slot, aim):
		skill_flash[slot] = 0.32
		_sound(400 + ["Q","W","E","R"].find(slot) * 160, 0.13)
	else:
		var a: Dictionary = model.ability(slot)
		if model.hunt.get("state","")=="returning":
			_notify(_t("hunt.channel_locked"))
		elif model.level < int(a.get("unlock_level", 1)):
			_notify(_t("skill.locked",{"level":int(a.get("unlock_level",1))}))
		elif float(model.cooldowns.get(slot, 0)) > 0:
			_notify(_t("skill.cooling_down"))
		elif model.energy-model.energy_reserved < float(a.get("energy_cost", 0)):
			_notify(_t("skill.no_mana"))
		else:
			_notify(_t("skill.unavailable"))

func _potion() -> void:
	if model.use_potion():
		_notify(_t("potion.used"))
		_sound(720,0.2)
	else:
		var key: String = "potion.unavailable"
		if model.respawn_left>0: key="potion.dead"
		elif model.phase not in ["Combat","Boss"]: key="potion.phase"
		elif model.potions<=0: key="potion.empty"
		elif model.potion_cd>0: key="potion.cooldown"
		elif model.hp>=model.stats.max_hp: key="potion.full_hp"
		_notify(_t(key))

func _notify(message: String) -> void:
	toast = message
	toast_time = 2.8

func _reason(reason: String) -> String:
	if reason=="Forge opens between waves" or reason in ["not_preparation","phase"]: return _t("shop.not_preparation")
	if reason=="Potion reserve full (3)" or reason=="potion_limit": return _t("shop.potion_limit")
	if reason=="All six equipment slots are full" or reason in ["inventory_full","full"]: return _t("shop.inventory_full")
	if reason.begins_with("Need "):
		return _t("shop.gold_shortfall",{"gold":reason.split(" ")[1]})
	if reason in ["insufficient_gold","not_enough_gold","gold"]: return _t("shop.not_enough_gold")
	if reason.begins_with("Unlocks after wave"): return _t("shop.unlock",{"wave":reason.get_slice(" ",3)})
	if reason=="Unknown item": return _t("shop.invalid_item")
	if reason=="Invalid equipment slot": return _t("shop.invalid_slot")
	if reason=="Ready": return _t("shop.buy")
	return reason

func _world(p: Vector2) -> Vector2:
	return MAP.position + Vector2(p.x / 96.0 * MAP.size.x, p.y / 48.0 * MAP.size.y)

func _draw() -> void:
	ui_paint=Vector3.ONE
	paint_regions=_occlusion_regions()
	paint_controls=control_painted_rects()
	hits.clear()
	draw_rect(Rect2(Vector2.ZERO, SIZE), INK)
	if mode == "title":
		_draw_title()
	else:
		_draw_arena()
		_draw_hud()
		_draw_controls()
		_draw_status_strip()
		_draw_minimap()
		if banner_time > 0 and modal == "" and str(_status_content().title)=="":
			var alpha: float = minf(1, banner_time)
			_set_ui_paint(Rect2(425,138,430,46))
			_panel(Rect2(425, 138, 430, 46), Color(0.04,0.10,0.14,alpha * 0.90), Color(0.7,0.6,0.35,alpha))
			_label(banner, Vector2(640, 169), 22, Color(0.96,0.85,0.6,alpha), HORIZONTAL_ALIGNMENT_CENTER)
			ui_paint=Vector3.ONE
	if modal != "":
		draw_rect(Rect2(Vector2.ZERO, SIZE), Color(0.02,0.025,0.02,0.66))
		hits.clear()
		match modal:
			"shop": _draw_shop()
			"pause": _draw_pause()
			"help": _draw_help()
			"credits": _draw_credits()
			"result": _draw_result()
	if toast_time>0 and not (mode=="game" and modal=="" and bool(_status_content().danger)):
		var tw: float = minf(1150,maxf(300,font.get_string_size(toast,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x+48))
		var ty: float = 676 if modal!="" else (486 if mode=="title" else 238)
		_panel(Rect2((1280-tw)/2,ty,tw,36),Color("272e23"),GOLD,4)
		_label(toast,Vector2(640,ty+25),19,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	if is_instance_valid(qa_controller):
		_panel(Rect2(460,682,360,30),Color("30291d"),GOLD,6)
		_label("QA AUTOPLAY · 합성 입력 테스트" if qa_controller.active else "QA AUTOPLAY · 테스트 종료",Vector2(640,703),14,GOLD,HORIZONTAL_ALIGNMENT_CENTER)

	if diagnostic_fixture:
		_panel(Rect2(315,680,650,32),Color("392719"),GOLD,3)
		_label("FIXTURE · 상태 주입 · 플레이 검증 아님",Vector2(640,703),18,PAPER,HORIZONTAL_ALIGNMENT_CENTER)

func control_painted_rects() -> Dictionary:
	var result: Dictionary = {"stick":Rect2(joystick_center-Vector2(68,68),Vector2(136,136)),"potion":Rect2(877,595,86,104),"hud_hero":Rect2(24,22,340,140),"hud_castle":Rect2(424,22,432,100),"hud_boss":Rect2(424,130,432,54),"hud_gold":Rect2(890,22,158,42),"hud_shop":Rect2(1070,22,80,80),"hud_pause":Rect2(1166,22,90,80)}
	for slot in ["Q","W","E","R"]: result[slot]=Rect2(skill_center(slot)-Vector2(50,50),Vector2(100,112))
	return result

func _occlusion_regions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if mode!="game" or modal!="": return result
	if model.respawn_left<=0 and model.hp>0:
		result.append({"rect":art.sprite_bounds(model.hero_id,_world(model.pos),59).grow(4),"source":"hero"})
	for enemy in model.enemies:
		if float(enemy.hp)<=0: continue
		var body: Rect2 = Rect2(_world(enemy.pos)-Vector2(22,22),Vector2(44,44)) if str(enemy.kind)=="weakness" else art.sprite_bounds(str(enemy.kind),_world(enemy.pos),art.enemy_height(str(enemy.kind))).grow(4)
		result.append({"rect":body,"source":"enemy"})
		if float(enemy.get("telegraph",0))>0:
			result.append({"rect":Rect2(_world(enemy.pos)+Vector2(-10,-55),Vector2(20,20)),"source":"enemy_warning"})
			var locked: Vector2 = _world(Vector2(enemy.get("attack_pos",model.pos)))
			var radius: float = (0.8 if str(enemy.kind) in ["siege","shooter"] else 1.8)*MAP.size.x/96.0
			result.append({"rect":Rect2(locked-Vector2.ONE*radius,Vector2.ONE*radius*2).grow(3),"source":"enemy_warning"})
			if str(enemy.kind) in ["siege","shooter"]:
				result.append({"rect":Rect2(_world(enemy.pos),Vector2.ZERO).expand(locked).grow(4),"source":"enemy_warning"})
	for hazard in model.hazards:
		var radius: float = float(hazard.radius)*MAP.size.x/96.0
		result.append({"rect":Rect2(_world(hazard.pos)-Vector2.ONE*radius,Vector2.ONE*radius*2).grow(3),"source":"hazard"})
	if model.boss_pattern_left>0 and model.boss_pattern=="smash":
		var origin: Vector2 = Vector2(model.boss_pattern_data.pos)
		var direction: Vector2 = Vector2(model.boss_pattern_data.dir)
		var bounds: Rect2 = Rect2(_world(origin),Vector2.ZERO)
		for i in range(17): bounds=bounds.expand(_world(origin+direction.rotated(-PI/3+i*TAU/48)*float(model.boss_pattern_data.radius)))
		result.append({"rect":bounds.grow(3),"source":"boss_warning"})
	for shot in model.projectiles:
		if not shot.get("hostile",false): continue
		var point: Vector2 = Vector2(shot.pos)
		# Current/past trail plus100ms directional lookahead avoids a point blink.
		var bounds: Rect2 = Rect2(_world(point),Vector2.ZERO).expand(_world(Vector2(shot.get("previous",point))))
		bounds=bounds.expand(_world(point+Vector2(shot.get("velocity",Vector2.ZERO))*0.1)).grow(maxf(20,float(shot.get("radius",0.3))*MAP.size.x/96.0))
		result.append({"rect":bounds,"source":"hostile_projectile"})
	return result

func _overlap_sources(rect: Rect2, regions: Array[Dictionary]) -> Array[String]:
	var result: Array[String] = []
	for region in regions:
		if rect.intersects(region.rect) and str(region.source) not in result: result.append(str(region.source))
	return result

func occlusion_paint_state() -> Dictionary:
	var regions: Array[Dictionary] = _occlusion_regions()
	var result: Dictionary = {}
	var rectangles: Dictionary = control_painted_rects()
	for id in rectangles:
		var sources: Array[String] = _overlap_sources(rectangles[id],regions)
		var faded: bool = not sources.is_empty()
		result[id]={"rect":rectangles[id],"occluded":faded,"sources":sources,"backing_alpha":OCCLUSION_BACKING_ALPHA if faded else 1.0,"ink_alpha":OCCLUSION_INK_ALPHA if faded else 1.0,"text_alpha":OCCLUSION_TEXT_ALPHA if faded else 1.0}
	return result

func _set_ui_paint(rect: Rect2) -> void:
	ui_paint=Vector3(OCCLUSION_BACKING_ALPHA,OCCLUSION_INK_ALPHA,OCCLUSION_TEXT_ALPHA) if not _overlap_sources(rect,paint_regions).is_empty() else Vector3.ONE

func _ui_fill(color: Color) -> Color:
	return Color(color,color.a*ui_paint.x)

func _ui_ink(color: Color) -> Color:
	return Color(color,color.a*ui_paint.y)

func _font_for_size(size: int) -> Font:
	return heading_font if size>=23 else font

func _label(text: String, at: Vector2, size: int = 18, color: Color = PAPER, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	var face: Font = _font_for_size(size)
	var offset: float = 0
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		offset = face.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x/2
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		offset = face.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	# Backplates carry contrast; do not thicken every small Hangul glyph with an outline.
	draw_string(face,at-Vector2(offset,0),text,HORIZONTAL_ALIGNMENT_LEFT,width,size,Color(color,color.a*ui_paint.z))

func _lines(text: String, at: Vector2, size: int = 18, color: Color = MUTED, spacing: float = 27) -> void:
	var y: float = at.y
	for line in text.split("\n"):
		_label(line, Vector2(at.x,y), size,color)
		y += spacing

func _paragraph(text: String, rect: Rect2, size: int = 20, color: Color = PAPER, spacing: float = 30) -> float:
	var y: float = rect.position.y
	for section in text.split("\n"):
		var line: String = ""
		for word in section.split(" "):
			var test: String = word if line=="" else line+" "+word
			if font.get_string_size(test,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>rect.size.x and line!="":
				_label(line,Vector2(rect.position.x,y),size,color)
				y += spacing
				line = word
			else: line=test
		_label(line,Vector2(rect.position.x,y),size,color)
		y += spacing
	return y-rect.position.y

func _panel(rect: Rect2, color: Color = PANEL, border: Color = LINE, radius: int = 6) -> void:
	var cut: float = minf(8.0,minf(rect.size.x,rect.size.y)*0.18)
	var p: Vector2 = rect.position
	var e: Vector2 = rect.end
	var points: PackedVector2Array = PackedVector2Array([p+Vector2(cut,0),Vector2(e.x-cut,p.y),Vector2(e.x,p.y+cut),e-Vector2(0,cut),e-Vector2(cut,0),Vector2(p.x+cut,e.y),Vector2(p.x,e.y-cut),p+Vector2(0,cut)])
	draw_colored_polygon(points,_ui_fill(color))
	var edge: PackedVector2Array = points.duplicate()
	edge.append(points[0])
	draw_polyline(edge,_ui_ink(border),1.3,true)
	if rect.size.y>35:
		draw_line(p+Vector2(cut+2,2),Vector2(e.x-cut-2,p.y+2),_ui_ink(Color(border,0.35)),1,true)
		draw_line(Vector2(p.x+cut+2,e.y-2),e-Vector2(cut+2,2),_ui_fill(Color(0,0,0,0.35)),2,true)

func _button(rect: Rect2, text: String, action: String, value: String = "", primary: bool = false, enabled: bool = true, size: int = 20) -> void:
	var previous_paint: Vector3 = ui_paint
	_set_ui_paint(rect)
	var bg: Color = Color("494436") if primary else Color("282e29")
	if rect.has_point(hover_pos): bg = bg.lightened(0.08)
	if not enabled: bg = Color("232824")
	_panel(rect,bg,GOLD if primary and enabled else LINE,4)
	if primary and enabled:
		draw_line(rect.position+Vector2(12,rect.size.y-5),rect.end-Vector2(12,5),_ui_ink(GOLD),2,true)
	_label(text,rect.get_center()+Vector2(0,size*0.36),size,PAPER if enabled else MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	hits.append({"rect":rect,"action":action,"value":value})
	ui_paint=previous_paint

func _bar(rect: Rect2, value: float, maximum: float, color: Color, title: String = "", text_size: int = 14) -> void:
	_panel(rect,BAR_EMPTY,BAR_EDGE,5)
	var fill: Rect2 = rect.grow(-3)
	fill.size.x *= clampf(value / maxf(1,maximum), 0, 1)
	if fill.size.x > 0:
		_panel(fill, color, color, 3)
	if title != "":
		var baseline: Vector2 = rect.get_center()+Vector2(0,text_size*0.36)
		_label(title,baseline,text_size,PAPER,HORIZONTAL_ALIGNMENT_CENTER)

func _hero_color(id: String) -> Color:
	return {"guardian":Color("6acccc"),"ranger":Color("a5ce7e"),"arcanist":Color("c3a2eb")}.get(id, TEAL)

func _draw_title() -> void:
	art.backdrop(self,time)
	# A single hero dominates the scene; the roster is a compact new-game choice.
	art.castle(self,Vector2(152,402),1.0,time)
	draw_set_transform(Vector2(358,565),0,Vector2(1,0.25))
	draw_circle(Vector2.ZERO,205,Color(0.025,0.03,0.025,0.5))
	draw_arc(Vector2.ZERO,202,0,TAU,64,Color("75654a"),3,true)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	art.hero(self,Vector2(358,552),selected_hero,Vector2.RIGHT,time,6.0,false)
	_label(_t("app.name"),Vector2(702,144),52,PAPER)
	draw_line(Vector2(702,169),Vector2(1130,169),GOLD,2,true)
	_label(_t("title.subtitle"),Vector2(702,205),21,MUTED)
	_label(_t("title.hero_select"),Vector2(702,254),20,GOLD)
	for i in range(3):
		var id: String = HERO_IDS[i]
		var rect: Rect2 = Rect2(702+i*146,278,132,126)
		var chosen: bool = id==selected_hero
		_panel(rect,Color("373c31") if chosen else Color(0.08,0.1,0.08,0.8),GOLD if chosen else LINE,5)
		art.hero(self,rect.get_center()+Vector2(0,20),id,Vector2.RIGHT,time,1.35,false)
		_label(HERO_NAMES[id],rect.position+Vector2(66,110),22,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		if chosen:
			draw_colored_polygon(PackedVector2Array([rect.position+Vector2(8,8),rect.position+Vector2(24,8),rect.position+Vector2(8,24)]),GOLD)
			draw_line(rect.position+Vector2(16,122),rect.end-Vector2(16,4),GOLD,2,true)
		hits.append({"rect":rect,"action":"hero","value":id})
	_label(HERO_NAMES[selected_hero],Vector2(702,460),38,PAPER)
	_label(HERO_ROLES[selected_hero],Vector2(1130,458),22,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	_paragraph(HERO_BLURBS[selected_hero],Rect2(702,486,430,52),22,MUTED,30)
	var saved: bool = model.has_checkpoint()
	if saved:
		_button(Rect2(702,550,270,82),_t("title.continue"),"continue","",true,true,27)
		_button(Rect2(988,550,144,82),"새 게임","start","",false,true,23)
	else:
		_button(Rect2(702,550,430,82),_t("title.start"),"start","",true,true,28)
	_button(Rect2(702,650,200,52),_t("title.help"),"modal","help",false,true,20)
	_button(Rect2(932,650,200,52),_t("title.credits"),"modal","credits",false,true,20)
	_label(_t("title.offline"),Vector2(56,681),18,MUTED)

func _draw_arena() -> void:
	art.terrain(self, Rect2(Vector2.ZERO,SIZE), time)
	art.castle(self, _world(Vector2(4,12)), model.base_hp / maxf(1,model.max_base_hp), time)
	_draw_hunt_camp()
	_draw_defenders()
	# All combat geometry is projected from model meters, including y perspective.
	_draw_world_disk(model.pos, float(model.stats.get("attack_range",1.8)), Color(0.3,0.8,0.75,0.012), Color(0.4,0.8,0.75,0.13), 1.0)
	for zone in model.pulse_zones:
		_draw_world_disk(zone.pos,float(zone.radius),Color(0.4,0.5,0.9,0.10),Color(0.6,0.7,1,0.5),1.5)
		_draw_world_arc(zone.pos,float(zone.radius),1.0-clampf(float(zone.left),0,1),Color(0.75,0.85,1,0.85),2.5)
	for trap in model.traps:
		_draw_world_disk(trap.pos,float(trap.radius),Color(0.4,0.7,0.3,0.07),Color(0.6,0.85,0.4,0.7),1.5)
		var tp: Vector2 = _world(trap.pos)
		draw_line(tp-Vector2(8,5),tp+Vector2(8,5),TEAL,2,true)
		draw_line(tp+Vector2(-8,5),tp+Vector2(8,-5),TEAL,2,true)
	for hazard in model.hazards:
		var warning: bool = float(hazard.warning)>0
		var hc: Color = Color(0.96,0.27,0.16,0.16 if warning else 0.30)
		_draw_world_disk(hazard.pos,float(hazard.radius),hc,RED,2.5)
		var hpos: Vector2 = _world(hazard.pos)
		if warning: _label("!",hpos+Vector2(0,7),22,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		if not warning:
			for i in range(5):
				var ember: Vector2 = hpos+Vector2(sin(i*7.1)*25,cos(i*4.8)*15-fmod(time*12+i*5,20))
				draw_circle(ember,2.2,Color(1,0.6,0.2,0.6))
	if model.boss_pattern_left>0 and model.boss_pattern=="smash":
		_draw_world_cone(model.boss_pattern_data.pos, model.boss_pattern_data.dir, float(model.boss_pattern_data.radius), PI/3, Color(1,0.2,0.15,0.22), RED)
	elif model.boss_pattern_left>0 and model.boss_pattern=="cannon":
		_draw_world_disk(Vector2(4,12),2.0,Color(1,0.2,0.1,0.12),RED,3)
	for e in model.enemies:
		var p: Vector2 = _world(e.pos)
		var warning: float = float(e.get("telegraph", 0))
		if warning > 0:
			var locked: Vector2 = Vector2(e.get("attack_pos",model.pos))
			if str(e.kind) in ["siege","shooter"]:
				draw_line(p,_world(locked),Color(1,0.32,0.22,0.5),2.0,true)
				_draw_world_disk(locked,0.8,Color(1,0.3,0.2,0.1),RED,1.5)
			else:
				_draw_world_disk(locked,1.8,Color(1,0.25,0.18,0.10),Color(1,0.4,0.3,0.7),1.5)
			draw_circle(p+Vector2(0,-45),9,RED)
			_label("!",p+Vector2(0,-39),15,INK,HORIZONTAL_ALIGNMENT_CENTER)
		if int(e.id)==model.selected_target_id:
			_draw_world_disk(e.pos,float(e.radius)+0.35,Color(0,0,0,0),Color(0.95,0.8,0.35,0.85),1.5)
			var marker: Vector2 = p+Vector2(0,-55)
			draw_colored_polygon(PackedVector2Array([marker+Vector2(-5,-7),marker+Vector2(5,-7),marker]),GOLD)
	for effect in model.effects:
		_draw_effect(effect)
	_draw_aim_preview()
	for e in model.enemies:
		var p: Vector2 = _world(e.pos)
		art.enemy(self,p,str(e.kind),time,float(e.get("telegraph",0))>0)
		var hp: float = float(e.hp)
		var mhp: float = float(e.max_hp)
		if hp < mhp or str(e.kind).contains("boss"):
			_bar(Rect2(p+Vector2(-21,-44),Vector2(42,6)),hp,mhp,RED)
	for shot in model.projectiles:
		var color: Color = RED if shot.get("hostile",false) else (_hero_color(model.hero_id) if model.hero_id == "arcanist" else GOLD)
		var p: Vector2 = _world(shot.pos)
		var direction: Vector2 = Vector2(shot.get("velocity",Vector2.RIGHT)).normalized()
		draw_line(p-direction*17,p,color.darkened(0.4),5,true)
		draw_line(p-direction*8,p,color,3,true)
		draw_circle(p,3.5,color.lightened(0.3))
	var hp: Vector2 = _world(model.pos)
	if model.respawn_left <= 0:
		if model.shield > 0:
			draw_circle(hp+Vector2(0,-12),31,Color(0.3,0.8,1,0.12))
			draw_arc(hp+Vector2(0,-12),31,0,TAU,40,BLUE,2,true)
		art.hero(self,hp,model.hero_id,model.facing,time,1.0,_movement().length()>0.05)
		if model.invulnerable_left>0: _label(_t("hud.invulnerable",{"seconds":_cooldown_text(model.invulnerable_left)}),hp+Vector2(0,-52),16,TEAL,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		draw_arc(hp,24,0,TAU,32,Color("63899a"),2,true)
		_label(_t("hud.respawn",{"seconds":int(ceilf(model.respawn_left))}),hp+Vector2(0,-25),18,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	for floater in floating_text:
		var location: Vector2 = _world(floater.pos)+Vector2(float(floater.offset),-45-(0.65-float(floater.life))*42)
		_label(floater.text,location+Vector2(1,1),16,Color(0.03,0.07,0.09,float(floater.life)/0.65),HORIZONTAL_ALIGNMENT_CENTER)
		_label(floater.text,location,16,Color(GOLD,minf(1,float(floater.life)*3)),HORIZONTAL_ALIGNMENT_CENTER)
	_draw_player_marker()
	if model.hp / maxf(1,float(model.stats.get("max_hp",1)))<0.25 and model.respawn_left<=0:
		draw_rect(MAP,Color(0.95,0.2,0.1,0.2+sin(time*5)*0.08),false,4)

# Decorative screen-space tracking ring, not a combat range indicator. It is
# drawn above units/effects while boss HUD text remains in the foreground.
func player_marker_geometry() -> Dictionary:
	var radii: Vector2 = Vector2(18,7)
	var margin: Vector2 = radii+Vector2(3,3)
	# Sprite anchor is83% of its height: the ellipse contacts the boot bottoms.
	var center: Vector2 = _world(model.pos)+Vector2(0,7)
	center.x = clampf(center.x,MAP.position.x+margin.x,MAP.end.x-margin.x)
	center.y = clampf(center.y,MAP.position.y+margin.y,MAP.end.y-margin.y)
	return {"visible":mode=="game" and model.respawn_left<=0,"center":center,"radius":radii.x,"radii":radii,"shape":"ground_ellipse","bounds":Rect2(center-margin,margin*2)}

func _draw_player_marker() -> void:
	var marker: Dictionary = player_marker_geometry()
	if not marker.visible: return
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(33): points.append(marker.center+Vector2.from_angle(TAU*i/32.0)*marker.radii)
	draw_polyline(points,Color(0.025,0.035,0.02,0.85),3.0,true)
	draw_polyline(points,Color(0.90,0.89,0.74,0.90),1.35,true)

func _draw_aim_preview() -> void:
	if skill_pointer.is_empty(): return
	var target: Vector2 = _skill_target()
	if target==Vector2.ZERO: return
	var direction: Vector2 = (target-model.pos).normalized()
	var key: String = model.hero_id+"."+str(skill_pointer.slot)
	var fill: Color = Color(0.4,0.85,0.9,0.12)
	var border: Color = Color(0.65,0.96,1,0.9)
	match key:
		"guardian.Q": _draw_world_cone(model.pos,direction,4.0,PI/4,fill,border)
		"guardian.E":
			target = Vector2(clampf(target.x,2,47),clampf(target.y,2,22))
			draw_line(_world(model.pos),_world(target),border,3,true)
			_draw_world_disk(target,2.5,fill,border)
		"ranger.Q":
			var side: Vector2 = Vector2(-direction.y,direction.x)*0.75
			var end: Vector2 = model.pos+direction*14
			var corners: PackedVector2Array = PackedVector2Array([_world(model.pos-side),_world(model.pos+side),_world(end+side),_world(end-side),_world(model.pos-side)])
			draw_colored_polygon(corners.slice(0,corners.size()-1),fill)
			draw_polyline(corners,border,2,true)
		"ranger.W":
			target = Vector2(clampf(target.x,2,47),clampf(target.y,2,22))
			_draw_world_disk(target,3,fill,border)
		"ranger.E":
			target = model.pos-direction*4
			target = Vector2(clampf(target.x,2,47),clampf(target.y,2,22))
			draw_line(_world(model.pos),_world(target),border,3,true)
			_draw_world_disk(target,0.65,fill,border)
			_label("후퇴",_world(target)+Vector2(0,-20),13,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		"arcanist.Q": _draw_world_disk(target,3.5,fill,border)
		"arcanist.E": _draw_world_disk(target,4.0,fill,border)
	var at: Vector2 = _world(target)
	draw_line(at-Vector2(7,0),at+Vector2(7,0),border,2,true)
	draw_line(at-Vector2(0,5),at+Vector2(0,5),border,2,true)

func _boss_pattern_name(pattern: String) -> String:
	return _t("boss.pattern."+pattern)

func _draw_world_arc(center: Vector2, radius: float, progress: float, color: Color, thickness: float = 2.0) -> void:
	if progress<0.01: return
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(33):
		points.append(_world(center+Vector2.from_angle(-PI/2+TAU*progress*i/32.0)*radius))
	draw_polyline(points,color,thickness,true)

func _draw_world_disk(center: Vector2, radius: float, fill: Color, border: Color, thickness: float = 2.0) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(49):
		points.append(_world(center+Vector2.from_angle(i*TAU/48.0)*radius))
	if fill.a>0:
		draw_colored_polygon(points.slice(0,points.size()-1),fill)
	if border.a>0:
		draw_polyline(points,border,thickness,true)

func _draw_world_cone(center: Vector2, direction: Vector2, radius: float, half_angle: float, fill: Color, border: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([_world(center)])
	for i in range(33):
		points.append(_world(center+Vector2.from_angle(direction.angle()-half_angle+2*half_angle*i/32.0)*radius))
	points.append(_world(center))
	draw_colored_polygon(points.slice(0,points.size()-1),fill)
	draw_polyline(points,border,2.0,true)
	for i in range(1,6):
		var dir: Vector2 = Vector2.from_angle(direction.angle()-half_angle+2*half_angle*i/6)
		draw_line(_world(center+dir*0.5),_world(center+dir*radius),Color(border,0.25),1,true)

func _draw_effect(effect: Dictionary) -> void:
	var center: Vector2 = Vector2(effect.get("pos",Vector2.ZERO))
	var pos: Vector2 = _world(center)
	var life: float = float(effect.get("life",0.2))
	var maximum: float = maxf(0.1,float(effect.get("max_life",0.4)))
	var progress: float = 1.0-clampf(life/maximum,0,1)
	var kind: String = str(effect.get("kind","hit"))
	var radius: float = maxf(0.4,float(effect.get("radius",1)))
	var color: Color = _hero_color(model.hero_id)
	if kind.contains("enemy") or kind in ["smash","base_hit","cannon"]:
		color = RED
	elif kind.contains("heal"):
		color = TEAL
	elif kind in ["hit","slash","cleave","spark"]:
		color = GOLD
	color.a = maxf(0.15,1.0-progress)
	var fill: Color = Color(color,color.a*0.13)
	var direction: Vector2 = Vector2(effect.get("dir",model.facing))
	if kind in ["slash","cleave","enemy_slash","smash"]:
		_draw_world_cone(center,direction,radius,PI/3 if kind=="smash" else PI/4,fill,color)
	elif kind in ["pierce","dash"]:
		var endpoint: Vector2 = _world(center+direction*radius)
		draw_line(pos,endpoint,Color(color,0.2),17*(1-progress)+3,true)
		draw_line(pos,endpoint,color,4*(1-progress)+1,true)
	elif kind in ["hit","spark","death"]:
		for i in range(6):
			var dir: Vector2 = Vector2.from_angle(float(i)*TAU/6+progress)
			draw_line(pos+dir*progress*15,pos+dir*(8+progress*24),color,2,true)
	else:
		_draw_world_disk(center,radius*(0.7+progress*0.3),fill,color,2.5)


func lane_remaining_count() -> int:
	return model.main_enemy_count()+model.spawn_queue.size()

func support_help_values() -> Dictionary:
	var hunt_rules: Dictionary = model.tempo.hunt
	var waves: Array[String] = []
	for wave in hunt_rules.waves: waves.append(str(int(wave)))
	var count: int = 0
	for amount in hunt_rules.enemy_counts.values(): count += int(amount)
	return {"count":count,"waves":"·".join(waves),"seconds":int(hunt_rules.window_seconds),"gold":int(hunt_rules.gold_reward),"xp":int(hunt_rules.xp_reward),"return_seconds":int(hunt_rules.return_seconds),"emergency_percent":roundi(float(hunt_rules.emergency_castle_ratio)*100),"entry_percent":roundi(float(hunt_rules.min_castle_ratio)*100),"respawn_seconds":int(model.tempo.defenders.respawn_seconds)}

func _can_hunt_start() -> bool:
	return mode=="game" and modal=="" and model.phase=="Combat" and model.hp>0 and model.respawn_left<=0 and model.can_start_hunt()

func _can_hunt_return() -> bool:
	return mode=="game" and modal=="" and model.phase=="Combat" and model.hp>0 and model.respawn_left<=0 and model.hunt.get("state","") in ["active","cleared"]

func hunt_summary() -> Dictionary:
	var state: String = str(model.hunt.get("state",""))
	var rules: Dictionary = model.tempo.hunt
	var visible: bool = mode=="game" and model.phase=="Combat" and state in ["available","active","cleared","returning"]
	var emergency: bool = model.base_hp/maxf(1,model.max_base_hp)<=float(rules.emergency_castle_ratio)
	var blocked: bool = state=="available" and model.base_hp/maxf(1,model.max_base_hp)<=float(rules.min_castle_ratio)
	var values: Dictionary = support_help_values()
	var title: String = _t("hunt."+state) if visible else ""
	var detail: String = ""
	if state=="available": title=_t("hunt.offer_title",values)
	if state=="available": detail=_t("hunt.entry_blocked",values) if blocked else _t("hunt.offer_detail",values)
	elif state=="active": detail=_t("hunt.time_left",{"seconds":int(ceilf(maxf(0,float(model.hunt.get("time_left",0)))) )})
	elif state=="cleared": detail=_t("hunt.reward",values)
	elif state=="returning": detail=_t("hunt.return_progress",{"seconds":"%.1f" % maxf(0,float(model.hunt.get("return_left",0)))})
	var return_hint_key: String = "hunt.emergency_hint" if emergency else "hunt.return_hint"
	if state=="active": return_hint_key="hunt.abandon_emergency_hint" if emergency else "hunt.abandon_hint"
	return {"return_hint":_t(return_hint_key,values),"state":state,"visible":visible,"pos":Vector2(model.hunt.get("pos",Vector2.ZERO)),"radius":float(rules.activation_radius),"title":title,"detail":detail,"emergency":emergency,"entry_blocked":blocked,"can_start":_can_hunt_start(),"can_return":_can_hunt_return(),"return_rect":Rect2(350,600,280,78)}

func _sync_hunt_presentation() -> void:
	var state: String = str(model.hunt.get("state",""))
	var action: String = "start" if _can_hunt_start() else ("return" if _can_hunt_return() else "")
	if state!=observed_hunt_state or action!=observed_hunt_action:
		_invalidate_hits()
	observed_hunt_action=action
	if state==observed_hunt_state: return
	observed_hunt_state=state
	if state=="available": _set_coach(_t("hunt.optional_risk"),"",5.0)
	elif state=="active": _set_coach(_t("hunt.battle_continues"),"",4.0)
	elif state=="cleared": _notify(_t("hunt.reward",support_help_values()))
	elif state=="closed" and model.hunt.get("outcome","")=="timeout": _notify(_t("hunt.timeout"))

func _draw_hunt_camp() -> void:
	var summary: Dictionary = hunt_summary()
	if not summary.visible: return
	var p: Vector2 = _world(summary.pos)
	# Dashed brass boundary marks approach range, not automatic entry or danger.
	for i in range(12):
		var start: float = TAU*i/12.0
		var points: PackedVector2Array = PackedVector2Array()
		for j in range(5): points.append(_world(summary.pos+Vector2.from_angle(start+j*0.065)*summary.radius))
		draw_polyline(points,Color(GOLD,0.65),1.5,true)
	draw_line(p+Vector2(0,-12),p+Vector2(0,-40),Color("191d17"),5,true)
	draw_line(p+Vector2(0,-12),p+Vector2(0,-40),GOLD,2,true)
	draw_colored_polygon(PackedVector2Array([p+Vector2(1,-39),p+Vector2(24,-34),p+Vector2(1,-26)]),GOLD)
	var panel: Rect2 = Rect2(p+Vector2(82,-8),Vector2(310,78))
	_panel(panel,Color(0.06,0.08,0.06,0.92),LINE,4)
	_label(str(summary.title),panel.position+Vector2(14,28),22,GOLD)
	_label(str(summary.detail),panel.position+Vector2(14,59),19,PAPER)

func _draw_hunt_return() -> void:
	var summary: Dictionary = hunt_summary()
	if summary.can_start:
		_button(summary.return_rect,_t("hunt.start"),"hunt_start","",true,true,24)
		_label(_t("hunt.start_risk"),Vector2(490,588),19,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	elif summary.can_return:
		_button(summary.return_rect,_t("hunt.emergency_return" if summary.emergency else "hunt.return"),"hunt_return","",true,true,24)
		_label(str(summary.return_hint),Vector2(490,588),19,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	elif summary.visible and summary.state=="returning":
		_set_ui_paint(summary.return_rect)
		_panel(summary.return_rect,Color(0.07,0.09,0.07,0.92),GOLD,4)
		_label(str(summary.detail),summary.return_rect.get_center()+Vector2(0,-4),24,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		_label(_t("hunt.unsafe"),summary.return_rect.get_center()+Vector2(0,26),18,RED,HORIZONTAL_ALIGNMENT_CENTER)
	ui_paint=Vector3.ONE

func _draw_defenders() -> void:
	for defender in model.defenders:
		var p: Vector2 = _world(defender.pos)
		var alive: bool = float(defender.hp)>0 and float(defender.respawn_left)<=0
		art.defender(self,p,alive,float(defender.flash)>0)
		if alive:
			_bar(Rect2(p+Vector2(-21,-49),Vector2(42,8)),float(defender.hp),float(defender.max_hp),BLUE)
		else:
			_panel(Rect2(p+Vector2(-38,-41),Vector2(76,25)),Color(0.04,0.06,0.05,0.92),LINE,2)
			_label(_t("defender.respawn",{"seconds":int(ceilf(float(defender.respawn_left)))}),p+Vector2(0,-22),17,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	for ally in model.allies:
		var p: Vector2 = _world(ally.pos)
		var alive: bool = float(ally.hp)>0 and float(ally.respawn_left)<=0
		art.hero(self,p,ally.hero,Vector2.RIGHT,time,0.8,false,1.0)
		if alive:
			_bar(Rect2(p+Vector2(-21,-49),Vector2(42,8)),float(ally.hp),float(ally.max_hp),TEAL)

func _draw_minimap() -> void:
	var mm_rect = Rect2(1080, 50, 180, 120)
	_panel(mm_rect, Color(0.06,0.08,0.06,0.85), LINE, 3)
	# 맵 경계
	draw_rect(Rect2(mm_rect.position + Vector2(5,5), mm_rect.size - Vector2(10,10)), Color(0.15,0.2,0.15,0.3), false, 1)
	# 적 표시
	for e in model.enemies:
		var mx: float = mm_rect.position.x + 5 + (e.pos.x / 96.0) * (mm_rect.size.x - 10)
		var my: float = mm_rect.position.y + 5 + (e.pos.y / 48.0) * (mm_rect.size.y - 10)
		draw_circle(Vector2(mx,my), 2.0, RED)
	# 동료 표시
	for ally in model.allies:
		var ax: float = mm_rect.position.x + 5 + (ally.pos.x / 96.0) * (mm_rect.size.x - 10)
		var ay: float = mm_rect.position.y + 5 + (ally.pos.y / 48.0) * (mm_rect.size.y - 10)
		draw_circle(Vector2(ax,ay), 2.5, TEAL)
	# 영웅 표시
	var hx: float = mm_rect.position.x + 5 + (model.pos.x / 96.0) * (mm_rect.size.x - 10)
	var hy: float = mm_rect.position.y + 5 + (model.pos.y / 48.0) * (mm_rect.size.y - 10)
	draw_circle(Vector2(hx,hy), 3.0, GOLD)
	# 베이스 표시
	var bx: float = mm_rect.position.x + 5 + (4.0 / 96.0) * (mm_rect.size.x - 10)
	var by: float = mm_rect.position.y + 5 + (12.0 / 48.0) * (mm_rect.size.y - 10)
	draw_circle(Vector2(bx,by), 3.0, Color(0.9,0.7,0.3))
func _notice_text(notice: String) -> String:
	var key: String = copy.notice_key(notice)
	if key!="": return _t(key,{"seconds":_cooldown_text(model.boss_pattern_left)})
	if notice.begins_with("WAVE "): return _t("banner.wave_clear",{"wave":model.completed_wave}) if notice.contains("CLEAR") else _t("banner.wave_start",{"wave":model.wave})
	if notice.begins_with("LEVEL "): return _t("banner.level_up",{"level":model.level})
	if notice.begins_with("Fallen "): return _t("combat.respawn",{"seconds":int(ceilf(model.respawn_left))})
	if notice.begins_with("Forged "):
		var legacy: String = notice.trim_prefix("Forged ")
		for id in model.items:
			if str(model.items[id].get("name_ko",""))==legacy: return _t("shop.bought",{"item":_item_name(id)})
		return _t("shop.buy")
	if notice.begins_with("Sold "): return _t("shop.sell")
	if notice.contains("unlocks at level"): return _t("skill.unavailable")
	return _reason(notice)

func _draw_hud() -> void:
	_set_ui_paint(paint_controls.hud_hero)
	_panel(Rect2(24,22,340,108),Color(0.065,0.08,0.065,0.92),LINE,5)
	art.hero(self,Vector2(66,94),model.hero_id,Vector2.RIGHT,time,1.0,false,ui_paint.x)
	_label(HERO_NAMES[model.hero_id],Vector2(108,46),22,PAPER)
	_label(_t("common.level",{"level":model.level}),Vector2(344,46),18,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	_bar(Rect2(108,56,236,25),model.hp,float(model.stats.max_hp),HP_FILL,"HP %d / %d" % [model.hp,model.stats.max_hp],19)
	_bar(Rect2(108,92,236,24),model.energy,float(model.stats.max_energy),MANA_FILL,_t("hud.mana_value",{"current":int(model.energy),"max":int(model.stats.max_energy)}),18)
	if model.shield>0:
		_label(_t("hud.shield",{"shield":int(model.shield)}),Vector2(34,154),18,BLUE)
	_set_ui_paint(paint_controls.hud_castle)
	_panel(Rect2(424,22,432,100),Color(0.065,0.08,0.065,0.90),LINE,5)
	_label(_t("hud.initial_wave") if model.wave==0 and _is_preparation() else (_t("hud.boss") if model.phase in ["Boss","BossIntro","FinalPreparation"] else _t("hud.wave",{"wave":model.wave})),Vector2(640,49),23,GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	_bar(Rect2(442,63,396,27),model.base_hp,model.max_base_hp,DANGER_FILL if base_flash>0 else CASTLE_FILL,"%s  %d / %d" % [_t("hud.castle_hp"),maxi(0,int(model.base_hp)),model.max_base_hp],19)
	if model.phase=="Combat":
		_label(_t("hud.enemy_count",{"count":lane_remaining_count()}),Vector2(640,113),18,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		_label(_phase_label(),Vector2(640,113),18,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	_set_ui_paint(paint_controls.hud_gold)
	_label(_t("hud.gold",{"gold":model.gold}),Vector2(1048,55),26,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	ui_paint=Vector3.ONE
	_button(Rect2(1070,22,80,80),_t("common.shop"),"modal","shop",false,true,21)
	_button(Rect2(1166,22,90,80),"","modal","pause")
	_set_ui_paint(paint_controls.hud_pause)
	draw_rect(Rect2(1198,47,6,30),_ui_ink(PAPER))
	draw_rect(Rect2(1217,47,6,30),_ui_ink(PAPER))
	ui_paint=Vector3.ONE
	for enemy in model.enemies:
		if str(enemy.kind)=="boss":
			_set_ui_paint(paint_controls.hud_boss)
			_panel(Rect2(424,130,432,54),Color(0.09,0.06,0.05,0.93),Color("765047"),4)
			_label(_t("enemy.boss.name"),Vector2(640,151),18,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
			_bar(Rect2(442,158,396,18),float(enemy.hp),float(enemy.max_hp),DANGER_FILL,"%d / %d" % [enemy.hp,enemy.max_hp],15)

	ui_paint=Vector3.ONE

func _phase_label() -> String:
	return _t("phase."+model.phase)

func _set_coach(title: String, body: String, duration: float) -> void:
	coach_title = title
	coach_body = body
	coach_left = duration

func _status_content() -> Dictionary:
	if model.boss_pattern_left>0:
		match model.boss_pattern:
			"cannon": return {"title":_t("combat.cannon",{"seconds":_cooldown_text(model.boss_pattern_left)}),"body":"","danger":true}
			"smash": return {"title":_t("combat.smash"),"body":"","danger":true}
			"debris": return {"title":_t("combat.debris"),"body":"","danger":true}
	if model.respawn_left>0:
		return {"title":_t("combat.respawn",{"seconds":int(ceilf(model.respawn_left))}),"body":"","danger":true}
	if not model.hazards.is_empty():
		return {"title":_t("combat.hazard"),"body":"","danger":true}
	if not skill_pointer.is_empty():
		return {"title":_t("combat.aim"),"body":"","danger":false}
	if coach_left>0:
		return {"title":coach_title,"body":"","danger":false}
	if _is_preparation() and model.wave==0:
		return {"title":_t("combat.first_move" if fmod(time,8)<4 else "combat.first_skill"),"body":"","danger":false}
	return {"title":"","body":"","danger":false}

func _draw_status_strip() -> void:
	var status: Dictionary = _status_content()
	if str(status.title)=="": return
	var danger: bool = bool(status.danger)
	var width: float = minf(900,maxf(420,font.get_string_size(str(status.title),HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+48))
	var y: float = 188 if model.phase in ["Boss","BossIntro"] else (526 if _is_preparation() else 140)
	_set_ui_paint(Rect2(640-width/2,y,width,46))
	_panel(Rect2(640-width/2,y,width,46),Color(0.24,0.10,0.07,0.94) if danger else Color(0.08,0.10,0.08,0.88),RED if danger else LINE,4)
	_label(str(status.title),Vector2(640,y+31),22,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	ui_paint=Vector3.ONE

func _draw_controls() -> void:
	var stick: Vector2 = joystick_center
	_set_ui_paint(paint_controls.stick)
	draw_circle(stick,66,_ui_fill(Color(0.025,0.03,0.025,0.68)))
	draw_arc(stick,64,0,TAU,48,_ui_ink(Color("888470")),2,true)
	draw_arc(stick,45,0,TAU,40,_ui_ink(Color(0.7,0.67,0.55,0.3)),1,true)
	for dir in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
		draw_line(stick+dir*53,stick+dir*59,_ui_ink(GOLD),2,true)
	draw_circle(stick+joystick*42,25,_ui_fill(Color("252d25")))
	draw_circle(stick+joystick*42,20,_ui_fill(Color("848777")))
	draw_arc(stick+joystick*42,21,0,TAU,32,_ui_ink(PAPER),1.5,true)
	ui_paint=Vector3.ONE
	if _is_preparation():
		var key: String = "prep.boss_start" if model.phase=="FinalPreparation" else ("prep.first_start" if model.wave==0 else "prep.next_start")
		_button(Rect2(350,598,280,80),_t(key),"next","",true,true,25)
		_button(Rect2(646,598,170,80),_t("common.shop"),"modal","shop",false,true,23)
		if model.prep_left>0:
			_label(_t("prep.boss_countdown" if model.phase=="FinalPreparation" else "prep.countdown",{"seconds":int(ceilf(model.prep_left))}),Vector2(584,584),20,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	_draw_hunt_return()
	for i in range(4):
		var slot: String = ["Q","W","E","R"][i]
		var center: Vector2 = skill_center(i)
		_set_ui_paint(paint_controls[slot])
		var ability: Dictionary = model.ability(slot)
		var unlocked: bool = model.level>=int(ability.get("unlock_level",1))
		var cd: float = float(model.cooldowns.get(slot,0))
		var enough_mana: bool = model.energy-model.energy_reserved>=float(ability.get("energy_cost",0))
		var can_cast: bool = unlocked and cd<=0 and enough_mana and model.respawn_left<=0 and model.phase in ["Combat","Boss"] and model.hunt.get("state","")!="returning"
		var accent: Color = GOLD if i==3 else PAPER
		draw_circle(center,47,_ui_fill(Color(0.035,0.04,0.03,0.94)))
		draw_arc(center,46,0,TAU,48,_ui_ink(GOLD if can_cast else Color("676a59")),3,true)
		draw_arc(center,41,0,TAU,48,_ui_ink(Color("555545")),1,true)
		if cd>0:
			_draw_cooldown_sector(center,40,clampf(cd/maxf(1,float(ability.get("cooldown_seconds",1))),0,1))
		# Emblem is drawn AFTER the sweep: state never erases skill identity.
		art.skill_icon(self,center+Vector2(0,-9),i,_ui_ink(accent if unlocked else Color("8e9183")),model.hero_id)
		if cd>0 or not unlocked:
			var label: String = _cooldown_text(cd) if cd>0 else "Lv.%d" % int(ability.get("unlock_level",1))
			_panel(Rect2(center+Vector2(-31,13),Vector2(62,23)),Color("151b17"),LINE,2)
			_label(label,center+Vector2(0,31),20,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		elif not enough_mana:
			draw_colored_polygon(PackedVector2Array([center+Vector2(28,20),center+Vector2(36,33),center+Vector2(20,33)]),Color(BLUE,ui_paint.z))
			_label("!",center+Vector2(28,31),13,INK,HORIZONTAL_ALIGNMENT_CENTER)
		if float(skill_flash.get(slot,0))>0: draw_arc(center,49,0,TAU,48,_ui_ink(PAPER),3,true)
		_panel(Rect2(center+Vector2(-49,37),Vector2(98,24)),Color("121912"),LINE,2)
		_label(SKILL_NAMES[model.hero_id][i],center+Vector2(0,56),20,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		hits.append({"rect":Rect2(center-Vector2(49,49),Vector2(98,110)),"action":"skill","value":slot})
	ui_paint=Vector3.ONE
	if not skill_pointer.is_empty():
		var cancel: Rect2 = _skill_cancel_rect()
		_set_ui_paint(cancel)
		_panel(cancel,Color("673d32") if cancel.has_point(skill_pointer.position) else Color("252b25"),RED,4)
		_label(_t("common.cancel"),cancel.get_center()+Vector2(0,8),22,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
		draw_arc(skill_pointer.center,49,0,TAU,48,_ui_ink(PAPER),3,true)
	var potion: Vector2 = Vector2(920,638)
	_set_ui_paint(paint_controls.potion)
	draw_circle(potion,40,_ui_fill(Color(0.035,0.04,0.03,0.92)))
	draw_arc(potion,40,0,TAU,40,_ui_ink(GOLD if model.potions>0 else LINE),2,true)
	if model.potion_cd>0: _draw_cooldown_sector(potion,36,model.potion_cd/30.0)
	art.potion_icon(self,potion+Vector2(0,-5),_ui_ink(TEAL),ui_paint.x)
	_label(_cooldown_text(model.potion_cd) if model.potion_cd>0 else "×%d" % model.potions,potion+Vector2(0,32),19,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	_panel(Rect2(potion+Vector2(-43,37),Vector2(86,24)),Color("121912"),LINE,2)
	_label(_t("hud.potion"),potion+Vector2(0,56),20,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	hits.append({"rect":Rect2(potion-Vector2(43,43),Vector2(86,104)),"action":"potion"})

	ui_paint=Vector3.ONE

func _cooldown_text(seconds: float) -> String:
	return "%.1f" % maxf(0,seconds) if seconds<1 else str(int(ceilf(seconds)))

func _draw_cooldown_sector(center: Vector2, radius: float, progress: float) -> void:
	if progress<=0: return
	var points: PackedVector2Array = PackedVector2Array([center])
	var segments: int = maxi(2,int(ceilf(progress*40)))
	for i in range(segments+1):
		points.append(center+Vector2.from_angle(-PI/2+TAU*minf(progress,0.9999)*i/segments)*radius)
	draw_colored_polygon(points,_ui_fill(Color(0.42,0.43,0.36,0.34)))
	draw_arc(center,radius+5,-PI/2,-PI/2+TAU*progress,40,_ui_ink(GOLD),3,true)

func _item_name(id: String) -> String:
	return _t("item."+id+".name") if copy.strings.has("item."+id+".name") else _t("shop.invalid_item")

func _stats_text(item: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for key in item.get("stats",{}):
		var value: float = float(item.stats[key])
		var number: String = "%d%%" % roundi(value*100) if key in PERCENT_STATS else ("%d" % int(value) if is_equal_approx(value,float(int(value))) else "%.1f" % value)
		result.append("%s +%s" % [STAT_NAMES.get(key,key),number])
	return result

func _recommended_item() -> String:
	var owned: Array = model.inventory
	if model.hero_id=="guardian":
		if not owned.has("tempest_glaive"):
			if not owned.has("storm_blade"):
				return "iron_blade" if not owned.has("iron_blade") and model.completed_wave<2 else "storm_blade"
			return "tempest_glaive"
		if not owned.has("fortress"):
			return "guard_armor" if not owned.has("guard_armor") else "fortress"
		if not owned.has("guard_armor"): return "guard_armor"
	elif model.hero_id=="ranger":
		if not owned.has("falcon_eye"):
			if not owned.has("crit_scope"):
				return "iron_blade" if not owned.has("iron_blade") and model.completed_wave<2 else "crit_scope"
			return "falcon_eye"
		if not owned.has("tempest_glaive"):
			return "storm_blade" if not owned.has("storm_blade") else "tempest_glaive"
		if not owned.has("swift_bow"): return "swift_bow"
	else:
		if not owned.has("star_core"):
			if not owned.has("focuser"):
				return "focus_stone" if not owned.has("focus_stone") and model.completed_wave<2 else "focuser"
			return "star_core"
		if not owned.has("sanctuary"):
			return "ward_mantle" if not owned.has("ward_mantle") else "sanctuary"
		if not owned.has("focuser"): return "focuser"
	return "healing_potion" if model.potions<3 else ("focus_stone" if model.hero_id=="arcanist" else "iron_blade")

func _select_shop_item(id: String) -> void:
	_invalidate_hits()
	selected_item = id
	var catalog: Array = model.data.get("items",[])
	for i in range(catalog.size()):
		if str(catalog[i].id)==id:
			shop_page = i/12
			return

func _draw_shop() -> void:
	_panel(Rect2(28,24,1224,672),Color("191f1b"),GOLD,6)
	_label(_t("shop.title"),Vector2(58,76),34,PAPER)
	_label(_t("shop.paused"),Vector2(170,74),18,MUTED)
	_label(_t("common.gold_value",{"gold":model.gold}),Vector2(1068,74),28,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	_button(Rect2(1100,40,120,64),_t("common.close"),"close","",false,true,21)
	var recommended: String = _recommended_item()
	var recommendation_quote: Dictionary = model.get_buy_quote(recommended)
	_label(_t("shop.recommended"),Vector2(58,119),19,GOLD)
	_button(Rect2(122,88,310,45),_t("shop.recommendation_item",{"item":_item_name(recommended),"cost":int(recommendation_quote.get("cost",0))}),"item",recommended,false,true,18)
	_label(_t("shop.hero_only"),Vector2(452,118),17,MUTED)
	draw_line(Vector2(834,140),Vector2(834,674),LINE,2,true)
	var all_items: Array = model.data.get("items",[])
	for i in range(shop_page*12,mini(all_items.size(),shop_page*12+12)):
		var item: Dictionary = all_items[i]
		var id: String = str(item.id)
		var k: int = i%12
		var rect: Rect2 = Rect2(58+(k%3)*252,146+(k/3)*88,240,80)
		var unlocked: bool = model.completed_wave>=int(item.get("unlock_after_wave",0))
		if id==selected_item:
			_panel(rect,Color("34382d"),GOLD,4)
			draw_rect(Rect2(rect.position+Vector2(2,14),Vector2(3,52)),GOLD)
		else:
			draw_line(rect.position+Vector2(8,79),rect.end-Vector2(8,1),Color("3d4438"),1,true)
		art.item_icon(self,rect.position+Vector2(34,38),id,PAPER,1.0)
		_label(_item_name(id),rect.position+Vector2(70,31),21,PAPER if unlocked else MUTED)
		_label(_t("shop.price",{"price":int(item.total_price)}) if unlocked else _t("shop.unlock",{"wave":int(item.unlock_after_wave)}),rect.position+Vector2(70,61),18,GOLD if unlocked else MUTED)
		hits.append({"rect":rect,"action":"item","value":id})
	_button(Rect2(58,510,154,48),_t("shop.previous"),"shop_page","0",false,shop_page>0,20)
	_label(_t("shop.page",{"page":shop_page+1,"pages":2}),Vector2(430,542),20,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	_button(Rect2(660,510,142,48),_t("shop.next"),"shop_page","1",false,shop_page<1,20)
	_label(_t("shop.inventory",{"count":model.inventory.size()}),Vector2(58,587),20,PAPER)
	_label(_t("shop.potions",{"count":model.potions}),Vector2(802,587),19,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	for i in range(6):
		var rect: Rect2 = Rect2(58+i*126,603,114,74)
		_panel(rect,Color("0f1511"),GOLD if selected_slot==i else LINE,4)
		if i<model.inventory.size():
			var id: String = str(model.inventory[i])
			art.item_icon(self,rect.position+Vector2(57,27),id,PAPER,0.83)
			_label(_item_name(id),rect.position+Vector2(57,64),18,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
			hits.append({"rect":rect,"action":"slot","value":str(i)})
		else:
			draw_line(rect.get_center()-Vector2(8,0),rect.get_center()+Vector2(8,0),LINE,2,true)
			draw_line(rect.get_center()-Vector2(0,8),rect.get_center()+Vector2(0,8),LINE,2,true)
	if not model.items.has(selected_item): return
	var item: Dictionary = model.items[selected_item]
	art.item_icon(self,Vector2(891,183),selected_item,GOLD,1.4)
	_label(_item_name(selected_item),Vector2(946,177),27,PAPER)
	_label(_t("shop.tier",{"tier":int(item.tier)}) if int(item.tier)>0 else _t("shop.consumable"),Vector2(946,208),18,MUTED)
	var y: float = 254
	for stat in _stats_text(item):
		_label(stat,Vector2(860,y),21,PAPER)
		y += 29
	var passive: String = str(item.get("passive",{}).get("type","")) if item.get("passive") is Dictionary else ""
	var description: String = ""
	match passive:
		"damage_reduction_aura": description=_t("item.passive.fortress")+"\n"+_t("item.passive.fortress_note")
		"low_hp_shield": description=_t("item.passive.sanctuary")+"\n"+_t("item.passive.sanctuary_timing")
		"heal_over_time": description=_t("item.passive.potion")+"\n"+_t("item.passive.potion_timing")
	if description!="": y += _paragraph(description,Rect2(860,y+4,350,90),18,GOLD,25)+8
	var recipe: Dictionary = item.get("recipe",{})
	if not recipe.is_empty():
		y = maxf(y+6,366)
		_label(_t("shop.recipe"),Vector2(860,y),18,MUTED)
		y += 28
		for ingredient in recipe:
			_label(_t("shop.recipe_item",{"item":_item_name(ingredient),"count":int(recipe[ingredient])}),Vector2(860,y),19,PAPER)
			y += 26
	var quote: Dictionary = model.get_buy_quote(selected_item)
	var cost: int = int(quote.get("cost",item.total_price))
	var consumed: Array = quote.get("consume",[])
	var can_buy: bool = bool(quote.get("ok",false)) and _is_preparation()
	var can_sell: bool = selected_slot>=0 or (selected_item=="healing_potion" and model.potions>0)
	_label(_t("shop.current_cost",{"cost":cost}),Vector2(860,538),25,GOLD)
	var note: String = _t("shop.consume",{"count":consumed.size()}) if not consumed.is_empty() else (_t("shop.missing_materials") if not recipe.is_empty() else "")
	if not _is_preparation(): note=_t("shop.combat_locked")
	_label(note,Vector2(860,569),17,MUTED)
	var buy_label: String = _t("shop.combine" if not consumed.is_empty() else "shop.buy") if can_buy else _shop_block_label(item,quote)
	if can_sell:
		_button(Rect2(860,594,166,78),buy_label,"buy","",true,can_buy,21)
		_button(Rect2(1042,594,178,78),_t("shop.sell_price",{"price":int(item.sell_price)}),"sell_potion" if selected_item=="healing_potion" else "sell","",false,_is_preparation(),20)
	else:
		_button(Rect2(860,594,360,78),buy_label,"buy","",true,can_buy,23)

func _shop_block_label(item: Dictionary, quote: Dictionary) -> String:
	if not _is_preparation(): return _t("shop.not_preparation")
	if model.completed_wave<int(item.get("unlock_after_wave",0)): return _t("shop.unlock",{"wave":int(item.unlock_after_wave)})
	if model.gold<int(quote.get("cost",item.total_price)): return _t("shop.not_enough_gold")
	return _reason(str(quote.get("reason","Ready")))

func _draw_pause() -> void:
	_panel(Rect2(398,84,484,552),Color("1b211b"),GOLD,6)
	_label(_t("pause.title"),Vector2(640,143),36,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(440,165),Vector2(840,165),LINE,1,true)
	_button(Rect2(440,190,400,78),_t("pause.continue"),"close","",true,true,27)
	_button(Rect2(440,286,192,64),_t("pause.help"),"modal","help",false,true,22)
	_button(Rect2(648,286,192,64),_t("settings.sound_on" if sound_enabled else "settings.sound_off"),"sound","",false,true,20)
	draw_line(Vector2(440,380),Vector2(840,380),LINE,1,true)
	_button(Rect2(440,406,400,64),_t("pause.restart"),"restart","",false,true,23)
	_button(Rect2(440,488,400,64),_t("pause.title_screen"),"title","",false,true,23)
	_paragraph(_t("pause.save_note"),Rect2(440,592,400,40),18,MUTED,26)

func _draw_help() -> void:
	_panel(Rect2(70,36,1140,648),Color("1b211b"),GOLD,6)
	_label(_t("help.title"),Vector2(108,94),34,PAPER)
	_button(Rect2(1052,58,120,62),_t("common.close"),"close","",false,true,21)
	for i in range(4):
		_button(Rect2(108+i*266,138,250,56),_t(["help.tab.controls","help.tab.skills","help.tab.equipment","help.tab.support"][i]),"help_page",str(i),help_page==i,true,22)
	if help_page==0:
		# Two gesture diagrams convey the action before the text does.
		var left: Vector2 = Vector2(252,308)
		draw_circle(left,49,Color("30372d"));draw_arc(left,49,0,TAU,40,GOLD,2,true)
		draw_circle(left+Vector2(22,-16),19,PAPER)
		draw_line(left,left+Vector2(48,-34),GOLD,3,true)
		_label(_t("help.controls.move_title"),Vector2(142,410),25,PAPER)
		_paragraph(_t("help.controls.move"),Rect2(142,447,390,90),21,MUTED,31)
		var right: Vector2 = Vector2(770,308)
		draw_circle(right,49,Color("30372d"));draw_arc(right,49,0,TAU,40,GOLD,2,true)
		art.skill_icon(self,right,0,PAPER,selected_hero if mode=="title" else model.hero_id)
		draw_line(right+Vector2(56,0),right+Vector2(151,-32),GOLD,3,true)
		draw_circle(right+Vector2(151,-32),12,PAPER)
		_label(_t("help.controls.skill_title"),Vector2(652,410),25,PAPER)
		_paragraph(_t("help.controls.skill"),Rect2(652,447,480,110),21,MUTED,31)
		_button(Rect2(108,584,570,60),_t("settings.keyboard_arrows" if keyboard_arrows else "settings.keyboard_wasd"),"keyboard","",false,true,20)
		_paragraph(_t("help.controls.keyboard_common"),Rect2(708,603,450,60),18,MUTED,26)
	elif help_page==1:
		var hero: String = model.hero_id if mode=="game" else selected_hero
		_label(HERO_NAMES[hero]+" · "+HERO_ROLES[hero],Vector2(108,239),23,GOLD)
		for i in range(4):
			var slot: String = ["Q","W","E","R"][i]
			var ability: Dictionary = {}
			for definition in model.data.abilities:
				if str(definition.get("id",""))==hero+"."+slot: ability=definition
			var y: float = 294+i*87
			art.skill_icon(self,Vector2(142,y+12),i,PAPER,hero)
			_label(SKILL_NAMES[hero][i],Vector2(188,y),23,PAPER)
			_paragraph(_t("skill."+hero+"."+slot+".detail"),Rect2(188,y+31,948,52),20,MUTED,25)
			_label("Lv.%d · %s" % [int(ability.get("unlock_level",1)),_t("skill.cost",{"cost":int(ability.get("energy_cost",0))})],Vector2(1158,y+7),18,GOLD,HORIZONTAL_ALIGNMENT_RIGHT)
	elif help_page==2:
		_label(_t("help.controls.goal_title"),Vector2(108,248),24,GOLD)
		_paragraph(_t("help.controls.goal"),Rect2(108,284,490,80),21,PAPER,31)
		_label(_t("help.equipment.prep_title"),Vector2(108,386),24,GOLD)
		_paragraph(_t("help.equipment.prep",{"seconds":int(model.tempo.preparation_seconds) if model.ruleset=="fast" else 15}),Rect2(108,423,490,112),20,PAPER,30)
		_paragraph(_t("help.equipment.first_prep"),Rect2(108,558,490,64),19,MUTED,28)
		_label(_t("help.equipment.slots_title"),Vector2(650,248),24,GOLD)
		_paragraph(_t("help.equipment.slots"),Rect2(650,284,500,80),21,PAPER,31)
		_label(_t("help.equipment.recipe_title"),Vector2(650,386),24,GOLD)
		_paragraph(_t("help.equipment.recipe"),Rect2(650,423,500,112),20,PAPER,30)
		_paragraph(_t("help.equipment.unlock"),Rect2(650,558,500,64),19,MUTED,28)


	else:
		var values: Dictionary = support_help_values()
		_label(_t("help.support.defenders_title"),Vector2(108,248),24,GOLD)
		_paragraph(_t("help.support.defenders",values),Rect2(108,284,490,120),21,PAPER,31)
		_label(_t("help.support.camp_title"),Vector2(108,438),24,GOLD)
		_paragraph(_t("help.support.camp",values),Rect2(108,474,490,160),20,PAPER,30)
		_label(_t("help.support.risk_title"),Vector2(650,248),24,GOLD)
		_paragraph(_t("help.support.risk",values),Rect2(650,284,500,120),21,PAPER,31)
		_label(_t("help.support.return_title"),Vector2(650,438),24,GOLD)
		_paragraph(_t("help.support.return",values),Rect2(650,474,500,160),20,PAPER,30)

func _draw_credits() -> void:
	_panel(Rect2(220,76,840,566),Color("1b211b"),GOLD,6)
	_label(_t("credits.title"),Vector2(270,137),34,PAPER)
	_label(_t("credits.game"),Vector2(270,187),25,GOLD)
	var lines: Array[String] = [_t("credits.genre"),_t("credits.art"),_t("credits.sound"),_t("credits.font"),_t("credits.engine"),"godotengine.org/license",_t("credits.offline"),_t("credits.save")]
	for i in range(lines.size()): _label(lines[i],Vector2(270,234+i*34),20,PAPER if i<5 else MUTED)
	_button(Rect2(470,550,340,64),_t("common.back"),"close","",true,true,23)

func result_summary() -> Dictionary:
	var metrics: Dictionary = model.metrics
	var names: Dictionary = {"crawler":_t("enemy.crawler.name"), "skirmisher":_t("enemy.skirmisher.name"), "shooter":_t("enemy.shooter.name"), "guard":_t("enemy.guard.name"), "siege":"공성포", "boss":_t("enemy.boss.name"), "boss_cannon":"보스 포격", "projectile":"원거리 공격"}
	var source_rows: Array = []
	var total: float = 0.0
	var by_kind: Dictionary = metrics.get("base_damage_by_kind",{})
	for source in by_kind:
		var amount: float = float(by_kind[source])
		if not is_finite(amount) or amount<=0: continue
		source_rows.append({"source":str(source), "label":str(names.get(str(source),"기타 공격")), "amount":amount})
		total += amount
	source_rows.sort_custom(func(a,b): return str(a.source)<str(b.source) if float(a.amount)==float(b.amount) else float(a.amount)>float(b.amount))
	var rows: Array = []
	var other: float = 0.0
	for i in range(source_rows.size()):
		if i<2: rows.append(source_rows[i].duplicate())
		else: other += float(source_rows[i].amount)
	if other>0: rows.append({"source":"__other__", "label":"기타", "amount":other})
	var elapsed_seconds: float = maxf(0,model.elapsed)
	# Valid saves allow any finite nonnegative elapsed value. Avoid overflowing
	# an int for extreme saves; the lower-bound label remains truthful and fits.
	var duration: String = "100시간+"
	if elapsed_seconds<360000:
		var seconds: int = int(elapsed_seconds)
		duration = "%02d:%02d" % [seconds/60,seconds%60] if seconds<3600 else "%d:%02d:%02d" % [seconds/3600,(seconds/60)%60,seconds%60]
	return {"completed_waves":maxi(0,int(model.completed_wave)), "deaths":maxi(0,int(metrics.get("deaths",0))), "cannon_interrupts":maxi(0,int(metrics.get("cannons_cancelled",0))), "simulation_seconds":elapsed_seconds, "time_label":duration, "damage_total":total, "damage_rows":rows, "damage_includes_overkill":true}

func _result_number(value: float, decimal: bool = false) -> String:
	if value>=100000000: return "%.1f억" % (value/100000000.0)
	if value>=10000: return "%.1f만" % (value/10000.0)
	return "%.1f" % value if decimal else str(int(value))

func _draw_result() -> void:
	var won: bool = model.phase=="Victory"
	var summary: Dictionary = result_summary()
	_panel(Rect2(238,48,804,620),Color("1b211b"),GOLD if won else RED,6)
	_label(_t("result.victory" if won else "result.defeat"),Vector2(640,122),48,GOLD if won else RED,HORIZONTAL_ALIGNMENT_CENTER)
	_label(_t("result.victory_detail" if won else "result.defeat_detail"),Vector2(640,164),23,PAPER,HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(280,187),Vector2(1000,187),LINE,1,true)
	var labels: Array[String] = [_t("result.completed_waves"),_t("result.deaths"),_t("result.cannon_interrupts"),_t("result.time")]
	var values: Array[String] = ["%d / 10" % summary.completed_waves,_result_number(summary.deaths)+"회",_result_number(summary.cannon_interrupts)+"회",summary.time_label]
	for i in range(4):
		var x: float = 280+(i%2)*382
		var y: float = 230+(i/2)*58
		_label(labels[i],Vector2(x,y),21,MUTED)
		_label(values[i],Vector2(x+338,y),26,PAPER,HORIZONTAL_ALIGNMENT_RIGHT)
	_label(_t("result.time_note"),Vector2(640,333),18,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	_label(_t("result.time_accuracy_note"),Vector2(640,358),17,MUTED,HORIZONTAL_ALIGNMENT_CENTER)
	draw_line(Vector2(280,381),Vector2(1000,381),LINE,1,true)
	_label(_t("result.castle_damage"),Vector2(280,414),22,PAPER)
	_label(_t("result.damage_note"),Vector2(1000,414),18,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
	if summary.damage_rows.is_empty():
		_label(_t("result.no_damage"),Vector2(640,480),24,TEAL,HORIZONTAL_ALIGNMENT_CENTER)
	else:
		for i in range(summary.damage_rows.size()):
			var row: Dictionary = summary.damage_rows[i]
			_label(row.label,Vector2(300,451+i*29),21,PAPER)
			_label(_result_number(row.amount,true),Vector2(980,451+i*29),21,PAPER,HORIZONTAL_ALIGNMENT_RIGHT)
	_button(Rect2(280,558,352,78),_t("result.restart"),"restart","",true,true,25)
	_button(Rect2(648,558,352,78),_t("result.title_screen"),"title","",false,true,23)
