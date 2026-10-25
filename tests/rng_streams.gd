extends SceneTree
const Model = preload("res://scripts/siege_model.gd")
var checks = 0
var failures: Array = []
func check(value: bool, name: String):
	checks += 1
	if not value: failures.append(name); printerr("FAIL: ",name)
func _init():
	var a = Model.new()
	var b = Model.new()
	a.reset("guardian",12345)
	b.reset("guardian",12345)
	check(a.rng.state==b.rng.state and a.spawn_rng.state==b.spawn_rng.state,"Equal seeds reproduce both stream states")
	check(a.rng.state!=a.spawn_rng.state,"Spawn/combat initial streams are distinct")
	for i in 1000: b.rng.randf()
	check(a.spawn_rng.state==b.spawn_rng.state,"Combat draws do not change spawn stream")
	check(a.camp_rng.state==b.camp_rng.state,"Combat draws do not change camp stream")
	a.start_next_wave()
	b.start_next_wave()
	check(a.spawn_queue==b.spawn_queue,"Wave order invariant under unrelated combat RNG draws")
	a.auto_attack_enabled=false
	b.auto_attack_enabled=false
	var a_births: Array=[]
	var b_births: Array=[]
	for i in 300:
		var old_a=a.enemies.size()
		var old_b=b.enemies.size()
		a.step(1.0/30.0,Vector2.ZERO)
		b.step(1.0/30.0,Vector2.ZERO)
		if a.enemies.size()>old_a: a_births.append({"kind":a.enemies[-1].kind,"pos":a.enemies[-1].pos,"attack_timer":a.enemies[-1].attack_timer})
		if b.enemies.size()>old_b: b_births.append({"kind":b.enemies[-1].kind,"pos":b.enemies[-1].pos,"attack_timer":b.enemies[-1].attack_timer})
	check(a_births.size()>8,"Actual scheduler produced a meaningful spawn sample")
	check(a_births==b_births,"Actual spawn kinds, positions and attack offsets invariant under combat draws")
	check(a.spawn_rng.state==b.spawn_rng.state,"Scheduler preserves equivalent spawn stream position")
	check(a.rng.state!=b.rng.state,"Independent combat stream remains independently advanced")
	a.phase="Preparation"
	a.enemies.clear()
	a.spawn_queue.clear()
	check(a.save_checkpoint(),"Current-schema checkpoint saves")
	var saved=JSON.parse_string(FileAccess.get_file_as_string(Model.SAVE_PATH))
	check(saved.schema==Model.SAVE_SCHEMA and saved.has("spawn_rng_state") and saved.has("camp_rng_state"),"Checkpoint explicitly includes both states and current schema")
	var restored=Model.new()
	check(restored.load_checkpoint(),"Current-schema checkpoint loads")
	for i in 10:
		check(a.rng.randi()==restored.rng.randi(),"Combat RNG continuation %d"%i)
		check(a.spawn_rng.randi()==restored.spawn_rng.randi(),"Spawn RNG continuation %d"%i)
		check(a.camp_rng.randi()==restored.camp_rng.randi(),"Camp RNG continuation %d"%i)
	saved.schema=1
	saved.erase("spawn_rng_state")
	for path in [Model.SAVE_PATH,Model.SAVE_PATH+".bak"]:
		var file=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(saved))
		file.close()
	var legacy=Model.new()
	check(not legacy.load_checkpoint(),"Legacy schema1 does not silently invent new stream state")
	check(legacy.notice.contains("incompatible game version"),"Legacy rejection explains version incompatibility")
	legacy.reset("ranger",91)
	check(legacy.start_next_wave(),"Normal fresh-start recovery remains available after legacy rejection")
	print(JSON.stringify({"suite":"rng_streams","checks":checks,"failures":failures,"passed":failures.is_empty(),"save_schema":Model.SAVE_SCHEMA}))
	quit(0 if failures.is_empty() else 1)
