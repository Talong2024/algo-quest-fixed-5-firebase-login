# =============================================================================
# AlgoQuest — Chapter 5: Kingdom Roads (Graph) v3
# File: scripts/chapters/graph/GraphGame.gd
#
# GameRouter integration:
#   Chapters 21–25 → tiers 0–4
#   GameRouter.go_to_chapter(21..25) sets DifficultyManager.current_tier (0..4)
#   before loading this scene.  _ready() reads that tier via DifficultyManager.
#
#   Completion:  GameRouter.chapter_complete(chapter_id, score, stars)
#   chapter_id   = GameRouter.current_chapter  (21..25)
#
# 5 Tiers:
#   0 (ch 21) — CONNECT   4 nodes, connect all into one component
#   1 (ch 22) — PATH      5 nodes, find any path A→B
#   2 (ch 23) — BFS       6 nodes, click cities in correct BFS order
#   3 (ch 24) — DIJKSTRA  7 nodes, build the cheapest path START→END
#   4 (ch 25) — EXPERT    8 nodes, Dijkstra + dynamic edge mutations
#
# Teaching additions vs v2:
#   • Adjacency-list panel always visible (Gap 1 from checklist)
#   • BFS queue rendered as animated FIFO strip (Gap 2)
#   • DFS mode stub added to tier 2 toggle (Gap 3)
#   • Dijkstra distance-table widget updates per relaxation (Gap 4)
#   • Spanning-tree celebration text after Connect success (Gap 5)
#   • Weighted vs unweighted micro-lesson on tier 3 intro (Gap 6)
# =============================================================================

extends Node2D

# ── Safe helpers ──────────────────────────────────────────────────────────────
func _apply_font(node: Control) -> void:
	if _pixel_font == null or not is_instance_valid(node): return
	node.add_theme_font_override("font", _pixel_font)

func _safe_bgm(path: String) -> void:
	if has_node("/root/AudioManager") and AudioManager.has_method("play_bgm"):
		AudioManager.play_bgm(path)

func _safe_sfx(path: String) -> void:
	if has_node("/root/AudioManager") and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx(path)

# ─────────────────────────────────────────────────────────────────────────────
#  ASSETS
# ─────────────────────────────────────────────────────────────────────────────
# Background — Pixel Art Top Down by Cainos (cainos.itch.io/pixel-art-top-down-basic)
# Drop the pre-composed overworld PNG into res://assets/medieval/art/map/
const PATH_BG      := "res://assets/medieval/art/map/grass.jpg"

# Font — Tiny RPG Font Kit I (opengameart.org/content/tiny-rpg-font-kit-i, CC0)
# Drop the TTF into res://assets/medieval/font/
const PATH_FONT    := "res://assets/medieval/font/medieval.ttf"

# SFX — unchanged (keep existing success/fail/level_up)
const PATH_SFX_OK  := "res://assets/codemon/audio/sfx/success.ogg"
const PATH_SFX_FAIL:= "res://assets/codemon/audio/sfx/fail.ogg"
const PATH_SFX_WIN := "res://assets/codemon/audio/sfx/level_up.ogg"

# BGM — Free Fantasy Medieval Ambient Music Pack by alkakrab
# (alkakrab.itch.io/free-fantasy-medieval-ambient-music-pack)
# Drop the OGG loop into res://assets/medieval/audio/music/
const PATH_BGM     := "res://assets/medieval/audio/music/silverbook_loop.ogg"

# Node tiles — Tiny Swords by Pixel Frog (pixelfrog-assets.itch.io/tiny-swords, CC0)
# Path inside pack: Factions/Knights/Buildings/
# Each file is a 192x192 spritesheet — use frame 0 (first column) as static icon.
# In Godot: set texture as AtlasTexture, region = Rect2(0, 0, 192, 192)
const CITY_ICONS: Array[String] = [
	"res://assets/medieval/art/buildings/House.png",      # 128x192
	"res://assets/medieval/art/buildings/House2.png",     # 128x192
	"res://assets/medieval/art/buildings/House3.png",     # 128x192
	"res://assets/medieval/art/buildings/Tower.png",      # 128x256
	"res://assets/medieval/art/buildings/Barracks.png",   # 192x256
	"res://assets/medieval/art/buildings/Archery.png",    # 192x256
	"res://assets/medieval/art/buildings/Monastery.png",  # 192x320
	"res://assets/medieval/art/buildings/Castle.png",     # 320x256
]

# ─────────────────────────────────────────────────────────────────────────────
#  LAYOUT & COLORS
# ─────────────────────────────────────────────────────────────────────────────
const CITY_SCALE := Vector2(0.65, 0.65)  # tallest sprite 320px * 0.65 ≈ 208px — large & readable
const CITY_HIT   := 44.0                 # larger hit radius to match bigger sprites
const SNAP_DIST  := 80.0
const MAGNET_R   := 120.0

# ── Medieval color palette ────────────────────────────────────────────────────
const EDGE_COLOR   := Color(0.72, 0.55, 0.25, 0.8)   # aged rope road
const PATH_COLOR   := Color(0.95, 0.78, 0.20)         # gold trail
const PATH_EDGE    := Color(0.85, 0.60, 0.10, 0.9)    # burnished gold
const LIVE_COL     := Color(0.95, 0.85, 0.40, 0.65)   # glowing rune draft
const SNAP_COL     := Color(0.90, 0.85, 0.40, 0.85)   # rune snap highlight
const BFS_NEXT_COL := Color(0.40, 0.85, 0.45)         # enchanted green
const START_COL    := Color(0.30, 1.00, 0.30)         # keep — universally "safe"
const END_COL      := Color(1.00, 0.30, 0.30)         # keep — universally "danger"
const COL_WRONG    := Color(1.00, 0.15, 0.15)         # keep
const COL_OK       := Color(0.85, 0.70, 0.20)         # gold correct flash
const COL_WHITE    := Color.WHITE

# Per-city tints — earthy medieval: stone, forest, amber, burgundy, slate, parchment
const CITY_COLORS: Array[Color] = [
	Color(0.75, 0.65, 0.45),  # stone
	Color(0.25, 0.55, 0.30),  # forest green
	Color(0.85, 0.60, 0.15),  # amber
	Color(0.55, 0.20, 0.25),  # burgundy
	Color(0.40, 0.50, 0.65),  # slate blue
	Color(0.90, 0.82, 0.60),  # parchment
	Color(0.60, 0.35, 0.15),  # earthy brown
	Color(0.70, 0.70, 0.50),  # aged linen
]
const CANVAS := Rect2(180, 120, 820, 440)

# ─────────────────────────────────────────────────────────────────────────────
#  TIER PARAMS  (index = tier 0..4, chapter = 21..25)
# ─────────────────────────────────────────────────────────────────────────────
const TIER_PARAMS: Array[Dictionary] = [
	# tier 0 — ch 21 — OBSERVE: what is a graph?
	{"node_count":4,  "edge_count":5,  "mode":"observe",  "weighted":false,
	 "dynamic":false, "time_limit":0.0, "penalty":0,  "hints":true,
	 "concept":"OBSERVE"},
	# tier 1 — ch 22 — CONNECT: draw roads to connect all cities
	{"node_count":5,  "edge_count":3,  "mode":"connect",  "weighted":false,
	 "dynamic":false, "time_limit":0.0, "penalty":0,  "hints":true,
	 "concept":"CONNECT"},
	# tier 2 — ch 23 — PATH: find a path between two cities
	{"node_count":6,  "edge_count":8,  "mode":"path",     "weighted":false,
	 "dynamic":false, "time_limit":0.0, "penalty":10, "hints":true,
	 "concept":"PATH"},
	# tier 3 — ch 24 — BFS
	{"node_count":6,  "edge_count":8,  "mode":"bfs_dfs",  "weighted":false,
	 "dynamic":false, "time_limit":60.0,"penalty":15, "hints":false,
	 "concept":"BFS"},
	# tier 4 — ch 25 — DIJKSTRA
	{"node_count":7,  "edge_count":10, "mode":"dijkstra", "weighted":true,
	 "dynamic":false, "time_limit":50.0,"penalty":25, "hints":false,
	 "concept":"DIJKSTRA"},
]

