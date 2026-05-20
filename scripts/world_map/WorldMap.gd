# =============================================================================
# AlgoQuest — World Map  (Sprite Node Edition)
# File: scripts/world_map/WorldMap.gd
#
# HOW SPRITES WORK HERE
# ─────────────────────
# Each chapter in CHAPTERS has a "sprite" key pointing to a PNG under
# res://assets/map/.  During _ready(), _build_sprite_nodes() iterates every
# chapter, loads the texture, creates a Sprite2D child under $ChapterNodes,
# and stores a reference in _sprite_nodes[chapter_id].
#
# _draw_nodes() (called by _draw) no longer draws the filled circle or emoji
# icon — instead it only draws the decorative ring, hover glow, lock tint,
# star/score badges, name label, and tier pips.  The Sprite2D sits underneath
# all of that and provides the actual image.
#
# FALLBACK
# ────────
# If a PNG file is missing or hasn't been imported yet, the node falls back to
# drawing the old filled circle + emoji so the map still works during
# development before all assets are ready.
#
# SPRITE FILES NEEDED (save under res://assets/map/)
#   node_castle.png      — Kingdom Gate      (castle building)
#   node_tower.png       — Castle of Echoes  (wizard/watch tower)
#   node_station.png     — Chain Station     (dock / windmill / town house)
#   node_forest.png      — Oracle's Forest   (tree cluster)
#   node_crossroads.png  — Kingdom Roads     (crossroads / town)
#
# Recommended source: Fantasy Paper Map Pixelart Asset Pack (itch.io, free)
#   https://aamatniekss.itch.io/fantasy-paper-map-pixelart-asset-pack
# =============================================================================

extends Node2D

const PATH_FONT  := "res://assets/fonts/freepixel.ttf"
const TIER_LABELS: Array[String] = ["Easy", "Normal", "Hard", "Expert", "Master"]

# ─────────────────────────────────────────────────────────────────────────────
#  CHAPTER DATA
#  "sprite" → path to the PNG for this node
#  "icon"   → fallback emoji used if sprite file is missing
# ─────────────────────────────────────────────────────────────────────────────
const CHAPTERS: Array = [
	{ "id":1,  "name":"Kingdom Gate",     "dsa":"Queue — FIFO",
	  "pos":Vector2(170, 460),  "color":Color("#6BCB77"),
	  "sprite":"res://assets/map/node_castle.png",      "icon":"🏰", "tiers":5 },
	{ "id":6,  "name":"Castle of Echoes", "dsa":"Stack — LIFO",
	  "pos":Vector2(400, 270),  "color":Color("#C77DFF"),
	  "sprite":"res://assets/map/node_tower.png",       "icon":"🗼", "tiers":5 },
	{ "id":11, "name":"Chain Station",    "dsa":"Linked List",
	  "pos":Vector2(640, 460),  "color":Color("#FFD93D"),
	  "sprite":"res://assets/map/node_station.png",     "icon":"🚂", "tiers":5 },
	{ "id":16, "name":"Oracle's Forest",  "dsa":"BST / AVL Tree",
	  "pos":Vector2(880, 270),  "color":Color("#88CC77"),
	  "sprite":"res://assets/map/node_forest.png",      "icon":"🌲", "tiers":5 },
	{ "id":21, "name":"Kingdom Roads",    "dsa":"Graph Algorithms",
	  "pos":Vector2(1110, 460), "color":Color("#4D96FF"),
	  "sprite":"res://assets/map/node_crossroads.png",  "icon":"🗺",  "tiers":5 },
]

const ROADS: Array = [[0,1],[0,2],[1,2],[1,3],[2,4],[3,4]]

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _avatar:       Node2D          = $PlayerAvatar
@onready var _anim:         AnimationPlayer = $AnimationPlayer
@onready var _tooltip_bg:   Control         = $HUD/TooltipBG
@onready var _tooltip_lbl:  Label           = $HUD/TooltipBG/TooltipLbl
@onready var _chapter_root: Node2D          = $ChapterNodes

# ── State ─────────────────────────────────────────────────────────────────────
var _pixel_font:    Font       = null
var _map_data:      Dictionary = {}
var _hover_id:      int        = -1
var _avatar_pos:    Vector2    = Vector2(170, 460)
var _is_teacher:    bool       = false
var _stars:         Array      = []

# chapter_id → Sprite2D  (populated in _build_sprite_nodes)
# If the texture could not be loaded, the entry is null and the old
# circle+icon fallback is used for that node.
var _sprite_nodes:  Dictionary = {}

var _badge_ring:    ColorRect  = null
var _badge_circle:  ColorRect  = null
var _badge_label:   Label      = null

