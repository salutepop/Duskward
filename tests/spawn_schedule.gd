extends SceneTree
const Model = preload("res://scripts/siege_model.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
func _init():
	var base=Model.new()
	var interval:float=float(base.tempo.spawn_interval_seconds)
	var initial:int=int(base.tempo.initial_spawn_count)
	var total:int=0
	for kind in base.tempo.wave_counts[0]: total+=int(base.tempo.wave_counts[0][kind])
	for dt in [1.0/30.0,1.0/60.0,0.1,0.07]:
		var m=Model.new();m.start_next_wave();m.auto_attack_enabled=false;m.defenders=[];m.allies=[]
		var elapsed:float=0
		for tick in ceili(10.5/dt):
			var before:int=m.enemies.size()
			m.step(dt);elapsed+=minf(dt,0.1)
			var expected:int=mini(total,initial+int(floor((elapsed+0.00000001)/interval)))
			check(m.enemies.size()==expected,"partition count dt%s tick%d"%[dt,tick+1])
			check(m.enemies.size()-before<=1,"no catch-up burst dt%s tick%d"%[dt,tick+1])
		check(m.spawn_queue.is_empty() and m.enemies.size()==total,"all%d queued arrivals without drift dt%s"%[total-initial,dt])
	var m=Model.new();m.start_next_wave();m.auto_attack_enabled=false;m.defenders=[];m.allies=[]
	for i in 57:m.spawn_enemy("crawler",Vector2(46,12),false)
	for i in 120:m.step(1.0/30)
	check(m.enemies.size()==60 and m.spawn_queue.size()==total-initial,"cap retains queue over4seconds")
	m.enemies[0].hp=0;m.enemies[1].hp=0;m._resolve_deaths()
	m.step(1.0/30)
	check(m.enemies.size()==59 and m.spawn_queue.size()==total-initial-1,"one slot refill after cap release")
	var gap_ticks:int=int(round(interval*30.0))
	for i in gap_ticks-1:m.step(1.0/30)
	check(m.enemies.size()==59,"no backlog refill before a full interval")
	m.step(1.0/30)
	check(m.enemies.size()==60 and m.spawn_queue.size()==total-initial-2,"next refill after one full interval")
	m=Model.new();m.start_next_wave();m.auto_attack_enabled=false;m.defenders=[];m.allies=[]
	for i in 5:m.step(10.0)
	check(is_equal_approx(m.elapsed,0.5) and m.enemies.size()==initial+int(floor(0.5/interval)),"large caller delta retains existing0.1s model cap")
	print("SPAWN_SCHEDULE ",JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
