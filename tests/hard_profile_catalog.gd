extends SceneTree
const Model=preload("res://scripts/siege_model.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
func _init():
	var expected_counts=[22,28,32,36,40,43,46,49,52,56]
	var expected_budgets=[24,44,50,64,72,84,93,105,112,122]
	var m=Model.new()
	var total_cost:int=0
	var clear_gold:int=0
	for wave in range(1,11):
		var declared:Dictionary=m.tempo.wave_counts[wave-1]
		var count:int=0
		var cost:int=0
		for kind in declared:
			check(m.enemy_types.has(kind),"declared role %s exists in catalog wave%d"%[kind,wave])
			if not m.enemy_types.has(kind): continue
			count+=int(declared[kind])
			cost+=int(declared[kind])*int(m.enemy_types[kind].cost)
		check(count==expected_counts[wave-1],"declared wave count%d"%wave)
		check(cost==expected_budgets[wave-1],"declared wave budget%d"%wave)
		total_cost+=cost
		clear_gold+=roundi((40+5*wave)*float(m.tempo.wave_reward_multiplier))
	check(total_cost==770 and clear_gold==845,"declared total budget and rounded clear gold")
	check(total_cost*6+clear_gold==5465,"total ordinary earned gold5465 excluding start and hunts")
	check(m.tempo.kill_gold_per_cost==6 and m.tempo.kill_xp_per_cost==15,"per-cost gold6 XP15")
	check(m.tempo.wave_counts[0].has("skirmisher") and m.tempo.wave_counts[1].has("shooter") and m.tempo.wave_counts[1].has("guard") and m.tempo.wave_counts[2].has("siege"),"earlier distinct role introductions")
	check(m.tempo.wave_counts[3].siege==2 and m.tempo.wave_counts[7].siege==4,"camp waves retain siege pressure")
	var spawnable=Model.new()
	spawnable.phase="Combat"
	spawnable.wave=1
	for kind in m.enemy_types:
		var e=spawnable.spawn_enemy(kind,Vector2(20,12),false)
		check(not e.is_empty() and float(e.hp)>0 and float(e.max_hp)>0,"catalog role %s spawns"%kind)
	var original=FileAccess.get_file_as_string("res://data/balance.json")
	var parsed=JSON.parse_string(original)
	check(parsed is Dictionary and parsed.has("items"),"balance catalog parses")
	var by_id:Dictionary={}
	if parsed is Dictionary:
		for item in parsed.get("items",[]): by_id[str(item.get("id",""))]=int(item.get("total_price",0))
	var original_items:Dictionary={"iron_blade":200,"focus_stone":200,"armor_plate":200,"spring_gear":200,"ward_cloth":200,"keen_lens":200,"energy_cell":200,"guard_seal":200,"storm_blade":600,"guard_armor":600,"focuser":600,"swift_bow":600,"crit_scope":600,"ward_mantle":600,"reservoir":600,"blood_edge":600,"iron_ring":600,"tempest_glaive":1400,"fortress":1400,"star_core":1400,"falcon_eye":1400,"sanctuary":1400,"sanguine":1400,"healing_potion":150}
	for id in original_items:
		check(by_id.has(id) and int(by_id[id])==int(original_items[id]),"original catalog item %s unchanged"%id)
	print("HARD_PROFILE_CATALOG ",JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