var _panel_layer:       CanvasLayer    = null
var _panel_dim:         ColorRect      = null
var _panel_root:        PanelContainer = null
var _panel_vbox:        VBoxContainer  = null
var _tier_nodes:        Array          = []
var _selected_chapter:  Dictionary     = {}

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font if ResourceLoader.exists(PATH_FONT) else null

	if has_node("/root/PlayerProfile") and PlayerProfile.is_loaded():
		_map_data = PlayerProfile.progress
		if PlayerProfile.has_method("is_teacher"):
			_is_teacher = PlayerProfile.is_teacher()
		elif "role" in PlayerProfile:
			_is_teacher = PlayerProfile.role == "teacher"

	_generate_stars()
	_build_sprite_nodes()   # ← new: create Sprite2D children
	_build_player_badge()
	_build_hud()
	_build_region_areas()
	_build_info_panel()
	_play_enter_animation()
	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
#  SPRITE NODE BUILDER
#  Creates one Sprite2D per chapter under $ChapterNodes.
#  Called once in _ready().  Re-call if you hot-reload assets.
# ─────────────────────────────────────────────────────────────────────────────
func _build_sprite_nodes() -> void:
	# Clean up any previous sprites (e.g. after hot-reload)
	for child in _chapter_root.get_children():
		child.queue_free()
	_sprite_nodes.clear()

	for ch: Dictionary in CHAPTERS:
		var cid:     int     = ch["id"]     as int
		var pos:     Vector2 = ch["pos"]    as Vector2
		var col:     Color   = ch["color"]  as Color
		var path:    String  = ch["sprite"] as String

		# ── Try to load the texture ──────────────────────────────────────────
		var texture: Texture2D = null
		if ResourceLoader.exists(path):
			texture = load(path) as Texture2D

		if texture == null:
			# Sprite file not found — mark as null; _draw_nodes() will use
			# the circle + emoji fallback for this chapter.
			_sprite_nodes[cid] = null
			continue

		# ── Create Sprite2D ──────────────────────────────────────────────────
		var sprite := Sprite2D.new()
		sprite.texture  = texture
		sprite.position = pos
		sprite.z_index  = 3   # above roads (z=0), below HUD overlays

		# Scale so the sprite fits neatly inside the 96-px-diameter node circle.
		# Target display size: 72×72 px.  Adjust if your PNGs are a different
		# logical size — e.g. if the PNG is 32×32 px, scale = 72/32 = 2.25.
		const TARGET_PX := 72.0
		var img_w: float = float(texture.get_width())
		var img_h: float = float(texture.get_height())
		var scale_f: float = TARGET_PX / max(img_w, img_h)
		sprite.scale = Vector2(scale_f, scale_f)

		# Tint locked nodes grey so they visually read as unavailable
		# (updated each frame in _update_sprite_tints, called from _draw)
		sprite.modulate = _sprite_tint(cid, col)

		_chapter_root.add_child(sprite)
		_sprite_nodes[cid] = sprite

# ─────────────────────────────────────────────────────────────────────────────
#  SPRITE TINT HELPER
#  Returns the modulate colour a sprite should have right now.
#  Called both on build and every _draw() so tints update when progress changes.
# ─────────────────────────────────────────────────────────────────────────────
func _sprite_tint(cid: int, col: Color) -> Color:
	var vis: bool = _is_unlocked(cid) or _is_teacher
	if not vis:
		# Dark desaturated tint for locked nodes
		return Color(0.18, 0.18, 0.14, 0.75)
	# Subtle colour-tint so each sprite picks up its chapter accent colour
	# without fully overriding the original art.
	# lerp(white, col, 0.25) keeps the sprite mostly faithful to its artwork.
	return Color.WHITE.lerp(col, 0.25)

# ─────────────────────────────────────────────────────────────────────────────
#  STAR FIELD
# ─────────────────────────────────────────────────────────────────────────────
func _generate_stars() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	for _i in range(130):
		_stars.append(Vector2(rng.randf_range(0, 1280), rng.randf_range(70, 530)))