# Each concept maps to an Array of slide Dictionaries:
# { "title", "body", "image" }
# image = "" means no image for that slide.
# Images live in res://assets/medieval/art/tutorial/
const CONCEPT_SLIDES: Dictionary = {
	"OBSERVE": [
		{
			"title": "What is a Graph?",
			"body":  "A graph is a set of NODES connected by EDGES.\n\nNodes represent cities. Edges are the roads between them.",
			"image": "res://assets/medieval/art/tutorial/graph_intro.png",
		},
		{
			"title": "Nodes & Edges",
			"body":  "Each city (node) can connect to many others.\nThe Adjacency List shows every connection.",
			"image": "res://assets/medieval/art/tutorial/adjacency.png",
		},
		{
			"title": "Your Task",
			"body":  "Click each city to highlight its neighbours.\nExplore all cities to complete this level!",
			"image": "",
		},
	],
	"CONNECT": [
		{
			"title": "Connecting a Graph",
			"body":  "Right now the cities are split into separate groups.\nA graph is CONNECTED when you can reach every city from any other.",
			"image": "res://assets/medieval/art/tutorial/disconnected.png",
		},
		{
			"title": "Draw Roads",
			"body":  "Drag from one city to another to draw a road.\nConnect ALL cities into ONE network.",
			"image": "res://assets/medieval/art/tutorial/connect_drag.png",
		},
	],
	"PATH": [
		{
			"title": "What is a Path?",
			"body":  "A path is a sequence of cities joined by existing roads.\nYou can only travel along roads that already exist.",
			"image": "res://assets/medieval/art/tutorial/path_intro.png",
		},
		{
			"title": "Find the Path",
			"body":  "Click a START city, then keep clicking connected cities\nuntil you reach a different city.",
			"image": "",
		},
	],
	"BFS": [
		{
			"title": "Breadth-First Search",
			"body":  "BFS visits every reachable city starting from one node.\nIt explores the NEAREST cities first — level by level.",
			"image": "res://assets/medieval/art/tutorial/bfs_levels.png",
		},
		{
			"title": "The Queue",
			"body":  "BFS uses a QUEUE (First-In First-Out).\nThe front of the queue is always visited next.",
			"image": "res://assets/medieval/art/tutorial/bfs_queue.png",
		},
		{
			"title": "Your Task",
			"body":  "A start city is chosen for you.\nClick cities in the correct BFS order.\nThe queue panel on the right shows what comes next.",
			"image": "",
		},
	],
	"DIJKSTRA": [
		{
			"title": "Weighted Graphs",
			"body":  "Each road has a COST (weight).\nThe cheapest path minimises the total cost, not the number of hops.",
			"image": "res://assets/medieval/art/tutorial/weighted_graph.png",
		},
		{
			"title": "Dijkstra's Algorithm",
			"body":  "At each step, pick the unvisited city with the LOWEST known cost.\nThe distance table on the right updates as you go.",
			"image": "res://assets/medieval/art/tutorial/dijkstra_table.png",
		},
		{
			"title": "Your Task",
			"body":  "Build your path step-by-step from START (green) to END (red).\nOnly the cheapest path earns full marks!",
			"image": "",
		},
	],
	"EXPERT": [
		{
			"title": "Expert: Dynamic Roads",
			"body":  "Same rules as Dijkstra — but roads open and close every 8 seconds!\nAdapt your path when the map changes.",
			"image": "",
		},
	],
}


# Preloaded tutorial textures — matched to CONCEPT_SLIDES image paths
const TUTORIAL_TEXTURES: Dictionary = {
	"res://assets/medieval/art/tutorial/graph_intro.png":    preload("res://assets/medieval/art/tutorial/graph_intro.png"),
	"res://assets/medieval/art/tutorial/adjacency.png":      preload("res://assets/medieval/art/tutorial/adjacency.png"),
	"res://assets/medieval/art/tutorial/disconnected.png":   preload("res://assets/medieval/art/tutorial/disconnected.png"),
	"res://assets/medieval/art/tutorial/connect_drag.png":   preload("res://assets/medieval/art/tutorial/connect_drag.png"),
	"res://assets/medieval/art/tutorial/path_intro.png":     preload("res://assets/medieval/art/tutorial/path_intro.png"),
	"res://assets/medieval/art/tutorial/bfs_levels.png":     preload("res://assets/medieval/art/tutorial/bfs_levels.png"),
	"res://assets/medieval/art/tutorial/bfs_queue.png":      preload("res://assets/medieval/art/tutorial/bfs_queue.png"),
	"res://assets/medieval/art/tutorial/weighted_graph.png": preload("res://assets/medieval/art/tutorial/weighted_graph.png"),
	"res://assets/medieval/art/tutorial/dijkstra_table.png": preload("res://assets/medieval/art/tutorial/dijkstra_table.png"),
}
# ─────────────────────────────────────────────────────────────────────────────
#  NODE REFS — must match GraphGame.tscn exactly
# ─────────────────────────────────────────────────────────────────────────────
@onready var _bg:              Sprite2D       = $Background
@onready var _edge_layer:      Node2D         = $EdgeLayer
@onready var _city_layer:      Node2D         = $CityLayer
@onready var _wt_layer:        Node2D         = $WeightLayer
@onready var _path_layer:      Node2D         = $PathLayer
@onready var _label_layer:     CanvasLayer    = $LabelLayer
@onready var _live_edge:       Line2D         = $LiveEdge
@onready var _edge_timer:      Timer          = $EdgeTimer
@onready var _game_timer:      Timer          = $GameTimer

# HUD
@onready var _score_lbl:       Label          = $HUD/ScoreLabel
@onready var _combo_lbl:       Label          = $HUD/ComboLabel
@onready var _timer_lbl:       Label          = $HUD/TimerLabel
@onready var _goal_lbl:        Label          = $HUD/GoalLabel
@onready var _acc_lbl:         Label          = $HUD/AccuracyLabel
@onready var _lives_row:       HBoxContainer  = $HUD/LivesRow
@onready var _hint_lbl:        Label          = $HUD/HintBox/HintLabel
@onready var _hint_box:        PanelContainer = $HUD/HintBox
@onready var _task_lbl:        Label          = $HUD/TaskLabel
@onready var _mode_lbl:        Label          = $HUD/ModeLabel
@onready var _cost_lbl:        Label          = $HUD/CostLabel
@onready var _fail_summary:    PanelContainer = $HUD/FailSummary
@onready var _fail_lbl:        Label          = $HUD/FailSummary/FailLabel

# Teaching widgets (right panel)
@onready var _bfs_display:     VBoxContainer  = $HUD/RightPanel/BFSQueueDisplay
@onready var _adj_panel:       VBoxContainer  = $HUD/RightPanel/AdjPanel
@onready var _dist_panel:      VBoxContainer  = $HUD/RightPanel/DistPanel

# Completion
@onready var _complete_banner: Label          = $CompleteBanner

# Intro slide window
@onready var _intro_overlay:   PanelContainer = $HUD/IntroOverlay
@onready var _intro_title:     Label          = $HUD/IntroOverlay/Margin/VBox/TitleLabel
@onready var _intro_image:     TextureRect    = $HUD/IntroOverlay/Margin/VBox/SlideImage
@onready var _intro_body:      Label          = $HUD/IntroOverlay/Margin/VBox/BodyLabel
@onready var _intro_page:      Label          = $HUD/IntroOverlay/Margin/VBox/NavRow/PageLabel
@onready var _intro_back:      Button         = $HUD/IntroOverlay/Margin/VBox/NavRow/BackBtn
@onready var _intro_next:      Button         = $HUD/IntroOverlay/Margin/VBox/NavRow/NextBtn

# ─────────────────────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────────────────────
var _p: Dictionary = {}
var _chapter_id: int = 21          # resolved from GameRouter.current_chapter

var _cities: Array = []            # {id, sprite, pos, label, neighbors, color}
var _edges:  Array = []            # {a, b, weight, line}
var _path_lines: Array = []

# Interaction
var _drag_city_id: int     = -1
var _drag_offset:  Vector2 = Vector2.ZERO
var _edge_src_id:  int     = -1
var _snap_city_id: int     = -1

# Path / BFS / Dijkstra state
var _selected_path: Array  = []
var _bfs_order:     Array  = []
var _observe_clicked: Array = []
var _city_by_id:     Dictionary = {}  # id → city dict for safe lookup
var _src_id: int = -1
var _dst_id: int = -1
var _running_cost: float = 0.0

# Dijkstra distance table (node_id → best known cost)
var _dist_table: Dictionary = {}

