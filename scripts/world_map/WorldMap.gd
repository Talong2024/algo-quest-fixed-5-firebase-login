# =============================================================================
# AlgoQuest — World Map
# File: scripts/world_map/WorldMap.gd
#
# World map nodes → correct GameRouter chapter IDs:
#   Kingdom Gate    → chapter 1  (Queue Beginner, tiers 1-5 handled internally)
#   Castle of Echoes→ chapter 6  (Stack)
#   Chain Station   → chapter 7  (LinkedList)
#   Oracle's Forest → chapter 16  (Tree Beginner, tiers 16-20 handled internally)
#   Kingdom Roads   → chapter 13 (Graph)
#
# CHANGE LOG:
#   • Clicking a node now opens a tier-selection panel instead of jumping
#     straight to chapter 1. Each tier shows its difficulty label and is
#     enabled only if the player has reached it (sequential unlock within
#     the family) or has already completed it (free replay).
# =============================================================================

extends Node2D

const PATH_FONT  := "res://assets/fonts/freepixel.ttf"
const HERO_BASE  := "res://assets/art/character/heroes/"
const ANIM_FRAME_NAMES: Array[String] = ["walk1", "stand", "walk2"]
const IDLE_FPS   := 4.0
const WALK_FPS   := 6.0
const DEFAULT_HERO := "paladin"

# Difficulty labels shown on tier buttons (index 0 = tier 1 = Beginner, etc.)
const TIER_LABELS: Array[String] = ["Easy", "Normal", "Hard", "Expert", "Master"]

# ─────────────────────────────────────────────────────────────────────────────
#  CHAPTER DATA
#  "id" must match the FIRST chapter in each family (GameRouter handles tiers)
# ─────────────────────────────────────────────────────────────────────────────
const CHAPTERS: Array = [
	{ "id":1,  "name":"Kingdom Gate",     "game":"Kingdom Queue",
	  "dsa":"Queue — FIFO",       "pos":Vector2(300, 380),
	  "color":Color("#6BCB77"),   "icon":"🏰",
	  "tiers":5,  "tier_label":"Queue tiers 1-5" },
	{ "id":6,  "name":"Castle of Echoes", "game":"Castle Stack",
	  "dsa":"Stack — LIFO",       "pos":Vector2(500, 230),
	  "color":Color("#C77DFF"),   "icon":"🗼",
	  "tiers":5,  "tier_label":"Stack tiers 1-5" },
	{ "id":11,  "name":"Chain Station",    "game":"Chain Train",
	  "dsa":"Linked List",        "pos":Vector2(700, 370),
	  "color":Color("#FFD93D"),   "icon":"🚂",
	  "tiers":5,  "tier_label":"LinkedList tiers 1-5" },
	{ "id":16,  "name":"Oracle's Forest",  "game":"Oracle's Forest",
	  "dsa":"BST / AVL Tree",     "pos":Vector2(880, 220),
	  "color":Color("#88CC77"),   "icon":"🌲",
	  "tiers":5,  "tier_label":"Tree tiers 1-5" },
	{ "id":21, "name":"Kingdom Roads",    "game":"Kingdom Roads",
	  "dsa":"Graph Algorithms",   "pos":Vector2(1040, 390),
	  "color":Color("#4D96FF"),   "icon":"🗺",
	  "tiers":5,  "tier_label":"Graph tiers 1-5" },
]

# Road connections use array INDEX (0-based), not chapter id
const ROADS: Array = [[0,1],[0,2],[1,2],[1,3],[2,4],[3,4]]

# Which chapter ids count as "complete" for unlock purposes
# Completing chapter 5 unlocks chapter 6, completing 6 unlocks 7, etc.
const UNLOCK_CHAIN: Dictionary = {
	5:  6,   # finishing Queue Expert (ch 5)  unlocks Stack (ch 6)
	10: 11,  # Stack Expert (ch 10)           unlocks LinkedList (ch 11)
	15: 16,  # LinkedList Expert (ch 15)      unlocks Tree (ch 16)
	20: 21,  # Tree Expert (ch 20)            unlocks Graph (ch 21)
}

