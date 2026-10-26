extends RefCounted
## Original presentation primitives, plus validated original character atlases.
const ENEMY_HEIGHTS = {"crawler":37.0,"skirmisher":49.0,"shooter":50.0,"guard":61.0,"siege":63.0,"boss":116.0,"weakness":40.0,"elite":50.0,"healer":46.0,"summoner":52.0,"flyer":44.0}
var atlas: Texture2D
var regions: Dictionary = {}
var background: Texture2D
var item_atlas: Texture2D
var item_regions: Dictionary = {}

func _init() -> void:
	if ResourceLoader.exists("res://assets/art/characters_atlas_v1.png"):
		atlas = load("res://assets/art/characters_atlas_v1.png") as Texture2D
	if ResourceLoader.exists("res://assets/art/battlefield_v1.png"):
		background = load("res://assets/art/battlefield_v1.png") as Texture2D
	if ResourceLoader.exists("res://assets/art/items_atlas_v1.png"):
		item_atlas = load("res://assets/art/items_atlas_v1.png") as Texture2D
	if FileAccess.file_exists("res://assets/art/manifest.json"):
		var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/manifest.json"))
		for asset in manifest.get("assets",[]):
			if str(asset.get("file","")).contains("characters"):
				for region in asset.get("regions",[]):
					var r: Array = region.rect
					regions[region.id] = Rect2(r[0],r[1],r[2],r[3])
			elif str(asset.get("file","")).contains("items_atlas"):
				for region in asset.get("regions",[]):
					var r: Array = region.rect
					item_regions[region.id] = Rect2(r[0],r[1],r[2],r[3])

func sprite_bounds(id: String, at: Vector2, height: float) -> Rect2:
	var source: Rect2 = regions.get(id,Rect2(0,0,height,height))
	var size: Vector2 = Vector2(source.size.x/maxf(1,source.size.y)*height,height)
	return Rect2(at-Vector2(size.x*0.5,size.y*0.83),size)

func enemy_height(kind: String) -> float:
	return float(ENEMY_HEIGHTS.get(kind,49.0))

func sprite(c: CanvasItem, id: String, at: Vector2, height: float, flip: bool = false, tint: Color = Color.WHITE) -> bool:
	if atlas == null or not regions.has(id):
		return false
	var source: Rect2 = regions[id]
	var target: Rect2 = sprite_bounds(id,at,height)
	if flip:
		c.draw_set_transform(at,0,Vector2(-1,1))
		target.position -= at
		c.draw_texture_rect_region(atlas,target,source,tint)
		c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	else:
		c.draw_texture_rect_region(atlas,target,source,tint)
	return true

func backdrop(c: CanvasItem, t: float, size: Vector2 = Vector2(1280,720)) -> void:
	c.draw_rect(Rect2(Vector2.ZERO,size),Color("111610"))
	if background!=null:
		c.draw_texture_rect(background,Rect2(Vector2.ZERO,size),false,Color(0.46,0.47,0.37))
	# Quiet natural light on the character, iron-dark space behind menu lettering.
	for i in range(16):
		c.draw_rect(Rect2(size.x*0.5+i*40,0,40,size.y),Color(0.025,0.035,0.025,0.35+i*0.025))
	c.draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.035,0.025,0.20))

