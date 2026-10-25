extends SceneTree
const Model=preload("res://scripts/siege_model.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
func smash(m,center:Vector2,direction:Vector2):
	m.boss_pattern="smash";m.boss_pattern_data={"pos":center,"dir":direction,"radius":7.0}
	m._resolve_boss_pattern({})
func _init():
	var m=Model.new();m.phase="Boss";m.pos=m.defenders[0].pos
	smash(m,Vector2(12,12),Vector2.LEFT)
	check(m.hp<900,"hero positive smash control")
	check(is_equal_approx(m.defenders[0].hp,80) and is_equal_approx(m.defenders[1].hp,80),"both defenders take same raw cone damage")
	m=Model.new();m.defenders[0].pos=Vector2(12,12);m.defenders[1].pos=Vector2(20,12)
	smash(m,Vector2(12,12),Vector2.LEFT)
	check(m.defenders[0].hp==80,"defender apex included")
	check(m.defenders[1].hp==260,"behind and outside cone safe")
	m=Model.new();m.defenders[0].pos=Vector2(7,4)
	smash(m,Vector2(12,12),Vector2.LEFT)
	check(m.defenders[0].hp==260,"side/outside distance safe")
	m=Model.new();m.pos=m.defenders[0].pos
	m.hazards=[{"pos":m.defenders[0].pos,"radius":2.2,"warning":1.0,"life":5.0,"damage":35.0,"kind":"debris"}]
	m._step_hazards(0.5)
	check(m.defenders[0].hp==260 and m.hp==900,"warning does not damage hero or ally")
	m._step_hazards(0.6);m._step_hazards(0.1)
	check(is_equal_approx(m.defenders[0].hp,256.5),"active debris damages ally raw3.5")
	check(m.hp<900 and m.defenders[1].hp==260,"hero positive and outside ally negative control")
	m.defenders[0].hp=3;m._step_hazards(0.1)
	check(m.defenders[0].hp==0 and m.metrics.defender_deaths==1 and m.defenders[0].respawn_left==22,"hazard kills and schedules normal respawn")
	m._step_hazards(0.1);check(m.metrics.defender_deaths==1,"dead defender not killed twice")
	m=Model.new();m.boss_pattern="cannon";m._resolve_boss_pattern({})
	check(m.base_hp==5760 and m.defenders[0].hp==260 and m.defenders[1].hp==260,"cannon remains castle-only")
	print("DEFENDER_BOSS_GEOMETRY ",JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