# ─────────────────────────────────────────────────────────────────────────────
#  NODE REFS
# ─────────────────────────────────────────────────────────────────────────────
@onready var _map_bg:       Sprite2D        = $MapBackground
@onready var _avatar:       Node2D          = $PlayerAvatar
@onready var _anim:         AnimationPlayer = $AnimationPlayer
@onready var _tooltip_bg:   Control         = $HUD/TooltipBG
@onready var _tooltip_lbl:  Label           = $HUD/TooltipBG/TooltipLbl

# ─────────────────────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────────────────────
var _pixel_font:   Font        = null
var _frames_cache: Dictionary  = {}
var _map_data:     Dictionary  = {}
var _hover_id:     int         = -1
var _avatar_pos:   Vector2     = Vector2(300, 380)
var _av_sprite:    AnimatedSprite2D = null

# Tier-panel — built entirely in code on a CanvasLayer so it always floats
# centred on screen above the map, independent of world-space transforms.
var _panel_layer:   CanvasLayer = null   # layer that hosts the modal
var _panel_dim:     ColorRect   = null   # full-screen dark overlay
var _panel_root:    PanelContainer = null # the visible card
var _panel_vbox:    VBoxContainer  = null # content inside card
var _tier_nodes:    Array          = []   # dynamically added nodes (cleared on close)
var _selected_chapter: Dictionary  = {}  # chapter currently shown

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font
	# PlayerProfile is the canonical autoload; streak is updated internally on load
	if has_node("/root/PlayerProfile") and PlayerProfile.is_loaded():
		_map_data = PlayerProfile.progress

	_build_map_background()
	_build_player_avatar()
	_build_hud()
	_build_region_areas()
	_build_info_panel()
	_play_enter_animation()
	queue_redraw()

# ─────────────────────────────────────────────────────────────────────────────
#  MAP BACKGROUND
# ─────────────────────────────────────────────────────────────────────────────
func _build_map_background() -> void:
	var path := "res://assets/codemon/art/map/bg_forest.png"
	if ResourceLoader.exists(path) and is_instance_valid(_map_bg):
		_map_bg.texture  = load(path)
		_map_bg.position = Vector2(640, 360)

# ─────────────────────────────────────────────────────────────────────────────
#  PLAYER AVATAR
# ─────────────────────────────────────────────────────────────────────────────
func _build_player_avatar() -> void:
	var hero_key := DEFAULT_HERO
	if has_node("/root/PlayerProfile"):
		var saved: String = PlayerProfile.get_selected_hero()
		if saved != "": hero_key = saved

	_av_sprite = AnimatedSprite2D.new()
	_av_sprite.sprite_frames  = _make_sprite_frames(hero_key)
	_av_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_av_sprite.scale          = Vector2(-3.5, 3.5)   # negative X → faces right/forward
	_av_sprite.z_index        = 5
	_av_sprite.play("idle")
	_avatar.add_child(_av_sprite)

	var name_lbl := Label.new()
	name_lbl.text = PlayerProfile.get_username() \
		if has_node("/root/PlayerProfile") else "Hero"
	if _pixel_font: name_lbl.add_theme_font_override("font", _pixel_font)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	name_lbl.position = Vector2(-24, -72)
	_avatar.add_child(name_lbl)
	_avatar.position = _avatar_pos

