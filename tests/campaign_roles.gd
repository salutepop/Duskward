extends SceneTree
## Campaign length and new-role behaviour. Controlled model fixtures, not a played run.
const Model = preload("res://scripts/siege_model.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures.append(label)

func _init():
	var m=Model.new()
	check(m.final_wave==15,"campaign is fifteen ordinary waves")
	check(m.final_wave==m.data.waves.size() and m.final_wave==m.tempo.wave_counts.size(),"wave tables agree")
	# Wave fourteen must not open the boss gate.
	m.phase="Combat"; m.wave=14; m.completed_wave=13; m.spawn_queue=[]; m.enemies=[]
	m._clear_wave()
	check(m.phase=="Preparation","wave fourteen clears into ordinary preparation")
	check(is_equal_approx(m.prep_left,float(m.tempo.preparation_seconds)),"ordinary preparation keeps its own length")
	# Wave fifteen opens the final preparation.
	m.phase="Combat"; m.wave=15; m.completed_wave=14; m.spawn_queue=[]; m.enemies=[]
	m._clear_wave()
	check(m.phase=="FinalPreparation","wave fifteen clears into final preparation")
	check(is_equal_approx(m.prep_left,15.0),"final preparation is fifteen seconds")
	check(m.start_next_wave() and m.phase=="BossIntro","final preparation starts the boss intro")
	for i in 200: m.step(1.0/30.0)
	check(m.phase=="Boss","boss phase reached")
	var boss: Dictionary = m._boss()
	check(not boss.is_empty(),"boss spawned")
	check(is_equal_approx(float(boss.max_hp),18000.0*0.85),"boss hp follows catalog and solo scale")
	check(is_equal_approx(float(boss.armor),20.0),"boss armor follows catalog")
	# The boss walks to the castle, not to the old 48x24 arena coordinate.
	m.auto_attack_enabled=false
	m.pos=Vector2(90,45); m.respawn_left=0; m.defenders=[]
	for i in 2400: m.step(1.0/30.0)
	var settled: Dictionary = m._boss()
	check(not settled.is_empty() and settled.pos.distance_to(Model.CASTLE+Vector2(4,0))<3.0,"boss advances to the siege line")
	# The bonus arena must hand control back to a preparation that advances.
	var s=Model.new()
	s.phase="Combat"; s.wave=3; s.completed_wave=2; s.enemies=[]; s.spawn_queue=[]
	s._clear_wave()
	check(s.phase=="SpecialEvent" and not s.special_event.is_empty(),"wave three clear opens the bonus arena")
	for i in 3000:
		s.step(1.0/30.0)
		if s.phase!="SpecialEvent": break
	check(s.phase=="Preparation" and is_equal_approx(s.prep_left,float(s.tempo.preparation_seconds)),"arena returns to a live preparation")
	check(s.start_next_wave() and s.phase=="Combat" and s.wave==4,"arena is not re-entered by the next wave")
	check(s.special_event.is_empty(),"arena fires once per campaign")
	for i in 30: s.step(1.0/30.0)
	check(s.phase=="Combat" and s.wave==4,"wave four keeps running after the arena")
	# Flyers cross defender lines and ground traps.
	var f=Model.new(); f.phase="Combat"; f.wave=1; f.auto_attack_enabled=false; f.pos=Vector2(90,45); f.defenders=[]
	var flyer: Dictionary = f.spawn_enemy("flyer",Vector2(40,24),false)
	f.traps.append({"pos":Vector2(40,24),"radius":3.0,"arm":0.0,"life":2.0,"damage":50.0})
	for i in 30: f.step(1.0/30.0)
	check(is_equal_approx(float(flyer.hp),float(flyer.max_hp)),"flyer ignores ground traps")
	check(float(flyer.pos.x)<40.0,"flyer advances on the castle")
	var g=Model.new(); g.phase="Combat"; g.wave=1; g.auto_attack_enabled=false; g.pos=Vector2(90,45)
	g.defenders[0].pos=Vector2(30,24); g.defenders[1].pos=Vector2(30,24)
	var crosser: Dictionary = g.spawn_enemy("flyer",Vector2(31.4,24),false)
	for i in 45: g.step(1.0/30.0)
	check(str(crosser.attack_target)!="defender","flyer does not stop for defenders")
	# A ground crawler in the same spot does engage the defender.
	var h=Model.new(); h.phase="Combat"; h.wave=1; h.auto_attack_enabled=false; h.pos=Vector2(90,45)
	h.defenders[0].pos=Vector2(30,24); h.defenders[1].pos=Vector2(30,24)
	var walker: Dictionary = h.spawn_enemy("crawler",Vector2(31.4,24),false)
	for i in 45: h.step(1.0/30.0)
	check(str(walker.attack_target)=="defender","ground crawler still engages defenders")
	print("CAMPAIGN_ROLES ",JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