func terrain(c: CanvasItem, bounds: Rect2, t: float) -> void:
	c.draw_rect(bounds,Color("263b39"))
	if background != null:
		var source_width: float = background.get_width()
		var center_y: float = background.get_height()*0.4506
		var source_height: float = minf(source_width / (bounds.size.x/bounds.size.y),center_y*2.0)
		var source_y: float = maxf(0,center_y-source_height*0.5)
		c.draw_texture_rect_region(background,bounds,Rect2(0,source_y,source_width,source_height),Color(0.86,0.90,0.89))
		sprite(c,"portal",Vector2(bounds.end.x-35,bounds.get_center().y+7),93,false,Color(0.85,0.8,0.85,0.9))
		c.draw_rect(bounds,Color("4c625a"),false,1)
		return
	# Deliberately low-frequency terrain keeps spell and enemy silhouettes legible.
	for row in range(14):
		for column in range(34):
			var x: float = bounds.position.x+column*37+(row%2)*13
			var y: float = bounds.position.y+row*31
			var n: float = sin(column*17.23+row*11.37)
			var color: Color = Color("30423b") if n>0 else Color("233932")
			c.draw_polygon(PackedVector2Array([Vector2(x,y+9),Vector2(x+21,y),Vector2(x+38,y+13),Vector2(x+15,y+23)]),PackedColorArray([color]))
	# Broad ancient road. No obstacles are implied in walkable space.
	var road: PackedVector2Array = PackedVector2Array([Vector2(28,292),Vector2(300,301),Vector2(600,311),Vector2(950,295),Vector2(1252,284),Vector2(1252,392),Vector2(950,405),Vector2(600,388),Vector2(300,393),Vector2(28,402)])
	c.draw_colored_polygon(road,Color("48504a"))
	for i in range(32):
		var x: float = 48+i*39
		var y: float = 320+sin(i*0.75)*14
		c.draw_line(Vector2(x,y),Vector2(x+26,y-3),Color("60665a"),1,true)
		c.draw_line(Vector2(x+9,y+49),Vector2(x+30,y+47),Color("353f3c"),1,true)
	# Boundary terrain and ruins outside the active lane.
	for i in range(25):
		var x: float = 40+i*51
		var y: float = bounds.position.y+8+sin(i*1.4)*5
		var base: Color = Color("2e4443")
		c.draw_colored_polygon(PackedVector2Array([Vector2(x-15,y+15),Vector2(x-7,y-2),Vector2(x+12,y-7),Vector2(x+24,y+10),Vector2(x+15,y+23)]),base)
		c.draw_line(Vector2(x-7,y-2),Vector2(x+12,y-7),Color("49625a"),2,true)
	for i in range(18):
		var x: float = 50+i*69
		var y: float = bounds.end.y-12
		c.draw_line(Vector2(x,y),Vector2(x-6,y-12),Color("4b6550"),2,true)
		c.draw_line(Vector2(x,y),Vector2(x+4,y-9),Color("4b6550"),2,true)
	# Enemy portal sits beyond the playable right edge.
	sprite(c,"portal",Vector2(1225,341),100,false,Color(0.8,0.8,0.85,0.8))
	c.draw_arc(Vector2(1215,350),34,0,TAU,40,Color(0.8,0.22,0.25,0.3+sin(t*2)*0.1),2,true)
	c.draw_rect(bounds,Color("4c625a"),false,1)

func castle(c: CanvasItem, at: Vector2, hp_ratio: float, t: float) -> void:
	c.draw_set_transform(at,0,Vector2(1,0.35))
	c.draw_circle(Vector2.ZERO,80,Color(0.02,0.06,0.08,0.55))
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if not sprite(c,"castle",at+Vector2(0,8),156):
		c.draw_rect(Rect2(at+Vector2(-53,-83),Vector2(106,98)),Color("698080"))
		c.draw_rect(Rect2(at+Vector2(-17,-25),Vector2(34,40)),Color("1d3541"))
		for x in [-55,-5,45]:
			c.draw_rect(Rect2(at+Vector2(x,-110),Vector2(28,46)),Color("a1b0a0"))
	if hp_ratio<0.4:
		for i in range(4):
			var p: Vector2 = at+Vector2(-48+i*29,-24+sin(i)*11)
			c.draw_circle(p+Vector2(0,-fmod(t*16+i*7,31)),7,Color(0.9,0.38,0.1,0.45))
			c.draw_circle(p,5,Color("f1b454"))

func hero(c: CanvasItem, at: Vector2, id: String, facing: Vector2, t: float, scale: float = 1.0, moving: bool = false, opacity: float = 1.0) -> void:
	var bob: float = sin(t*13)*2 if moving else sin(t*2.2)*0.6
	c.draw_set_transform(at,0,Vector2(1,0.32))
	c.draw_circle(Vector2.ZERO,19*scale,Color(0.02,0.05,0.07,0.55*opacity))
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if sprite(c,id,at+Vector2(0,bob),59*scale,facing.x>0,Color(1,1,1,opacity)):
		return
	var col: Color = {"guardian":Color("62b9b9"),"ranger":Color("94b779"),"arcanist":Color("b99cda")}.get(id,Color.WHITE)
	col.a *= opacity
	c.draw_circle(at+Vector2(0,-23)*scale,10*scale,col)
	c.draw_rect(Rect2(at+Vector2(-11,-20)*scale,Vector2(22,25)*scale),col.darkened(0.3))
	c.draw_line(at+Vector2(9,-17)*scale,at+Vector2(24,-32)*scale,Color(Color("e1cb91"),opacity),4*scale,true)