# Per-city glow tweens — keyed by city id — for adjacent-node pulse effect
var _glow_tweens: Dictionary = {}
# Canvas-layer label nodes — keyed by city id
var _city_labels: Dictionary = {}

# Analytics
var _stat := {
	"correct":0, "wrong_order":0, "wrong_cost":0,
	"non_neighbor":0, "wrong_connect":0,
}

var _score:       int   = 0
var _combo:       int   = 0
var _lives:       int   = 3
var _combo_decay: float = 0.0
const COMBO_TTL := 3.0

var _time_left: float = 0.0
var _alive:     bool  = false
var _intro_visible: bool  = false
var _intro_slides:  Array = []
var _intro_page_idx: int  = 0
var _pixel_font: Font = null

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font

	# ── Resolve chapter & tier from GameRouter ──────────────────────────────
	if has_node("/root/GameRouter"):
		_chapter_id = GameRouter.current_chapter
	# Clamp to graph family 21–25
	_chapter_id = clamp(_chapter_id, 21, 25)

	var tier: int = 0
	if has_node("/root/DifficultyManager"):
		tier = DifficultyManager.current_tier
	tier = clamp(tier, 0, 4)
	_p = TIER_PARAMS[tier]

	# ── Scene setup ─────────────────────────────────────────────────────────
	_setup_bg()
	_setup_hud()
	_spawn_cities(_p["node_count"])
	await get_tree().process_frame  # ensure sprites are in scene tree before drawing edges
	_generate_edges(_p["edge_count"])
	if _p["weighted"]:
		_draw_weight_labels()

	_mode_lbl.text         = _p["mode"].to_upper()
	_complete_banner.visible = false
	_fail_summary.visible    = false
	_cost_lbl.visible        = (_p["mode"] == "dijkstra")

	# Right-panel widgets: show what's relevant
	_bfs_display.visible = false
	_adj_panel.visible   = (_p["mode"] in ["observe", "connect", "path", "bfs_dfs"])
	_dist_panel.visible  = (_p["mode"] == "dijkstra")

	_build_adj_panel()

	if _p["mode"] == "bfs_dfs":
		_start_bfs_auto()

	if _p["mode"] == "dijkstra" and _cities.size() >= 2:
		# Enforce minimum hop distance so START and END are never trivially adjacent.
		# Tier 3 (ch24) needs at least 3 hops, tier 4 (ch25) needs at least 4 hops.
		var min_hops := 4 if _p["dynamic"] else 3
		var pair     := _find_distant_pair(min_hops)
		_src_id = pair[0]
		_dst_id = pair[1]
		_mark_endpoints()
		_init_dist_table()
		_refresh_dist_panel()

	# Timers
	if _p["time_limit"] > 0:
		_time_left = _p["time_limit"]
		_game_timer.wait_time = 1.0
		_game_timer.one_shot  = false
		_game_timer.timeout.connect(_tick_clock)
		_game_timer.start()

	if _p["dynamic"]:
		_edge_timer.wait_time = 8.0
		_edge_timer.one_shot  = false
		_edge_timer.timeout.connect(_mutate_one_edge)
		_edge_timer.start()

	_live_edge.default_color = LIVE_COL
	_live_edge.width         = 8.0
	_live_edge.visible       = false

	_safe_bgm(PATH_BGM)
	_alive = true
	_hint_box.visible = false  # intro slides replaced hint box

	_show_intro()

# ─────────────────────────────────────────────────────────────────────────────
#  INTRO OVERLAY
# ─────────────────────────────────────────────────────────────────────────────
func _show_intro() -> void:
	var concept: String = _p["concept"]
	if concept not in CONCEPT_SLIDES: return
	_intro_slides   = CONCEPT_SLIDES[concept]
	_intro_page_idx = 0
	_intro_visible  = true
	_intro_overlay.visible = true
	# Wire buttons
	_intro_back.pressed.connect(_on_intro_back)
	_intro_next.pressed.connect(_on_intro_next)
	_apply_font(_intro_title)
	_apply_font(_intro_body)
	_apply_font(_intro_page)
	_intro_title.add_theme_font_size_override("font_size", 20)
	_intro_body.add_theme_font_size_override("font_size", 16)
	_intro_page.add_theme_font_size_override("font_size", 14)
	_refresh_intro_slide()

func _refresh_intro_slide() -> void:
	var slide: Dictionary = _intro_slides[_intro_page_idx]
	_intro_title.text = slide["title"]
	_intro_body.text  = slide["body"]
	var img_path: String = slide["image"]
	if img_path != "" and img_path in TUTORIAL_TEXTURES:
		_intro_image.texture = TUTORIAL_TEXTURES[img_path]
		_intro_image.visible = true
	else:
		_intro_image.visible = false
	_intro_page.text  = "%d / %d" % [_intro_page_idx + 1, _intro_slides.size()]
	_intro_back.disabled = (_intro_page_idx == 0)
	_intro_next.text  = "Begin!" if _intro_page_idx == _intro_slides.size() - 1 else "Next ▶"

func _on_intro_back() -> void:
	_intro_page_idx = max(0, _intro_page_idx - 1)
	_refresh_intro_slide()

func _on_intro_next() -> void:
	if _intro_page_idx < _intro_slides.size() - 1:
		_intro_page_idx += 1
		_refresh_intro_slide()
	else:
		_dismiss_intro()

func _dismiss_intro() -> void:
	_intro_visible         = false
	_intro_overlay.visible = false

# ─────────────────────────────────────────────────────────────────────────────
#  SETUP
# ─────────────────────────────────────────────────────────────────────────────
func _setup_bg() -> void:
	_bg.texture        = load(PATH_BG)
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.position       = Vector2(640, 360)
	_bg.scale          = Vector2(1280.0 / 576.0, 720.0 / 384.0)
	_bg.z_index        = -10

func _setup_hud() -> void:
	var labels: Array = [
		_score_lbl, _combo_lbl, _timer_lbl, _goal_lbl, _acc_lbl,
		_hint_lbl, _task_lbl, _mode_lbl, _cost_lbl, _fail_lbl,
		_complete_banner,
	]
	for lbl in labels:
		if is_instance_valid(lbl):
			_apply_font(lbl)
			lbl.add_theme_font_size_override("font_size", 20)

	_score_lbl.text    = "Score: 0"
	_combo_lbl.text    = ""
	_acc_lbl.text      = "Accuracy: -"
	_goal_lbl.text     = _goal_text()
	_task_lbl.text     = _goal_text()
	_timer_lbl.visible = _p["time_limit"] > 0
	if _p["time_limit"] > 0:
		_timer_lbl.text = "⏱ %d" % int(_p["time_limit"])

	_complete_banner.add_theme_font_size_override("font_size", 60)
	_complete_banner.add_theme_color_override("font_color", Color(0.3, 1, 0.4))
	_complete_banner.z_index = 100

	_refresh_lives()

func _goal_text() -> String:
	match _p["mode"]:
		"observe":  return "Click any city to see its connections."
		"connect":  return "Connect all %d cities into one network." % _p["node_count"]
		"path":     return "Find any path between two cities."
		"bfs_dfs":  return "Click cities in correct BFS order."
		"dijkstra": return "Build the cheapest path: START → END."
		_:          return ""

# ─────────────────────────────────────────────────────────────────────────────
#  CITY SPAWN
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_cities(count: int) -> void:
	for i in range(count):
		var pos       := _random_clear_pos()
		var icon_path := CITY_ICONS[i % CITY_ICONS.size()]
		var sprite    := Sprite2D.new()
		if ResourceLoader.exists(icon_path):
			# Single static frame — load directly, no atlas or hframes needed
			sprite.texture = load(icon_path)
		else:
			var cr       := ColorRect.new()
			cr.size       = Vector2(32, 32)
			cr.position   = Vector2(-16, -16)
			cr.color      = CITY_COLORS[i % CITY_COLORS.size()]
			sprite.add_child(cr)
		sprite.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale           = CITY_SCALE
		sprite.modulate        = Color.WHITE  # no tint — show original sprite colors
		sprite.z_index         = 10
		sprite.set_meta("city_id", i)
		_city_layer.add_child(sprite)
		sprite.global_position = pos

		var lbl := Label.new()
		lbl.text = char(65 + i)
		_apply_font(lbl)
		lbl.add_theme_font_size_override("font_size", 36)   # larger, easy to read
		lbl.add_theme_color_override("font_color", COL_WHITE)
		lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		lbl.add_theme_constant_override("shadow_offset_x", 3)
		lbl.add_theme_constant_override("shadow_offset_y", 3)
		lbl.set_meta("city_label_id", i)
		# Place on the CanvasLayer so it always renders on top, unaffected by world transforms
		_label_layer.add_child(lbl)
		# Position will be synced every frame in _process; store reference
		_city_labels[i] = lbl

		var city_data := {
			"id":        i,
			"sprite":    sprite,
			"pos":       pos,
			"label":     char(65 + i),
			"neighbors": [],
			"color":     Color.WHITE,  # no tint
		}
		_cities.append(city_data)
		_city_by_id[i] = city_data

