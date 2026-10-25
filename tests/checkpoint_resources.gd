extends SceneTree
const Model = preload("res://scripts/siege_model.gd")
var checks = 0
var failures: Array = []
func check(value: bool, name: String):
	checks += 1
	if not value: failures.append(name); printerr("FAIL: ",name)
func write_save(save: Dictionary, suffix: String = ""):
	var f = FileAccess.open(Model.SAVE_PATH+suffix,FileAccess.WRITE)
	f.store_string(JSON.stringify(save)); f.close()
func _init():
	for hero in ["guardian","ranger","arcanist"]:
		var direct = Model.new()
		direct.reset(hero,918)
		var original_hp = direct.hp
		check(direct.buy("armor_plate").ok,"Lawful HP equipment purchase: "+hero)
		check(direct.hp==original_hp and direct.stats.max_hp==original_hp+100,"Buying max HP does not heal: "+hero)
		var loaded = Model.new()
		check(loaded.load_checkpoint(),"Purchase checkpoint loads: "+hero)
		check(loaded.hp==direct.hp and loaded.energy==direct.energy,"Load preserves exact resources: "+hero)
		check(loaded.inventory==direct.inventory and loaded.gold==direct.gold,"Load preserves economy: "+hero)
		check(direct.start_next_wave() and loaded.start_next_wave(),"Both paths can start combat: "+hero)
		check(loaded.hp==direct.hp and loaded.energy==direct.energy,"Ready after load has no resource advantage: "+hero)
		var sold = Model.new()
		check(sold.load_checkpoint() and sold.sell(0).ok,"Lawful sale from checkpoint: "+hero)
		var sold_reload = Model.new()
		check(sold_reload.load_checkpoint() and sold_reload.hp==sold.hp and sold_reload.energy==sold.energy,"Sale checkpoint preserves resources: "+hero)
		for i in 3:
			check(sold_reload.load_checkpoint() and sold_reload.hp==sold.hp,"Repeated load never heals: %s/%d"%[hero,i])
	# Controlled resource fixtures: fractional health/energy and derived-stat bounds.
	var fixture = Model.new()
	fixture.buy("armor_plate")
	fixture.hp = 873.125
	fixture.energy = 37.25
	check(fixture.save_checkpoint(),"Fractional resource fixture saves")
	var valid: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE_PATH))
	check(valid.schema==Model.SAVE_SCHEMA and valid.hp==fixture.hp and valid.energy==fixture.energy,"Current schema stores both exact resources")
	var recovered = Model.new()
	check(recovered.load_checkpoint() and recovered.hp==fixture.hp and recovered.energy==fixture.energy,"Fractional resources round-trip")
	for bad in [{"hp":1000.01},{"hp":0},{"hp":-1},{"energy":100.01},{"energy":-1},{"hp":"900"},{"energy":null}]:
		var damaged = valid.duplicate(true)
		for key in bad: damaged[key]=bad[key]
		write_save(damaged); write_save(damaged,".bak")
		var rejected = Model.new(); rejected.gold=17
		check(not rejected.load_checkpoint() and rejected.gold==17,"Invalid resource state rejects atomically: "+str(bad))
		write_save(valid,".bak")
		check(rejected.load_checkpoint() and rejected.hp==fixture.hp and rejected.energy==fixture.energy,"Valid backup restores exact resources: "+str(bad))
	for old_schema in [1,2,3]:
		var old = valid.duplicate(true)
		old.schema = old_schema; old.erase("hp"); old.erase("energy")
		write_save(old); write_save(old,".bak")
		var old_load = Model.new()
		check(not old_load.load_checkpoint() and old_load.notice.contains("incompatible game version"),"Old schema rejected explicitly: "+str(old_schema))
	print(JSON.stringify({"suite":"checkpoint_resources","checks":checks,"failures":failures,"passed":failures.is_empty(),"save_schema":Model.SAVE_SCHEMA,"fixture_note":"Purchases/sales use normal economy; fractional/bounds cases are controlled save fixtures, not full legal matches."}))
	quit(0 if failures.is_empty() else 1)