func enemy(c: CanvasItem, at: Vector2, kind: String, t: float, attacking: bool, alpha: float = 1.0) -> void:
	if kind=="weakness":
		c.draw_circle(at,16,Color(0.92,0.65,0.25,0.15*alpha))
		var pulse: float = 13+sin(t*8)*2
		c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-pulse),at+Vector2(pulse,0),at+Vector2(0,pulse),at+Vector2(-pulse,0)]),Color("f3bf65",alpha))
		c.draw_arc(at,pulse+7,0,TAU,24,Color("fff0c7",alpha),1.5,true)
		return
	var height: float = enemy_height(kind)
	var bob: float = sin(t*7+at.x*0.05)*1.3
	c.draw_set_transform(at,0,Vector2(1,0.34))
	c.draw_circle(Vector2.ZERO,height*0.29,Color(0.02,0.04,0.06,0.5*alpha))
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	if kind=="elite":
		if sprite(c,"crawler",at+Vector2(0,bob),height*1.35,false,Color(1,0.74,0.64,alpha)):
			return
	elif kind=="flyer":
		_flyer(c,at,t,attacking,alpha)
		return
	elif kind=="healer":
		_robed(c,at,t,Color("6fae7c"),Color("e7f5c8"),alpha,false)
		return
	elif kind=="summoner":
		_robed(c,at,t,Color("8f74c8"),Color("e0c8ff"),alpha,true)
		return
	if sprite(c,kind,at+Vector2(0,bob),height,false,Color(1,0.75,0.7,alpha) if attacking else Color(1,1,1,alpha)):
		return
	c.draw_circle(at+Vector2(0,-10),14,Color("984b4f",alpha))
	c.draw_line(at+Vector2(-14,-15),at+Vector2(14,-15),Color("e5a179",alpha),3,true)

# Winged silhouette; the only role that crosses defender lines.
func _flyer(c: CanvasItem, at: Vector2, t: float, attacking: bool, alpha: float) -> void:
	var bob: float = sin(t*9+at.x*0.05)*4.0
	var flap: float = sin(t*13)*0.5+0.5
	var body: Vector2 = at+Vector2(0,-26+bob)
	var wing: Color = Color("3a3350",alpha)
	c.draw_colored_polygon(PackedVector2Array([body+Vector2(-4,0),body+Vector2(-16-flap*8,-12-flap*4),body+Vector2(-24-flap*4,2),body+Vector2(-6,7)]),wing)
	c.draw_colored_polygon(PackedVector2Array([body+Vector2(4,0),body+Vector2(16+flap*8,-12-flap*4),body+Vector2(24+flap*4,2),body+Vector2(6,7)]),wing)
	c.draw_circle(body,8,Color("5c4b76",alpha))
	c.draw_circle(body+Vector2(-3,-2),1.8,Color(1,0.8,0.4,alpha))
	c.draw_circle(body+Vector2(3,-2),1.8,Color(1,0.8,0.4,alpha))
	if attacking: c.draw_arc(body,12,0,TAU,20,Color(1,0.4,0.3,alpha),2,true)