# ─────────────────────────────────────────────────────────────────────────────
#  PLAYER BADGE
# ─────────────────────────────────────────────────────────────────────────────
func _build_player_badge() -> void:
	if not is_instance_valid(_avatar): return
	var uname: String = "?"
	if has_node("/root/PlayerProfile"): uname = PlayerProfile.get_username()

	var ring_col:   Color  = Color("#FFD93D") if _is_teacher else Color("#4D96FF")
	var fill_col:   Color  = Color("#2a1a00") if _is_teacher else Color("#0d1f3c")
	var badge_text: String = "👑" if _is_teacher else uname.substr(0,1).to_upper()

	_badge_ring          = ColorRect.new()
	_badge_ring.color    = ring_col
	_badge_ring.size     = Vector2(44, 44)
	_badge_ring.position = Vector2(-22, -22)
	_avatar.add_child(_badge_ring)

	_badge_circle          = ColorRect.new()
	_badge_circle.color    = fill_col
	_badge_circle.size     = Vector2(36, 36)
	_badge_circle.position = Vector2(-18, -18)
	_badge_circle.z_index  = 1
	_avatar.add_child(_badge_circle)

	_badge_label = Label.new()
	_badge_label.text = badge_text
	_badge_label.add_theme_font_size_override("font_size", 16)
	_badge_label.add_theme_color_override("font_color", ring_col)
	_badge_label.position = Vector2(-9, -10)
	_badge_label.z_index  = 2
	_avatar.add_child(_badge_label)

	var name_lbl := Label.new()
	name_lbl.text = uname
	if _pixel_font: name_lbl.add_theme_font_override("font", _pixel_font)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color",
		Color("#FFD93D") if _is_teacher else Color(1.0, 0.95, 0.6))
	name_lbl.position = Vector2(-24, -56)
	name_lbl.z_index  = 2
	_avatar.add_child(name_lbl)

	if _is_teacher:
		var role_lbl := Label.new()
		role_lbl.text = "TEACHER"
		if _pixel_font: role_lbl.add_theme_font_override("font", _pixel_font)
		role_lbl.add_theme_font_size_override("font_size", 9)
		role_lbl.add_theme_color_override("font_color", Color("#FFD93D"))
		role_lbl.position = Vector2(-22, -44)
		role_lbl.z_index  = 2
		_avatar.add_child(role_lbl)

	_avatar.position = _avatar_pos
	var tw := create_tween(); tw.set_loops()
	tw.tween_property(_badge_ring, "color",
		Color(ring_col.r, ring_col.g, ring_col.b, 0.28), 1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_badge_ring, "color",
		Color(ring_col.r, ring_col.g, ring_col.b, 1.0),  1.1).set_trans(Tween.TRANS_SINE)

# ─────────────────────────────────────────────────────────────────────────────
#  HUD
# ─────────────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var hud: CanvasLayer = $HUD as CanvasLayer
	var hud_h: int = 86 if _is_teacher else 62

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.84); bg.position = Vector2.ZERO; bg.size = Vector2(1280, hud_h)
	hud.add_child(bg)

	var accent := ColorRect.new()
	accent.color    = Color("#FFD93D") if _is_teacher else Color("#4D96FF")
	accent.position = Vector2(0, hud_h - 2); accent.size = Vector2(1280, 2)
	hud.add_child(accent)

	_hud_lbl(hud, "ALGOQUEST",   Vector2(20, 7),  10, Color("#4D96FF"))
	_hud_lbl(hud, "Kingdom Map", Vector2(20, 23), 22, Color("#e8e8d0"))

	if _is_teacher:
		var tbg := ColorRect.new()
		tbg.color = Color(0.20, 0.14, 0.0, 1.0); tbg.position = Vector2(0, 62); tbg.size = Vector2(1280, 24)
		hud.add_child(tbg)
		_hud_lbl(hud, "🎓  Teacher Mode — All Levels Unlocked", Vector2(20, 64), 11, Color("#FFD93D"))

	if has_node("/root/PlayerProfile"):
		_hud_lbl(hud, PlayerProfile.get_username(), Vector2(830, 9), 13, Color("#aaaaaa"))
		var st := PlayerProfile.stats as Dictionary
		_hud_lbl(hud, "Score: %d  |  Perfects: %d  |  Streak: %d days" % [
			st.get("total_score",0) as int, st.get("perfect_clears",0) as int,
			st.get("login_streak",0) as int], Vector2(830, 27), 12, Color("#FFD93D"))

	var btns: Array = [["Profile",  func(): GameRouter.go_progress_screen()],
					   ["Progress", func(): GameRouter.go_progress_screen()],
					   ["Settings", func(): GameRouter.go_settings()]]
	for i: int in btns.size():
		var b := Button.new(); b.text = btns[i][0] as String
		b.custom_minimum_size = Vector2(100, 30)
		if _pixel_font: b.add_theme_font_override("font", _pixel_font)
		b.add_theme_font_size_override("font_size", 13)
		b.position = Vector2(798 + i * 112, hud_h - 44)
		b.pressed.connect(btns[i][1] as Callable); hud.add_child(b)

	var fam_starts: Array[int] = [1, 6, 11, 16, 21]
	var tcols: Array[Color] = [Color("#6BCB77"),Color("#C77DFF"),Color("#FFD93D"),
							   Color("#88CC77"),Color("#4D96FF")]
	for i: int in fam_starts.size():
		var ok := true
		if has_node("/root/PlayerProfile"):
			for t in range(5):
				if not (PlayerProfile.progress.get(fam_starts[i]+t,{}) as Dictionary)\
						.get("complete",false) as bool:
					ok = false; break
		var dot := ColorRect.new(); dot.color = tcols[i] if ok else Color("#222230")
		dot.position = Vector2(200 + i*26, hud_h-14); dot.size = Vector2(20, 8)
		hud.add_child(dot)

	if is_instance_valid(_tooltip_bg):
		_tooltip_bg.visible = false
		if _pixel_font and is_instance_valid(_tooltip_lbl):
			_tooltip_lbl.add_theme_font_override("font", _pixel_font)
			_tooltip_lbl.add_theme_font_size_override("font_size", 13)

