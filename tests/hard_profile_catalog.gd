extends SceneTree
const Model=preload("res://scripts/siege_model.gd")
var checks:int=0
var failures:Array[String]=[]
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)
func _init():
	var m=Model.new()
	var declared_counts:Array=m.tempo.wave_counts
	var declared_budgets:Array=m.tempo.wave_budgets
	# The active profile must describe the same campaign length as the catalog.
	check(declared_counts.size()==m.data.waves.size(),"profile wave count matches catalog")
	check(m.final_wave==declared_counts.size(),"final wave derives from the active table")
	check(declared_budgets.size()==declared_counts.size(),"every declared wave has a budget")
	var total_cost:int=0
	var clear_gold:int=0
	var seen_roles:Array[String]=[]
	var previous_cost:int=0
	var previous_count:int=0
	for index in range(declared_counts.size()):
		var wave:int=index+1
		var composition:Dictionary=declared_counts[index]
		var count:int=0
		var cost:int=0
		for kind in composition:
			check(m.enemy_types.has(kind),"declared role %s exists in catalog wave%d"%[kind,wave])
			if not m.enemy_types.has(kind): continue
			count+=int(composition[kind])
			cost+=int(composition[kind])*int(m.enemy_types[kind].cost)
			if not seen_roles.has(kind): seen_roles.append(kind)
		check(cost==int(declared_budgets[index]),"declared wave budget%d is %d not %d"%[wave,int(declared_budgets[index]),cost])
		check(cost>=previous_cost and count>=previous_count,"wave%d pressure is non-decreasing"%wave)
		previous_cost=cost
		previous_count=count
		total_cost+=cost
		clear_gold+=roundi((40+5*wave)*float(m.tempo.wave_reward_multiplier))
	check(seen_roles.size()==m.enemy_types.size(),"every catalog role is scheduled in the campaign")
	check(m.tempo.wave_counts[0].has("skirmisher") and m.tempo.wave_counts[1].has("shooter") and m.tempo.wave_counts[1].has("guard") and m.tempo.wave_counts[2].has("siege"),"earlier distinct role introductions")
	check(m.tempo.wave_counts[3].has("flyer") and m.tempo.wave_counts[6].has("healer") and m.tempo.wave_counts[8].has("summoner"),"support roles arrive after their counters")
	check(m.tempo.kill_gold_per_cost==6 and m.tempo.kill_xp_per_cost==12,"per-cost gold6 XP12")
	check(is_equal_approx(float(m.tempo.final_preparation_seconds),float(m.data.phase_rules.final_preparation_seconds)),"final preparation follows the catalog")
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
	print("HARD_PROFILE_CATALOG ",JSON.stringify({"checks":checks,"failures":failures,"waves":declared_counts.size(),"total_cost":total_cost,"clear_gold":clear_gold,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
