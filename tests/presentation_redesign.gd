extends SceneTree
## UI-only scene-state and geometry fixtures. Actual Android pixels remain required.
var ui
var checks=0
var failures=[]
var states=[]
func check(ok,label):
 checks+=1
 if not ok: failures.append(label)
func capture(label):
 ui.queue_redraw();await process_frame;await process_frame
 var targets=ui.hits.duplicate(true)
 for i in targets.size():
  check(Rect2(Vector2.ZERO,ui.SIZE).encloses(targets[i].rect),label+" target in bounds "+str(targets[i].action))
  for j in range(i): check(not targets[i].rect.intersects(targets[j].rect),label+" hit overlap "+str(i)+"/"+str(j))
 states.append({"state":label,"targets":targets.size()})
func luminance(color):
 var c=color.srgb_to_linear()
 return c.r*0.2126+c.g*0.7152+c.b*0.0722
func contrast(a,b):
 var x=luminance(a);var y=luminance(b)
 return (maxf(x,y)+0.05)/(minf(x,y)+0.05)
func _initialize():call_deferred("run")
func run():
 ui=load("res://main.tscn").instantiate();root.add_child(ui);await process_frame;ui.set_process(false);ui.sound_enabled=false
 check(ui.MAP==Rect2(0,40,1280,640),"uniform world projection")
 check(is_equal_approx(ui.MAP.size.x/48,ui.MAP.size.y/24),"world circles preserve radius")
 check(ui.font.resource_path.ends_with("Pretendard-Medium.otf") and ui.heading_font.resource_path.ends_with("Pretendard-SemiBold.otf"),"bundled Korean family files")
 check(ui.font.get_font_weight()==500 and ui.heading_font.get_font_weight()==600,"actual medium/semibold weight metadata")
 check(not ui.font.allow_system_fallback and not ui.heading_font.allow_system_fallback,"no device font fallback")
 check(ui.skill_center(0)==Vector2(1056,528) and ui.skill_center(3)==Vector2(1178,638),"coordinated12px upward cluster shift")
 for hero in ui.HERO_IDS:
  for title in ui.SKILL_NAMES[hero]:check(ui.font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,20).x<=94,"20px backed skill name fits "+title)
 check(ui._t("hud.initial_wave")=="전투 준비","no initial internal wave0 label")
 for fill in [ui.HP_FILL,ui.MANA_FILL,ui.CASTLE_FILL,ui.DANGER_FILL]:
  check(contrast(ui.PAPER,fill)>=4.5,"nominal small bar-text contrast >=4.5 "+str(fill))
  check(contrast(fill,ui.BAR_EMPTY)>=3,"nominal fill/empty boundary >=3 "+str(fill))
 check(contrast(ui.BAR_EDGE,ui.BAR_EMPTY)>=3 and contrast(ui.BAR_EDGE,ui.PANEL)>=3,"bar edge separated from empty and panel")
 for pair in [["guardian","기사"],["ranger","궁수"],["arcanist","마법사"]]:
  ui.selected_hero=pair[0];check(ui.HERO_NAMES[pair[0]]==pair[1],"catalog hero "+pair[0]);await capture("title_"+pair[0])
  check(ui.font.get_string_size(ui.HERO_BLURBS[pair[0]],HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<860,"hero description at most two lines")
 ui._start_new();await capture("preparation")
 var marker=ui.player_marker_geometry()
 check(marker.shape=="ground_ellipse" and marker.radii==Vector2(18,7),"thin ground-contact ellipse")
 check(marker.center==ui._world(ui.model.pos)+Vector2(0,7),"ellipse aligned to sprite foot anchor")
 check(ui._cooldown_text(3.2)=="4" and ui._cooldown_text(0.7)=="0.7","cooldown integer except subsecond")
 ui._open_modal("shop");await capture("shop0");ui._action("shop_page","1");await capture("shop1")
 for item in ui.model.data.items:
  check(ui._item_name(item.id)!=str(item.id) and not ui._item_name(item.id).begins_with("item."),"catalog item "+str(item.id))
  ui._action("item",item.id);await capture("detail_"+str(item.id))
 ui._close_modal();ui._open_modal("pause");await capture("pause")
 ui._open_modal("help")
 for page in range(4):
  ui._action("help_page",str(page));await capture("help"+str(page))
 ui._close_modal();ui._close_modal()
 for hero in ui.HERO_IDS:
  ui.selected_hero=hero;ui._start_new();ui.model.phase="Combat";ui.model.level=12;ui.model.recalculate_stats();ui.last_phase="Combat"
  for slot in ["Q","W","E","R"]:ui.model.cooldowns[slot]=3.2
  await capture("cooldowns_"+hero)
  for slot in ["Q","W","E","R"]:ui.model.cooldowns[slot]=0
  ui.model.energy=0;await capture("no_mana_"+hero)
 ui.model.phase="Boss";ui.model.spawn_enemy("boss",Vector2(24,12),false);ui.model.boss_pattern="smash";ui.model.boss_pattern_left=0.7;ui.model.boss_pattern_data={"pos":Vector2(24,12),"dir":Vector2.RIGHT,"radius":7.0,"duration":1.2}
 await capture("boss_warning")
 check(ui._status_content().danger,"boss threat wins status")
 for phase in ["Victory","Defeat"]:
  ui.model.phase=phase;ui.modal="result";await capture(phase)
 ui.mode="title";ui.modal="credits";await capture("credits")
 print("PRESENTATION_REDESIGN ",JSON.stringify({"checks":checks,"failures":failures,"states":states,"pixel_acceptance":false}))
 ui.queue_free();await process_frame;quit(0 if failures.is_empty() else 1)