func _hud_lbl(p: Node, t: String, pos: Vector2, sz: int, col: Color) -> void:
	var l := Label.new(); l.text = t; l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if _pixel_font: l.add_theme_font_override("font", _pixel_font)
	p.add_child(l)

# ─────────────────────────────────────────────────────────────────────────────
#  CLICK AREAS
# ─────────────────────────────────────────────────────────────────────────────
func _build_region_areas() -> void:
	for ch: Dictionary in CHAPTERS:
		var cid: int = ch["id"] as int; var pos: Vector2 = ch["pos"] as Vector2
		var area := Area2D.new(); var shape := CollisionShape2D.new()
		var circ := CircleShape2D.new(); circ.radius = 54.0
		shape.shape = circ; area.position = pos; area.add_child(shape)
		area.input_event.connect(func(_vp, event: InputEvent, _i):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					_click(cid, _is_unlocked(cid), pos))
		area.mouse_entered.connect(func(): _hover(cid, pos))
		area.mouse_exited.connect(func():  _unhover())
		add_child(area)

# ─────────────────────────────────────────────────────────────────────────────
#  INFO PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _build_info_panel() -> void:
	_panel_layer = CanvasLayer.new(); _panel_layer.layer = 20; _panel_layer.visible = false
	add_child(_panel_layer)

	_panel_dim = ColorRect.new(); _panel_dim.color = Color(0,0,0,0.62)
	_panel_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			if (ev as InputEventMouseButton).pressed and \
			   (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_close_info_panel())
	_panel_layer.add_child(_panel_dim)

	_panel_root = PanelContainer.new()
	_panel_root.custom_minimum_size = Vector2(340, 0)
	_panel_root.anchor_left   = 0.5; _panel_root.anchor_right  = 0.5
	_panel_root.anchor_top    = 0.5; _panel_root.anchor_bottom = 0.5
	_panel_root.offset_left   = -170; _panel_root.offset_right  = 170
	_panel_root.offset_top    = -270; _panel_root.offset_bottom = 270
	_panel_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_root.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0e0e1c"); sb.border_color = Color("#FFD93D")
	sb.set_border_width_all(2); sb.set_corner_radius_all(10)
	sb.content_margin_left = 24; sb.content_margin_right  = 24
	sb.content_margin_top  = 20; sb.content_margin_bottom = 24
	_panel_root.add_theme_stylebox_override("panel", sb)
	_panel_layer.add_child(_panel_root)

	_panel_vbox = VBoxContainer.new()
	_panel_vbox.add_theme_constant_override("separation", 10)
	_panel_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel_root.add_child(_panel_vbox)

