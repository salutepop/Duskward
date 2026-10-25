extends SceneTree
# Controlled lifecycle fixtures, not legal match or difficulty evidence.
const Model = preload("res://scripts/siege_model.gd")
var checks: int = 0
var failures: Array = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: ",label)
func fixture(state: String):
	var m = Model.new()
	m.phase = "Combat"
	m.wave = 4
	m.completed_wave = 3
	m.auto_attack_enabled = false
	m._prepare_hunt()
	m.hunt.state = state
	var lane = m.spawn_enemy("crawler",Vector2(46,20),false)
	lane.speed = 0
	lane.attack_timer = 9999
	return m
func advance(m, seconds: float) -> void:
	for tick in ceili(seconds*30): m.step(1.0/30.0)
func _init() -> void:
	for state in ["waiting","available"]:
		var m = fixture(state)
		var initial_gold: int = m.gold
		m.damage_hero(99999)
		check(m.hunt.state==state,"Death preserves unactivated "+state+" opportunity")
		check(m.metrics.hunt_attempts==0 and m.metrics.hunt_successes==0 and m.gold==initial_gold,"Unactivated death pays/consumes no bounty: "+state)
		advance(m,10.1)
		check(m.hp>0 and m.respawn_left<=0,"Actual respawn completes: "+state)
		check(m.hunt.state=="available","Unactivated opportunity available after respawn: "+state)
		m.pos=m.hunt.pos
		check(m.start_hunt() and m.metrics.hunt_attempts==1,"Player may choose first activation after respawn: "+state)
		m.invulnerable_left=0
		m.damage_hero(99999)
		check(m.hunt.state=="closed" and m.hunt.outcome=="hero_death","Activated death consumes opportunity: "+state)
		check(m.metrics.hunt_gold==0 and m.metrics.hunt_successes==0,"Activated failure never pays bounty: "+state)
		advance(m,10.1)
		m.pos=m.hunt.pos
		check(not m.start_hunt() and m.metrics.hunt_attempts==1,"Second respawn cannot replay consumed camp: "+state)
	for state in ["waiting","available"]:
		var m = fixture(state)
		m.enemies.clear()
		m.step(1.0/30.0)
		check(m.completed_wave==4 and m.hunt.state=="closed" and m.hunt.outcome=="wave_end","Wave-end still expires unactivated "+state+" opportunity")
	var active = fixture("available")
	active.pos=active.hunt.pos
	check(active.start_hunt(),"Timeout fixture activates normally")
	active.hunt.time_left=0.01
	active.step(1.0/30.0)
	check(active.hunt.state=="closed" and active.hunt.outcome=="timeout","Activated timeout remains consumed")
	check(active.metrics.hunt_successes==0 and active.metrics.hunt_gold==0,"Timeout gives no partial reward")
	print(JSON.stringify({"suite":"hunt_opportunity_lifecycle","checks":checks,"failures":failures,"passed":failures.is_empty(),"evidence_type":"controlled state fixtures"}))
	quit(0 if failures.is_empty() else 1)
