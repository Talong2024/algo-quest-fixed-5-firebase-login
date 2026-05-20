# =============================================================================
# AlgoQuest — Chapter 4: Oracle's Forest (BST)
# =============================================================================
# TIER-BY-TIER CURRICULUM
# Tier 0 BEGINNER  — What is a BST? Insert only (guided ghost slots, 5 tiles)
# Tier 1 EASY      — Binary Search Algorithm (Insert 6 → Search 4)
# Tier 2 NORMAL    — Inorder Traversal (Insert 7 → Search 2 → Inorder tap 3)
# Tier 3 HARD      — Pre/Post Traversal + Deletion
#                    (Insert 8 → Search 2 → Preorder 2 → Postorder 2 → Delete 2)
# Tier 4 EXPERT    — AVL Self-Balancing
#                    (Insert/AVL 9 → Search 3 → Inorder tap 2)
# =============================================================================
extends Node2D

# ── Assets ───────────────────────────────────────────────────────────────────
const PATH_FONT       := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_OK     := "res://assets/audio/sfx/tile_place.ogg"
const PATH_SFX_FAIL   := "res://assets/audio/sfx/fail.ogg"
const PATH_SFX_WIN    := "res://assets/audio/sfx/level_up.ogg"
const PATH_SFX_PICKUP := "res://assets/audio/sfx/tile_pickup.wav"
const PATH_BGM        := "res://assets/audio/music/forest.ogg"
const NODE_ICON       := "res://assets/art/tree/nodes/runeBlack_tile_036.png"
const ROOT_ICON       := "res://assets/art/tree/nodes/runeBlack_tileOutline_036.png"
const NODE_SCALE      := Vector2(1.2, 1.2)

# ── Layout ───────────────────────────────────────────────────────────────────
const ROOT_POS   := Vector2(640.0, 90.0)
const LEVEL_H    := 85.0
const SPREAD_MUL := 180.0
const NODE_HIT   := 28.0
const SNAP_DIST  := 64.0
const MAGNET_R   := 100.0
const GHOST_R    := 30.0
const MAX_DEPTH  := 4
const POOL_Y     := 650.0

# ── Colours ──────────────────────────────────────────────────────────────────
const COL_EDGE       := Color(0.55, 0.85, 0.45, 0.85)
const COL_OK         := Color(0.3,  1.0,  0.4)
const COL_WRONG      := Color(1.0,  0.15, 0.15)
const COL_WHITE      := Color.WHITE
const COL_HEAD       := Color(1.0,  0.85, 0.1)
const COL_SEARCH_HI  := Color(0.4,  0.9,  1.0,  1.0)
const COL_ELIM       := Color(0.25, 0.25, 0.25, 0.4)
const COL_ANCESTRY   := Color(1.0,  0.85, 0.1,  0.9)
const COL_TRACE      := Color(1.0,  0.9,  0.3,  0.85)
const COL_GHOST_OK   := Color(0.3,  1.0,  0.5,  0.3)
const COL_GHOST_NO   := Color(1.0,  0.2,  0.2,  0.25)
const COL_GHOST_SNAP := Color(0.3,  1.0,  0.5,  0.75)
const COL_INORDER    := Color(0.5,  1.0,  0.7)
const COL_PREORDER   := Color(1.0,  0.7,  0.3)
const COL_POSTORDER  := Color(0.8,  0.5,  1.0)
const COL_DEL        := Color(1.0,  0.3,  0.3)
const COL_AVL_BAD    := Color(1.0,  0.4,  0.2)
const COL_AVL_OK     := Color(0.3,  1.0,  0.5)
const COL_NODE_BASE  := Color(0.65, 0.82, 0.55)

# ── Wood UI palette ────────────────────────────────────────────────────────────
const WOOD_DARK   := Color(0.22, 0.13, 0.06, 0.97)  # dark walnut fill
const WOOD_MID    := Color(0.34, 0.20, 0.08, 0.97)  # mid oak
const WOOD_LIGHT  := Color(0.52, 0.32, 0.12, 1.00)  # light pine plank
const WOOD_GRAIN  := Color(0.60, 0.38, 0.14, 1.00)  # grain highlight
const WOOD_BORDER := Color(0.72, 0.48, 0.18, 1.00)  # carved border
const WOOD_GOLD   := Color(0.95, 0.78, 0.25, 1.00)  # gilded trim
const WOOD_TEXT   := Color(0.98, 0.92, 0.72, 1.00)  # parchment text
const WOOD_SUBTEXT:= Color(0.82, 0.70, 0.45, 1.00)  # subdued parchment

# ── Tier config ───────────────────────────────────────────────────────────────
const TIER_CONFIG: Array[Dictionary] = [
	{ "name":"BEGINNER","insert_count":5,"insert_guided":true,"hints":true,
	  "phases":["insert"],"search_rounds":0,"trav_rounds":0,"delete_rounds":0,"avl_rounds":0 },
	{ "name":"EASY","insert_count":6,"insert_guided":false,"hints":true,
	  "phases":["insert","search"],"search_rounds":4,"trav_rounds":0,"delete_rounds":0,"avl_rounds":0 },
	{ "name":"NORMAL","insert_count":7,"insert_guided":false,"hints":false,
	  "phases":["insert","search","inorder"],"search_rounds":2,"trav_rounds":3,"delete_rounds":0,"avl_rounds":0 },
	{ "name":"HARD","insert_count":8,"insert_guided":false,"hints":false,
	  "phases":["insert","search","preorder","postorder","delete"],
	  "search_rounds":2,"trav_rounds":2,"delete_rounds":2,"avl_rounds":0 },
	{ "name":"EXPERT","insert_count":9,"insert_guided":false,"hints":false,
	  "phases":["insert","avl","search","inorder"],
	  "search_rounds":3,"trav_rounds":2,"delete_rounds":0,"avl_rounds":4 },
]

# ── Enums ─────────────────────────────────────────────────────────────────────
enum MasterPhase { INTRO, PLAYING, COMPLETE }
enum RoundType   { NONE, INSERT, SEARCH, INORDER, PREORDER, POSTORDER, DELETE, AVL }

# ── Scene refs ────────────────────────────────────────────────────────────────
@onready var _tree_layer:      Node2D         = $TreeLayer
@onready var _edge_layer:      Node2D         = $EdgeLayer
@onready var _ghost_layer:     Node2D         = $GhostLayer
@onready var _trace_layer:     Node2D         = $TraceLayer
@onready var _pool_tray:       Node2D         = $PoolTray
@onready var _complete_banner: Label          = $CompleteBanner
@onready var _trav_banner:     Label          = $HUD/TraversalBanner
@onready var _score_lbl:       Label          = $HUD/ScoreLabel
@onready var _combo_lbl:       Label          = $HUD/ComboLabel
@onready var _goal_lbl:        Label          = $HUD/GoalLabel
@onready var _acc_lbl:         Label          = $HUD/AccuracyLabel
@onready var _lives_row:       HBoxContainer  = $HUD/LivesRow
@onready var _hint_lbl:        Label          = $HUD/HintBox/HintLabel
@onready var _hint_box:        PanelContainer = $HUD/HintBox
@onready var _fail_summary:    PanelContainer = $HUD/FailSummary
@onready var _fail_lbl:        Label          = $HUD/FailSummary/FailLabel

# ── Runtime state ─────────────────────────────────────────────────────────────
var _cfg:          Dictionary  = {}
var _tier:         int         = 0
var _master_phase: MasterPhase = MasterPhase.INTRO
var _round_type:   RoundType   = RoundType.NONE
var _is_dragging:  bool        = false

# BST  {value, sprite, left, right, parent, pos, depth, height}
var _bst:  Array = []
var _root: int   = -1
var _ghosts: Array = []

# Insert drag
var _pool:           Array   = []
var _drag_pool_idx:  int     = -1
var _drag_offset:    Vector2 = Vector2.ZERO
var _snap_ghost_idx: int     = -1

# Tap / search / traversal
var _target_val:     int   = -1
var _tap_path:       Array = []
var _tap_idx:        int   = 0
var _round_mistakes: int   = 0
var _rounds_done:    int   = 0
var _trav_sequence:  Array = []
var _trav_hi:        int   = 0   # highlighted index in trav_sequence

# Phase queue
var _phase_queue:         Array  = []
var _current_phase_name:  String = ""

# AVL / Delete
var _avl_pending:         int    = -1
var _avl_correct:         String = ""
var _delete_target:       int    = -1

# Scoring
var _score: int  = 0
var _lives: int  = 3
var _stat := { "correct":0, "wrong":0, "inserts":0, "searches":0, "traversals":0 }
var _alive: bool = false

# Parallax background
var _parallax_layers: Array = []
var _bg_time:         float = 0.0

# Built-in UI nodes
var _pixel_font:  Font       = null
var _instr_rect:  ColorRect  = null
var _instr_task:  Label      = null
var _instr_rule:  Label      = null
var _banner_rect: ColorRect  = null
var _banner_lbl:  Label      = null
var _banner_sub:  Label      = null

# Intro overlay
var _intro_canvas: CanvasLayer = null
var _intro_slides: Array       = []
var _intro_idx:    int         = 0

# =============================================================================
#  READY
# =============================================================================
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font
	_tier = 0
	if has_node("/root/DifficultyManager"):
		_tier = clamp(DifficultyManager.current_tier, 0, TIER_CONFIG.size() - 1)
	_cfg = TIER_CONFIG[_tier]

	_trav_banner.visible     = false
	_complete_banner.visible = false
	_fail_summary.visible    = false
	_hint_box.visible        = false

	_setup_hud()
	_setup_instr_bar()
	_setup_banner()
	_setup_hint_overlay()
	_setup_bg()
	_generate_pool()
	AudioManager.play_bgm(PATH_BGM)
	_alive = true
	_build_intro_slides()
	_show_intro_overlay()

# =============================================================================
#  PARALLAX BACKGROUND
#  12-layer forest parallax — same asset path as the original game.
#  Each layer scrolls horizontally at a different speed via sine wave.
#  If an asset file is missing (e.g. in editor without assets) it is skipped
#  silently so the game still runs.
# =============================================================================
func _setup_bg() -> void:
	# Hide the placeholder Sprite2D from the .tscn (it has no texture anyway)
	var bg_node := get_node_or_null("Background") as Sprite2D
	if bg_node: bg_node.visible = false

	# Layers 0011 (solid sky) and 0010 (sky gradient) are SKIPPED intentionally.
	# They fill the screen with an opaque sky color that hides the game tree.
	# Only forest/tree layers are loaded so the background stays dark top-to-bottom.
	var layers := [
		{"file":"Layer_0009_2.png",      "scroll":3.0,  "z":-28},
		{"file":"Layer_0008_3.png",      "scroll":5.0,  "z":-27},
		{"file":"Layer_0007_Lights.png", "scroll":5.0,  "z":-26},
		{"file":"Layer_0006_4.png",      "scroll":8.0,  "z":-25},
		{"file":"Layer_0005_5.png",      "scroll":11.0, "z":-24},
		{"file":"Layer_0004_Lights.png", "scroll":11.0, "z":-23},
		{"file":"Layer_0003_6.png",      "scroll":15.0, "z":-22},
		{"file":"Layer_0002_7.png",      "scroll":18.0, "z":-21},
		{"file":"Layer_0001_8.png",      "scroll":20.0, "z":-20},
		{"file":"Layer_0000_9.png",      "scroll":20.0, "z":-19},
	]
	# Dark background fill — prevents any sky-color bleed between forest layers
	var dark_bg := ColorRect.new()
	dark_bg.color    = Color(0.04, 0.05, 0.08, 1.0)  # very dark blue-black
	dark_bg.size     = Vector2(1280, 720)
	dark_bg.position = Vector2.ZERO
	dark_bg.z_index  = -35
	add_child(dark_bg)

	var base := "res://assets/art/tree/bg/parallax/"
	for layer in layers:
		var path: String = base + (layer["file"] as String)
		if not ResourceLoader.exists(path): continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null: continue
		var sp := Sprite2D.new()
		sp.texture        = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index        = layer["z"] as int
		# Scale to fill entire 1280×720 viewport
		var sx := 1280.0 / tex.get_width()
		var sy := 720.0  / tex.get_height()
		sp.scale    = Vector2(sx, sy)
		# Sprite origin is the texture centre — position at screen centre
		sp.position = Vector2(640.0, 360.0)
		sp.set_meta("scroll_amount", layer["scroll"] as float)
		add_child(sp)
		_parallax_layers.append(sp)

# =============================================================================
#  PROCESS — drives parallax scroll and combo decay
# =============================================================================
func _process(delta: float) -> void:
	if not _alive: return
	_bg_time += delta
	for sp in _parallax_layers:
		if not is_instance_valid(sp): continue
		var amount: float = sp.get_meta("scroll_amount") as float
		sp.position.x = 640.0 + sin(_bg_time * 0.18) * amount

# =============================================================================
#  POOL
# =============================================================================
func _generate_pool() -> void:
	var count: int = _cfg["insert_count"]
	var vals: Array[int] = []
	while vals.size() < count:
		var v := randi() % 89 + 10
		if v not in vals: vals.append(v)
	vals.shuffle()
	for v in vals: _pool.append(v)

# =============================================================================
#  INTRO SLIDES  (tier-specific, 4 slides each)
# =============================================================================
func _build_intro_slides() -> void:
	match _tier:
		0: _slides_tier0()
		1: _slides_tier1()
		2: _slides_tier2()
		3: _slides_tier3()
		4: _slides_tier4()

func _slides_tier0() -> void:
	_intro_slides = [
		{ "title":"What is a Binary Search Tree?",
		  "body":"A BST stores values in a structured tree.\nEach node has at most two children.\nNodes = rune stones   |   Edges = branches",
		  "draw":_draw_s0_what_is_bst },
		{ "title":"Anatomy of a Tree",
		  "body":"Root = topmost node (no parent).\nLeaf = node with no children.\nHeight = longest path root → leaf.",
		  "draw":_draw_s0_anatomy },
		{ "title":"The BST Rule",
		  "body":"Every value SMALLER than a node goes LEFT.\nEvery value LARGER goes RIGHT.\nThis rule applies at every single node.",
		  "draw":_draw_s0_rule },
		{ "title":"Level 1 — Build the Tree",
		  "body":"Drag each rune from the tray at the bottom\nto its correct slot in the tree.\nGreen = valid slot   |   Red = invalid",
		  "draw":_draw_s0_build },
	]

func _slides_tier1() -> void:
	_intro_slides = [
		{ "title":"Binary Search Algorithm",
		  "body":"To find a value in a BST, start at the root.\nCompare: go LEFT if smaller, RIGHT if larger.\nRepeat until found or hit a dead end.",
		  "draw":_draw_s1_intro },
		{ "title":"O(log n) Time Complexity",
		  "body":"Each comparison halves the remaining tree.\nBalanced tree of 7 nodes: worst case = 3 steps.\nDegenerate tree of 7 nodes: worst case = 7 steps.",
		  "draw":_draw_s1_complexity },
		{ "title":"Tracing the Search Path",
		  "body":"At each node: compare target with node value.\n< node → go LEFT     > node → go RIGHT\n= node → FOUND!",
		  "draw":_draw_s1_trace },
		{ "title":"Level 2 — Search the Tree",
		  "body":"The tree is already built from Level 1.\nTap each node you would visit on the path\nfrom the root to the target value.",
		  "draw":_draw_s1_gameplay },
	]

func _slides_tier2() -> void:
	_intro_slides = [
		{ "title":"Tree Traversal",
		  "body":"Traversal = visiting every node in a specific order.\nUnlike search (stops when found),\ntraversal visits ALL nodes exactly once.",
		  "draw":_draw_s2_intro },
		{ "title":"Inorder: Left → Root → Right",
		  "body":"Visit the left subtree first,\nthen the current node,\nthen the right subtree — applied recursively.",
		  "draw":_draw_s2_rule },
		{ "title":"Inorder = Always Sorted Output",
		  "body":"In any BST, inorder traversal always produces\nvalues in ascending (sorted) order.\nThis is the most useful property of the BST.",
		  "draw":_draw_s2_sorted },
		{ "title":"Level 3 — Tap the Inorder Path",
		  "body":"After building and searching the tree,\ntap every node in inorder sequence.\nLeft subtree → Root → Right subtree.",
		  "draw":_draw_s2_gameplay },
	]