func _open_info_panel(ch: Dictionary) -> void:
	_selected_chapter = ch
	var cid:   int   = ch["id"]    as int
	var tiers: int   = ch.get("tiers",1) as int
	var col:   Color = ch["color"] as Color
	var d: Dictionary = _map_data.get(cid,{}) as Dictionary
	var score: int    = d.get("best_score",0) as int

	for n in _tier_nodes: if is_instance_valid(n): n.queue_free()
	_tier_nodes.clear()

	# Header: sprite thumbnail + title
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 8)
	_panel_vbox.add_child(header); _tier_nodes.append(header)

	# Small sprite thumbnail in the panel header (falls back to emoji label)
	var sprite_path: String = ch.get("sprite","") as String
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var thumb := TextureRect.new()
		thumb.texture             = load(sprite_path) as Texture2D
		thumb.custom_minimum_size = Vector2(36, 36)
		thumb.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.modulate            = col
		header.add_child(thumb)
	else:
		var icon_lbl := Label.new()
		icon_lbl.text = ch.get("icon","?") as String
		icon_lbl.add_theme_font_size_override("font_size", 28)
		header.add_child(icon_lbl)

	var title_lbl := Label.new(); title_lbl.text = ch["name"] as String
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _pixel_font: title_lbl.add_theme_font_override("font", _pixel_font)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", col)
	header.add_child(title_lbl)

	if _is_teacher:
		var tb := Label.new(); tb.text = "🎓 ALL"
		tb.add_theme_font_size_override("font_size", 10)
		tb.add_theme_color_override("font_color", Color("#FFD93D"))
		header.add_child(tb)

	var xbtn := Button.new(); xbtn.text = "✕"; xbtn.flat = true
	xbtn.custom_minimum_size = Vector2(30,30)
	if _pixel_font: xbtn.add_theme_font_override("font", _pixel_font)
	xbtn.add_theme_font_size_override("font_size", 14)
	xbtn.add_theme_color_override("font_color", Color("#888888"))
	xbtn.pressed.connect(_close_info_panel); header.add_child(xbtn)

	var div := HSeparator.new(); var dsb := StyleBoxFlat.new()
	dsb.bg_color = col.darkened(0.3); dsb.content_margin_top = 1
	div.add_theme_stylebox_override("separator", dsb)
	_panel_vbox.add_child(div); _tier_nodes.append(div)

	var dsa := Label.new(); dsa.text = ch["dsa"] as String
	dsa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: dsa.add_theme_font_override("font", _pixel_font)
	dsa.add_theme_font_size_override("font_size", 12)
	dsa.add_theme_color_override("font_color", Color("#888860"))
	_panel_vbox.add_child(dsa); _tier_nodes.append(dsa)

	var sh := HBoxContainer.new(); sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation", 4)
	_panel_vbox.add_child(sh); _tier_nodes.append(sh)
	for t in range(tiers):
		var done: bool = (_map_data.get(cid+t,{}) as Dictionary).get("complete",false) as bool
		var s := Label.new(); s.text = "⭐" if done else "☆"
		s.add_theme_font_size_override("font_size", 18)
		s.add_theme_color_override("font_color", Color("#FFD93D") if done else Color("#333322"))
		sh.add_child(s)

	var sc := Label.new(); sc.text = "Best: %d pts" % score if score > 0 else "Not yet played"
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: sc.add_theme_font_override("font", _pixel_font)
	sc.add_theme_font_size_override("font_size", 12)
	sc.add_theme_color_override("font_color", Color("#FFD93D") if score > 0 else Color("#666650"))
	_panel_vbox.add_child(sc); _tier_nodes.append(sc)

	var dh := Label.new(); dh.text = "— Select Difficulty —"
	dh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: dh.add_theme_font_override("font", _pixel_font)
	dh.add_theme_font_size_override("font_size", 11)
	dh.add_theme_color_override("font_color", Color("#666650"))
	_panel_vbox.add_child(dh); _tier_nodes.append(dh)

	for t in range(tiers):
		var tid: int  = cid + t
		var done: bool = (_map_data.get(tid,{}) as Dictionary).get("complete",false) as bool
		var prev: bool = t == 0 or (_map_data.get(cid+t-1,{}) as Dictionary).get("complete",false) as bool
		var ok: bool   = _is_teacher or prev or done
		var lbl: String = TIER_LABELS[t] if t < TIER_LABELS.size() else "Tier %d" % (t+1)

		var btn := Button.new(); btn.disabled = not ok
		btn.custom_minimum_size = Vector2(292, 44)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _pixel_font: btn.add_theme_font_override("font", _pixel_font)
		btn.add_theme_font_size_override("font_size", 15)

		var bc: Color = Color("#7a6000") if done else (col.darkened(0.55) if ok else Color("#1a1a14"))
		var sn := StyleBoxFlat.new(); var sv := StyleBoxFlat.new()
		var sp := StyleBoxFlat.new(); var sd := StyleBoxFlat.new()
		for sb in [sn,sv,sp,sd]:
			sb.set_corner_radius_all(6); sb.set_border_width_all(1)
			sb.content_margin_left = 14; sb.content_margin_right = 14
		sn.bg_color = bc;                     sn.border_color = col if ok else Color("#333322")
		sv.bg_color = bc.lightened(0.18) if ok else bc
		sv.border_color = col.lightened(0.3) if ok else Color("#333322")
		sp.bg_color = bc.darkened(0.2);       sp.border_color = Color("#FFD93D")
		sd.bg_color = Color("#111110");        sd.border_color = Color("#222218")
		btn.add_theme_stylebox_override("normal",   sn)
		btn.add_theme_stylebox_override("hover",    sv)
		btn.add_theme_stylebox_override("pressed",  sp)
		btn.add_theme_stylebox_override("disabled", sd)

		var ico: String; var tc: Color
		if done:  ico = "✓  "; tc = Color("#FFD93D")
		elif ok:  ico = "▶  "; tc = col.lightened(0.4)
		else:     ico = "🔒 "; tc = Color("#444430")
		btn.text = ico + lbl
		btn.add_theme_color_override("font_color",          tc)
		btn.add_theme_color_override("font_disabled_color", Color("#333322"))
		btn.add_theme_color_override("font_hover_color",    tc.lightened(0.2))
		btn.add_theme_color_override("font_pressed_color",  Color("#FFD93D"))

		var cap_tid: int = tid; var cap_pos: Vector2 = ch["pos"] as Vector2
		btn.pressed.connect(func():
			_close_info_panel()
			_walk_avatar_to(cap_pos, func(): GameRouter.go_to_chapter(cap_tid)))
		_panel_vbox.add_child(btn); _tier_nodes.append(btn)

	_panel_layer.visible = true