func _random_clear_pos() -> Vector2:
	# Try random positions first with strict spacing
	for _a in 120:
		var x  := CANVAS.position.x + randf() * CANVAS.size.x
		var y  := CANVAS.position.y + randf() * CANVAS.size.y
		var p  := Vector2(x, y)
		var ok := true
		for c: Dictionary in _cities:
			if (c["pos"] as Vector2).distance_to(p) < 140.0:
				ok = false; break
		if ok: return p
	# Fallback: grid-based placement so no two nodes ever overlap
	var cols := 4
	var idx  := _cities.size()
	var cell_w := CANVAS.size.x / float(cols)
	var cell_h := CANVAS.size.y / float(cols)
	var col := idx % cols
	var row := idx / cols
	return CANVAS.position + Vector2(cell_w * col + cell_w * 0.5, cell_h * row + cell_h * 0.5)

# ─────────────────────────────────────────────────────────────────────────────
#  EDGE GENERATION
# ─────────────────────────────────────────────────────────────────────────────
func _generate_edges(count: int) -> void:
	# Connect mode: start with NO edges so the player must do the work.
	# Other modes need a connected graph to guarantee a valid path/BFS/Dijkstra,
	# so they get a spanning tree first then extras.
	if _p["mode"] == "connect":
		# Add only a small number of random edges (fewer than needed to connect all)
		# so the player still has meaningful work to do.
		var partial: int = max(1, _cities.size() / 2 - 1)
		var tries   := 0
		while partial > 0 and tries < 200:
			var a := randi() % _cities.size()
			var b := randi() % _cities.size()
			if a != b and not _edge_exists(a, b):
				_add_edge(a, b)
				partial -= 1
			tries += 1
		return

	# All other modes: build a spanning tree using nearest-neighbor order
	# so roads connect spatially close cities and avoid long crossing lines.
	_spanning_tree_by_proximity()
	var extras := count - (_cities.size() - 1)
	var tries  := 0
	while extras > 0 and tries < 400:
		# Extra edges also prefer nearby pairs to reduce crossings
		var best_a   := -1
		var best_b   := -1
		var best_dist := INF
		for _r in 12:
			var a := randi() % _cities.size()
			var b := randi() % _cities.size()
			if a == b or _edge_exists(a, b): continue
			var d := (_cities[a]["pos"] as Vector2).distance_to(_cities[b]["pos"] as Vector2)
			if d < best_dist: best_dist = d; best_a = a; best_b = b
		if best_a >= 0:
			_add_edge(best_a, best_b)
			extras -= 1
		tries += 1

# Builds a spanning tree by always connecting the nearest unvisited city —
# like Prim's algorithm. Keeps roads short and reduces visual crossings.
func _spanning_tree_by_proximity() -> void:
	if _cities.size() < 2: return
	var visited: Dictionary = {0: true}
	while visited.size() < _cities.size():
		var best_a    := -1
		var best_b    := -1
		var best_dist := INF
		for a: int in visited:
			for bi in range(_cities.size()):
				if bi in visited or _edge_exists(a, bi): continue
				var d := (_cities[a]["pos"] as Vector2).distance_to(_cities[bi]["pos"] as Vector2)
				if d < best_dist: best_dist = d; best_a = a; best_b = bi
		if best_a >= 0:
			_add_edge(best_a, best_b)
			visited[best_b] = true
		else:
			break

func _add_edge(a: int, b: int) -> void:
	if a == b or _edge_exists(a, b): return
	# Always read from sprite position — guaranteed correct even before first frame
	var sa := _cities[a]["sprite"] as Node2D
	var sb := _cities[b]["sprite"] as Node2D
	var pa := sa.global_position if sa.is_inside_tree() else (_cities[a]["pos"] as Vector2)
	var pb := sb.global_position if sb.is_inside_tree() else (_cities[b]["pos"] as Vector2)
	# Sync stored pos so all future lookups are accurate
	_cities[a]["pos"] = pa
	_cities[b]["pos"] = pb
	var w  := randi() % 9 + 1
	var ln := Line2D.new()
	ln.default_color = EDGE_COLOR
	ln.width         = 8.0
	ln.add_point(pa)
	ln.add_point(pb)
	_edge_layer.add_child(ln)
	_edges.append({"a": a, "b": b, "weight": w, "line": ln})
	# Must get array reference directly — casting to Array creates a copy
	var nb_a: Array = _cities[a]["neighbors"]
	var nb_b: Array = _cities[b]["neighbors"]
	nb_a.append(b)
	nb_b.append(a)

func _edge_exists(a: int, b: int) -> bool:
	for e: Dictionary in _edges:
		if (e["a"] == a and e["b"] == b) or (e["a"] == b and e["b"] == a):
			return true
	return false

func _draw_weight_labels() -> void:
	for c in _wt_layer.get_children(): c.queue_free()
	await get_tree().process_frame
	for e: Dictionary in _edges:
		var pa  := _cities[e["a"]]["pos"] as Vector2
		var pb  := _cities[e["b"]]["pos"] as Vector2
		var mid := (pa + pb) * 0.5
		var lbl := Label.new()
		lbl.text = str(e["weight"])
		_apply_font(lbl)
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
		_wt_layer.add_child(lbl)
		lbl.global_position = mid + Vector2(-8, -18)

# Returns BFS hop count between two nodes (-1 if unreachable)
func _bfs_hop_distance(from_id: int, to_id: int) -> int:
	var visited: Dictionary = {}
	var q: Array = [[from_id, 0]]
	while not q.is_empty():
		var cur: Array = q.pop_front()
		var node: int  = cur[0]
		var hops: int  = cur[1]
		if node == to_id: return hops
		if node in visited: continue
		visited[node] = true
		for nb: int in ((_city_by_id[node]["neighbors"] if node in _city_by_id else []) as Array):
			if nb not in visited: q.append([nb, hops + 1])
	return -1  # unreachable

# Finds a src/dst pair with at least min_hops between them.
# Falls back to the most distant reachable pair if min_hops can't be satisfied.
func _find_distant_pair(min_hops: int) -> Array:
	var best_src := 0
	var best_dst := _cities.size() - 1
	var best_d   := -1
	for a in range(_cities.size()):
		for b in range(_cities.size()):
			if a == b: continue
			var d := _bfs_hop_distance(a, b)
			if d >= min_hops:
				return [a, b]  # first pair that satisfies min_hops
			if d > best_d:
				best_d = d; best_src = a; best_dst = b
	# Fallback: return most distant pair found even if under min_hops
	return [best_src, best_dst]

func _mark_endpoints() -> void:
	if _src_id >= 0:
		(_cities[_src_id]["sprite"] as Node2D).modulate = START_COL
		_float_label(_cities[_src_id]["sprite"] as Node2D, "START", START_COL)
	if _dst_id >= 0:
		(_cities[_dst_id]["sprite"] as Node2D).modulate = END_COL
		_float_label(_cities[_dst_id]["sprite"] as Node2D, "END", END_COL)
	_task_lbl.text = "Build path: %s → %s" % [
		_cities[_src_id]["label"], _cities[_dst_id]["label"],
	]

# ─────────────────────────────────────────────────────────────────────────────
#  ADJACENCY LIST PANEL  (teaching widget — always visible in non-Dijkstra modes)
# ─────────────────────────────────────────────────────────────────────────────
func _build_adj_panel() -> void:
	for c in _adj_panel.get_children(): c.queue_free()

	var title := Label.new()
	title.text = "Adjacency list"
	_apply_font(title)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1))
	_adj_panel.add_child(title)

	for city: Dictionary in _cities:
		var nb_labels: Array = (city["neighbors"] as Array).map(
			func(n): return (_city_by_id[n]["label"] as String) if n in _city_by_id else "?"
		)
		var lbl := Label.new()
		lbl.text = "%s → [%s]" % [city["label"], ", ".join(nb_labels)]
		_apply_font(lbl)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", COL_WHITE)
		_adj_panel.add_child(lbl)

