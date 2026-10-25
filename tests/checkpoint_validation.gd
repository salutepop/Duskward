extends SceneTree
const Model = preload("res://scripts/siege_model.gd")
var checks = 0
var failures: Array = []
func check(value: bool, name: String):
	checks += 1
	if not value: failures.append(name); printerr("FAIL: ",name)
func write_save(save: Dictionary, suffix: String = ""):
	var f = FileAccess.open(Model.SAVE_PATH+suffix,FileAccess.WRITE)
	f.store_string(JSON.stringify(save))
	f.close()
func _init():
	var original = Model.new()
	check(original.save_checkpoint(),"Valid checkpoint created")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE_PATH))
	var cases: Array = []
	for map_key in ["casts_by_slot","damage_by_source","hits_by_source","base_damage_by_kind","hero_damage_by_kind"]:
		for bad in [[],{},"not-a-number",null,-1]:
			var broken = valid.duplicate(true)
			broken.metrics[map_key] = {"basic":bad}
			cases.append({"name":map_key+"="+str(bad),"save":broken})
	for field in ["completed_wave","gold","xp","level","potions","seed"]:
		var broken = valid.duplicate(true)
		broken[field] = 1.5
		cases.append({"name":"fractional "+field,"save":broken})
	for broken_history in [[null],[{}],[{"wave":1,"time":0,"base_hp":6000,"level":1,"gold_earned":[]}]]:
		var broken = valid.duplicate(true)
		broken.metrics.waves = broken_history
		cases.append({"name":"malformed wave history","save":broken})
	var extra_cooldown = valid.duplicate(true)
	extra_cooldown.cooldowns.X = []
	cases.append({"name":"unknown malformed cooldown","save":extra_cooldown})
	for fixture in cases:
		write_save(fixture.save)
		write_save(fixture.save,".bak")
		var rejected = Model.new()
		rejected.gold = 321
		check(not rejected.load_checkpoint(),"Reject "+fixture.name)
		check(rejected.gold==321 and rejected.phase=="Preparation","Atomic state on rejection: "+fixture.name)
		write_save(valid,".bak")
		var recovered = Model.new()
		check(recovered.load_checkpoint() and recovered.notice.contains("recovered"),"Backup recovery: "+fixture.name)
		recovered.phase = "Combat"
		var enemy = recovered.spawn_enemy("crawler",recovered.pos+Vector2(1,0))
		recovered._basic_attack()
		recovered.step(1.0/30.0)
		check(enemy.hp<enemy.max_hp and recovered.metrics.hits_by_source.basic==1,"Recovered state can fight: "+fixture.name)
	# Unknown metadata is ignored rather than merged into live simulation state.
	var forward_metadata = valid.duplicate(true)
	forward_metadata.metrics.unknown_future_metadata = {"value":[]}
	write_save(forward_metadata)
	var future = Model.new()
	check(future.load_checkpoint() and not future.metrics.has("unknown_future_metadata"),"Unknown metrics do not enter live state")
	# Recovery must not replace a known-good backup with the corrupt primary.
	var damaged = valid.duplicate(true)
	damaged.metrics.damage_by_source = {"basic":[]}
	write_save(damaged)
	write_save(valid,".bak")
	var chain = Model.new()
	check(chain.load_checkpoint(),"Recovery chain begins from valid backup")
	chain.gold = 123
	check(chain.save_checkpoint(),"Recovered state can save a new primary")
	write_save(damaged)
	var second_recovery = Model.new()
	check(second_recovery.load_checkpoint(),"Known-good backup survives recovery followed by save")
	check(second_recovery.gold==int(valid.gold),"Surviving backup retains its original valid economy")
	print(JSON.stringify({"suite":"checkpoint_validation","checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
