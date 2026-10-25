extends SceneTree
const Model = preload("res://scripts/siege_model.gd")
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures.append(label)
func _init():
	for dt in [1.0/30.0,1.0/60.0,0.1,0.07]:
		var m=Model.new();m.start_next_wave();m.auto_attack_enabled=false;m.defenders=[]
		var elapsed:float=0
		for tick in ceili(10.5/dt):
			var before:int=m.enemies.size()
			m.step(dt);elapsed+=minf(dt,0.1)
			var expected:int=mini(22,3+int(floor((elapsed+0.00000001)/0.5)))
			check(m.enemies.size()==expected,"partition count dt%s tick%d"%[dt,tick+1])
			check(m.enemies.size()-before<=1,"no catch-up burst dt%s tick%d"%[dt,tick+1])
		check(m.spawn_queue.is_empty() and m.enemies.size()==22,"all19 queued arrivals without drift dt%s"%dt)
	var m=Model.new();m.start_next_wave();m.auto_attack_enabled=false;m.defenders=[]
	for i in 57:m.spawn_enemy("crawler",Vector2(46,12),false)
	for i in 120:m.step(1.0/30)
	check(m.enemies.size()==60 and m.spawn_queue.size()==19,"cap retains queue over4seconds")
	m.enemies[0].hp=0;m.enemies[1].hp=0;m._resolve_deaths()
	m.step(1.0/30)
	check(m.enemies.size()==59 and m.spawn_queue.size()==18,"one slot refill after cap release")
	for i in 14:m.step(1.0/30)
	check(m.enemies.size()==59,"no backlog refill before a full interval")
	m.step(1.0/30)
	check(m.enemies.size()==60 and m.spawn_queue.size()==17,"next refill exactly15ticks later")
	m=Model.new();m.start_next_wave();m.auto_attack_enabled=false;m.defenders=[]
	for i in 5:m.step(10.0)
	check(is_equal_approx(m.elapsed,0.5) and m.enemies.size()==4,"large caller delta retains existing0.1s model cap")
	print("SPAWN_SCHEDULE ",JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
