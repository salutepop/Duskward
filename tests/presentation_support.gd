extends SceneTree
## Controlled support-state/input/geometry fixtures, not lawful gameplay evidence.
var ui
var checks: int = 0
var failures: Array[String] = []
func check(ok: bool, label: String) -> void:
 checks+=1
 if not ok: failures.append(label)
func _initialize(): call_deferred("run")
func redraw() -> void:
 ui.queue_redraw();await process_frame;await process_frame
func finger(index: int,p: Vector2,pressed: bool) -> void:
 var e=InputEventScreenTouch.new();e.index=index;e.position=p;e.pressed=pressed;root.push_input(e,true)
func touch(p: Vector2) -> void:
 finger(31,p,true);finger(31,p,false)
func camp(state: String) -> void:
 ui.model.phase="Combat";ui.last_phase="Combat";ui.model.wave=4;ui.model.respawn_left=0;ui.model.hp=300
 ui.model.hunt={"state":state,"wave":4,"pos":Vector2(28,6),"time_left":14.2,"return_left":1.4,"reward_claimed":state=="cleared","outcome":"","enemy_ids":[]}
 ui._sync_hunt_presentation()
func eligible_camp() -> void:
 ui.modal="";ui.modal_stack.clear();ui.model.base_hp=ui.model.max_base_hp;ui.model.enemies.clear();ui.model.spawn_queue.clear()
 ui.model.pos=Vector2(28,6);camp("available")
func has_action(action: String) -> bool:
 for hit in ui.hits:
  if str(hit.action)==action:return true
 return false