# Support casters share one robed body; the sigil tells healer from summoner.
func _robed(c: CanvasItem, at: Vector2, t: float, robe: Color, accent: Color, alpha: float, summon: bool) -> void:
	var base: Vector2 = at+Vector2(0,sin(t*4+at.x*0.05)*1.5)
	c.draw_colored_polygon(PackedVector2Array([base+Vector2(0,-44),base+Vector2(13,-20),base+Vector2(11,0),base+Vector2(-11,0),base+Vector2(-13,-20)]),Color(robe,alpha))
	c.draw_circle(base+Vector2(0,-46),7,Color(robe.lightened(0.25),alpha))
	c.draw_circle(base+Vector2(0,-46),4,Color("1b1a20",alpha))
	var pulse: float = 0.5+sin(t*5)*0.5
	var focus: Vector2 = base+Vector2(0,-62-pulse*3)
	if summon:
		c.draw_circle(focus,9+4*pulse,Color(accent,0.18*alpha))
		c.draw_arc(focus,9,0,TAU,18,Color(accent,alpha),2,true)
	else:
		c.draw_line(focus+Vector2(-5,0),focus+Vector2(5,0),Color(accent,alpha),3,true)
		c.draw_line(focus+Vector2(0,-5),focus+Vector2(0,5),Color(accent,alpha),3,true)

func _arrow(c: CanvasItem, start: Vector2, end: Vector2, color: Color, width: float=3.0) -> void:
	var d: Vector2 = (end-start).normalized()
	var side: Vector2 = Vector2(-d.y,d.x)
	c.draw_line(start,end-d*5,color,width,true)
	c.draw_colored_polygon(PackedVector2Array([end,end-d*12+side*6,end-d*12-side*6]),color)