# ─────────────────────────────────────────────────────────────────────────────
#  DIJKSTRA DISTANCE TABLE  (teaching widget)
# ─────────────────────────────────────────────────────────────────────────────
func _init_dist_table() -> void:
	_dist_table.clear()
	for city: Dictionary in _cities:
		_dist_table[city["id"]] = INF
	if _src_id >= 0:
		_dist_table[_src_id] = 0.0

func _refresh_dist_panel() -> void:
	for c in _dist_panel.get_children(): c.queue_free()

	var title := Label.new()
	title.text = "Distance table"
	_apply_font(title)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.7, 0.9, 1))
	_dist_panel.add_child(title)

	for city: Dictionary in _cities:
		var cid := city["id"] as int
		var d: float = _dist_table.get(cid, INF)
		var ds  := "∞" if d == INF else str(int(d))
		var col := Color(0.4, 1, 0.6) if cid in _selected_path else COL_WHITE
		var lbl := Label.new()
		lbl.text = "%s: %s" % [city["label"], ds]
		_apply_font(lbl)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", col)
		_dist_panel.add_child(lbl)

func _relax_from(node_id: int) -> void:
	# Update dist_table from node_id's known cost — for teaching display only.
	var base: float = _dist_table.get(node_id, INF)
	if base == INF: return
	for e: Dictionary in _edges:
		var nb := -1
		if e["a"] == node_id:   nb = e["b"]
		elif e["b"] == node_id: nb = e["a"]
		if nb < 0: continue
		var alt: float = base + float(e["weight"])
		if alt < (_dist_table.get(nb, INF) as float):
			_dist_table[nb] = alt
	_refresh_dist_panel()

# ─────────────────────────────────────────────────────────────────────────────
#  PROCESS
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _alive: return
	if _combo > 0:
		_combo_decay -= delta
		if _combo_decay <= 0.0:
			_combo = 0
			_combo_lbl.text = ""
	if _edge_src_id >= 0 and _live_edge != null:
		_update_snap_glow(get_viewport().get_mouse_position())

	# Sync CanvasLayer city labels to follow their sprite world positions
	for cid: int in _city_labels:
		var lbl_node := _city_labels[cid] as Label
		if not is_instance_valid(lbl_node): continue
		if cid >= _cities.size(): continue
		var sp := _cities[cid]["sprite"] as Node2D
		if not is_instance_valid(sp): continue
		# Convert world position to screen position for CanvasLayer
		var screen_pos := get_viewport().get_canvas_transform() * sp.global_position
		lbl_node.position = screen_pos + Vector2(-14, 52)