# ─────────────────────────────────────────────────────────────────────────────
#  HUD
# ─────────────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var hud_bar: CanvasLayer = $HUD as CanvasLayer

	var bg := ColorRect.new()
	bg.color    = Color(0, 0, 0, 0.78)
	bg.position = Vector2.ZERO
	bg.size     = Vector2(1280, 58)
	hud_bar.add_child(bg)

	_hud_lbl(hud_bar, "ALGOQUEST",   Vector2(20, 8),  10, Color("#4D96FF"))
	_hud_lbl(hud_bar, "Kingdom Map", Vector2(20, 26), 20, Color("#e8e8d0"))

	if has_node("/root/PlayerProfile"):
		_hud_lbl(hud_bar, PlayerProfile.get_username(),
			Vector2(820, 10), 13, Color("#888860"))
		var stats := PlayerProfile.stats as Dictionary
		_hud_lbl(hud_bar,
			"Score: %d  |  Perfects: %d  |  Streak: %d days" % [
				stats.get("total_score",    0) as int,
				stats.get("perfect_clears", 0) as int,
				stats.get("login_streak",   0) as int],
			Vector2(820, 30), 12, Color("#FFD93D"))

	var btns: Array = [
		["Character", func(): GameRouter.go_char_select()],
		["Progress",  func(): GameRouter.go_progress_screen()],
		["Settings",  func(): GameRouter.go_settings()],
	]
	for i: int in btns.size():
		var b := Button.new()
		b.text = btns[i][0] as String
		b.custom_minimum_size = Vector2(96, 28)
		if _pixel_font: b.add_theme_font_override("font", _pixel_font)
		b.add_theme_font_size_override("font_size", 13)
		b.position = Vector2(790 + i * 108, 62)
		b.pressed.connect(btns[i][1] as Callable)
		hud_bar.add_child(b)

	var topics: Array[String] = ["queue","stack","linked_list","tree","graph"]
	var tcols:  Array[Color]  = [
		Color("#6BCB77"), Color("#C77DFF"), Color("#FFD93D"),
		Color("#88CC77"), Color("#4D96FF")]
	# DSA mastery dot = all 5 tiers of that family complete in PlayerProfile.progress
	var family_starts: Array[int] = [1, 6, 11, 16, 21]
	for i: int in topics.size():
		var mastered := false
		if has_node("/root/PlayerProfile"):
			mastered = true
			for t in range(5):
				if not (PlayerProfile.progress.get(family_starts[i] + t, {}) \
						as Dictionary).get("complete", false) as bool:
					mastered = false; break
		var dot      := ColorRect.new()
		dot.color    = tcols[i] if mastered else Color("#1a1a2a")
		dot.position = Vector2(200 + i * 24, 68)
		dot.size     = Vector2(18, 10)
		hud_bar.add_child(dot)

	if is_instance_valid(_tooltip_bg):
		_tooltip_bg.visible = false
		if _pixel_font and is_instance_valid(_tooltip_lbl):
			_tooltip_lbl.add_theme_font_override("font", _pixel_font)
			_tooltip_lbl.add_theme_font_size_override("font_size", 13)

func _hud_lbl(parent: Node, text: String, pos: Vector2,
			   sz: int, col: Color) -> void:
	var l := Label.new()
	l.text     = text
	l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if _pixel_font: l.add_theme_font_override("font", _pixel_font)
	parent.add_child(l)

# ─────────────────────────────────────────────────────────────────────────────
#  CHAPTER CLICK AREAS
# ─────────────────────────────────────────────────────────────────────────────
func _build_region_areas() -> void:
	for ch: Dictionary in CHAPTERS:
		var cid:      int     = ch["id"]  as int
		var pos:      Vector2 = ch["pos"] as Vector2
		var unlocked: bool    = _is_unlocked(cid)

		var area  := Area2D.new()
		var shape := CollisionShape2D.new()
		var circ  := CircleShape2D.new()
		circ.radius = 54.0
		shape.shape = circ
		area.position = pos
		area.add_child(shape)
		area.input_event.connect(func(_vp: Node, event: InputEvent, _idx: int):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					_click(cid, _is_unlocked(cid), pos))
		area.mouse_entered.connect(func(): _hover(cid, pos))
		area.mouse_exited.connect(func():  _unhover())
		add_child(area)

