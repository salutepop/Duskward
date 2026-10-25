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
	var total_cost:int=0
	var clear_gold:int=0
	for wave in range(1,11):
		var m=Model.new();m.completed_wave=wave-1;m.wave=wave-1
		check(m.start_next_wave(),"start fixture wave%d"%wave)
		var actual:Dictionary={}
		for enemy in m.enemies:actual[enemy.kind]=int(actual.get(enemy.kind,0))+1
		for kind in m.spawn_queue:actual[kind]=int(actual.get(kind,0))+1
		var count:int=0;var cost:int=0
		for kind in actual:
			count+=actual[kind];cost+=actual[kind]*int(m.enemy_types[kind].cost)
		check(count==expected_counts[wave-1],"declared wave count%d"%wave)
		check(cost==expected_budgets[wave-1],"declared wave budget%d"%wave)
		check(actual.size()==m.tempo.wave_counts[wave-1].size(),"no extra role wave%d"%wave)
		for kind in actual:check(actual[kind]==int(m.tempo.wave_counts[wave-1][kind]),"kind count %d%s"%[wave,kind])
		total_cost+=cost;clear_gold+=roundi((40+5*wave)*float(m.tempo.wave_reward_multiplier))
	check(total_cost==770 and clear_gold==845,"declared total budget and rounded clear gold")
	check(total_cost*6+clear_gold==5465,"total ordinary earned gold5465 excluding start and hunts")
	var m=Model.new()
	check(m.tempo.kill_gold_per_cost==6 and m.tempo.kill_xp_per_cost==15,"per-cost gold6 XP15")
	check(m.tempo.wave_counts[0].has("skirmisher") and m.tempo.wave_counts[1].has("shooter") and m.tempo.wave_counts[1].has("guard") and m.tempo.wave_counts[2].has("siege"),"earlier distinct role introductions")
	check(m.tempo.wave_counts[3].siege==2 and m.tempo.wave_counts[7].siege==4,"camp waves retain siege pressure")
	var original=FileAccess.get_file_as_string("res://data/balance.json")
	check(original.sha256_text()=="bffeade64cec5b7ef72685da6fb3895f5972f3b1b0de84bc4387cf5c377f171b","original design balance catalog unchanged")
	print("HARD_PROFILE_CATALOG ",JSON.stringify({"checks":checks,"failures":failures,"fixture_only":true}))
	quit(0 if failures.is_empty() else 1)