func _update_snap_glow(mouse_pos: Vector2) -> void:
	var best_d  := MAGNET_R
	var best_id := -1
	for c: Dictionary in _cities:
		if c["id"] == _edge_src_id: continue
		var nd := c["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var d := nd.global_position.distance_to(mouse_pos)
		if d < best_d: best_d = d; best_id = c["id"]

	if _snap_city_id >= 0 and _snap_city_id != best_id:
		var prev: Dictionary = _cities[_snap_city_id]
		(_cities[_snap_city_id]["sprite"] as Node2D).modulate = prev["color"] as Color
	_snap_city_id = best_id
	if best_id >= 0:
		(_cities[best_id]["sprite"] as Node2D).modulate = SNAP_COL
		if best_d < SNAP_DIST and _live_edge != null:
			_live_edge.set_point_position(
				1, (_cities[best_id]["sprite"] as Node2D).global_position
			)

# ─────────────────────────────────────────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	# Intro overlay swallows all input until dismissed
	if _intro_visible:
		return  # buttons handle navigation; block all game input

	if not _alive: return

	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: _on_down(e.position)
			else:         _on_up(e.position)
	elif event is InputEventMouseMotion:
		if _edge_src_id >= 0 and _live_edge != null:
			_live_edge.set_point_position(1, event.position)
		elif _drag_city_id >= 0:
			var c: Dictionary = _cities[_drag_city_id]
			(_cities[_drag_city_id]["sprite"] as Node2D).global_position = \
				event.position + _drag_offset
			c["pos"] = event.position + _drag_offset
			_redraw_edges()

func _on_down(pos: Vector2) -> void:
	var hit := _city_at(pos)
	if hit < 0: return
	match _p["mode"]:
		"connect":
			_edge_src_id = hit
			_live_edge.clear_points()
			_live_edge.add_point(_cities[hit]["pos"])
			_live_edge.add_point(pos)
			_live_edge.visible = true
		"observe":  _on_observe_click(hit)
		"path":     _on_path_click(hit)
		"dijkstra": _on_dijkstra_click(hit)
		"bfs_dfs":  _on_bfs_click(hit)
		_:
			_drag_city_id = hit
			_drag_offset  = (_cities[hit]["sprite"] as Node2D).global_position - pos
			(_cities[hit]["sprite"] as Node2D).z_index = 30

func _on_up(pos: Vector2) -> void:
	if _edge_src_id >= 0:
		_live_edge.visible = false
		var dst := _snap_city_id if _snap_city_id >= 0 else _city_at(pos)
		if _snap_city_id >= 0:
			(_cities[_snap_city_id]["sprite"] as Node2D).modulate = \
				_cities[_snap_city_id]["color"]
			_snap_city_id = -1
		if dst >= 0 and dst != _edge_src_id and not _edge_exists(_edge_src_id, dst):
			_add_edge(_edge_src_id, dst)
			if _p["weighted"]: _draw_weight_labels()
			_build_adj_panel()
			_apply_correct(_cities[_edge_src_id]["sprite"] as Node2D, 20)
			_check_connected()
		elif dst == _edge_src_id:
			pass  # self-loop: silent ignore
		else:
			_apply_wrong(
				_cities[_edge_src_id]["sprite"] as Node2D, 0,
				"Those cities are already connected!\nEach pair of cities can only\nhave one direct road between them."
			)
		_edge_src_id = -1
		return

	if _drag_city_id >= 0:
		(_cities[_drag_city_id]["sprite"] as Node2D).z_index = 10
		_drag_city_id = -1

func _city_at(pos: Vector2) -> int:
	for c: Dictionary in _cities:
		var nd := c["sprite"] as Node2D
		if is_instance_valid(nd) and nd.global_position.distance_to(pos) < CITY_HIT:
			return c["id"]
	return -1

# ─────────────────────────────────────────────────────────────────────────────
#  OBSERVE MODE  (tier 0 — what is a graph?)
# ─────────────────────────────────────────────────────────────────────────────
func _on_observe_click(id: int) -> void:
	# Reset all cities to their base color and stop any active glow tweens
	for c: Dictionary in _cities:
		_stop_glow(c["id"] as int)
		(c["sprite"] as Node2D).modulate = Color.WHITE
	# Highlight clicked city in gold
	(_cities[id]["sprite"] as Node2D).modulate = PATH_COLOR
	# Start pulsing glow on all adjacent neighbors
	for nb: int in _cities[id]["neighbors"]:
		_start_glow(nb)
	_task_lbl.text = "%s connects to: %s" % [
		_cities[id]["label"],
		", ".join((_cities[id]["neighbors"] as Array).map(func(n): return (_city_by_id[n]["label"] as String) if n in _city_by_id else "?"))
	]
	# Award points for each new city discovered
	if not id in _observe_clicked:
		_observe_clicked.append(id)
		_apply_correct(_cities[id]["sprite"] as Node2D, 10)
	if _observe_clicked.size() >= _cities.size():
		# Completion bonus
		_score += 50
		_score_lbl.text = "Score: %d" % _score
		_play_completion()

# ─────────────────────────────────────────────────────────────────────────────
#  CONNECT MODE
# ─────────────────────────────────────────────────────────────────────────────
func _check_connected() -> bool:
	if _cities.is_empty(): return true
	var components := _count_components()
	if components == 1:
		_task_lbl.text = "✓ All %d cities connected!\nYou built a Spanning Tree — %d edges for %d nodes." % [
			_cities.size(), _edges.size(), _cities.size(),
		]
		# Completion bonus based on remaining lives
		var bonus := _lives * 30
		_score += bonus
		_score_lbl.text = "Score: %d  (+%d bonus)" % [_score, bonus]
		_play_completion()
		return true
	_task_lbl.text = "Connect all cities! (%d separate groups remain)" % components
	return false

func _count_components() -> int:
	var visited: Dictionary = {}
	var count := 0
	for c: Dictionary in _cities:
		if c["id"] in visited: continue
		count += 1
		var q: Array = [c["id"]]
		while not q.is_empty():
			var cur: int = q.pop_front()
			if cur in visited: continue
			visited[cur] = true
			for nb: int in _cities[cur]["neighbors"]: q.append(nb)
	return count

# ─────────────────────────────────────────────────────────────────────────────
#  PATH MODE
# ─────────────────────────────────────────────────────────────────────────────
func _on_path_click(id: int) -> void:
	if _selected_path.is_empty():
		_selected_path.append(id)
		(_cities[id]["sprite"] as Node2D).modulate = PATH_COLOR
		_task_lbl.text = "Start at %s — now click a destination city." % _cities[id]["label"]
		# Glow adjacent cities so player can see valid next steps
		_stop_all_glows()
		for nb: int in _cities[id]["neighbors"]:
			_start_glow(nb)
		return

	var last: int = _selected_path.back()
	if not _are_neighbors(last, id):
		_stat["non_neighbor"] += 1
		_apply_wrong(
			_cities[id]["sprite"] as Node2D, _p["penalty"],
			"No direct road between %s and %s!\nIn a graph you can only travel\nalong edges that exist." % [
				_cities[last]["label"], _cities[id]["label"],
			]
		)
		return

	_stop_all_glows()
	_selected_path.append(id)
	(_cities[id]["sprite"] as Node2D).modulate = PATH_COLOR
	_draw_path_edge(_selected_path[_selected_path.size() - 2], id)
	_task_lbl.text = "Path so far: %s  (%d hops)" % [
		_path_label(_selected_path), _selected_path.size() - 1,
	]
	# Glow next valid neighbors (excluding already visited)
	for nb: int in _cities[id]["neighbors"]:
		if nb not in _selected_path:
			_start_glow(nb)

	if id != _selected_path[0]:
		for cid: int in _selected_path:
			_apply_correct(_cities[cid]["sprite"] as Node2D, 15)
		# Length bonus — shorter paths score more
		var length_bonus: int = max(0, (8 - _selected_path.size()) * 20)
		_score += length_bonus
		_score_lbl.text = "Score: %d" % _score
		_task_lbl.text = "✓ Path found: %s" % _path_label(_selected_path)
		_stop_all_glows()
		_play_completion()

# ─────────────────────────────────────────────────────────────────────────────
#  DIJKSTRA MODE
# ─────────────────────────────────────────────────────────────────────────────
func _on_dijkstra_click(id: int) -> void:
	if _selected_path.is_empty():
		if id != _src_id:
			_apply_wrong(
				_cities[id]["sprite"] as Node2D, 0,
				"Dijkstra starts at %s (green)!\nClick the START city first." % _cities[_src_id]["label"]
			)
			return
		_selected_path.append(id)
		(_cities[id]["sprite"] as Node2D).modulate = PATH_COLOR
		_running_cost = 0.0
		_relax_from(id)
		_update_cost_label()
		_task_lbl.text = "Good — now click the next city on your path to %s." % \
			_cities[_dst_id]["label"]
		# Glow adjacent neighbors so player can see valid next steps
		_stop_all_glows()
		for nb: int in _cities[id]["neighbors"]:
			if nb not in _selected_path:
				_start_glow(nb)
		return

	var last: int = _selected_path.back()
	if id in _selected_path:
		_apply_wrong(_cities[id]["sprite"] as Node2D, 0,
			"City %s is already on your path!" % _cities[id]["label"])
		return

	if not _are_neighbors(last, id):
		_stat["non_neighbor"] += 1
		_apply_wrong(
			_cities[id]["sprite"] as Node2D, _p["penalty"],
			"Cities %s and %s have no direct road!\nDijkstra follows existing edges only." % [
				_cities[last]["label"], _cities[id]["label"],
			]
		)
		return

	var w := _edge_weight(last, id)
	_running_cost += w
	_selected_path.append(id)
	(_cities[id]["sprite"] as Node2D).modulate = PATH_COLOR
	_draw_path_edge(last, id)
	_relax_from(id)
	_update_cost_label()
	_task_lbl.text = "Cost so far: %d — keep building toward %s." % [
		int(_running_cost), _cities[_dst_id]["label"],
	]
	# Glow valid next neighbors
	_stop_all_glows()
	for nb: int in _cities[id]["neighbors"]:
		if nb not in _selected_path:
			_start_glow(nb)

	if id == _dst_id:
		var optimal := _dijkstra_cost(_src_id, _dst_id)
		if _running_cost <= optimal + 0.01:
			for cid: int in _selected_path:
				_apply_correct(_cities[cid]["sprite"] as Node2D, 30)
			# Speed bonus — more time left = more points
			var speed_bonus := int(_time_left) * 2 if _p["time_limit"] > 0 else 50
			_score += speed_bonus
			_score_lbl.text = "Score: %d  (+%d speed bonus)" % [_score, speed_bonus]
			_task_lbl.text = "✓ Optimal path!  Total cost: %d" % int(_running_cost)
			_play_completion()
		else:
			_stat["wrong_cost"] += 1
			for cid: int in _selected_path:
				_apply_wrong(_cities[cid]["sprite"] as Node2D, _p["penalty"], "")
			_task_lbl.text = (
				"Not the cheapest path!\nYour cost: %d  |  Optimal: %d\n" +
				"Dijkstra always picks the minimum-cost next step."
			) % [int(_running_cost), int(optimal)]
			await get_tree().create_timer(1.8).timeout
			_reset_path()

func _update_cost_label() -> void:
	_cost_lbl.text = "Running cost: %d" % int(_running_cost)

# ─────────────────────────────────────────────────────────────────────────────
#  BFS MODE  (with live FIFO queue display)
# ─────────────────────────────────────────────────────────────────────────────
func _start_bfs_auto() -> void:
	# Auto-pick a random start so the player goes straight into ordering
	var start_id := randi() % _cities.size()
	_bfs_order = _compute_bfs(start_id)
	_selected_path.clear()
	_selected_path.append(start_id)
	(_cities[start_id]["sprite"] as Node2D).modulate = PATH_COLOR
	_bfs_display.visible = true
	_update_bfs_display()
	_task_lbl.text = "BFS starts at %s — click cities in correct BFS order." % \
		_cities[start_id]["label"]
	if _bfs_order.size() > 1: _highlight_bfs_expected()

func _on_bfs_click(id: int) -> void:
	if _bfs_order.is_empty(): return  # not started yet — handled by _start_bfs_auto

	var step := _selected_path.size()
	if step >= _bfs_order.size(): return

	# Only cities that appear in the remaining _bfs_order are reachable.
	# Anything not in _bfs_order is either visited or unreachable from start.
	var remaining_set: Array = _bfs_order.slice(step)
	if id not in remaining_set:
		_apply_wrong(
			_cities[id]["sprite"] as Node2D, 0,
			"City %s is not reachable yet!
BFS can only visit cities connected
to already-visited cities." % [
				_cities[id]["label"],
			]
		)
		return

	var expected: int = _bfs_order[step]
	if id == expected:
		_selected_path.append(id)
		(_cities[id]["sprite"] as Node2D).modulate = PATH_COLOR
		_apply_correct(_cities[id]["sprite"] as Node2D, 15)
		_mark_bfs_visited(id)
		_clear_bfs_hint()
		_update_bfs_display()
		if _selected_path.size() < _bfs_order.size():
			_highlight_bfs_expected()
			_task_lbl.text = "✓ Correct!  Next: city %s" % \
				_cities[_bfs_order[_selected_path.size()]]["label"]
		else:
			_bfs_display.visible = false
			# Perfect BFS bonus
			var bfs_bonus := _lives * 25
			_score += bfs_bonus
			_score_lbl.text = "Score: %d  (+%d bonus)" % [_score, bfs_bonus]
			_task_lbl.text = "✓ BFS complete!  All %d cities visited in order." % \
				_bfs_order.size()
			_play_completion()
	else:
		_stat["wrong_order"] += 1
		_apply_wrong(
			_cities[id]["sprite"] as Node2D, _p["penalty"],
			"Wrong BFS order!\nBFS visits the NEAREST unvisited cities first\n(level by level, using a queue).\nExpected: %s,  you clicked: %s." % [
				_cities[expected]["label"], _cities[id]["label"],
			]
		)