# ─────────────────────────────────────────────────────────────────────────────
#  INFO PANEL — a centred modal built entirely in code on a CanvasLayer
#  so it always sits at a fixed screen position above all world-space nodes.
# ─────────────────────────────────────────────────────────────────────────────
func _build_info_panel() -> void:
	# CanvasLayer so the panel ignores world-space camera/transforms
	_panel_layer = CanvasLayer.new()
	_panel_layer.layer = 20          # above HUD (layer 10) and everything else
	_panel_layer.visible = false
	add_child(_panel_layer)

	# Full-screen dim overlay — clicking it closes the panel
	_panel_dim = ColorRect.new()
	_panel_dim.color             = Color(0.0, 0.0, 0.0, 0.55)
	_panel_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				_close_info_panel())
	_panel_layer.add_child(_panel_dim)

	# Card — centred on screen
	_panel_root = PanelContainer.new()
	_panel_root.custom_minimum_size = Vector2(300, 0)
	_panel_root.set_anchors_preset(Control.PRESET_CENTER)
	# Offset so it's centred properly (PanelContainer grows downward from anchor)
	_panel_root.pivot_offset = Vector2(150, 0)

	# Dark styled background
	var sb := StyleBoxFlat.new()
	sb.bg_color          = Color("#12121e")
	sb.border_color      = Color("#FFD93D")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left   = 20
	sb.content_margin_right  = 20
	sb.content_margin_top    = 16
	sb.content_margin_bottom = 20
	_panel_root.add_theme_stylebox_override("panel", sb)
	_panel_layer.add_child(_panel_root)

	_panel_vbox = VBoxContainer.new()
	_panel_vbox.add_theme_constant_override("separation", 8)
	_panel_root.add_child(_panel_vbox)

