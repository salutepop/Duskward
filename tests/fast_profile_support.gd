extends SceneTree
const Model = preload("res://scripts/siege_model.gd")
var failures: Array[String] = []
var checks: int = 0
func check(value: bool, label: String):
	checks += 1
	if not value: failures.append(label)
func tick(m, seconds: float):
	for i in ceili(seconds*30): m.step(1.0/30.0)
func camp():
	var m = Model.new()
	m.phase = "Combat"; m.wave = 4; m.spawn_queue = ["crawler"]
	m.auto_attack_enabled = false; m.defenders = []
	m._prepare_hunt(); m.elapsed = 6; m._step_hunt_clock(0)
	return m
func run():
	var classic = Model.new("classic")
	check(classic.defenders.is_empty(),"classic no support")
	classic.start_next_wave()
	check(classic.enemies.is_empty() and classic.spawn_queue.size()==18,"classic original first wave")
	var m = Model.new()
	check(m.defenders.size()==2,"two targetable defenders")
	m.start_next_wave()
	check(m.enemies.size()==3 and m.spawn_queue.size()==19,"hard22 enemies with3 initial")
	check(m.phase=="Combat" and m.elapsed==0,"no time acceleration at start")
	tick(m,1.1)
	check(m.enemies.size()==5,"two additional half-second arrivals")
	m=Model.new(); var enemy=m.spawn_enemy("crawler",Vector2(15,12)); var gold=m.gold; var xp=m.xp
	m._damage_enemy(enemy,10000,"physical",false,"fixture");m._resolve_deaths()
	check(m.gold-gold==6 and m.xp-xp==15,"fast exact per-cost rewards")
	check(m.metrics.lane_gold==6 and m.metrics.lane_xp==15,"lane reward attribution")
	check(m.metrics.hero_lane_gold==6 and m.metrics.defender_lane_gold==0,"hero lane attribution")
	m._resolve_deaths();check(m.gold==gold+6,"death settlement idempotent")
	m=Model.new();m.phase="Combat";m.auto_attack_enabled=false;m.pos=Vector2(30,24)
	enemy=m.spawn_enemy("crawler",Vector2(9,22));enemy.speed=0;enemy.attack_timer=100
	for i in 30: m._step_defenders(1.0/30);m._step_projectiles(1.0/30)
	check(m.metrics.defender_damage>0 and m.metrics.damage_dealt==0,"AI damage separately credited")
	check(m.metrics.damage_by_source.is_empty() and m.ranger_hits==0 and m.arcanist_passive_cd==0,"AI no hero attack procs")
	m._damage_enemy(enemy,10000,"physical",false,"defender");m._resolve_deaths()
	check(m.metrics.defender_lane_gold==6 and m.metrics.defender_lane_xp==15 and m.metrics.defender_kills==1,"AI one shared reward with attribution")
	m._damage_defender(m.defenders[0],10000)
	check(m.defenders[0].hp==0 and m.defenders[0].respawn_left==22 and m.metrics.defender_deaths==1,"AI death and respawn timer")
	m._step_defenders(22.1);check(m.defenders[0].hp==260,"AI revives without hero resource changes")
	m.enemies=[];enemy=m.spawn_enemy("siege",Vector2(12,24));enemy.attack_timer=0;m._step_enemies(1.0/30)
	check(enemy.attack_target=="base" and is_equal_approx(enemy.telegraph,0.9),"siege ignores defenders and keeps warning")
	m.enemies=[];enemy=m.spawn_enemy("crawler",Vector2(7.5,22));enemy.attack_timer=0;m._step_enemies(1.0/30)
	check(enemy.attack_target=="defender","ordinary enemy targets live defender")
	var before=m.base_hp;m._damage_defender(m.defenders[0],10000);m._enemy_attack(enemy)
	check(m.base_hp==before,"dead ally target does not redirect to castle")
	m=Model.new();m.phase="Boss";m.auto_attack_enabled=false
	enemy=m.spawn_enemy("weakness",Vector2(10,24),false)
	for ally in m.defenders: ally.attack_left=0
	for i in 120: m._step_defenders(1.0/30);m._step_projectiles(1.0/30)
	check(enemy.hp>0,"defenders cannot clear fresh core alone in4seconds")
	m=camp();check(m.hunt.state=="available" and not m.start_hunt(),"camp appears but far activation fails")
	check(m.metrics.hunt_attempts==0,"failed activation costs nothing")
	m.pos=m.hunt.pos;m.base_hp=2100
	check(not m.start_hunt(),"35percent base blocks activation")
	m.base_hp=2200;var lane_rng=m.spawn_rng.state;var camp_state=m.camp_rng.state
	check(m.start_hunt(),"nearby living hero can activate")
	check(m.spawn_rng.state==lane_rng and m.camp_rng.state!=camp_state,"camp randomness isolated from lane stream")
	check(m.enemies.size()==4 and m.main_enemy_count()==0,"four camp enemies excluded from lane count")
	for e in m.enemies: check(e.hunt_enemy and not e.reward,"camp enemy no individual reward")
	gold=m.gold;xp=m.xp
	m._damage_enemy(m.enemies[0],10000,"physical");m._resolve_deaths()
	check(m.gold==gold and m.xp==xp,"partial hunt pays nothing")
	for e in m.enemies: m._damage_enemy(e,10000,"physical")
	m._resolve_deaths();m._settle_hunt()
	check(m.gold==gold+120 and m.xp==xp+100 and m.hunt.state=="cleared","one camp clear bounty")
	m._settle_hunt();check(m.metrics.hunt_successes==1 and m.gold==gold+120,"repeat settlement no duplicate")
	m.hp=400;m.energy=20;m.cooldowns.Q=4
	check(m.request_hunt_return() and not m.request_hunt_return(),"return idempotent")
	check(not m.cast("Q"),"return channel blocks skill")
	var at=m.pos;m.step(1.0/30,Vector2.LEFT)
	check(m.pos==at,"return channel blocks movement")
	tick(m,2.1)
	check(m.pos==m.START and m.hunt.state=="closed","two-second return reaches castle")
	check(m.hp<=400 and m.energy<100 and m.cooldowns.Q>0 and m.invulnerable_left==0,"return no heal CD reset or invulnerability")
	check(not m.start_hunt() and not m.request_hunt_return(),"closed opportunity cannot restart or teleport")
	m=camp();m.pos=m.hunt.pos;m.start_hunt();m.base_hp=1800;m.hp=300
	check(m.request_hunt_return() and m.pos==m.START and m.hunt.state=="closed","requested emergency return immediate")
	check(m.gold==300 and m.hp==300,"abandoned camp no reward or heal")
	m=camp();m.pos=m.hunt.pos;m.start_hunt();m.hunt.time_left=0.01
	for e in m.enemies:e.hp=0
	m.step(1.0/30)
	check(m.hunt.outcome=="timeout" and m.metrics.hunt_successes==0,"timeout wins over same-step last kill")
	m=camp();m.pos=m.hunt.pos;m.start_hunt()
	for e in m.enemies:e.hp=0
	m.damage_hero(100000);m._resolve_deaths();m._settle_hunt()
	check(m.hunt.state=="closed" and m.metrics.hunt_successes==0 and m.gold==300,"hero death wins pending camp reward")
	m=camp();m.pos=m.hunt.pos;m.start_hunt()
	for e in m.enemies:e.hp=0
	m.base_hp=0;m.step(1.0/30)
	check(m.phase=="Defeat" and m.metrics.hunt_successes==0,"castle defeat wins pending camp reward")
	m=camp();m.pos=m.hunt.pos;m.start_hunt();m.spawn_queue=[]
	for e in m.enemies:e.hp=0
	m.step(1.0/30)
	check(m.phase=="Preparation" and m.metrics.hunt_successes==1,"living last camp and lane kill pays before wave clear")
	check(is_equal_approx(m.prep_left,float(m.tempo.preparation_seconds)) and m.hunt.state=="closed","configured prep duration and camp closure")
	m=camp();m.pos=m.hunt.pos;m.start_hunt();m.pos=m.START
	for e in m.enemies:e.attack_timer=0
	for i in 300:m._step_enemies(1.0/30)
	for e in m.enemies:check(e.pos.distance_to(e.home)<0.3 and e.attack_target!="base","camp monsters return home never castle")
	m=Model.new();m.hp=400;m.energy=23;m.buy("armor_plate")
	check(m.save_checkpoint(),"schema4 save succeeds")
	var restored=Model.new();check(restored.load_checkpoint() and restored.hp==400 and restored.energy==23,"schema4 exact resources restore")
	check(restored.camp_rng.state==m.camp_rng.state,"camp RNG checkpoint restore")
	check(not Model.new("classic").load_checkpoint(),"cross-profile checkpoint rejects")
	var previous=JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE_PATH));previous.schema=3
	for path in [Model.SAVE_PATH,Model.SAVE_PATH+".bak"]:
		var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(previous));file.close()
	var legacy=Model.new()
	check(not legacy.load_checkpoint() and legacy.notice.contains("incompatible game version"),"schema3 rejection explains version not corruption")
	print("FAST_PROFILE_SUPPORT ",JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
func _initialize():call_deferred("run")