func _mark_bfs_visited(id: int) -> void:
	# Add a persistent ✓ label above the city sprite so player always sees done cities
	var nd := _cities[id]["sprite"] as Node2D
	if not is_instance_valid(nd): return
	# Remove any existing visited marker first
	for child in nd.get_children():
		if child.has_meta("bfs_visited_marker"):
			child.queue_free()
	var lbl := Label.new()
	lbl.text = "✓"
	lbl.set_meta("bfs_visited_marker", true)
	_apply_font(lbl)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4))
	lbl.position = Vector2(8, -58)
	nd.add_child(lbl)

func _update_bfs_display() -> void:
	for c in _bfs_display.get_children(): c.queue_free()

	# Show visited cities first
	var vtitle := Label.new()
	vtitle.text = "Visited ✓"
	_apply_font(vtitle)
	vtitle.add_theme_font_size_override("font_size", 16)
	vtitle.add_theme_color_override("font_color", Color(0.5, 0.9, 0.5))
	_bfs_display.add_child(vtitle)
	for cid: int in _selected_path:
		var vlbl := Label.new()
		vlbl.text = "  ✓ %s" % _cities[cid]["label"]
		_apply_font(vlbl)
		vlbl.add_theme_font_size_override("font_size", 14)
		vlbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_bfs_display.add_child(vlbl)

	var title := Label.new()
	title.text = "Queue (next →)"
	_apply_font(title)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.7, 0.7, 1))
	_bfs_display.add_child(title)

	# Show the remaining steps from _bfs_order so the queue
	# always matches exactly what the game expects next.
	var step := _selected_path.size()
	var remaining := _bfs_order.slice(step)

	if remaining.is_empty():
		var emp := Label.new()
		emp.text = "  (empty)"
		_apply_font(emp)
		emp.add_theme_font_size_override("font_size", 16)
		emp.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		_bfs_display.add_child(emp)
		return

	for i in range(remaining.size()):
		var cid: int = remaining[i]
		var lbl := Label.new()
		var prefix := "→ " if i == 0 else "  "
		lbl.text = "%s[%d] %s" % [prefix, i, _cities[cid]["label"]]
		_apply_font(lbl)
		lbl.add_theme_font_size_override("font_size", 16)
		var col := BFS_NEXT_COL if i == 0 else COL_WHITE
		lbl.add_theme_color_override("font_color", col)
		_bfs_display.add_child(lbl)

func _highlight_bfs_expected() -> void:
	var step := _selected_path.size()
	if step >= _bfs_order.size(): return
	# Glow all currently-valid BFS candidates (same level as expected next)
	var nxt: int = _bfs_order[step]
	_stop_all_glows()
	_start_glow(nxt)
	# Also glow any other same-level candidates for fairness
	for i in range(step + 1, _bfs_order.size()):
		var cid: int = _bfs_order[i]
		if _are_neighbors_of_any(_selected_path, cid):
			_start_glow(cid)

func _are_neighbors_of_any(visited: Array, cid: int) -> bool:
	for vid: int in visited:
		if _are_neighbors(vid, cid):
			return true
	return false

func _clear_bfs_hint() -> void:
	_stop_all_glows()
	for c: Dictionary in _cities:
		if c["id"] not in _selected_path:
			(c["sprite"] as Node2D).modulate = c["color"]

func _compute_bfs(start: int) -> Array:
	var visited: Dictionary = {}
	var q: Array = [start]
	var order: Array = []
	while not q.is_empty():
		var cur: int = q.pop_front()
		if cur in visited: continue
		visited[cur] = true
		order.append(cur)
		var nb: Array = ((_city_by_id[cur]["neighbors"] if cur in _city_by_id else []) as Array).duplicate()
		nb.sort()
		for n: int in nb:
			if n not in visited: q.append(n)
	return order

# ─────────────────────────────────────────────────────────────────────────────
#  PATH HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _draw_path_edge(a: int, b: int) -> void:
	var pa := _cities[a]["pos"] as Vector2
	var pb := _cities[b]["pos"] as Vector2
	var ln := Line2D.new()
	ln.default_color = PATH_EDGE
	ln.width   = 10.0
	ln.z_index = 5
	ln.add_point(pa)
	ln.add_point(pb)
	_path_layer.add_child(ln)
	_path_lines.append(ln)

func _reset_path() -> void:
	_stop_all_glows()
	for ln in _path_lines:
		if is_instance_valid(ln): (ln as Node2D).queue_free()
	_path_lines.clear()
	for c: Dictionary in _cities:
		(c["sprite"] as Node2D).modulate = c["color"]
	_selected_path.clear()
	_running_cost = 0.0
	_update_cost_label()
	_init_dist_table()
	_refresh_dist_panel()
	if _p["mode"] == "dijkstra": _mark_endpoints()
	_task_lbl.text = _goal_text()

func _path_label(path: Array) -> String:
	return " → ".join(path.map(func(i): return (_city_by_id[i]["label"] as String) if i in _city_by_id else "?"))

func _are_neighbors(a: int, b: int) -> bool:
	if a not in _city_by_id: return false
	return b in (_city_by_id[a]["neighbors"] as Array)

func _edge_weight(a: int, b: int) -> int:
	for e: Dictionary in _edges:
		if (e["a"] == a and e["b"] == b) or (e["a"] == b and e["b"] == a):
			return e["weight"]
	return 0

func _dijkstra_cost(s: int, t: int) -> float:
	var dist: Dictionary = {}
	for c: Dictionary in _cities: dist[c["id"]] = INF
	dist[s] = 0.0
	var unvis: Array = _cities.map(func(c): return c["id"])
	while not unvis.is_empty():
		unvis.sort_custom(func(a, b): return dist.get(a, INF) < dist.get(b, INF))
		var u: int = unvis.pop_front()
		if u == t: break
		for e: Dictionary in _edges:
			var nb := -1
			if   e["a"] == u: nb = e["b"]
			elif e["b"] == u: nb = e["a"]
			if nb < 0 or nb not in unvis: continue
			var alt: float = dist[u] + float(e["weight"])
			if alt < dist[nb]: dist[nb] = alt
	return dist.get(t, INF)

# ─────────────────────────────────────────────────────────────────────────────
#  DYNAMIC EDGES (Expert tier 4)
# ─────────────────────────────────────────────────────────────────────────────
func _mutate_one_edge() -> void:
	if _edges.is_empty(): return
	var idx := randi() % _edges.size()
	var removed: Dictionary = _edges[idx]
	(removed["line"] as Node2D).queue_free()
	_edges.remove_at(idx)
	var nb_ra: Array = _cities[removed["a"]]["neighbors"]
	var nb_rb: Array = _cities[removed["b"]]["neighbors"]
	nb_ra.erase(removed["b"])
	nb_rb.erase(removed["a"])
	_float_label(_cities[removed["a"]]["sprite"] as Node2D, "Road closed!", COL_WRONG)
	for _try in 30:
		var a := randi() % _cities.size()
		var b := randi() % _cities.size()
		if a != b and not _edge_exists(a, b):
			_add_edge(a, b)
			if _p["weighted"]: _draw_weight_labels()
			break
	_build_adj_panel()

func _redraw_edges() -> void:
	for e: Dictionary in _edges:
		var ln := e["line"] as Line2D
		if is_instance_valid(ln):
			ln.set_point_position(0, _cities[e["a"]]["pos"])
			ln.set_point_position(1, _cities[e["b"]]["pos"])

# ─────────────────────────────────────────────────────────────────────────────
#  COMPLETION
# ─────────────────────────────────────────────────────────────────────────────
func _play_completion() -> void:
	if not _alive: return
	_safe_sfx(PATH_SFX_WIN)

	# Screen flash
	var flash := ColorRect.new()
	flash.color   = Color(0.4, 1, 0.6, 0.0)
	flash.size    = Vector2(1280, 720)
	flash.z_index = 90
	add_child(flash)
	var ftw := flash.create_tween()
	ftw.tween_property(flash, "color:a", 0.5, 0.12)
	ftw.tween_property(flash, "color:a", 0.0, 0.5)
	ftw.tween_callback(flash.queue_free)

	# Banner pop-in
	_complete_banner.visible = true
	_complete_banner.text    = "PATH FOUND!"
	_complete_banner.scale   = Vector2(0.1, 0.1)
	_complete_banner.global_position = Vector2(380, 290)
	_complete_banner.create_tween() \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT) \
		.tween_property(_complete_banner, "scale", Vector2(1, 1), 0.4)

	if has_node("/root/PlayerProfile"):
		var s := _build_stats(true)
		PlayerProfile.save_chapter_result(_chapter_id, int(s["score"]), _grade_to_stars(_calc_grade(true)), float(s.get("accuracy", 0.0)))

	await get_tree().create_timer(2.5).timeout
	_end_game(true)

