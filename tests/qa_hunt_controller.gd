extends SceneTree
# Controlled controller-branch/input fixtures, not full legal match evidence.
const Controller=preload("res://scripts/qa_autoplay.gd")
var ui
var controller
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func _initialize():call_deferred("run")
func redraw():ui.queue_redraw();await process_frame;await process_frame
func fixture():
	if controller!=null:controller.free()
	controller=Controller.new();check(controller.configure(ui,"ranger:hunt"),"Explicit debug known policy configures")
	controller.set_process(false)
	ui._start_new();ui.sound_enabled=false;ui.set_process(false)
	ui.model.reset("ranger",12345);ui.model.phase="Combat";ui.last_phase="Combat";ui.model.wave=4;ui.model.completed_wave=3;ui.model._prepare_hunt();ui.model.hunt.state="available"
	ui.model.auto_attack_enabled=false
	var lane=ui.model.spawn_enemy("crawler",Vector2(46,20),false);lane.speed=0;lane.attack_timer=9999
	ui._sync_hunt_presentation()
func run():
	for hero in ["guardian","ranger","arcanist"]:
		for policy in ["priority","aggressive","hunt"]:check(Controller.valid_request(hero+":"+policy),"Known hero/policy "+hero+policy)
	for bad in ["","ranger","ranger:unknown","boss:hunt","ranger:hunt:code","ranger:hunt;quit","http://x:hunt"]:check(not Controller.valid_request(bad),"Unknown request rejected "+bad)
	ui=load("res://main.tscn").instantiate();root.add_child(ui);await process_frame;ui.set_process(false);ui.sound_enabled=false
	check(ui.qa_controller==null and ui.mode=="title","Normal title has no controller")
	fixture();await redraw()
	var original_pos=ui.model.pos
	check(controller._hunt_control(),"Approach owns joystick")
	check(ui.joystick.length()>0 and ui.model.pos==original_pos,"Controller dispatches movement without teleporting model")
	check(controller.hunt_visits["4"].stage=="approach","One local trip selected")
	ui.model.pos=ui.model.hunt.pos;ui._sync_hunt_presentation();await redraw()
	var original_gold=ui.model.gold;var original_hp=ui.model.hp
	controller._hunt_control()
	check(ui.model.hunt.state=="active" and ui.model.metrics.hunt_attempts==1,"Start accepted through real hitbox")
	check(controller.hunt_visits["4"].activation_at==ui.model.elapsed,"Actual activation time recorded")
	check(controller.event_count>=4 and ui.model.gold==original_gold and ui.model.hp==original_hp,"Touch events not health/currency grants")
	await redraw();ui.model.elapsed+=10.1
	controller._hunt_control()
	check(ui.model.hunt.state=="returning" and controller.hunt_visits["4"].stage=="returning","10s cap requests real unsafe return")
	check(controller.hunt_decisions[-1].reason=="active_time_limit","Return reason recorded")
	for tick in 61:ui.model.step(1.0/30.0)
	controller._observe_hunt_end()
	check(ui.model.hunt.state=="closed" and controller.hunt_visits["4"].stage=="finished","Normal model return completes and observation closes log")
	check(ui.model.metrics.hunt_successes==0 and ui.model.gold==original_gold,"Abandon does not invent reward")
	fixture();ui.model.base_hp=3600;await redraw();controller._hunt_control()
	check(controller.hunt_visits["4"].stage=="skipped","Exact60percent castle does not enter")
	ui.model.base_hp=6000;controller._hunt_control();check(controller.hunt_visits["4"].stage=="skipped","Skipped wave is not retried")
	fixture();await redraw();controller._hunt_control();ui.model.elapsed=8.01;controller._hunt_control()
	check(controller.hunt_visits["4"].stage=="aborted" and ui.model.metrics.hunt_attempts==0,"8s approach cap abandons without camp activation")
	fixture();await redraw();controller._hunt_control();ui.model.hp=ui.model.stats.max_hp*0.54;controller._hunt_control()
	check(controller.hunt_visits["4"].stage=="aborted","Approach safety rechecked")
	fixture();ui.model.pos=ui.model.hunt.pos;ui._sync_hunt_presentation();await redraw();controller._hunt_control();await redraw()
	ui.model.base_hp=3600;controller._hunt_control();check(ui.model.hunt.state=="returning" and controller.hunt_decisions[-1].reason=="castle_safety","Active safety threshold returns")
	fixture();ui.model.pos=ui.model.hunt.pos;ui._sync_hunt_presentation();await redraw();controller._hunt_control();await redraw()
	ui.model.hunt.state="cleared";ui.model.hunt.reward_claimed=true;ui._sync_hunt_presentation();await redraw();controller._hunt_control()
	check(ui.model.hunt.state=="returning" and controller.hunt_decisions[-1].reason=="clear","Cleared camp requests return")
	fixture();await redraw();controller.stage="play";controller.delay=0;ui._open_modal("pause");controller._process(0.1)
	check(controller.hunt_visits.is_empty() and ui.modal=="pause","Controller does not dismiss player/lifecycle pause")
	controller.policy="hunt";ui.model.phase="Preparation";ui.model.completed_wave=0
	var resources=JSON.stringify({"gold":ui.model.gold,"inventory":ui.model.inventory,"hp":ui.model.hp})
	check(controller._next_purchase()=="iron_blade","Hunt route begins with legal item")
	check(resources==JSON.stringify({"gold":ui.model.gold,"inventory":ui.model.inventory,"hp":ui.model.hp}),"Purchase recommendation is read-only")
	await revision_three_checks()
	print(JSON.stringify({"suite":"qa_hunt_controller","checks":checks,"failures":failures,"controlled_fixtures":true,"full_match":false}))
	controller.free();ui.queue_free();await process_frame;await create_timer(.2).timeout;quit(0 if failures.is_empty() else 1)

