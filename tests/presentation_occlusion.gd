extends SceneTree
## Pure geometry plus real scene input/steps. No pixel, FPS, or playfeel claim.
var ui
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool,label: String) -> void:
 checks+=1
 if not ok: failures.append(label)
func _initialize():call_deferred("run")
func redraw() -> void:
 ui.queue_redraw();await process_frame;await process_frame
func finger(index: int,p: Vector2,pressed: bool) -> void:
 var event=InputEventScreenTouch.new();event.index=index;event.position=p;event.pressed=pressed;root.push_input(event,true)
func drag(index: int,p: Vector2) -> void:
 var event=InputEventScreenDrag.new();event.index=index;event.position=p;root.push_input(event,true)
func clean() -> void:
 ui.model.reset("guardian");ui.mode="game";ui.modal="";ui.model.phase="Combat";ui.last_phase="Combat"
 ui.model.pos=Vector2(24,12);ui.model.enemies.clear();ui.model.hazards.clear();ui.model.projectiles.clear();ui.model.spawn_queue.clear()
 ui.model.boss_pattern_left=0;ui._release_controls()
func run() -> void:
 ui=load("res://main.tscn").instantiate();root.add_child(ui);await process_frame;ui.set_process(false);ui.sound_enabled=false
 clean();await redraw()
 var normal_hits=ui.hits.duplicate(true)
 for id in ui.occlusion_paint_state():
  var item=ui.occlusion_paint_state()[id]
  check(not item.occluded and item.backing_alpha==1 and item.ink_alpha==1 and item.text_alpha==1,"normal paint preserved "+id)
 var cases={"R":Vector2(44.2,22),"W":Vector2(44.2,18.3),"stick":Vector2(4.875,21.8),"hud_castle":Vector2(24,2.5),"hud_hero":Vector2(7,3),"potion":Vector2(34.5,22)}
 for id in cases:
  clean();ui.model.pos=cases[id];var original=ui.model.pos;var hp=ui.model.hp
  var state=ui.occlusion_paint_state()[id]
  check(state.occluded and "hero" in state.sources,"actor overlap recognized "+id)
  check(state.backing_alpha<0.2 and state.ink_alpha>0 and state.ink_alpha<0.6,"backing and large glyph both fade "+id)
  check(state.text_alpha>=0.8,"small state text retains stronger ink "+id)
  check(ui.model.pos==original and ui.model.hp==hp,"pure helper leaves model unchanged "+id)
  await redraw()
  check(ui.hits==normal_hits,"paint never changes hit metadata "+id)
  check(ui.ui_paint==Vector3.ONE,"paint scope restored after frame "+id)
 clean();var enemy=ui.model.spawn_enemy("guard",Vector2(44.2,22),false);ui.model.selected_target_id=enemy.id
 check("enemy" in ui.occlusion_paint_state().R.sources,"enemy including selected target fades control")
 clean();ui.model.hazards=[{"pos":Vector2(44.2,22),"radius":2.2,"warning":1.0,"life":5.0,"damage":30.0,"kind":"debris"}]
 check("hazard" in ui.occlusion_paint_state().R.sources,"warning footprint fades control without nearby actor")
 ui.model.hazards[0].warning=0
 check("hazard" in ui.occlusion_paint_state().R.sources,"active hazard also fades control")
 clean();enemy=ui.model.spawn_enemy("guard",Vector2(30,12),false);enemy.telegraph=0.3;enemy.attack_pos=Vector2(44.2,22)
 check("enemy_warning" in ui.occlusion_paint_state().R.sources,"locked attack point has own footprint")
 clean();ui.model.projectiles=[{"pos":Vector2(41,22),"previous":Vector2(40.5,22),"velocity":Vector2(16,0),"hostile":true,"radius":0.3,"life":2.0}]
 var original_shot=ui.model.projectiles[0].duplicate(true)
 check("hostile_projectile" in ui.occlusion_paint_state().R.sources,"projectile trail and lookahead prevent point blink")
 check(ui.model.projectiles[0]==original_shot,"projectile footprint does not simulate shot")
 ui.model.projectiles[0].hostile=false
 check(not ui.occlusion_paint_state().R.occluded,"friendly projectile does not fade unrelated controls")
 clean();ui.model.boss_pattern="smash";ui.model.boss_pattern_left=1;ui.model.boss_pattern_data={"pos":Vector2(42,16),"dir":Vector2.DOWN,"radius":7.0,"duration":1.2}
 check("boss_warning" in ui.occlusion_paint_state().R.sources,"locked boss cone footprint")
 # Public two-pointer input stays captured as ordinary model steps cross overlap.
 clean();ui.model.pos=Vector2(40.8,22);ui.model.spawn_enemy("crawler",Vector2(46,12),false);await redraw()
 check(not ui.occlusion_paint_state().R.occluded,"movement starts outside R paint footprint")
 finger(7,ui.joystick_center+Vector2(61,0),true)
 finger(8,ui.skill_center(0),true);drag(8,ui.skill_center(0)+Vector2(-70,-40))
 var before=ui.model.pos
 for i in range(12):ui._process(1.0/30.0)
 await redraw()
 check(ui.model.pos.x>before.x and is_equal_approx(ui.model.pos.y,before.y),"normal stick moves through world projection")
 check(ui.occlusion_paint_state().R.occluded,"ordinary movement enters overlapping paint")
 check(ui.joystick_id==7 and int(ui.skill_pointer.id)==8,"opacity transition preserves both pointer owners")
 var target=ui._skill_target()
 var screen_direction=(ui._world(target)-ui._world(ui.model.pos)).normalized()
 check(screen_direction.dot(Vector2(-70,-40).normalized())>0.999,"aim remains aligned while moving and faded")
 var energy=ui.model.energy;var reserved=ui.model.energy_reserved
 drag(8,ui._skill_cancel_rect().get_center());finger(8,ui._skill_cancel_rect().get_center(),false)
 check(ui.skill_pointer.is_empty() and ui.model.energy==energy and ui.model.energy_reserved==reserved,"faded aim cancellation spends no resource")
 finger(7,Vector2(-50,-50),false)
 check(ui.joystick_id==-99 and ui.joystick==Vector2.ZERO,"outside release remains safe after fading")
 ui.model.pos=Vector2(24,12);ui.model.enemies.clear();await redraw()
 check(not ui.occlusion_paint_state().R.occluded,"paint returns immediately without smoothing or input delay")
 # All ability states render on the same geometry; raster legibility remains external.
 for state in ["locked","cooldown","no_mana","ready"]:
  clean();ui.model.pos=Vector2(44.2,22)
  ui.model.level=1 if state=="locked" else 12;ui.model.recalculate_stats()
  ui.model.cooldowns.R=3.2 if state=="cooldown" else 0
  ui.model.energy=0 if state=="no_mana" else ui.model.stats.max_energy
  await redraw();check(ui.hits==normal_hits,"faded state preserves actions "+state)
 # The four explicitly labeled debug fixtures are frozen and retain original points.
 for stage in ui.DIAGNOSTIC_FIXTURES:
  ui._prepare_corner_fixture(stage);await redraw()
  var id={"corner-lower":"R","corner-upper":"W","left-stick":"stick","top-hud":"hud_castle"}[stage]
  check(ui.occlusion_paint_state()[id].occluded,"diagnostic actually intersects "+stage)
  check(ui.diagnostic_fixture and not ui.is_processing_input(),"diagnostic opt-in input disabled "+stage)
 print("PRESENTATION_OCCLUSION ",JSON.stringify({"checks":checks,"failures":failures,"controlled_fixture":true,"pixel_acceptance":false,"physical_phone_acceptance":false}))
 ui.queue_free();await process_frame;await create_timer(0.25).timeout;quit(0 if failures.is_empty() else 1)
