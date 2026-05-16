# =============================================================================
# AlgoQuest — LinkedList Chapter (chapters 11-15)
# File: scripts/chapters/linked_list/LinkedListGame.gd
# v6 — interactability overhaul
#
# INTERACTABILITY CHANGES vs v5:
#   [INPUT]
#   + Cursor shape: default=arrow, hover car body=POINTING_HAND,
#                   hover port zone=CROSS, dragging body=DRAG, dragging arrow=CROSS
#   + Hover highlight: port dot brightens; car body gets a subtle rim on hover
#   + Port hit area enlarged: 44×44 px invisible touch-safe rect overlaid on port
#   + Click-to-select + click-to-connect fallback:
#       LMB on a car with NO drag → selects it (cyan ring);
#       LMB on a second car while one is selected → links them.
#       Works without any dragging — touch / mouse both.
#   + List-phase hook hit enlarged from 22 px to 44 px
#   + Right-click-to-unlink reminder shown on ALL tiers (small inline note)
#   + Floating "+N shifts" label rises from displaced cars in array tier
#   + Drag ghost: semi-transparent duplicate follows cursor while body-dragging
#
#   [FEEDBACK]
#   + _flash() now restores _node_base_color() instead of COL_WHITE
#   + Error messages rewritten: each explains what the *structure* requires,
#       not just what went wrong
#   + Array phase gets a persistent live "Shifts: N | Ops: M" ticker
#   + _mid_game_hint() fires on 2nd+ mistake — surfaces dominant-mistake
#       guidance mid-play, not only in the post-game summary
#   + Hint box stays visible on tiers 3-4 for unlink reminder (no longer
#       fully hidden — unlink line is always shown, concept hints are gated)
# =============================================================================

extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  ASSETS
# ─────────────────────────────────────────────────────────────────────────────
# PATH_BG replaced — background now uses 7-layer ParallaxBackground (see _setup_bg)
const PATH_FONT     := "res://assets/font/freepixel.ttf"
const PATH_SFX_LINK := "res://assets/audio/sfx/bubble.ogg"
const PATH_SFX_OK   := "res://assets/audio/sfx/success.ogg"
const PATH_SFX_FAIL := "res://assets/audio/sfx/fail.ogg"
const PATH_SFX_WIN  := "res://assets/audio/sfx/level_up.ogg"
const PATH_BGM      := "res://assets/audio/music/desert.ogg"
const PATH_BGM_TRAIN   := "res://assets/audio/music/the_rainbow_train.ogg"
const PATH_SFX_HOVER   := "res://assets/audio/sfx/001_Hover_01.wav"

const ICON_PATHS: Array[String] = [
	"res://assets/art/character/array.png",
	"res://assets/art/character/int.png",
	"res://assets/art/character/for.png",
	"res://assets/art/character/while.png",
	"res://assets/art/character/if.png",
	"res://assets/art/character/string.png",
	"res://assets/art/character/bool.png",
	"res://assets/art/character/double.png",
]

# ─────────────────────────────────────────────────────────────────────────────
#  LAYOUT
# ─────────────────────────────────────────────────────────────────────────────
const NODE_SCALE   := Vector2(0.60, 0.60)
const PORT_OFFSET  := Vector2(85.0, 0.0)
const PORT_HIT     := 70.0
const NODE_HIT     := 80.0
const SNAP_R       := 160.0
const MAGNET_R     := 220.0
const TRASH_R      := 50.0
const CANVAS       := Rect2(100, 130, 1080, 460)

# Array tier layout
const ARRAY_SLOT_W  := 90.0
const ARRAY_SLOT_H  := 70.0
const ARRAY_Y       := 320.0
const ARRAY_START_X := 200.0

const COL_ARROW    := Color(0.35, 0.9, 1.0)
const COL_LIVE     := Color(1.0, 1.0, 0.3, 0.7)
const COL_SNAP     := Color(0.3, 1.0, 0.9, 0.85)
const COL_GHOST    := Color(0.5, 0.5, 1.0, 0.35)
const COL_GAP      := Color(1.0, 0.8, 0.2, 0.6)
const COL_HEAD     := Color(1.0, 0.85, 0.1)
const COL_TAIL     := Color(0.5, 1.0, 0.5)
const COL_CYCLE    := Color(1.0, 0.2, 0.2)
const COL_STAGED   := Color(0.8, 0.5, 1.0)
const COL_WRONG    := Color(1.0, 0.15, 0.15)
const COL_OK       := Color(0.3, 1.0, 0.4)
const COL_WHITE    := Color.WHITE
# Train body tint — used for mid-chain cars (Coal/Logs).
# Pure white on dark sprites = invisible. This warm light colour
# reads as 'white train' against the dark city background.
const COL_TRAIN_MID := Color(0.85, 0.92, 1.0, 1.0)
const COL_HINT     := Color(0.7, 0.7, 1.0, 0.6)
const COL_COST     := Color(1.0, 0.45, 0.1)
const COL_CHEAP    := Color(0.2, 1.0, 0.6)
const COL_ARRAY_SLOT := Color(0.25, 0.25, 0.4, 0.9)
const COL_ARRAY_HL   := Color(1.0, 0.35, 0.35, 0.85)
# v6: hover / selection colours
const COL_HOVER_RIM  := Color(1.0, 1.0, 1.0, 0.55)
const COL_SELECTED   := Color(0.2, 0.85, 1.0, 1.0)   # cyan ring = selected node

# ─────────────────────────────────────────────────────────────────────────────
#  TIER PARAMS
# ─────────────────────────────────────────────────────────────────────────────
const TIER_PARAMS: Array[Dictionary] = [
	{"concept":"ARRAY_FEEL", "node_count":5, "insert":false, "delete":false,
	 "reverse":false, "cycle_inject":false, "penalty":0,
	 "time_limit":0.0, "target_links":0, "accuracy_target":0.0, "hints":true},
	{"concept":"CONNECT",  "node_count":4, "insert":false, "delete":false,
	 "reverse":false, "cycle_inject":false, "penalty":0,
	 "time_limit":0.0, "target_links":3, "accuracy_target":0.0, "hints":true},
	{"concept":"INSERT",   "node_count":4, "insert":true,  "delete":false,
	 "reverse":false, "cycle_inject":false, "penalty":10,
	 "time_limit":0.0, "target_links":4, "accuracy_target":60.0, "hints":true},
	{"concept":"REVERSE",  "node_count":5, "insert":false, "delete":false,
	 "reverse":true,  "cycle_inject":false, "penalty":25,
	 "time_limit":90.0, "target_links":4, "accuracy_target":70.0, "hints":false},
	{"concept":"CYCLE",    "node_count":6, "insert":false, "delete":false,
	 "reverse":false, "cycle_inject":true,  "penalty":40,
	 "time_limit":75.0, "target_links":5, "accuracy_target":75.0, "hints":false},
]

# ─────────────────────────────────────────────────────────────────────────────
#  NODE REFS
# ─────────────────────────────────────────────────────────────────────────────
@onready var _bg:              Sprite2D       = $Background
@onready var _node_layer:      Node2D         = $NodeLayer
@onready var _arrow_layer:     Node2D         = $ArrowLayer
@onready var _ghost_layer:     Node2D         = $GhostLayer
@onready var _gap_layer:       Node2D         = $GapLayer
@onready var _array_layer:     Node2D         = $ArrayLayer
@onready var _cycle_hl:        Node2D         = $CycleHighlight
@onready var _trash_zone:      Node2D         = $TrashZone
@onready var _insert_tray:     Node2D         = $InsertTray
@onready var _null_marker:     Label          = $NullMarker
@onready var _complete_banner: Label          = $CompleteBanner
@onready var _game_tmr:        Timer          = $GameTimer
@onready var _cycle_dot_tmr:   Timer          = $CycleDotTimer
@onready var _traverse_tmr:    Timer          = $TraverseTimer
@onready var _score_lbl:       Label          = $HUD/ScoreLabel
@onready var _combo_lbl:       Label          = $HUD/ComboLabel
@onready var _timer_lbl:       Label          = $HUD/TimerLabel
@onready var _goal_lbl:        Label          = $HUD/GoalLabel
@onready var _acc_lbl:         Label          = $HUD/AccuracyLabel
@onready var _lives_row:       HBoxContainer  = $HUD/LivesRow
@onready var _hint_lbl:        Label          = $HUD/HintBox/HintLabel
@onready var _hint_box:        PanelContainer = $HUD/HintBox
@onready var _task_lbl:        Label          = $HUD/TaskLabel
@onready var _struct_lbl:      Label          = $HUD/StructureLabel
@onready var _cost_banner:     Label          = $HUD/CostBanner
@onready var _replay_btn:      Button         = $HUD/ReplayBtn
@onready var _fail_summary:    PanelContainer = $HUD/FailSummary
@onready var _fail_lbl:        Label          = $HUD/FailSummary/FailLabel

# ─────────────────────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────────────────────
var _p: Dictionary = {}
var _nodes: Array  = []
var _uid:   int    = 0

# Array tier state
var _array_slots:        Array  = []
var _array_items:        Array  = []
var _array_insert_idx:   int    = -1
var _array_delete_idx:   int    = -1
var _array_drag_item:    int    = -1
var _array_drag_off:     Vector2 = Vector2.ZERO
var _array_done:         bool   = false
var _instruction_panel:  PanelContainer = null
var _shift_count:        int   = 0
var _list_ops:           int   = 0
var _shift_label:        Label = null
var _list_ops_label:     Label = null
var _list_nodes_af:      Array = []
var _list_arrows_af:     Array = []
var _af_phase:           int     = 0
var _af_target:          Array   = []
var _af_selected:        int     = -1
var _af_drag_hook:       int     = -1
var _af_live_arrow:      Line2D  = null

# Reverse / insert task
var _original_order:  Array = []
var _insert_node_id:  int   = -1

# Drag: body
var _drag_id:     int    = -1
var _drag_offset: Vector2 = Vector2.ZERO
# v6: ghost node shown while dragging
var _drag_ghost:  Node2D = null

# Drag: arrow
var _arrow_src:   int    = -1
var _live_arrow:  Line2D = null
var _snap_target: int    = -1

# v6: click-to-select state (fallback for non-drag linking)
var _selected_id:    int    = -1   # node currently selected by single click
var _select_ring:    Node2D = null # visual ring drawn around selected node

# v6: hover tracking
var _hover_id:       int    = -1   # node under cursor

# Traversal replay
var _traverse_path:  Array = []
var _traverse_idx:   int   = 0
var _traverse_cursor: Label = null

# Cycle animation
var _cycle_dot:     Label = null
var _cycle_path:    Array = []
var _cycle_dot_idx: int   = 0

# Analytics
var _stat := {
	"correct":0, "bad_link":0, "wrong_reverse":0,
	"bad_insert":0, "structural_err":0, "cycle_missed":0,
	"array_shifts":0,
}

var _score:  int   = 0
var _combo:  int   = 0
var _lives:  int   = 3
var _combo_decay: float = 0.0
const COMBO_TTL := 3.0

var _time_left:   float = 0.0
var _alive:             bool  = false
var _complete:          bool  = false
var _parallax_bg: ParallaxBackground = null
var _panel_dragging:   bool    = false
var _panel_drag_off:   Vector2 = Vector2.ZERO
var _player_link_actions: int = 0   # gates reverse/structural validation
# Real chapter ID (11–15) derived from tier at _ready — used for all
# GameRouter and ProgressTracker calls so retry/next land on the correct level.
var _chapter_id:  int   = 11

var _pixel_font: Font = null

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font
	var tier: int = 0
	if has_node("/root/DifficultyManager"):
		tier = DifficultyManager.current_tier
	tier = clamp(tier, 0, TIER_PARAMS.size() - 1)
	_p          = TIER_PARAMS[tier]
	_chapter_id = 11 + tier   # chapters 11–15 map to tiers 0–4

	_setup_bg()
	_setup_hud()
	_setup_timer()

	_trash_zone.visible      = _p["delete"]
	_null_marker.visible     = false
	_cycle_hl.visible        = false
	_fail_summary.visible    = false
	_complete_banner.visible = false
	_cost_banner.visible     = false

	match _p["concept"]:
		"ARRAY_FEEL":
			_task_lbl.text   = ""
			_hint_box.visible = false
			_spawn_array_tier(false)
		_:
			_spawn_nodes(_p["node_count"])
			if _p["reverse"]:
				_prebuild_chain()
				_record_original_order()
				_draw_ghost_reversed_arrows()
				_task_lbl.text = "Reverse ALL links!\nFaint arrows show the target.\nRight-click any car to remove its link."
			elif _p["cycle_inject"] and _nodes.size() >= 4:
				_prebuild_chain()
				_inject_cycle()
				_task_lbl.text = "⚠ A cycle exists! Break it.\nRight-click any car to remove its link."
				_highlight_cycle_nodes()
				_start_cycle_dot_animation()
			elif _p["insert"]:
				_prebuild_chain()
				_spawn_insert_node()
				_set_task_by_concept()
			else:
				_set_task_by_concept()

	# Show paginated intro for every tier
	await _show_tier_intro()

	# v6: hint box always visible — shows unlink reminder on all tiers
	if _p["concept"] == "ARRAY_FEEL":
		_hint_box.visible = false
		AudioManager.play_bgm(PATH_BGM_TRAIN)
	else:
		_hint_box.visible = true
		_hint_lbl.text = _unlink_reminder_text()
		AudioManager.play_bgm(PATH_BGM)

	_alive = true

# ─────────────────────────────────────────────────────────────────────────────
#  v6: unlink reminder shown in hint box on all list tiers
# ─────────────────────────────────────────────────────────────────────────────
func _unlink_reminder_text() -> String:
	return "Right-click any car to remove its outgoing link.\nOr click a car to select it (cyan ring), then click another to connect."

# ─────────────────────────────────────────────────────────────────────────────
#  SETUP
# ─────────────────────────────────────────────────────────────────────────────
# Parallax layer paths — all PNGs live in res://assets/art/background/city/
const PATH_BG_SKY        := "res://assets/art/background/city/parallaxcitysky.png"
const PATH_BG_MTN2       := "res://assets/art/background/city/parallaxcitybackgroundmountain2.png"
const PATH_BG_MTN        := "res://assets/art/background/city/parallaxcitybackgroundmountain.png"
const PATH_BG_BUILDINGS  := "res://assets/art/background/city/parallaxcitybuildings.png"
const PATH_BG_WATER      := "res://assets/art/background/city/parallaxcitywater.png"
const PATH_BG_REFLECT    := "res://assets/art/background/city/parallaxcitywaterreflexion.png"
const PATH_BG_FRONT      := "res://assets/art/background/city/parallaxcityfront.png"