func _close_info_panel() -> void:
	if is_instance_valid(_panel_layer): _panel_layer.visible = false
	for n in _tier_nodes: if is_instance_valid(n): n.queue_free()
	_tier_nodes.clear(); _selected_chapter = {}

# ─────────────────────────────────────────────────────────────────────────────
#  UNLOCK LOGIC
# ─────────────────────────────────────────────────────────────────────────────
func _is_unlocked(chapter_id: int) -> bool:
	if chapter_id == 1: return true
	if has_node("/root/PlayerProfile"): return PlayerProfile.is_chapter_unlocked(chapter_id)
	return (_map_data.get(chapter_id-1,{}) as Dictionary).get("complete",false) as bool

# ─────────────────────────────────────────────────────────────────────────────
#  ENTER ANIMATION
# ─────────────────────────────────────────────────────────────────────────────
func _play_enter_animation() -> void:
	if not is_instance_valid(_anim): return
	var anim := Animation.new(); anim.length = 0.9
	var t: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, ".:modulate:a")
	anim.track_insert_key(t, 0.0, 0.0)
	anim.track_insert_key(t, 0.9, 1.0)
	var lib := AnimationLibrary.new(); lib.add_animation("enter", anim)
	_anim.add_animation_library("", lib); _anim.play("enter")

# ─────────────────────────────────────────────────────────────────────────────
#  DRAW  — background + roads + overlays (sprites drawn by their own Sprite2D)
# ─────────────────────────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_background()
	_draw_roads()
	_update_sprite_tints()   # refresh tints each frame in case unlock state changed
	_draw_node_overlays()    # rings, badges, pips, labels — drawn ON TOP of sprites

func _update_sprite_tints() -> void:
	for ch: Dictionary in CHAPTERS:
		var cid: int   = ch["id"]    as int
		var col: Color = ch["color"] as Color
		var sprite = _sprite_nodes.get(cid, null)
		if sprite != null and is_instance_valid(sprite):
			# Hover: brighten slightly
			var new_mod := _sprite_tint(cid, col)
			if _hover_id == cid and (_is_unlocked(cid) or _is_teacher):
				new_mod = new_mod.lightened(0.15)
			sprite.modulate = new_mod

