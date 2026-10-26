extends SceneTree
# Original combat formula fixtures isolate the classic encounter profile.
# Fast-profile interactions and real default-profile matches have separate gates.
const Model = preload("res://scripts/siege_model.gd")
var checks = 0
var failures: Array = []

func check(condition: bool, message: String):
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: ",message)

func sim(hero: String = "guardian"):
	var m = Model.new("classic")
	m.reset(hero,718)
	m.phase = "Combat"
	m.wave = 1
	m.level = 12
	m.recalculate_stats()
	m.hp = m.stats.max_hp
	m.energy = m.stats.max_energy
	m.auto_attack_enabled = false
	m.spawn_queue = ["crawler"]
	m.spawn_timer = 9999
	return m

func advance(m, seconds: float):
	for i in int(ceil(seconds*30)): m.step(1.0/30.0,Vector2.ZERO)

func dummy(m, at: Vector2 = Model.START+Vector2(-3,0)):
	var e = m.spawn_enemy("crawler",at,false)
	e.hp = 10000.0
	e.max_hp = 10000.0
	e.speed = 0.0
	e.attack_timer = 10000.0
	return e

func _init():
	var m = sim()
	var e = dummy(m)
	check(m.cast("Q"),"Q windup starts")
	check(is_equal_approx(m.energy,100),"Energy reserved, not deducted before commit")
	check(is_zero_approx(m.cooldowns.Q),"Cooldown not started during windup")
	m.cancel_cast()
	advance(m,0.3)
	check(is_equal_approx(e.hp,10000),"Canceled Q never damages")
	check(is_equal_approx(m.energy,100),"Canceled Q costs nothing")
	m.cast("Q")
	advance(m,0.3)
	check(e.hp<10000,"Committed Q damages")
	check(m.cooldowns.Q>6,"Cooldown begins on commit")
	check(m.energy<90,"Committed Q spends15energy")

	m = sim()
	e = dummy(m)
	m.cast("Q")
	m.damage_hero(1000000)
	advance(m,0.3)
	check(is_equal_approx(e.hp,10000),"Death cancels uncommitted ability")
	check(m.pending_casts.is_empty() and is_zero_approx(m.energy_reserved),"Death releases all reservations")
	check(m.respawn_left>0 and m.hp==0,"Death starts respawn without revival by regen")
	advance(m,7)
	check(m.hp==m.stats.max_hp and m.energy==m.stats.max_energy,"Respawn restores health and energy")
	check(m.pos==Model.START,"Respawn at safe start")

	for hero in ["guardian","ranger","arcanist"]:
		for slot in ["Q","W","E","R"]:
			m = sim(hero)
			e = dummy(m)
			check(m.cast(slot),"%s.%s cast accepted" % [hero,slot])
			advance(m,1.4 if (slot=="R" and hero=="guardian") or (slot=="E" and hero=="arcanist") else 0.4)
			check(m.cooldowns[slot]>0,"%s.%s cooldown committed" % [hero,slot])
			check(m.metrics.casts==1,"%s.%s commits exactly once" % [hero,slot])
			check(m.energy<=100 and m.energy>=0,"%s.%s energy within bounds" % [hero,slot])
			if slot=="Q" or (slot=="E" and hero!="ranger") or (slot=="R" and hero!="ranger"):
				check(e.hp<10000,"%s.%s has actual combat effect" % [hero,slot])

	m = sim()
	m.add_shield("skill",200,4)
	m.add_shield("skill",100,4)
	m.add_shield("item",300,2)
	check(is_equal_approx(m.shield,500),"Same shield group max; different groups add")
	var before_hp = m.hp
	m.damage_hero(100)
	check(is_equal_approx(m.hp,before_hp),"Shield absorbs before health")
	check(m.shield_groups.item.amount<300 and m.shield_groups.skill.amount==200,"Earliest expiry shield consumed first")
	advance(m,2.1)
	check(is_equal_approx(m.shield,200),"Independent shield expires without deleting longer shield")
	m.damage_hero(1000000)
	check(m.shield_groups.is_empty(),"Death removes all shield groups")

	m = sim("ranger")
	m.inventory = ["blood_edge","sanguine","sanguine"]
	m.recalculate_stats()
	check(is_equal_approx(m.stats.lifesteal,0.12),"Lifesteal highest source only")
	m.hp = 100
	e = dummy(m)
	e.hp = 1
	m._damage_enemy(e,10000,"physical",true)
	check(is_equal_approx(m.hp,100.12),"Lifesteal uses HP actually removed, not overkill")
	e = dummy(m)
	for i in 20: m._damage_enemy(e,10000,"physical",true)
	check(m.hp<=100+m.stats.max_hp*0.08+0.0001,"Rolling1s lifesteal cap")

	m = sim()
	m.hp = 100
	m.potions = 1
	check(m.use_potion(),"Potion consumed when hurt")
	advance(m,0.5)
	check(is_equal_approx(m.hp,100),"Potion waits for first1s pulse")
	advance(m,2.6)
	check(is_equal_approx(m.hp,100+m.stats.max_hp*0.3),"Potion heals30percent over3pulses")
	check(m.potions==0 and m.potion_cd>26,"Potion stock/CD persist")

	m = sim()
	m.level = 1
	m.recalculate_stats()
	check(not m.cast("R"),"Locked ultimate cannot cast")
	check(m.metrics.casts==0,"Rejected cast has no effect")
	m.phase = "Preparation"
	m.base_hp = 3000
	m.gold = 300
	check(m.buy("iron_blade").ok,"Preparation purchase allowed")
	check(m.save_checkpoint(),"Checkpoint atomic save succeeds")
	var restored = Model.new("classic")
	check(restored.load_checkpoint(),"Checkpoint load succeeds")
	check(restored.gold==100 and restored.inventory==["iron_blade"] and restored.base_hp==3000,"Checkpoint restores economy/base exactly")
	check(restored.completed_wave==0,"Checkpoint does not grant wave rewards")

	m = sim()
	m.phase = "Boss"
	m.spawn_queue.clear()
	m.base_hp = 0
	var boss = m.spawn_enemy("boss",Vector2(12,12),false)
	boss.hp = 0
	advance(m,1.0/30)
	check(m.phase=="Defeat","Castle defeat wins simultaneous boss death")
	check(is_equal_approx(Model.mitigation(25),0.8),"Positive armor formula")
	check(is_equal_approx(Model.mitigation(-25),1.2),"Negative armor formula")
	check(is_equal_approx(Model.segment_distance(Vector2(5,0),Vector2.ZERO,Vector2(10,0)),0),"Projectile sweep covers skipped midpoint")
	m = sim("arcanist")
	e = dummy(m)
	m.cast("E",e.pos)
	advance(m,0.5)
	check(is_equal_approx(e.hp,10000),"Ground zone does not pulse before its first second")
	check(e.slow>0,"Ground zone slows before first damage pulse")
	advance(m,4.0)
	check(is_equal_approx(10000-e.hp,4*(20+0.3*m.stats.sp)),"Ground zone has exactly four delayed pulses")
	check(is_zero_approx(e.slow),"Ground slow ends after leaving expired field")
	m = sim()
	e = dummy(m)
	m._slow(e,0.4,1,"strong")
	m._slow(e,0.2,3,"weak")
	check(is_equal_approx(e.slow,0.4),"Strongest slow wins while both active")
	advance(m,1.1)
	check(is_equal_approx(e.slow,0.2),"Weaker slow resumes after independent stronger expiry")
	advance(m,2.1)
	check(is_zero_approx(e.slow),"All slow sources expire independently")
	m = sim()
	e = dummy(m,Vector2(10,12))
	m.auto_attack_enabled = true
	m.invulnerable_left = 2
	m.cast("Q")
	advance(m,0.1)
	check(m.invulnerable_left>1.8,"Windup reservation preserves respawn immunity")
	check(is_equal_approx(e.hp,10000),"Basic attack waits until skill windup completes")
	advance(m,0.2)
	check(is_zero_approx(m.invulnerable_left),"Committed ability ends respawn immunity")
	m = sim()
	m.phase = "Preparation"
	m.potions = 2
	m.potion_cd = 12
	var potion_gold = m.gold
	check(m.sell_potion().ok and m.potions==1 and m.gold==potion_gold+90,"Potion can be sold at original90gold refund")
	check(is_equal_approx(m.potion_cd,12),"Potion sale does not reset shared cooldown")
	m.phase = "Combat"
	check(not m.sell_potion().ok and m.potions==1,"Potion cannot be sold during combat")
	m.phase = "Preparation"
	m.save_checkpoint()
	m.gold += 1
	m.save_checkpoint()
	var broken = FileAccess.open(Model.SAVE_PATH,FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	var recovered = Model.new("classic")
	check(recovered.load_checkpoint(),"Corrupt primary recovers validated backup without engine error")
	check(recovered.gold==potion_gold+90,"Backup recovery does not invent currency")
	m = sim()
	m.phase = "Boss"
	m.pos = Vector2(20,12)
	m.spawn_queue.clear()
	m.boss_cooldowns = {"cannon":999.0,"smash":0.0,"debris":999.0}
	m.spawn_enemy("boss",m.pos,false)
	var apex_health = m.hp
	advance(m,1.0/30.0)
	check(m.boss_pattern=="smash" and m.boss_pattern_data.dir.length()>0.99,"Coincident smash locks a deterministic nonzero direction")
	advance(m,1.3)
	check(m.hp<apex_health,"Stationary overlapping hero is hit at the smash apex")
	m = sim("ranger")
	dummy(m,m.pos)
	m._basic_attack()
	check(m.facing.length()>0.99,"Coincident basic attack preserves a usable facing direction")
	var dodge_origin = m.pos
	m.cast("E",m.pos)
	advance(m,0.4)
	check(is_equal_approx(m.pos.distance_to(dodge_origin),4),"Backstep still moves after coincident basic attack")
	print(JSON.stringify({"suite":"model_regression","checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