func _setup_bg() -> void:
	# Hide the legacy single-sprite background
	_bg.visible = false

	# Build a ParallaxBackground so all 7 city layers sit behind the game
	var pb := ParallaxBackground.new()
	pb.layer = -1   # CanvasLayer behind world (layer -1 renders behind layer 0)
	add_child(pb)
	move_child(pb, 0)   # behind everything
	_parallax_bg = pb

	# Layer definitions: [path, scale_x, scale_y, scroll_scale, offset_y]
	# scroll_scale: how fast the layer scrolls relative to camera (0 = fixed)
	# The city sprites are wide PNGs — scale them to fill 1280×720
	var layers: Array = [
		[PATH_BG_SKY,       1.0, 1.0, 0.0,  0.0],   # sky — fixed
		[PATH_BG_MTN2,      1.0, 1.0, 0.05, 0.0],   # far mountains
		[PATH_BG_MTN,       1.0, 1.0, 0.1,  0.0],   # near mountains
		[PATH_BG_BUILDINGS, 1.0, 1.0, 0.2,  0.0],   # city buildings
		[PATH_BG_WATER,     1.0, 1.0, 0.25, 0.0],   # water
		[PATH_BG_REFLECT,   1.0, 1.0, 0.25, 0.0],   # water reflection
		[PATH_BG_FRONT,     1.0, 1.0, 0.35, 0.0],   # foreground
	]

	for layer_def: Array in layers:
		var path: String     = layer_def[0]
		var sy: float        = layer_def[2]
		var offset_y: float  = layer_def[4]
		if not ResourceLoader.exists(path): continue
		var pl := ParallaxLayer.new()
		pl.motion_scale     = Vector2(layer_def[3], 0.0)
		pl.motion_mirroring = Vector2(1280, 0)   # seamless horizontal loop
		pb.add_child(pl)
		var spr := Sprite2D.new()
		spr.texture        = load(path)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Scale to COVER 1280×720 — use the larger of the two axes
		# so the image fills the screen with no gaps on either edge.
		var tex: Texture2D  = spr.texture
		var tw: float       = float(tex.get_width())
		var th: float       = float(tex.get_height())
		var scale_x: float  = 1280.0 / tw
		var scale_y: float  = 720.0  / th
		var cover: float    = maxf(scale_x, scale_y)
		spr.scale           = Vector2(cover, cover)
		# Centre the sprite on screen; offset_y lets layers be nudged
		spr.position        = Vector2(640.0, 360.0 + offset_y)
		pl.add_child(spr)

# Applies a neon-themed pill background + glow colour to a HUD label.
func _style_hud_bar(lbl: Label, neon_col: Color) -> void:
	if not is_instance_valid(lbl): return
	var style := StyleBoxFlat.new()
	style.bg_color             = Color(0.03, 0.05, 0.10, 0.82)
	style.border_width_bottom  = 2
	style.border_color         = neon_col
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left   = 8
	style.content_margin_right  = 8
	style.content_margin_top    = 2
	style.content_margin_bottom = 2
	lbl.add_theme_stylebox_override("normal", style)
	lbl.add_theme_color_override("font_color", neon_col)

func _setup_hud() -> void:
	for lbl: Label in [_score_lbl, _combo_lbl, _timer_lbl, _goal_lbl,
						_acc_lbl, _hint_lbl, _task_lbl, _struct_lbl,
						_null_marker, _fail_lbl, _complete_banner, _cost_banner]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", _pixel_font)
			lbl.add_theme_font_size_override("font_size", 16)
	# ── Neon HUD styling ─────────────────────────────────────────
	_style_hud_bar(_score_lbl,  Color(0.0, 0.9, 1.0))   # cyan  — score
	_style_hud_bar(_goal_lbl,   Color(1.0, 0.85, 0.0))  # gold  — goal
	_style_hud_bar(_acc_lbl,    Color(0.3, 1.0, 0.5))   # green — accuracy
	_style_hud_bar(_struct_lbl, Color(0.5, 0.7, 1.0))   # blue  — structure
	_style_hud_bar(_timer_lbl,  Color(1.0, 0.4, 0.2))   # orange — timer

	if is_instance_valid(_task_lbl):
		_task_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD
		_task_lbl.custom_minimum_size = Vector2(900, 0)
		_task_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	if is_instance_valid(_hint_lbl):
		_hint_lbl.autowrap_mode       = TextServer.AUTOWRAP_WORD
		_hint_lbl.custom_minimum_size = Vector2(380, 0)

	_score_lbl.text  = "Score: 0"
	_combo_lbl.text  = ""
	_acc_lbl.text    = "Accuracy: -"
	_goal_lbl.text   = _goal_text()
	_timer_lbl.visible = _p["time_limit"] > 0
	if _p["time_limit"] > 0:
		_time_left = _p["time_limit"]
		_timer_lbl.text = "⏱ %d" % int(_time_left)
	_struct_lbl.text = "Structure: building..."

	_complete_banner.add_theme_font_size_override("font_size", 52)
	_complete_banner.add_theme_color_override("font_color", COL_HEAD)
	_complete_banner.z_index = 100

	_cost_banner.add_theme_font_size_override("font_size", 20)
	_cost_banner.z_index = 80

	if is_instance_valid(_replay_btn):
		_replay_btn.text    = "▶ Replay Traversal"
		_replay_btn.visible = false
		_replay_btn.pressed.connect(_start_traversal_replay)

	_refresh_lives()

func _goal_text() -> String:
	match _p["concept"]:
		"ARRAY_FEEL": return "Goal: sort the array, then chain the linked list"
		_:            return "Goal: valid linked list (%d links)" % _p["target_links"]

func _setup_timer() -> void:
	if _p["time_limit"] > 0:
		_game_tmr.wait_time = 1.0
		_game_tmr.one_shot  = false
		_game_tmr.timeout.connect(_tick_clock)
		_game_tmr.start()

func _set_task_by_concept() -> void:
	_insert_tray.visible = (_p["concept"] == "INSERT")
	match _p["concept"]:
		"CONNECT":
			# Task label is set AFTER the tutorial so it reflects step 4
			_task_lbl.text = ""
		"INSERT":
			_task_lbl.text = "Insert the PURPLE car into the chain between two others.\nStep 1: right-click the car BEFORE the gap to remove its link.\nStep 2: drag its ▶ to the purple car.  Step 3: drag purple's ▶ to the next car."
		"REVERSE":
			_task_lbl.text = "Reverse all links — head becomes tail.\nRight-click any car to remove its current link, then re-draw it backward."
		"CYCLE":
			_task_lbl.text = "⚠ A cycle exists! Break it to form a valid list.\nRight-click the car whose arrow loops back to remove the bad link."

# ─────────────────────────────────────────────────────────────────────────────
#  PER-TIER INTRO  — paginated slides shown before every tier starts.
#  Mirrors the GraphGame pattern: Back / Next / "Begin!" buttons, dark overlay,
#  game input blocked until player dismisses the last slide.
# ─────────────────────────────────────────────────────────────────────────────
const TIER_SLIDES: Dictionary = {
	"ARRAY_FEEL": [
		{
			"title": "Arrays vs Linked Lists",
			"title_col": COL_HEAD,
			"lines": [
				["", "An ARRAY stores items in fixed slots — like assigned seats on a train.", COL_WHITE],
				["", "To insert at position [1], every car from [1] onward must SHIFT one space.", COL_WRONG],
				["", "", COL_WHITE],
				["ARRAY",  "[0] [1] [2] [3] — order comes from physical position", COL_WRONG],
				["LIST",   "0x3A → 0xF7 → 0x11 → NULL — order comes from pointers", COL_CHEAP],
				["", "", COL_WHITE],
				["", "This level lets you feel the cost of shifting firsthand.", COL_OK],
			],
		},
		{
			"title": "Your Task",
			"title_col": COL_OK,
			"lines": [
				["PHASE 1", "Drag-sort the train cars into the TARGET ORDER shown above.", COL_OK],
				["", "Every swap displaces cars — that is the O(n) shift cost.", COL_WRONG],
				["", "", COL_WHITE],
				["PHASE 2", "Re-chain the same cars as a linked list using pointer arrows.", COL_CHEAP],
				["", "Inserting in a linked list costs 0 shifts — just two pointer changes.", COL_CHEAP],
				["", "", COL_WHITE],
				["", "Compare the shift counters after both phases — that is the lesson!", COL_HEAD],
			],
		},
	],
	"CONNECT": [
		{
			"title": "Step 1 — What is a Linked List?",
			"title_col": COL_HEAD,
			"lines": [
				["", "An array stores items side by side in memory — like assigned seats.", COL_WHITE],
				["", "A linked list is different.  Each car can sit ANYWHERE in memory.", COL_OK],
				["", "Order is created by POINTERS — each car remembers the address of the next.", COL_OK],
				["", "", COL_WHITE],
				["ARRAY", "[0] [1] [2] [3]  — slots are fixed, neighbours are physical", COL_WRONG],
				["LIST",  "0x3A → 0x11 → 0xF2 → NULL  — neighbours are pointers", COL_CHEAP],
				["", "", COL_WHITE],
				["", "This lets you insert or delete in O(1) time — just change a pointer.", COL_CHEAP],
			],
		},
		{
			"title": "Step 2 — Nodes and Pointers",
			"title_col": COL_HEAD,
			"lines": [
				["", "Each train car is a NODE.  Every node has two things:", COL_WHITE],
				["", "", COL_WHITE],
				["DATA",    "The cargo value stored inside the node  (the number on the car)", COL_OK],
				["POINTER", "The address of the NEXT node  (shown as an arrow between cars)", COL_ARROW],
				["", "", COL_WHITE],
				["", "The last node's pointer is NULL — it points to nothing.  That ends the list.", COL_TAIL],
				["", "The first node is called the HEAD.  It has no car pointing to it.", COL_HEAD],
				["", "", COL_WHITE],
				["", "In code:   node.next = &other_node      ← that is what the arrow represents.", COL_HINT],
			],
		},
		{
			"title": "Step 3 — How to Connect Two Cars",
			"title_col": COL_CHEAP,
			"lines": [
				["", "Each car has a cyan ▶ dot on its RIGHT side.  That dot IS the pointer.", COL_ARROW],
				["", "", COL_WHITE],
				["WAY 1", "DRAG the ▶ dot from one car and DROP it onto another car.", COL_OK],
				["WAY 2", "CLICK a car (cyan ring appears), then CLICK the car to link to.", COL_OK],
				["", "", COL_WHITE],
				["UNDO",  "RIGHT-CLICK any car to remove its outgoing pointer.", COL_COST],
				["", "", COL_WHITE],
				["", "Hover near a car while dragging — it glows cyan when close enough to snap.", COL_HINT],
			],
		},
		{
			"title": "Step 4 — Your Goal",
			"title_col": COL_OK,
			"lines": [
				["", "Connect ALL cars into ONE chain ending at NULL.", COL_WHITE],
				["", "", COL_WHITE],
				["RULE 1", "Every car must be reachable from the HEAD.", COL_OK],
				["RULE 2", "No car may be pointed to by more than ONE other car.", COL_OK],
				["RULE 3", "The last car's ▶ must reach the NULL marker on the right.", COL_OK],
				["", "", COL_WHITE],
				["", "The level completes automatically when all rules are satisfied!", COL_CHEAP],
			],
		},
	],
	"INSERT": [
		{
			"title": "Inserting into a Linked List",
			"title_col": COL_HEAD,
			"lines": [
				["", "In an array, inserting at position [1] forces every element after it to shift.", COL_WRONG],
				["", "That is O(n) time — slow for large arrays.", COL_WRONG],
				["", "", COL_WHITE],
				["", "In a linked list, insertion is only 3 pointer changes: O(1).", COL_CHEAP],
				["", "", COL_WHITE],
				["STEP 1", "Remove A's existing pointer  (right-click A)", COL_OK],
				["STEP 2", "Draw A's ▶ to the NEW node", COL_OK],
				["STEP 3", "Draw NEW node's ▶ to B", COL_OK],
			],
		},
		{
			"title": "Your Task",
			"title_col": COL_OK,
			"lines": [
				["", "A chain already exists.  A PURPLE car is waiting in the tray above.", COL_WHITE],
				["", "", COL_WHITE],
				["", "Insert the purple car BETWEEN two adjacent cars of your choice.", COL_OK],
				["", "Both connections (incoming and outgoing) are required for a valid chain.", COL_OK],
				["", "", COL_WHITE],
				["UNDO", "Right-click any car to remove its outgoing pointer.", COL_COST],
			],
		},
	],
	"REVERSE": [
		{
			"title": "Reversing a Linked List",
			"title_col": COL_HEAD,
			"lines": [
				["", "To reverse a list, every pointer must flip direction.", COL_WHITE],
				["", "", COL_WHITE],
				["BEFORE", "A → B → C → D → NULL", COL_WRONG],
				["AFTER",  "D → C → B → A → NULL", COL_CHEAP],
				["", "", COL_WHITE],
				["", "The old TAIL becomes the new HEAD.", COL_HEAD],
			],
		},
		{
			"title": "How to Reverse",
			"title_col": COL_OK,
			"lines": [
				["", "Faint ghost arrows show you the TARGET direction for each pointer.", COL_HINT],
				["", "", COL_WHITE],
				["STEP 1", "Right-click a car to remove its current outgoing link.", COL_OK],
				["STEP 2", "Drag the ▶ dot BACKWARD to the car that used to point here.", COL_OK],
				["STEP 3", "Repeat until every arrow matches its ghost.", COL_OK],
				["", "", COL_WHITE],
				["⏱", "Time limit applies — work quickly!", COL_COST],
			],
		},
	],
	"CYCLE": [
		{
			"title": "Cycles in a Linked List",
			"title_col": COL_WRONG,
			"lines": [
				["", "A valid linked list ends at NULL.", COL_WHITE],
				["", "A CYCLE happens when a node's pointer loops back to an earlier node.", COL_WRONG],
				["", "The traversal never terminates — this is a real and dangerous bug!", COL_WRONG],
				["", "", COL_WHITE],
				["", "The animated dot shows a traversal pointer circling endlessly.", COL_HINT],
				["", "Highlighted cars are inside the loop.", COL_HINT],
			],
		},
		{
			"title": "Your Task",
			"title_col": COL_OK,
			"lines": [
				["", "Find the car whose arrow creates the loop.", COL_WHITE],
				["", "", COL_WHITE],
				["STEP 1", "Right-click the offending car to remove its bad link.", COL_OK],
				["STEP 2", "Re-draw its ▶ to the correct next car (or NULL) to fix the chain.", COL_OK],
				["", "", COL_WHITE],
				["⏱", "Time limit applies — act fast!", COL_COST],
			],
		},
	],
}

func _show_tier_intro() -> void:
	var concept: String = _p["concept"]
	if concept not in TIER_SLIDES: return
	var slides: Array = TIER_SLIDES[concept]
	_alive = false

	for i in slides.size():
		var slide: Dictionary = slides[i]
		var is_last: bool = (i == slides.size() - 1)
		var btn_text: String = "Begin!" if is_last else "Next  →"
		# Re-use existing slide builder — just needs title/title_col/lines/btn keys
		var step: Dictionary = {
			"title":     slide["title"],
			"title_col": slide["title_col"],
			"lines":     slide["lines"],
			"btn":       btn_text,
		}
		await _show_tutorial_slide(step)

# ─────────────────────────────────────────────────────────────────────────────
#  CONNECT TIER — kept for compatibility; _show_tier_intro supersedes it
# ─────────────────────────────────────────────────────────────────────────────
func _show_contrast_intro() -> void:
	pass  # now handled by _show_tier_intro above