func _draw_background() -> void:
	var bands := 28
	for i in range(bands):
		var t := float(i) / float(bands)
		var col: Color
		if t < 0.65:
			col = Color("#080a14").lerp(Color("#0d1a34"), t / 0.65)
		else:
			col = Color("#0d1a34").lerp(Color("#101e2e"), (t - 0.65) / 0.35)
		draw_rect(Rect2(0, t * 720.0, 1280, 720.0 / bands + 1), col)

	draw_colored_polygon(PackedVector2Array([
		Vector2(0,720),   Vector2(0,490),   Vector2(100,440), Vector2(230,475),
		Vector2(360,415), Vector2(480,460), Vector2(590,400), Vector2(700,435),
		Vector2(810,395), Vector2(930,440), Vector2(1060,405),Vector2(1180,445),
		Vector2(1280,415),Vector2(1280,720)]), Color("#0d1826"))

	draw_colored_polygon(PackedVector2Array([
		Vector2(0,720),   Vector2(0,555),   Vector2(70,515),  Vector2(170,548),
		Vector2(280,505), Vector2(400,540), Vector2(510,500), Vector2(620,538),
		Vector2(730,498), Vector2(855,535), Vector2(970,498), Vector2(1090,530),
		Vector2(1200,500),Vector2(1280,520),Vector2(1280,720)]), Color("#0b1520"))

	draw_rect(Rect2(0, 598, 1280, 122), Color("#080c14"))
	draw_rect(Rect2(0, 598, 1280, 3),   Color("#1a2a40") * Color(1,1,1,0.5))

	for s: Vector2 in _stars:
		var b := 0.3 + fmod(s.x * 0.0031 + s.y * 0.0019, 0.65)
		draw_circle(s, 1.0, Color(b, b, b + 0.08, b))

	draw_circle(Vector2(1170, 105), 40, Color("#bdd0e8"))
	draw_circle(Vector2(1188, 95),  36, Color("#080a14"))
	draw_arc(Vector2(1170, 105), 50, 0, TAU, 32, Color(0.65, 0.78, 1.0, 0.10), 10.0)

	for i in range(14):
		var bx := 300.0 + i * 48.0
		var bh := 16.0 + fmod(float(i) * 8.1, 30.0)
		draw_rect(Rect2(bx, 598 - bh, 13, bh), Color(0.12, 0.18, 0.30, 0.75))
		if int(fmod(float(i), 2.0)) == 0:
			draw_rect(Rect2(bx+3, 601 - bh + 4, 4, 3), Color(0.95, 0.85, 0.2, 0.55))

	for i in range(7):
		draw_arc(Vector2(i * 200.0 + 60, 612), 120, 0, PI, 16, Color(0.25, 0.45, 0.75, 0.055), 20.0)

func _draw_roads() -> void:
	for conn: Array in ROADS:
		var pa: Vector2 = CHAPTERS[conn[0]]["pos"] as Vector2
		var pb: Vector2 = CHAPTERS[conn[1]]["pos"] as Vector2
		var done: bool  = (_map_data.get(CHAPTERS[conn[0]]["id"] as int, {}) as Dictionary)\
			.get("complete", false) as bool
		draw_line(pa, pb, Color(0,0,0,0.5), 9.0)
		draw_line(pa, pb, Color("#3a2c10") if done else Color("#1e1a0c"), 5.0)
		draw_line(pa, pb, Color("#5a4820") if done else Color("#14100a"), 2.0)

