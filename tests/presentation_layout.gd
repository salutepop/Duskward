extends SceneTree
## Headless presentation geometry/font audit, not physical-phone readability proof.
## Exercises real scene redraw and ordinary UI transactions in isolated test user data.
var failures: Array = []
var checks: int = 0
var states: Array = []
var main
func check(ok: bool, label: String):
 checks += 1
 if not ok: failures.append(label)
func _initialize(): call_deferred("audit")
func capture(label: String):
 main.queue_redraw()
 await process_frame
 var targets: Array = main.hits.duplicate(true)
 var whole=Rect2(Vector2.ZERO,main.SIZE)
 for i in range(targets.size()):
  var a: Dictionary=targets[i]
  check(whole.encloses(a.rect),label+": target inside viewport "+str(a.action))
  for j in range(i):
   check(not a.rect.intersects(targets[j].rect),label+": distinct touch targets "+str(i)+"/"+str(j))
  var primary: bool=str(a.action) in ["start","buy","sell","sell_potion","next"] or (str(a.action)=="modal" and str(a.get("value",""))=="pause")
  if primary:
   check(a.rect.size.y>=78,label+": primary target >=78 logical px "+str(a.action))
   check(a.rect.size.x>=78,label+": primary target width >=78 "+str(a.action))
 states.append({"state":label,"target_count":targets.size()})
func audit():
 main=load("res://scripts/main.gd").new()
 root.add_child(main)
 await process_frame
 main.set_process(false)
 main.sound_enabled=false
 await capture("title")
 for id in main.HERO_IDS:
  check(main.font.get_string_size(main.HERO_BLURBS[id],HORIZONTAL_ALIGNMENT_LEFT,-1,22).x<=860,"portrait description fits two430px lines "+id)
 main._start_new()
 await capture("preparation")
 main._open_modal("shop")
 await capture("shop_page_0")
 main._action("shop_page","1")
 await capture("shop_page_1")
 main._action("item","iron_blade")
 main._action("buy","")
 main._action("slot","0")
 await capture("shop_equipment_sell")
 check(main.selected_slot==0,"equipment selection exists before restart")
 main._start_new()
 check(main.selected_slot==-1 and main.shop_page==0,"new game clears stale shop selection")
 main._open_modal("shop")
 main._action("item","healing_potion")
 main._action("buy","")
 await capture("shop_potion_sell")
 main._action("close","")
 # Real device canvases: 19.5:9 phone (1560x720) and 16:10 tablet (1280x800).
 for view in [Vector2(1560,720),Vector2(1280,800)]:
  main._apply_layout(view)
  main._start_new()
  await capture("device%dx%d_preparation" % [int(view.x),int(view.y)])
  main._open_modal("shop")
  await capture("device%dx%d_shop" % [int(view.x),int(view.y)])
  main._action("close","")
 main._apply_layout(Vector2(1280,720))
 main._start_new()
 var scaled_targets=[]
 for dimensions in [Vector2(800,480),Vector2(1920,1080),Vector2(2400,1080),Vector2(1280,800)]:
  var uniform=minf(dimensions.x/main.SIZE.x,dimensions.y/main.SIZE.y)
  scaled_targets.append({"viewport_pixels":str(dimensions),"min_primary_height_pixels":78*uniform,"physical_dp_claim":false})
 print("PRESENTATION_LAYOUT ",JSON.stringify({"checks":checks,"failures":failures,"states":states,"geometry_scaling_only":scaled_targets,"physical_readability_verified":false}))
 quit(0 if failures.is_empty() else 1)