# Builds and shows one tutorial slide, waits for player to dismiss it.
func _show_tutorial_slide(step: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.z_index = 200
	panel.position = Vector2(120, 120)
	panel.custom_minimum_size = Vector2(1040, 0)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 7)
	panel.add_child(vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = step["title"]
	title_lbl.add_theme_font_override("font", _pixel_font)
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", step["title_col"])
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title_lbl)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Content rows
	for row: Array in (step["lines"] as Array):
		var tag_str: String  = row[0]
		var body_str: String = row[1]
		var col: Color       = row[2]

		if body_str.is_empty():
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 4)
			vbox.add_child(gap)
			continue

		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 16)
		vbox.add_child(hbox)

		if tag_str.is_empty():
			# Indent-only line — no tag column
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(88, 0)
			hbox.add_child(spacer)
		else:
			var tag := Label.new()
			tag.text = "[%s]" % tag_str
			tag.add_theme_font_override("font", _pixel_font)
			tag.add_theme_font_size_override("font_size", 13)
			tag.add_theme_color_override("font_color", col)
			tag.custom_minimum_size  = Vector2(88, 0)
			tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tag.autowrap_mode        = TextServer.AUTOWRAP_OFF
			hbox.add_child(tag)

		var body := Label.new()
		body.text = body_str
		body.add_theme_font_override("font", _pixel_font)
		body.add_theme_font_size_override("font_size", 14)
		body.add_theme_color_override("font_color", col)
		body.autowrap_mode       = TextServer.AUTOWRAP_WORD
		body.custom_minimum_size = Vector2(900, 0)
		hbox.add_child(body)

	# Dismiss button
	var btn := Button.new()
	btn.text = step["btn"]
	btn.add_theme_font_override("font", _pixel_font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(180, 38)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(btn)

	# Fade in
	panel.modulate = Color(1, 1, 1, 0)
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)

	# await the signal directly — lambda capture of a local bool does not
	# work in GDScript (primitives captured by value, not reference).
	await btn.pressed

	# Fade out
	var tw := panel.create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.25)
	await tw.finished
	panel.queue_free()

# ─────────────────────────────────────────────────────────────────────────────
#  ARRAY TIER
# ─────────────────────────────────────────────────────────────────────────────
const PATH_TRAIN_ENGINE  := "res://assets/art/train/Engine.png"
const PATH_TRAIN_COAL    := "res://assets/art/train/Coal.png"
const PATH_TRAIN_EMPTY   := "res://assets/art/train/Empty.png"
const PATH_TRAIN_CABOOSE := "res://assets/art/train/Caboose.png"
const PATH_TRAIN_LOGS    := "res://assets/art/train/Logs.png"

const TRAIN_SLOT_W  := 130.0
const TRAIN_SLOT_H  := 108.0
const TRAIN_Y       := 370.0
const TRAIN_START_X := 30.0
const TRAIN_GAP     := 8.0
const TRAIN_SCALE   := Vector2(0.60, 0.60)
const LIST_START_X  := 690.0
const LIST_Y        := 450.0
const LIST_NODE_GAP := 100.0

func _spawn_array_tier(_is_delete: bool) -> void:
	for c in _array_layer.get_children(): c.queue_free()
	_array_slots.clear()
	_array_items.clear()
	_list_nodes_af.clear()
	_list_arrows_af.clear()
	_shift_count  = 0
	_list_ops     = 0
	_af_phase     = 0
	_af_target.clear()
	_af_selected  = -1
	_af_drag_hook = -1
	_spawn_array_game(_p["node_count"])

const CAR_VALUES := [17, 31, 10, 24, 45]

func _spawn_array_game(count: int) -> void:
	var values: Array = CAR_VALUES.slice(0, count)
	values.shuffle()
	_af_target = values.duplicate()
	_af_target.sort()

	var total_w: float = (TRAIN_SLOT_W + TRAIN_GAP) * count - TRAIN_GAP
	var track := ColorRect.new()
	track.size     = Vector2(total_w + 20, 8)
	track.position = Vector2(TRAIN_START_X - 10, TRAIN_Y + TRAIN_SLOT_H - 6)
	track.color    = Color(0.35, 0.24, 0.1)
	track.z_index  = 0
	_array_layer.add_child(track)

	_draw_array_target_banner()

	for i in range(count):
		var sx: float = TRAIN_START_X + i * (TRAIN_SLOT_W + TRAIN_GAP)
		var cx: float = sx + TRAIN_SLOT_W * 0.5
		var cy: float = TRAIN_Y + TRAIN_SLOT_H * 0.5

		var slot_spr := Sprite2D.new()
		if ResourceLoader.exists(PATH_TRAIN_EMPTY):
			slot_spr.texture = load(PATH_TRAIN_EMPTY)
		slot_spr.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST
		slot_spr.scale           = TRAIN_SCALE
		slot_spr.z_index         = 1
		slot_spr.modulate        = COL_ARRAY_SLOT
		_array_layer.add_child(slot_spr)
		slot_spr.global_position = Vector2(cx, cy)

		var idx_lbl := Label.new()
		idx_lbl.text = "[%d]" % i
		idx_lbl.add_theme_font_override("font", _pixel_font)
		idx_lbl.add_theme_font_size_override("font_size", 11)
		idx_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.75))
		idx_lbl.position = Vector2(sx + TRAIN_SLOT_W * 0.5 - 10, TRAIN_Y + TRAIN_SLOT_H + 4)
		_array_layer.add_child(idx_lbl)

		_array_slots.append({
			"rect":    Rect2(sx, TRAIN_Y - 4, TRAIN_SLOT_W, TRAIN_SLOT_H + 8),
			"item_id": i,
			"bg":      slot_spr
		})

		var item := _make_train_item(i, PATH_TRAIN_COAL, str(values[i]), COL_WHITE,
			Vector2(cx, cy))
		item["value"] = values[i]
		_array_items.append(item)

	_shift_label = Label.new()
	_shift_label.add_theme_font_override("font", _pixel_font)
	_shift_label.add_theme_font_size_override("font_size", 14)
	_shift_label.add_theme_color_override("font_color", COL_COST)
	_shift_label.position = Vector2(TRAIN_START_X, TRAIN_Y + TRAIN_SLOT_H + 28)
	_shift_label.z_index  = 5
	_array_layer.add_child(_shift_label)
	_update_shift_label()

	_show_instruction_panel(
		"ARRAY — Sort the train cars into the target order",
		"DRAG cars to swap them into the correct slot order.\n"
		+ "Every car you displace counts as a SHIFT — that is the array's cost.",
		COL_OK)