func _open_info_panel(ch: Dictionary) -> void:
	_selected_chapter = ch
	var cid:   int        = ch["id"]    as int
	var tiers: int        = ch.get("tiers", 1) as int
	var col:   Color      = ch["color"] as Color
	var d:     Dictionary = _map_data.get(cid, {}) as Dictionary
	var score: int        = d.get("best_score", 0) as int

	# Clear previous dynamic nodes
	for n in _tier_nodes:
		if is_instance_valid(n): n.queue_free()
	_tier_nodes.clear()

	# ── Header row: icon + title + close button ───────────────────────────────
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	_panel_vbox.add_child(header)
	_tier_nodes.append(header)

	var icon_lbl := Label.new()
	icon_lbl.text = ch["icon"] as String
	icon_lbl.add_theme_font_size_override("font_size", 26)
	header.add_child(icon_lbl)

	var title_lbl := Label.new()
	title_lbl.text = ch["name"] as String
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _pixel_font: title_lbl.add_theme_font_override("font", _pixel_font)
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", col)
	header.add_child(title_lbl)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(28, 28)
	if _pixel_font: close_btn.add_theme_font_override("font", _pixel_font)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", Color("#aaaaaa"))
	close_btn.pressed.connect(_close_info_panel)
	header.add_child(close_btn)

	# ── Divider ───────────────────────────────────────────────────────────────
	var div := HSeparator.new()
	var div_sb := StyleBoxFlat.new()
	div_sb.bg_color = col.darkened(0.3)
	div_sb.content_margin_top = 1
	div.add_theme_stylebox_override("separator", div_sb)
	_panel_vbox.add_child(div)
	_tier_nodes.append(div)

	# ── DSA subtitle ─────────────────────────────────────────────────────────
	var dsa_lbl := Label.new()
	dsa_lbl.text = ch["dsa"] as String
	if _pixel_font: dsa_lbl.add_theme_font_override("font", _pixel_font)
	dsa_lbl.add_theme_font_size_override("font_size", 12)
	dsa_lbl.add_theme_color_override("font_color", Color("#888860"))
	_panel_vbox.add_child(dsa_lbl)
	_tier_nodes.append(dsa_lbl)

	# ── Star row ──────────────────────────────────────────────────────────────
	var stars_hbox := HBoxContainer.new()
	stars_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_hbox.add_theme_constant_override("separation", 4)
	_panel_vbox.add_child(stars_hbox)
	_tier_nodes.append(stars_hbox)
	for t in range(tiers):
		var done: bool = (_map_data.get(cid + t, {}) as Dictionary)\
			.get("complete", false) as bool
		var star := Label.new()
		star.text = "⭐" if done else "☆"
		star.add_theme_font_size_override("font_size", 18)
		star.add_theme_color_override("font_color",
			Color("#FFD93D") if done else Color("#333322"))
		stars_hbox.add_child(star)

	# ── Best score ────────────────────────────────────────────────────────────
	var score_lbl := Label.new()
	score_lbl.text = "Best: %d pts" % score if score > 0 else "Not yet played"
	score_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: score_lbl.add_theme_font_override("font", _pixel_font)
	score_lbl.add_theme_font_size_override("font_size", 12)
	score_lbl.add_theme_color_override("font_color",
		Color("#FFD93D") if score > 0 else Color("#666650"))
	_panel_vbox.add_child(score_lbl)
	_tier_nodes.append(score_lbl)

	# ── Difficulty heading ────────────────────────────────────────────────────
	var diff_lbl := Label.new()
	diff_lbl.text = "— Select Difficulty —"
	diff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: diff_lbl.add_theme_font_override("font", _pixel_font)
	diff_lbl.add_theme_font_size_override("font_size", 11)
	diff_lbl.add_theme_color_override("font_color", Color("#666650"))
	_panel_vbox.add_child(diff_lbl)
	_tier_nodes.append(diff_lbl)

	# ── Tier buttons ──────────────────────────────────────────────────────────
	for t in range(tiers):
		var tier_id:   int  = cid + t
		var tier_done: bool = (_map_data.get(tier_id, {}) as Dictionary)\
			.get("complete", false) as bool
		var prev_done: bool = t == 0 or \
			(_map_data.get(cid + t - 1, {}) as Dictionary)\
			.get("complete", false) as bool
		var accessible: bool = prev_done or tier_done

		var label_text: String = TIER_LABELS[t] \
			if t < TIER_LABELS.size() else "Tier %d" % (t + 1)

		var btn := Button.new()
		btn.text = label_text
		btn.disabled = not accessible
		btn.custom_minimum_size = Vector2(260, 40)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _pixel_font:
			btn.add_theme_font_override("font", _pixel_font)
		btn.add_theme_font_size_override("font_size", 15)

		# Build coloured StyleBoxFlat for each state
		var btn_sb_normal  := StyleBoxFlat.new()
		var btn_sb_hover   := StyleBoxFlat.new()
		var btn_sb_pressed := StyleBoxFlat.new()
		var btn_sb_dis     := StyleBoxFlat.new()

		var base_col: Color
		if tier_done:
			base_col = Color("#7a6000")          # gold-ish for completed
		elif accessible:
			base_col = col.darkened(0.55)        # chapter colour, darker fill
		else:
			base_col = Color("#1a1a14")          # near-black for locked

		for sb in [btn_sb_normal, btn_sb_hover, btn_sb_pressed, btn_sb_dis]:
			sb.set_corner_radius_all(5)
			sb.set_border_width_all(1)

		btn_sb_normal.bg_color  = base_col
		btn_sb_normal.border_color = col if accessible else Color("#333322")
		btn_sb_hover.bg_color   = base_col.lightened(0.18) if accessible else base_col
		btn_sb_hover.border_color = col.lightened(0.3) if accessible else Color("#333322")
		btn_sb_pressed.bg_color = base_col.darkened(0.2)
		btn_sb_pressed.border_color = Color("#FFD93D")
		btn_sb_dis.bg_color     = Color("#111110")
		btn_sb_dis.border_color = Color("#222218")

		for sb in [btn_sb_normal, btn_sb_hover, btn_sb_pressed, btn_sb_dis]:
			sb.content_margin_left  = 12
			sb.content_margin_right = 12

		btn.add_theme_stylebox_override("normal",   btn_sb_normal)
		btn.add_theme_stylebox_override("hover",    btn_sb_hover)
		btn.add_theme_stylebox_override("pressed",  btn_sb_pressed)
		btn.add_theme_stylebox_override("disabled", btn_sb_dis)

		# Icon prefix + text colour
		var status_icon: String
		var txt_col: Color
		if tier_done:
			status_icon = "✓  "; txt_col = Color("#FFD93D")
		elif accessible:
			status_icon = "▶  "; txt_col = col.lightened(0.4)
		else:
			status_icon = "🔒 "; txt_col = Color("#444430")
		btn.text = status_icon + label_text
		btn.add_theme_color_override("font_color",          txt_col)
		btn.add_theme_color_override("font_disabled_color", Color("#333322"))
		btn.add_theme_color_override("font_hover_color",    txt_col.lightened(0.2))
		btn.add_theme_color_override("font_pressed_color",  Color("#FFD93D"))

		var captured_tid: int    = tier_id
		var captured_pos: Vector2 = ch["pos"] as Vector2
		btn.pressed.connect(func():
			_close_info_panel()
			_walk_avatar_to(captured_pos, func():
				GameRouter.go_to_chapter(captured_tid)))

		_panel_vbox.add_child(btn)
		_tier_nodes.append(btn)

	# Recentre card vertically now that we know its height
	_panel_root.set_anchors_preset(Control.PRESET_CENTER)
	_panel_root.position -= Vector2(150, 0)   # shift left by half min-width

	_panel_layer.visible = true