# ─────────────────────────────────────────────────────────────────────────────
#  NODE OVERLAYS
#  Drawn on top of the Sprite2D children.
#  When no sprite was loaded (null in _sprite_nodes), draws the full circle
#  + emoji fallback so the map always looks complete.
# ─────────────────────────────────────────────────────────────────────────────
func _draw_node_overlays() -> void:
	for ch: Dictionary in CHAPTERS:
		var cid:   int     = ch["id"]    as int
		var pos:   Vector2 = ch["pos"]   as Vector2
		var col:   Color   = ch["color"] as Color
		var d:     Dictionary = _map_data.get(cid,{}) as Dictionary
		var unlocked: bool = _is_unlocked(cid)
		var vis:   bool = unlocked or _is_teacher
		var complete: bool = d.get("complete",false) as bool
		var mastered: bool = d.get("mastered",false) as bool
		var hover: bool = _hover_id == cid
		var score: int  = d.get("best_score",0) as int
		var tiers: int  = ch.get("tiers",1) as int
		var has_sprite: bool = _sprite_nodes.get(cid, null) != null

		# ── Fallback: full circle if sprite missing ──────────────────────────
		if not has_sprite:
			draw_circle(pos + Vector2(4,6), 50, Color(0,0,0,0.42))
			if hover and vis: draw_circle(pos, 60, col * Color(1,1,1,0.18))
			draw_circle(pos, 48, col.darkened(0.45) if vis else Color("#111010"))
			draw_string(ThemeDB.fallback_font, pos + Vector2(-14,10),
				ch.get("icon","?") as String, HORIZONTAL_ALIGNMENT_LEFT, -1, 26,
				col if vis else Color("#22200c"))
		else:
			# ── Sprite present: drop shadow behind the sprite ────────────────
			draw_circle(pos + Vector2(4, 6), 50, Color(0,0,0,0.36))
			# Hover glow behind the sprite
			if hover and vis:
				draw_circle(pos, 62, col * Color(1,1,1,0.20))

		# ── Decorative ring (always drawn, sprite or not) ────────────────────
		var bc: Color
		if mastered:    bc = Color("#FFD93D")
		elif hover:     bc = col.lightened(0.4)
		elif vis:       bc = col
		else:           bc = Color("#2a2612")
		draw_arc(pos, 50, 0, TAU, 48, bc, 2.5)
		if vis:
			draw_arc(pos, 42, 0, TAU, 40, col * Color(1,1,1,0.30), 1.0)

		# ── Lock overlay (dark vignette + lock icon) ─────────────────────────
		if not vis:
			# Semi-transparent dark circle masks the sprite
			draw_circle(pos, 50, Color(0,0,0,0.58))
			draw_string(ThemeDB.fallback_font, pos + Vector2(-12,8),
				"🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("#888844"))

		# ── Completion / mastery stars ────────────────────────────────────────
		if complete:
			draw_string(ThemeDB.fallback_font, pos + Vector2(-10,-64), "⭐",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#FFD93D"))
		if mastered:
			draw_string(ThemeDB.fallback_font, pos + Vector2(12,-64), "★",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#FFD93D"))

		# ── Name label (centred below node) ──────────────────────────────────
		var nm: String = ch["name"] as String
		draw_string(ThemeDB.fallback_font,
			Vector2(pos.x - nm.length()*3.5, pos.y + 94),
			nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			col if vis else Color("#282410"))

		if score > 0:
			var sc := "%d pts" % score
			draw_string(ThemeDB.fallback_font,
				Vector2(pos.x - sc.length()*3.0, pos.y + 110),
				sc, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#887838"))

		# ── Tier pips ─────────────────────────────────────────────────────────
		for t in range(tiers):
			var tdone: bool = (_map_data.get(cid+t,{}) as Dictionary).get("complete",false) as bool
			var pp: Vector2 = pos + Vector2(-((tiers-1)*9) + t*18, 66)
			draw_circle(pp, 5.5, col if tdone else Color("#1a1810"))
			draw_arc(pp, 5.5, 0, TAU, 12,
				col.lightened(0.3) if tdone else Color("#2e2c18"), 1.5)

# ─────────────────────────────────────────────────────────────────────────────
#  HOVER / CLICK
# ─────────────────────────────────────────────────────────────────────────────
func _hover(cid: int, pos: Vector2) -> void:
	_hover_id = cid
	var ch: Dictionary = CHAPTERS.filter(func(c): return c["id"] == cid)[0]
	var d := _map_data.get(cid,{}) as Dictionary
	var complete: bool = d.get("complete",false) as bool
	var mastered: bool = d.get("mastered",false) as bool
	var tiers:    int  = ch.get("tiers",1) as int
	var done_c := 0
	for t in range(tiers):
		if (_map_data.get(cid+t,{}) as Dictionary).get("complete",false): done_c += 1
	var status: String
	if not _is_unlocked(cid) and not _is_teacher:
		status = "🔒 Complete previous chapter first"
	elif mastered: status = "★ Mastered! Click to select difficulty"
	elif complete: status = "✓ Complete — click to replay"
	else:          status = "▶ Click to select difficulty!"
	if is_instance_valid(_tooltip_bg):
		_tooltip_bg.visible  = true
		_tooltip_bg.position = Vector2(min(pos.x + 62, 1010), pos.y - 22)
		_tooltip_lbl.text    = "%s\nDSA: %s\nProgress: %d/%d tiers\n%s" % [
			ch["name"] as String, ch["dsa"] as String, done_c, tiers, status]
	queue_redraw()

func _unhover() -> void:
	_hover_id = -1
	if is_instance_valid(_tooltip_bg): _tooltip_bg.visible = false
	queue_redraw()

func _click(cid: int, unlocked: bool, _pos: Vector2) -> void:
	if not unlocked and not _is_teacher:
		if has_node("/root/AudioManager"): AudioManager.play_sfx("wrong")
		return
	if has_node("/root/AudioManager"): AudioManager.play_sfx("click")
	_close_info_panel()
	var ch: Dictionary = CHAPTERS.filter(func(c): return c["id"] == cid)[0]
	_open_info_panel(ch)

# ─────────────────────────────────────────────────────────────────────────────
#  AVATAR WALK
# ─────────────────────────────────────────────────────────────────────────────
func _walk_avatar_to(target: Vector2, after: Callable) -> void:
	if not is_instance_valid(_avatar): after.call(); return
	if is_instance_valid(_badge_ring):
		var sq := create_tween()
		sq.tween_property(_badge_ring, "scale", Vector2(1.2, 0.8), 0.12)
		sq.tween_property(_badge_ring, "scale", Vector2(1.0, 1.0), 0.12)
	var tw := create_tween()
	tw.tween_property(_avatar, "position", target, 0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _avatar_pos = target; after.call())

func _process(_delta: float) -> void:
	pass
