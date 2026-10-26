extends SceneTree
## Controlled formatting/layout fixtures, not evidence of a played victory.
var ui
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
 checks += 1
 if not ok: failures.append(label)
func near(a: float,b: float) -> bool: return absf(a-b)<0.00001
func redraw() -> void:
 ui.queue_redraw()
 await process_frame
 await process_frame
func tap(action: String) -> void:
 for hit in ui.hits:
  if str(hit.action)==action:
   var p: Vector2=hit.rect.get_center()
   var e=InputEventScreenTouch.new();e.index=18;e.position=p;e.pressed=true;root.push_input(e,true)
   e=InputEventScreenTouch.new();e.index=18;e.position=p;e.pressed=false;root.push_input(e,true)
   return
 check(false,"missing public target "+action)
func _initialize(): call_deferred("run")
func run() -> void:
 ui=load("res://main.tscn").instantiate();root.add_child(ui);await process_frame
 ui.set_process(false);ui.sound_enabled=false;ui._start_new()
 var summary: Dictionary=ui.result_summary()
 check(summary.damage_rows.is_empty() and near(summary.damage_total,0),"zero damage")
 check(summary.deaths==0 and summary.cannon_interrupts==0,"zero counters")
 ui.model.metrics.base_damage_by_kind={"boss_cannon":6200.25,"crawler":10.5,"siege":90.125,"guard":3.75}
 var original: Dictionary=ui.model.metrics.duplicate(true)
 summary=ui.result_summary()
 check(summary.damage_rows.size()==3,"two main sources plus Other")
 check(summary.damage_rows[0].source=="boss_cannon" and summary.damage_rows[1].source=="siege","descending source order")
 check(summary.damage_rows[2].source=="__other__" and near(summary.damage_rows[2].amount,14.25),"Other preserves omitted amounts")
 check(near(summary.damage_total,6304.625) and summary.damage_includes_overkill,"raw overkill retained, not clamped to6000HP")
 var row_sum: float=0
 for row in summary.damage_rows: row_sum+=float(row.amount)
 check(near(row_sum,summary.damage_total),"row sum equals source total")
 check(original==ui.model.metrics,"summary does not mutate metrics")
 ui.model.metrics.base_damage_by_kind={"siege":30,"guard":30,"crawler":30,"shooter":10}
 summary=ui.result_summary()
 check(summary.damage_rows[0].source=="crawler" and summary.damage_rows[1].source=="guard","ties use stable source ID")
 check(near(summary.damage_rows[2].amount,40),"tie remainder aggregated")
 ui.model.metrics.base_damage_by_kind={"<unknown long source>":9,"zero":0,"negative":-2}
 summary=ui.result_summary()
 check(summary.damage_rows.size()==1 and summary.damage_rows[0].label=="기타 공격","unknown source safe label")
 check(near(summary.damage_total,9),"nonpositive source values omitted")
 ui.model.metrics=JSON.parse_string(JSON.stringify(original))
 check(near(ui.result_summary().damage_total,6304.625),"JSON-loaded metrics preserve values")
 for seconds in [0,59,60,3599,3600,359999]:
  ui.model.elapsed=seconds+0.75
  summary=ui.result_summary()
  check(near(summary.simulation_seconds,seconds+0.75),"unrounded simulation seconds %d"%seconds)
  check(ui.font.get_string_size("게임 시간(시뮬레이션)",HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+ui.font.get_string_size(summary.time_label,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x+16<=348,"time tile fit %d"%seconds)
 check(ui.result_summary().time_label=="99:59:59","long time has hours")
 for seconds in [360000.0,1e12,1e100,1e308]:
  ui.model.elapsed=seconds
  summary=ui.result_summary()
  check(summary.time_label=="100시간+" and summary.simulation_seconds==seconds,"huge valid elapsed preserved without int overflow "+str(seconds))
  check(ui.font.get_string_size("게임 시간(시뮬레이션)",HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+ui.font.get_string_size(summary.time_label,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x+16<=348,"huge elapsed tile fit "+str(seconds))
 for count in [0,1,9999,10000,100000000,1000000000,1000000000000]:
  var value: String=ui._result_number(count)+"회"
  check(ui.font.get_string_size("포격 중단",HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+ui.font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x+16<=348,"large count tile fit %d"%count)
 var caption: String="성채에 가해진 공격 피해 · 초과 피해 포함"
 check(ui.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+ui.font.get_string_size(ui._result_number(1000000000,true),HORIZONTAL_ALIGNMENT_LEFT,-1,22).x+24<=788,"damage caption and amount fit")
 for hero in ui.HERO_IDS:
  ui.model.reset(hero);ui.mode="game"
  for p in [Vector2(2,2),Vector2(47,2),Vector2(2,22),Vector2(47,22),Vector2(24,2),Vector2(24,22),Vector2(2,12),Vector2(47,12),Vector2(24,12),Vector2(-100,-100),Vector2(100,100)]:
   ui.model.pos=p
   var marker: Dictionary=ui.player_marker_geometry()
   check(marker.visible and Rect2(Vector2.ZERO,ui.SIZE).encloses(marker.bounds),"marker clamped "+hero+str(p))
   check(ui.model.pos==p,"marker leaves position unchanged "+hero+str(p))
  ui.model.respawn_left=1
  check(not ui.player_marker_geometry().visible,"marker hidden during respawn "+hero)
 ui.model.reset("guardian");ui.model.completed_wave=10;ui.model.elapsed=447.73
 ui.model.metrics.base_damage_by_kind=original.base_damage_by_kind.duplicate()
 for phase in ["Victory","Defeat"]:
  ui.model.phase=phase;ui.mode="game";ui.modal="result";await redraw()
  check(ui.hits.size()==2,"only result actions "+phase)
  for hit in ui.hits:
   check(Rect2(Vector2.ZERO,ui.SIZE).encloses(hit.rect) and hit.rect.size.y>=78,"result action in bounds and78px "+str(hit.action)+phase)
  check(not ui.hits[0].rect.intersects(ui.hits[1].rect),"result actions do not overlap "+phase)
 tap("restart")
 check(ui.mode=="game" and ui.modal=="" and ui.model.completed_wave==0,"public result restart")
 ui.model.phase="Defeat";ui.modal="result";await redraw();tap("title")
 check(ui.mode=="title" and ui.modal=="" and ui.modal_stack.is_empty(),"public result title")
 print("PRESENTATION_RESULTS ",JSON.stringify({"checks":checks,"failures":failures,"method":"Controlled pure-summary, font-fit, marker-geometry and public-Viewport result-navigation fixtures; not a played victory or pixel readability claim."}))
 ui.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