func skill_icon(c: CanvasItem, at: Vector2, index: int, color: Color, hero_id: String) -> void:
	var key: String = hero_id+"."+str(index)
	match key:
		"guardian.0":
			c.draw_colored_polygon(PackedVector2Array([at+Vector2(-12,11),at+Vector2(10,-20),at+Vector2(20,-25),at+Vector2(17,-13),at+Vector2(-5,17)]),color)
			c.draw_line(at+Vector2(-18,8),at+Vector2(-1,23),color,4,true)
			c.draw_arc(at+Vector2(-3,-2),27,-1.3,0.45,16,color,2,true)
		"guardian.1":
			var pts: PackedVector2Array = PackedVector2Array([at+Vector2(-19,-20),at+Vector2(19,-20),at+Vector2(16,6),at+Vector2(0,23),at+Vector2(-16,6),at+Vector2(-19,-20)])
			c.draw_polyline(pts,color,3.5,true)
			c.draw_line(at+Vector2(0,-14),at+Vector2(0,13),color,4,true)
			c.draw_line(at+Vector2(-11,-5),at+Vector2(11,-5),color,3,true)
		"guardian.2":
			c.draw_polyline(PackedVector2Array([at+Vector2(-8,-18),at+Vector2(13,-18),at+Vector2(12,8),at+Vector2(2,20),at+Vector2(-8,8),at+Vector2(-8,-18)]),color,3,true)
			_arrow(c,at+Vector2(-27,0),at+Vector2(26,0),color)
			c.draw_line(at+Vector2(-24,-13),at+Vector2(-14,-13),color,2,true)
			c.draw_line(at+Vector2(-24,13),at+Vector2(-14,13),color,2,true)
		"guardian.3":
			for radius in [10,18,26]: c.draw_arc(at,radius,-2.9,0.1,28,color,2.8,true)
			c.draw_colored_polygon(PackedVector2Array([at+Vector2(-7,2),at+Vector2(7,2),at+Vector2(10,15),at+Vector2(0,23),at+Vector2(-10,15)]),color)
		"ranger.0":
			_arrow(c,at+Vector2(-23,20),at+Vector2(24,-20),color,3.5)
			for x in [-9,3,15]: c.draw_line(at+Vector2(x,-15),at+Vector2(x+8,-4),color,2,true)
		"ranger.1":
			c.draw_arc(at+Vector2(0,8),23,PI,TAU,24,color,3,true)
			c.draw_polyline(PackedVector2Array([at+Vector2(-23,8),at+Vector2(-15,-1),at+Vector2(-8,8),at+Vector2(0,-1),at+Vector2(8,8),at+Vector2(15,-1),at+Vector2(23,8)]),color,2.5,true)
			c.draw_line(at+Vector2(-22,15),at+Vector2(22,15),color,3,true)
			for i in range(3):
				var d: Vector2=Vector2.from_angle(-PI*0.8+i*0.3*PI)
				c.draw_line(at+Vector2(0,-10)+d*11,at+Vector2(0,-10)+d*18,color,2,true)
		"ranger.2":
			_arrow(c,at+Vector2(24,-9),at+Vector2(-24,-9),color,4)
			c.draw_arc(at+Vector2(7,11),13,0.2,2.8,16,color,3,true)
			c.draw_line(at+Vector2(10,2),at+Vector2(21,20),color,4,true)
			c.draw_line(at+Vector2(-1,20),at+Vector2(17,20),color,3,true)
		"ranger.3":
			_arrow(c,at+Vector2(-22,17),at+Vector2(23,-18),color,3)
			_arrow(c,at+Vector2(-22,17),at+Vector2(25,13),color,3)
			c.draw_arc(at+Vector2(-25,5),17,-1.1,1.1,16,color,2,true)
		"arcanist.0":
			c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-20),at+Vector2(11,0),at+Vector2(0,20),at+Vector2(-11,0)]),color)
			for i in range(6):
				var d: Vector2=Vector2.from_angle(i*TAU/6)
				c.draw_line(at+d*18,at+d*27,color,2.5,true)
		"arcanist.1":
			c.draw_arc(at,24,-2.9,-0.25,24,color,3,true)
			c.draw_arc(at,24,0.25,2.9,24,color,3,true)
			c.draw_polyline(PackedVector2Array([at+Vector2(0,-16),at+Vector2(12,-2),at+Vector2(8,12),at+Vector2(0,21),at+Vector2(-8,12),at+Vector2(-12,-2),at+Vector2(0,-16)]),color,3,true)
		"arcanist.2":
			c.draw_set_transform(at,0,Vector2(1,0.55))
			c.draw_arc(Vector2.ZERO,26,0,TAU,32,color,3,true)
			c.draw_arc(Vector2.ZERO,15,0,TAU,24,color,2,true)
			c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
			for x in [-18,0,18]:
				c.draw_line(at+Vector2(x,-5),at+Vector2(x,-23+abs(x)*0.3),color,2,true)
				c.draw_circle(at+Vector2(x,-23+abs(x)*0.3),2.5,color)
		"arcanist.3":
			c.draw_line(at+Vector2(0,-15),at+Vector2(0,15),color,6,true)
			c.draw_line(at+Vector2(-14,0),at+Vector2(14,0),color,6,true)
			c.draw_arc(at,25,-1.2,1.2,20,color,2.5,true)
			c.draw_arc(at,25,PI-1.2,PI+1.2,20,color,2.5,true)
		"guardian.4":
			c.draw_polyline(PackedVector2Array([at+Vector2(-14,-20),at+Vector2(14,-20),at+Vector2(12,4),at+Vector2(0,18),at+Vector2(-12,4),at+Vector2(-14,-20)]),color,3,true)
			for i in range(8):
				var d: Vector2 = Vector2.from_angle(i*TAU/8)
				c.draw_line(at+d*17,at+d*26,color,2,true)
		"ranger.4":
			for angle in [-15,0,15]:
				var d: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(angle))
				_arrow(c,at-d*22,at+d*22,color,3)
		"arcanist.4":
			c.draw_colored_polygon(PackedVector2Array([at+Vector2(0,-24),at+Vector2(9,-6),at+Vector2(14,6),at+Vector2(6,20),at+Vector2(-6,20),at+Vector2(-14,6),at+Vector2(-9,-6)]),color)
			c.draw_arc(at+Vector2(0,6),14,-0.4,PI+0.4,16,color,2,true)

func potion_icon(c: CanvasItem, at: Vector2, color: Color, backing_opacity: float = 1.0) -> void:
	var pts: PackedVector2Array = PackedVector2Array([at+Vector2(-6,-19),at+Vector2(6,-19),at+Vector2(6,-10),at+Vector2(13,0),at+Vector2(12,18),at+Vector2(-12,18),at+Vector2(-13,0),at+Vector2(-6,-10),at+Vector2(-6,-19)])
	c.draw_colored_polygon(pts,Color(Color("28575a"),backing_opacity))
	c.draw_polyline(pts,color,2.5,true)
	c.draw_line(at+Vector2(-10,5),at+Vector2(10,5),color,2,true)
	c.draw_line(at+Vector2(-7,-22),at+Vector2(7,-22),Color(Color("d3b571"),color.a),4,true)