func _close_info_panel() -> void:
	if is_instance_valid(_panel_layer):
		_panel_layer.visible = false
	for n in _tier_nodes:
		if is_instance_valid(n): n.queue_free()
	_tier_nodes.clear()
	_selected_chapter = {}

# ─────────────────────────────────────────────────────────────────────────────
#  UNLOCK LOGIC
#  Chapter 1 (Queue) always unlocked.
#  Others unlock when the last tier of the previous family is complete.
# ─────────────────────────────────────────────────────────────────────────────
func _is_unlocked(chapter_id: int) -> bool:
	if chapter_id == 1: return true
	if has_node("/root/PlayerProfile"):
		return PlayerProfile.is_chapter_unlocked(chapter_id)
	# Fallback: check _map_data populated at ready
	return (_map_data.get(chapter_id - 1, {}) as Dictionary)\
		.get("complete", false) as bool

# ─────────────────────────────────────────────────────────────────────────────
#  ENTER ANIMATION
# ─────────────────────────────────────────────────────────────────────────────
func _play_enter_animation() -> void:
	if not is_instance_valid(_anim): return
	var anim := Animation.new()
	anim.length = 0.8
	var t: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, ".:modulate:a")
	anim.track_insert_key(t, 0.0, 0.0)
	anim.track_insert_key(t, 0.8, 1.0)
	var lib := AnimationLibrary.new()
	lib.add_animation("enter", anim)
	_anim.add_animation_library("", lib)
	_anim.play("enter")