func _draw_array_target_banner() -> void:
	var banner := PanelContainer.new()
	banner.position            = Vector2(TRAIN_START_X, 178)
	banner.custom_minimum_size = Vector2(500, 44)
	banner.z_index             = 10
	_array_layer.add_child(banner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	banner.add_child(hbox)

	var title := Label.new()
	title.text = "TARGET: "
	title.add_theme_font_override("font", _pixel_font)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", COL_HEAD)
	hbox.add_child(title)

	for v: int in _af_target:
		var lbl := Label.new()
		lbl.text = "[%d]" % v
		lbl.add_theme_font_override("font", _pixel_font)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", COL_WHITE)
		hbox.add_child(lbl)

func _show_cargo_tooltip(item: Dictionary, pos: Vector2) -> void:
	var tip := Label.new()
	tip.text = "Cargo: %d" % (item["value"] as int)
	tip.add_theme_font_override("font", _pixel_font)
	tip.add_theme_font_size_override("font_size", 14)
	tip.add_theme_color_override("font_color", COL_HEAD)
	tip.z_index = 100
	_array_layer.add_child(tip)
	tip.global_position = pos + Vector2(-20, -55)
	var tw := tip.create_tween()
	tw.tween_interval(1.2)
	tw.tween_property(tip, "modulate:a", 0.0, 0.4)
	tw.tween_callback(tip.queue_free)

func _check_array_sorted() -> bool:
	for i in range(_array_slots.size()):
		var item: Dictionary = _array_item_by_id(_array_slots[i]["item_id"])
		if item.is_empty(): return false
		if (item["value"] as int) != (_af_target[i] as int): return false
	return true

func _swap_array_cars(slot_a: int, slot_b: int) -> void:
	if slot_a == slot_b: return
	var displaced: int = abs(slot_b - slot_a) - 1
	var this_shift: int = 1 + displaced
	_shift_count += this_shift
	_stat["array_shifts"] += this_shift
	# Shifts are an EDUCATIONAL counter — they show the cost the array pays.
	# The player is not penalised for shifting; the comparison with the list
	# phase (0 shifts) is the lesson. Score is untouched here.
	_update_shift_label()

	var tmp: int = _array_slots[slot_a]["item_id"]
	_array_slots[slot_a]["item_id"] = _array_slots[slot_b]["item_id"]
	_array_slots[slot_b]["item_id"] = tmp

	for i in [slot_a, slot_b]:
		var item: Dictionary = _array_item_by_id(_array_slots[i]["item_id"])
		if item.is_empty(): continue
		var nd := item["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var tx: float = TRAIN_START_X + i * (TRAIN_SLOT_W + TRAIN_GAP) + TRAIN_SLOT_W * 0.5
		var ty: float = TRAIN_Y + TRAIN_SLOT_H * 0.5
		nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
			.tween_property(nd, "global_position", Vector2(tx, ty), 0.25)

	# Flash displaced intermediate cars orange
	var lo: int = min(slot_a, slot_b)
	var hi: int = max(slot_a, slot_b)
	for i in range(lo + 1, hi):
		var item: Dictionary = _array_item_by_id(_array_slots[i]["item_id"])
		if item.is_empty(): continue
		var nd := item["sprite"] as Node2D
		if is_instance_valid(nd): _pulse_node(nd, COL_COST)

	# v6: floating "+N shifts" label so the cost is visceral, not just numeric
	var mid_item: Dictionary = _array_item_by_id(_array_slots[slot_a]["item_id"])
	if not mid_item.is_empty():
		var nd := mid_item["sprite"] as Node2D
		if is_instance_valid(nd):
			_float_label(nd, "+%d shift%s" % [this_shift, "s" if this_shift > 1 else ""], COL_COST)

	AudioManager.play_sfx(PATH_SFX_HOVER)

	if _check_array_sorted():
		await get_tree().create_timer(0.4).timeout
		_finish_array_phase()

func _finish_array_phase() -> void:
	# Reward sorting completion — base 100 pts, bonus for fewer shifts
	var sort_bonus: int = max(0, 100 - _shift_count * 5)
	_score += sort_bonus
	_score_lbl.text = "Score: %d" % _score
	_clear_instruction_panel()
	_show_instruction_panel(
		"✓ Array sorted!  Shifts used: %d   Bonus earned: +%d" % [_shift_count, sort_bonus],
		"In an array, order comes from POSITION — slot [0], [1], [2]...\n"
		+ "Every swap forces neighbouring cars to move. That is the O(n) cost.\n"
		+ "Now try the LINKED LIST — same cars, zero shifts needed.",
		COL_CHEAP)
	_show_cost_banner("Array needed %d shifts to sort   ·   Linked list needed 0 shifts" % _shift_count, COL_CHEAP)
	await get_tree().create_timer(3.0).timeout
	_start_list_phase()

# ─────────────────────────────────────────────────────────────────────────────
#  LINKED LIST PHASE (ARRAY_FEEL tier, phase 1)
# ─────────────────────────────────────────────────────────────────────────────
func _start_list_phase() -> void:
	_af_phase = 1
	_cost_banner.visible = false
	_clear_instruction_panel()

	for c in _array_layer.get_children(): c.queue_free()
	_array_slots.clear()
	_list_arrows_af.clear()
	_af_drag_hook   = -1
	_af_live_arrow  = null
	_list_nodes_af.clear()

	# Fixed rail Y — all cars on the same horizontal track line
	const RAIL_Y_AF: float = 370.0
	var x_slots: Array[float] = [110.0, 280.0, 450.0, 620.0, 790.0, 960.0]
	x_slots.shuffle()
	var positions: Array[Vector2] = []
	for xv: float in x_slots:
		positions.append(Vector2(xv, RAIL_Y_AF))

	# Use the same _af_target values so comparison is honest
	var vals: Array = _af_target.duplicate()
	vals.shuffle()
	for i in range(vals.size()):
		var pos: Vector2 = positions[i] if i < positions.size() \
			else Vector2(100 + i * 180, 350)
		_spawn_list_car(i, vals[i], pos)

	var null_lbl := Label.new()
	null_lbl.text = "NULL"
	null_lbl.add_theme_font_override("font", _pixel_font)
	null_lbl.add_theme_font_size_override("font_size", 16)
	null_lbl.add_theme_color_override("font_color", COL_TAIL)
	null_lbl.position = Vector2(1080, 335)
	null_lbl.z_index  = 5
	_array_layer.add_child(null_lbl)
	_array_layer.set_meta("null_pos", Vector2(1100, 360))

	_draw_list_target_banner()

	_show_instruction_panel(
		"LINKED LIST — chain the cars in the target order",
		"DRAG the hook (▶) on the right of each car to another car or to NULL.\n"
		+ "No slots, no shifting — just pointer assignments.",
		COL_CHEAP)

func _spawn_list_car(uid: int, val: int, pos: Vector2) -> void:
	var spr := Sprite2D.new()
	var path := PATH_TRAIN_COAL if uid % 2 == 0 else PATH_TRAIN_LOGS
	if ResourceLoader.exists(path): spr.texture = load(path)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale    = TRAIN_SCALE
	spr.z_index  = 10
	spr.modulate = COL_TRAIN_MID
	_array_layer.add_child(spr)
	spr.global_position = pos

	var val_lbl := Label.new()
	val_lbl.text = str(val)
	val_lbl.add_theme_font_override("font", _pixel_font)
	val_lbl.add_theme_font_size_override("font_size", 36)
	val_lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	val_lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	val_lbl.add_theme_constant_override("shadow_offset_x", 2)
	val_lbl.add_theme_constant_override("shadow_offset_y", 2)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.custom_minimum_size  = Vector2(80, 0)
	val_lbl.position = Vector2(-40, -22)
	spr.add_child(val_lbl)

	# v6: enlarged hook hit area (44×44) for touch safety
	var hook := ColorRect.new()
	hook.size     = Vector2(44, 44)
	hook.position = Vector2(63, -22)
	hook.color    = Color(0, 0, 0, 0)   # invisible — hit area only
	hook.z_index  = 13
	spr.add_child(hook)

	# Visible hook dot (still 18×18 visually)
	var hook_vis := ColorRect.new()
	hook_vis.size     = Vector2(18, 18)
	hook_vis.position = Vector2(76, -9)
	hook_vis.color    = COL_ARROW
	hook_vis.z_index  = 11
	spr.add_child(hook_vis)

	var hook_lbl := Label.new()
	hook_lbl.text = "▶"
	hook_lbl.add_theme_font_size_override("font_size", 13)
	hook_lbl.add_theme_color_override("font_color", COL_WHITE)
	hook_lbl.position = Vector2(74, -11)
	spr.add_child(hook_lbl)

	_list_nodes_af.append({
		"id":      uid,
		"value":   val,
		"sprite":  spr,
		"next_id": -1,
		"arrow":   null
	})

func _draw_list_target_banner() -> void:
	var banner := PanelContainer.new()
	banner.position            = Vector2(200, 155)
	banner.custom_minimum_size = Vector2(700, 44)
	banner.z_index             = 10
	_array_layer.add_child(banner)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	banner.add_child(hbox)

	var title := Label.new()
	title.text = "TARGET ORDER: "
	title.add_theme_font_override("font", _pixel_font)
	title.add_theme_font_size_override("font_size", 15)
	title.add_theme_color_override("font_color", COL_HEAD)
	hbox.add_child(title)

	for i in range(_af_target.size()):
		var lbl := Label.new()
		var arrow := " → " if i < _af_target.size() - 1 else " → NULL"
		lbl.text = "%d%s" % [_af_target[i], arrow]
		lbl.add_theme_font_override("font", _pixel_font)
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", COL_WHITE)
		hbox.add_child(lbl)

func _list_node_af_by_id(id: int) -> Dictionary:
	for n: Dictionary in _list_nodes_af:
		if n["id"] == id: return n
	return {}

func _list_hook_world_pos(node: Dictionary) -> Vector2:
	var spr := node["sprite"] as Node2D
	if not is_instance_valid(spr): return Vector2.ZERO
	return spr.global_position + Vector2(85, 0)

func _list_node_at(pos: Vector2, exclude_id: int) -> int:
	for node: Dictionary in _list_nodes_af:
		if node["id"] == exclude_id: continue
		var spr := node["sprite"] as Node2D
		if not is_instance_valid(spr): continue
		if spr.global_position.distance_to(pos) < 48.0:
			return node["id"]
	return -1

func _list_draw_arrow_between(src: Dictionary, dst_pos: Vector2) -> Line2D:
	if src["arrow"] and is_instance_valid(src["arrow"] as Node2D):
		(src["arrow"] as Node2D).queue_free()
	var from := _list_hook_world_pos(src)
	var line := Line2D.new()
	line.default_color = COL_ARROW
	line.width  = 3.0
	line.z_index = 8
	line.add_point(from); line.add_point(dst_pos)
	var dir := (dst_pos - from).normalized()
	line.add_point(dst_pos - dir * 10 + dir.rotated(deg_to_rad(140)) * 8)
	line.add_point(dst_pos)
	line.add_point(dst_pos - dir * 10 + dir.rotated(deg_to_rad(-140)) * 8)
	_array_layer.add_child(line)
	return line

func _check_list_correct() -> bool:
	var start_id := -1
	for node: Dictionary in _list_nodes_af:
		if (node["value"] as int) == (_af_target[0] as int):
			start_id = node["id"]; break
	if start_id < 0: return false
	var visited: Dictionary = {}
	var cur_id := start_id
	var order: Array = []
	while cur_id >= 0 and cur_id not in visited:
		visited[cur_id] = true
		var nd := _list_node_af_by_id(cur_id)
		if nd.is_empty(): return false
		order.append(nd["value"] as int)
		var nxt: int = nd["next_id"]
		if nxt == -2: break
		cur_id = nxt
	if order.size() != _af_target.size(): return false
	for i in range(order.size()):
		if order[i] != (_af_target[i] as int): return false
	return true

func _finish_list_phase() -> void:
	_clear_instruction_panel()
	for node: Dictionary in _list_nodes_af:
		var spr := node["sprite"] as Node2D
		if is_instance_valid(spr): _flash_af(spr, COL_OK)
	# Reward list completion — bonus for using fewer pointer ops
	var list_bonus: int = 50 + _list_ops * 10
	_score += list_bonus
	_score_lbl.text = "Score: %d" % _score
	AudioManager.play_sfx(PATH_SFX_HOVER)
	_show_instruction_panel(
		"✓ Linked list complete!  Pointer ops: %d   Earned: +%d pts" % [_list_ops, list_bonus],
		"Array needed %d shifts.  Linked list needed 0 shifts — just %d pointer assignments.\n"
		+ "Same cars. Same order. Completely different cost." % [_shift_count, _list_ops],
		COL_HEAD)
	_show_cost_banner("Array: %d shifts    Linked List: 0 shifts" % _shift_count, COL_CHEAP)
	await get_tree().create_timer(3.5).timeout
	_array_done = true
	_check_array_completion()

func _flash_af(nd: Node2D, c: Color) -> void:
	if not is_instance_valid(nd): return
	nd.create_tween().tween_property(nd, "modulate", c, 0.06)
	nd.create_tween().tween_property(nd, "modulate", COL_WHITE, 0.28)

# ─────────────────────────────────────────────────────────────────────────────
#  ARRAY FEEL — SHARED HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _update_shift_label() -> void:
	if is_instance_valid(_shift_label):
		_shift_label.text = "Array shifts so far: %d  (each shift = the array moving a car)" % _shift_count

func _update_list_ops_label() -> void:
	if is_instance_valid(_list_ops_label):
		_list_ops_label.text = "Pointer changes: %d" % _list_ops

func _make_train_item(uid: int, sprite_path: String, label_text: String,
		color: Color, pos: Vector2) -> Dictionary:
	var sprite := Sprite2D.new()
	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
	else:
		var cr := ColorRect.new()
		cr.size = Vector2(40, 32); cr.position = Vector2(-20, -16)
		cr.color = Color(0.4, 0.4, 0.7)
		sprite.add_child(cr)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale    = TRAIN_SCALE
	sprite.z_index  = 10
	sprite.modulate = color if color != COL_WHITE else COL_TRAIN_MID
	_array_layer.add_child(sprite)
	sprite.global_position = pos
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size  = Vector2(80, 0)
	lbl.position = Vector2(-40, -22)
	sprite.add_child(lbl)
	return {"id": uid, "sprite": sprite, "slot_idx": -1,
			"addr": label_text, "sprite_path": sprite_path, "value": 0}

func _array_item_by_id(id: int) -> Dictionary:
	for item: Dictionary in _array_items:
		if item["id"] == id: return item
	return {}

# ─────────────────────────────────────────────────────────────────────────────
#  ARRAY TIER INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _array_on_lmb_down(pos: Vector2) -> void:
	if _af_phase == 0:
		for i in range(_array_slots.size()):
			var item: Dictionary = _array_item_by_id(_array_slots[i]["item_id"])
			if item.is_empty(): continue
			var nd := item["sprite"] as Node2D
			if not is_instance_valid(nd): continue
			if nd.global_position.distance_to(pos) < NODE_HIT:
				_array_drag_item = item["id"]
				_array_drag_off  = nd.global_position - pos
				nd.z_index = 30
				_af_selected = i
				# v6: ghost
				_spawn_drag_ghost_af(item)
				return
	else:
		# Hook detection with enlarged 44px radius
		for node: Dictionary in _list_nodes_af:
			var hook_pos := _list_hook_world_pos(node)
			if hook_pos.distance_to(pos) < 44.0:
				_af_drag_hook = node["id"]
				_af_live_arrow = Line2D.new()
				_af_live_arrow.default_color = COL_LIVE
				_af_live_arrow.width  = 2.5
				_af_live_arrow.z_index = 20
				_af_live_arrow.add_point(hook_pos)
				_af_live_arrow.add_point(pos)
				_array_layer.add_child(_af_live_arrow)
				return
		for node: Dictionary in _list_nodes_af:
			var spr := node["sprite"] as Node2D
			if not is_instance_valid(spr): continue
			if spr.global_position.distance_to(pos) < NODE_HIT:
				_array_drag_item = node["id"]
				_array_drag_off  = spr.global_position - pos
				spr.z_index = 30
				return

func _array_on_lmb_up(pos: Vector2) -> void:
	_destroy_drag_ghost()
	if _af_phase == 0:
		if _array_drag_item < 0: return
		var item := _array_item_by_id(_array_drag_item)
		if not item.is_empty():
			(item["sprite"] as Node2D).z_index = 10
		var dropped_slot := -1
		for i in range(_array_slots.size()):
			if _array_slots[i]["rect"].has_point(pos):
				dropped_slot = i; break
		if dropped_slot >= 0 and dropped_slot != _af_selected:
			await _swap_array_cars(_af_selected, dropped_slot)
		else:
			if not item.is_empty():
				var nd := item["sprite"] as Node2D
				if is_instance_valid(nd):
					var tx: float = TRAIN_START_X + _af_selected * (TRAIN_SLOT_W + TRAIN_GAP) + TRAIN_SLOT_W * 0.5
					nd.create_tween().tween_property(nd, "global_position:x", tx, 0.2)
		_array_drag_item = -1
		_af_selected     = -1
	else:
		if _af_drag_hook >= 0 and is_instance_valid(_af_live_arrow):
			_af_live_arrow.queue_free()
			_af_live_arrow = null
			var src := _list_node_af_by_id(_af_drag_hook)
			if src.is_empty(): _af_drag_hook = -1; return
			var null_pos: Vector2 = _array_layer.get_meta("null_pos") as Vector2
			if pos.distance_to(null_pos) < 55.0:
				src["next_id"] = -2
				src["arrow"] = _list_draw_arrow_between(src, null_pos)
				_list_ops += 1; _update_list_ops_label()
				_float_label(src["sprite"] as Node2D, "→ NULL", COL_TAIL)
			else:
				var target_id := _list_node_at(pos, _af_drag_hook)
				if target_id >= 0:
					src["next_id"] = target_id
					var dst := _list_node_af_by_id(target_id)
					src["arrow"] = _list_draw_arrow_between(src,
						(dst["sprite"] as Node2D).global_position)
					_list_ops += 1; _update_list_ops_label()
					_float_label(src["sprite"] as Node2D, "pointer set!", COL_CHEAP)
					AudioManager.play_sfx(PATH_SFX_HOVER)
			_af_drag_hook = -1
			if _check_list_correct():
				await get_tree().create_timer(0.3).timeout
				await _finish_list_phase()
			return
		if _array_drag_item >= 0:
			for node: Dictionary in _list_nodes_af:
				if node["id"] == _array_drag_item:
					(node["sprite"] as Node2D).z_index = 10; break
			_array_drag_item = -1

func _array_on_rmb_down(pos: Vector2) -> void:
	if _af_phase == 0:
		for i in range(_array_slots.size()):
			var item: Dictionary = _array_item_by_id(_array_slots[i]["item_id"])
			if item.is_empty(): continue
			var nd := item["sprite"] as Node2D
			if is_instance_valid(nd) and nd.global_position.distance_to(pos) < NODE_HIT:
				_show_cargo_tooltip(item, nd.global_position)
				return

# ─────────────────────────────────────────────────────────────────────────────
#  v6: DRAG GHOST helpers
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_drag_ghost_af(item: Dictionary) -> void:
	var original := item["sprite"] as Sprite2D
	if not is_instance_valid(original): return
	var ghost := Sprite2D.new()
	ghost.texture        = original.texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale          = original.scale
	ghost.modulate       = Color(1, 1, 1, 0.35)
	ghost.z_index        = 5
	_array_layer.add_child(ghost)
	ghost.global_position = original.global_position
	_drag_ghost = ghost

func _spawn_drag_ghost(data: Dictionary) -> void:
	var original := data["sprite"] as Sprite2D
	if not is_instance_valid(original): return
	var ghost := Sprite2D.new()
	ghost.texture        = original.texture
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.scale          = original.scale
	ghost.modulate       = Color(1, 1, 1, 0.35)
	ghost.z_index        = 5
	_node_layer.add_child(ghost)
	ghost.global_position = original.global_position
	_drag_ghost = ghost

func _destroy_drag_ghost() -> void:
	if is_instance_valid(_drag_ghost):
		_drag_ghost.queue_free()
	_drag_ghost = null

# ─────────────────────────────────────────────────────────────────────────────
#  INSTRUCTION PANEL
# ─────────────────────────────────────────────────────────────────────────────
func _show_instruction_panel(title: String, body: String, title_color: Color) -> void:
	if is_instance_valid(_instruction_panel):
		_instruction_panel.queue_free()
	# Draggable floating popup — starts bottom-centre, player can move it.
	var panel := PanelContainer.new()
	panel.position            = Vector2(290, 540)
	panel.custom_minimum_size = Vector2(700, 0)
	panel.z_index             = 50
	var style := StyleBoxFlat.new()
	style.bg_color                   = Color(0.04, 0.06, 0.14, 0.95)
	style.border_width_top           = 2
	style.border_width_left          = 1
	style.border_width_right         = 1
	style.border_width_bottom        = 1
	style.border_color               = Color(0.2, 0.6, 1.0, 0.85)
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 16
	style.content_margin_right  = 16
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	_array_layer.add_child(panel)
	_instruction_panel = panel
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	# Drag title bar
	var title_bar := HBoxContainer.new()
	title_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(title_bar)
	var drag_hint_lbl := Label.new()
	drag_hint_lbl.text = "⠿"   # drag handle icon
	drag_hint_lbl.add_theme_font_override("font", _pixel_font)
	drag_hint_lbl.add_theme_font_size_override("font_size", 14)
	drag_hint_lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9, 0.7))
	title_bar.add_child(drag_hint_lbl)
	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.add_theme_font_override("font", _pixel_font)
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", title_color)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	title_bar.add_child(title_lbl)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.add_theme_font_override("font", _pixel_font)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.pressed.connect(func(): _clear_instruction_panel())
	title_bar.add_child(close_btn)
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var body_lbl := Label.new()
	body_lbl.text = body
	body_lbl.add_theme_font_override("font", _pixel_font)
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.add_theme_color_override("font_color", COL_WHITE)
	body_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	body_lbl.custom_minimum_size = Vector2(660, 0)
	vbox.add_child(body_lbl)
	# Make panel draggable via title bar
	title_bar.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton:
			var emb := ev as InputEventMouseButton
			if emb.button_index == MOUSE_BUTTON_LEFT:
				_panel_dragging = emb.pressed
				if emb.pressed:
					_panel_drag_off = panel.position - emb.global_position
		elif ev is InputEventMouseMotion and _panel_dragging:
			panel.position = (ev as InputEventMouseMotion).global_position + _panel_drag_off
	)
	title_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	panel.modulate = Color(1, 1, 1, 0)
	panel.create_tween().tween_property(panel, "modulate:a", 1.0, 0.25)

func _clear_instruction_panel() -> void:
	if is_instance_valid(_instruction_panel):
		var tw := _instruction_panel.create_tween()
		tw.tween_property(_instruction_panel, "modulate:a", 0.0, 0.15)
		tw.tween_callback(_instruction_panel.queue_free)
		_instruction_panel = null

func _check_array_completion() -> void:
	if not _array_done: return
	_complete = true
	_clear_instruction_panel()
	_cost_banner.visible = false
	_complete_banner.visible = true
	_complete_banner.text    = "Array: %d shifts   List: 0 shifts" % _shift_count
	_complete_banner.scale   = Vector2(0.1, 0.1)
	_complete_banner.global_position = Vector2(200, 300)
	var tw := _complete_banner.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_complete_banner, "scale", Vector2(1.0, 1.0), 0.4)
	AudioManager.play_sfx(PATH_SFX_HOVER)
	await get_tree().create_timer(3.2).timeout
	if has_node("/root/GameRouter"):
		var _s1 := _build_stats(true)
		GameRouter.chapter_complete(_chapter_id, int(_s1["score"]), int(_s1["stars"]))
	else:
		get_tree().change_scene_to_file("res://scenes/chapters/linked_list/LinkedListGame.tscn")

func _show_cost_banner(text: String, color: Color) -> void:
	_cost_banner.visible = true
	_cost_banner.text    = text
	_cost_banner.add_theme_color_override("font_color", color)

# ─────────────────────────────────────────────────────────────────────────────
#  SPAWN NODES (list tiers)
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_nodes(count: int) -> void:
	var spacing := (CANVAS.size.x - 80.0) / (count + 1)
	for i in range(count):
		var pos := Vector2(
			CANVAS.position.x + 40.0 + spacing * (i + 1),
			370.0   # fixed rail Y — sits on city floor
		)
		_nodes.append(_make_node(pos, false))
	if _p["concept"] in ["CONNECT", "INSERT", "REVERSE"]:
		_spawn_null_engine()