func _slides_tier3() -> void:
	_intro_slides = [
		{ "title":"Preorder: Root → Left → Right",
		  "body":"Visit the node FIRST, then traverse left, then right.\nUse: copying or serialising a tree —\nparent must be known before its children.",
		  "draw":_draw_s3_preorder },
		{ "title":"Postorder: Left → Right → Root",
		  "body":"Traverse left, then right, then visit node LAST.\nUse: safely deleting a tree —\nchildren must be freed before the parent.",
		  "draw":_draw_s3_postorder },
		{ "title":"Deleting a Node from a BST",
		  "body":"Case 1 — Leaf: simply remove it.\nCase 2 — One child: replace node with its child.\nCase 3 — Two children: swap with inorder successor.",
		  "draw":_draw_s3_delete },
		{ "title":"What is the Inorder Successor?",
		  "body":"The inorder successor of node N is the\nSMALLEST value in N's RIGHT subtree.\nFind it: go right once, then left as far as possible.",
		  "draw":_draw_s3_successor },
	]

func _slides_tier4() -> void:
	_intro_slides = [
		{ "title":"Why Trees Become Unbalanced",
		  "body":"Inserting sorted values (10, 20, 30…)\nmakes the BST degenerate into a linked list.\nSearch becomes O(n) instead of O(log n).",
		  "draw":_draw_s4_degenerate },
		{ "title":"AVL Balance Factor",
		  "body":"Balance Factor = height(left) − height(right).\nAVL trees keep this at −1, 0, or +1 everywhere.\nIf |BF| > 1 after an insert → rotate to fix it.",
		  "draw":_draw_s4_bf },
		{ "title":"Four Rotation Cases",
		  "body":"LL — inserted LEFT-LEFT   → Right rotate\nRR — inserted RIGHT-RIGHT → Left rotate\nLR — LEFT then RIGHT       → Left-Right double rotate\nRL — RIGHT then LEFT       → Right-Left double rotate",
		  "draw":_draw_s4_rotations },
		{ "title":"Level 4 — Detect & Fix Imbalance",
		  "body":"A node is inserted automatically.\nWhen the tree becomes unbalanced,\nchoose the correct rotation type to restore balance.",
		  "draw":_draw_s4_gameplay },
	]

# =============================================================================
#  WOOD THEME HELPERS
#  Returns StyleBoxFlat objects that simulate carved wood planks.
#  Used by intro, banner, instr bar, hint card, and all buttons.
# =============================================================================
func _wood_panel(radius: int = 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = WOOD_MID
	s.border_color        = WOOD_BORDER
	s.border_width_left   = 3; s.border_width_right  = 3
	s.border_width_top    = 3; s.border_width_bottom  = 3
	s.corner_radius_top_left     = radius; s.corner_radius_top_right    = radius
	s.corner_radius_bottom_left  = radius; s.corner_radius_bottom_right = radius
	s.shadow_color  = Color(0, 0, 0, 0.55)
	s.shadow_size   = 6
	s.shadow_offset = Vector2(2, 3)
	return s

func _wood_btn_normal() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color            = WOOD_LIGHT
	s.border_color        = WOOD_GOLD
	s.border_width_left   = 2; s.border_width_right  = 2
	s.border_width_top    = 2; s.border_width_bottom  = 4  # thicker bottom = carved ledge
	s.corner_radius_top_left     = 5; s.corner_radius_top_right    = 5
	s.corner_radius_bottom_left  = 5; s.corner_radius_bottom_right = 5
	s.shadow_color  = Color(0, 0, 0, 0.45)
	s.shadow_size   = 4
	s.shadow_offset = Vector2(1, 2)
	return s

func _wood_btn_hover() -> StyleBoxFlat:
	var s := _wood_btn_normal()
	s.bg_color     = WOOD_GRAIN
	s.border_color = Color(1.0, 0.92, 0.4, 1.0)
	return s

func _wood_btn_pressed() -> StyleBoxFlat:
	var s := _wood_btn_normal()
	s.bg_color            = WOOD_DARK
	s.border_color        = WOOD_GOLD
	s.border_width_bottom = 2   # flatten bottom when pressed
	s.shadow_size         = 0
	s.shadow_offset       = Vector2.ZERO
	return s

func _style_wood_btn(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal",   _wood_btn_normal())
	btn.add_theme_stylebox_override("hover",    _wood_btn_hover())
	btn.add_theme_stylebox_override("pressed",  _wood_btn_pressed())
	btn.add_theme_stylebox_override("focus",    _wood_btn_hover())
	btn.add_theme_color_override("font_color",         WOOD_TEXT)
	btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.95, 0.55))
	btn.add_theme_color_override("font_pressed_color", WOOD_SUBTEXT)

# =============================================================================
#  INTRO OVERLAY
# =============================================================================
func _show_intro_overlay() -> void:
	_master_phase = MasterPhase.INTRO
	_intro_canvas = CanvasLayer.new()
	_intro_canvas.layer = 100
	add_child(_intro_canvas)

	# ── Full-screen dark dimmer ────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color   = Color(0.0, 0.0, 0.0, 0.68)
	bg.size    = Vector2(1280, 720)
	bg.z_index = 0
	_intro_canvas.add_child(bg)

	# ── Tier badge ────────────────────────────────────────────────────────────
	var badge := Label.new()
	badge.name = "Badge"
	badge.add_theme_font_override("font", _pixel_font)
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", WOOD_GOLD)
	badge.text     = "Tier %d — %s" % [_tier, _cfg["name"] as String]
	badge.position = Vector2(60, 26)
	badge.z_index  = 5
	_intro_canvas.add_child(badge)

	# ── Slide counter ─────────────────────────────────────────────────────────
	var ctr := Label.new()
	ctr.name = "Counter"
	ctr.add_theme_font_override("font", _pixel_font)
	ctr.add_theme_font_size_override("font_size", 13)
	ctr.add_theme_color_override("font_color", WOOD_SUBTEXT)
	ctr.position             = Vector2(480, 26)
	ctr.size                 = Vector2(320, 24)
	ctr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ctr.z_index              = 5
	_intro_canvas.add_child(ctr)

	# ── Title ─────────────────────────────────────────────────────────────────
	var ttl := Label.new()
	ttl.name = "Title"
	ttl.add_theme_font_override("font", _pixel_font)
	ttl.add_theme_font_size_override("font_size", 22)
	ttl.add_theme_color_override("font_color", WOOD_GOLD)
	ttl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	ttl.add_theme_constant_override("shadow_offset_x", 2)
	ttl.add_theme_constant_override("shadow_offset_y", 2)
	ttl.position             = Vector2(60, 496)
	ttl.size                 = Vector2(1160, 40)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	ttl.z_index              = 5
	_intro_canvas.add_child(ttl)

	# ── Gold divider ──────────────────────────────────────────────────────────
	var div := ColorRect.new()
	div.color    = WOOD_GOLD
	div.size     = Vector2(880, 2)
	div.position = Vector2(200, 540)
	div.z_index  = 5
	_intro_canvas.add_child(div)

	# ── Body text ─────────────────────────────────────────────────────────────
	var body := Label.new()
	body.name = "Body"
	body.add_theme_font_override("font", _pixel_font)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", WOOD_TEXT)
	body.position             = Vector2(80, 546)
	body.size                 = Vector2(1120, 96)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	body.z_index              = 5
	_intro_canvas.add_child(body)

	# ── Back button ───────────────────────────────────────────────────────────
	var back := Button.new()
	back.name = "Back"
	back.text = "◀  Back"
	back.position = Vector2(60, 656)
	back.size     = Vector2(160, 44)
	back.add_theme_font_override("font", _pixel_font)
	back.add_theme_font_size_override("font_size", 14)
	back.pressed.connect(_intro_prev)
	_style_wood_btn(back)
	back.z_index = 5
	_intro_canvas.add_child(back)

	# ── Next / Start button ───────────────────────────────────────────────────
	var nxt := Button.new()
	nxt.name = "Next"
	nxt.text = "Next  ▶"
	nxt.position = Vector2(1060, 656)
	nxt.size     = Vector2(160, 44)
	nxt.add_theme_font_override("font", _pixel_font)
	nxt.add_theme_font_size_override("font_size", 14)
	nxt.pressed.connect(_intro_next)
	_style_wood_btn(nxt)
	nxt.z_index = 5
	_intro_canvas.add_child(nxt)

	# ── Dot indicators ────────────────────────────────────────────────────────
	for i in range(_intro_slides.size()):
		var dot := ColorRect.new()
		dot.name     = "Dot%d" % i
		dot.size     = Vector2(10, 10)
		dot.position = Vector2(608 + i * 22, 668)
		dot.color    = WOOD_SUBTEXT
		dot.z_index  = 5
		_intro_canvas.add_child(dot)

	_intro_idx = 0
	_refresh_intro()

func _refresh_intro() -> void:
	var slide: Dictionary = _intro_slides[_intro_idx]
	var total := _intro_slides.size()
	(_intro_canvas.get_node("Counter") as Label).text = "%d / %d" % [_intro_idx + 1, total]
	(_intro_canvas.get_node("Title")   as Label).text = slide["title"] as String
	(_intro_canvas.get_node("Body")    as Label).text = slide["body"]  as String
	(_intro_canvas.get_node("Back")    as Button).visible = _intro_idx > 0
	(_intro_canvas.get_node("Next")    as Button).text = \
		"Start Game  ▶" if _intro_idx == total - 1 else "Next  ▶"
	for i in range(total):
		(_intro_canvas.get_node("Dot%d" % i) as ColorRect).color = \
			WOOD_GOLD if i == _intro_idx else WOOD_SUBTEXT
	# Use free() not queue_free() so the old drawer is gone THIS frame
	# before the new one is added — prevents one-frame double-draw bleed.
	var old := _intro_canvas.get_node_or_null("Diagram")
	if old:
		old.name = "DeadDiagram"
		old.free()
	var diag := _DiagramDrawer.new()
	diag.name       = "Diagram"
	diag.draw_fn    = slide["draw"] as Callable
	diag.pixel_font = _pixel_font
	diag.z_index    = 2   # above dimmer (0), below text labels (5)
	_intro_canvas.add_child(diag)

func _intro_next() -> void:
	if _intro_idx < _intro_slides.size() - 1:
		_intro_idx += 1; _refresh_intro()
	else:
		_close_intro()

func _intro_prev() -> void:
	if _intro_idx > 0:
		_intro_idx -= 1; _refresh_intro()

func _close_intro() -> void:
	var bg := _intro_canvas.get_child(0) as ColorRect
	_intro_canvas.create_tween().tween_property(bg, "color:a", 0.0, 0.3)\
		.finished.connect(func():
			_intro_canvas.queue_free(); _intro_canvas = null; _begin_game())

# =============================================================================
#  INNER CLASSES
# =============================================================================
class _DiagramDrawer extends Node2D:
	var draw_fn:    Callable
	var pixel_font: Font

	# Wood palette (duplicated here so the inner class is self-contained)
	const _WOOD_DARK   := Color(0.22, 0.13, 0.06, 0.97)
	const _WOOD_MID    := Color(0.34, 0.20, 0.08, 0.97)
	const _WOOD_BORDER := Color(0.72, 0.48, 0.18, 1.00)
	const _WOOD_GOLD   := Color(0.95, 0.78, 0.25, 1.00)
	const _WOOD_GRAIN  := Color(0.60, 0.38, 0.14, 0.10)

	func _draw() -> void:
		# ── 1. Full-screen dark base (behind everything) ──────────────────────
		draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.04, 0.10, 1.0), true)

		# ── 2. Solid wood fill
		draw_rect(Rect2(0, 0, 1280, 488), _WOOD_MID, true)

		# ── 3. Wood board BORDER ─────────────────────────────────────────────
		# Left edge plank
		draw_rect(Rect2(0, 0, 32, 488), _WOOD_MID, true)
		for gi in range(12):
			draw_rect(Rect2(4, 20 + gi * 38, 24, 1), _WOOD_GRAIN, true)
		# Right edge plank
		draw_rect(Rect2(1248, 0, 32, 488), _WOOD_MID, true)
		for gi in range(12):
			draw_rect(Rect2(1252, 20 + gi * 38, 24, 1), _WOOD_GRAIN, true)
		# Top plank
		draw_rect(Rect2(0, 0, 1280, 14), _WOOD_MID, true)
		for gi in range(3):
			draw_rect(Rect2(32, 2 + gi * 4, 1216, 1), _WOOD_GRAIN, true)
		# Gold top line
		draw_rect(Rect2(0, 13, 1280, 2), _WOOD_GOLD, true)
		# Border outline
		draw_rect(Rect2(0, 0, 1280, 488), _WOOD_BORDER, false, 2.5)
		# Corner nails
		for cp in [Vector2(16, 14), Vector2(1264, 14), Vector2(16, 474), Vector2(1264, 474)]:
			draw_circle(cp, 5.0, _WOOD_GOLD)
			draw_circle(cp, 2.5, _WOOD_DARK)

		# ── 4. Diagram content (drawn over forest, inside board) ──────────────
		if draw_fn.is_valid(): draw_fn.call(self, pixel_font)

		# ── 5. Footer text panel (dark wood, y=488..648) ──────────────────────
		draw_rect(Rect2(0, 488, 1280, 160), _WOOD_DARK, true)
		for gi in range(7):
			draw_rect(Rect2(16, 498 + gi * 20, 1248, 1), _WOOD_GRAIN, true)
		draw_rect(Rect2(0, 488, 1280, 2), _WOOD_GOLD, true)
		draw_rect(Rect2(0, 488, 1280, 160), _WOOD_BORDER, false, 2.0)

		# ── 6. Button tray (mid wood, y=648..710) ─────────────────────────────
		draw_rect(Rect2(0, 648, 1280, 62), _WOOD_MID, true)
		for gi in range(3):
			draw_rect(Rect2(16, 656 + gi * 14, 1248, 1), _WOOD_GRAIN, true)
		draw_rect(Rect2(0, 648, 1280, 2), _WOOD_GOLD, true)
		draw_rect(Rect2(0, 648, 1280, 62), _WOOD_BORDER, false, 1.5)

	# Forest-themed background drawn behind every slide diagram.
	# Uses only draw_* calls — no external textures.
	static func _draw_forest_bg(ci: CanvasItem) -> void:
		# ── Sky gradient (dark top → midnight blue bottom) ──────────────────
		ci.draw_rect(Rect2(0, 0, 1280, 460), Color(0.04, 0.04, 0.10), true)
		# Subtle horizontal gradient bands to suggest depth
		for i in range(8):
			var a := 0.03 + i * 0.005
			ci.draw_rect(Rect2(0, i * 58, 1280, 60), Color(0.06, 0.08, 0.15, a), true)

		# ── Stars ────────────────────────────────────────────────────────────
		var star_positions: Array[Vector2] = [
			Vector2(60,30), Vector2(140,18), Vector2(220,42), Vector2(320,12),
			Vector2(410,35), Vector2(510,8),  Vector2(580,28), Vector2(700,15),
			Vector2(780,38), Vector2(870,10), Vector2(960,32), Vector2(1050,20),
			Vector2(1130,44),Vector2(1200,14),Vector2(1240,38),Vector2(380,55),
			Vector2(650,50), Vector2(900,55), Vector2(1010,48),Vector2(170,60),
		]
		for sp2 in star_positions:
			ci.draw_circle(sp2, 1.5, Color(1.0, 1.0, 0.9, 0.55))

		# ── Moon (top right) ──────────────────────────────────────────────────
		ci.draw_circle(Vector2(1180, 52), 28.0, Color(0.95, 0.92, 0.78, 0.22))
		ci.draw_circle(Vector2(1172, 48), 24.0, Color(0.04, 0.04, 0.10, 1.0))  # crescent mask
		ci.draw_arc(Vector2(1180, 52), 28.0, -1.2, 1.2, 24, Color(0.95, 0.92, 0.78, 0.45), 1.5)

		# ── Distant fog layer ─────────────────────────────────────────────────
		ci.draw_rect(Rect2(0, 330, 1280, 40), Color(0.18, 0.28, 0.35, 0.18), true)
		ci.draw_rect(Rect2(0, 350, 1280, 30), Color(0.18, 0.28, 0.35, 0.12), true)

		# ── Far background tree silhouettes (3 large) ────────────────────────
		var far_trees: Array[Vector2] = [Vector2(180, 400), Vector2(640, 380), Vector2(1100, 395)]
		for tp in far_trees:
			# Trunk
			ci.draw_rect(Rect2(tp.x - 7, tp.y, 14, 60), Color(0.08, 0.06, 0.04), true)
			# Canopy layers (triangle-ish using circles stacked)
			for layer in range(4):
				var r := 55.0 - layer * 10.0
				var cy2 := tp.y - layer * 28.0
				ci.draw_circle(Vector2(tp.x, cy2), r, Color(0.04, 0.10, 0.06, 0.75 + layer * 0.05))

		# ── Mid-ground tree silhouettes (5 medium) ───────────────────────────
		var mid_trees: Array[Vector2] = [
			Vector2(60, 430), Vector2(290, 422), Vector2(520, 418),
			Vector2(760, 425), Vector2(990, 420), Vector2(1220, 428),
		]
		for tp in mid_trees:
			ci.draw_rect(Rect2(tp.x - 5, tp.y, 10, 40), Color(0.06, 0.05, 0.03), true)
			for layer in range(3):
				var r := 38.0 - layer * 9.0
				var cy2 := tp.y - layer * 22.0
				ci.draw_circle(Vector2(tp.x, cy2), r, Color(0.05, 0.13, 0.07, 0.80 + layer * 0.06))

		# ── Ground strip ──────────────────────────────────────────────────────
		ci.draw_rect(Rect2(0, 438, 1280, 22), Color(0.05, 0.10, 0.05), true)
		# Ground highlight edge
		ci.draw_line(Vector2(0, 438), Vector2(1280, 438), Color(0.15, 0.30, 0.12, 0.5), 1.5)

		# ── Foreground grass tufts ────────────────────────────────────────────
		var tuft_xs: Array[float] = [40,110,210,330,450,570,680,800,910,1020,1130,1230]
		for tx in tuft_xs:
			for blade in range(5):
				var bx := tx + blade * 7.0 - 14.0
				ci.draw_line(
					Vector2(bx, 458),
					Vector2(bx + randf_range(-3, 3), 442 + randf_range(0, 6)),
					Color(0.12, 0.35, 0.10, 0.65), 1.5
				)

		# ── Fireflies (small glowing dots) ────────────────────────────────────
		var ff: Array[Vector2] = [
			Vector2(120, 380), Vector2(350, 370), Vector2(490, 390),
			Vector2(720, 365), Vector2(860, 382), Vector2(1050, 375),
		]
		for fpos in ff:
			ci.draw_circle(fpos, 3.0, Color(0.8, 1.0, 0.4, 0.18))
			ci.draw_circle(fpos, 1.5, Color(0.9, 1.0, 0.6, 0.55))