# ─────────────────────────────────────────────────────────────────────────────
#  DRAW — roads & chapter nodes
# ─────────────────────────────────────────────────────────────────────────────
func _draw() -> void:
	# Roads — ROADS uses 0-based indices into CHAPTERS array
	for conn: Array in ROADS:
		var pa: Vector2 = CHAPTERS[conn[0]]["pos"] as Vector2
		var pb: Vector2 = CHAPTERS[conn[1]]["pos"] as Vector2
		var id_a: int   = CHAPTERS[conn[0]]["id"] as int
		var ca: bool    = (_map_data.get(id_a, {}) as Dictionary)\
			.get("complete", false) as bool
		draw_line(pa, pb, Color("#3a3010"), 6.0)
		draw_line(pa, pb, Color("#5a5020") if ca else Color("#2a2010"), 3.0)

	# Chapter nodes
	for ch: Dictionary in CHAPTERS:
		var cid:      int        = ch["id"]    as int
		var pos:      Vector2    = ch["pos"]   as Vector2
		var col:      Color      = ch["color"] as Color
		var d:        Dictionary = _map_data.get(cid, {}) as Dictionary
		var unlocked: bool       = _is_unlocked(cid)
		var complete: bool       = d.get("complete", false) as bool
		var mastered: bool       = d.get("mastered", false) as bool
		var hover:    bool       = _hover_id == cid
		var score:    int        = d.get("best_score", 0)   as int

		# ── Tier progress pip row (shown for multi-tier families) ─────────────
		var tiers: int = ch.get("tiers", 1) as int
		if tiers > 1:
			for t in range(tiers):
				var tier_ch_id: int = cid + t
				var tier_done: bool = (_map_data.get(tier_ch_id, {}) as Dictionary)\
					.get("complete", false) as bool
				var pip_pos := pos + Vector2(-((tiers - 1) * 9) + t * 18, 68)
				draw_circle(pip_pos, 5.0,
					col if tier_done else Color("#2a2a1a"))
				draw_arc(pip_pos, 5.0, 0, TAU, 12,
					col.lightened(0.3) if tier_done else Color("#444430"), 1.5)

		draw_circle(pos + Vector2(3, 3), 46, Color(0, 0, 0, 0.5))
		draw_circle(pos, 46, col.darkened(0.5) if unlocked else Color("#1a1a10"))
		if hover and unlocked:
			draw_circle(pos, 52, col * Color(1, 1, 1, 0.18))
		var border_col: Color = Color("#FFD93D") if mastered else \
			(col.lightened(0.3) if hover else (col if unlocked else Color("#2a2a10")))
		draw_arc(pos, 46, 0, TAU, 32, border_col, 2.5)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-12, 8),
			ch["icon"] as String, HORIZONTAL_ALIGNMENT_LEFT, -1, 22,
			col if unlocked else Color("#333320"))
		if not unlocked:
			draw_string(ThemeDB.fallback_font, pos + Vector2(-10, 22),
				"🔒", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#555530"))
		if complete:
			draw_string(ThemeDB.fallback_font, pos + Vector2(-10, -56),
				"⭐", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("#FFD93D"))
		if mastered:
			draw_string(ThemeDB.fallback_font, pos + Vector2(10, -56),
				"★", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#FFD93D"))
		draw_string(ThemeDB.fallback_font, pos + Vector2(-42, 82),
			ch["name"] as String, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			col if unlocked else Color("#333320"))
		if score > 0:
			draw_string(ThemeDB.fallback_font, pos + Vector2(-24, 96),
				"%d pts" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
				Color("#888840"))

# ─────────────────────────────────────────────────────────────────────────────
#  HOVER / CLICK
# ─────────────────────────────────────────────────────────────────────────────
func _hover(cid: int, pos: Vector2) -> void:
	_hover_id = cid
	var ch: Dictionary = CHAPTERS.filter(func(c): return c["id"] == cid)[0]
	var unlocked: bool = _is_unlocked(cid)
	var d:         Dictionary = _map_data.get(cid, {}) as Dictionary
	var complete:  bool       = d.get("complete", false) as bool
	var mastered:  bool       = d.get("mastered", false) as bool
	var tiers:     int        = ch.get("tiers", 1) as int

	var status: String
	if not unlocked:
		status = "🔒 Complete previous chapter first"
	elif mastered:
		status = "★ Mastered! Click to select difficulty"
	elif complete:
		status = "✓ Complete — click to select difficulty"
	else:
		status = "▶ Click to select difficulty!"

	var tier_text: String = ""
	if tiers > 1:
		var done_count := 0
		for t in range(tiers):
			if (_map_data.get(cid + t, {}) as Dictionary).get("complete", false):
				done_count += 1
		tier_text = "\nProgress: %d / %d tiers" % [done_count, tiers]

	if is_instance_valid(_tooltip_bg):
		_tooltip_bg.visible  = true
		_tooltip_bg.position = pos + Vector2(56, -20)
		_tooltip_lbl.text    = "%s\nDSA: %s%s\n%s" % [
			ch["name"] as String,
			ch["dsa"]  as String,
			tier_text,
			status]
	queue_redraw()

func _unhover() -> void:
	_hover_id = -1
	if is_instance_valid(_tooltip_bg): _tooltip_bg.visible = false
	queue_redraw()

func _click(cid: int, unlocked: bool, pos: Vector2) -> void:
	if not unlocked:
		if has_node("/root/AudioManager"): AudioManager.play_sfx("wrong")
		return
	if has_node("/root/AudioManager"): AudioManager.play_sfx("click")

	# Close any open panel first, then open the tier selector for this chapter
	_close_info_panel()
	var ch: Dictionary = CHAPTERS.filter(func(c): return c["id"] == cid)[0]
	_open_info_panel(ch)

# ─────────────────────────────────────────────────────────────────────────────
#  AVATAR WALK
# ─────────────────────────────────────────────────────────────────────────────
func _walk_avatar_to(target: Vector2, after: Callable) -> void:
	if not is_instance_valid(_avatar):
		after.call(); return
	if is_instance_valid(_av_sprite):
		_av_sprite.play("walk")
		# scale.x is -3.5 (mirrored), so flip_h reverses that mirror:
		#   walking right → flip_h false  (keeps the -X mirror → faces right)
		#   walking left  → flip_h true   (cancels mirror → faces left)
		_av_sprite.flip_h = target.x > _avatar.position.x
	var tw := create_tween()
	tw.tween_property(_avatar, "position", target, 0.6).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func():
		_avatar_pos = target
		if is_instance_valid(_av_sprite):
			_av_sprite.play("idle")
			_av_sprite.flip_h = false   # idle default: faces right (forward)
		after.call())

# ─────────────────────────────────────────────────────────────────────────────
#  SPRITE FRAMES
#
#  Prefers {key}_sheet.png (full CGabriel spritesheet, 10 cols × N rows, 24px).
#  Row 0 = south (faces player). Slices col 0 / col 3 / col 6 for walk cycle.
#  Falls back to individually exported PNGs when the sheet is absent.
# ─────────────────────────────────────────────────────────────────────────────
func _make_sprite_frames(hero_key: String) -> SpriteFrames:
	if hero_key in _frames_cache: return _frames_cache[hero_key]

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	var sheet_path := "%s%s_sheet.png" % [HERO_BASE, hero_key]
	var use_sheet  := ResourceLoader.exists(sheet_path)
	var sheet_tex: Texture2D = null
	if use_sheet:
		sheet_tex = load(sheet_path) as Texture2D

	var _atlas := func(col_x: int, row_y: int) -> AtlasTexture:
		var a        := AtlasTexture.new()
		a.atlas       = sheet_tex
		a.region      = Rect2(col_x, row_y, 24, 24)
		a.filter_clip = true
		return a

	# idle — south row (y=0), cols 0 / 72 / 144
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", IDLE_FPS)
	if use_sheet:
		for col_x in [0, 72, 144]:
			sf.add_frame("idle", _atlas.call(col_x, 0))
	else:
		for frame_name in ANIM_FRAME_NAMES:
			var path := "%s%s_idle_%s.png" % [HERO_BASE, hero_key, frame_name]
			if ResourceLoader.exists(path): sf.add_frame("idle", load(path))

	# walk — same south row, faster playback
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", WALK_FPS)
	if use_sheet:
		for col_x in [0, 72, 144]:
			sf.add_frame("walk", _atlas.call(col_x, 0))
	else:
		for frame_name in ANIM_FRAME_NAMES:
			var path := "%s%s_walk_%s.png" % [HERO_BASE, hero_key, frame_name]
			if ResourceLoader.exists(path): sf.add_frame("walk", load(path))

	_frames_cache[hero_key] = sf
	return sf

func _process(_delta: float) -> void:
	pass