func _spawn_insert_node() -> void:
	var node := _make_node(Vector2(640, 80), true)
	node["staged"] = true
	_insert_node_id = node["id"]
	(node["sprite"] as Node2D).modulate = COL_STAGED
	_nodes.append(node)

func _spawn_null_engine() -> void:
	var spr := Sprite2D.new()
	if ResourceLoader.exists(PATH_TRAIN_ENGINE):
		spr.texture = load(PATH_TRAIN_ENGINE)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale    = NODE_SCALE
	spr.flip_h   = true
	spr.modulate = COL_TAIL
	spr.z_index  = 8
	_node_layer.add_child(spr)
	spr.global_position = Vector2(
		CANVAS.position.x + CANVAS.size.x - 60,
		CANVAS.position.y + CANVAS.size.y * 0.5
	)
	var lbl := Label.new()
	lbl.text = "NULL"
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", COL_TAIL)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-30, -60)
	spr.add_child(lbl)
	var hint := Label.new()
	hint.text = "← chain ends here"
	hint.add_theme_font_override("font", _pixel_font)
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.6, 0.9, 0.6, 0.7))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.position = Vector2(-50, 30)
	spr.add_child(hint)

func _make_node(pos: Vector2, staged: bool) -> Dictionary:
	var sprite_path: String
	if staged:
		sprite_path = PATH_TRAIN_ENGINE
	elif _uid == 0:
		sprite_path = PATH_TRAIN_ENGINE   # first node = engine (HEAD)
	else:
		sprite_path = PATH_TRAIN_COAL if _uid % 2 == 0 else PATH_TRAIN_LOGS

	var sprite := Sprite2D.new()
	if ResourceLoader.exists(sprite_path):
		sprite.texture = load(sprite_path)
	else:
		var cr := ColorRect.new()
		cr.size = Vector2(32, 32); cr.position = Vector2(-16, -16)
		cr.color = Color(0.3 + _uid * 0.12, 0.55, 0.9)
		sprite.add_child(cr)

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale    = NODE_SCALE
	sprite.z_index  = 10
	sprite.modulate = COL_TRAIN_MID   # visible against dark bg
	_node_layer.add_child(sprite)
	sprite.global_position = pos

	# ── PORT INDICATOR (added as sibling in NodeLayer, not child of sprite) ──
	# Adding port elements as children of the Sprite2D causes the sprite
	# texture to occlude them in certain Godot batching orders.
	# As NodeLayer siblings they always draw on top of the sprite.
	var port_container := Node2D.new()
	port_container.z_index = 20   # always above sprite (z=10) in NodeLayer
	port_container.global_position = pos + PORT_OFFSET
	_node_layer.add_child(port_container)

	# Invisible 44×44 touch-safe hit zone
	var port_hit := ColorRect.new()
	port_hit.size     = Vector2(44, 44)
	port_hit.position = Vector2(-22, -22)
	port_hit.color    = Color(0, 0, 0, 0)
	_node_layer.add_child(port_hit)   # also a sibling so input works
	port_hit.global_position = pos + PORT_OFFSET + Vector2(-22, -22)

	# Outer glow ring
	var port_ring := ColorRect.new()
	port_ring.size     = Vector2(36, 36)
	port_ring.position = Vector2(-18, -18)
	port_ring.color    = Color(COL_ARROW.r, COL_ARROW.g, COL_ARROW.b, 0.28)
	port_container.add_child(port_ring)

	# Solid centre dot
	var port := ColorRect.new()
	port.size     = Vector2(28, 28)
	port.position = Vector2(-14, -14)
	port.color    = COL_ARROW
	port_container.add_child(port)

	# Large arrow label
	var port_lbl := Label.new()
	port_lbl.text = "▶"
	port_lbl.add_theme_font_override("font", _pixel_font)
	port_lbl.add_theme_font_size_override("font_size", 22)
	port_lbl.add_theme_color_override("font_color", Color.WHITE)
	port_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	port_lbl.add_theme_constant_override("shadow_offset_x", 2)
	port_lbl.add_theme_constant_override("shadow_offset_y", 2)
	port_lbl.position = Vector2(-13, -14)
	port_container.add_child(port_lbl)

	# "drag" hint below the port — only shown on CONNECT tier
	if _p["concept"] == "CONNECT":
		var drag_hint := Label.new()
		drag_hint.text = "drag"
		drag_hint.add_theme_font_override("font", _pixel_font)
		drag_hint.add_theme_font_size_override("font_size", 10)
		drag_hint.add_theme_color_override("font_color", Color(COL_ARROW.r, COL_ARROW.g, COL_ARROW.b, 0.85))
		drag_hint.position = Vector2(-10, 16)
		port_container.add_child(drag_hint)

	# Store port_container ref in data so it moves with the sprite during drag
	# (see _redraw_all_arrows — we'll update port positions there too)
	var _port_node := port_container   # captured in data dict below

	# Pulse tween
	var pulse_tw := port_ring.create_tween().set_loops()
	pulse_tw.tween_property(port_ring, "modulate:a", 0.08, 0.7)
	pulse_tw.tween_property(port_ring, "modulate:a", 1.0,  0.7)

	var addr := "0x%02X" % ((_uid * 37 + 11) % 256)
	var lbl := Label.new()
	lbl.text = addr
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 36)   # larger
	lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))
	lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.custom_minimum_size  = Vector2(180, 0)   # full sprite width
	lbl.position             = Vector2(-90, -18) # centred on 180px body
	sprite.add_child(lbl)

	var data := {"id": _uid, "addr": addr, "sprite": sprite,
				  "next_id": -1, "arrow": null, "staged": staged,
				  "port": port_container}
	_uid += 1
	return data

# ─────────────────────────────────────────────────────────────────────────────
#  PRE-BUILD / INJECT
# ─────────────────────────────────────────────────────────────────────────────
func _prebuild_chain() -> void:
	for i in range(_nodes.size() - 1):
		_nodes[i]["next_id"] = _nodes[i + 1]["id"]
		_nodes[i]["arrow"]   = _draw_arrow(_nodes[i])
	_update_all_node_visuals()

func _record_original_order() -> void:
	_original_order.clear()
	for data: Dictionary in _nodes:
		_original_order.append(data["id"])

func _inject_cycle() -> void:
	if _nodes.size() < 3: return
	# v6: randomise the cycle injection point (not always nodes[last] → nodes[1])
	var cycle_target_idx: int = randi_range(0, _nodes.size() - 3)
	var last: Dictionary = _nodes.back() as Dictionary
	last["next_id"] = _nodes[cycle_target_idx]["id"]
	last["arrow"]   = _draw_arrow(last)

# ─────────────────────────────────────────────────────────────────────────────
#  GHOST / GAP / CYCLE
# ─────────────────────────────────────────────────────────────────────────────
func _draw_ghost_reversed_arrows() -> void:
	for c in _ghost_layer.get_children(): c.queue_free()
	for i in range(1, _nodes.size()):
		var src_nd := _nodes[i]["sprite"] as Node2D
		var dst_nd := _nodes[i - 1]["sprite"] as Node2D
		if not is_instance_valid(src_nd) or not is_instance_valid(dst_nd): continue
		var line := Line2D.new()
		line.default_color = COL_GHOST; line.width = 2.0
		line.add_point(src_nd.global_position + PORT_OFFSET)
		line.add_point(dst_nd.global_position)
		_ghost_layer.add_child(line)

func _draw_gap_indicators() -> void:
	for c in _gap_layer.get_children(): c.queue_free()
	for i in range(_nodes.size() - 1):
		var a: Dictionary = _nodes[i]; var b: Dictionary = _nodes[i + 1]
		if a["staged"] or b["staged"]: continue
		if a["next_id"] >= 0: continue
		var pa := (a["sprite"] as Node2D).global_position + PORT_OFFSET
		var pb := (b["sprite"] as Node2D).global_position
		for s in range(8):
			if s % 2 == 1: continue
			var t0 := float(s) / 8.0; var t1 := float(s + 1) / 8.0
			var dash := Line2D.new()
			dash.default_color = COL_GAP; dash.width = 2.0
			dash.add_point(pa.lerp(pb, t0)); dash.add_point(pa.lerp(pb, t1))
			_gap_layer.add_child(dash)

func _clear_gap_indicators() -> void:
	for c in _gap_layer.get_children(): c.queue_free()

func _start_cycle_dot_animation() -> void:
	_cycle_path = _get_cycle_path()
	if _cycle_path.is_empty(): return
	_cycle_dot = Label.new(); _cycle_dot.text = "●"; _cycle_dot.z_index = 50
	_cycle_dot.add_theme_font_size_override("font_size", 22)
	_cycle_dot.add_theme_color_override("font_color", COL_CYCLE)
	add_child(_cycle_dot); _cycle_dot_idx = 0
	_cycle_dot_tmr.wait_time = 0.35; _cycle_dot_tmr.one_shot = false
	_cycle_dot_tmr.timeout.connect(_advance_cycle_dot); _cycle_dot_tmr.start()

func _advance_cycle_dot() -> void:
	if not _alive or _cycle_path.is_empty(): return
	if not is_instance_valid(_cycle_dot): return
	_cycle_dot_idx = (_cycle_dot_idx + 1) % _cycle_path.size()
	var d: Dictionary = _data_by_id(_cycle_path[_cycle_dot_idx])
	if d:
		var nd := d["sprite"] as Node2D
		if is_instance_valid(nd):
			_cycle_dot.global_position = nd.global_position + Vector2(-8, -50)

func _get_cycle_path() -> Array:
	var slow: int = _nodes[0]["id"]; var fast: int = _nodes[0]["id"]
	var in_cycle := false
	for _i in range(_nodes.size() * 2):
		var sd: Dictionary = _data_by_id(slow); if not sd or sd["next_id"] < 0: return []
		var fd: Dictionary = _data_by_id(fast); if not fd or fd["next_id"] < 0: return []
		var fd2: Dictionary = _data_by_id(fd["next_id"]); if not fd2 or fd2["next_id"] < 0: return []
		slow = sd["next_id"] as int; fast = fd2["next_id"] as int
		if slow == fast: in_cycle = true; break
	if not in_cycle: return []
	var path: Array = [slow]
	var cur: Dictionary = _data_by_id(slow); if cur.is_empty(): return []
	var nxt: int = cur["next_id"]
	while nxt != slow and nxt >= 0:
		path.append(nxt)
		var d: Dictionary = _data_by_id(nxt); if d.is_empty(): break
		nxt = d["next_id"]
	return path

func _stop_cycle_animation() -> void:
	_cycle_dot_tmr.stop()
	if is_instance_valid(_cycle_dot): _cycle_dot.queue_free()
	_cycle_dot = null; _cycle_path.clear()

# ─────────────────────────────────────────────────────────────────────────────
#  TRAVERSAL REPLAY
# ─────────────────────────────────────────────────────────────────────────────
func _start_traversal_replay() -> void:
	if not is_instance_valid(_replay_btn): return
	_replay_btn.disabled = true
	if is_instance_valid(_traverse_cursor): _traverse_cursor.queue_free()

	var head_id := _find_head()
	if head_id < 0: _replay_btn.disabled = false; return
	_traverse_path.clear()
	var cur := head_id; var visited: Dictionary = {}
	while cur >= 0 and cur not in visited:
		visited[cur] = true; _traverse_path.append(cur)
		var d: Dictionary = _data_by_id(cur); if not d: break
		cur = d["next_id"]

	_traverse_cursor = Label.new()
	_traverse_cursor.text = "▼"
	_traverse_cursor.z_index = 60
	_traverse_cursor.add_theme_font_size_override("font_size", 26)
	_traverse_cursor.add_theme_color_override("font_color", COL_HEAD)
	add_child(_traverse_cursor)
	_traverse_idx = 0
	_hint_lbl.text = "Traversal: following .next pointers from HEAD → NULL"
	_hint_box.visible = true

	_traverse_tmr.wait_time = 0.55
	_traverse_tmr.one_shot  = false
	if not _traverse_tmr.timeout.is_connected(_step_traversal):
		_traverse_tmr.timeout.connect(_step_traversal)
	_traverse_tmr.start()

func _step_traversal() -> void:
	if _traverse_idx >= _traverse_path.size():
		_traverse_tmr.stop()
		if is_instance_valid(_traverse_cursor):
			var tw := _traverse_cursor.create_tween()
			tw.tween_property(_traverse_cursor, "modulate:a", 0.0, 0.4)
			tw.tween_callback(_traverse_cursor.queue_free)
		_traverse_cursor = null
		_hint_lbl.text = "Traversal complete — reached NULL!\nEvery node was visited exactly once."
		if is_instance_valid(_replay_btn): _replay_btn.disabled = false
		return

	var cid: int = _traverse_path[_traverse_idx]
	var d: Dictionary = _data_by_id(cid)
	if d.is_empty(): _traverse_tmr.stop(); return
	var nd := d["sprite"] as Node2D
	if not is_instance_valid(nd): _traverse_tmr.stop(); return

	if is_instance_valid(_traverse_cursor):
		_traverse_cursor.global_position = nd.global_position + Vector2(-12, -56)

	var tw := nd.create_tween()
	tw.tween_property(nd, "modulate", COL_SNAP, 0.12)
	tw.tween_property(nd, "modulate", _node_base_color(d), 0.3)

	var next_addr := "NULL"
	if d["next_id"] >= 0:
		var nd2: Dictionary = _data_by_id(d["next_id"])
		if not nd2.is_empty(): next_addr = nd2["addr"] as String
	_hint_lbl.text = "At %s  →  .next = %s" % [d["addr"], next_addr]

	_traverse_idx += 1

# ─────────────────────────────────────────────────────────────────────────────
#  PROCESS
# ─────────────────────────────────────────────────────────────────────────────
const PARALLAX_SPEED := -90.0  # px/s — negative = city moves left (train moves right)

func _process(delta: float) -> void:
	if is_instance_valid(_parallax_bg):
		_parallax_bg.scroll_offset.x += PARALLAX_SPEED * delta
	if not _alive: return
	if _combo > 0:
		_combo_decay -= delta
		if _combo_decay <= 0.0: _combo = 0; _combo_lbl.text = ""
	if _p["concept"] not in ["ARRAY_FEEL"]:
		_update_null_marker()
		_update_hover()
	if _live_arrow != null:
		_update_snap_glow(get_viewport().get_mouse_position())
	# Drag ghost follow
	if is_instance_valid(_drag_ghost):
		_drag_ghost.global_position = get_viewport().get_mouse_position() + _drag_offset
	# Live arrow tracking — update endpoints in-place every frame while dragging
	if _drag_id >= 0 and _p["concept"] != "ARRAY_FEEL":
		_update_arrows_for_node(_drag_id)

