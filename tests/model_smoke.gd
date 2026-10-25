extends SceneTree
const Model = preload("res://scripts/siege_model.gd")
func _init():
	var outcomes: Array = []
	var failed: bool = false
	for hero in ["guardian","ranger","arcanist"]:
		var m = Model.new()
		m.reset(hero,12345)
		var purchase: Dictionary = m.buy("focus_stone" if hero=="arcanist" else "iron_blade")
		if not purchase.ok or not m.start_next_wave(): failed=true
		for frame in 2700:
			if m.completed_wave>=1 or m.phase=="Defeat": break
			var direction: Vector2 = Vector2.ZERO
			var nearest: Dictionary = {}
			var best: float = INF
			for enemy in m.enemies:
				var distance: float = m.pos.distance_to(enemy.pos)
				if enemy.hp>0 and distance<best:
					nearest=enemy;best=distance
			if not nearest.is_empty() and best>float(m.stats.attack_range)*0.85:
				direction=(nearest.pos-m.pos).normalized()
			m.cast("Q")
			m.step(1.0/30.0,direction)
		var ok: bool = m.completed_wave==1 and m.base_hp>0
		failed = failed or not ok
		outcomes.append({"hero":hero,"passed":ok,"time":m.elapsed,"kills":m.metrics.kills,"deaths":m.metrics.deaths,"base_hp":m.base_hp,"ruleset":m.ruleset,"tempo_version":m.tempo.version})
	print("FIRST_WAVE_SMOKE ",JSON.stringify({"outcomes":outcomes,"normal_economy":true,"state_grants":false}))
	quit(1 if failed else 0)