func item_icon(c: CanvasItem, at: Vector2, id: String, color: Color, scale: float=1.0) -> void:
	if item_atlas!=null and item_regions.has(id):
		var source: Rect2 = item_regions[id]
		var target_size: Vector2 = source.size*(52.0*scale/maxf(source.size.x,source.size.y))
		c.draw_texture_rect_region(item_atlas,Rect2(at-target_size*0.5,target_size),source)
		return
	c.draw_set_transform(at,0,Vector2(scale,scale))
	if id=="healing_potion":
		potion_icon(c,Vector2.ZERO,color)
	elif id.contains("blade") or id in ["blood_edge","sanguine","iron_blade","tempest_glaive"]:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-4,9),Vector2(12,-19),Vector2(20,-25),Vector2(17,-13),Vector2(3,14)]),color)
		c.draw_line(Vector2(-9,7),Vector2(10,18),Color("d8b97c"),4,true)
		c.draw_line(Vector2(1,13),Vector2(-8,25),Color("9c8357"),5,true)
	elif id.contains("armor") or id in ["guard_seal","fortress","sanctuary","iron_ring"]:
		c.draw_colored_polygon(PackedVector2Array([Vector2(-19,-18),Vector2(19,-18),Vector2(17,9),Vector2(0,25),Vector2(-17,9)]),color.darkened(0.25))
		c.draw_polyline(PackedVector2Array([Vector2(-19,-18),Vector2(19,-18),Vector2(17,9),Vector2(0,25),Vector2(-17,9),Vector2(-19,-18)]),color,2,true)
		c.draw_line(Vector2(0,-12),Vector2(0,16),Color("d4bd7b"),3,true)
	elif id in ["keen_lens","crit_scope","falcon_eye"]:
		c.draw_arc(Vector2.ZERO,17,0,TAU,24,color,4,true)
		c.draw_circle(Vector2.ZERO,5,Color("c9e1bf"))
		c.draw_line(Vector2(11,13),Vector2(24,26),Color("cfad75"),5,true)
	elif id=="swift_bow":
		c.draw_arc(Vector2(-10,0),27,-1.2,1.2,20,color,4,true)
		c.draw_line(Vector2(0,-24),Vector2(0,24),Color("e6d6ae"),1,true)
	elif id.contains("cloth") or id.contains("mantle"):
		c.draw_colored_polygon(PackedVector2Array([Vector2(-10,-22),Vector2(10,-22),Vector2(24,22),Vector2(0,13),Vector2(-24,22)]),color)
		c.draw_line(Vector2(-10,-22),Vector2(10,-22),Color("dfc280"),4,true)
	elif id=="spring_gear":
		c.draw_arc(Vector2.ZERO,15,0,TAU,24,color,6,true)
		for i in range(8):
			var dir: Vector2 = Vector2.from_angle(i*TAU/8)
			c.draw_line(dir*14,dir*24,color,6,true)
	else:
		c.draw_colored_polygon(PackedVector2Array([Vector2(0,-25),Vector2(17,-5),Vector2(10,20),Vector2(-10,20),Vector2(-17,-5)]),color)
		c.draw_line(Vector2(0,-20),Vector2(0,17),color.lightened(0.5),2,true)
		c.draw_line(Vector2(-12,-4),Vector2(12,-4),color.lightened(0.4),2,true)
	c.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)

func defender(c: CanvasItem, at: Vector2, alive: bool, flash: bool) -> void:
	# A smaller bow silhouette and blue pennant distinguish local NPCs from the hero.
	var tint: Color = Color(0.70,0.84,0.91,1.0 if alive else 0.28)
	if flash: tint=Color(1.0,0.66,0.55)
	sprite(c,"ranger",at,43,false,tint)
	c.draw_line(at+Vector2(-19,3),at+Vector2(-19,-25),Color("1b2526"),4,true)
	c.draw_line(at+Vector2(-19,3),at+Vector2(-19,-25),Color("a9b9bd"),1.5,true)
	c.draw_colored_polygon(PackedVector2Array([at+Vector2(-18,-25),at+Vector2(-6,-20),at+Vector2(-18,-15)]),Color("74a4bc") if alive else Color("596567"))