# Update the two arrows affected when a node moves: the one leaving it (tail)
# and any arrow pointing to it (head). Updates Line2D points in-place — no rebuild.
func _update_arrows_for_node(nid: int) -> void:
	var dragged: Dictionary = _data_by_id(nid)
	if not dragged: return
	var drag_nd := dragged["sprite"] as Node2D
	if not is_instance_valid(drag_nd): return
	var drag_pos := drag_nd.global_position

	for data: Dictionary in _nodes:
		var arrow: Variant = data["arrow"]
		if not arrow or not is_instance_valid(arrow as Node2D): continue
		var line := arrow as Line2D
		if line.get_point_count() < 5: continue

		# (a) Arrow LEAVING the dragged node — move its tail (point 0)
		if data["id"] == nid:
			var new_tail := _arrow_layer.to_local(drag_pos + PORT_OFFSET)
			var head     := line.get_point_position(1)
			line.set_point_position(0, new_tail)
			_set_arrowhead(line, new_tail, head)

		# (b) Arrow pointing TO the dragged node — move its head (points 1-4)
		elif data["next_id"] == nid:
			var src_nd := data["sprite"] as Node2D
			if not is_instance_valid(src_nd): continue
			var tail     := _arrow_layer.to_local(src_nd.global_position + PORT_OFFSET)
			var new_head := _arrow_layer.to_local(drag_pos)
			_set_arrowhead(line, tail, new_head)

func _set_arrowhead(line: Line2D, local_tail: Vector2, local_head: Vector2) -> void:
	var dir := (local_head - local_tail).normalized()
	if dir == Vector2.ZERO: return
	line.set_point_position(1, local_head)
	line.set_point_position(2, local_head - dir * 14.0 + dir.rotated(deg_to_rad(140.0))  * 12.0)
	line.set_point_position(3, local_head)
	line.set_point_position(4, local_head - dir * 14.0 + dir.rotated(deg_to_rad(-140.0)) * 12.0)

