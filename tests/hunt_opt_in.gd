extends SceneTree
# Controlled activation/lifecycle fixtures, not a legal match or touch-feel claim.
const Model=preload("res://scripts/siege_model.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label);printerr("FAIL: ",label)
func fixture():
	var m=Model.new();m.phase="Combat";m.wave=4;m.completed_wave=3;m.auto_attack_enabled=false
	m._prepare_hunt();m.elapsed=6;m._step_hunt_clock(0)
	var lane=m.spawn_enemy("crawler",Vector2(46,20),false);lane.speed=0;lane.attack_timer=9999
	return m
func done():
	print(JSON.stringify({"suite":"hunt_opt_in","checks":checks,"failures":failures,"controlled_fixtures":true}))
	quit(0 if failures.is_empty() else 1)
func _init():
	var m=fixture();m.pos=m.hunt.pos
	for tick in 60:m.step(1.0/30.0)
	check(m.hunt.state=="available" and m.metrics.hunt_attempts==0,"Standing inside available camp does not opt in")
	check(m.enemies.size()==1,"Proximity alone creates no camp enemies")
	check(m.has_method("can_start_hunt"),"Pure start eligibility API exists")
	if not m.has_method("can_start_hunt"):done();return
	var before=JSON.stringify({"hunt":m.hunt,"metrics":m.metrics,"gold":m.gold,"xp":m.xp,"camp_rng":str(m.camp_rng.state)})
	for repeat in 10:check(m.can_start_hunt(),"Eligible request preview "+str(repeat))
	check(before==JSON.stringify({"hunt":m.hunt,"metrics":m.metrics,"gold":m.gold,"xp":m.xp,"camp_rng":str(m.camp_rng.state)}),"Repeated eligibility checks are pure")
	check(m.start_hunt() and m.metrics.hunt_attempts==1,"Explicit nearby request activates once")
	check(not m.start_hunt() and not m.can_start_hunt() and m.enemies.size()==5,"Repeated explicit requests never duplicate camp")
	for reason in ["far","low_hp_castle","dead","phase","capacity"]:
		m=fixture();m.pos=m.hunt.pos
		match reason:
			"far":m.pos+=Vector2(2.501,0)
			"low_hp_castle":m.base_hp=2100
			"dead":m.hp=0;m.respawn_left=1
			"phase":m.phase="Preparation"
			"capacity":
				for count in 56:m.spawn_enemy("crawler",Vector2(46,20),false)
		check(not m.can_start_hunt() and not m.start_hunt(),"Existing condition rejects explicit request: "+reason)
		check(m.hunt.state=="available" and m.metrics.hunt_attempts==0,"Rejected request consumes nothing: "+reason)
	m=fixture();m.pos=m.hunt.pos+Vector2(2.5,0)
	check(m.can_start_hunt() and m.start_hunt(),"Exact activation boundary remains inclusive")
	done()