func run() -> void:
 ui=load("res://main.tscn").instantiate();root.add_child(ui);await process_frame;ui.set_process(false);ui.sound_enabled=false
 ui._start_new()
 check(ui.model.defenders.size()==2,"two local NPCs from model")
 check(ui.support_help_values().seconds==int(ui.model.tempo.hunt.window_seconds),"help timer comes from rules")
 check(ui._t("help.equipment.prep",{"seconds":8}).contains("8초"),"preparation copy is parameterized")
 for state in ["waiting","available","active","cleared","returning","closed"]:
  camp(state);await redraw();var summary=ui.hunt_summary()
  check(summary.visible==(state in ["available","active","cleared","returning"]),"camp visibility "+state)
  check(has_action("hunt_return")== (state in ["active","cleared"]),"return hit only legal states "+state)
  check(summary.pos==Vector2(28,6),"exact model camp position "+state)
  for i in ui.hits.size():
   check(Rect2(Vector2.ZERO,ui.SIZE).encloses(ui.hits[i].rect),"support hit in bounds "+state)
   for j in range(i):check(not ui.hits[i].rect.intersects(ui.hits[j].rect),"support target nonoverlap "+state)
  if summary.visible:
   check(ui.font.get_string_size(summary.title,HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<282,"camp title fits "+state)
   check(ui.font.get_string_size(summary.detail,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x<282,"camp detail fits "+state)
 # A button appearing under a held pointer must not activate on its release.
 eligible_camp();ui.model.pos=Vector2(9,12);ui._sync_hunt_presentation();await redraw()
 finger(7,ui.joystick_center,true)
 ui.model.pos=Vector2(28,6);ui._sync_hunt_presentation();await redraw()
 var start_point=ui.hunt_summary().return_rect.get_center()
 check(has_action("hunt_start") and not has_action("hunt_return"),"nearby available camp paints explicit start only")
 finger(7,start_point,false)
 check(ui.model.hunt.state=="available" and ui.joystick_id==-99,"held joystick release cannot opt in")
 finger(8,ui.skill_center(0),true);await redraw();finger(8,start_point,false)
 check(ui.model.hunt.state=="available" and ui.skill_pointer.is_empty(),"held skill release cannot opt in")
 ui.model.cancel_cast()
 # Every guard is re-evaluated against current state, even before another draw.
 for guard in ["distance","castle_hp","hero_hp","death","capacity","phase","state","modal"]:
  eligible_camp();await redraw()
  check(has_action("hunt_start"),"fresh visible start before stale guard "+guard)
  match guard:
   "distance":ui.model.pos=Vector2(9,12)
   "castle_hp":ui.model.base_hp=ui.model.max_base_hp*0.35
   "hero_hp":ui.model.hp=0
   "death":ui.model.respawn_left=1
   "capacity":
    for i in range(57):ui.model.spawn_enemy("crawler",Vector2(30,12),false)
   "phase":ui.model.phase="Preparation"
   "state":ui.model.hunt.state="closed"
   "modal":ui._open_modal("pause")
  var before=ui.model.metrics.hunt_attempts
  touch(start_point)
  check(ui.model.metrics.hunt_attempts==before,"stale start rejected "+guard)
 eligible_camp();await redraw();ui.model.pos=Vector2(9,12);ui._sync_hunt_presentation()
 check(ui.hits.is_empty(),"range eligibility transition invalidates hit cache")
 eligible_camp();await redraw();var attempts=ui.model.metrics.hunt_attempts
 touch(start_point)
 check(ui.model.hunt.state=="active" and ui.model.metrics.hunt_attempts==attempts+1,"fresh press explicitly starts camp")
 check(ui.model.enemies.size()==4,"one fresh press spawns one camp")
 touch(start_point)
 check(ui.model.enemies.size()==4 and ui.model.metrics.hunt_attempts==attempts+1,"same-frame duplicate start cannot spawn twice")
 ui.model.enemies.clear();ui.model.pos=Vector2(9,12)
 check(ui.support_help_values().count==4,"help enemy count from profile")
 camp("available")
 check(ui.hunt_summary().title.contains("120G") and ui.hunt_summary().title.contains("100XP"),"reward disclosed before entry")
 camp("active")
 check(ui.hunt_summary().return_hint.contains("미완료 보상 포기"),"active return discloses forfeiture")
 check(ui.font.get_string_size(ui.hunt_summary().return_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x<440,"return risk cue fits unused middle space")
 camp("available");ui.model.base_hp=ui.model.max_base_hp*0.35
 check(ui.hunt_summary().entry_blocked,"entry threshold accurately shown")
 check(not ui.hunt_summary().can_return,"available not returnable")
 ui.model.base_hp=ui.model.max_base_hp;camp("active");await redraw()
 var point=ui.hunt_summary().return_rect.get_center();var hp=ui.model.hp;var energy=ui.model.energy
 ui.model.cooldowns.Q=3.0
 touch(point)
 check(ui.model.hunt.state=="returning" and is_equal_approx(ui.model.hunt.return_left,2.0),"public return starts model2s channel")
 check(ui.hits.is_empty(),"channel transition invalidates painted actions")
 check(ui.model.hp==hp and ui.model.energy==energy and ui.model.cooldowns.Q==3.0,"return does not heal/refill/reset cooldown")
 touch(point);check(ui.model.hunt.return_left==2.0,"same-frame stale return cannot reset channel")
 ui._open_modal("pause");camp("active")
 check(not ui._action_allowed("hunt_return",""),"pause context rejects return")
 ui._close_modal();ui.model.respawn_left=3
 check(not ui._action_allowed("hunt_return",""),"dead rejects return")
 camp("cleared");ui.model.base_hp=ui.model.max_base_hp*0.3;await redraw()
 check(ui.hunt_summary().emergency,"emergency exact30percent visible")
 hp=ui.model.hp;energy=ui.model.energy
 touch(point)
 check(ui.model.hunt.state=="closed" and ui.model.pos==ui.model.START,"explicit public emergency return immediate")
 check(ui.model.hp==hp and ui.model.energy==energy,"emergency has no recovery")
 camp("active");await redraw();ui.model.hunt.state="closed";touch(point)
 check(ui.model.hunt.state=="closed","stale return context guarded before redraw")
 ui.model.enemies.clear();ui.model.spawn_queue.clear()
 ui.model.spawn_enemy("crawler",Vector2(30,12),false)
 var hunted=ui.model.spawn_enemy("guard",Vector2(28,6),false);hunted.hunt_enemy=true
 ui.model.spawn_queue.append("crawler")
 check(ui.lane_remaining_count()==2,"lane count excludes camp but includes queued spawn")
 camp("active");ui.model.boss_pattern="smash";ui.model.boss_pattern_left=1
 check(ui._status_content().danger,"urgent danger outranks hunt coach")
 ui.model.boss_pattern_left=0;ui.model.hazards=[]
 ui._open_modal("help");ui._action("help_page","3");await redraw()
 check(ui.help_page==3 and not has_action("hunt_return"),"fourth help tab masks game actions")
 for key in ["help.support.defenders","help.support.camp","help.support.risk","help.support.return"]:
  var content=ui._t(key,ui.support_help_values())
  check(not content.contains("{"),"all help substitutions "+key)
  var width=490.0 if key in ["help.support.defenders","help.support.camp"] else 500.0
  var size=21 if key in ["help.support.defenders","help.support.risk"] else 20
  var lines=1;var line=""
  for word in content.split(" "):
   var candidate=word if line=="" else line+" "+word
   if ui.font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width and line!="":lines+=1;line=word
   else:line=candidate
  check(lines<=(4 if size==21 else 5),"help paragraph bounded "+key)
 check(ui._notice_text("HUNT START  •  The castle battle continues.").contains("사냥"),"hunt notice localized")
 var save_before=FileAccess.get_file_as_bytes(ui.model.SAVE_PATH)
 for stage in ["corner-lower","corner-upper"]:
  ui._prepare_corner_fixture(stage)
  var elapsed_before=ui.model.elapsed
  ui._process(1.0)
  await redraw()
  check(ui.diagnostic_fixture and not ui.is_processing_input(),"fixture disables public input "+stage)
  check(ui.model.elapsed==elapsed_before,"fixture freezes simulation "+stage)
  check(ui.qa_controller==null,"fixture not QA autoplay "+stage)
  ui._notification(ui.NOTIFICATION_APPLICATION_FOCUS_OUT)
  ui._notification(ui.NOTIFICATION_APPLICATION_FOCUS_IN)
  check(ui.modal=="","frozen fixture survives capture focus change "+stage)
  check(ui.skill_center(3 if stage=="corner-lower" else 1).distance_to(ui._world(ui.model.pos))<15,"fixture actually occupies control center "+stage)
  check(ui.model.hazards.size()==1 and ui.model.enemies[0].telegraph>0,"fixture hostile warnings present "+stage)
  check(FileAccess.get_file_as_bytes(ui.model.SAVE_PATH)==save_before,"fixture never writes checkpoint "+stage)
 print("PRESENTATION_SUPPORT ",JSON.stringify({"checks":checks,"failures":failures,"controlled_state_injection":true,"pixel_acceptance":false}))
 ui.queue_free();await process_frame;await create_timer(0.25).timeout;quit(0 if failures.is_empty() else 1)