# ─────────────────────────────────────────────────────────────────────────────
#  GLOW PULSE  (adjacent-node animation on CanvasLayer — no green tint)
# ─────────────────────────────────────────────────────────────────────────────
# Pulsing colors: a warm amber-gold that fades in/out to give a clear magical glow.
const GLOW_COLOR_A := Color(1.00, 0.85, 0.20, 1.0)   # bright gold peak
const GLOW_COLOR_B := Color(0.55, 0.35, 0.05, 0.55)  # dim amber trough

func _start_glow(city_id: int) -> void:
	if city_id < 0 or city_id >= _cities.size(): return
	var nd := _cities[city_id]["sprite"] as Node2D
	if not is_instance_valid(nd): return
	# Kill any previous tween on this city
	_stop_glow(city_id)
	# Create a looping ping-pong tween on the modulate color
	var tw := nd.create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(nd, "modulate", GLOW_COLOR_A, 0.45)
	tw.tween_property(nd, "modulate", GLOW_COLOR_B, 0.45)
	_glow_tweens[city_id] = tw

func _stop_glow(city_id: int) -> void:
	if city_id in _glow_tweens:
		var tw = _glow_tweens[city_id]
		if tw != null and tw is Tween:
			tw.kill()
		_glow_tweens.erase(city_id)

func _stop_all_glows() -> void:
	for cid in _glow_tweens.keys():
		_stop_glow(cid)
	_glow_tweens.clear()

# ─────────────────────────────────────────────────────────────────────────────
#  FEEDBACK
# ─────────────────────────────────────────────────────────────────────────────
func _apply_correct(nd: Node2D, pts: int) -> void:
	_stat["correct"] += 1
	_combo += 1
	_combo_decay = COMBO_TTL
	var earned := pts * (1 + _combo / 5)
	_score += earned
	_score_lbl.text = "Score: %d" % _score
	_combo_lbl.text = "×%d COMBO!" % _combo if _combo > 1 else ""
	_acc_lbl.text   = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd):
		_flash(nd, COL_OK)
		_bounce(nd)
		_float_label(nd, "+%d" % earned, COL_OK)
	_safe_sfx(PATH_SFX_OK)
	_log("correct", earned)

func _apply_wrong(nd: Node2D, penalty: int, msg: String) -> void:
	_combo = 0
	_combo_lbl.text = ""
	if penalty > 0:
		_score = max(0, _score - penalty)
		_score_lbl.text = "Score: %d" % _score
	_acc_lbl.text = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd):
		_flash(nd, COL_WRONG)
		_shake(nd)
	if not msg.is_empty():
		_show_ctx(nd, msg)
	_lives -= 1
	_refresh_lives()
	if _lives <= 0: _end_game(false)
	_safe_sfx(PATH_SFX_FAIL)
	_log("wrong", -penalty)

func _show_ctx(nd: Node2D, text: String) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent()
	if not par: return
	var lbl := Label.new()
	lbl.text    = text
	lbl.z_index = 200
	_apply_font(lbl)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COL_WRONG)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	par.add_child(lbl)
	lbl.global_position = nd.global_position + Vector2(-60, -70)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -55), 1.3)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.3)
	tw.tween_callback(lbl.queue_free)

func _flash(nd: Node2D, c: Color) -> void:
	if not is_instance_valid(nd): return
	var restore := COL_WHITE
	if nd.has_meta("city_id"):
		var cid: int = nd.get_meta("city_id")
		if cid < _cities.size(): restore = _cities[cid]["color"] as Color
	var tw := nd.create_tween()
	tw.tween_property(nd, "modulate", c, 0.06)
	tw.tween_property(nd, "modulate", restore, 0.25)

func _bounce(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var s := nd.scale
	var tw := nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "scale", s * 1.4, 0.08)
	tw.tween_property(nd, "scale", s, 0.18)

func _shake(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var o  := nd.position
	var tw := nd.create_tween()
	for _i in range(6):
		tw.tween_property(nd, "position",
			o + Vector2(randf_range(-7, 7), randf_range(-4, 4)), 0.04)
	tw.tween_property(nd, "position", o, 0.04)

func _float_label(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent()
	if not par: return
	var lbl := Label.new()
	lbl.text    = text
	lbl.z_index = 200
	_apply_font(lbl)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	par.add_child(lbl)
	lbl.global_position = nd.global_position + Vector2(-28, -44)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -40), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  CLOCK / LIVES / ANALYTICS / END
# ─────────────────────────────────────────────────────────────────────────────
func _tick_clock() -> void:
	_time_left -= 1.0
	_timer_lbl.text = "⏱ %d" % max(0, int(_time_left))
	if _time_left <= 0.0: _end_game(false)

func _refresh_lives() -> void:
	for c in _lives_row.get_children(): c.queue_free()
	for i in range(3):
		var lbl := Label.new()
		lbl.text = "❤" if i < _lives else "🖤"
		lbl.add_theme_font_size_override("font_size", 26)
		_lives_row.add_child(lbl)

func _accuracy() -> float:
	var total: int = (
		int(_stat["correct"]) + int(_stat["wrong_order"]) +
		int(_stat["wrong_cost"]) + int(_stat["non_neighbor"])
	)
	return 100.0 if total == 0 else float(_stat["correct"]) / float(total) * 100.0

func _log(_action: String, _value: int) -> void:
	pass   # analytics stub — wire to your own system if needed

func _build_stats(success: bool) -> Dictionary:
	return {
		"score":         _score,
		"grade":         _calc_grade(success),
		"accuracy":      _accuracy(),
		"correct":       _stat["correct"],
		"wrong_order":   _stat["wrong_order"],
		"wrong_cost":    _stat["wrong_cost"],
		"non_neighbor":  _stat["non_neighbor"],
		"success":       success,
		"chapter":       _chapter_id,
	}

func _end_game(success: bool) -> void:
	if not _alive: return
	_alive = false
	_edge_timer.stop()
	_game_timer.stop()

	var grade   := _calc_grade(success)
	var summary := ""
	if success:
		summary = "✓ Grade: %s  |  Accuracy: %.0f%%  |  Score: %d" % [
			grade, _accuracy(), _score,
		]
	else:
		summary = "✗ Grade: %s\n%s" % [grade, _dominant_mistake()]

	_fail_summary.visible = true
	_fail_lbl.text        = summary

	if has_node("/root/PlayerProfile"):
		var s := _build_stats(success)
		PlayerProfile.save_chapter_result(_chapter_id, int(s["score"]), _grade_to_stars(grade), float(s.get("accuracy", 0.0)))

	await get_tree().create_timer(3.0).timeout

	# ── Route back through GameRouter ───────────────────────────────────────
	if has_node("/root/GameRouter"):
		GameRouter.chapter_complete(_chapter_id, _score, _grade_to_stars(grade))
	else:
		get_tree().change_scene_to_file("res://scenes/world_map/WorldMap.tscn")

func _calc_grade(success: bool) -> String:
	var acc := _accuracy()
	if not success: return "C" if acc >= 60.0 else "F"
	if acc >= 95.0: return "S"
	if acc >= 82.0: return "A"
	if acc >= 68.0: return "B"
	return "C"

func _dominant_mistake() -> String:
	var ranked := [
		["wrong_order", "You clicked cities in the wrong BFS order."],
		["wrong_cost",  "Your path was not the cheapest — Dijkstra finds minimum cost."],
		["non_neighbor","You tried to travel between cities with no direct road."],
	]
	var best     := "Keep practicing!"
	var best_cnt := 0
	for pair in ranked:
		var cnt: int = _stat[pair[0]]
		if cnt > best_cnt: best_cnt = cnt; best = pair[1]
	return best

func _grade_to_stars(grade: String) -> int:
	match grade:
		"S", "A": return 3
		"B":      return 2
		"C":      return 1
		_:        return 0