# _CircleSprite kept as fallback when tile asset is missing
class _CircleSprite extends Node2D:
	var radius: float = 24.0
	var color:  Color = Color(0.65, 0.82, 0.55)
	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, color)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32,
			Color(color.r * 0.55, color.g * 0.55, color.b * 0.55), 2.5)

# _CentredLabel: draws a number string exactly centred on (0,0) using draw_string.
# This works correctly regardless of the parent sprite's scale.
class _CentredLabel extends Node2D:
	var display_value: String = ""
	var pixel_font:    Font   = null
	func _draw() -> void:
		if pixel_font == null or display_value.is_empty(): return
		var sz   := 15
		var ts   := pixel_font.get_string_size(display_value, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
		var base := pixel_font.get_ascent(sz)
		# draw shadow first
		draw_string(pixel_font,
			Vector2(-ts.x * 0.5 + 1, base * 0.5 + 1),
			display_value, HORIZONTAL_ALIGNMENT_LEFT, -1, sz,
			Color(0.0, 0.0, 0.0, 0.85))
		# draw main text
		draw_string(pixel_font,
			Vector2(-ts.x * 0.5, base * 0.5),
			display_value, HORIZONTAL_ALIGNMENT_LEFT, -1, sz,
			Color(0.95, 0.95, 0.7))

# =============================================================================
#  GAME FLOW
# =============================================================================
func _begin_game() -> void:
	_master_phase = MasterPhase.PLAYING
	_phase_queue  = (_cfg["phases"] as Array).duplicate()
	_advance_phase()

func _advance_phase() -> void:
	if _phase_queue.is_empty(): _play_completion(); return
	_current_phase_name = _phase_queue.pop_front() as String
	match _current_phase_name:
		"insert":    _start_insert()
		"search":    _start_search()
		"inorder":   _start_traversal(RoundType.INORDER)
		"preorder":  _start_traversal(RoundType.PREORDER)
		"postorder": _start_traversal(RoundType.POSTORDER)
		"delete":    _start_delete()
		"avl":       _start_avl()

# =============================================================================
#  PHASE: INSERT
# =============================================================================
func _start_insert() -> void:
	_round_type = RoundType.INSERT
	_rebuild_pool_sprites()
	_refresh_ghosts()
	_goal_lbl.text = "Runes left: %d" % _pool.size()
	_update_instr("Build the Tree — drag each rune to its correct slot.", "")
	# Hints only appear after first mistake — see _show_hint_overlay()
	_hint_box.visible = false
	# banner removed

func _on_insert_done() -> void:
	_flash_inorder_seq()
	await get_tree().create_timer(2.2).timeout
	_trav_banner.visible = false
	for c in _pool_tray.get_children(): c.queue_free()
	_hide_all_ghosts()
	_advance_phase()

func _flash_inorder_seq() -> void:
	# Collect inorder (= sorted least→greatest) sequence
	var order: Array = []
	_collect_inorder(_root, order)
	# Glow each node sequentially: brighten then settle to a soft teal
	for i in range(order.size()):
		var nd := _bst[order[i]]["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var tw := nd.create_tween()
		tw.tween_interval(i * 0.22)                           # stagger by 220ms
		tw.tween_property(nd, "modulate", Color(1.2,1.2,1.2), 0.08)  # flash white
		tw.tween_property(nd, "modulate", COL_INORDER, 0.18)  # settle to teal
	# Show sorted ticker after all nodes have glowed
	var vals: Array = []
	_collect_inorder_vals(_root, vals)
	var strs: PackedStringArray = []
	for v in vals: strs.append(str(v as int))
	var total_delay := order.size() * 0.22 + 0.3
	await get_tree().create_timer(total_delay).timeout
	_trav_banner.text    = "Sorted: " + " → ".join(strs)
	_trav_banner.visible = true
	AudioManager.play_sfx(PATH_SFX_WIN)

# =============================================================================
#  SILENT TREE BUILD (used when search/traversal phase starts with empty tree)
# =============================================================================
func _silent_build_tree() -> void:
	# Generate a balanced-ish set of values and insert them without animation
	var vals: Array[int] = [50, 25, 75, 12, 37, 62, 87]
	for v in vals:
		_silent_insert(v)
	_pool.clear()   # pool is irrelevant now
	for c in _pool_tray.get_children(): c.queue_free()
	_hide_all_ghosts()

func _silent_insert(value: int) -> void:
	if _bst.size() >= 15: return   # safety cap
	var slot := _find_insert_slot(value)
	var sp   := _make_number_sprite(value)
	_tree_layer.add_child(sp)
	sp.global_position = slot["pos"]
	var ni := _bst.size()
	_bst.append({"value":value,"sprite":sp,"left":-1,"right":-1,
		"parent":slot["parent_idx"],"pos":slot["pos"],"depth":_slot_depth(slot),"height":1})
	if slot["side"] == "root": _root = ni
	elif slot["parent_idx"] >= 0:
		if slot["side"] == "left":  _bst[slot["parent_idx"]]["left"]  = ni
		if slot["side"] == "right": _bst[slot["parent_idx"]]["right"] = ni
	_invalidate_heights_upward(ni)
	if slot["parent_idx"] >= 0:
		_animate_branch(_bst[slot["parent_idx"]]["pos"], slot["pos"])

# =============================================================================
#  PHASE: SEARCH
# =============================================================================
func _start_search() -> void:
	_round_type = RoundType.SEARCH; _rounds_done = 0
	_trav_banner.visible = false
	# If the tree is empty (Tier 1 starts here), auto-build it silently
	if _bst.is_empty(): _silent_build_tree()
	_restore_node_colors()
	_hint_lbl.text = "Compare target with each node. Left if smaller, right if larger."
	_hint_box.visible = _cfg["hints"] as bool
	_show_banner("Level 2 — Binary Search", "Tap nodes along the path to the target.", COL_SEARCH_HI)
	await get_tree().create_timer(2.0).timeout
	_begin_search_round()

func _begin_search_round() -> void:
	if _rounds_done >= (_cfg["search_rounds"] as int): _advance_phase(); return
	_restore_node_colors()
	var live := _live_indices()
	var deep := live.filter(func(i): return (_bst[i]["depth"] as int) >= 1)
	if deep.is_empty(): deep = live
	var ti: int     = deep[randi() % deep.size()]
	_target_val     = _bst[ti]["value"] as int
	_tap_path       = _build_search_path(_target_val)
	_tap_idx        = 0; _round_mistakes = 0
	_goal_lbl.text  = "Search %d/%d  |  Find: %d" % [
		_rounds_done + 1, _cfg["search_rounds"] as int, _target_val]
	_update_instr("Search for  %d  — tap each node you visit." % _target_val,
		"Start at root. Left if smaller, right if larger.")
	_pulse_node(_bst[_root]["sprite"] as Node2D, COL_SEARCH_HI)

func _handle_search_tap(pos: Vector2) -> void:
	for i in _live_indices():
		var nd := _bst[i]["sprite"] as Node2D
		if nd.global_position.distance_to(pos) > NODE_HIT: continue
		if i == _tap_path[_tap_idx]:
			_flash(nd, COL_OK)
			var val: int = _bst[i]["value"] as int
			var dir := "FOUND!" if val == _target_val else ("→ LEFT" if _target_val < val else "→ RIGHT")
			_float_node(nd, "%d %s" % [val, dir], COL_OK)
			if _target_val < val: _grey_subtree(_bst[i]["right"] as int)
			elif _target_val > val: _grey_subtree(_bst[i]["left"] as int)
			_tap_idx += 1; _stat["correct"] += 1
			AudioManager.play_sfx(PATH_SFX_OK)
			if _tap_idx >= _tap_path.size():
				_score += maxi(80 - _round_mistakes * 20, 10); _score_lbl.text = "Score: %d" % _score
				_stat["searches"] += 1; _rounds_done += 1
				await get_tree().create_timer(1.2).timeout; _begin_search_round()
			else:
				_pulse_node(_bst[_tap_path[_tap_idx]]["sprite"] as Node2D, COL_SEARCH_HI)
		else:
			_flash(nd, COL_WRONG); _shake(nd); _round_mistakes += 1; _stat["wrong"] += 1
			_lives -= 1; _refresh_lives(); AudioManager.play_sfx(PATH_SFX_FAIL)
			if _cfg["hints"] as bool:
				var cur_val: int = _bst[_tap_path[_tap_idx]]["value"] as int
				var dir := "LEFT" if _target_val < cur_val else "RIGHT"
				_show_hint_overlay(
					"Compare  %d  with  %d\n%d %s %d  →  go  %s" % [
						_target_val, cur_val,
						_target_val, "<" if _target_val < cur_val else ">", cur_val,
						dir])
			if _lives <= 0: _end_game(false)
		return

# =============================================================================
#  PHASE: TRAVERSAL  (Inorder / Preorder / Postorder)
# =============================================================================
func _start_traversal(rt: RoundType) -> void:
	_round_type = rt; _rounds_done = 0
	_restore_node_colors(); _trav_banner.visible = false
	var nm: String; var col: Color; var rule: String
	match rt:
		RoundType.INORDER:   nm="Inorder";   col=COL_INORDER;   rule="Left → Root → Right"
		RoundType.PREORDER:  nm="Preorder";  col=COL_PREORDER;  rule="Root → Left → Right"
		RoundType.POSTORDER: nm="Postorder"; col=COL_POSTORDER; rule="Left → Right → Root"
		_:                   nm="Traversal"; col=COL_WHITE;     rule=""
	_update_instr("%s Traversal — tap nodes in the correct order." % nm, rule)
	if _cfg["hints"] as bool:
		_hint_lbl.text = "Tap every node in %s order.\n%s" % [nm, rule]; _hint_box.visible = true
	_show_banner("Level — %s Traversal" % nm, "Tap all nodes in the correct order.", col)
	await get_tree().create_timer(2.0).timeout
	_begin_trav_round(rt)

func _begin_trav_round(rt: RoundType) -> void:
	if _rounds_done >= (_cfg["trav_rounds"] as int): _advance_phase(); return
	_restore_node_colors(); _trav_sequence = []; _trav_hi = 0; _round_mistakes = 0
	match rt:
		RoundType.INORDER:   _collect_inorder(_root, _trav_sequence)
		RoundType.PREORDER:  _collect_preorder(_root, _trav_sequence)
		RoundType.POSTORDER: _collect_postorder(_root, _trav_sequence)
	_goal_lbl.text = "Round %d/%d  |  Tap %d nodes" % [
		_rounds_done + 1, _cfg["trav_rounds"] as int, _trav_sequence.size()]
	for i in _live_indices(): (_bst[i]["sprite"] as Node2D).modulate = Color(0.45, 0.45, 0.45)
	_pulse_node(_bst[_trav_sequence[0]]["sprite"] as Node2D, _trav_col(rt))

func _handle_trav_tap(pos: Vector2, rt: RoundType) -> void:
	var col := _trav_col(rt)
	for i in _live_indices():
		var nd := _bst[i]["sprite"] as Node2D
		if nd.global_position.distance_to(pos) > NODE_HIT: continue
		if i == _trav_sequence[_trav_hi]:
			_flash(nd, col); nd.modulate = col
			_float_node(nd, "+%d" % (10 + _trav_hi * 2), col)
			_trav_hi += 1; _stat["correct"] += 1; AudioManager.play_sfx(PATH_SFX_OK)
			if _trav_hi >= _trav_sequence.size():
				_score += maxi(120 - _round_mistakes * 15, 20); _score_lbl.text = "Score: %d" % _score
				_stat["traversals"] += 1; _rounds_done += 1; AudioManager.play_sfx(PATH_SFX_WIN)
				await get_tree().create_timer(1.0).timeout; _begin_trav_round(rt)
			else:
				_pulse_node(_bst[_trav_sequence[_trav_hi]]["sprite"] as Node2D, col)
		else:
			_flash(nd, COL_WRONG); _shake(nd); _round_mistakes += 1; _stat["wrong"] += 1
			_lives -= 1; _refresh_lives(); AudioManager.play_sfx(PATH_SFX_FAIL)
			if _cfg["hints"] as bool:
				var exp_val: int = _bst[_trav_sequence[_trav_hi]]["value"] as int
				match _round_type:
					RoundType.INORDER:   _show_hint_overlay("Inorder: Left → Root → Right\nNext node to tap: %d" % exp_val)
					RoundType.PREORDER:  _show_hint_overlay("Preorder: Root → Left → Right\nNext node to tap: %d" % exp_val)
					RoundType.POSTORDER: _show_hint_overlay("Postorder: Left → Right → Root\nNext node to tap: %d" % exp_val)
			if _lives <= 0: _end_game(false)
		return

func _trav_col(rt: RoundType) -> Color:
	match rt:
		RoundType.INORDER:   return COL_INORDER
		RoundType.PREORDER:  return COL_PREORDER
		RoundType.POSTORDER: return COL_POSTORDER
		_:                   return COL_WHITE

# =============================================================================
#  PHASE: DELETE
# =============================================================================
func _start_delete() -> void:
	_round_type = RoundType.DELETE; _rounds_done = 0; _restore_node_colors()
	_update_instr("Delete a Node — tap the highlighted node.",
		"Leaf=remove | 1 child=lift up | 2 children=swap successor")
	_hint_lbl.text = "Tap the RED node. Tree restructures to stay valid."; _hint_box.visible = true
	_show_banner("Level — Delete a Node", "Remove nodes while keeping the BST valid.", COL_DEL)
	await get_tree().create_timer(2.0).timeout; _begin_delete_round()

func _begin_delete_round() -> void:
	if _rounds_done >= (_cfg["delete_rounds"] as int): _advance_phase(); return
	_restore_node_colors()
	var live := _live_indices()
	if live.size() < 2: _advance_phase(); return
	var cands := live.filter(func(i): return i != _root)
	if cands.is_empty(): cands = live
	var di: int = cands[randi() % cands.size()]
	_delete_target = di
	(_bst[di]["sprite"] as Node2D).modulate = COL_DEL
	_goal_lbl.text = "Delete node: %d" % (_bst[di]["value"] as int)
	_update_instr("Tap the RED node (%d) to delete it." % (_bst[di]["value"] as int),
		"Tree restructures automatically.")

func _handle_delete_tap(pos: Vector2) -> void:
	if _delete_target < 0: return
	var nd := _bst[_delete_target]["sprite"] as Node2D
	if not is_instance_valid(nd) or nd.global_position.distance_to(pos) > NODE_HIT: return
	var val: int = _bst[_delete_target]["value"] as int
	var nd_pos := nd.global_position
	_perform_delete(_delete_target)
	_delete_target = -1; _rounds_done += 1
	_score += 60; _score_lbl.text = "Score: %d" % _score
	_float_world(nd_pos, "Deleted %d" % val, COL_DEL)
	AudioManager.play_sfx(PATH_SFX_WIN)
	await get_tree().create_timer(1.2).timeout; _begin_delete_round()

func _perform_delete(idx: int) -> void:
	var lc: int = _bst[idx]["left"]  as int
	var rc: int = _bst[idx]["right"] as int
	var sp := _bst[idx]["sprite"] as Node2D
	if lc < 0 and rc < 0:
		_detach_node(idx)
		if is_instance_valid(sp): sp.create_tween().tween_property(sp,"modulate:a",0.0,0.3).finished.connect(sp.queue_free)
		return
	if lc < 0 or rc < 0:
		_replace_node(idx, rc if lc < 0 else lc)
		if is_instance_valid(sp): sp.create_tween().tween_property(sp,"modulate:a",0.0,0.3).finished.connect(sp.queue_free)
		return
	# Two children — find inorder successor
	var succ := rc
	while (_bst[succ]["left"] as int) >= 0: succ = _bst[succ]["left"] as int
	_bst[idx]["value"] = _bst[succ]["value"]
	for child in (_bst[idx]["sprite"] as Node2D).get_children():
		if child is Label: (child as Label).text = str(_bst[idx]["value"] as int)
	_perform_delete(succ)

func _detach_node(idx: int) -> void:
	var par: int = _bst[idx]["parent"] as int
	if par < 0: _root = -1
	elif (_bst[par]["left"] as int) == idx: _bst[par]["left"]  = -1
	else:                                    _bst[par]["right"] = -1
	_bst[idx]["sprite"] = null

func _replace_node(idx: int, child_idx: int) -> void:
	var par: int = _bst[idx]["parent"] as int
	_bst[child_idx]["parent"] = par
	if par < 0: _root = child_idx
	elif (_bst[par]["left"] as int) == idx: _bst[par]["left"]  = child_idx
	else:                                    _bst[par]["right"] = child_idx
	_bst[idx]["sprite"] = null

# =============================================================================
#  PHASE: AVL BALANCING
# =============================================================================
func _start_avl() -> void:
	_round_type = RoundType.AVL; _rounds_done = 0
	_update_instr("AVL Balancing — after each insert, choose the correct rotation.", "")
	_show_banner("Level — AVL Self-Balancing",
		"Detect imbalance after insert, then choose the correct rotation.", COL_AVL_BAD)
	await get_tree().create_timer(2.0).timeout; _begin_avl_round()

func _begin_avl_round() -> void:
	if _rounds_done >= (_cfg["avl_rounds"] as int): _advance_phase(); return
	var val := _next_avl_val()
	var slot = _find_insert_slot(val)
	var dest: Vector2 = slot["pos"]
	var tile := _make_number_sprite(val)
	_tree_layer.add_child(tile); tile.global_position = Vector2(640, 580)
	await tile.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
		.tween_property(tile,"global_position",dest,0.5).finished

	var ni := _bst.size()
	_bst.append({"value":val,"sprite":tile,"left":-1,"right":-1,
		"parent":slot["parent_idx"],"pos":dest,"depth":_slot_depth(slot),"height":1})
	if slot["side"] == "root": _root = ni
	elif slot["parent_idx"] >= 0:
		if slot["side"] == "left":  _bst[slot["parent_idx"]]["left"]  = ni
		if slot["side"] == "right": _bst[slot["parent_idx"]]["right"] = ni
	_invalidate_heights_upward(ni)
	if slot["parent_idx"] >= 0: _animate_branch(_bst[slot["parent_idx"]]["pos"], dest)
	AudioManager.play_sfx(PATH_SFX_OK)

	var imbal := _find_imbalanced()
	if imbal < 0:
		_rounds_done += 1; await get_tree().create_timer(0.5).timeout; _begin_avl_round(); return

	_avl_pending = imbal
	_avl_correct = _determine_rotation(imbal, ni)
	(_bst[imbal]["sprite"] as Node2D).modulate = COL_AVL_BAD
	_float_node(_bst[imbal]["sprite"] as Node2D, "BF=%d" % _bf(imbal), COL_AVL_BAD)
	_goal_lbl.text = "Inserted %d — tree is unbalanced!" % val
	_update_instr("Which rotation fixes this imbalance?", "")
	_show_avl_buttons()

func _next_avl_val() -> int:
	var used: Array = []
	for nd in _bst:
		if is_instance_valid(nd["sprite"] as Node2D): used.append(nd["value"] as int)
	var v := randi() % 89 + 10; var tries := 0
	while (v in used) and tries < 40: v = randi() % 89 + 10; tries += 1
	return v

func _find_imbalanced() -> int:
	for i in range(_bst.size()):
		if not is_instance_valid(_bst[i]["sprite"] as Node2D): continue
		if abs(_bf(i)) > 1: return i
	return -1

func _bf(idx: int) -> int:
	if idx < 0 or idx >= _bst.size(): return 0
	return _cached_height(_bst[idx]["left"] as int) - _cached_height(_bst[idx]["right"] as int)

func _determine_rotation(imbal_idx: int, new_idx: int) -> String:
	var bf: int = _bf(imbal_idx)
	if bf > 1:
		var lc: int = _bst[imbal_idx]["left"] as int
		return "LL (Right Rotate)" if (lc >= 0 and _in_subtree(lc, new_idx)) \
			else "LR (Left-Right Rotate)"
	else:
		var rc: int = _bst[imbal_idx]["right"] as int
		return "RR (Left Rotate)" if (rc >= 0 and _in_subtree(rc, new_idx)) \
			else "RL (Right-Left Rotate)"

func _in_subtree(ancestor: int, target: int) -> bool:
	var cur := target
	while cur >= 0 and cur < _bst.size():
		if cur == ancestor: return true
		cur = _bst[cur]["parent"] as int
	return false

func _show_avl_buttons() -> void:
	var ov := CanvasLayer.new(); ov.name = "AVLOv"; ov.layer = 50; add_child(ov)
	var labels: Array[String] = ["LL (Right Rotate)","RR (Left Rotate)",
		"LR (Left-Right Rotate)","RL (Right-Left Rotate)"]
	var pos := [Vector2(200,320),Vector2(680,320),Vector2(200,420),Vector2(680,420)]
	for i in range(4):
		var btn := Button.new()
		btn.text = labels[i]; btn.position = pos[i]; btn.size = Vector2(380,65)
		btn.add_theme_font_override("font", _pixel_font)
		btn.add_theme_font_size_override("font_size", 16)
		var lbl := labels[i]
		btn.pressed.connect(func(): _on_avl_choice(lbl, ov))
		ov.add_child(btn)

func _on_avl_choice(chosen: String, ov: CanvasLayer) -> void:
	ov.queue_free()
	if chosen == _avl_correct:
		_score += 100; _score_lbl.text = "Score: %d" % _score
		_float_world(Vector2(640,280), "✓ Correct! %s" % chosen, COL_OK)
		if _avl_pending >= 0 and is_instance_valid(_bst[_avl_pending]["sprite"] as Node2D):
			_bounce(_bst[_avl_pending]["sprite"] as Node2D)
			(_bst[_avl_pending]["sprite"] as Node2D).modulate = COL_AVL_OK
		_stat["correct"] += 1; AudioManager.play_sfx(PATH_SFX_WIN)
	else:
		_lives -= 1; _refresh_lives(); _stat["wrong"] += 1
		_float_world(Vector2(640,280), "✗ Correct: %s" % _avl_correct, COL_WRONG)
		AudioManager.play_sfx(PATH_SFX_FAIL)
		if _lives <= 0: _end_game(false); return
	_rounds_done += 1
	await get_tree().create_timer(1.5).timeout
	_restore_node_colors(); _begin_avl_round()

# =============================================================================
#  INPUT
# =============================================================================
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var _mbe := event as InputEventMouseButton
		if _mbe.button_index == MOUSE_BUTTON_LEFT and _mbe.pressed:
			if Rect2(1224, 4, 44, 28).has_point(_mbe.position):
				var _pm := get_node_or_null("PauseMenu")
				if _pm and _pm.has_method("toggle"): _pm.toggle()
				return
	if not _alive or _master_phase != MasterPhase.PLAYING: return
	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index != MOUSE_BUTTON_LEFT: return
		if e.pressed:
			match _round_type:
				RoundType.INSERT:    if not _is_dragging: _try_pickup(e.position)
				RoundType.SEARCH:    _handle_search_tap(e.position)
				RoundType.INORDER:   _handle_trav_tap(e.position, RoundType.INORDER)
				RoundType.PREORDER:  _handle_trav_tap(e.position, RoundType.PREORDER)
				RoundType.POSTORDER: _handle_trav_tap(e.position, RoundType.POSTORDER)
				RoundType.DELETE:    _handle_delete_tap(e.position)
		else:
			if _is_dragging: _try_drop()
	elif event is InputEventMouseMotion:
		if _is_dragging and _drag_pool_idx >= 0:
			_move_drag_sprite(event.position + _drag_offset)

# =============================================================================
#  INSERT MECHANICS
# =============================================================================
func _try_pickup(pos: Vector2) -> void:
	for i in range(_pool.size()):
		if i >= _pool_tray.get_child_count(): break
		var sp := _pool_tray.get_child(i) as Node2D
		if not is_instance_valid(sp) or sp.global_position.distance_to(pos) > NODE_HIT * 2.0: continue
		_is_dragging = true; _drag_pool_idx = i
		_drag_offset = sp.global_position - pos; sp.z_index = 50
		AudioManager.play_sfx(PATH_SFX_PICKUP)
		_show_comparison_trace(_pool[i] as int); _show_all_ghosts_colored(_pool[i] as int)
		return

func _move_drag_sprite(world_pos: Vector2) -> void:
	if _drag_pool_idx < 0 or _drag_pool_idx >= _pool_tray.get_child_count(): return
	var sp := _pool_tray.get_child(_drag_pool_idx) as Node2D
	if not is_instance_valid(sp): return
	sp.global_position = world_pos
	_update_snap_ghost(sp.global_position, _pool[_drag_pool_idx] as int)
	_apply_magnetic_pull(sp)

func _try_drop() -> void:
	_is_dragging = false
	if _drag_pool_idx < 0: return
	var sp  := _pool_tray.get_child(_drag_pool_idx) as Node2D
	var pos := sp.global_position if is_instance_valid(sp) else Vector2.ZERO
	var val := _pool[_drag_pool_idx] as int
	sp.z_index = 10; _clear_trace(); _hide_all_ghosts()
	if pos.y > POOL_Y - 50.0: _return_to_home(); _drag_pool_idx = -1; return

	var slot = _find_snap_slot(pos, val)
	if slot == null: slot = _nearest_valid_slot(pos, val)
	if slot == null:
		if _nearest_any_slot(pos) != null:
			_flash(sp, COL_WRONG); _shake(sp); _lives -= 1; _refresh_lives()
			AudioManager.play_sfx(PATH_SFX_FAIL)
			# Show hint overlay explaining BST rule
			if _cfg["hints"] as bool:
				_show_hint_overlay(
					"BST Rule: place smaller values to the LEFT,\nlarger values to the RIGHT of each node.\n\nGreen slots = valid  |  Red slots = wrong side.")
			if _lives <= 0: _end_game(false)
		_return_to_home(); _drag_pool_idx = -1; return

	var dest: Vector2 = slot["pos"]
	sp.get_parent().remove_child(sp); _tree_layer.add_child(sp); sp.global_position = dest
	if slot["parent_idx"] >= 0: _animate_branch(_bst[slot["parent_idx"]]["pos"], dest)
	var ni := _bst.size()
	_bst.append({"value":val,"sprite":sp,"left":-1,"right":-1,
		"parent":slot["parent_idx"],"pos":dest,"depth":_slot_depth(slot),"height":1})
	if slot["side"] == "root": _root = ni
	elif slot["parent_idx"] >= 0:
		if slot["side"] == "left":  _bst[slot["parent_idx"]]["left"]  = ni
		if slot["side"] == "right": _bst[slot["parent_idx"]]["right"] = ni
	_invalidate_heights_upward(ni)
	_pool.remove_at(_drag_pool_idx); _drag_pool_idx = -1; _snap_ghost_idx = -1
	_flash_ancestry(ni); _bounce(sp); AudioManager.play_sfx(PATH_SFX_OK)
	var pts: int = maxi(100 - (_bst[ni]["depth"] as int) * 22, 20)
	_score += pts; _stat["inserts"] += 1; _score_lbl.text = "Score: %d" % _score
	_float_node(sp, "+%d" % pts, COL_OK)
	_refresh_ghosts(); _goal_lbl.text = "Runes left: %d" % _pool.size()
	if _pool.is_empty():
		await get_tree().create_timer(0.4).timeout; _on_insert_done()

func _return_to_home() -> void:
	if _drag_pool_idx < 0 or _drag_pool_idx >= _pool_tray.get_child_count(): return
	var sp := _pool_tray.get_child(_drag_pool_idx) as Node2D
	if not is_instance_valid(sp): return
	var spacing := 900.0 / (_pool.size() + 1)
	sp.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
		.tween_property(sp, "global_position", Vector2(160.0 + spacing * (_drag_pool_idx + 1), POOL_Y), 0.3)

func _rebuild_pool_sprites() -> void:
	for c in _pool_tray.get_children(): c.queue_free()
	var spacing := 900.0 / (_pool.size() + 1)
	for i in range(_pool.size()):
		var sp := _make_number_sprite(_pool[i] as int)
		_pool_tray.add_child(sp)
		sp.global_position = Vector2(160.0 + spacing * (i + 1), POOL_Y)

func _make_number_sprite(value: int) -> Node2D:
	# The sprite origin (0,0) is the visual centre of the tile/circle.
	# We attach a _CentredLabel child that draws the value string centred on (0,0).
	var sp: Node2D
	var icon_path := NODE_ICON
	if ResourceLoader.exists(icon_path):
		var sprite        := Sprite2D.new()
		sprite.texture     = load(icon_path) as Texture2D
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale       = NODE_SCALE
		sprite.z_index     = 10
		sp = sprite
	else:
		var node := Node2D.new()
		node.z_index = 10
		var circle := _CircleSprite.new()
		circle.z_index = 11
		node.add_child(circle)
		sp = node
	# _CentredLabel draws the value string pixel-perfect centred using font metrics
	var drawer := _CentredLabel.new()
	drawer.display_value = str(value)
	drawer.pixel_font    = _pixel_font
	drawer.z_index       = 12
	sp.add_child(drawer)
	return sp

# =============================================================================
#  GHOST SLOTS
# =============================================================================
func _refresh_ghosts() -> void:
	for c in _ghost_layer.get_children(): c.queue_free(); _ghosts.clear()
	if _bst.is_empty(): _add_ghost(ROOT_POS, -1, "root")
	else: _collect_ghost_slots(_root, ROOT_POS, 0)
	if _cfg["insert_guided"] as bool: _show_all_ghosts_colored(-1)

func _collect_ghost_slots(idx: int, _pos: Vector2, depth: int) -> void:
	if idx < 0 or idx >= _bst.size() or depth >= MAX_DEPTH: return
	var ap: Vector2 = _bst[idx]["pos"]; var spread := SPREAD_MUL / pow(2.0, float(depth))
	var lp := ap + Vector2(-spread, LEVEL_H); var rp := ap + Vector2(spread, LEVEL_H)
	if (_bst[idx]["left"] as int) < 0:
		if lp.x > 40 and lp.x < 1240 and lp.y < POOL_Y - 80: _add_ghost(lp, idx, "left")
	else: _collect_ghost_slots(_bst[idx]["left"] as int, lp, depth + 1)
	if (_bst[idx]["right"] as int) < 0:
		if rp.x > 40 and rp.x < 1240 and rp.y < POOL_Y - 80: _add_ghost(rp, idx, "right")
	else: _collect_ghost_slots(_bst[idx]["right"] as int, rp, depth + 1)

func _add_ghost(pos: Vector2, parent_idx: int, side: String) -> void:
	var panel := Panel.new(); var style := StyleBoxFlat.new()
	style.bg_color = COL_GHOST_OK
	for r in ["corner_radius_top_left","corner_radius_top_right",
			  "corner_radius_bottom_left","corner_radius_bottom_right"]: style.set(r, int(GHOST_R))
	panel.add_theme_stylebox_override("panel", style)
	panel.size = Vector2(GHOST_R*2, GHOST_R*2); panel.position = pos - Vector2(GHOST_R, GHOST_R)
	panel.modulate.a = 0.0; _ghost_layer.add_child(panel)
	var clbl := Label.new()
	clbl.text = _ghost_lbl(parent_idx, side)
	clbl.add_theme_font_override("font", _pixel_font)
	clbl.add_theme_font_size_override("font_size", 11)
	clbl.add_theme_color_override("font_color", Color(0.9, 1.0, 0.7))
	clbl.global_position = pos + Vector2(-20, GHOST_R + 2); clbl.modulate.a = 0.0
	_ghost_layer.add_child(clbl)
	_ghosts.append({"pos":pos,"parent_idx":parent_idx,"side":side,"rect":panel,"clbl":clbl})

func _ghost_lbl(parent_idx: int, side: String) -> String:
	if side == "root": return "root"
	if parent_idx < 0 or parent_idx >= _bst.size(): return ""
	var pv: int = _bst[parent_idx]["value"]
	return "< %d" % pv if side == "left" else "> %d" % pv

func _show_all_ghosts_colored(dragged_val: int) -> void:
	for g in _ghosts:
		var valid := dragged_val < 0 or _bst_rule_ok(g["parent_idx"], g["side"], dragged_val)
		var style := StyleBoxFlat.new()
		style.bg_color = COL_GHOST_OK if valid else COL_GHOST_NO
		for r in ["corner_radius_top_left","corner_radius_top_right",
				  "corner_radius_bottom_left","corner_radius_bottom_right"]: style.set(r, int(GHOST_R))
		(g["rect"] as Panel).add_theme_stylebox_override("panel", style)
		(g["rect"] as Panel).create_tween().tween_property(g["rect"],"modulate:a",1.0,0.15)
		(g["clbl"] as Label).create_tween().tween_property(g["clbl"],"modulate:a",1.0,0.15)

func _hide_all_ghosts() -> void:
	for g in _ghosts:
		(g["rect"] as Panel).create_tween().tween_property(g["rect"],"modulate:a",0.0,0.12)
		(g["clbl"] as Label).create_tween().tween_property(g["clbl"],"modulate:a",0.0,0.12)

func _update_snap_ghost(mouse_pos: Vector2, val: int) -> void:
	var best_d := MAGNET_R; var best_idx := -1
	for i in range(_ghosts.size()):
		var g: Dictionary = _ghosts[i]
		if not _bst_rule_ok(g["parent_idx"], g["side"], val): continue
		var d: float = mouse_pos.distance_to(g["pos"])
		if d < best_d: best_d = d; best_idx = i
	_snap_ghost_idx = best_idx
	for i in range(_ghosts.size()):
		var g: Dictionary = _ghosts[i]
		var is_snap := (i == best_idx)
		var valid   := _bst_rule_ok(g["parent_idx"], g["side"], val)
		var style   := StyleBoxFlat.new()
		style.bg_color = COL_GHOST_SNAP if is_snap else (COL_GHOST_OK if valid else COL_GHOST_NO)
		for r in ["corner_radius_top_left","corner_radius_top_right",
				  "corner_radius_bottom_left","corner_radius_bottom_right"]: style.set(r, int(GHOST_R))
		(g["rect"] as Panel).add_theme_stylebox_override("panel", style)
		(g["rect"] as Panel).scale = Vector2(1.3,1.3) if is_snap else Vector2.ONE

func _apply_magnetic_pull(sp: Node2D) -> void:
	if _snap_ghost_idx < 0: return
	var g: Dictionary = _ghosts[_snap_ghost_idx]
	var dist: float = sp.global_position.distance_to(g["pos"])
	if dist > MAGNET_R: return
	sp.global_position = sp.global_position.lerp(g["pos"], 0.18 * (1.0 - dist / MAGNET_R))

func _find_snap_slot(pos: Vector2, val: int):
	if _snap_ghost_idx >= 0 and _snap_ghost_idx < _ghosts.size():
		var g: Dictionary = _ghosts[_snap_ghost_idx]
		if _bst_rule_ok(g["parent_idx"], g["side"], val) and pos.distance_to(g["pos"]) < SNAP_DIST * 1.5: return g
	return null

func _nearest_valid_slot(pos: Vector2, val: int):
	var best_d := SNAP_DIST; var best = null
	for g in _ghosts:
		if not _bst_rule_ok(g["parent_idx"], g["side"], val): continue
		var d: float = pos.distance_to(g["pos"])
		if d < best_d: best_d = d; best = g
	return best

func _nearest_any_slot(pos: Vector2):
	var best_d := SNAP_DIST * 1.5; var best = null
	for g in _ghosts:
		var d: float = pos.distance_to(g["pos"])
		if d < best_d: best_d = d; best = g
	return best

func _bst_rule_ok(parent_idx: int, side: String, val: int) -> bool:
	if side == "root": return true
	if side == "duplicate": return false
	if parent_idx < 0 or parent_idx >= _bst.size(): return false
	var pv: int = _bst[parent_idx]["value"]
	return val < pv if side == "left" else val > pv

# =============================================================================
#  BST UTILITIES
# =============================================================================
func _find_insert_slot(value: int) -> Dictionary:
	if _bst.is_empty(): return {"pos":ROOT_POS,"parent_idx":-1,"side":"root"}
	return _find_slot_from(_root, ROOT_POS, 0, value)

func _find_slot_from(idx: int, pos: Vector2, depth: int, value: int) -> Dictionary:
	if depth >= MAX_DEPTH:
		return {"pos":pos,"parent_idx":idx,"side":"left" if value < (_bst[idx]["value"] as int) else "right"}
	var spread := SPREAD_MUL / pow(2.0, float(depth))
	var nv: int = _bst[idx]["value"] as int
	if value == nv: return {"pos":pos,"parent_idx":idx,"side":"duplicate"}
	elif value < nv:
		var lp := pos + Vector2(-spread, LEVEL_H)
		if (_bst[idx]["left"] as int) < 0: return {"pos":lp,"parent_idx":idx,"side":"left"}
		return _find_slot_from(_bst[idx]["left"] as int, lp, depth+1, value)
	else:
		var rp := pos + Vector2(spread, LEVEL_H)
		if (_bst[idx]["right"] as int) < 0: return {"pos":rp,"parent_idx":idx,"side":"right"}
		return _find_slot_from(_bst[idx]["right"] as int, rp, depth+1, value)

func _slot_depth(slot: Dictionary) -> int:
	if slot["side"] == "root": return 0
	if slot["parent_idx"] < 0: return 1
	return (_bst[slot["parent_idx"]]["depth"] as int) + 1

func _build_search_path(target: int) -> Array:
	var path: Array = []; var cur: int = _root
	while cur >= 0 and cur < _bst.size():
		if not is_instance_valid(_bst[cur]["sprite"] as Node2D): break
		path.append(cur)
		var val: int = _bst[cur]["value"] as int
		if target == val: break
		elif target < val: cur = _bst[cur]["left"] as int
		else:              cur = _bst[cur]["right"] as int
	return path

func _live_indices() -> Array:
	var out: Array = []
	for i in range(_bst.size()):
		if is_instance_valid(_bst[i]["sprite"] as Node2D): out.append(i)
	return out

func _collect_inorder(idx: int, out: Array) -> void:
	if idx < 0 or idx >= _bst.size() or not is_instance_valid(_bst[idx]["sprite"] as Node2D): return
	_collect_inorder(_bst[idx]["left"] as int, out); out.append(idx)
	_collect_inorder(_bst[idx]["right"] as int, out)

func _collect_preorder(idx: int, out: Array) -> void:
	if idx < 0 or idx >= _bst.size() or not is_instance_valid(_bst[idx]["sprite"] as Node2D): return
	out.append(idx); _collect_preorder(_bst[idx]["left"] as int, out)
	_collect_preorder(_bst[idx]["right"] as int, out)

func _collect_postorder(idx: int, out: Array) -> void:
	if idx < 0 or idx >= _bst.size() or not is_instance_valid(_bst[idx]["sprite"] as Node2D): return
	_collect_postorder(_bst[idx]["left"] as int, out); _collect_postorder(_bst[idx]["right"] as int, out)
	out.append(idx)

func _collect_inorder_vals(idx: int, out: Array) -> void:
	if idx < 0 or idx >= _bst.size() or not is_instance_valid(_bst[idx]["sprite"] as Node2D): return
	_collect_inorder_vals(_bst[idx]["left"] as int, out)
	out.append(_bst[idx]["value"] as int)
	_collect_inorder_vals(_bst[idx]["right"] as int, out)

func _invalidate_heights_upward(start: int) -> void:
	var cur := start
	while cur >= 0 and cur < _bst.size():
		var lh := _cached_height(_bst[cur]["left"] as int)
		var rh := _cached_height(_bst[cur]["right"] as int)
		_bst[cur]["height"] = 1 + maxi(lh, rh); cur = _bst[cur]["parent"] as int

func _cached_height(idx: int) -> int:
	if idx < 0 or idx >= _bst.size(): return 0
	return _bst[idx]["height"] as int

# =============================================================================
#  VISUAL HELPERS
# =============================================================================
func _restore_node_colors() -> void:
	for i in range(_bst.size()):
		var nd := _bst[i]["sprite"] as Node2D
		if is_instance_valid(nd): nd.modulate = COL_HEAD if i == _root else COL_WHITE

func _grey_subtree(idx: int) -> void:
	if idx < 0 or idx >= _bst.size(): return
	var nd := _bst[idx]["sprite"] as Node2D
	if is_instance_valid(nd): nd.create_tween().tween_property(nd,"modulate",COL_ELIM,0.25)
	_grey_subtree(_bst[idx]["left"] as int); _grey_subtree(_bst[idx]["right"] as int)

func _flash_ancestry(new_idx: int) -> void:
	var chain: Array = []; var cur := new_idx
	while cur >= 0 and cur < _bst.size(): chain.append(cur); cur = _bst[cur]["parent"] as int
	for i in range(chain.size() - 1, -1, -1):
		var ni: int = chain[i]; var nd := _bst[ni]["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var tw := nd.create_tween()
		tw.tween_interval((chain.size() - 1 - i) * 0.08)
		tw.tween_property(nd,"modulate",COL_ANCESTRY,0.06)
		tw.tween_property(nd,"modulate",COL_HEAD if ni==_root else COL_WHITE,0.22)

func _show_comparison_trace(value: int) -> void:
	_clear_trace()
	if _bst.is_empty(): return
	_trace_path(_root, ROOT_POS, 0, value)

func _trace_path(idx: int, pos: Vector2, depth: int, value: int) -> void:
	if idx < 0 or idx >= _bst.size(): return
	var nv: int = _bst[idx]["value"]; var spread := SPREAD_MUL / pow(2.0, float(depth))
	var go_left := value < nv
	var lbl := Label.new()
	lbl.text = ("%d<%d→L" if go_left else "%d>%d→R") % [value, nv]
	lbl.add_theme_font_override("font", _pixel_font); lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COL_TRACE)
	lbl.global_position = pos + Vector2(GHOST_R+4,-16); lbl.z_index = 30; _trace_layer.add_child(lbl)
	lbl.modulate.a = 0.0; lbl.create_tween().tween_property(lbl,"modulate:a",1.0,0.18)
	var child_pos := pos + Vector2(-spread if go_left else spread, LEVEL_H)
	var child_idx: int = _bst[idx]["left"] as int if go_left else _bst[idx]["right"] as int
	for s in range(6):
		if s % 2 == 0:
			var line := Line2D.new(); line.default_color = COL_TRACE; line.width = 2.5
			line.add_point(pos.lerp(child_pos,float(s)/6.0)); line.add_point(pos.lerp(child_pos,float(s+1)/6.0))
			line.z_index = 25; _trace_layer.add_child(line)
	if child_idx >= 0: _trace_path(child_idx, child_pos, depth+1, value)

func _clear_trace() -> void: for c in _trace_layer.get_children(): c.queue_free()

func _animate_branch(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new(); line.default_color = COL_EDGE; line.width = 3.0
	line.add_point(from); line.add_point(from); _edge_layer.add_child(line)
	line.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)\
		.tween_method(func(t:float): line.set_point_position(1,from.lerp(to,t)),0.0,1.0,0.3)

func _flash(nd: Node2D, c: Color) -> void:
	if not is_instance_valid(nd): return
	var _ftw := nd.create_tween()
	_ftw.tween_property(nd, "modulate", c, 0.06)
	_ftw.tween_property(nd, "modulate", COL_WHITE, 0.28)

func _bounce(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var s := nd.scale
	var btw := nd.create_tween()
	btw.set_trans(Tween.TRANS_BACK)
	btw.set_ease(Tween.EASE_OUT)
	btw.tween_property(nd, "scale", s * 1.4, 0.08)
	btw.tween_property(nd, "scale", s, 0.18)

func _shake(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var o := nd.position; var tw := nd.create_tween()
	for _i in range(6): tw.tween_property(nd,"position",o+Vector2(randf_range(-7,7),randf_range(-4,4)),0.04)
	tw.tween_property(nd,"position",o,0.04)

func _pulse_node(nd: Node2D, color: Color) -> void:
	if not is_instance_valid(nd): return
	var tw := nd.create_tween()
	for _i in range(3):
		tw.tween_property(nd, "modulate", color, 0.1)
		tw.tween_property(nd, "modulate", COL_WHITE, 0.1)

func _float_node(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	_float_world(nd.global_position + Vector2(-20,-44), text, color)

func _float_world(pos: Vector2, text: String, color: Color) -> void:
	var lbl := Label.new(); lbl.text = text; lbl.z_index = 200
	lbl.add_theme_font_override("font", _pixel_font); lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", color); _tree_layer.add_child(lbl)
	lbl.global_position = pos; var tw := lbl.create_tween()
	tw.tween_property(lbl,"position",lbl.position+Vector2(0,-40),0.9)
	tw.parallel().tween_property(lbl,"modulate:a",0.0,0.9); tw.tween_callback(lbl.queue_free)

# =============================================================================
#  HINT SYSTEM — shown as full-screen overlay only when player makes a mistake
# =============================================================================
var _hint_overlay:     ColorRect = null
var _hint_overlay_lbl: Label     = null
var _hint_dismiss_btn: Button    = null

func _setup_hint_overlay() -> void:
	var hud := get_node_or_null("HUD") as CanvasLayer
	if hud == null: return

	_hint_overlay = ColorRect.new()
	_hint_overlay.color   = Color(0.0, 0.0, 0.0, 0.0)
	_hint_overlay.size    = Vector2(1280, 720)
	_hint_overlay.z_index = 80
	_hint_overlay.visible = false
	hud.add_child(_hint_overlay)

	# Wood card
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _wood_panel(8))
	card.size     = Vector2(800, 190)
	card.position = Vector2(240, 240)
	card.z_index  = 81
	_hint_overlay.add_child(card)

	# Gold top accent
	var accent := ColorRect.new()
	accent.color    = WOOD_GOLD
	accent.size     = Vector2(800, 3)
	accent.position = Vector2(0, 0)
	card.add_child(accent)

	# Grain lines
	for gi in range(5):
		var g := ColorRect.new()
		g.color    = Color(WOOD_GRAIN.r, WOOD_GRAIN.g, WOOD_GRAIN.b, 0.09)
		g.size     = Vector2(780, 1)
		g.position = Vector2(10, 18 + gi * 26)
		card.add_child(g)

	_hint_overlay_lbl = Label.new()
	_hint_overlay_lbl.add_theme_font_override("font", _pixel_font)
	_hint_overlay_lbl.add_theme_font_size_override("font_size", 16)
	_hint_overlay_lbl.add_theme_color_override("font_color", WOOD_TEXT)
	_hint_overlay_lbl.position             = Vector2(20, 14)
	_hint_overlay_lbl.size                 = Vector2(760, 130)
	_hint_overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint_overlay_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_hint_overlay_lbl)

	_hint_dismiss_btn = Button.new()
	_hint_dismiss_btn.text     = "Got it  ✓"
	_hint_dismiss_btn.position = Vector2(580, 148)
	_hint_dismiss_btn.size     = Vector2(200, 36)
	_hint_dismiss_btn.add_theme_font_override("font", _pixel_font)
	_hint_dismiss_btn.add_theme_font_size_override("font_size", 14)
	_hint_dismiss_btn.pressed.connect(_dismiss_hint_overlay)
	_style_wood_btn(_hint_dismiss_btn)
	card.add_child(_hint_dismiss_btn)

func _show_hint_overlay(text: String) -> void:
	if _hint_overlay == null: return
	_hint_overlay_lbl.text = text
	_hint_overlay.visible  = true
	_hint_overlay.color.a  = 0.0
	var tw := _hint_overlay.create_tween()
	tw.tween_property(_hint_overlay, "color:a", 0.88, 0.18)
	# Auto-dismiss after 4s if player doesn't tap
	await get_tree().create_timer(4.0).timeout
	if is_instance_valid(_hint_overlay) and _hint_overlay.visible:
		_dismiss_hint_overlay()

func _dismiss_hint_overlay() -> void:
	if _hint_overlay == null or not _hint_overlay.visible: return
	var tw := _hint_overlay.create_tween()
	tw.tween_property(_hint_overlay, "color:a", 0.0, 0.22)
	tw.tween_callback(func(): _hint_overlay.visible = false)

# =============================================================================
#  HUD
# =============================================================================
func _setup_hud() -> void:
	_score_lbl.text="Score: 0"; _combo_lbl.text=""; _goal_lbl.text=""; _acc_lbl.text=""
	_refresh_lives()
	_setup_pause_btn()

func _setup_pause_btn() -> void:
	# PauseButton is a ColorRect in the tscn — clicks handled in _input below
	var pm := get_node_or_null("PauseMenu")
	if pm and pm.has_signal("howto_requested"):
		pm.howto_requested.connect(_reopen_intro)

func _reopen_intro() -> void:
	# Rebuild intro slides from scratch so the player can review them mid-game
	_intro_idx = 0
	_build_intro_slides()
	_show_intro_overlay()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pm := get_node_or_null("PauseMenu")
		if pm and pm.has_method("toggle"): pm.toggle()

func _refresh_lives() -> void:
	for c in _lives_row.get_children(): c.queue_free()
	for i in range(3):
		var lbl := Label.new(); lbl.text = "❤" if i<_lives else "🖤"
		lbl.add_theme_font_size_override("font_size",22); _lives_row.add_child(lbl)

func _setup_instr_bar() -> void:
	# Wood plank bar — sits at y=36, height 40
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _wood_panel(0))  # no radius — full-width plank
	panel.size     = Vector2(1280, 40)
	panel.position = Vector2(0, 36)
	panel.z_index  = 40
	add_child(panel)
	_instr_rect = ColorRect.new()   # keep var valid but unused for colour
	_instr_rect.visible = false
	panel.add_child(_instr_rect)

	# Grain lines across the bar
	for gi in range(3):
		var grain := ColorRect.new()
		grain.color    = Color(WOOD_GRAIN.r, WOOD_GRAIN.g, WOOD_GRAIN.b, 0.10)
		grain.size     = Vector2(1280, 1)
		grain.position = Vector2(0, 6 + gi * 12)
		grain.z_index  = 41
		panel.add_child(grain)

	# Gold top edge line
	var top_edge := ColorRect.new()
	top_edge.color    = WOOD_GOLD
	top_edge.size     = Vector2(1280, 1)
	top_edge.position = Vector2(0, 0)
	top_edge.z_index  = 41
	panel.add_child(top_edge)

	_instr_task = Label.new()
	_instr_task.add_theme_font_override("font", _pixel_font)
	_instr_task.add_theme_font_size_override("font_size", 15)
	_instr_task.add_theme_color_override("font_color", WOOD_TEXT)
	_instr_task.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	_instr_task.add_theme_constant_override("shadow_offset_x", 1)
	_instr_task.add_theme_constant_override("shadow_offset_y", 1)
	_instr_task.position             = Vector2(16, 5)
	_instr_task.size                 = Vector2(800, 30)
	_instr_task.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_instr_task.z_index              = 42
	panel.add_child(_instr_task)

	_instr_rule = Label.new()
	_instr_rule.add_theme_font_override("font", _pixel_font)
	_instr_rule.add_theme_font_size_override("font_size", 12)
	_instr_rule.add_theme_color_override("font_color", WOOD_SUBTEXT)
	_instr_rule.autowrap_mode        = TextServer.AUTOWRAP_OFF
	_instr_rule.clip_text            = true
	_instr_rule.position             = Vector2(820, 5)
	_instr_rule.size                 = Vector2(446, 30)
	_instr_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_instr_rule.z_index              = 42
	panel.add_child(_instr_rule)

func _update_instr(task: String, rule: String) -> void:
	_instr_task.text=task; _instr_rule.text=rule

# Banner state
var _banner_pill:     ColorRect = null   # small top bar that stays visible
var _banner_pill_lbl: Label     = null
var _banner_col:      Color     = COL_HEAD

func _setup_banner() -> void:
	# ── Full-screen dimmer overlay ────────────────────────────────────────────
	_banner_rect = ColorRect.new()
	_banner_rect.color   = Color(0.0, 0.0, 0.0, 0.0)
	_banner_rect.size    = Vector2(1280, 720)
	_banner_rect.z_index = 95
	_banner_rect.visible = false
	add_child(_banner_rect)

	# ── Wood card on the overlay ──────────────────────────────────────────────
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _wood_panel(10))
	card.size     = Vector2(860, 120)
	card.position = Vector2(210, 490)
	card.z_index  = 96
	_banner_rect.add_child(card)

	# Gold top strip on card
	var gold_strip := ColorRect.new()
	gold_strip.color    = WOOD_GOLD
	gold_strip.size     = Vector2(860, 3)
	gold_strip.position = Vector2(0, 0)
	card.add_child(gold_strip)

	# Grain lines
	for gi in range(4):
		var g := ColorRect.new()
		g.color    = Color(WOOD_GRAIN.r, WOOD_GRAIN.g, WOOD_GRAIN.b, 0.09)
		g.size     = Vector2(840, 1)
		g.position = Vector2(10, 20 + gi * 28)
		card.add_child(g)

	_banner_lbl = Label.new()
	_banner_lbl.add_theme_font_override("font", _pixel_font)
	_banner_lbl.add_theme_font_size_override("font_size", 20)
	_banner_lbl.add_theme_color_override("font_color", WOOD_GOLD)
	_banner_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_banner_lbl.add_theme_constant_override("shadow_offset_x", 2)
	_banner_lbl.add_theme_constant_override("shadow_offset_y", 2)
	_banner_lbl.position             = Vector2(20, 10)
	_banner_lbl.size                 = Vector2(820, 40)
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.add_child(_banner_lbl)

	_banner_sub = Label.new()
	_banner_sub.add_theme_font_override("font", _pixel_font)
	_banner_sub.add_theme_font_size_override("font_size", 15)
	_banner_sub.add_theme_color_override("font_color", WOOD_TEXT)
	_banner_sub.position             = Vector2(20, 56)
	_banner_sub.size                 = Vector2(820, 56)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(_banner_sub)

	# ── Pill — wood plank that docks to the top ───────────────────────────────
	_banner_pill = ColorRect.new()
	_banner_pill.color    = WOOD_MID
	_banner_pill.size     = Vector2(1280, 36)
	_banner_pill.position = Vector2(0, 0)
	_banner_pill.z_index  = 94
	_banner_pill.visible  = false
	add_child(_banner_pill)

	# Pill gold border bottom
	var pill_edge := ColorRect.new()
	pill_edge.color    = WOOD_GOLD
	pill_edge.size     = Vector2(1280, 2)
	pill_edge.position = Vector2(0, 34)
	_banner_pill.add_child(pill_edge)

	# Pill grain
	for gi in range(2):
		var g := ColorRect.new()
		g.color    = Color(WOOD_GRAIN.r, WOOD_GRAIN.g, WOOD_GRAIN.b, 0.08)
		g.size     = Vector2(1280, 1)
		g.position = Vector2(0, 8 + gi * 14)
		_banner_pill.add_child(g)

	_banner_pill_lbl = Label.new()
	_banner_pill_lbl.add_theme_font_override("font", _pixel_font)
	_banner_pill_lbl.add_theme_font_size_override("font_size", 15)
	_banner_pill_lbl.add_theme_color_override("font_color", WOOD_GOLD)
	_banner_pill_lbl.size                 = Vector2(1280, 36)
	_banner_pill_lbl.position             = Vector2(0, 0)
	_banner_pill_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_pill_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_banner_pill.add_child(_banner_pill_lbl)

func _show_banner(title: String, sub: String, col: Color) -> void:
	_banner_col = col
	_banner_lbl.text = title
	_banner_lbl.add_theme_color_override("font_color", col)
	_banner_sub.text = sub

	# Hide old pill if visible
	_banner_pill.visible = false
	_banner_pill.color.a = 0.0

	# Phase 1: fade the full-screen overlay in
	_banner_rect.visible = true
	_banner_rect.color.a = 0.0
	var tw := _banner_rect.create_tween()
	tw.tween_property(_banner_rect, "color:a", 0.88, 0.20)
	# Phase 2: hold for 1.4s
	tw.tween_interval(1.4)
	# Phase 3: fade out overlay
	tw.tween_property(_banner_rect, "color:a", 0.0, 0.3)
	tw.tween_callback(func():
		_banner_rect.visible = false
		_banner_pill.visible  = false
	)

# =============================================================================
#  COMPLETION
# =============================================================================
func _play_completion() -> void:
	_alive=false; _master_phase=MasterPhase.COMPLETE; AudioManager.play_sfx(PATH_SFX_WIN)
	_complete_banner.visible=true; _complete_banner.text="LEVEL COMPLETE!"
	_complete_banner.scale=Vector2(0.1,0.1)
	_complete_banner.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
		.tween_property(_complete_banner,"scale",Vector2(1,1),0.4)
	_acc_lbl.text="Accuracy: %.0f%%" % _accuracy()
	var grade:=_calc_grade(true); var chapter_id:int=GameRouter.current_chapter if has_node("/root/GameRouter") else 16
	if has_node("/root/PlayerProfile"): PlayerProfile.save_chapter_result(chapter_id,_score,_grade_to_stars(grade),_accuracy())
	await get_tree().create_timer(2.5).timeout
	if has_node("/root/GameRouter"): GameRouter.chapter_complete(chapter_id,_score,_grade_to_stars(grade))

func _end_game(success: bool) -> void:
	if _master_phase==MasterPhase.COMPLETE: return
	_alive=false; _master_phase=MasterPhase.COMPLETE
	var grade:=_calc_grade(success); _fail_summary.visible=true
	_fail_lbl.text=("✓" if success else "✗")+" Grade:%s  Tier:%s  Acc:%.0f%%  Score:%d"\
		%[grade,_cfg["name"] as String,_accuracy(),_score]
	var chapter_id:int=GameRouter.current_chapter if has_node("/root/GameRouter") else 16
	if has_node("/root/PlayerProfile"): PlayerProfile.save_chapter_result(chapter_id,_score,_grade_to_stars(grade),_accuracy())
	await get_tree().create_timer(3.0).timeout
	if has_node("/root/GameRouter"): GameRouter.chapter_complete(chapter_id,_score,_grade_to_stars(grade))

func _accuracy() -> float:
	# inserts + traversal correct taps all count toward accuracy
	var correct: int = (_stat["correct"] as int) + (_stat["inserts"] as int) + (_stat["traversals"] as int)
	var total:   int = correct + (_stat["wrong"] as int)
	return 100.0 if total == 0 else float(correct) / float(total) * 100.0

func _calc_grade(success: bool) -> String:
	var a := _accuracy()
	if not success:
		return "C" if a >= 60.0 else "F"
	if a >= 95.0: return "S"
	if a >= 82.0: return "A"
	if a >= 68.0: return "B"
	return "C"

func _grade_to_stars(grade: String) -> int:
	match grade:
		"S", "A": return 3
		"B":      return 2
		"C":      return 1
		_:        return 0

# =============================================================================
#  SLIDE DIAGRAM DRAW FUNCTIONS  (all drawn with CanvasItem.draw_* — no images)
#  Diagram area: x=100..1180, y=110..455
# =============================================================================

# ── Draw helpers ──────────────────────────────────────────────────────────────
func _dn(ci:CanvasItem, pos:Vector2, val:int, col:Color, font:Font, r:float=26.0) -> void:
	ci.draw_circle(pos, r, col)
	ci.draw_arc(pos, r, 0, TAU, 32, col.darkened(0.35), 2.5)
	var sz  := 16
	var s   := str(val)
	var tw  := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
	var asc := font.get_ascent(sz)
	# Shadow then text — centred exactly on pos
	ci.draw_string(font, Vector2(pos.x - tw*0.5 + 1, pos.y + asc*0.5 + 1),
		s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0,0,0,0.7))
	ci.draw_string(font, Vector2(pos.x - tw*0.5, pos.y + asc*0.5),
		s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color(0.04, 0.04, 0.04))