func revision_three_checks():
	fixture(); controller.hero="guardian"; ui.model.reset("guardian",12345); ui.model.phase="Combat"; ui.model.pos=Vector2(15,12)
	var target=ui.model.spawn_enemy("siege",Vector2(16.5,12),false)
	check(Controller.CONTROLLER_REVISION==3,"Controller correction is explicitly versioned")
	check(controller._movement(target)==Vector2.RIGHT,"Hunt guardian moves closer than legacy attack edge")
	controller.policy="priority"
	check(controller._movement(target)==Vector2.ZERO,"Legacy priority stance is unchanged")
	controller.policy="hunt"; target.pos=Vector2(15.7,12)
	check(controller._movement(target)==Vector2.ZERO,"Close stance stops inside0.8m")
	ui.model.boss_pattern="smash"; ui.model.boss_pattern_left=1; ui.model.boss_pattern_data={"pos":Vector2(12,12),"dir":Vector2.RIGHT,"radius":7.0}
	var first=controller._visible_danger_escape()
	check(first.active and first.direction==Vector2.DOWN,"Locked-axis side exit chosen, independent of selected target")
	ui.model.pos=Vector2(14,19); ui.model.elapsed+=0.3; ui.model.boss_pattern_left=0.7
	check(controller._visible_danger_escape().direction==first.direction,"Exit held after crossing warning edge")
	ui.model.boss_pattern=""; ui.model.boss_pattern_left=0
	check(not controller._visible_danger_escape().active and controller.escape_direction==Vector2.ZERO,"Completed warning resets held escape")
	ui.model.pos=Vector2(12,12); ui.model.boss_pattern="smash"; ui.model.boss_pattern_left=1; ui.model.boss_pattern_data.dir=Vector2.ZERO
	check(controller._visible_danger_escape().direction==Vector2.RIGHT,"Apex and zero-axis fallback finite")
	ui.model.boss_pattern=""; controller._visible_danger_escape(); ui.model.hazards=[{"pos":ui.model.pos,"radius":3.0}]
	check(controller._visible_danger_escape().direction==Vector2.UP,"Visible debris center has finite escape")
	ui.model.hazards=[]; ui.model.pos=Vector2(15,12); target.pos=Vector2(20,12); ui.model.boss_pattern="smash"; ui.model.boss_pattern_left=1; ui.model.boss_pattern_data={"pos":Vector2(12,12),"dir":Vector2.RIGHT,"radius":7.0}
	ui.model.cooldowns={"Q":99.0,"W":99.0,"E":0.0,"R":99.0}; ui.model.level=6; ui.model.stats=ui.model.derived_stats("guardian",6,[]); ui.model.energy=ui.model.stats.max_energy
	await redraw(); controller._skills(target)
	check(ui.model.pending_casts.is_empty() and ui.model.cast_buffer.is_empty(),"Guardian dash cannot undo active warning escape")
	fixture(); controller.hero="arcanist"; ui.model.reset("arcanist",12345); ui.model.phase="Boss"; ui.last_phase="Boss"; ui.model.level=6; ui.model.stats=ui.model.derived_stats("arcanist",6,[]); ui.model.energy=ui.model.stats.max_energy; ui.model.pos=Vector2(12,12)
	target=ui.model.spawn_enemy("boss",Vector2(21,12),false)
	check(controller._movement(target)==Vector2.RIGHT,"Ready ultimate condition approaches boss body reach")
	controller.policy="priority"
	check(controller._movement(target)==Vector2.ZERO,"Legacy arcanist positioning retained")
	controller.policy="hunt"; target.pos=Vector2(20.4,12); ui.model.cooldowns={"Q":99.0,"W":99.0,"E":99.0,"R":0.0}
	await redraw(); controller._skills(target)
	check(ui.model.pending_casts.size()==1 and ui.model.pending_casts[0].slot=="R","Actual Viewport tap accepts ultimate at boss-radius edge")
	ui.model.cancel_cast(); ui.model.cooldowns.R=5; target.pos=Vector2(21,12)
	check(controller._movement(target)==Vector2.ZERO,"Unavailable ultimate does not force approach")