# ─────────────────────────────────────────────────────────────────────────────
#  v6: HOVER HIGHLIGHT
#  Brightens the port dot when the cursor is over the port zone,
#  and dims the car body slightly when hoverable.
# ─────────────────────────────────────────────────────────────────────────────
func _update_hover() -> void:
	var mouse := get_viewport().get_mouse_position()
	var new_hover := -1

	for data: Dictionary in _nodes:
		var nd := data["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		if nd.global_position.distance_to(mouse) < NODE_HIT + 20:
			new_hover = data["id"]
			break

	if new_hover == _hover_id: return

	# Clear old hover
	if _hover_id >= 0:
		var old: Dictionary = _data_by_id(_hover_id)
		if old and is_instance_valid(old["sprite"] as Node2D):
			var nd := old["sprite"] as Node2D
			# Restore port colour
			var port := nd.get_child(1) if nd.get_child_count() > 1 else null
			if is_instance_valid(port) and port is ColorRect:
				(port as ColorRect).color = COL_ARROW
			nd.modulate = _node_base_color(old)

	_hover_id = new_hover

	if _hover_id >= 0:
		var hov: Dictionary = _data_by_id(_hover_id)
		if hov and is_instance_valid(hov["sprite"] as Node2D):
			var nd := hov["sprite"] as Node2D
			# Brighten port dot
			var port := nd.get_child(1) if nd.get_child_count() > 1 else null
			if is_instance_valid(port) and port is ColorRect:
				(port as ColorRect).color = COL_LIVE

# ─────────────────────────────────────────────────────────────────────────────
#  v6: CLICK-TO-SELECT RING
# ─────────────────────────────────────────────────────────────────────────────
func _set_selection(id: int) -> void:
	# Clear existing ring
	if is_instance_valid(_select_ring):
		_select_ring.queue_free()
		_select_ring = null

	_selected_id = id
	if id < 0: return

	var data: Dictionary = _data_by_id(id)
	if not data: return
	var nd := data["sprite"] as Node2D
	if not is_instance_valid(nd): return

	# Draw a cyan ring around the node
	var ring := Node2D.new()
	ring.z_index = 25
	_node_layer.add_child(ring)
	ring.global_position = nd.global_position
	_select_ring = ring

	# We draw the ring in _draw — simplest is a Label with a circle character
	var ring_lbl := Label.new()
	ring_lbl.text = "◯"
	ring_lbl.add_theme_font_size_override("font_size", 72)
	ring_lbl.add_theme_color_override("font_color", COL_SELECTED)
	ring_lbl.position = Vector2(-36, -42)
	ring.add_child(ring_lbl)

	_float_label(nd, "selected — click a target", COL_SELECTED)

# ─────────────────────────────────────────────────────────────────────────────
#  SNAP GLOW
# ─────────────────────────────────────────────────────────────────────────────
func _update_snap_glow(mouse_pos: Vector2) -> void:
	var best_dist := MAGNET_R; var best_id := -1
	for data: Dictionary in _nodes:
		if data["id"] == _arrow_src: continue
		var nd := data["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var d := nd.global_position.distance_to(mouse_pos)
		if d < best_dist: best_dist = d; best_id = data["id"]

	if _snap_target >= 0 and _snap_target != best_id:
		var prev: Dictionary = _data_by_id(_snap_target)
		if prev:
			var prev_nd := prev["sprite"] as Node2D
			if is_instance_valid(prev_nd): prev_nd.modulate = _node_base_color(prev)

	_snap_target = best_id
	if best_id >= 0:
		var snap_data: Dictionary = _data_by_id(best_id)
		if snap_data:
			var snap_nd := snap_data["sprite"] as Node2D
			if is_instance_valid(snap_nd): snap_nd.modulate = COL_SNAP
		if _live_arrow != null and best_dist < SNAP_R:
			var snap_nd := (_data_by_id(best_id)["sprite"] as Node2D)
			_live_arrow.set_point_position(1, snap_nd.global_position)

func _node_base_color(data: Dictionary) -> Color:
	if data["staged"]: return COL_STAGED
	var head_id := _find_head(); var tail_id := _find_tail()
	if data["id"] == head_id: return COL_HEAD
	if data["id"] == tail_id: return COL_TAIL
	return COL_TRAIN_MID

# ─────────────────────────────────────────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _alive: return

	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				if _p["concept"] in ["ARRAY_FEEL"]:
					_array_on_lmb_down(e.position)
				else:
					_on_lmb_down(e.position)
			else:
				if _p["concept"] in ["ARRAY_FEEL"]:
					_array_on_lmb_up(e.position)
				else:
					_on_lmb_up(e.position)
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			if _p["concept"] == "ARRAY_FEEL":
				_array_on_rmb_down(e.position)
			elif _p["delete"]:
				var deleted := _try_delete_return(e.position)
				if not deleted:
					_try_unlink(e.position)
			else:
				_try_unlink(e.position)

	elif event is InputEventMouseMotion:
		if _p["concept"] == "ARRAY_FEEL":
			if _array_drag_item >= 0:
				if _af_phase == 0:
					var item := _array_item_by_id(_array_drag_item)
					if not item.is_empty():
						(item["sprite"] as Node2D).global_position = event.position + _array_drag_off
				else:
					for node: Dictionary in _list_nodes_af:
						if node["id"] == _array_drag_item:
							(node["sprite"] as Node2D).global_position = event.position + _array_drag_off
							if (node["next_id"] as int) >= 0:
								var dst: Dictionary = _list_node_af_by_id(node["next_id"])
								if not dst.is_empty():
									var dst_pos := (dst["sprite"] as Node2D).global_position
									node["arrow"] = _list_draw_arrow_between(node, dst_pos)
							break
			if _af_drag_hook >= 0 and is_instance_valid(_af_live_arrow):
				_af_live_arrow.set_point_position(1, event.position)
		else:
			if _live_arrow != null:
				_live_arrow.set_point_position(1, event.position)
			if _drag_id >= 0:
				var d: Dictionary = _data_by_id(_drag_id)
				if d:
					var nd := d["sprite"] as Node2D
					nd.global_position = event.position + _drag_offset
					# Keep port indicator in sync with sprite
					if d.has("port") and is_instance_valid(d["port"] as Node2D):
						(d["port"] as Node2D).global_position = nd.global_position + PORT_OFFSET
					# Arrow endpoints updated live in _process — no rebuild here
				# Move select ring with the node
				if is_instance_valid(_select_ring) and _selected_id == _drag_id:
					var d2: Dictionary = _data_by_id(_drag_id)
					if d2 and is_instance_valid(d2["sprite"] as Node2D):
						_select_ring.global_position = (d2["sprite"] as Node2D).global_position

# ─────────────────────────────────────────────────────────────────────────────
#  LMB DOWN — PORT ZONE → draw arrow; BODY → drag; TAP → select/connect
# ─────────────────────────────────────────────────────────────────────────────
func _on_lmb_down(pos: Vector2) -> void:
	# --- Port detection: right half of car OR within PORT_HIT of port centre ---
	for data: Dictionary in _nodes:
		var nd := data["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var car_center := nd.global_position
		var dx := pos.x - car_center.x
		var dy: float = absf(pos.y - car_center.y)
		# Enlarged port zone: dx > 0, within 110 horizontally, 70 vertically
		if dx > 0 and dx < 110.0 and dy < 70.0:
			var port_world := nd.global_position + PORT_OFFSET
			_arrow_src  = data["id"]
			_live_arrow = _make_temp_line(port_world, pos)
			# Cancel any active click-selection if dragging an arrow
			_set_selection(-1)
			return

	# --- Body drag / click-to-select ---
	for data: Dictionary in _nodes:
		var nd := data["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		if nd.global_position.distance_to(pos) < NODE_HIT:
			# v6: if something is already selected, treat this click as a CONNECT
			if _selected_id >= 0 and _selected_id != data["id"]:
				var src_id := _selected_id
				_set_selection(-1)
				_try_link(src_id, data["id"])
				_check_completion()
				return
			# Otherwise start a drag (also acts as tap-to-select on release)
			_drag_id     = data["id"]
			_drag_offset = nd.global_position - pos
			nd.z_index   = 30
			_spawn_drag_ghost(data)
			return

# ─────────────────────────────────────────────────────────────────────────────
#  LMB UP
# ─────────────────────────────────────────────────────────────────────────────
func _on_lmb_up(pos: Vector2) -> void:
	_destroy_drag_ghost()

	if _arrow_src >= 0 and _live_arrow != null:
		_live_arrow.queue_free(); _live_arrow = null
		var target_id := _snap_target if _snap_target >= 0 else _node_at(pos, _arrow_src)
		if _snap_target >= 0:
			var sd: Dictionary = _data_by_id(_snap_target)
			if sd: (_data_by_id(_snap_target)["sprite"] as Node2D).modulate = _node_base_color(sd)
			_snap_target = -1
		if target_id >= 0:
			_try_link(_arrow_src, target_id)
		else:
			var src: Dictionary = _data_by_id(_arrow_src)
			if src:
				_apply_wrong(src["sprite"] as Node2D, 0,
					"Release over another car to connect.\nThe structure needs each node to point somewhere.")
		_arrow_src = -1
		_check_completion()
		return

	if _drag_id >= 0:
		var d: Dictionary = _data_by_id(_drag_id)
		if d:
			var nd := d["sprite"] as Node2D
			nd.z_index = 10
			# Sync port position on drop
			if d.has("port") and is_instance_valid(d["port"] as Node2D):
				(d["port"] as Node2D).global_position = nd.global_position + PORT_OFFSET
			# v6: small drag distance = tap → toggle selection
			var drag_dist := nd.global_position.distance_to(pos + _drag_offset - nd.global_position + nd.global_position)
			# Simpler: compare node pos (updated during drag) to original click
			# We check if we've been called immediately after a very short drag
			if _p["delete"] and nd.global_position.distance_to(_trash_zone.global_position) < TRASH_R:
				_delete_node(_drag_id); _drag_id = -1; return

			# If barely moved, treat as tap-to-select
			# (drag_offset holds original_pos - click_pos; if nd.pos ≈ click_pos + drag_offset it barely moved)
			var original_pos := pos + _drag_offset
			if nd.global_position.distance_to(original_pos) < 12.0:
				# It was a tap, not a drag
				if _selected_id == _drag_id:
					_set_selection(-1)   # deselect on second tap
				else:
					_set_selection(_drag_id)
				_drag_id = -1
				return

		_drag_id = -1
		_redraw_all_arrows()

# ─────────────────────────────────────────────────────────────────────────────
#  LINK
# ─────────────────────────────────────────────────────────────────────────────
func _try_link(src_id: int, dst_id: int) -> void:
	var src: Dictionary = _data_by_id(src_id)
	if src.is_empty(): return

	if src_id == dst_id:
		_apply_wrong(src["sprite"] as Node2D, _p["penalty"],
			"A node can't point to itself — that creates a cycle of length 1.\nPoint to a DIFFERENT car.")
		return

	if not _p["cycle_inject"]:
		for other: Dictionary in _nodes:
			if other["id"] == src_id: continue
			if other["next_id"] == dst_id:
				_stat["bad_link"] += 1
				_apply_wrong(src["sprite"] as Node2D, _p["penalty"],
					"Two nodes can't point to the same target!\n%s already points here.\nRight-click %s to free it first." \
					% [other["addr"], other["addr"]])
				_pulse_conflict(other["id"], dst_id)
				_mid_game_hint()
				return

	if src["arrow"] and is_instance_valid(src["arrow"] as Node2D):
		(src["arrow"] as Node2D).queue_free()

	src["next_id"] = dst_id
	src["arrow"]   = _draw_arrow(src)
	_apply_correct(src["sprite"] as Node2D, 15)
	AudioManager.play_sfx(PATH_SFX_LINK)
	_player_link_actions += 1
	_update_all_node_visuals()
	_clear_gap_indicators()
	_show_pointer_tooltip(src, _data_by_id(dst_id))
	_hint_next_unlinked()
	if _p["reverse"]: _check_ghost_progress()

	if is_instance_valid(_replay_btn) and _count_links() >= 1:
		_replay_btn.visible = true

# ─────────────────────────────────────────────────────────────────────────────
#  v6: MID-GAME HINT — surfaces dominant-mistake guidance on 2nd+ mistake
# ─────────────────────────────────────────────────────────────────────────────
func _mid_game_hint() -> void:
	var total_mistakes: int = int(_stat["bad_link"]) + int(_stat["wrong_reverse"]) + \
		int(_stat["bad_insert"]) + int(_stat["structural_err"])
	if total_mistakes < 2: return   # only start hinting after the second mistake
	_hint_lbl.text = _dominant_mistake() + "\n\n" + _unlink_reminder_text()
	_hint_box.visible = true

# ─────────────────────────────────────────────────────────────────────────────
#  POINTER TOOLTIP
# ─────────────────────────────────────────────────────────────────────────────
func _show_pointer_tooltip(src: Dictionary, dst: Dictionary) -> void:
	if dst.is_empty(): return
	var src_addr: String = src["addr"]
	var dst_addr: String = dst["addr"]
	_hint_lbl.text = (
		"%s.next  =  %s\n" % [src_addr, dst_addr]
		+ "The arrow IS a pointer — it stores a memory address.\n"
		+ "Order comes only from these pointers, not from position."
	)
	_hint_box.visible = true

# ─────────────────────────────────────────────────────────────────────────────
#  NEXT-NODE HINT / CONFLICT PULSE / GHOST PROGRESS
# ─────────────────────────────────────────────────────────────────────────────
func _hint_next_unlinked() -> void:
	for data: Dictionary in _nodes:
		if data["staged"]: continue
		if data["next_id"] < 0:
			var nd := data["sprite"] as Node2D
			if is_instance_valid(nd):
				var tw := nd.create_tween()
				tw.tween_property(nd, "modulate", COL_HINT, 0.15)
				tw.tween_property(nd, "modulate", _node_base_color(data), 0.4)
			break

func _pulse_conflict(existing_src_id: int, dst_id: int) -> void:
	var s: Dictionary = _data_by_id(existing_src_id)
	var d: Dictionary = _data_by_id(dst_id)
	if s: _pulse_node(s["sprite"] as Node2D, COL_WRONG)
	if d: _pulse_node(d["sprite"] as Node2D, COL_WRONG)

func _check_ghost_progress() -> void:
	var correct_count := 0
	for i in range(1, _nodes.size()):
		var src_id: int = _nodes[i]["id"]; var dst_id: int = _nodes[i - 1]["id"]
		var src: Dictionary = _data_by_id(src_id)
		if not src.is_empty() and (src["next_id"] as int) == dst_id:
			correct_count += 1
	var frac := float(correct_count) / float(_nodes.size() - 1)
	for c in _ghost_layer.get_children():
		if c is Line2D:
			(c as Line2D).default_color = Color(COL_GHOST.r, COL_GHOST.g,
				COL_GHOST.b, COL_GHOST.a * (1.0 - frac * 0.8))

# ─────────────────────────────────────────────────────────────────────────────
#  HEAD / TAIL / NULL MARKER / STRUCT LABEL
# ─────────────────────────────────────────────────────────────────────────────
func _find_head() -> int:
	var pointed_to: Dictionary = {}
	for data: Dictionary in _nodes:
		if data["next_id"] >= 0: pointed_to[data["next_id"]] = true
	for data: Dictionary in _nodes:
		if data["id"] not in pointed_to: return data["id"]
	return -1

func _find_tail() -> int:
	for data: Dictionary in _nodes:
		if data["next_id"] < 0: return data["id"]
	return -1

func _update_all_node_visuals() -> void:
	var head_id := _find_head(); var tail_id := _find_tail()
	for data: Dictionary in _nodes:
		var nd := data["sprite"] as Sprite2D
		if not is_instance_valid(nd): continue
		if data["staged"]:
			if ResourceLoader.exists(PATH_TRAIN_ENGINE):
				nd.texture = load(PATH_TRAIN_ENGINE)
			nd.flip_h   = false
			nd.modulate = COL_STAGED
		elif data["id"] == head_id:
			if ResourceLoader.exists(PATH_TRAIN_ENGINE):
				nd.texture = load(PATH_TRAIN_ENGINE)
			nd.flip_h   = false
			nd.modulate = COL_HEAD
		elif data["id"] == tail_id:
			if ResourceLoader.exists(PATH_TRAIN_CABOOSE):
				nd.texture = load(PATH_TRAIN_CABOOSE)
			nd.flip_h   = false
			nd.modulate = COL_TAIL
		else:
			var cargo := PATH_TRAIN_COAL if (data["id"] as int) % 2 == 0 else PATH_TRAIN_LOGS
			if ResourceLoader.exists(cargo):
				nd.texture = load(cargo)
			nd.flip_h   = false
			nd.modulate = COL_TRAIN_MID
		# Sync port indicator position to sprite
		if data.has("port") and is_instance_valid(data["port"] as Node2D):
			(data["port"] as Node2D).global_position = nd.global_position + PORT_OFFSET
	_update_struct_label(head_id, tail_id)

func _update_null_marker() -> void:
	var tail_id := _find_tail()
	if tail_id < 0: _null_marker.visible = false; return
	var tail: Dictionary = _data_by_id(tail_id)
	if not tail: _null_marker.visible = false; return
	var nd := tail["sprite"] as Node2D
	if not is_instance_valid(nd): _null_marker.visible = false; return
	_null_marker.visible = true
	_null_marker.global_position = nd.global_position + Vector2(52, -10)
	_null_marker.text = "→ NULL"
	_null_marker.add_theme_font_size_override("font_size", 14)
	_null_marker.add_theme_color_override("font_color", COL_TAIL)

func _update_struct_label(head_id: int, tail_id: int) -> void:
	var heads := _count_heads(); var links := _count_links()
	var parts: Array[String] = []
	if head_id >= 0: parts.append("HEAD: %s" % (_data_by_id(head_id)["addr"] as String))
	else:             parts.append("HEAD: ⚠ none")
	if tail_id >= 0: parts.append("TAIL: %s" % (_data_by_id(tail_id)["addr"] as String))
	else:             parts.append("TAIL: ⚠ none")
	parts.append("Links: %d/%d" % [links, _p["target_links"]])
	if _has_cycle():  parts.append("⚠ CYCLE")
	if heads > 1:     parts.append("⚠ %d heads" % heads)
	_struct_lbl.text = "  |  ".join(parts)

# ─────────────────────────────────────────────────────────────────────────────
#  CYCLE HIGHLIGHT
# ─────────────────────────────────────────────────────────────────────────────
func _highlight_cycle_nodes() -> void:
	for c in _cycle_hl.get_children(): c.queue_free()
	_cycle_hl.visible = true
	var path := _get_cycle_path()
	for cid: int in path:
		var d: Dictionary = _data_by_id(cid); if d.is_empty(): continue
		var nd := d["sprite"] as Node2D
		if is_instance_valid(nd):
			nd.modulate = COL_CYCLE
			var ring := Label.new()
			ring.text = "↺"
			ring.add_theme_font_size_override("font_size", 28)
			ring.add_theme_color_override("font_color", COL_CYCLE)
			_cycle_hl.add_child(ring)
			ring.global_position = nd.global_position + Vector2(-14, -50)
	_hint_lbl.text = (
		"These nodes loop forever!\n"
		+ ".next never reaches NULL — traversal runs INFINITELY.\n"
		+ "Right-click the last node in the loop to remove the bad link,\n"
		+ "then re-link it to NULL or the correct next node."
	)
	_hint_box.visible = true

# ─────────────────────────────────────────────────────────────────────────────
#  GUIDING FEEDBACK
# ─────────────────────────────────────────────────────────────────────────────
func _guide_multiple_heads(heads_list: Array) -> void:
	var head_id := _find_head()
	for hid: int in heads_list:
		var d: Dictionary = _data_by_id(hid); if d.is_empty(): continue
		if hid == head_id: _pulse_node(d["sprite"] as Node2D, COL_HEAD)
		else:               _pulse_node(d["sprite"] as Node2D, COL_WRONG)

func _guide_disconnected(disconnected_ids: Array) -> void:
	for did: int in disconnected_ids:
		var d: Dictionary = _data_by_id(did); if d.is_empty(): continue
		var nd := d["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var nearest := _nearest_chained_node(did); if nearest < 0: continue
		var nd2 := (_data_by_id(nearest)["sprite"] as Node2D)
		if not is_instance_valid(nd2): continue
		var hint_line := Line2D.new()
		hint_line.default_color = Color(1.0, 1.0, 0.4, 0.45); hint_line.width = 2.0
		hint_line.add_point(nd.global_position); hint_line.add_point(nd2.global_position)
		_ghost_layer.add_child(hint_line)
		await get_tree().create_timer(2.0).timeout
		if is_instance_valid(hint_line): hint_line.queue_free()

func _nearest_chained_node(from_id: int) -> int:
	var head_id := _find_head(); if head_id < 0: return -1
	var chain: Array = []; var cur := head_id; var visited: Dictionary = {}
	while cur >= 0 and cur not in visited:
		visited[cur] = true; chain.append(cur)
		var d: Dictionary = _data_by_id(cur); if not d: break
		cur = d["next_id"]
	if chain.is_empty(): return -1
	var from_nd := (_data_by_id(from_id)["sprite"] as Node2D)
	var best_dist := INF; var best := -1
	for cid: int in chain:
		if cid == from_id: continue
		var d: Dictionary = _data_by_id(cid); if d.is_empty(): continue
		var dist := from_nd.global_position.distance_to((d["sprite"] as Node2D).global_position)
		if dist < best_dist: best_dist = dist; best = cid
	return best

# ─────────────────────────────────────────────────────────────────────────────
#  COMPLETION CHECK
#
#  KEY DESIGN RULE: never penalise an incomplete / in-progress state.
#  Structural errors (multiple heads, disconnected nodes, wrong reverse)
#  only fire when link_count == target_links — i.e. the player believes
#  they are finished. During building, the HUD updates silently so the
#  player can see progress without being punished for every intermediate step.
# ─────────────────────────────────────────────────────────────────────────────
func _check_completion() -> void:
	if _complete: return
	_update_all_node_visuals()

	# ── CYCLE tier: check on every action because the cycle is pre-existing ──
	if _p["cycle_inject"]:
		if _has_cycle():
			_highlight_cycle_nodes()
			_task_lbl.text = "⚠ Cycle still present! Right-click the looping car to break it."
			return
		else:
			_stop_cycle_animation()
			for c in _cycle_hl.get_children(): c.queue_free()

	var links := _count_links()
	var target := _p["target_links"] as int

	# ── Still building — update hint silently, no errors, no penalties ────────
	if links < target:
		if _p["insert"] and _insert_node_id >= 0:
			_validate_insert_v3()   # updates hint box only, no penalty (see function)
		return

	# ── All links placed — now validate the structure ─────────────────────────

	# REVERSE: check pointer direction
	if _p["reverse"] and not _validate_reverse(): return

	# INSERT: check purple is wired between two nodes
	if _p["insert"] and _insert_node_id >= 0:
		if not _validate_insert_v3(): return

	# HEAD count
	var heads := _count_heads()
	if heads == 0:
		_stat["structural_err"] += 1
		_apply_wrong(_nodes[0]["sprite"] as Node2D, _p["penalty"],
			"Every car has an incoming pointer — there is no HEAD.\n"
			+ "Right-click one link to remove it and free a head node.")
		_mid_game_hint()
		return
	if heads > 1:
		_stat["structural_err"] += 1
		_guide_multiple_heads(_get_all_heads())
		_apply_wrong(_nodes[0]["sprite"] as Node2D, _p["penalty"],
			"%d cars have no incoming pointer — only ONE can be the HEAD.\n"
			+ "Right-click a link on one of the extra heads to merge them into the chain." % heads)
		_mid_game_hint()
		return

	# Reachability
	var head_id := _find_head()
	var reachable := _linear_traverse_count(head_id)
	if reachable != _nodes.size():
		_stat["structural_err"] += 1
		_guide_disconnected(_get_disconnected_ids(head_id))
		_apply_wrong(_data_by_id(head_id)["sprite"] as Node2D, _p["penalty"],
			"Only %d of %d cars reachable from HEAD.\n"
			+ "Some cars are not in the chain — connect every car." \
			% [reachable, _nodes.size()])
		_mid_game_hint()
		return

	if _p["concept"] == "INSERT":
		_show_insert_cost_comparison()

	_complete = true
	_play_completion()

func _show_insert_cost_comparison() -> void:
	var position_idx := 0
	var head_id := _find_head(); var cur := head_id; var visited: Dictionary = {}
	while cur >= 0 and cur not in visited:
		visited[cur] = true
		if cur == _insert_node_id: break
		position_idx += 1
		var d: Dictionary = _data_by_id(cur); if not d: break
		cur = d["next_id"]
	var n := _nodes.size()
	var array_cost := n - position_idx
	_hint_lbl.text = (
		"Insert complete!\n"
		+ "An array would have shifted %d item(s) — O(%d) work.\n" % [array_cost, array_cost]
		+ "The linked list changed 2 pointers — O(1) work.\n"
		+ "Same result. Completely different cost."
	)
	_hint_box.visible = true
	_cost_banner.text = "Array: O(%d)  vs  List: O(1)" % array_cost
	_cost_banner.add_theme_color_override("font_color", COL_CHEAP)
	_cost_banner.visible = true

func _get_all_heads() -> Array:
	var pointed_to: Dictionary = {}
	for data: Dictionary in _nodes:
		if data["next_id"] >= 0: pointed_to[data["next_id"]] = true
	var heads: Array = []
	for data: Dictionary in _nodes:
		if data["id"] not in pointed_to: heads.append(data["id"])
	return heads

func _get_disconnected_ids(head_id: int) -> Array:
	var visited: Dictionary = {}; var cur := head_id
	while cur >= 0 and cur not in visited:
		visited[cur] = true
		var d: Dictionary = _data_by_id(cur); if not d: break
		cur = d["next_id"]
	var disconnected: Array = []
	for data: Dictionary in _nodes:
		if data["id"] not in visited: disconnected.append(data["id"])
	return disconnected

# ─────────────────────────────────────────────────────────────────────────────
#  COMPLETION MOMENT
# ─────────────────────────────────────────────────────────────────────────────
func _play_completion() -> void:
	# Clear selection ring
	_set_selection(-1)
	AudioManager.play_sfx(PATH_SFX_WIN)
	var flash_rect := ColorRect.new()
	flash_rect.color   = Color(0.4, 1.0, 0.6, 0.0)
	flash_rect.size    = Vector2(1280, 720)
	flash_rect.z_index = 90
	add_child(flash_rect)
	var flash_tw := flash_rect.create_tween()
	flash_tw.tween_property(flash_rect, "color:a", 0.55, 0.12)
	flash_tw.tween_property(flash_rect, "color:a", 0.0, 0.55)
	flash_tw.tween_callback(flash_rect.queue_free)

	_complete_banner.visible = true
	_complete_banner.text    = "CHAIN COMPLETE!"
	_complete_banner.scale   = Vector2(0.1, 0.1)
	_complete_banner.global_position = Vector2(320, 290)
	var banner_tw := _complete_banner.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	banner_tw.tween_property(_complete_banner, "scale", Vector2(1.0, 1.0), 0.4)

	for data: Dictionary in _nodes:
		var nd := data["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		_burst_label(nd, "✓", COL_OK)
		await get_tree().create_timer(0.05).timeout

	var head_id := _find_head()
	if head_id >= 0:
		var hd: Dictionary = _data_by_id(head_id)
		if not hd.is_empty(): _apply_correct(hd["sprite"] as Node2D, 60)

	_task_lbl.text = "✓ Valid linked list built!"
	# Drive all cars off the right edge — train departs!
	var delay := 0.0
	var head_ord := _find_head()
	var cur_id := head_ord; var vis: Dictionary = {}
	while cur_id >= 0 and cur_id not in vis:
		vis[cur_id] = true
		var dd: Dictionary = _data_by_id(cur_id)
		if dd.is_empty(): break
		var car := dd["sprite"] as Node2D
		if is_instance_valid(car):
			var tw_car := car.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tw_car.tween_interval(delay)
			tw_car.tween_property(car, "global_position:x", 1500.0, 0.7)
			# Also drive port container
			if dd.has("port") and is_instance_valid(dd["port"] as Node2D):
				var tw_p := (dd["port"] as Node2D).create_tween()
				tw_p.tween_interval(delay)
				tw_p.tween_property(dd["port"] as Node2D, "global_position:x", 1500.0, 0.7)
		delay += 0.08
		cur_id = (dd["next_id"] as int)
	await get_tree().create_timer(1.2).timeout
	var _s2 := _build_stats(true)
	GameRouter.chapter_complete(_chapter_id, int(_s2["score"]), int(_s2["stars"]))

# ─────────────────────────────────────────────────────────────────────────────
#  VALIDATION
# ─────────────────────────────────────────────────────────────────────────────
func _validate_reverse() -> bool:
	if _original_order.is_empty(): return true
	# Don't penalise until the player has changed at least one link.
	# The pre-built chain is forward — it fails the check immediately.
	if _player_link_actions == 0:
		_hint_lbl.text = (
			"The chain currently points FORWARD.\n"
			+ "Right-click each link to remove it, then re-draw it backward.\n"
			+ "Faint arrows show the target direction.")
		_hint_box.visible = true
		return false
	var head_id := _find_head()
	if head_id < 0:
		_stat["wrong_reverse"] += 1
		_apply_wrong(_nodes[0]["sprite"] as Node2D, _p["penalty"],
			"Reverse created a cycle — no HEAD found.\n"
			+ "One car must have no incoming pointer.\n"
			+ "Right-click a link to break the loop.")
		return false
	var current: Array = []; var cur: int = head_id; var visited: Dictionary = {}
	while cur >= 0 and cur not in visited:
		visited[cur] = true; current.append(cur)
		var d: Dictionary = _data_by_id(cur); if not d: break
		cur = d["next_id"]
	var expected := _original_order.duplicate(); expected.reverse()
	if current == expected: return true
	_stat["wrong_reverse"] += 1
	_apply_wrong(_nodes[0]["sprite"] as Node2D, _p["penalty"],
		"Not fully reversed yet.\n"
		+ "Each car should point to the car that USED to point to it.\n"
		+ "Right-click any wrong link to remove it, then re-draw it backward.")
	_mid_game_hint()
	return false

func _validate_insert_v3() -> bool:
	var ins: Dictionary = _data_by_id(_insert_node_id)
	if ins.is_empty(): return true
	var prev_id: int = -1
	for data: Dictionary in _nodes:
		if data["next_id"] == _insert_node_id: prev_id = data["id"]; break
	var next_id: int = ins["next_id"]
	# Success — purple is fully wired in between two nodes
	if prev_id >= 0 and next_id >= 0:
		ins["staged"] = false; _insert_node_id = -1; return true
	# Still in progress — give a hint in the hint box but NO penalty and NO stat
	# _validate_insert_v3 is called on every link action; penalising here
	# means every correct link to a non-purple node triggers a wrong-answer.
	if prev_id < 0 and next_id < 0:
		_hint_lbl.text = (
			"Purple car is not wired in yet.\n"
			+ "Pattern: ExistingA → Purple → ExistingB\n"
			+ "Right-click A's current link, redraw it to Purple, then drag Purple → B.")
	elif prev_id < 0:
		_hint_lbl.text = (
			"One more step: a car must point TO the purple car.\n"
			+ "Right-click the car before the gap and redraw its link to purple.")
	else:
		_hint_lbl.text = (
			"One more step: drag Purple's ▶ to the next car in the chain.")
	_hint_box.visible = true
	return false

# ─────────────────────────────────────────────────────────────────────────────
#  GRAPH HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _count_heads() -> int:
	var pointed_to: Dictionary = {}
	for data: Dictionary in _nodes:
		if data["next_id"] >= 0: pointed_to[data["next_id"]] = true
	var c := 0
	for data: Dictionary in _nodes:
		if data["id"] not in pointed_to: c += 1
	return c

func _count_links() -> int:
	var c := 0
	for data: Dictionary in _nodes:
		if data["next_id"] >= 0: c += 1
	return c

func _linear_traverse_count(start_id: int) -> int:
	var visited: Dictionary = {}; var cur := start_id
	while cur >= 0 and cur not in visited:
		visited[cur] = true
		var d: Dictionary = _data_by_id(cur); if not d: break
		cur = d["next_id"]
	return visited.size()

func _has_cycle() -> bool:
	if _nodes.is_empty(): return false
	var slow: int = _nodes[0]["id"]; var fast: int = _nodes[0]["id"]
	for _i in range(_nodes.size() * 2):
		var sd: Dictionary = _data_by_id(slow); if not sd or sd["next_id"] < 0: return false
		var fd: Dictionary = _data_by_id(fast); if not fd or fd["next_id"] < 0: return false
		var fd2: Dictionary = _data_by_id(fd["next_id"]); if not fd2 or fd2["next_id"] < 0: return false
		slow = sd["next_id"] as int; fast = fd2["next_id"]
		if slow == fast: return true
	return false

func _ids_to_addrs(ids: Array) -> String:
	var parts: Array[String] = []
	for id: int in ids:
		var d: Dictionary = _data_by_id(id)
		parts.append(d["addr"] if not d.is_empty() else "?")
	return " → ".join(parts)

# ─────────────────────────────────────────────────────────────────────────────
#  UNLINK (right-click)
# ─────────────────────────────────────────────────────────────────────────────
func _try_unlink(pos: Vector2) -> void:
	for data: Dictionary in _nodes:
		var nd := data["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		if nd.global_position.distance_to(pos) > NODE_HIT: continue
		if data["next_id"] < 0:
			# Node has no link — tell the player rather than silently doing nothing
			_float_label(nd, "no link to remove", COL_HINT)
			return
		if data["arrow"] and is_instance_valid(data["arrow"] as Node2D):
			(data["arrow"] as Node2D).queue_free()
		data["arrow"]   = null
		data["next_id"] = -1
		_player_link_actions += 1
		_float_label(nd, "link removed", COL_WRONG)
		AudioManager.play_sfx(PATH_SFX_FAIL)
		_update_all_node_visuals()
		_clear_gap_indicators()
		# Restore hint to reminder after unlink
		_hint_lbl.text = _unlink_reminder_text()
		return

# ─────────────────────────────────────────────────────────────────────────────
#  DELETE NODE
# ─────────────────────────────────────────────────────────────────────────────
func _try_delete_return(pos: Vector2) -> bool:
	for data: Dictionary in _nodes:
		var nd := data["sprite"] as Node2D
		if is_instance_valid(nd) and nd.global_position.distance_to(pos) < NODE_HIT:
			_delete_node(data["id"]); return true
	return false

func _delete_node(id: int) -> void:
	var data: Dictionary = _data_by_id(id); if not data: return
	for other: Dictionary in _nodes:
		if other["next_id"] == id: other["next_id"] = data["next_id"]
	if data["arrow"] and is_instance_valid(data["arrow"] as Node2D):
		(data["arrow"] as Node2D).queue_free()
	if data.has("port") and is_instance_valid(data["port"] as Node2D):
		(data["port"] as Node2D).queue_free()
	var nd := data["sprite"] as Node2D
	if is_instance_valid(nd):
		_apply_correct(nd, 10)
		var tw := nd.create_tween()
		tw.tween_property(nd, "scale", Vector2.ZERO, 0.25)
		tw.tween_callback(nd.queue_free)
	_nodes.erase(data)
	_redraw_all_arrows(); _update_all_node_visuals(); _check_completion()

# ─────────────────────────────────────────────────────────────────────────────
#  ARROW DRAWING
# ─────────────────────────────────────────────────────────────────────────────
func _draw_arrow(data: Dictionary) -> Line2D:
	if data["arrow"] and is_instance_valid(data["arrow"] as Node2D):
		(data["arrow"] as Node2D).queue_free()
	var dst: Dictionary = _data_by_id(data["next_id"])
	if dst.is_empty(): return null
	var src_nd := data["sprite"] as Node2D; var dst_nd := dst["sprite"] as Node2D
	if not is_instance_valid(src_nd) or not is_instance_valid(dst_nd): return null
	return _make_perm_line(src_nd.global_position + PORT_OFFSET, dst_nd.global_position)

func _redraw_all_arrows() -> void:
	for data: Dictionary in _nodes:
		if data["arrow"] and is_instance_valid(data["arrow"] as Node2D):
			(data["arrow"] as Node2D).queue_free(); data["arrow"] = null
		if data["next_id"] >= 0: data["arrow"] = _draw_arrow(data)

func _make_perm_line(from: Vector2, to: Vector2) -> Line2D:
	var line := Line2D.new()
	line.default_color = COL_ARROW
	line.width = 9.0
	var local_from := _arrow_layer.to_local(from)
	var local_to   := _arrow_layer.to_local(to)
	var dir := (local_to - local_from).normalized()
	line.add_point(local_from)
	line.add_point(local_to)
	line.add_point(local_to - dir * 20 + dir.rotated(deg_to_rad(140)) * 16)
	line.add_point(local_to)
	line.add_point(local_to - dir * 20 + dir.rotated(deg_to_rad(-140)) * 16)
	_arrow_layer.add_child(line)
	return line

func _make_temp_line(from: Vector2, to: Vector2) -> Line2D:
	var line := Line2D.new()
	line.default_color = COL_LIVE
	line.width = 7.0
	line.add_point(from)
	line.add_point(to)
	_arrow_layer.add_child(line)
	return line

func _node_at(pos: Vector2, exclude: int) -> int:
	for data: Dictionary in _nodes:
		if data["id"] == exclude: continue
		var nd := data["sprite"] as Node2D
		if is_instance_valid(nd) and nd.global_position.distance_to(pos) < SNAP_R:
			return data["id"]
	return -1

func _data_by_id(id: int):
	for data: Dictionary in _nodes:
		if data["id"] == id: return data
	return null

# ─────────────────────────────────────────────────────────────────────────────
#  FEEDBACK & ANIMATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _apply_correct(nd: Node2D, pts: int) -> void:
	_stat["correct"] += 1; _combo += 1; _combo_decay = COMBO_TTL
	var earned := pts * (1 + _combo / 5)
	_score += earned; _score_lbl.text = "Score: %d" % _score
	_combo_lbl.text = "×%d COMBO!" % _combo if _combo > 1 else ""
	_acc_lbl.text   = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd): _flash(nd, COL_OK); _bounce(nd); _float_label(nd, "+%d" % earned, COL_OK)
	AudioManager.play_sfx(PATH_SFX_OK)

func _apply_wrong(nd: Node2D, penalty: int, msg: String) -> void:
	_combo = 0; _combo_lbl.text = ""
	if penalty > 0: _score = max(0, _score - penalty); _score_lbl.text = "Score: %d" % _score
	_acc_lbl.text = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd): _flash(nd, COL_WRONG); _shake_node(nd)
	if not msg.is_empty(): _show_context_feedback(nd, msg)
	_lives -= 1; _refresh_lives()
	if _lives <= 0: _end_game(false)
	AudioManager.play_sfx(PATH_SFX_FAIL)

func _show_context_feedback(nd: Node2D, text: String) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new(); lbl.text = text; lbl.z_index = 200
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", COL_WRONG)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	lbl.custom_minimum_size = Vector2(280, 0)
	par.add_child(lbl); lbl.global_position = nd.global_position + Vector2(-60, -90)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -60), 2.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 2.0)
	tw.tween_callback(lbl.queue_free)

func _burst_label(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new(); lbl.text = text; lbl.z_index = 201
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", color)
	par.add_child(lbl); lbl.global_position = nd.global_position + Vector2(-10, -30)
	var tw := lbl.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "position", lbl.position + Vector2(randf_range(-30, 30), -60), 0.6)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tw.tween_callback(lbl.queue_free)

# v6: _flash restores _node_base_color instead of hardcoded COL_WHITE
func _flash(nd: Node2D, c: Color) -> void:
	if not is_instance_valid(nd): return
	var data: Dictionary = _data_by_id_sprite(nd)
	var restore := _node_base_color(data) if not data.is_empty() else COL_TRAIN_MID
	var tw := nd.create_tween()
	tw.tween_property(nd, "modulate", c, 0.06)
	tw.tween_property(nd, "modulate", restore, 0.28)

# Helper: find node data by sprite reference
func _data_by_id_sprite(nd: Node2D) -> Dictionary:
	for data: Dictionary in _nodes:
		if data["sprite"] == nd: return data
	return {}

func _bounce(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var s := nd.scale
	var tw := nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "scale", s * 1.35, 0.08); tw.tween_property(nd, "scale", s, 0.18)

func _shake_node(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var o := nd.position; var tw := nd.create_tween()
	for _i in range(6):
		tw.tween_property(nd, "position", o + Vector2(randf_range(-7, 7), randf_range(-4, 4)), 0.04)
	tw.tween_property(nd, "position", o, 0.04)

func _pulse_node(nd: Node2D, color: Color) -> void:
	if not is_instance_valid(nd): return
	var tw := nd.create_tween()
	for _i in range(4):
		tw.tween_property(nd, "modulate", color, 0.08)
		tw.tween_property(nd, "modulate", COL_WHITE, 0.08)

func _float_label(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new(); lbl.text = text; lbl.z_index = 200
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	par.add_child(lbl); lbl.global_position = nd.global_position + Vector2(-20, -44)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -40), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  CLOCK / HUD / ANALYTICS / END
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
		lbl.add_theme_font_size_override("font_size", 22)
		_lives_row.add_child(lbl)

func _accuracy() -> float:
	var total: int = int(_stat["correct"]) + int(_stat["bad_link"]) + int(_stat["wrong_reverse"]) + \
					  int(_stat["bad_insert"]) + int(_stat["structural_err"]) + int(_stat["cycle_missed"])
	return 100.0 if total == 0 else float(_stat["correct"]) / float(total) * 100.0

func _build_stats(success: bool) -> Dictionary:
	var grade: String = _calc_grade(success)
	return {
		"chapter_id":    _chapter_id,
		"score":         _score,
		"grade":         grade,
		"stars":         _grade_to_stars(grade),
		"success":       success,
		"accuracy":      _accuracy(),
		"correct":       _stat["correct"],
		"bad_link":      _stat["bad_link"],
		"wrong_reverse": _stat["wrong_reverse"],
		"bad_insert":    _stat["bad_insert"],
		"structural_err":_stat["structural_err"],
		"array_shifts":  _stat["array_shifts"],
	}

func _end_game(success: bool) -> void:
	if not _alive: return
	_set_selection(-1)
	_destroy_drag_ghost()
	_alive = false; _game_tmr.stop(); _stop_cycle_animation()
	var grade := _calc_grade(success)
	var summary := "✓ Grade: %s  Accuracy: %.0f%%" % [grade, _accuracy()] if success \
		else "✗ Grade: %s\n%s" % [grade, _dominant_mistake()]
	_fail_summary.visible = true; _fail_lbl.text = summary
	await get_tree().create_timer(3.0).timeout
	var _s3 := _build_stats(success)
	GameRouter.chapter_complete(_chapter_id, int(_s3["score"]), int(_s3["stars"]))

func _calc_grade(success: bool) -> String:
	var acc := _accuracy()
	if not success: return "C" if acc >= 60.0 else "F"
	if acc >= 95.0: return "S"
	if acc >= 82.0: return "A"
	if acc >= 68.0: return "B"
	return "C"

func _dominant_mistake() -> String:
	var ranked := [
		["bad_link",       "Tip: in a valid list, each node is pointed to by exactly ONE other node.\nIf two nodes point to the same target, right-click one to unlink it first."],
		["structural_err", "Tip: the list needs one HEAD (no incoming pointer) and a chain\nthat reaches every node exactly once before hitting NULL."],
		["wrong_reverse",  "Tip: to reverse, each node should point to the node that USED to point to it.\nRight-click existing links and re-draw them backward."],
		["bad_insert",     "Tip: inserting a node means wiring it BETWEEN two existing nodes:\nA → Purple → B.  Both connections are required."],
	]
	var best := "Keep practising — you are making progress!"; var best_cnt := 0
	for pair in ranked:
		var cnt: int = _stat[pair[0]]
		if cnt > best_cnt: best_cnt = cnt; best = pair[1]
	return best

func _grade_to_stars(grade: String) -> int:
	match grade:
		"S", "A": return 3
		"B":       return 2
		"C":       return 1
		_:         return 0
