extends SceneTree
## Growth points, stat allocation and skill ranks. Controlled model fixtures.
const Model = preload("res://scripts/siege_model.gd")
var checks:int=0
var failures:Array[String]=[]

func check(ok:bool,label:String):
	checks+=1
	if not ok: failures.append(label)

func cast_damage(m, slot:String) -> float:
	m.metrics.damage_dealt=0.0
	m.enemies=[]
	var e: Dictionary = m.spawn_enemy("crawler",m.pos+Vector2(2,0),false)
	e.hp=1000000.0; e.max_hp=1000000.0; e.armor=0.0
	m._execute_cast({"slot":slot,"aim":m.pos+Vector2(2,0),"dir":Vector2.RIGHT,"origin":m.pos})
	return float(m.metrics.damage_dealt)

func _init():
	var m=Model.new()
	check(m.level==1 and m.unspent_points==0,"a new hero starts with no growth points")
	check(m.skill_rank("Q")==1 and m.max_skill_rank()==5,"skills start at rank one of five")
	# Level thresholds are cumulative; three level ups must grant three points.
	m.xp=510
	m._update_level()
	check(m.level==4,"500 xp reaches level four")
	check(m.unspent_points==3,"each level up grants exactly one point")
	# Stats: one point buys three stat points, folded into derived stats.
	var ad_before: float = float(m.stats.ad)
	var armor_before: float = float(m.stats.armor)
	var spend: Dictionary = m.spend_point("stat","str")
	check(spend.get("ok",false) and spend.get("amount",0)==3,"a point buys three stat points")
	check(int(m.stat_points.str)==3 and m.unspent_points==2,"strength allocation is recorded")
	check(is_equal_approx(float(m.stats.ad),ad_before+3.0*1.8),"strength raises attack damage")
	check(is_equal_approx(float(m.stats.armor),armor_before+3.0*0.5),"strength raises armor")
	# Vitality grants the new headroom immediately.
	var hp_before: float = m.hp
	var max_before: float = float(m.stats.max_hp)
	m.spend_point("stat","vit")
	check(is_equal_approx(float(m.stats.max_hp),max_before+48.0),"vitality raises max hp")
	check(is_equal_approx(m.hp,hp_before+48.0),"vitality grants the new hp immediately")
	# Skill ranks: damage scales, cooldown shrinks, and the cap holds.
	var base_damage: float = cast_damage(m,"Q")
	check(m.unspent_points==1,"one point remains")
	check(m.spend_point("skill","Q").get("ok",false),"a point buys a skill rank")
	check(m.skill_rank("Q")==2,"skill rank increases")
	check(is_equal_approx(m.skill_power("Q"),1.15),"rank two adds fifteen percent damage")
	check(is_equal_approx(m.skill_cooldown_scale("Q"),0.94),"rank two trims six percent cooldown")
	var ranked_damage: float = cast_damage(m,"Q")
	check(is_equal_approx(ranked_damage,base_damage*1.15),"ranked damage is applied in combat")
	# Exhausted, locked and capped spends are refused with a reason.
	var refused: Dictionary = m.spend_point("skill","W")
	check(not refused.get("ok",true) and str(refused.get("reason",""))=="no_points","spending without points is refused")
	m.unspent_points=20
	check(str(m.can_spend_point("skill","R").get("reason",""))=="locked","locked skills cannot be ranked")
	for i in 10: m.spend_point("skill","Q")
	check(m.skill_rank("Q")==5,"ranks stop at five")
	check(str(m.can_spend_point("skill","Q").get("reason",""))=="max_rank","a capped skill reports max rank")
	check(is_equal_approx(m.skill_power("Q"),1.6),"rank five is sixty percent damage")
	check(is_equal_approx(m.skill_cooldown_scale("Q"),0.76),"rank five trims twenty four percent cooldown")
	check(not m.can_spend_point("stat","luck").get("ok",true),"unknown stats are refused")
	# Checkpoint round trip keeps points, ranks and the derived stats in sync.
	var s=Model.new()
	s.phase="Preparation"; s.completed_wave=2; s.wave=2
	s.xp=510; s._update_level()
	s.spend_point("stat","agi")
	s.spend_point("skill","Q")
	s.save_checkpoint()
	var loaded=Model.new()
	check(loaded.load_checkpoint(),"a growth checkpoint loads")
	check(int(loaded.stat_points.agi)==3,"allocated stats survive a save")
	check(loaded.skill_rank("Q")==2,"skill ranks survive a save")
	check(loaded.unspent_points==1,"unspent points survive a save")
	check(loaded.hp<=float(loaded.stats.max_hp),"loaded hp respects the grown ceiling")
	print("GROWTH_PROGRESSION ",JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