func _de(ci:CanvasItem,a:Vector2,b:Vector2,col:Color=Color(0.55,0.85,0.45,0.85),w:float=3.0)->void:
	ci.draw_line(a,b,col,w)

func _darrow(ci:CanvasItem,frm:Vector2,to:Vector2,col:Color,w:float=2.5)->void:
	ci.draw_line(frm,to,col,w); var d:=(to-frm).normalized(); var p:=Vector2(-d.y,d.x)*8.0
	ci.draw_line(to,to-d*16+p,col,w); ci.draw_line(to,to-d*16-p,col,w)

func _dl(ci:CanvasItem,pos:Vector2,text:String,col:Color,font:Font,sz:int=14)->void:
	ci.draw_string(font,pos,text,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,col)

func _dlc(ci:CanvasItem,pos:Vector2,text:String,col:Color,font:Font,sz:int=14)->void:
	var ts:=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,sz)
	ci.draw_string(font,pos-Vector2(ts.x/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,sz,col)

func _dbox(ci:CanvasItem,rect:Rect2,bg:Color,border:Color)->void:
	ci.draw_rect(rect,bg,true); ci.draw_rect(rect,border,false,1.5)

# ── Shared sample tree positions ──────────────────────────────────────────────
func _stn()->Dictionary:
	var cx:=640.0; var ry:=185.0
	return {50:Vector2(cx,ry),30:Vector2(cx-140,ry+85),70:Vector2(cx+140,ry+85),
		20:Vector2(cx-210,ry+170),40:Vector2(cx-80,ry+170),
		60:Vector2(cx+70,ry+170),80:Vector2(cx+200,ry+170)}

func _draw_sample_tree(ci:CanvasItem,font:Font,hi:Array=[],dim:Array=[])->void:
	var ns:=_stn()
	for e:Array in [[50,30],[50,70],[30,20],[30,40],[70,60],[70,80]]: _de(ci,ns[e[0]],ns[e[1]])
	for val in ns:
		var col:Color
		if val in hi: col=COL_SEARCH_HI
		elif val in dim: col=Color(0.3,0.3,0.3,0.4)
		elif val==50: col=COL_HEAD
		else: col=COL_NODE_BASE
		_dn(ci,ns[val],val,col,font)

# ════════════════════════════════════════════════════════════════════════════
#  SLIDE DIAGRAMS  — Layout contract
#  Diagram safe zone: x=60..1220   y=108..448
#  Body text divider sits at y=460. Nothing may draw below y=448.
#  Tree origin (root centre) is always at TREE_O = (640, 148).
#  Node radius = 22. Labels that sit ABOVE a node: y - 34.
#  Labels that sit BELOW a node: y + 30. Never y + 36+ (clips into next row).
#  Horizontal labels to the RIGHT of a node: x + 28.
#  Compact tree layout (5-level height fits in zone):
#    Root y=148, Level1 y=218, Level2 y=288  (LEVEL_H=70, SPREAD=130 at root)
# ════════════════════════════════════════════════════════════════════════════

# Compact tree positions used by all slides
func _ctn() -> Dictionary:
	var cx := 640.0; var ry := 162.0; var lh := 72.0; var sp := 130.0
	return {
		50: Vector2(cx,        ry),
		30: Vector2(cx - sp,   ry + lh),
		70: Vector2(cx + sp,   ry + lh),
		20: Vector2(cx - sp - 68, ry + lh*2),
		40: Vector2(cx - sp + 62, ry + lh*2),
		60: Vector2(cx + sp - 62, ry + lh*2),
		80: Vector2(cx + sp + 68, ry + lh*2),
	}

func _draw_compact_tree(ci: CanvasItem, font: Font, hi: Array = [], dim: Array = []) -> void:
	var ns := _ctn()
	for e: Array in [[50,30],[50,70],[30,20],[30,40],[70,60],[70,80]]:
		_de(ci, ns[e[0]], ns[e[1]])
	for val: int in ns:
		var col: Color
		if   val in hi:  col = COL_SEARCH_HI
		elif val in dim: col = Color(0.35, 0.35, 0.35, 0.45)
		elif val == 50:  col = COL_HEAD
		else:            col = COL_NODE_BASE
		_dn(ci, ns[val], val, col, font, 24.0)

# ════════════════════════════════════════════════════════════════════════════
#  TIER 0  — BST Basics
# ════════════════════════════════════════════════════════════════════════════
func _draw_s0_what_is_bst(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()

	# "← Root" — to the RIGHT of the root node, vertically centred on it
	_dl(ci, ns[50] + Vector2(32, -7), "← Root", COL_HEAD, font, 13)

	# "Leaf" labels — far enough below the node circle (radius 24 → bottom at +24)
	# Use +44 so there's a 20px gap below the circle edge
	for v: int in [20, 40, 60, 80]:
		_dlc(ci, ns[v] + Vector2(0, 44), "Leaf", Color(0.65, 0.65, 0.5), font, 11)

	# "Edge" label — placed beside the midpoint of the root→right edge,
	# offset to the RIGHT so it doesn't overlap either node or the line
	var emid: Vector2 = ns[50].lerp(ns[70], 0.55) + Vector2(14, -4)
	_dl(ci, emid, "Edge", Color(0.55, 0.85, 0.45), font, 12)

	# "Node (rune stone)" — top-left corner, well away from any drawn element
	_dl(ci, Vector2(68, 108), "Node (rune stone)", Color(0.9, 0.9, 0.6), font, 13)

func _draw_s0_anatomy(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()
	# Level indicators — right side, clear of rightmost node (ns[80] ~x=770)
	var level_x := 880.0
	var level_ys: Array[float] = [148.0, 218.0, 288.0]
	var level_labels: Array[String] = ["Level 0  (Root)", "Level 1", "Level 2  (Leaves)"]
	var node_right_xs: Array[float] = [ns[50].x + 28.0, ns[70].x + 28.0, ns[80].x + 28.0]
	for i in range(3):
		# Short horizontal tick from node edge to level label
		ci.draw_line(Vector2(node_right_xs[i], level_ys[i]),
			Vector2(level_x - 8, level_ys[i]),
			Color(0.4, 0.5, 0.4, 0.5), 1.0)
		_dl(ci, Vector2(level_x, level_ys[i] - 7), level_labels[i],
			Color(0.65, 0.75, 0.55), font, 12)
	# Height annotation — below the last level, enough gap from ns[20/40/60/80]
	_dl(ci, Vector2(level_x, 335), "Height = 2", COL_HEAD, font, 13)
	# Left subtree highlight box — only around 30, 20, 40 (no text clashing)
	var box_x: float = ns[20].x - 28.0
	var box_y: float = ns[30].y - 28.0
	var box_w: float = (ns[40].x + 28.0) - box_x
	var box_h: float = (ns[20].y + 28.0) - box_y
	ci.draw_rect(Rect2(Vector2(box_x, box_y), Vector2(box_w, box_h)),
		Color(0.3, 0.8, 1.0, 0.07), true)
	ci.draw_rect(Rect2(Vector2(box_x, box_y), Vector2(box_w, box_h)),
		Color(0.3, 0.8, 1.0, 0.45), false, 1.5)
	# Box label — below the box with enough gap from the leaf nodes (radius 24 → bottom at ns[20].y+24)
	_dlc(ci, Vector2((box_x + box_x + box_w) / 2.0, ns[20].y + 50),
		"Left subtree of 50", Color(0.4, 0.8, 1.0), font, 12)

func _draw_s0_rule(ci: CanvasItem, font: Font) -> void:
	# Focused 3-node diagram only — root=50, left child=30 (blue), right child=70 (orange)
	# Vertically centred in the upper diagram zone with plenty of breathing room
	var rx := 640.0; var ry := 165.0; var spread := 190.0; var ch := 110.0
	var lp := Vector2(rx - spread, ry + ch)
	var rp := Vector2(rx + spread, ry + ch)
	# Colour-coded edges (no extra arrows on top — edge IS the arrow)
	_de(ci, Vector2(rx, ry), lp, Color(0.3, 0.8, 1.0), 3.0)
	_de(ci, Vector2(rx, ry), rp, Color(1.0, 0.7, 0.3), 3.0)
	_dn(ci, Vector2(rx, ry), 50, COL_HEAD, font, 26.0)
	_dn(ci, lp, 30, Color(0.3, 0.7, 1.0), font, 24.0)
	_dn(ci, rp, 70, Color(1.0, 0.6, 0.2), font, 24.0)
	# Comparison labels — centred below each child, clear of rule box
	_dlc(ci, lp + Vector2(0, 38), "30 < 50  →  LEFT",  Color(0.3, 0.85, 1.0), font, 14)
	_dlc(ci, rp + Vector2(0, 38), "70 > 50  →  RIGHT", Color(1.0, 0.72, 0.3), font, 14)
	# Rule box — fixed at y=350, well below the children's labels
	_dbox(ci, Rect2(Vector2(280, 350), Vector2(720, 66)), Color(0.07, 0.08, 0.18), Color(0.4, 0.4, 0.65))
	_dlc(ci, Vector2(640, 371), "Rule:   LEFT  <  Node  <  RIGHT", COL_HEAD, font, 18)
	_dlc(ci, Vector2(640, 398), "This applies at every single node", Color(0.65, 0.65, 0.52), font, 13)

func _draw_s0_build(ci: CanvasItem, font: Font) -> void:
	# Partial tree: root=50 (placed), right child=70 (placed)
	# Left slot is open (green ghost) — drag tile=30 toward it
	var rx := 640.0; var ry := 148.0; var lh := 95.0; var sp := 140.0
	var root_p  := Vector2(rx, ry)
	var right_p := Vector2(rx + sp, ry + lh)
	var ghost_p := Vector2(rx - sp, ry + lh)   # open left slot
	var bad_p   := Vector2(rx + sp + 90, ry + lh + 95)  # invalid slot under right child
	var tile_p  := Vector2(rx - sp, ry + lh + 140)       # dragged tile

	# Edges
	_de(ci, root_p, right_p)
	_de(ci, root_p, ghost_p, Color(0.3, 1.0, 0.5, 0.4), 2.0)
	_de(ci, right_p, bad_p, Color(1.0, 0.2, 0.2, 0.3), 1.5)

	# Placed nodes
	_dn(ci, root_p,  50, COL_HEAD,      font, 24.0)
	_dn(ci, right_p, 70, COL_NODE_BASE, font, 22.0)

	# Green ghost slot
	ci.draw_circle(ghost_p, 26.0, Color(0.3, 1.0, 0.5, 0.28))
	ci.draw_arc(ghost_p, 26.0, 0, TAU, 32, Color(0.3, 1.0, 0.5, 0.85), 2.0)
	_dlc(ci, ghost_p + Vector2(0, 35), "< 50  ✓", Color(0.35, 1.0, 0.5), font, 12)

	# Red ghost slot
	ci.draw_circle(bad_p, 22.0, Color(1.0, 0.2, 0.2, 0.22))
	ci.draw_arc(bad_p, 22.0, 0, TAU, 32, Color(1.0, 0.25, 0.25, 0.75), 1.5)
	_dlc(ci, bad_p + Vector2(0, 31), "> 70  ✗", Color(1.0, 0.4, 0.4), font, 11)

	# Dragged tile (the rune being moved)
	_dn(ci, tile_p, 30, Color(0.92, 0.82, 0.32), font, 24.0)

	# Dashed arrow from tile to ghost slot — one clean arrow, no edge doubling
	_darrow(ci, tile_p + Vector2(0, -28), ghost_p + Vector2(0, 30), Color(0.35, 1.0, 0.5), 2.0)
	_dlc(ci, tile_p + Vector2(0, 42), "Drag to green slot", Color(0.45, 0.95, 0.5), font, 12)

# ════════════════════════════════════════════════════════════════════════════
#  TIER 1  — Binary Search
# ════════════════════════════════════════════════════════════════════════════
func _draw_s1_intro(ci: CanvasItem, font: Font) -> void:
	# Draw tree manually so path edges are coloured differently from grey edges
	var ns := _ctn()
	# Grey dim edges first (non-path)
	_de(ci, ns[50], ns[70], Color(0.3,0.3,0.3,0.4), 2.0)
	_de(ci, ns[70], ns[60], Color(0.3,0.3,0.3,0.4), 2.0)
	_de(ci, ns[70], ns[80], Color(0.3,0.3,0.3,0.4), 2.0)
	_de(ci, ns[30], ns[20], Color(0.3,0.3,0.3,0.4), 2.0)
	# Highlighted path edges
	_de(ci, ns[50], ns[30], COL_SEARCH_HI, 3.5)
	_de(ci, ns[30], ns[40], COL_SEARCH_HI, 3.5)
	# Dim nodes
	for v: int in [20, 60, 70, 80]:
		_dn(ci, ns[v], v, Color(0.3,0.3,0.3,0.45), font, 22.0)
	# Path nodes on top
	for v: int in [50, 30, 40]:
		_dn(ci, ns[v], v, COL_SEARCH_HI, font, 22.0)
	# Step labels — right of each path node, staggered so they don't touch
	# Labels centred below each path node — clear of circle (radius 22, bottom at +22)
	_dlc(ci, ns[50] + Vector2(0, 44), "40 < 50  →  LEFT",  COL_SEARCH_HI, font, 12)
	_dlc(ci, ns[30] + Vector2(0, 44), "40 > 30  →  RIGHT", COL_SEARCH_HI, font, 12)
	_dlc(ci, ns[40] + Vector2(0, 44), "✓  FOUND 40!", COL_OK, font, 13)
	# Header
	_dlc(ci, Vector2(640, 108), "Searching for:  40", COL_HEAD, font, 17)

func _draw_s1_complexity(ci: CanvasItem, font: Font) -> void:
	# Vertical divider splits diagram in half
	ci.draw_line(Vector2(600, 108), Vector2(600, 445), Color(0.35,0.35,0.55,0.45), 1.0)

	# ── Left panel: balanced 7-node tree ──────────────────────────────────
	var lx := 290.0; var ly := 145.0
	var bp: Array[Vector2] = [
		Vector2(lx,       ly),
		Vector2(lx-80,   ly+68), Vector2(lx+80,   ly+68),
		Vector2(lx-120,  ly+136),Vector2(lx-40,   ly+136),
		Vector2(lx+40,   ly+136),Vector2(lx+120,  ly+136),
	]
	for e: Array in [[0,1],[0,2],[1,3],[1,4],[2,5],[2,6]]:
		_de(ci, bp[e[0]], bp[e[1]])
	for p: Vector2 in bp:
		_dn(ci, p, 0, COL_NODE_BASE, font, 18.0)
	# Labels well clear of nodes (bottom of lowest nodes = ly+136+18 = ly+154)
	_dlc(ci, Vector2(lx, ly - 30), "Balanced", COL_OK, font, 14)
	_dlc(ci, Vector2(lx, ly + 178), "O(log n)  =  3 steps", COL_OK, font, 13)

	# ── Right panel: degenerate sorted chain ──────────────────────────────
	var dx := 870.0; var dy := 128.0
	var prev := Vector2(dx, dy)
	for i in range(7):
		var cur := Vector2(dx, dy + i * 42)
		if i > 0: _de(ci, prev, cur, Color(1.0,0.45,0.2), 2.0)
		_dn(ci, cur, 10 + i*10, Color(1.0,0.45,0.2,0.88), font, 15.0)
		prev = cur
	# Labels: top label above first node, bottom label below last node (+15 = +42*6+15=267)
	_dlc(ci, Vector2(dx, dy - 30), "Degenerate", Color(1.0,0.5,0.2), font, 14)
	_dlc(ci, Vector2(dx, dy + 282), "O(n)  =  7 steps", Color(1.0,0.5,0.2), font, 13)

func _draw_s1_trace(ci: CanvasItem, font: Font) -> void:
	# Search for 60: path 50→70→60 highlighted; left subtree dimmed
	_draw_compact_tree(ci, font, [], [30, 20, 40, 80])
	var ns := _ctn()
	_de(ci, ns[50], ns[70], COL_SEARCH_HI, 3.5)
	_de(ci, ns[70], ns[60], COL_SEARCH_HI, 3.5)
	for v: int in [50, 70, 60]:
		_dn(ci, ns[v], v, COL_SEARCH_HI, font, 22.0)
	_dlc(ci, ns[50] + Vector2(0, 44), "60 > 50  →  RIGHT", COL_SEARCH_HI, font, 12)
	_dlc(ci, ns[70] + Vector2(0, 44), "60 < 70  →  LEFT",  COL_SEARCH_HI, font, 12)
	_dlc(ci, ns[60] + Vector2(0, 44), "60 = 60  →  FOUND!", COL_OK, font, 13)
	_dlc(ci, Vector2(640, 108), "Searching for:  60", COL_HEAD, font, 17)

func _draw_s1_gameplay(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()
	_dlc(ci, Vector2(640, 108), "Tap each node along the search path", COL_HEAD, font, 16)
	# Pulse ring on root to indicate start
	ci.draw_arc(ns[50], 32.0, 0, TAU, 32, COL_SEARCH_HI, 2.5)
	_dlc(ci, ns[50] + Vector2(0, 38), "Start here", COL_SEARCH_HI, font, 12)

# ════════════════════════════════════════════════════════════════════════════
#  TIER 2  — Inorder Traversal
# ════════════════════════════════════════════════════════════════════════════
func _draw_s2_intro(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()
	_dlc(ci, Vector2(640, 108), "Traversal = visit every node exactly once", COL_HEAD, font, 16)
	# Number each node in inorder sequence — ABOVE node so no clash with value text
	var inorder: Array[int] = [20, 30, 40, 50, 60, 70, 80]
	for i in range(inorder.size()):
		_dlc(ci, ns[inorder[i]] + Vector2(0, -40), str(i + 1), COL_INORDER, font, 13)

func _draw_s2_rule(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()
	# ① Left subtree box — around 30, 20, 40
	var bx1: float = ns[20].x - 26.0
	var bw1: float = (ns[40].x + 26.0) - bx1
	var by1: float = ns[30].y - 26.0
	var bh1: float = (ns[20].y + 26.0) - by1
	ci.draw_rect(Rect2(Vector2(bx1, by1), Vector2(bw1, bh1)), Color(0.3,1.0,0.5,0.07), true)
	ci.draw_rect(Rect2(Vector2(bx1, by1), Vector2(bw1, bh1)), Color(0.3,1.0,0.5,0.5), false, 1.5)
	_dlc(ci, Vector2(bx1 + bw1/2.0, ns[20].y + 48), "① Left first", COL_INORDER, font, 12)
	# ② Root ring
	ci.draw_arc(ns[50], 30.0, 0, TAU, 32, COL_INORDER, 2.5)
	_dlc(ci, ns[50] + Vector2(0, -44), "② Root", COL_INORDER, font, 12)
	# ③ Right subtree box — around 70, 60, 80
	var bx3: float = ns[60].x - 26.0
	var bw3: float = (ns[80].x + 26.0) - bx3
	var by3: float = ns[70].y - 26.0
	var bh3: float = (ns[60].y + 26.0) - by3
	ci.draw_rect(Rect2(Vector2(bx3, by3), Vector2(bw3, bh3)), Color(0.3,1.0,0.5,0.07), true)
	ci.draw_rect(Rect2(Vector2(bx3, by3), Vector2(bw3, bh3)), Color(0.3,1.0,0.5,0.5), false, 1.5)
	_dlc(ci, Vector2(bx3 + bw3/2.0, ns[80].y + 48), "③ Right last", COL_INORDER, font, 12)
	# Formula
	_dlc(ci, Vector2(640, 365), "Left  →  Root  →  Right   (recursive)", COL_INORDER, font, 15)

func _draw_s2_sorted(ci: CanvasItem, font: Font) -> void:
	# Small tree (top half) + sorted linear sequence (bottom half)
	_draw_compact_tree(ci, font)
	_dlc(ci, Vector2(640, 108), "Inorder output is always sorted!", COL_HEAD, font, 17)
	# Sorted node row — at y=350 with enough room above the divider
	var sv: Array[int] = [20, 30, 40, 50, 60, 70, 80]
	var oy := 355.0; var spacing := 92.0
	var startx := 640.0 - (sv.size() - 1) * spacing / 2.0
	for i in range(sv.size()):
		var bx := startx + i * spacing
		_dn(ci, Vector2(bx, oy), sv[i], COL_INORDER, font, 18.0)
		if i < sv.size() - 1:
			_darrow(ci, Vector2(bx + 20, oy), Vector2(bx + spacing - 20, oy), COL_INORDER, 2.0)

func _draw_s2_gameplay(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()
	_dlc(ci, Vector2(640, 108), "Tap every node in inorder sequence", COL_HEAD, font, 16)
	var inorder: Array[int] = [20, 30, 40, 50, 60, 70, 80]
	for i in range(inorder.size()):
		ci.draw_arc(ns[inorder[i]], 26.0, 0, TAU, 32, COL_INORDER, 2.0)
		_dlc(ci, ns[inorder[i]] + Vector2(0, -40), str(i + 1), COL_INORDER, font, 12)

# ════════════════════════════════════════════════════════════════════════════
#  TIER 3  — Pre/Post Traversal + Delete
# ════════════════════════════════════════════════════════════════════════════
func _draw_s3_preorder(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()
	_dlc(ci, Vector2(640, 108), "Preorder: Root → Left → Right", COL_HEAD, font, 17)
	var pre: Array[int] = [50, 30, 20, 40, 70, 60, 80]
	for i in range(pre.size()):
		ci.draw_arc(ns[pre[i]], 26.0, 0, TAU, 32, COL_PREORDER, 2.0)
		_dlc(ci, ns[pre[i]] + Vector2(0, -40), str(i + 1), COL_PREORDER, font, 12)
	_dlc(ci, Vector2(640, 355), "50 → 30 → 20 → 40 → 70 → 60 → 80", COL_PREORDER, font, 13)

func _draw_s3_postorder(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()
	_dlc(ci, Vector2(640, 108), "Postorder: Left → Right → Root", COL_HEAD, font, 17)
	var post: Array[int] = [20, 40, 30, 60, 80, 70, 50]
	for i in range(post.size()):
		ci.draw_arc(ns[post[i]], 26.0, 0, TAU, 32, COL_POSTORDER, 2.0)
		_dlc(ci, ns[post[i]] + Vector2(0, -40), str(i + 1), COL_POSTORDER, font, 12)
	_dlc(ci, Vector2(640, 355), "20 → 40 → 30 → 60 → 80 → 70 → 50", COL_POSTORDER, font, 13)

func _draw_s3_delete(ci: CanvasItem, font: Font) -> void:
	# Three cases side by side — each in its own 340px column
	# Case 1 at x=190, Case 2 at x=530 (centre), Case 3 at x=870
	var cols3: Array[float] = [190.0, 530.0, 870.0]
	var cy := 185.0; var r := 20.0

	# ── Case 1: Leaf ──────────────────────────────────────────────────────
	var c1 := cols3[0]
	_dlc(ci, Vector2(c1, cy - 32), "Case 1: Leaf", Color(0.9,0.9,0.6), font, 13)
	_dn(ci, Vector2(c1, cy), 30, COL_NODE_BASE, font, r)
	_de(ci, Vector2(c1, cy), Vector2(c1 - 44, cy + 75), COL_DEL)
	_dn(ci, Vector2(c1 - 44, cy + 75), 20, COL_DEL, font, r)
	_dlc(ci, Vector2(c1 - 44, cy + 75 + 30), "Remove it", COL_DEL, font, 12)

	# ── Case 2: One child ─────────────────────────────────────────────────
	var c2 := cols3[1]
	_dlc(ci, Vector2(c2, cy - 32), "Case 2: One Child", Color(0.9,0.9,0.6), font, 13)
	_dn(ci, Vector2(c2, cy), 40, COL_DEL, font, r)
	_de(ci, Vector2(c2, cy), Vector2(c2 + 50, cy + 75))
	_dn(ci, Vector2(c2 + 50, cy + 75), 55, COL_NODE_BASE, font, r)
	_darrow(ci, Vector2(c2 + 50, cy + 75) + Vector2(-8, -22),
		Vector2(c2, cy) + Vector2(8, 22), Color(0.3, 1.0, 0.5))
	_dlc(ci, Vector2(c2, cy + 75 + 30), "Lift child up", Color(0.3,1.0,0.5), font, 12)

	# ── Case 3: Two children ─────────────────────────────────────────────
	var c3 := cols3[2]
	_dlc(ci, Vector2(c3, cy - 32), "Case 3: Two Children", Color(0.9,0.9,0.6), font, 13)
	_dn(ci, Vector2(c3, cy), 50, COL_DEL, font, r)
	_de(ci, Vector2(c3, cy), Vector2(c3 - 50, cy + 75))
	_de(ci, Vector2(c3, cy), Vector2(c3 + 50, cy + 75))
	_dn(ci, Vector2(c3 - 50, cy + 75), 30, COL_NODE_BASE, font, r)
	_dn(ci, Vector2(c3 + 50, cy + 75), 70, COL_NODE_BASE, font, r)
	_de(ci, Vector2(c3 + 50, cy + 75), Vector2(c3 + 18, cy + 150))
	_dn(ci, Vector2(c3 + 18, cy + 150), 60, Color(0.3,1.0,0.5), font, 18.0)
	_dlc(ci, Vector2(c3 + 18, cy + 150 + 26), "successor", Color(0.3,1.0,0.5), font, 11)
	_darrow(ci, Vector2(c3 + 6, cy + 143), Vector2(c3 - 4, cy + 22), Color(0.3,1.0,0.5))

	# Shared rule box at the bottom
	_dbox(ci, Rect2(Vector2(80, 365), Vector2(1100, 48)), Color(0.07,0.08,0.18), Color(0.35,0.35,0.55))
	_dlc(ci, Vector2(640, 381), "Leaf → remove   |   1 child → lift up   |   2 children → swap successor", COL_HEAD, font, 13)

func _draw_s3_successor(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font, [], [20, 40])
	var ns := _ctn()
	_dlc(ci, Vector2(640, 108), "Inorder Successor = smallest in right subtree", COL_HEAD, font, 16)
	# Highlight path: 50 → 70 → 60
	_de(ci, ns[50], ns[70], Color(0.3,1.0,0.5), 3.5)
	_de(ci, ns[70], ns[60], Color(0.3,1.0,0.5), 3.5)
	for v: int in [50, 70, 60]:
		_dn(ci, ns[v], v, Color(0.3, 1.0, 0.5), font, 22.0)
	_dl(ci, ns[70] + Vector2(28, -6), "Go RIGHT once", Color(0.3,1.0,0.5), font, 12)
	_dl(ci, ns[60] + Vector2(28, -6), "Then LEFT as far as possible", Color(0.3,1.0,0.5), font, 12)
	_dlc(ci, ns[60] + Vector2(0, 36), "= Inorder Successor of 50", COL_OK, font, 12)

# ════════════════════════════════════════════════════════════════════════════
#  TIER 4  — AVL Balancing
# ════════════════════════════════════════════════════════════════════════════
func _draw_s4_degenerate(ci: CanvasItem, font: Font) -> void:
	# Left panel: balanced  |  Right panel: degenerate chain
	ci.draw_line(Vector2(580, 115), Vector2(580, 430), Color(0.35,0.35,0.55,0.45), 1.0)

	# Balanced tree (left)
	var lx := 280.0; var ly := 140.0
	var bp: Array[Vector2] = [
		Vector2(lx,      ly),
		Vector2(lx-70,  ly+60), Vector2(lx+70,  ly+60),
		Vector2(lx-105, ly+120), Vector2(lx-35, ly+120),
		Vector2(lx+35,  ly+120), Vector2(lx+105, ly+120),
	]
	for e: Array in [[0,1],[0,2],[1,3],[1,4],[2,5],[2,6]]:
		_de(ci, bp[e[0]], bp[e[1]])
	for p: Vector2 in bp:
		_dn(ci, p, 0, COL_NODE_BASE, font, 18.0)
	_dlc(ci, Vector2(lx, ly - 28), "Balanced", COL_OK, font, 14)
	_dlc(ci, Vector2(lx, ly + 170), "O(log n)  →  3 steps max", COL_OK, font, 13)

	# Degenerate chain (right)
	var dx := 870.0; var dy := 128.0
	var prev := Vector2(dx, dy)
	for i in range(7):
		var cur := Vector2(dx, dy + i * 44)
		if i > 0: _de(ci, prev, cur, Color(1.0,0.45,0.2), 2.0)
		_dn(ci, cur, 10 + i * 10, Color(1.0,0.45,0.2,0.88), font, 16.0)
		prev = cur
	_dlc(ci, Vector2(dx, dy - 28), "Degenerate", Color(1.0,0.5,0.2), font, 14)
	_dlc(ci, Vector2(dx, dy + 320), "O(n)  →  7 steps max", Color(1.0,0.5,0.2), font, 13)

func _draw_s4_bf(ci: CanvasItem, font: Font) -> void:
	_draw_compact_tree(ci, font)
	var ns := _ctn()
	_dlc(ci, Vector2(640, 108), "Balance Factor = height(left) − height(right)", COL_HEAD, font, 16)
	# BF labels — ABOVE each node so they don't clash with node value text
	var bfs: Dictionary = {50:0, 30:0, 70:0, 20:0, 40:0, 60:0, 80:0}
	for val: int in bfs:
		_dlc(ci, ns[val] + Vector2(0, -34), "BF=%d" % bfs[val], COL_AVL_OK, font, 11)
	# Rule box
	_dbox(ci, Rect2(Vector2(260, 340), Vector2(760, 66)), Color(0.07,0.08,0.18), Color(0.4,0.4,0.6))
	_dlc(ci, Vector2(640, 360), "AVL rule:  BF must be  −1, 0,  or  +1  everywhere", COL_AVL_OK, font, 15)
	_dlc(ci, Vector2(640, 386), "If |BF| > 1 after insert  →  rotate to fix!", COL_AVL_BAD, font, 13)

func _draw_s4_rotations(ci: CanvasItem, font: Font) -> void:
	# 2×2 grid — each cell is 560×130 px
	# Cell origins: TL=(60,128) TR=(660,128) BL=(60,278) BR=(660,278)
	var titles: Array[String] = [
		"LL  →  Right Rotate", "RR  →  Left Rotate",
		"LR  →  Left-Right Rotate", "RL  →  Right-Left Rotate"
	]
	var cell_cols: Array[Color] = [COL_INORDER, COL_SEARCH_HI, COL_PREORDER, COL_POSTORDER]
	var ox: Array[float] = [60.0,  660.0, 60.0,  660.0]
	var oy2: Array[float] = [130.0, 130.0, 275.0, 275.0]

	# Horizontal divider between rows
	ci.draw_line(Vector2(60, 258), Vector2(1220, 258), Color(0.3,0.3,0.45,0.4), 1.0)
	# Vertical divider between columns
	ci.draw_line(Vector2(620, 115), Vector2(620, 420), Color(0.3,0.3,0.45,0.4), 1.0)

	for i in range(4):
		var x: float = ox[i]; var y: float = oy2[i]; var c: Color = cell_cols[i]
		_dlc(ci, Vector2(x + 280, y - 20), titles[i], c, font, 12)
		# Before: unbalanced 3-node chain (left-leaning for LL/LR, right-leaning for RR/RL)
		var n1 := Vector2(x + 80,  y)
		var n2 := Vector2(x + 80,  y + 50)
		var n3 := Vector2(x + 120, y + 50)
		_de(ci, n1, n2, c, 1.5); _de(ci, n2, n3, c, 1.5)
		_dn(ci, n1, 0, c.darkened(0.25), font, 14.0)
		_dn(ci, n2, 0, c, font, 14.0)
		_dn(ci, n3, 0, c.darkened(0.25), font, 14.0)
		# Arrow
		_darrow(ci, Vector2(x + 152, y + 25), Vector2(x + 196, y + 25), c)
		# After: balanced 3-node
		var m := Vector2(x + 260, y + 50)
		var ml := Vector2(x + 228, y)
		var mr := Vector2(x + 292, y)
		_de(ci, m, ml, c, 1.5); _de(ci, m, mr, c, 1.5)
		_dn(ci, m,  0, c, font, 14.0)
		_dn(ci, ml, 0, c.darkened(0.25), font, 14.0)
		_dn(ci, mr, 0, c.darkened(0.25), font, 14.0)

func _draw_s4_gameplay(ci: CanvasItem, font: Font) -> void:
	# Imbalanced right-right chain: 30→50→70
	var cx := 550.0; var ry2 := 145.0
	var r := Vector2(cx, ry2)
	var rc := Vector2(cx + 120, ry2 + 80)
	var rrc := Vector2(cx + 215, ry2 + 160)
	_de(ci, r, rc, Color(1.0,0.5,0.3), 2.5)
	_de(ci, rc, rrc, Color(1.0,0.5,0.3), 2.5)
	_dn(ci, r,   30, COL_AVL_BAD, font, 22.0)
	_dn(ci, rc,  50, Color(1.0,0.65,0.3), font, 22.0)
	_dn(ci, rrc, 70, COL_NODE_BASE, font, 22.0)
	# BF labels above each node
	_dlc(ci, r   + Vector2(0, -32), "BF = −2  !", COL_AVL_BAD, font, 13)
	_dlc(ci, rc  + Vector2(0, -32), "BF = −1",   Color(1.0,0.75,0.3), font, 12)
	_dlc(ci, rrc + Vector2(0, -32), "BF = 0",    COL_AVL_OK, font, 12)
	_dlc(ci, Vector2(640, 108), "Imbalanced after insert — choose a rotation:", COL_HEAD, font, 16)
	# 4 choice buttons
	var btn_labels: Array[String] = [
		"LL  (Right Rotate)", "RR  (Left Rotate)",
		"LR  (Left-Right)", "RL  (Right-Left)"
	]
	var btn_cols: Array[Color] = [COL_INORDER, COL_SEARCH_HI, COL_PREORDER, COL_POSTORDER]
	var bpos: Array[Vector2] = [
		Vector2(62, 320), Vector2(660, 320),
		Vector2(62, 392), Vector2(660, 392),
	]
	for i in range(4):
		var is_correct := (i == 1)   # RR is correct for right-right chain
		_dbox(ci, Rect2(bpos[i], Vector2(540, 56)),
			Color(0.08,0.18,0.09) if is_correct else Color(0.08,0.09,0.18),
			COL_OK if is_correct else btn_cols[i].darkened(0.35))
		_dlc(ci, bpos[i] + Vector2(270, 28),
			btn_labels[i] + ("  ✓" if is_correct else ""),
			COL_OK if is_correct else btn_cols[i], font, 14)
