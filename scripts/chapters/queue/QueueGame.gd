# =============================================================================
# AlgoQuest — Chapter 1: Kingdom Queue (FIFO) v5
# File: scripts/chapters/queue/QueueGame.gd
#
# TIER PROGRESSION — 5 tiers, one new mechanic per tier:
#
#  T0 — FIFO BASICS  (tutorial)
#       1 queue · 1 window · cap 4 · no patience · no timer
#       Teaches: enqueue at back, dequeue from front, FIFO order
#       New: peek (right-click), live [n/cap] counter, overflow/isEmpty badge
#
#  T1 — PEEK + SERVICE WINDOWS
#       1 queue · 3 typed windows · cap 4 · no patience · no timer
#       Teaches: peek-before-dequeue discipline, typed endpoint matching
#       New: 3 service windows, peek is REQUIRED before each dequeue
#
#  T2 — PATIENCE (time-bounded queue)
#       1 queue · 3 windows · cap 4 · patience 18s · no timer
#       Teaches: bounded-time queues, throughput vs latency, back-pressure
#       New: citizens leave when patience drains → life lost
#
#  T3 — PRIORITY QUEUE
#       1 queue · 3 windows · cap 5 · patience 14s · timer 120s
#       Teaches: sorted insert by key, O(n) cost, hold + restore
#       New: priority levels 1-3, O(n) insert label, hold slot fixed
#
#  T4 — EXPERT (lanes + monsters + fake signals)
#       3 queues · 1 window · cap 4 · patience 8s · timer 90s
#       Teaches: multi-lane routing, interrupt queues, deceptive signals
#       New: 3 lanes, monsters, fake VIP badges, all priority levels
#
# KEY FIXES vs v3:
#   - Peek fully implemented (right-click front citizen)
#   - Live [n/cap] counter + isEmpty badge per queue
#   - _restore_held_citizen called after every dequeue/defeat
#   - Priority insert shows sorted position + O(n) cost label
#   - Overflow label explains bounded-buffer concept
#   - _current_drop_gate resolved from window node map, not citizen data
#   - Monster escalation framed as "interrupt queue" concept
# =============================================================================

extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  ASSETS
# ─────────────────────────────────────────────────────────────────────────────
const PATH_FONT      := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_OK    := "res://assets/audio/sfx/success.ogg"
const PATH_SFX_FAIL  := "res://assets/audio/sfx/fail.ogg"
const PATH_SFX_BTN   := "res://assets/audio/sfx/button.ogg"
const PATH_BGM       := "res://assets/audio/bgm/street_laboratory.ogg"
const PATH_PARCHMENT := "res://assets/art/ui/parchment.png"

# ── Background parallax layers (back → front) ─────────────────────────────────
const PATH_BG_SKY     := "res://assets/art/bg/layer_5_sky.png"
const PATH_BG_MTN     := "res://assets/art/bg/layer_4_mountains.png"
const PATH_BG_CASTLE  := "res://assets/art/bg/layer_castle.png"
const PATH_BG_FAR     := "res://assets/art/bg/layer_3_trees_far.png"
const PATH_BG_MID     := "res://assets/art/bg/layer_2_trees_mid.png"
const PATH_BG_FRONT   := "res://assets/art/bg/layer_1_trees_front.png"
# Parallax scroll multipliers are embedded directly in _setup_bg layer_defs

# ── Animation frames — original multi-sprite assets ──────────────────────────
# idle  uses: {key}_idle_walk1.png, {key}_idle_stand.png, {key}_idle_walk2.png
# walk  uses: {key}_walk_walk1.png, {key}_walk_stand.png, {key}_walk_walk2.png
const ANIM_BASE:        String         = "res://assets/art/character/anim/"
const ANIM_FRAME_NAMES: Array[String] = ["walk1", "stand", "walk2"]
const IDLE_FPS := 3.0
const WALK_FPS := 8.0

const CITIZEN_ANIM_KEYS := {
	"noble":    ["noble_king", "noble_queen"],
	"merchant": ["merchant"],
	"peasant":  [
		"peasant_mid_man", "peasant_mid_woman",
		"peasant_young_man_a", "peasant_young_man_b",
		"peasant_young_woman_a", "peasant_young_woman_b",
		"peasant_boy", "peasant_girl",
	],
	"elder": ["elder_old_man", "elder_old_woman"],
}
const MONSTER_ANIM_KEYS := {
	"cultist":         "monster_cultist",
	"water_elemental": "monster_water_elemental",
	"wind_elemental":  "monster_wind_elemental",
	"earth_elemental": "monster_earth_elemental",
	"vampire":         "monster_vampire",
	"fire_elemental":  "monster_fire_elemental",
	"light_elemental": "monster_light_elemental",
	"dark_elemental":  "monster_dark_elemental",
}
const CITIZEN_KEYS: Array[String] = ["noble", "merchant", "peasant", "elder"]
const MONSTER_KEYS: Array[String] = [
	"cultist", "water_elemental", "wind_elemental", "earth_elemental",
	"vampire", "fire_elemental", "light_elemental", "dark_elemental",
]
const MONSTER_THREAT := {
	"cultist": 1, "water_elemental": 1, "wind_elemental": 1, "earth_elemental": 1,
	"vampire": 2, "fire_elemental": 2, "light_elemental": 2, "dark_elemental": 3,
}
const MONSTER_REWARD := {
	"cultist": 35, "water_elemental": 35, "wind_elemental": 35, "earth_elemental": 35,
	"vampire": 60, "fire_elemental": 60, "light_elemental": 60, "dark_elemental": 100,
}
const MONSTER_ICONS := {
	"cultist": "🔮", "water_elemental": "💧", "wind_elemental": "🌀",
	"earth_elemental": "🪨", "vampire": "🧛", "fire_elemental": "🔥",
	"light_elemental": "✨", "dark_elemental": "🌑",
}
const MONSTER_PENALTY      := 30
const MONSTER_SPAWN_CHANCE := [0.0, 0.0, 0.0, 0.0, 0.22]
const COL_MONSTER          := Color(1.0, 0.3, 0.3)
const COL_ESCALATED        := Color(1.0, 0.1, 0.6)
const ESCALATE_WARN        := 2.0
const COMBAT_SNAP          := 90.0

# ─────────────────────────────────────────────────────────────────────────────
#  SERVICE SYSTEM
# ─────────────────────────────────────────────────────────────────────────────
const SERVICES     := ["tax", "food", "permit"]
const SERVICE_ICON := { "tax": "💰", "food": "🍞", "permit": "📜" }
const SERVICE_COLOR := {
	"tax":    Color(0.35, 0.75, 1.0),
	"food":   Color(0.35, 1.0,  0.5),
	"permit": Color(1.0,  0.80, 0.35),
}
const LANE_SERVICE := { "a": "tax", "b": "food", "c": "permit" }

# ── Priority levels 0-4 ──────────────────────────────────────────────────────
# 0 = Normal (FIFO)
# 1 = VIP ⭐ — inserted ahead of 0s, O(n) scan
# 2 = Noble 👑 — inserted ahead of 0s and 1s
# 3 = Royal Decree 📜⚡
# 4 = Emergency 🚨 — absolute front
const PRIORITY_LABELS := {
	0: "",       1: "⭐ VIP",  2: "👑 NOBLE",
	3: "📜⚡ DECREE", 4: "🚨 EMERGENCY",
}
const PRIORITY_COLORS := {
	0: Color.WHITE,
	1: Color(1.0, 0.85, 0.1),
	2: Color(0.9, 0.5, 1.0),
	3: Color(1.0, 0.4, 0.2),
	4: Color(1.0, 0.1, 0.1),
}

# ─────────────────────────────────────────────────────────────────────────────
#  LAYOUT
# ─────────────────────────────────────────────────────────────────────────────
const SLOT_W       := 100.0
const FRONT_X      := 160.0
# ── Screen split: top 360px = world/background, bottom 360px = UI panel ──────
const SPLIT_Y      := 360.0   # divider between world and info panel
const GROUND_Y     := 320.0   # where character feet touch (within top half)
# Single-queue row sits at ground level
const ROW_A_Y      := 310.0
# Tri-queue lanes stagger upward from ground so all fit in the top half
const ROW_B_Y      := 310.0   # fallback (single queue tiers, lane B unused)
const ROW_C_Y      := 310.0   # fallback
const ROW_B_Y_TRI  := 220.0   # food lane
const ROW_C_Y_TRI  := 140.0   # permit lane (highest, near sky)
const C_SCALE      := Vector2(3.5, 3.5)
const SVC_X        := 55.0
const HIT_R        := 44.0
const SNAP_SVC     := 140.0
const WAIT_X_A     := 950.0
const WAIT_X_B     := 950.0
const WAIT_X_C     := 950.0
const WAIT_AREA_HIT := 60.0
const HOLD_X       := 55.0
const HOLD_Y       := 160.0

const COL_FRONT  := Color(0.3, 1.0, 0.3)
const COL_BACK   := Color(0.9, 0.9, 0.3)
const COL_WRONG  := Color(1.0, 0.15, 0.15)
const COL_WHITE  := Color.WHITE
const COL_PEEK   := Color(0.6, 0.9, 1.0)

const COL_OP_ENQUEUE := Color(0.4, 1.0, 0.5)
const COL_OP_DEQUEUE := Color(0.4, 0.8, 1.0)
const COL_OP_PEEK    := Color(0.8, 0.6, 1.0)
const COL_OP_OVER    := Color(1.0, 0.5, 0.1)

# ─────────────────────────────────────────────────────────────────────────────
#  TIER PARAMETERS  — 5 tiers, easiest to hardest
# ─────────────────────────────────────────────────────────────────────────────
# spawn_interval : seconds between citizen spawns (lower = harder)
# capacity       : max citizens in one queue
# patience       : seconds before citizen leaves (0 = infinite)
# penalty        : score penalty per mistake
# time_limit     : seconds for timed tiers (0 = unlimited)
# target_score   : score to win
# accuracy_target: minimum accuracy % to pass (0 = not checked)
# highlight_front: green-tint the front slot (scaffold for beginners)
# service_required: citizens carry a request tag
# tri_queue      : enable 3 separate lane queues
# multi_window   : 3 typed service windows (tax/food/permit)
# lane_routing   : player must route citizen to correct queue lane
# vip_events     : priority citizens can spawn
# fake_signals   : some VIP badges are fake (expert deception)
# tutorial       : run the step-by-step tutorial
# peek_required  : player must peek before each dequeue
# show_size_hud  : show live [n/cap] counter next to each queue
# max_priority   : highest priority level that can spawn (default 0)
# concept        : short name shown in intro screen
const TIER_PARAMS: Array[Dictionary] = [
	# ── TIER 0 ── FIFO BASICS ─────────────────────────────────────────────────
	# One queue, one window. No types, no timer, no patience.
	# Scaffolds: green front highlight, [n/cap] counter visible.
	# Player learns: enqueue at back, dequeue from front, FIFO order,
	#                peek (inspect without removing), overflow/isEmpty.
	{
		"concept":          "FIFO",
		"spawn_interval":   10.0,  "capacity":       4,
		"patience":         0.0,   "penalty":        0,
		"time_limit":       0.0,   "target_score":   120,
		"accuracy_target":  0.0,   "tutorial":       true,
		"highlight_front":  true,  "service_required": false,
		"tri_queue":        false, "multi_window":   false,
		"lane_routing":     false, "vip_events":     false,
		"fake_signals":     false, "peek_required":  false,
		"show_size_hud":    true,  "manual_enqueue": true,
		"monster_tutorial": false, "max_priority":   0,
	},
	# ── TIER 1 ── PEEK + SERVICE WINDOWS ─────────────────────────────────────
	# 1 queue, 3 typed windows. Citizens carry a request icon.
	# Peek is REQUIRED before every dequeue — wrong window = penalty.
	# Player learns: peek discipline, typed endpoint matching.
	{
		"concept":          "SERVICE",
		"spawn_interval":   8.5,   "capacity":       4,
		"patience":         0.0,   "penalty":        10,
		"time_limit":       0.0,   "target_score":   300,
		"accuracy_target":  60.0,  "tutorial":       false,
		"highlight_front":  true,  "service_required": true,
		"tri_queue":        false, "multi_window":   true,
		"lane_routing":     false, "vip_events":     false,
		"fake_signals":     false, "peek_required":  true,
		"show_size_hud":    true,  "manual_enqueue": true,
		"monster_tutorial": false, "max_priority":   0,
	},
	# ── TIER 2 ── PATIENCE (time-bounded queue) ───────────────────────────────
	# 1 queue, 3 windows, patience timer 18s. No game clock.
	# Citizens leave if not served → heart lost. Waiting area also drains.
	# Player learns: bounded-time queues, throughput vs latency.
	{
		"concept":          "PATIENCE",
		"spawn_interval":   7.0,   "capacity":       4,
		"patience":         18.0,  "penalty":        15,
		"time_limit":       0.0,   "target_score":   500,
		"accuracy_target":  60.0,  "tutorial":       false,
		"highlight_front":  false, "service_required": true,
		"tri_queue":        false, "multi_window":   true,
		"lane_routing":     false, "vip_events":     false,
		"fake_signals":     false, "peek_required":  true,
		"show_size_hud":    true,  "manual_enqueue": true,
		"monster_tutorial": false, "max_priority":   0,
	},
	# ── TIER 3 ── PRIORITY QUEUE ──────────────────────────────────────────────
	# 1 queue, 3 windows, patience 14s, game clock 120s.
	# Priority citizens (lvl 1-3) do sorted O(n) insertion.
	# Player learns: priority queue, sorted insert by key, O(n) cost,
	#                hold-and-restore when VIP displaces front citizen.
	{
		"concept":          "PRIORITY",
		"spawn_interval":   6.0,   "capacity":       5,
		"patience":         14.0,  "penalty":        20,
		"time_limit":       120.0, "target_score":   650,
		"accuracy_target":  62.0,  "tutorial":       false,
		"highlight_front":  false, "service_required": true,
		"tri_queue":        false, "multi_window":   true,
		"lane_routing":     false, "vip_events":     true,
		"fake_signals":     false, "peek_required":  true,
		"show_size_hud":    true,  "manual_enqueue": true,
		"monster_tutorial": false, "max_priority":   3,
	},
	# ── TIER 4 ── EXPERT (lanes + monsters + fake signals) ────────────────────
	# 3 queues (tax/food/permit), 1 shared window. Short patience (8s), 90s timer.
	# Monsters escalate to front (interrupt queue concept).
	# Some VIP badges are fake — player must peek to verify before dequeuing.
	# Player learns: multi-lane routing, interrupt queues, fake signals,
	#                decision under pressure with all rules active.
	{
		"concept":          "EXPERT",
		"spawn_interval":   4.5,   "capacity":       4,
		"patience":         8.0,   "penalty":        40,
		"time_limit":       90.0,  "target_score":   1000,
		"accuracy_target":  65.0,  "tutorial":       false,
		"highlight_front":  false, "service_required": true,
		"tri_queue":        true,  "multi_window":   false,
		"lane_routing":     true,  "vip_events":     true,
		"fake_signals":     true,  "peek_required":  true,
		"show_size_hud":    true,  "manual_enqueue": true,
		"monster_tutorial": true,  "max_priority":   4,
	},
]

# ─────────────────────────────────────────────────────────────────────────────
#  NODE REFS
# ─────────────────────────────────────────────────────────────────────────────
@onready var _bg:            Sprite2D       = $Background
@onready var _line_a:        Node2D         = $QueueLine_A
@onready var _line_b:        Node2D         = $QueueLine_B
@onready var _svc_a:         Node2D         = $ServiceWindow_A
@onready var _svc_b:         Node2D         = $ServiceWindow_B
@onready var _combat_a:      Node2D         = $CombatWindow_A
@onready var _combat_b:      Node2D         = $CombatWindow_B
@onready var _arrow_a:       Node2D         = $FrontArrow_A
@onready var _arrow_b:       Node2D         = $FrontArrow_B
@onready var _drag_ghost:    Node2D         = $DragGhost
@onready var _spawn_tmr:     Timer          = $SpawnTimer
@onready var _game_tmr:      Timer          = $GameTimer
@onready var _tut_blocker:   ColorRect      = $TutorialBlocker
# HUD
@onready var _score_lbl:     Label          = $HUD/ScoreLabel
@onready var _combo_lbl:     Label          = $HUD/ComboLabel
@onready var _timer_lbl:     Label          = $HUD/TimerLabel
@onready var _goal_lbl:      Label          = $HUD/GoalLabel
@onready var _acc_lbl:       Label          = $HUD/AccuracyLabel
@onready var _lives_row:     HBoxContainer  = $HUD/LivesRow
@onready var _hint_lbl:      Label          = $HUD/HintBox/HintLabel
@onready var _hint_box:      PanelContainer = $HUD/HintBox
@onready var _svc_row:       HBoxContainer  = $HUD/ServiceRow
@onready var _lane_lbl_a:    Label          = $HUD/LaneLabel_A
@onready var _lane_lbl_b:    Label          = $HUD/LaneLabel_B
@onready var _vip_alert:     PanelContainer = $HUD/VIPAlert
@onready var _vip_lbl:       Label          = $HUD/VIPAlert/VIPLabel
@onready var _monster_alert: PanelContainer = $HUD/MonsterAlert
@onready var _monster_lbl:   Label          = $HUD/MonsterAlert/MonsterLabel
@onready var _fail_summary:  PanelContainer = $HUD/FailSummary
@onready var _fail_lbl:      Label          = $HUD/FailSummary/FailLabel

# Dynamically created nodes
var _op_lbl:        Label          = null
var _front_lbl_a:   Label          = null
var _back_lbl_a:    Label          = null
var _front_lbl_b:   Label          = null
var _back_lbl_b:    Label          = null
var _wait_lbl_a:    Label          = null
var _wait_lbl_b:    Label          = null
var _overflow_lbl:  Label          = null
var _peek_panel:    PanelContainer = null
var _peek_lbl:      Label          = null
# Live size counters per queue  [n/cap]
var _size_lbl_a:    Label          = null
var _size_lbl_b:    Label          = null
var _size_lbl_c:    Label          = null
# isEmpty badges
var _empty_lbl_a:   Label          = null
var _empty_lbl_b:   Label          = null
var _empty_lbl_c:   Label          = null

# ─────────────────────────────────────────────────────────────────────────────
#  RUNTIME STATE
# ─────────────────────────────────────────────────────────────────────────────
var _p: Dictionary = {}

var _queue_a:   Array = []
var _queue_b:   Array = []
var _queue_c:   Array = []
var _waiting_a: Array = []
var _waiting_b: Array = []
var _waiting_c: Array = []

# VIP hold slot — citizen displaced from front while priority citizen is served
var _hold_slot:  Dictionary = {}
var _hold_which: String      = ""   # which queue the hold came from
var _hold_node:  Node2D      = null

var _monster_tut_done:  bool  = false
var _monster_tut_timer: float = 0.0
var _vip_tut_done:      bool  = false
var _fifo_correct_count: int  = 0

# Peek state — track which citizen was last peeked per queue
var _peeked_uid: Dictionary = {}   # { "a": uid, "b": uid, "c": uid }
var _peek_active: bool = false

var _extra_windows: Dictionary = {}  # svc type → Node2D for multi_window tiers
# Maps window Node2D → service type string (used for drop detection)
var _window_type_map: Dictionary = {}

var _patience_t:   Dictionary = {}
var _uid:          int        = 0
var _escalation_t: Dictionary = {}
var _monster_ids:  Dictionary = {}
var _frames_cache: Dictionary = {}

var _drag_node:   Node2D     = null
var _drag_data:   Dictionary = {}
var _drag_from:   String     = ""
var _drag_offset: Vector2    = Vector2.ZERO
var _is_dragging: bool       = false
var _overlay_tween: Tween    = null   # controls the auto-fading overlay hint

var _stat := {
	"correct":          0,
	"fifo_violation":   0,
	"service_miss":     0,
	"lane_miss":        0,
	"vip_ignored":      0,
	"patience_lost":    0,
	"monster_defeated": 0,
	"monster_escaped":  0,
	"monster_blocked":  0,
	"enqueue_count":    0,
	"dequeue_count":    0,
	"overflow_count":   0,
	"mid_insert_block": 0,
	"peek_count":       0,
	"peek_miss":        0,
}

var _score:       int   = 0
var _combo:       int   = 0
var _lives:       int   = 3
var _combo_decay: float = 0.0
const COMBO_TTL         := 3.0

var _time_left: float = 0.0
var _alive:     bool  = false

var _tut_step:   int  = 0
var _tut_locked: bool = false

var _pixel_font: Font = null

# ── Background parallax layer nodes (built at runtime in _setup_bg) ───────────
var _bg_layers: Array = []   # Array of { "sprite": Sprite2D, "scroll": float, "base_x": float }

# ── Algorithm panel — right-side live pseudocode + array view ────────────────
var _algo_panel:      PanelContainer = null
var _algo_array_lbl:  Label          = null   # shows queue as  [ A | B | C | _ ]
var _algo_code_lbl:   Label          = null   # highlights the pseudocode line just run
var _algo_explain_lbl: Label         = null   # one-sentence plain-English explanation
var _algo_last_op:    String         = ""     # "enqueue" | "dequeue" | "peek" | "overflow"

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font
	var tier := 0
	# GameRouter.current_chapter is set to the correct chapter_id BEFORE
	# change_scene_to_file() is called, making it the single reliable source
	# of truth. tier_in_family() converts chapter_id → 0-based tier index.
	# This replaces the fragile pending_tier meta approach entirely.
	if has_node("/root/GameRouter"):
		var chapter_id: int = GameRouter.current_chapter
		# Queue chapters are 1-5; tier = chapter_id - 1 (family starts at 1)
		if chapter_id >= 1 and chapter_id <= 5:
			tier = chapter_id - 1
		# else: non-queue chapter loaded this scene directly — keep tier 0
	elif has_node("/root/PlayerProfile") and PlayerProfile.is_loaded():
		# No GameRouter — derive from highest consecutive complete chapter.
		for ch_id in range(1, 6):
			if (PlayerProfile.get_chapter_data(ch_id).get("complete", false) as bool):
				tier = ch_id
			else:
				break
		tier = clamp(tier, 0, 4)
	_p = TIER_PARAMS[clamp(tier, 0, TIER_PARAMS.size() - 1)]

	_create_dynamic_nodes()
	_setup_bg()
	_setup_hud()
	_setup_monster_hud()
	_setup_service_buttons()
	_setup_timers()
	_setup_layout_for_tier()

	_drag_ghost.visible   = false
	_vip_alert.visible    = false
	_fail_summary.visible = false
	_tut_blocker.visible  = false
	_overflow_lbl.visible = false
	_op_lbl.visible       = false
	if is_instance_valid(_peek_panel):  _peek_panel.visible  = false
	if is_instance_valid(_algo_panel):  _algo_panel.visible  = true

	AudioManager.play_bgm(PATH_BGM)
	_alive = true

	if _p["tutorial"]:
		_run_tutorial()
	else:
		_show_concept_intro()

# ─────────────────────────────────────────────────────────────────────────────
#  DYNAMIC NODE CREATION
# ─────────────────────────────────────────────────────────────────────────────
func _create_dynamic_nodes() -> void:
	var hud := get_node("HUD") as Node

	# Operation label — large centred fade-out
	_op_lbl = Label.new()
	_op_lbl.name = "OperationLabel"
	_op_lbl.z_index = 300
	_op_lbl.global_position = Vector2(380, 390)   # bottom half centre
	_op_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(_op_lbl)

	var make_lbl := func(lbl_name: String, text: String, pos: Vector2, color: Color) -> Label:
		var l := Label.new()
		l.name = lbl_name; l.text = text; l.z_index = 50
		l.global_position = pos
		l.add_theme_color_override("font_color", color)
		hud.add_child(l)
		return l

	var cap: int = _p["capacity"]
	var tri_mode: bool = _p.get("tri_queue", false)
	var row_b: float = ROW_B_Y_TRI if tri_mode else _row_y("b")
	var row_c: float = ROW_C_Y_TRI if tri_mode else _row_y("c")

	_front_lbl_a = make_lbl.call("FrontLabel_A", "◀ DEQUEUE\nFRONT",
		Vector2(FRONT_X - 60, ROW_A_Y - 75), COL_FRONT)
	_back_lbl_a  = make_lbl.call("BackLabel_A",  "ENQUEUE\nBACK ▶",
		Vector2(FRONT_X + float(cap) * SLOT_W + 10.0, ROW_A_Y - 75.0), COL_BACK)
	_front_lbl_b = make_lbl.call("FrontLabel_B", "◀ DEQUEUE\nFRONT",
		Vector2(FRONT_X - 60, row_b - 75), COL_FRONT)
	_back_lbl_b  = make_lbl.call("BackLabel_B",  "ENQUEUE\nBACK ▶",
		Vector2(FRONT_X + float(cap) * SLOT_W + 10.0, row_b - 75.0), COL_BACK)
	_wait_lbl_a  = make_lbl.call("WaitLabel_A", "WAITING\nAREA",
		Vector2(WAIT_X_A - 20, ROW_A_Y - 80), Color(0.8, 0.8, 0.8))
	_wait_lbl_b  = make_lbl.call("WaitLabel_B", "WAITING\nAREA",
		Vector2(WAIT_X_B - 20, row_b - 80), Color(0.8, 0.8, 0.8))

	_overflow_lbl = make_lbl.call("OverflowLabel",
		"⚠ QUEUE FULL — OVERFLOW\nBounded buffer: fixed capacity reached.\nDEQUEUE from front to make room!",
		Vector2(300, 375), COL_OP_OVER)

	# ── Live size counter labels ──────────────────────────────────────────────
	_size_lbl_a  = make_lbl.call("SizeLbl_A", "[0/%d]" % cap,
		Vector2(FRONT_X - 10, ROW_A_Y - 100), Color(0.7, 0.9, 1.0))
	_size_lbl_b  = make_lbl.call("SizeLbl_B", "[0/%d]" % cap,
		Vector2(FRONT_X - 10, row_b - 100), Color(0.7, 0.9, 1.0))
	_size_lbl_c  = make_lbl.call("SizeLbl_C", "[0/%d]" % cap,
		Vector2(FRONT_X - 10, row_c - 100), Color(0.7, 0.9, 1.0))

	# isEmpty badges
	_empty_lbl_a = make_lbl.call("EmptyLbl_A", "EMPTY",
		Vector2(FRONT_X + 20, ROW_A_Y - 20), Color(0.5, 0.5, 0.5))
	_empty_lbl_b = make_lbl.call("EmptyLbl_B", "EMPTY",
		Vector2(FRONT_X + 20, row_b - 20), Color(0.5, 0.5, 0.5))
	_empty_lbl_c = make_lbl.call("EmptyLbl_C", "EMPTY",
		Vector2(FRONT_X + 20, row_c - 20), Color(0.5, 0.5, 0.5))

	# ── Peek panel ────────────────────────────────────────────────────────────
	_peek_panel = PanelContainer.new()
	_peek_panel.name    = "PeekPanel"
	_peek_panel.z_index = 250
	_peek_panel.position = Vector2(260, 80)
	var peek_style := StyleBoxFlat.new()
	peek_style.bg_color = Color(0.08, 0.06, 0.16, 0.94)
	peek_style.set_corner_radius_all(8)
	peek_style.content_margin_left   = 18.0
	peek_style.content_margin_right  = 18.0
	peek_style.content_margin_top    = 10.0
	peek_style.content_margin_bottom = 10.0
	_peek_panel.add_theme_stylebox_override("panel", peek_style)
	_peek_lbl = Label.new()
	_peek_lbl.name = "PeekLabel"
	_peek_lbl.add_theme_color_override("font_color", COL_PEEK)
	_peek_panel.add_child(_peek_lbl)
	hud.add_child(_peek_panel)

	# Priority legend — tier 3 (PRIORITY) and 4 (EXPERT)
	var tier_idx := TIER_PARAMS.find(_p)
	if tier_idx >= 3:
		var legend := Label.new()
		legend.name = "PriorityLegend"
		legend.text = "Priority: 0=Normal  1=⭐  2=👑  3=📜⚡  4=🚨"
		if _pixel_font: legend.add_theme_font_override("font", _pixel_font)
		legend.add_theme_font_size_override("font_size", 10)
		legend.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		legend.position = Vector2(200, 8)
		legend.z_index  = 50
		hud.add_child(legend)

	var tri: bool = _p.get("tri_queue", false)
	var mw:  bool = _p.get("multi_window", false)

	if mw:
		# Multi-window: three windows in a horizontal strip just above the ground line.
		# Spread evenly across the world width so the full play area stays open.
		# x positions: 160 (tax), 540 (food), 920 (permit) — roughly thirds of 1280px.
		var strip_y := GROUND_Y - 8.0
		var win_x   := [100.0,200.0,300.0]
		var win_types := ["tax", "food", "permit"]
		var food_nd  := Node2D.new(); add_child(food_nd)
		var permit_nd := Node2D.new(); add_child(permit_nd)
		var win_nodes: Array[Node2D] = [_svc_a, food_nd, permit_nd]
		for i in range(3):
			var nd: Node2D = win_nodes[i]
			_build_service_window_visual(nd, strip_y, "a", win_types[i])
			nd.position = Vector2(win_x[i], strip_y)
		_extra_windows = { "tax": _svc_a, "food": food_nd, "permit": permit_nd }
		_window_type_map[_svc_a]    = "tax"
		_window_type_map[food_nd]   = "food"
		_window_type_map[permit_nd] = "permit"
	elif tri:
		# Tri-queue: three lanes at staggered heights, shared window at mid-row
		_build_service_window_visual(_svc_a, ROW_A_Y, "a", "")
		_build_service_window_visual(_svc_b, ROW_B_Y_TRI, "b", "")
		_build_permit_window()
		var line_c := Node2D.new(); line_c.name = "QueueLine_C"; add_child(line_c)
		var arrow_c := Node2D.new()
		arrow_c.name = "FrontArrow_C"
		arrow_c.position = Vector2(FRONT_X, ROW_C_Y_TRI - 56)
		add_child(arrow_c)
		var ac_lbl := Label.new(); ac_lbl.text = "▼"; ac_lbl.position = Vector2(-6, 0)
		arrow_c.add_child(ac_lbl)
		_animate_front_arrow(arrow_c)
	else:
		_build_service_window_visual(_svc_a, ROW_A_Y, "a", "tax")

	_build_combat_window_visual(_combat_a, ROW_A_Y - 130.0)
	if _p.get("tri_queue", false):
		_build_combat_window_visual(_combat_b, ROW_B_Y_TRI - 130.0)
	if is_instance_valid(_combat_a): _combat_a.visible = false
	if is_instance_valid(_combat_b): _combat_b.visible = false

	# Hint box styling
	var hint := get_node_or_null("HUD/HintBox")
	if hint:
		var hc := hint as Control
		hc.anchor_left   = 0.0;  hc.anchor_right  = 0.58
		hc.anchor_top    = 0.5;  hc.anchor_bottom = 1.0
		hc.offset_left   = 8.0;  hc.offset_right  = -4.0
		hc.offset_top    = 4.0;  hc.offset_bottom = -4.0
		hc.z_index = 200
		hc.mouse_filter = Control.MOUSE_FILTER_STOP
		hc.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					_dismiss_hint()
		)
		if ResourceLoader.exists(PATH_PARCHMENT):
			var parch_tex := load(PATH_PARCHMENT) as Texture2D
			var style := StyleBoxTexture.new()
			style.texture = parch_tex
			style.content_margin_left   = 20.0; style.content_margin_right  = 20.0
			style.content_margin_top    = 12.0; style.content_margin_bottom = 12.0
			hc.add_theme_stylebox_override("panel", style)
			if is_instance_valid(_hint_lbl):
				_hint_lbl.add_theme_color_override("font_color", Color(0.15, 0.08, 0.02))
				_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_hint_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
				_hint_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
				_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_hint_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL
		else:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.12, 0.08, 0.02, 0.92)
			style.set_corner_radius_all(6)
			style.content_margin_left = 16.0; style.content_margin_right  = 16.0
			style.content_margin_top  = 10.0; style.content_margin_bottom = 10.0
			hc.add_theme_stylebox_override("panel", style)
			if is_instance_valid(_hint_lbl):
				_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				_hint_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
				_hint_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
				_hint_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				_hint_lbl.size_flags_vertical   = Control.SIZE_EXPAND_FILL

	# ── Algorithm panel — right side, always visible ──────────────────────────
	_build_algo_panel(hud)

# ─────────────────────────────────────────────────────────────────────────────
#  ALGORITHM PANEL  — live pseudocode + array view synced to every operation
# ─────────────────────────────────────────────────────────────────────────────
func _build_algo_panel(hud: Node) -> void:
	_algo_panel = PanelContainer.new()
	_algo_panel.name    = "AlgoPanel"
	_algo_panel.z_index = 60
	var c := _algo_panel as Control
	# Bottom-right quadrant of the bottom half
	c.anchor_left   = 0.6;  c.anchor_right  = 1.0
	c.anchor_top    = 0.5;  c.anchor_bottom = 1.0
	c.offset_left   = 4.0;  c.offset_right  = -8.0
	c.offset_top    = 4.0;  c.offset_bottom = -4.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.10, 0.92)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10.0; style.content_margin_right  = 10.0
	style.content_margin_top  = 8.0;  style.content_margin_bottom = 8.0
	_algo_panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_algo_panel.add_child(vbox)

	# Header
	var header := Label.new()
	header.text = "— queue state —"
	header.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	header.add_theme_font_size_override("font_size", 11)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: header.add_theme_font_override("font", _pixel_font)
	vbox.add_child(header)

	# Array view: [ A | B | C | _ ]
	_algo_array_lbl = Label.new()
	_algo_array_lbl.name = "AlgoArrayLbl"
	_algo_array_lbl.text = "[ empty ]"
	_algo_array_lbl.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	_algo_array_lbl.add_theme_font_size_override("font_size", 13)
	_algo_array_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_algo_array_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	if _pixel_font: _algo_array_lbl.add_theme_font_override("font", _pixel_font)
	vbox.add_child(_algo_array_lbl)

	# Index row: front=0, back=n-1
	var idx_lbl := Label.new()
	idx_lbl.name = "AlgoIdxLbl"
	idx_lbl.text = "↑ front=0"
	idx_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
	idx_lbl.add_theme_font_size_override("font_size", 10)
	idx_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if _pixel_font: idx_lbl.add_theme_font_override("font", _pixel_font)
	vbox.add_child(idx_lbl)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.3, 0.3, 0.4))
	vbox.add_child(sep)

	# Pseudocode header
	var code_hdr := Label.new()
	code_hdr.text = "— last operation —"
	code_hdr.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	code_hdr.add_theme_font_size_override("font_size", 11)
	code_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: code_hdr.add_theme_font_override("font", _pixel_font)
	vbox.add_child(code_hdr)

	# Pseudocode line — highlighted in colour
	_algo_code_lbl = Label.new()
	_algo_code_lbl.name = "AlgoCodeLbl"
	_algo_code_lbl.text = "—"
	_algo_code_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.5))
	_algo_code_lbl.add_theme_font_size_override("font_size", 12)
	_algo_code_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _pixel_font: _algo_code_lbl.add_theme_font_override("font", _pixel_font)
	vbox.add_child(_algo_code_lbl)

	# Plain-English explanation
	_algo_explain_lbl = Label.new()
	_algo_explain_lbl.name = "AlgoExplainLbl"
	_algo_explain_lbl.text = ""
	_algo_explain_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_algo_explain_lbl.add_theme_font_size_override("font_size", 11)
	_algo_explain_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _pixel_font: _algo_explain_lbl.add_theme_font_override("font", _pixel_font)
	vbox.add_child(_algo_explain_lbl)

	# Separator
	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.3, 0.3, 0.4))
	vbox.add_child(sep2)

	# Complexity line
	var complexity_hdr := Label.new()
	complexity_hdr.text = "— complexity —"
	complexity_hdr.add_theme_color_override("font_color", Color(0.5, 0.5, 0.7))
	complexity_hdr.add_theme_font_size_override("font_size", 11)
	complexity_hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: complexity_hdr.add_theme_font_override("font", _pixel_font)
	vbox.add_child(complexity_hdr)

	var complexity_lbl := Label.new()
	complexity_lbl.name = "AlgoComplexityLbl"
	complexity_lbl.text = "enqueue  O(1)\ndequeue  O(1)\npeek     O(1)\noverflow O(1) check"
	complexity_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	complexity_lbl.add_theme_font_size_override("font_size", 11)
	if _pixel_font: complexity_lbl.add_theme_font_override("font", _pixel_font)
	vbox.add_child(complexity_lbl)

	hud.add_child(_algo_panel)

# Call this after every enqueue / dequeue / peek / overflow to sync the panel
func _refresh_algo_panel(op: String, q: Array, extra: String = "") -> void:
	if not is_instance_valid(_algo_array_lbl): return
	var cap: int = _p["capacity"]

	# Build array string: [ 👤 | 👤 | 👤 | _ ]
	var parts: Array[String] = []
	for i in range(cap):
		if i < q.size():
			var d := q[i] as Dictionary
			var label: String
			if d.get("is_monster", false):
				label = MONSTER_ICONS.get(d.get("type", ""), "👾")
			else:
				var req: String = d.get("request", "")
				label = SERVICE_ICON.get(req, "👤") if req != "" else "👤"
			# Mark front and back
			if i == 0:   label = "▶" + label
			if i == q.size() - 1 and q.size() > 1: label = label + "◀"
			parts.append(label)
		else:
			parts.append("_")
	_algo_array_lbl.text = "[ " + " | ".join(parts) + " ]"

	# Update index row
	var idx_nd := _algo_panel.get_node_or_null("*/AlgoIdxLbl")
	if not idx_nd:
		# find by iterating vbox children
		var vb := _algo_panel.get_child(0)
		for child in vb.get_children():
			if child.name == "AlgoIdxLbl":
				idx_nd = child; break
	if idx_nd and idx_nd is Label:
		var idx_lbl2 := idx_nd as Label
		if q.is_empty():
			idx_lbl2.text = "isEmpty() = true"
			idx_lbl2.add_theme_color_override("font_color", Color(1.0, 0.5, 0.3))
		else:
			idx_lbl2.text = "front[0]  back[%d]  size=%d" % [q.size()-1, q.size()]
			idx_lbl2.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))

	# Pseudocode line + colour + explanation
	var code_text: String
	var code_col:  Color
	var explain:   String
	match op:
		"enqueue":
			code_text = "queue[back] = item\nback = (back + 1) % cap\nsize += 1"
			code_col  = COL_OP_ENQUEUE
			explain   = "Item added at the BACK.\nFront pointer unchanged — O(1)." + \
						("\n" + extra if extra != "" else "")
		"enqueue_priority":
			code_text = "scan from front → find pos\nqueue.insert(pos, item)\nsize += 1"
			code_col  = Color(1.0, 0.85, 0.1)
			explain   = "Priority insert: scan until a lower-\npriority item is found.\n" + extra
		"dequeue":
			code_text = "item = queue[front]\nfront = (front + 1) % cap\nsize -= 1\nreturn item"
			code_col  = COL_OP_DEQUEUE
			explain   = "Item removed from the FRONT.\nBack pointer unchanged — O(1)."
		"peek":
			code_text = "return queue[front]  ← no removal\n(front and size unchanged)"
			code_col  = COL_OP_PEEK
			explain   = "Read front without removing it.\nDestructive? No. Cost? O(1)."
		"overflow":
			code_text = "if size == cap:\n    raise OverflowError"
			code_col  = COL_OP_OVER
			explain   = "Bounded buffer full [%d/%d].\nMust dequeue before enqueuing." % \
						[q.size(), cap]
		"isEmpty":
			code_text = "return size == 0"
			code_col  = Color(0.6, 0.6, 0.6)
			explain   = "Queue is empty — nothing at front.\nDequeue would raise UnderflowError."
		_:
			return

	if is_instance_valid(_algo_code_lbl):
		_algo_code_lbl.text = code_text
		_algo_code_lbl.add_theme_color_override("font_color", code_col)
	if is_instance_valid(_algo_explain_lbl):
		_algo_explain_lbl.text = explain

	# Update complexity label when priority insert happens
	var vb2 := _algo_panel.get_child(0) if is_instance_valid(_algo_panel) else null
	if vb2:
		for child in vb2.get_children():
			if child.name == "AlgoComplexityLbl" and child is Label:
				var c_lbl := child as Label
				if op == "enqueue_priority":
					c_lbl.text = "enqueue  O(1)  ← normal\nenqueue  O(n)  ← priority\ndequeue  O(1)\npeek     O(1)"
				else:
					c_lbl.text = "enqueue  O(1)\ndequeue  O(1)\npeek     O(1)\noverflow O(1) check"
				break

# ─────────────────────────────────────────────────────────────────────────────
#  SERVICE / COMBAT WINDOW VISUALS
# ─────────────────────────────────────────────────────────────────────────────
func _build_service_window_visual(svc_node: Node2D, row_y: float,
		_which: String, svc_type: String = "tax") -> void:
	if not is_instance_valid(svc_node): return
	svc_node.position = Vector2(SVC_X, row_y)
	var col: Color   = SERVICE_COLOR.get(svc_type, Color(0.4, 0.8, 1.0))
	var icon: String = SERVICE_ICON.get(svc_type, "🏛")
	var lbl_text     := svc_type.to_upper() + "\nWINDOW"

	var border := ColorRect.new(); border.color = col.darkened(0.2)
	border.size = Vector2(100, 84); border.position = Vector2(-50, -42); border.z_index = 4
	svc_node.add_child(border)

	var box := ColorRect.new(); box.color = col.darkened(0.6)
	box.size = Vector2(96, 80); box.position = Vector2(-48, -40); box.z_index = 5
	svc_node.add_child(box)

	var icon_lbl := Label.new(); icon_lbl.text = icon
	icon_lbl.add_theme_font_size_override("font_size", 24)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.position = Vector2(-14, -36); icon_lbl.z_index = 6
	svc_node.add_child(icon_lbl)

	var txt_lbl := Label.new(); txt_lbl.text = lbl_text
	if _pixel_font: txt_lbl.add_theme_font_override("font", _pixel_font)
	txt_lbl.add_theme_font_size_override("font_size", 9)
	txt_lbl.add_theme_color_override("font_color", col.lightened(0.4))
	txt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt_lbl.position = Vector2(-34, 4); txt_lbl.z_index = 6
	svc_node.add_child(txt_lbl)

	# Tracker chip — replaces the static ◀ DROP label.
	# Shows live "✓ N served" count; incremented by _increment_window_tracker().
	var chip_bg := ColorRect.new()
	chip_bg.color    = col.darkened(0.65); chip_bg.color.a = 0.88
	chip_bg.size     = Vector2(84, 18); chip_bg.position = Vector2(-42, -62)
	chip_bg.name     = "TrackerBg"; chip_bg.z_index = 6
	svc_node.add_child(chip_bg)

	var tracker_lbl := Label.new()
	tracker_lbl.text = "✓ 0 served"
	tracker_lbl.name = "TrackerLabel"
	if _pixel_font: tracker_lbl.add_theme_font_override("font", _pixel_font)
	tracker_lbl.add_theme_font_size_override("font_size", 9)
	tracker_lbl.add_theme_color_override("font_color", col.lightened(0.5))
	tracker_lbl.position = Vector2(-38, -62); tracker_lbl.z_index = 7
	svc_node.add_child(tracker_lbl)

func _build_permit_window() -> void:
	var svc_c := Node2D.new(); svc_c.name = "ServiceWindow_C"; add_child(svc_c)
	_build_service_window_visual(svc_c, _row_y("c"), "c", "permit")

func _build_combat_window_visual(combat_node: Node2D, row_y: float) -> void:
	if not is_instance_valid(combat_node): return
	combat_node.global_position = Vector2(SVC_X, row_y - 70)
	var border := ColorRect.new(); border.color = Color(0.6, 0.1, 0.1, 0.7)
	border.size = Vector2(100, 84); border.position = Vector2(-50, -42); border.z_index = 4
	combat_node.add_child(border)
	var box := ColorRect.new(); box.color = Color(0.15, 0.04, 0.04, 0.88)
	box.size = Vector2(96, 80); box.position = Vector2(-48, -40); box.z_index = 5
	combat_node.add_child(box)
	var icon_lbl := Label.new(); icon_lbl.text = "⚔"
	icon_lbl.add_theme_font_size_override("font_size", 28)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.position = Vector2(-16, -36); icon_lbl.z_index = 6
	combat_node.add_child(icon_lbl)
	var txt_lbl := Label.new(); txt_lbl.text = "COMBAT\nWINDOW"
	if _pixel_font: txt_lbl.add_theme_font_override("font", _pixel_font)
	txt_lbl.add_theme_font_size_override("font_size", 9)
	txt_lbl.add_theme_color_override("font_color", Color(1.0, 0.6, 0.6))
	txt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	txt_lbl.position = Vector2(-34, 4); txt_lbl.z_index = 6
	combat_node.add_child(txt_lbl)

# ─────────────────────────────────────────────────────────────────────────────
#  SETUP HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _setup_bg() -> void:
	# Top half = world (0–360px). Layers are scaled to fill 1280×360.
	# Ground layers are bottom-anchored at SPLIT_Y so trees sit right at the divider.
	# Bottom half (360–720) is the UI info panel — built in _build_info_panel().
	#
	# Layer order back→front:
	#   z=-10  sky        (fills 1280×360, no parallax)
	#   z=-9   mountains  (bottom-anchored to SPLIT_Y)
	#   z=-8   castle
	#   z=-7   far trees
	#   z=-6   mid trees
	#   z=-5   front trees

	var layer_defs: Array[Dictionary] = [
		{ "path": PATH_BG_SKY,    "z": -10, "scroll": 0.00, "y_anchor": 0.5 },
		{ "path": PATH_BG_MTN,    "z": -9,  "scroll": 0.05, "y_anchor": 1.0 },
		{ "path": PATH_BG_CASTLE, "z": -8,  "scroll": 0.08, "y_anchor": 1.0 },
		{ "path": PATH_BG_FAR,    "z": -7,  "scroll": 0.15, "y_anchor": 1.0 },
		{ "path": PATH_BG_MID,    "z": -6,  "scroll": 0.25, "y_anchor": 1.0 },
		{ "path": PATH_BG_FRONT,  "z": -5,  "scroll": 0.40, "y_anchor": 1.0 },
	]

	# Source images: 1024×346. Scale to fill 1280 wide × SPLIT_Y tall.
	const SRC_W := 1024.0
	const SRC_H := 346.0
	const DST_W := 1280.0
	var scale_x := DST_W / SRC_W          # ~1.25
	var scale_y := SPLIT_Y / SRC_H        # ~1.04 — keeps layers in top half

	for i in range(layer_defs.size()):
		var def: Dictionary = layer_defs[i]
		var spr: Sprite2D
		if i == 0:
			spr = _bg   # reuse scene node for sky
		else:
			spr = Sprite2D.new()
			spr.name = "BgLayer%d" % i
			add_child(spr)

		if not ResourceLoader.exists(def["path"]):
			spr.visible = false
			continue

		spr.texture        = load(def["path"]) as Texture2D
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.z_index        = def["z"]
		spr.scale          = Vector2(scale_x, scale_y)

		var anchor_y: float = def["y_anchor"]
		# sky centred in top half; ground layers bottom-anchored to SPLIT_Y
		var pos_y := (SPLIT_Y * 0.5) if anchor_y == 0.5 else SPLIT_Y
		spr.position = Vector2(DST_W * 0.5, pos_y)

		_bg_layers.append({
			"sprite": spr,
			"scroll": def["scroll"],
			"base_x": DST_W * 0.5,
		})

	# Dark divider line between world and info panel
	var divider := ColorRect.new()
	divider.name            = "PanelDivider"
	divider.color           = Color(0.08, 0.06, 0.12, 1.0)
	divider.position        = Vector2(0, SPLIT_Y)
	divider.size            = Vector2(1280, 3)
	divider.z_index         = 50
	add_child(divider)

	# Info panel background filling the bottom half
	var panel_bg := ColorRect.new()
	panel_bg.name           = "InfoPanelBg"
	panel_bg.color          = Color(0.07, 0.06, 0.10, 0.97)
	panel_bg.position       = Vector2(0, SPLIT_Y + 3)
	panel_bg.size           = Vector2(1280, 360)
	panel_bg.z_index        = -1
	add_child(panel_bg)

func _setup_hud() -> void:
	var all_labels: Array = [
		_score_lbl, _combo_lbl, _timer_lbl, _goal_lbl, _acc_lbl,
		_hint_lbl, _lane_lbl_a, _lane_lbl_b, _vip_lbl, _fail_lbl,
	]
	for lbl in all_labels:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", _pixel_font)
			lbl.add_theme_font_size_override("font_size", 16)

	_score_lbl.text   = "Score: 0"
	_combo_lbl.text   = ""
	_goal_lbl.text    = "Goal: %d pts" % _p["target_score"]
	_acc_lbl.text     = "Accuracy: -"
	_timer_lbl.visible = _p["time_limit"] > 0
	if _p["time_limit"] > 0:
		_time_left = _p["time_limit"]
		_timer_lbl.text = "⏱ %d" % int(_time_left)

	_hint_box.visible  = true
	_hint_box.modulate = Color.WHITE
	_hint_lbl.text     = ""
	_refresh_lives()

	var dynamic_lbls: Array = [
		_op_lbl, _front_lbl_a, _back_lbl_a, _front_lbl_b, _back_lbl_b,
		_wait_lbl_a, _wait_lbl_b, _overflow_lbl, _peek_lbl,
		_size_lbl_a, _size_lbl_b, _size_lbl_c,
		_empty_lbl_a, _empty_lbl_b, _empty_lbl_c,
	]
	for lbl in dynamic_lbls:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", _pixel_font)
			lbl.add_theme_font_size_override("font_size", 14)
	if is_instance_valid(_op_lbl):
		_op_lbl.add_theme_font_size_override("font_size", 22)

	# Size/empty HUD only when enabled by tier
	var show_sz: bool = _p.get("show_size_hud", false)
	if is_instance_valid(_size_lbl_a): _size_lbl_a.visible  = show_sz
	if is_instance_valid(_size_lbl_b): _size_lbl_b.visible  = show_sz and _p.get("tri_queue", false)
	if is_instance_valid(_size_lbl_c): _size_lbl_c.visible  = show_sz and _p.get("tri_queue", false)
	if is_instance_valid(_empty_lbl_a): _empty_lbl_a.visible = false
	if is_instance_valid(_empty_lbl_b): _empty_lbl_b.visible = false
	if is_instance_valid(_empty_lbl_c): _empty_lbl_c.visible = false

	_back_lbl_b.visible  = _p.get("tri_queue", false)
	_front_lbl_b.visible = _p.get("tri_queue", false)
	_wait_lbl_b.visible  = _p.get("tri_queue", false)

	# In multi-window mode the three service windows sit at x=160/540/920.
	# The default ENQUEUE BACK label ends up at x≈570 (right on the food window)
	# and the DEQUEUE FRONT label at x≈100 (overlapping the tax window).
	# Push them to bracket the queue correctly: front label left of x=160,
	# back label right of the rightmost window (x=920+).
	# Also, the WAITING AREA label default x=930 overlaps the permit window.
	if _p.get("multi_window", false) and not _p.get("tri_queue", false):
		var cap: int = _p["capacity"]
		var queue_back_x := FRONT_X + float(cap) * SLOT_W + 10.0
		# Only move the back label if it would land inside the window strip (160–960).
		if queue_back_x < 980.0:
			if is_instance_valid(_back_lbl_a):
				_back_lbl_a.global_position = Vector2(980.0, ROW_A_Y - 75.0)
		# Keep front label at its natural position (x≈100) — it's fine.
		# Move WAITING AREA label above the permit window so it doesn't overlap.
		if is_instance_valid(_wait_lbl_a):
			_wait_lbl_a.global_position = Vector2(WAIT_X_A - 20.0, ROW_A_Y - 110.0)

func _setup_monster_hud() -> void:
	_monster_alert.visible = false
	if is_instance_valid(_monster_lbl):
		_monster_lbl.add_theme_font_override("font", _pixel_font)
		_monster_lbl.add_theme_font_size_override("font_size", 15)
		_monster_lbl.add_theme_color_override("font_color", COL_MONSTER)

func _setup_service_buttons() -> void:
	_svc_row.visible = false

func _setup_timers() -> void:
	_spawn_tmr.wait_time = _p["spawn_interval"]
	_spawn_tmr.one_shot  = false
	_spawn_tmr.timeout.connect(_on_spawn)
	_spawn_tmr.start()

	if _p["time_limit"] > 0:
		_game_tmr.wait_time = 1.0
		_game_tmr.one_shot  = false
		_game_tmr.timeout.connect(_tick_clock)
		_game_tmr.start()

func _setup_layout_for_tier() -> void:
	var tri: bool = _p.get("tri_queue", false)
	_line_b.visible  = tri
	_svc_b.visible   = tri
	_arrow_b.visible = tri
	_lane_lbl_a.visible = tri
	_lane_lbl_b.visible = tri

	if tri:
		_lane_lbl_a.text = "💰 TAX QUEUE"
		_lane_lbl_b.text = "🍞 FOOD QUEUE"
		# Reposition scene nodes to staggered tri-queue row heights
		_line_b.position  = Vector2(0, ROW_B_Y_TRI)
		_arrow_b.position = Vector2(FRONT_X, ROW_B_Y_TRI - 56)
		_svc_b.position   = Vector2(SVC_X, ROW_B_Y_TRI)
	else:
		_line_b.position  = Vector2(0, ROW_A_Y)
		_arrow_b.position = Vector2(FRONT_X, ROW_A_Y - 56)

	# Always snap FrontArrow_A to the correct queue row (scene default is 434,
	# which is below the panel divider and wrong for every non-tutorial tier).
	_arrow_a.position = Vector2(FRONT_X, ROW_A_Y - 56)

	_animate_front_arrow(_arrow_a)
	if tri: _animate_front_arrow(_arrow_b)

# ─────────────────────────────────────────────────────────────────────────────
#  CONCEPT INTRO
# ─────────────────────────────────────────────────────────────────────────────
func _show_concept_intro() -> void:
	# 5 concepts matching the 5 TIER_PARAMS entries
	var messages := {
		"FIFO":
			"FIFO — First In, First Out\n\n" +
			"► Drag citizens from WAITING AREA → queue BACK  =  ENQUEUE\n" +
			"► Drag the FRONT citizen → service window        =  DEQUEUE\n" +
			"► Right-click the front citizen                  =  PEEK\n\n" +
			"Watch the [n/cap] counter — when full the queue OVERFLOWS.\n" +
			"EMPTY badge = isEmpty() is true — nothing to dequeue.\n\n" +
			"[Click anywhere to begin]",
		"SERVICE":
			"Peek + Service windows\n\n" +
			"Citizens hide what they need — PEEK to find out!\n\n" +
			"► RIGHT-CLICK the front citizen  =  PEEK\n" +
			"   (reveals their request icon for a few seconds)\n" +
			"► Then DEQUEUE to the matching window:\n" +
			"     💰 TAX   🍞 FOOD   📜 PERMIT\n\n" +
			"Dequeuing without peeking first = PENALTY!\n\n" +
			"[Click to begin]",
		"PATIENCE":
			"Patience — time-bounded queues\n\n" +
			"► Citizens leave if not served in time\n" +
			"  (colour drains from green → red → gone)\n" +
			"► Losing a citizen = losing a heart\n" +
			"► Real-world link: bounded queues drop requests when full/slow\n\n" +
			"Keep throughput high — ENQUEUE and DEQUEUE quickly!\n\n" +
			"[Click to begin]",
		"PRIORITY":
			"Priority Queue — sorted insertion by key\n\n" +
			"► Citizens now carry a priority level (⭐ lvl 1 → 🚨 lvl 3)\n" +
			"► When enqueued, they are inserted at the correct SORTED POSITION\n" +
			"  — this costs O(n) time (you'll see the scan label!)\n" +
			"► Higher key = served sooner regardless of arrival order\n" +
			"► PEEK first — badges can hint at priority level\n\n" +
			"[Click to begin]",
		"EXPERT":
			"Expert — lanes, monsters, fake signals\n\n" +
			"► Three queues: 💰 TAX   🍞 FOOD   📜 PERMIT\n" +
			"► ENQUEUE each citizen to their correct lane\n" +
			"► Monsters escalate to FRONT (interrupt queue!) → drag to ⚔ COMBAT\n" +
			"► Some VIP badges are FAKE — PEEK to verify before dequeuing!\n" +
			"► Short patience, short timer — every second counts\n\n" +
			"[Click to begin]",
	}
	var concept: String = _p.get("concept", "FIFO")
	if concept not in messages: return

	_tut_locked = true; _spawn_tmr.stop()
	_hint_box.visible = true; _hint_lbl.text = messages[concept]
	_tut_blocker.visible = true
	_tut_blocker.modulate = Color(0, 0, 0, 0.55)
	await _wait_for_click()
	_tut_locked = false; _tut_blocker.visible = false
	_hint_box.visible = false; _hint_lbl.text = _idle_hint()
	_spawn_tmr.start()

func _idle_hint() -> String:
	var tri: bool = _p.get("tri_queue", false)
	if not _queue_a.is_empty() and (_queue_a[0] as Dictionary).get("is_monster", false):
		return "⚔ Monster at FRONT! Drag it → ⚔ COMBAT WINDOW (top-left)"
	if tri and not _queue_b.is_empty() and (_queue_b[0] as Dictionary).get("is_monster", false):
		return "⚔ Monster at FRONT of FOOD queue! Drag → ⚔ COMBAT WINDOW"
	var peek_req: bool = _p.get("peek_required", false)
	match _p.get("concept", "FIFO"):
		"FIFO":
			if not _queue_a.is_empty():
				return "DEQUEUE → drag FRONT citizen to the service window"
			if not _waiting_a.is_empty():
				return "ENQUEUE → drag citizen from WAITING AREA → queue BACK ▶"
			return "Waiting for citizens..."
		"SERVICE", "PATIENCE", "PRIORITY":
			if not _queue_a.is_empty():
				if peek_req and _peeked_uid.get("a", -1) != (_queue_a[0] as Dictionary).get("id", -2):
					return "RIGHT-CLICK front citizen to PEEK first!"
				var req: String = (_queue_a[0] as Dictionary).get("request", "")
				return "DEQUEUE → drag front to %s %s WINDOW" % [SERVICE_ICON.get(req, "?"), req.to_upper()]
			return "ENQUEUE → drag from WAITING AREA → queue BACK ▶"
		"EXPERT":
			return "ENQUEUE into correct lane  |  DEQUEUE FRONT → shared window"
		_:
			return "Waiting..."

# ─────────────────────────────────────────────────────────────────────────────
#  TUTORIAL (Tier 0 only)
# ─────────────────────────────────────────────────────────────────────────────
func _run_tutorial() -> void:
	_tut_step = 1; _tut_locked = true; _spawn_tmr.stop()
	_tut_blocker.visible = true; _tut_blocker.modulate = Color(0, 0, 0, 0.5)

	_show_hint(
		"Welcome to Kingdom Queue!\n\n" +
		"Citizens arrive in the WAITING AREA (right side).\n" +
		"  ENQUEUE  =  drag citizen → queue BACK ▶\n" +
		"  DEQUEUE  =  drag FRONT citizen → service window ◀\n" +
		"  PEEK     =  right-click FRONT citizen (inspect, no removal)\n\n" +
		"Watch the [n/cap] counter — it shows how full the queue is.\n\n" +
		"[Click to begin]"
	)
	await _wait_for_click()
	_hint_box.visible = false
	await get_tree().create_timer(0.3).timeout

	# Step 1 — spawn first citizen, start timer so game keeps running
	# even if player skips tutorial steps
	_on_spawn()
	_spawn_tmr.start()   # ← FIX: timer runs continuously from here on
	await get_tree().create_timer(2.5).timeout
	_show_hint(
		"Step 1 — ENQUEUE\n\n" +
		"Drag the citizen from the WAITING AREA\n" +
		"→ to the BACK ▶ of the queue (yellow label)\n\n" +
		"[Click to dismiss, then drag]"
	)
	_tut_locked = false; _tut_step = 2

func _advance_tutorial(step: int) -> void:
	match step:
		2:
			_tut_step = 3; _tut_locked = true
			_show_hint(
				"✓ ENQUEUED! Notice [1/%d] in the counter.\n\n" % _p["capacity"] +
				"Step 2 — PEEK\n" +
				"Right-click the FRONT citizen to PEEK at them\n" +
				"(inspect without removing — a key queue operation!)\n\n" +
				"[Click to dismiss, then right-click the citizen]"
			)
			_tut_locked = false

		3:
			_tut_step = 4; _tut_locked = true
			_show_hint(
				"✓ PEEKED! You saw the front citizen without removing them.\n\n" +
				"Step 3 — DEQUEUE\n" +
				"Now drag the FRONT citizen → service window (left)\n\n" +
				"[Click to dismiss, then drag to window]"
			)
			_tut_locked = false

		4:
			_tut_step = 5; _tut_locked = true
			_show_hint(
				"✓ DEQUEUED! Counter now shows [0/%d] = isEmpty!\n\n" % _p["capacity"] +
				"Step 4 — FIFO ORDER\n" +
				"Two citizens will arrive. ENQUEUE both.\n" +
				"Then try dragging the BACK one first — watch what happens!\n\n" +
				"[Click to dismiss]"
			)
			await get_tree().create_timer(0.4).timeout
			_on_spawn()
			await get_tree().create_timer(3.5).timeout
			_on_spawn()
			_tut_locked = false; _tut_step = 5

		5:
			_tut_step = 6; _tut_locked = true
			_show_hint(
				"⚠ FIFO Violation!\n\n" +
				"Only the FRONT can be dequeued.\n" +
				"First In = First Out — always serve in arrival order.\n\n" +
				"Drain both citizens in order, then continue.\n\n" +
				"[Click to dismiss]"
			)
			_tut_locked = false

		6:
			_tut_step = 7; _tut_locked = true
			_show_hint(
				"✓ FIFO mastered!\n\n" +
				"Step 5 — OVERFLOW (bounded buffer)\n" +
				"The queue holds at most %d citizens.\n" % _p["capacity"] +
				"Keep enqueuing until full, then try to add one more!\n\n" +
				"[Click to dismiss]"
			)
			# Spawn enough citizens to approach capacity (timer is already running)
			# Spawn 2 now; the running timer fills the rest naturally
			_on_spawn()
			await get_tree().create_timer(1.0).timeout
			_on_spawn()
			_tut_locked = false

		7:
			_tut_step = -1; _tut_locked = false; _tut_blocker.visible = false
			_show_hint(
				"✓ All concepts learned!\n\n" +
				"ENQUEUE → queue back\n" +
				"DEQUEUE → front to window\n" +
				"PEEK    → inspect front without removing\n" +
				"FIFO    → first in, first out\n" +
				"[n/cap] → queue size / capacity\n\n" +
				"Good luck!"
			)
			await get_tree().create_timer(3.5).timeout
			_hint_box.visible = false
			# Timer already running — no restart needed

func _wait_for_click() -> void:
	while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		await get_tree().process_frame
	var done := false
	while not done:
		await get_tree().process_frame
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			done = true
			while Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				await get_tree().process_frame

# ─────────────────────────────────────────────────────────────────────────────
#  PROCESS
# ─────────────────────────────────────────────────────────────────────────────
# Returns the correct world Y for a queue lane, respecting tri-queue stagger
func _row_y(which: String) -> float:
	var tri: bool = _p.get("tri_queue", false)
	match which:
		"b": return ROW_B_Y_TRI if tri else ROW_B_Y
		"c": return ROW_C_Y_TRI if tri else ROW_C_Y
		_:   return ROW_A_Y

func _process(delta: float) -> void:
	if not _alive: return

	if _combo > 0:
		_combo_decay -= delta
		if _combo_decay <= 0.0:
			_combo = 0; _combo_lbl.text = ""

	var tri: bool = _p.get("tri_queue", false)
	if _p["patience"] > 0.0:
		_tick_patience(delta, _queue_a, "a")
		_tick_patience_waiting(delta, _waiting_a, "a")
		if tri:
			_tick_patience(delta, _queue_b, "b")
			_tick_patience_waiting(delta, _waiting_b, "b")
			_tick_patience(delta, _queue_c, "c")
			_tick_patience_waiting(delta, _waiting_c, "c")

	_tick_escalation(delta, _queue_a, "a")
	if tri:
		_tick_escalation(delta, _queue_b, "b")
		_tick_escalation(delta, _queue_c, "c")

	if _is_dragging and _drag_node != null:
		_drag_ghost.position = _drag_node.position

	_refresh_size_hud()
	_tick_parallax(delta)

# ── Gentle auto-scroll parallax — layers drift right→left slowly ─────────────
var _parallax_offset: float = 0.0
const PARALLAX_SPEED := 18.0   # pixels/sec at scroll=1.0

func _tick_parallax(delta: float) -> void:
	if _bg_layers.is_empty(): return
	_parallax_offset += PARALLAX_SPEED * delta
	const DST_W := 1280.0
	for entry in _bg_layers:
		var spr := entry["sprite"] as Sprite2D
		if not is_instance_valid(spr): continue
		var scroll: float = entry["scroll"]
		var base_x: float = entry["base_x"]
		# Oscillate ±(DST_W * scroll * 0.5) around centre so it never leaves screen
		var offset := sin(_parallax_offset * scroll * 0.05) * DST_W * scroll * 0.3
		spr.position.x = base_x + offset

# ─────────────────────────────────────────────────────────────────────────────
#  SIZE HUD — live [n/cap] counter and isEmpty badge
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_size_hud() -> void:
	if not _p.get("show_size_hud", false): return
	var cap: int = _p["capacity"]
	_update_size_label(_size_lbl_a, _empty_lbl_a, _queue_a, cap)
	if _p.get("tri_queue", false):
		_update_size_label(_size_lbl_b, _empty_lbl_b, _queue_b, cap)
		_update_size_label(_size_lbl_c, _empty_lbl_c, _queue_c, cap)

func _update_size_label(sz_lbl: Label, em_lbl: Label, q: Array, cap: int) -> void:
	if not is_instance_valid(sz_lbl): return
	var n := q.size()
	sz_lbl.text = "[%d/%d]" % [n, cap]
	sz_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.4, 0.1) if n >= cap else Color(0.7, 0.9, 1.0))
	if is_instance_valid(em_lbl):
		em_lbl.visible = (n == 0)

# ─────────────────────────────────────────────────────────────────────────────
#  SPAWN
# ─────────────────────────────────────────────────────────────────────────────
func _on_spawn() -> void:
	if not _alive: return
	if _maybe_spawn_monster("a"): return

	var request: String = ""
	if _p.get("service_required", false):
		request = SERVICES[randi() % SERVICES.size()]

	var which := "a"
	if _p.get("tri_queue", false) or _p.get("lane_routing", false):
		if   request == "food":   which = "b"
		elif request == "permit": which = "c"

	var priority_level: int = 0
	if _p.get("vip_events", false):
		var max_p: int = _p.get("max_priority", 1)
		var roll := randf()
		match clamp(TIER_PARAMS.find(_p), 0, TIER_PARAMS.size() - 1):
			3:
				# T3 PRIORITY — levels 1-3, moderate frequency
				if   roll < 0.08: priority_level = min(3, max_p)
				elif roll < 0.18: priority_level = min(2, max_p)
				elif roll < 0.32: priority_level = min(1, max_p)
			4:
				# T4 EXPERT — all levels 1-4, higher frequency, with fake badges
				if   roll < 0.05: priority_level = min(4, max_p)
				elif roll < 0.12: priority_level = min(3, max_p)
				elif roll < 0.22: priority_level = min(2, max_p)
				elif roll < 0.36: priority_level = min(1, max_p)

	var is_vip: bool = priority_level > 0
	var ctype  := CITIZEN_KEYS[randi() % CITIZEN_KEYS.size()]
	var sprite := _build_citizen_sprite(ctype, request, is_vip, priority_level)
	add_child(sprite)

	var row_y: float
	var wait: Array
	match which:
		"b":  row_y = _row_y("b"); wait = _waiting_b
		"c":  row_y = _row_y("c"); wait = _waiting_c
		_:    row_y = ROW_A_Y; wait = _waiting_a

	var wait_x: float = WAIT_X_A + wait.size() * 70.0
	sprite.position = Vector2(1320.0, row_y)

	var data := {
		"id": _uid, "type": ctype, "request": request, "node": sprite,
		"priority": is_vip, "priority_level": priority_level,
		"queue": which, "is_monster": false, "in_queue": false,
	}
	_uid += 1
	wait.append(data)

	if _p["patience"] > 0.0:
		_patience_t[data["id"]] = _p["patience"] * 1.5

	var walk_dur: float = clampf((1320.0 - wait_x) / 400.0, 0.4, 2.5)
	var tw := sprite.create_tween().set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(sprite, "position:x", wait_x, walk_dur)
	tw.tween_callback(func():
		if is_instance_valid(sprite) and sprite is AnimatedSprite2D:
			(sprite as AnimatedSprite2D).play("idle"))

	_hint_lbl.text = _idle_hint()

# ─────────────────────────────────────────────────────────────────────────────
#  ENQUEUE
# ─────────────────────────────────────────────────────────────────────────────
func _try_enqueue(data: Dictionary, which: String) -> void:
	var q: Array
	match which:
		"b": q = _queue_b
		"c": q = _queue_c
		_:   q = _queue_a
	var cap: int = _p["capacity"]

	if q.size() >= cap:
		_stat["overflow_count"] += 1
		_show_operation_label(
			"OVERFLOW!\nBounded buffer full [%d/%d]\nDEQUEUE from front first!" % [q.size(), cap],
			COL_OP_OVER)
		_overflow_lbl.visible = true
		get_tree().create_timer(2.5).timeout.connect(
			func(): if is_instance_valid(_overflow_lbl): _overflow_lbl.visible = false,
			CONNECT_ONE_SHOT)
		var nd := data["node"] as Node2D
		_apply_wrong(nd, 0, "Queue FULL — bounded buffer\nDEQUEUE from the FRONT first.")
		_refresh_algo_panel("overflow", q)
		_reflow_waiting(which)
		return

	var wait: Array
	match which:
		"b": wait = _waiting_b
		"c": wait = _waiting_c
		_:   wait = _waiting_a
	wait.erase(data)
	data["in_queue"] = true

	if _p["patience"] > 0.0:
		_patience_t[data["id"]] = _p["patience"]

	var nd := data["node"] as Node2D
	var plevel: int = data.get("priority_level", 0)

	if plevel > 0:
		var insert_idx: int = q.size()
		for i in range(q.size()):
			var existing_level: int = (q[i] as Dictionary).get("priority_level", 0)
			if plevel > existing_level:
				insert_idx = i
				break

		var cost_lbl: String = "O(%d) insert — scanned %d element%s" % [
			q.size() + 1, insert_idx,
			"s" if insert_idx != 1 else ""
		]
		_show_operation_label(
			"PRIORITY ENQUEUE ✓  (level %d)\n%s\nInserted at position %d" % [plevel, cost_lbl, insert_idx + 1],
			PRIORITY_COLORS.get(plevel, COL_OP_ENQUEUE))
		_float_label(nd,
			"%s → pos %d" % [PRIORITY_LABELS.get(plevel, "VIP"), insert_idx + 1],
			PRIORITY_COLORS.get(plevel, COL_OP_ENQUEUE))

		if insert_idx == 0 and not q.is_empty():
			_do_vip_priority(data, q, which)
		else:
			q.insert(insert_idx, data)
		_refresh_algo_panel("enqueue_priority", q, cost_lbl)
	else:
		q.append(data)
		_show_operation_label("ENQUEUE ✓\nAdded to back  [%d/%d]" % [q.size(), cap], COL_OP_ENQUEUE)
		_float_label(nd, "ENQUEUE", COL_OP_ENQUEUE)
		_refresh_algo_panel("enqueue", q)

	_stat["enqueue_count"] += 1
	AudioManager.play_sfx(PATH_SFX_OK)
	_reflow(which)
	_reflow_waiting(which)
	_dismiss_hint()

	if _tut_step == 2: _advance_tutorial(2)

# ─────────────────────────────────────────────────────────────────────────────
#  DEQUEUE
# ─────────────────────────────────────────────────────────────────────────────
func _try_serve(q: Array, which: String) -> void:
	if q.is_empty(): return
	var data    := q[0] as Dictionary
	var nd      := data["node"] as Node2D
	var request: String = data.get("request", "")

	# Peek-first enforcement (tiers 1+)
	if _p.get("peek_required", false):
		if _peeked_uid.get(which, -1) != data.get("id", -2):
			_stat["peek_miss"] += 1
			_apply_wrong(nd, 0, "PEEK first!\nRight-click the front citizen\nbefore dequeuing.")
			_show_operation_label("PEEK required!\nRight-click front citizen first", COL_OP_PEEK)
			return

	# Multi-window gate — check against the window-type map
	if _p.get("multi_window", false) and request != "":
		if _current_drop_gate != request:
			_stat["service_miss"] += 1
			_apply_wrong(nd, _p["penalty"],
				"Wrong window!\n%s needs the %s %s window!" % [
					data.get("type","citizen").to_upper(),
					SERVICE_ICON.get(request,"?"),
					request.to_upper()])
			_reflow(which)
			return

	q.pop_front()
	_patience_t.erase(data["id"])
	_peeked_uid.erase(which)
	_stat["dequeue_count"] += 1
	var cap: int = _p["capacity"]

	# Update the served-count tracker chip on the window that just handled this citizen
	if _p.get("multi_window", false) and request != "":
		_increment_window_tracker(request)

	_show_operation_label("DEQUEUE ✓\nFront removed  [%d/%d]" % [q.size(), cap], COL_OP_DEQUEUE)
	_float_label(nd, "DEQUEUE", COL_OP_DEQUEUE)
	_refresh_algo_panel("dequeue" if not q.is_empty() else "isEmpty", q)

	if is_instance_valid(nd):
		_apply_correct(nd, 40)
		var tw := nd.create_tween()
		tw.tween_property(nd, "position:x", SVC_X - 80.0, 0.3)
		tw.parallel().tween_property(nd, "modulate:a", 0.0, 0.3)
		tw.tween_callback(nd.queue_free)

	_reflow(which)
	_dismiss_hint()

	# Restore any held citizen now that queue front is freed
	_restore_held_citizen(which)

	if _tut_step == 3: _advance_tutorial(3)
	if _tut_step == 4:
		_fifo_correct_count += 1
		if _fifo_correct_count >= 2:
			_fifo_correct_count = 0; _advance_tutorial(5)

	if _score >= _p["target_score"]:
		var acc := _accuracy()
		if _p["accuracy_target"] <= 0.0 or acc >= _p["accuracy_target"]:
			_end_game(true)
		else:
			_hint_lbl.text = "Score reached! Accuracy too low (%.0f%% / %.0f%% needed)." % [
				acc, _p["accuracy_target"]]

# ─────────────────────────────────────────────────────────────────────────────
#  PEEK  — right-click front citizen: show info, do NOT remove
# ─────────────────────────────────────────────────────────────────────────────
func _try_peek(pos: Vector2) -> bool:
	var queues := [
		[_queue_a, "a"], [_queue_b, "b"], [_queue_c, "c"]
	]
	for pair in queues:
		var q    := pair[0] as Array
		var which := pair[1] as String
		if q.is_empty(): continue
		var front := q[0] as Dictionary
		var nd    := front["node"] as Node2D
		if not is_instance_valid(nd): continue
		if nd.global_position.distance_to(pos) > HIT_R: continue

		# Valid peek
		_stat["peek_count"] += 1
		_peeked_uid[which] = front["id"]

		var ctype:    String = front.get("type", "citizen")
		var request:  String = front.get("request", "")
		var plevel:   int    = front.get("priority_level", 0)
		var is_mon:   bool   = front.get("is_monster", false)

		var peek_text := "PEEK — front of queue\n"
		if is_mon:
			var mtype: String = front.get("type", "monster")
			peek_text += "👾 MONSTER: %s\n" % mtype.replace("_", " ").to_upper()
			peek_text += "Threat: %s\n" % "💀".repeat(MONSTER_THREAT.get(mtype, 1))
			peek_text += "→ Drag to ⚔ COMBAT WINDOW"
		else:
			peek_text += "Type: %s\n" % ctype.to_upper()
			if request != "":
				peek_text += "Request: %s %s\n" % [SERVICE_ICON.get(request,"?"), request.to_upper()]
			if plevel > 0:
				peek_text += "Priority: %s (level %d)\n" % [PRIORITY_LABELS.get(plevel,"VIP"), plevel]
			peek_text += "→ Drag to matching window to DEQUEUE"

		# Show peek panel
		if is_instance_valid(_peek_panel) and is_instance_valid(_peek_lbl):
			_peek_lbl.text   = peek_text
			_peek_panel.visible = true
			_peek_active     = true
			get_tree().create_timer(2.5).timeout.connect(
				func():
					if is_instance_valid(_peek_panel): _peek_panel.visible = false
					_peek_active = false,
				CONNECT_ONE_SHOT)

		# Reveal the hidden request label on the citizen for the peek duration,
		# then hide it again — icon is only visible after a peek, not by default.
		var req_lbl_nd = nd.get_node_or_null("RequestLabel")
		if is_instance_valid(req_lbl_nd):
			req_lbl_nd.visible = true
			get_tree().create_timer(2.5).timeout.connect(
				func():
					if is_instance_valid(req_lbl_nd): req_lbl_nd.visible = false,
				CONNECT_ONE_SHOT)

		# Tint front node cyan briefly
		if is_instance_valid(nd):
			nd.modulate = COL_PEEK
			get_tree().create_timer(0.6).timeout.connect(
				func(): if is_instance_valid(nd): nd.modulate = COL_WHITE,
				CONNECT_ONE_SHOT)

		_show_operation_label("PEEK ✓\nFront inspected — not removed", COL_OP_PEEK)
		AudioManager.play_sfx(PATH_SFX_BTN)
		_refresh_algo_panel("peek", q)

		if _tut_step == 3: _advance_tutorial(3)
		return true
	return false

# ─────────────────────────────────────────────────────────────────────────────
#  HINT / OP LABEL
# ─────────────────────────────────────────────────────────────────────────────
func _dismiss_hint() -> void:
	if not is_instance_valid(_hint_box): return
	if _overlay_tween and _overlay_tween.is_valid(): _overlay_tween.kill()
	var tw := _hint_box.create_tween()
	tw.tween_property(_hint_box, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func():
		if is_instance_valid(_hint_box):
			_hint_box.visible = false; _hint_box.modulate.a = 1.0)

func _show_hint(text: String) -> void:
	if not is_instance_valid(_hint_box): return
	_hint_lbl.text = text; _hint_box.modulate.a = 1.0; _hint_box.visible = true

# Show a floating overlay hint in the world area that auto-fades.
# Use for drag-contextual tips so the bottom HUD panel stays clean.
func _show_overlay_hint(text: String, auto_fade_sec: float = 3.0) -> void:
	if not is_instance_valid(_hint_box): return
	var hc := _hint_box as Control
	# Float the hint in the upper-middle of the world (above the queue)
	hc.anchor_left   = 0.18; hc.anchor_right  = 0.82
	hc.anchor_top    = 0.04; hc.anchor_bottom = 0.20
	hc.offset_left   = 0.0;  hc.offset_right  = 0.0
	hc.offset_top    = 0.0;  hc.offset_bottom = 0.0
	hc.z_index = 300
	_hint_lbl.text     = text
	_hint_box.modulate = Color.WHITE
	_hint_box.visible  = true
	if _overlay_tween and _overlay_tween.is_valid(): _overlay_tween.kill()
	if auto_fade_sec > 0.0:
		_overlay_tween = _hint_box.create_tween()
		_overlay_tween.tween_interval(auto_fade_sec)
		_overlay_tween.tween_property(_hint_box, "modulate:a", 0.0, 0.4)
		_overlay_tween.tween_callback(func():
			if is_instance_valid(_hint_box): _hint_box.visible = false)

# Increment the served-count chip on a service window after a successful dequeue.
func _increment_window_tracker(svc_type: String) -> void:
	var nd: Node2D = _extra_windows.get(svc_type, null)
	if not nd or not is_instance_valid(nd): return
	var lbl := nd.get_node_or_null("TrackerLabel") as Label
	if not lbl: return
	var parts := lbl.text.trim_prefix("✓ ").split(" ")
	var current := int(parts[0]) if parts.size() > 0 else 0
	lbl.text = "✓ %d served" % (current + 1)
	# Brief flash to acknowledge the serve
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate", Color(1.8, 1.8, 1.8, 1.0), 0.05)
	tw.tween_property(lbl, "modulate", Color.WHITE, 0.25)

# Highlight (glow border) the matching service window when the player is dragging
# a citizen toward it. Call with svc_type="" to clear all highlights.
func _highlight_window(svc_type: String) -> void:
	for wtype: String in _extra_windows:
		var nd: Node2D = _extra_windows[wtype]
		if not is_instance_valid(nd): continue
		# Find the border ColorRect (first child) and tint it
		var border := nd.get_child(0) if nd.get_child_count() > 0 else null
		if not border is ColorRect: continue
		var col: Color = SERVICE_COLOR.get(wtype, Color.WHITE)
		if wtype == svc_type:
			(border as ColorRect).color = col.lightened(0.3)
		else:
			(border as ColorRect).color = col.darkened(0.2)

func _show_operation_label(text: String, color: Color) -> void:
	if not is_instance_valid(_op_lbl): return
	_op_lbl.text = text; _op_lbl.visible = true
	_op_lbl.add_theme_color_override("font_color", color)
	_op_lbl.modulate.a = 1.0
	var tw := _op_lbl.create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(_op_lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(func(): _op_lbl.visible = false)

# ─────────────────────────────────────────────────────────────────────────────
#  SPRITE BUILDERS  — original multi-sprite asset system
# ─────────────────────────────────────────────────────────────────────────────

func _make_sprite_frames(anim_key: String) -> SpriteFrames:
	if anim_key in _frames_cache: return _frames_cache[anim_key]
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim_name: String in ["idle", "walk"]:
		sf.add_animation(anim_name)
		sf.set_animation_loop(anim_name, true)
		sf.set_animation_speed(anim_name, IDLE_FPS if anim_name == "idle" else WALK_FPS)
		for frame_name: String in ANIM_FRAME_NAMES:
			var path := "%s%s_walk_%s.png" % [ANIM_BASE, anim_key, frame_name]
			if ResourceLoader.exists(path):
				sf.add_frame(anim_name, load(path))
	_frames_cache[anim_key] = sf
	return sf

func _build_citizen_sprite(ctype: String, request: String,
		is_vip: bool, priority_level: int = 0) -> AnimatedSprite2D:
	var anim_node := AnimatedSprite2D.new()
	var keys: Array = CITIZEN_ANIM_KEYS.get(ctype, CITIZEN_ANIM_KEYS["peasant"])
	var anim_key: String = keys[randi() % keys.size()]
	anim_node.set_meta("anim_key", anim_key)
	anim_node.sprite_frames  = _make_sprite_frames(anim_key)
	anim_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim_node.scale          = C_SCALE
	anim_node.z_index        = 10
	anim_node.flip_h         = true   # walk frames face right → flip to face left
	anim_node.play("walk")

	# Only tint by service color if peek is NOT required (tiers 0 or no service).
	# In peek-required tiers the icon is hidden — tinting would give it away.
	if request != "" and not _p.get("peek_required", false):
		anim_node.modulate = (SERVICE_COLOR[request] as Color).darkened(0.1)
	if is_vip and _p.get("fake_signals", false):
		anim_node.modulate = Color(1.0, 0.85, 0.1)

	if request != "":
		var req_lbl := Label.new()
		req_lbl.name    = "RequestLabel"   # named so peek can find and show it
		req_lbl.text    = SERVICE_ICON.get(request, "?")
		if _pixel_font: req_lbl.add_theme_font_override("font", _pixel_font)
		req_lbl.add_theme_font_size_override("font_size", 14)
		req_lbl.position = Vector2(-8, -36)
		req_lbl.visible  = false   # hidden until player peeks (right-click)
		anim_node.add_child(req_lbl)

	if is_vip and priority_level > 0:
		var fake: bool = _p.get("fake_signals", false)
		var plbl := Label.new()
		plbl.text = PRIORITY_LABELS.get(priority_level, "⭐") if not fake \
			else PRIORITY_LABELS.get(randi_range(1, priority_level), "⭐")
		if _pixel_font: plbl.add_theme_font_override("font", _pixel_font)
		plbl.add_theme_font_size_override("font_size", 9)
		plbl.add_theme_color_override("font_color",
			PRIORITY_COLORS.get(priority_level, Color.WHITE))
		plbl.position = Vector2(-36, -58)
		anim_node.add_child(plbl)
		if request == "":
			anim_node.modulate = (PRIORITY_COLORS.get(priority_level, Color.WHITE) as Color)\
				.lerp(Color.WHITE, 0.6)
	return anim_node

func _build_monster_sprite(mtype: String) -> AnimatedSprite2D:
	var anim_node := AnimatedSprite2D.new()
	var anim_key: String = MONSTER_ANIM_KEYS.get(mtype, "monster_cultist")
	anim_node.set_meta("anim_key", anim_key)
	anim_node.sprite_frames  = _make_sprite_frames(anim_key)
	anim_node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	anim_node.scale          = C_SCALE
	anim_node.z_index        = 10
	anim_node.flip_h         = true
	anim_node.modulate       = COL_MONSTER
	anim_node.play("walk")

	var icon: String = MONSTER_ICONS.get(mtype, "👾")
	var name_lbl := Label.new()
	name_lbl.text = "%s %s" % [icon, mtype.replace("_", " ").to_upper()]
	if _pixel_font: name_lbl.add_theme_font_override("font", _pixel_font)
	name_lbl.add_theme_font_size_override("font_size", 8)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8))
	name_lbl.position = Vector2(-28, -30)
	anim_node.add_child(name_lbl)

	var threat: int = MONSTER_THREAT.get(mtype, 1)
	var threat_lbl := Label.new()
	threat_lbl.text = "💀".repeat(threat)
	if _pixel_font: threat_lbl.add_theme_font_override("font", _pixel_font)
	threat_lbl.add_theme_font_size_override("font_size", 8)
	threat_lbl.position = Vector2(-12, -52)
	anim_node.add_child(threat_lbl)
	return anim_node

# ─────────────────────────────────────────────────────────────────────────────
#  SCRIPTED TUTORIAL SPAWNS
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_scripted_vip() -> void:
	var ctype  := CITIZEN_KEYS[randi() % CITIZEN_KEYS.size()]
	var sprite := _build_citizen_sprite(ctype, "", true, 1)
	add_child(sprite); sprite.position = Vector2(1320.0, ROW_A_Y)
	var data := {
		"id": _uid, "type": ctype, "request": "", "node": sprite,
		"priority": true, "priority_level": 1, "queue": "a",
		"is_monster": false, "in_queue": false,
	}
	_uid += 1; _waiting_a.append(data)
	var tw := sprite.create_tween().set_trans(Tween.TRANS_LINEAR)
	tw.tween_property(sprite, "position:x", WAIT_X_A, 1.8)
	tw.tween_callback(func():
		if is_instance_valid(sprite) and sprite is AnimatedSprite2D:
			(sprite as AnimatedSprite2D).play("idle"))

func _spawn_scripted_monster() -> void:
	if _queue_a.size() < 1: return
	var mtype  := "cultist"; var sprite := _build_monster_sprite(mtype)
	add_child(sprite); sprite.position = Vector2(FRONT_X + SLOT_W, ROW_A_Y)
	var data := {
		"id": _uid, "type": mtype, "request": "", "node": sprite,
		"priority": false, "queue": "a", "is_monster": true, "in_queue": true,
	}
	_uid += 1; _queue_a.insert(1, data)
	_monster_ids[data["id"]] = mtype
	_escalation_t[data["id"]] = 20.0
	if is_instance_valid(_combat_a): _combat_a.visible = true
	_reflow("a")
	_show_hint(
		"👾 MONSTER in the queue!\n\n" +
		"Monsters act as interrupt requests — they escalate to FRONT.\n" +
		"Drag the MONSTER → ⚔ COMBAT WINDOW (top-left) to defeat it.\n\n" +
		"Ignore it and lose a ❤!"
	)

# ─────────────────────────────────────────────────────────────────────────────
#  MONSTER SPAWNING
# ─────────────────────────────────────────────────────────────────────────────
func _maybe_spawn_monster(which: String) -> bool:
	var tier: int  = clamp(TIER_PARAMS.find(_p), 0, TIER_PARAMS.size() - 1)
	if randf() >= MONSTER_SPAWN_CHANCE[tier]: return false
	var q   := _queue_a if which == "a" else _queue_b
	var cap: int = _p["capacity"]
	if q.size() >= cap: return false
	var mtype  := MONSTER_KEYS[randi() % MONSTER_KEYS.size()]
	var sprite := _build_monster_sprite(mtype)
	add_child(sprite)
	sprite.position = Vector2(WAIT_X_A, ROW_A_Y if which == "a" else _row_y("b"))
	var data := {
		"id": _uid, "type": mtype, "request": "", "node": sprite,
		"priority": false, "queue": which, "is_monster": true, "in_queue": true,
	}
	_uid += 1; q.append(data)
	_monster_ids[data["id"]] = mtype
	var threat: int = MONSTER_THREAT.get(mtype, 1)
	_escalation_t[data["id"]] = 10.0 / float(threat)
	var combat_nd := _combat_a if which == "a" else _combat_b
	if is_instance_valid(combat_nd): combat_nd.visible = true
	if threat >= 3: _escalate_monster_now(data, q, which)
	else: _show_monster_alert(mtype, _escalation_t[data["id"]])
	_reflow(which)
	return true

# ─────────────────────────────────────────────────────────────────────────────
#  MONSTER ESCALATION — interrupt queue concept
# ─────────────────────────────────────────────────────────────────────────────
func _tick_escalation(delta: float, q: Array, which: String) -> void:
	for data: Dictionary in q:
		if not data.get("is_monster", false): continue
		var cid: int = data["id"]
		if cid not in _escalation_t: continue
		_escalation_t[cid] -= delta
		var nd := data["node"] as Node2D
		if _escalation_t[cid] <= ESCALATE_WARN and _escalation_t[cid] > 0.0:
			if is_instance_valid(nd):
				nd.modulate = COL_MONSTER.lerp(COL_ESCALATED,
					1.0 - (_escalation_t[cid] / ESCALATE_WARN))
		if _escalation_t[cid] <= 0.0:
			_escalation_t.erase(cid)
			_escalate_monster_now(data, q, which)
			return

func _escalate_monster_now(data: Dictionary, q: Array, which: String) -> void:
	var idx := q.find(data)
	if idx <= 0: return
	q.erase(data); q.push_front(data)
	var nd := data["node"] as Node2D
	if is_instance_valid(nd):
		nd.modulate = COL_ESCALATED; _pulse_node(nd, COL_ESCALATED)
	var mtype: String = _monster_ids.get(data["id"], "monster")
	_monster_alert.visible = true
	_monster_lbl.text = (
		"⚠ INTERRUPT QUEUE!\n" +
		"%s escalated to FRONT — breaks FIFO!\n\n" +
		"(Like an OS interrupt: high-priority signal\n" +
		"pre-empts normal queue order)\n\n" +
		"→ Drag monster to ⚔ COMBAT WINDOW (top-left)!"
	) % mtype.replace("_", " ").to_upper()
	get_tree().create_timer(4.5).timeout.connect(
		func(): if is_instance_valid(_monster_alert): _monster_alert.visible = false,
		CONNECT_ONE_SHOT)
	_reflow(which)
	_show_context_feedback(nd,
		"INTERRUPT QUEUE!\nEscalated to FRONT (breaks FIFO)", COL_ESCALATED)

func _show_monster_alert(mtype: String, escalate_in: float) -> void:
	_monster_alert.visible = true
	var threat: int  = MONSTER_THREAT.get(mtype, 1)
	var icon: String = MONSTER_ICONS.get(mtype, "👾")
	var urgency: String = (["", "Low threat", "Medium — hurry!", "HIGH — fight NOW!"] as Array[String])[clamp(threat, 0, 3)]
	_monster_lbl.text = "%s %s  |  %s\nWill interrupt to FRONT in %.0fs\n→ Drag to ⚔ COMBAT WINDOW!" % [
		icon, mtype.replace("_", " ").to_upper(), urgency, escalate_in]
	get_tree().create_timer(3.5).timeout.connect(
		func(): if is_instance_valid(_monster_alert): _monster_alert.visible = false,
		CONNECT_ONE_SHOT)

func _try_defeat_monster(q: Array, which: String) -> void:
	if q.is_empty(): return
	var data := q[0] as Dictionary
	if not data.get("is_monster", false): return
	q.pop_front()
	_escalation_t.erase(data["id"]); _monster_ids.erase(data["id"])
	_stat["monster_defeated"] += 1; _stat["dequeue_count"] += 1
	var mtype: String = data["type"]; var nd := data["node"] as Node2D
	var reward: int = MONSTER_REWARD.get(mtype, 40)
	_show_operation_label("DEQUEUE ✓\nMonster defeated — interrupt resolved!", COL_OP_DEQUEUE)
	if is_instance_valid(nd):
		_apply_correct(nd, reward); _float_label(nd, "DEQUEUE", COL_OP_DEQUEUE)
		var tw := nd.create_tween()
		tw.tween_property(nd, "rotation", nd.rotation + TAU, 0.4)
		tw.parallel().tween_property(nd, "scale", Vector2.ZERO, 0.4)
		tw.parallel().tween_property(nd, "modulate:a", 0.0, 0.4)
		tw.tween_callback(nd.queue_free)
	_refresh_algo_panel("dequeue" if not q.is_empty() else "isEmpty", q)
	_reflow(which); _hint_lbl.text = _idle_hint()
	_restore_held_citizen(which)
	if _score >= _p["target_score"]:
		var acc := _accuracy()
		if _p["accuracy_target"] <= 0.0 or acc >= _p["accuracy_target"]:
			_end_game(true)

# ─────────────────────────────────────────────────────────────────────────────
#  PRIORITY / VIP HOLD
# ─────────────────────────────────────────────────────────────────────────────
func _do_vip_priority(data: Dictionary, q: Array, which: String) -> void:
	var nd := data["node"] as Node2D
	if not q.is_empty() and q[0]["id"] != data["id"]:
		var displaced: Dictionary = q[0]; var dn := displaced["node"] as Node2D
		q.erase(displaced); displaced["in_queue"] = false
		var wait: Array
		match which:
			"b": wait = _waiting_b
			"c": wait = _waiting_c
			_:   wait = _waiting_a
		wait.append(displaced)
		var wait_x: float = WAIT_X_A + (wait.size() - 1) * 70.0
		var row_y: float
		match which:
			"b": row_y = _row_y("b")
			"c": row_y = _row_y("c")
			_:   row_y = ROW_A_Y
		# Save hold info for restore
		_hold_slot  = displaced
		_hold_which = which
		if is_instance_valid(dn):
			dn.modulate = Color(0.8, 0.8, 1.0)
			var tw := dn.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			tw.tween_property(dn, "position", Vector2(wait_x, row_y), 0.4)
			tw.tween_callback(func():
				if is_instance_valid(dn):
					dn.modulate = Color.WHITE
					if dn is AnimatedSprite2D: (dn as AnimatedSprite2D).play("idle"))
		_show_hold_indicator(wait_x, row_y)

	q.erase(data); q.push_front(data)
	_reflow(which)
	_vip_alert.visible = true
	var plevel2: int = data.get("priority_level", 1)
	_vip_lbl.text = (
		"%s  PRIORITY LEVEL %d\n" +
		"Sorted insert: level %d beats level 0\n" +
		"Displaced citizen → waiting area (will return)\n" +
		"This is O(n) priority queue insertion!"
	) % [PRIORITY_LABELS.get(plevel2, "⭐ VIP"), plevel2, plevel2]
	get_tree().create_timer(4.0).timeout.connect(
		func(): if is_instance_valid(_vip_alert): _vip_alert.visible = false,
		CONNECT_ONE_SHOT)
	_show_context_feedback(nd,
		"%s → FRONT (level %d)" % [PRIORITY_LABELS.get(plevel2,"VIP"), plevel2],
		PRIORITY_COLORS.get(plevel2, Color(1.0, 0.85, 0.1)))

func _show_hold_indicator(wait_x: float, row_y: float) -> void:
	if is_instance_valid(_hold_node): _hold_node.queue_free()
	_hold_node = Node2D.new(); _hold_node.position = Vector2(wait_x, row_y - 40); add_child(_hold_node)
	var lbl := Label.new(); lbl.text = "↩ ON HOLD"
	if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	lbl.position = Vector2(-30, 0); _hold_node.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_hold_node.queue_free)

func _restore_held_citizen(which: String) -> void:
	# Only restore if the hold belongs to this queue and the slot is occupied
	if _hold_slot.is_empty(): return
	if _hold_which != which: return
	var q: Array
	match which:
		"b": q = _queue_b
		"c": q = _queue_c
		_:   q = _queue_a
	var held := _hold_slot
	_hold_slot  = {}
	_hold_which = ""
	# Re-enqueue using sorted insert so relative priority is still respected
	var insert_idx: int = q.size()
	var held_level: int = held.get("priority_level", 0)
	for i in range(q.size()):
		if held_level > (q[i] as Dictionary).get("priority_level", 0):
			insert_idx = i; break
	q.insert(insert_idx, held)
	held["in_queue"] = true
	var dn := held["node"] as Node2D
	if is_instance_valid(dn):
		var req: String = held.get("request", "")
		# Don't restore service color tint in peek-required tiers
		dn.modulate = Color.WHITE if _p.get("peek_required", false) or req == "" else SERVICE_COLOR[req]
	if is_instance_valid(_hold_node):
		_hold_node.queue_free(); _hold_node = null
	_reflow(which)
	_show_context_feedback(
		dn if is_instance_valid(dn) else Node2D.new(),
		"↩ Returned from hold", Color(0.6, 0.8, 1.0))

# ─────────────────────────────────────────────────────────────────────────────
#  REFLOW
# ─────────────────────────────────────────────────────────────────────────────
func _reflow(which: String) -> void:
	var q: Array; var row_y: float
	match which:
		"b": q = _queue_b; row_y = _row_y("b")
		"c": q = _queue_c; row_y = _row_y("c")
		_:   q = _queue_a; row_y = ROW_A_Y

	for i in range(q.size()):
		var nd := q[i]["node"] as Node2D
		if not is_instance_valid(nd): continue
		var dest := Vector2(FRONT_X + i * SLOT_W, row_y)
		var moving_left := dest.x < nd.position.x - 4.0
		if nd is AnimatedSprite2D:
			var anim_nd := nd as AnimatedSprite2D
			if moving_left:
				if anim_nd.animation != "walk": anim_nd.play("walk")
			else:
				if anim_nd.animation != "idle": anim_nd.play("idle")
		nd.position.y = row_y
		var tw := nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		tw.tween_property(nd, "position:x", dest.x, 0.4)
		if moving_left and nd is AnimatedSprite2D:
			var anim_nd2 := nd as AnimatedSprite2D
			tw.tween_callback(func(): if is_instance_valid(anim_nd2): anim_nd2.play("idle"))

		if q[i].get("is_monster", false):
			if i == 0: nd.modulate = COL_ESCALATED
		else:
			var request: String = q[i].get("request", "")
			var is_front := i == 0
			var is_back  := i == q.size() - 1 and q.size() > 1
			# In peek-required tiers, don't tint by service color — it gives away
			# the citizen's request before the player peeks.
			var hide_svc_color: bool = _p.get("peek_required", false)
			if is_front:
				var plvl: int = q[i].get("priority_level", 0)
				if plvl > 0:
					nd.modulate = PRIORITY_COLORS.get(plvl, COL_FRONT)
				elif _p["highlight_front"]:
					nd.modulate = COL_FRONT
				else:
					nd.modulate = COL_WHITE if hide_svc_color or request == "" else SERVICE_COLOR[request]
			elif is_back:
				nd.modulate = COL_BACK.darkened(0.3) if hide_svc_color or request == "" \
					else SERVICE_COLOR[request].lerp(COL_BACK, 0.3)
			else:
				nd.modulate = COL_WHITE if hide_svc_color or request == "" else SERVICE_COLOR[request].darkened(0.1)

	var arrow := _arrow_a if which == "a" else _arrow_b
	if is_instance_valid(arrow):
		arrow.visible = not q.is_empty()
		if not q.is_empty(): arrow.position = Vector2(FRONT_X, row_y - 56)

func _reflow_waiting(which: String) -> void:
	var wait: Array; var row_y: float
	match which:
		"b": wait = _waiting_b; row_y = _row_y("b")
		"c": wait = _waiting_c; row_y = _row_y("c")
		_:   wait = _waiting_a; row_y = ROW_A_Y
	for i in range(wait.size()):
		var nd := wait[i]["node"] as Node2D
		if not is_instance_valid(nd): continue
		var dest := Vector2(WAIT_X_A + i * 70.0, row_y)
		nd.position.y = row_y
		nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)\
			.tween_property(nd, "position:x", dest.x, 0.22)

# ─────────────────────────────────────────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _alive: return
	if _tut_locked: return

	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed: _on_press(get_global_mouse_position())
			else:         _on_release(get_global_mouse_position())
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			_try_peek(get_global_mouse_position())

	elif event is InputEventMouseMotion and _is_dragging and _drag_node != null:
		_drag_node.global_position = get_global_mouse_position()
		_drag_node.position        = _drag_node.global_position
		_update_drag_ghost(get_global_mouse_position())

func _on_press(pos: Vector2) -> void:
	# Close peek panel on any left-click
	if is_instance_valid(_peek_panel): _peek_panel.visible = false

	_try_start_drag_waiting(pos, _waiting_a, "wait_a"); if _is_dragging: return
	_try_start_drag_waiting(pos, _waiting_b, "wait_b"); if _is_dragging: return
	_try_start_drag_waiting(pos, _waiting_c, "wait_c"); if _is_dragging: return
	_try_start_drag_queue(pos, _queue_a, "queue_a");    if _is_dragging: return
	if _p.get("tri_queue", false):
		_try_start_drag_queue(pos, _queue_b, "queue_b"); if _is_dragging: return
		_try_start_drag_queue(pos, _queue_c, "queue_c")

func _try_start_drag_waiting(pos: Vector2, wait: Array, from_key: String) -> void:
	for data: Dictionary in wait:
		var nd := data["node"] as Node2D
		if not is_instance_valid(nd): continue
		if nd.global_position.distance_to(pos) < WAIT_AREA_HIT:
			_is_dragging = true; _drag_node = nd; _drag_data = data; _drag_from = from_key
			nd.z_index = 50
			_drag_ghost.modulate = Color(0.4, 1.0, 0.5, 0.4); _drag_ghost.visible = true
			_show_overlay_hint("Drag to the BACK ▶ of the queue to ENQUEUE", 4.0)
			return

func _try_start_drag_queue(pos: Vector2, q: Array, from_key: String) -> void:
	if q.is_empty(): return
	var front_nd := q[0]["node"] as Node2D
	if not is_instance_valid(front_nd): return

	if front_nd.global_position.distance_to(pos) < HIT_R:
		_is_dragging = true; _drag_node = front_nd; _drag_data = q[0]; _drag_from = from_key
		front_nd.z_index = 50
		_drag_ghost.modulate = Color(0.4, 0.8, 1.0, 0.4); _drag_ghost.visible = true
		var req: String = q[0].get("request", "")
		if q[0].get("is_monster", false):
			_show_overlay_hint("⚔ Drag to COMBAT window", 4.0)
		elif req != "" and _p.get("multi_window", false):
			_show_overlay_hint(
				"Drag to the %s %s window → DEQUEUE" % [SERVICE_ICON.get(req,"?"), req.to_upper()],
				4.0)
			_highlight_window(req)
		else:
			_show_overlay_hint("Drag FRONT citizen → service window → DEQUEUE", 4.0)
		return

	# Non-front click → FIFO violation
	for i in range(1, q.size()):
		var nd: Node2D = q[i]["node"] as Node2D
		if not is_instance_valid(nd): continue
		if nd.global_position.distance_to(pos) < HIT_R:
			_stat["fifo_violation"] += 1; _stat["mid_insert_block"] += 1
			_apply_wrong(nd, _p["penalty"],
				"FIFO Violation!\nCannot access position %d.\nOnly FRONT can be dequeued." % (i + 1))
			_show_operation_label("FIFO VIOLATION!\nQueues only dequeue from FRONT", COL_WRONG)
			_pulse_node(q[0]["node"] as Node2D,
				COL_MONSTER if q[0].get("is_monster", false) else COL_FRONT)
			if _tut_step == 5: _advance_tutorial(5)
			return

func _on_release(pos: Vector2) -> void:
	if not _is_dragging: return
	_is_dragging = false; _drag_ghost.visible = false
	_dismiss_hint()
	_highlight_window("")   # clear all window glow

	# Guard: citizen may have been freed mid-drag (patience timeout, etc.)
	if not is_instance_valid(_drag_node):
		_drag_node = null; _drag_data = {}; _drag_from = ""
		return

	if _drag_node: _drag_node.z_index = 10

	var is_from_wait := _drag_from in ["wait_a", "wait_b", "wait_c"]
	var which_str: String
	match _drag_from:
		"wait_b", "queue_b": which_str = "b"
		"wait_c", "queue_c": which_str = "c"
		_:                   which_str = "a"
	var q: Array
	match which_str:
		"b": q = _queue_b
		"c": q = _queue_c
		_:   q = _queue_a

	if is_from_wait:
		var drop_pos := (_drag_node as Node2D).global_position
		var row_y_w: float
		match which_str:
			"b": row_y_w = _row_y("b")
			"c": row_y_w = _row_y("c")
			_:   row_y_w = ROW_A_Y
		var back_pos    := _get_back_slot_pos(which_str)
		var near_back   := drop_pos.distance_to(back_pos) < SNAP_SVC * 2.5
		var min_x: float = FRONT_X - SLOT_W if q.is_empty() \
			else FRONT_X + float(max(q.size()-1, 0)) * SLOT_W - SLOT_W * 0.5
		var dropped_right: bool = drop_pos.x > min_x and abs(drop_pos.y - row_y_w) < 90.0

		if near_back or dropped_right:
			_try_enqueue(_drag_data, which_str)
		else:
			var mid_blocked := false
			for i in range(q.size() - 1):
				var slot_pos := Vector2(FRONT_X + i * SLOT_W, row_y_w)
				if drop_pos.distance_to(slot_pos) < HIT_R:
					_stat["mid_insert_block"] += 1
					_apply_wrong(_drag_node, 0,
						"Can't insert in the middle!\nQueues only accept at the BACK.")
					_show_operation_label("INVALID!\nEnqueue at the BACK only", COL_WRONG)
					mid_blocked = true; break
			if not mid_blocked:
				_show_overlay_hint("Drop to the RIGHT side (BACK) of the queue to ENQUEUE!", 3.0)
			_reflow_waiting(which_str)
	else:
		# Guard again before casting _drag_node in the citizen/monster branch
		if not is_instance_valid(_drag_node):
			_drag_node = null; _drag_data = {}; _drag_from = ""
			return
		var is_monster: bool = _drag_data.get("is_monster", false)
		if is_monster:
			var drop_pos    := (_drag_node as Node2D).global_position
			var combat_y    := (ROW_A_Y if which_str == "a" else _row_y("b")) - 110.0
			var combat_pos  := Vector2(SVC_X, combat_y)
			if drop_pos.distance_to(combat_pos) < COMBAT_SNAP:
				_try_defeat_monster(q, which_str)
			else:
				_show_context_feedback(_drag_node,
					"That's a monster!\nDEQUEUE it to the ⚔ COMBAT window.", COL_MONSTER)
				_reflow(which_str)
		else:
			if not _queue_a.is_empty() and (_queue_a[0] as Dictionary).get("is_monster", false):
				_stat["monster_blocked"] += 1
				_show_context_feedback(_drag_node,
					"Monster blocking!\nDrag monster → ⚔ COMBAT first!", COL_MONSTER)
				_reflow(which_str)
			else:
				var drop_pos := (_drag_node as Node2D).global_position
				var served := false

				if _p.get("multi_window", false) and not _extra_windows.is_empty():
					# Find the closest window and register a hit if within snap radius.
					# Use the same radius as the ghost snap so visual and logic match.
					var best_wnd_node = null
					var best_dist: float = SNAP_SVC
					for wnd_node in _window_type_map:
						var wnd := wnd_node as Node2D
						if not is_instance_valid(wnd): continue
						var d := drop_pos.distance_to(wnd.global_position)
						if d < best_dist:
							best_dist     = d
							best_wnd_node = wnd_node
					if best_wnd_node != null:
						_current_drop_gate = _window_type_map[best_wnd_node]
						_try_serve(q, which_str)
						served = true
				else:
					var row_y_drop: float
					match which_str:
						"b": row_y_drop = _row_y("b")
						"c": row_y_drop = _row_y("c")
						_:   row_y_drop = ROW_A_Y
					var svc_pos := Vector2(SVC_X, row_y_drop)
					if drop_pos.distance_to(svc_pos) < SNAP_SVC * 2.5:
						_current_drop_gate = _drag_data.get("request", "")
						_try_serve(q, which_str)
						served = true

				if not served:
					_reflow(which_str)
					if _p.get("multi_window", false):
						_show_overlay_hint("Drag FRONT → matching coloured window\n💰 TAX  🍞 FOOD  📜 PERMIT\n(PEEK first to check type!)", 4.0)
					else:
						_show_overlay_hint("Drag FRONT citizen → service window on the left", 3.0)

	_drag_node = null; _drag_data = {}; _drag_from = ""

# Stored for drop gate resolution (set just before calling _try_serve)
var _current_drop_gate: String = ""

func _get_back_slot_pos(which: String) -> Vector2:
	var q: Array; var row_y: float
	match which:
		"b": q = _queue_b; row_y = _row_y("b")
		"c": q = _queue_c; row_y = _row_y("c")
		_:   q = _queue_a; row_y = ROW_A_Y
	var idx: int = min(q.size(), _p["capacity"] - 1)
	return Vector2(FRONT_X + idx * SLOT_W, row_y)

func _update_drag_ghost(pos: Vector2) -> void:
	var is_from_wait := _drag_from in ["wait_a", "wait_b", "wait_c"]
	var which_str    := "a" if _drag_from in ["wait_a", "queue_a"] else \
						("b" if _drag_from in ["wait_b", "queue_b"] else "c")

	if is_from_wait:
		var back_pos := _get_back_slot_pos(which_str)
		var dist     := pos.distance_to(back_pos)
		_drag_ghost.position = back_pos if dist < SNAP_SVC * 1.2 else pos
		_drag_ghost.modulate = Color(0.4, 1.0, 0.5, 0.7) if dist < SNAP_SVC * 1.2 \
			else Color(0.5, 1.0, 0.5, 0.35)
	elif _drag_data.get("is_monster", false):
		var combat := _combat_a if which_str == "a" else _combat_b
		if not is_instance_valid(combat): return
		var dist := pos.distance_to(combat.global_position)
		_drag_ghost.position = combat.global_position if dist < COMBAT_SNAP else pos
		_drag_ghost.modulate = Color(1.0, 0.4, 0.4, 0.7) if dist < COMBAT_SNAP \
			else Color(1.0, 0.3, 0.3, 0.35)
	else:
		# In multi-window tiers, snap to whichever window is closest to the cursor.
		# In single-window tiers, just use _svc_a (or _svc_b for lane b).
		var snap_target: Vector2 = Vector2.ZERO
		var snap_dist:   float   = INF
		if _p.get("multi_window", false) and not _window_type_map.is_empty():
			for wnd_node in _window_type_map:
				var wnd := wnd_node as Node2D
				if not is_instance_valid(wnd): continue
				var d := pos.distance_to(wnd.global_position)
				if d < snap_dist:
					snap_dist   = d
					snap_target = wnd.global_position
		else:
			var svc := _svc_a if which_str == "a" else _svc_b
			if not is_instance_valid(svc): return
			snap_dist   = pos.distance_to(svc.global_position)
			snap_target = svc.global_position
		var in_snap := snap_dist < SNAP_SVC
		_drag_ghost.position = snap_target if in_snap else pos
		_drag_ghost.modulate = Color(0.4, 1.0, 0.4, 0.6) if in_snap \
			else Color(1.0, 1.0, 1.0, 0.35)

# ─────────────────────────────────────────────────────────────────────────────
#  PATIENCE
# ─────────────────────────────────────────────────────────────────────────────
func _tick_patience(delta: float, q: Array, which: String) -> void:
	var leavers: Array = []
	for data: Dictionary in q:
		if data.get("is_monster", false): continue
		var cid: int = data["id"]
		if cid not in _patience_t: continue
		_patience_t[cid] -= delta
		var nd := data["node"] as Node2D
		if is_instance_valid(nd):
			var frac := clampf(_patience_t[cid] / _p["patience"], 0.0, 1.0)
			var svc_col: Color = SERVICE_COLOR.get(data.get("request", ""), COL_WHITE) as Color
			nd.modulate = svc_col.lerp(COL_WRONG, 1.0 - frac)
		if _patience_t[cid] <= 0.0: leavers.append(data)
	for data: Dictionary in leavers:
		q.erase(data); _patience_t.erase(data["id"]); _stat["patience_lost"] += 1
		var nd := data["node"] as Node2D
		if is_instance_valid(nd):
			_show_context_feedback(nd, "Left the queue!\nServe faster.", COL_WRONG)
			nd.create_tween().tween_property(nd, "modulate:a", 0.0, 0.4)\
				.finished.connect(nd.queue_free)
		_reflow(which); _apply_life_loss("")

func _tick_patience_waiting(delta: float, wait: Array, which: String) -> void:
	var leavers: Array = []
	for data: Dictionary in wait:
		var cid: int = data["id"]
		if cid not in _patience_t: continue
		_patience_t[cid] -= delta
		var nd := data["node"] as Node2D
		if is_instance_valid(nd):
			var frac := clampf(_patience_t[cid] / (_p["patience"] * 1.5), 0.0, 1.0)
			nd.modulate = COL_WHITE.lerp(COL_WRONG, 1.0 - frac)
		if _patience_t[cid] <= 0.0: leavers.append(data)
	for data: Dictionary in leavers:
		wait.erase(data); _patience_t.erase(data["id"]); _stat["patience_lost"] += 1
		var nd := data["node"] as Node2D
		if is_instance_valid(nd):
			_show_context_feedback(nd, "Left waiting area!\nENQUEUE faster.", COL_WRONG)
			nd.create_tween().tween_property(nd, "modulate:a", 0.0, 0.4)\
				.finished.connect(nd.queue_free)
		_reflow_waiting(which); _apply_life_loss("")

# ─────────────────────────────────────────────────────────────────────────────
#  FEEDBACK HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _apply_correct(nd: Node2D, pts: int) -> void:
	_stat["correct"] += 1; _combo += 1; _combo_decay = COMBO_TTL
	var earned: int = pts + (pts * _combo / 5)
	_score += earned; _score_lbl.text = "Score: %d" % _score
	_combo_lbl.text = "×%d COMBO!" % _combo if _combo > 1 else ""
	_acc_lbl.text   = "Accuracy: %.0f%%" % _accuracy()
	_flash(nd, COL_FRONT); _bounce(nd); _float_label(nd, "+%d" % earned, COL_FRONT)
	AudioManager.play_sfx(PATH_SFX_OK); _log("correct", earned)

func _apply_wrong(nd: Node2D, penalty: int, msg: String) -> void:
	_combo = 0; _combo_lbl.text = ""
	if penalty > 0: _score = max(0, _score - penalty); _score_lbl.text = "Score: %d" % _score
	_acc_lbl.text = "Accuracy: %.0f%%" % _accuracy()
	_flash(nd, COL_WRONG); _shake(nd)
	if not msg.is_empty(): _show_context_feedback(nd, msg, COL_WRONG)
	AudioManager.play_sfx(PATH_SFX_FAIL); _log("wrong", -penalty)

func _apply_life_loss(msg: String) -> void:
	_lives -= 1; _refresh_lives()
	if not msg.is_empty(): _hint_lbl.text = msg
	if _lives <= 0: _end_game(false)

func _show_context_feedback(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new(); lbl.text = text; lbl.z_index = 200
	if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	par.add_child(lbl); lbl.position = nd.position + Vector2(-60, -70)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -50), 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)

func _pulse_node(nd: Node2D, color: Color) -> void:
	if not is_instance_valid(nd): return
	var tw := nd.create_tween()
	for _i in 4:
		tw.tween_property(nd, "modulate", color, 0.07)
		tw.tween_property(nd, "modulate", COL_WHITE, 0.07)

# ─────────────────────────────────────────────────────────────────────────────
#  ANIMATION HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _animate_front_arrow(arrow: Node2D) -> void:
	if not is_instance_valid(arrow): return
	var tw := arrow.create_tween().set_loops()
	tw.tween_property(arrow, "position:y", arrow.position.y - 8, 0.5)
	tw.tween_property(arrow, "position:y", arrow.position.y, 0.5)

func _flash(nd: Node2D, c: Color) -> void:
	if not is_instance_valid(nd): return
	nd.create_tween().tween_property(nd, "modulate", c, 0.06)
	nd.create_tween().tween_property(nd, "modulate", COL_WHITE, 0.28)

func _bounce(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var s  := nd.scale
	var tw := nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "scale", s * 1.4, 0.08)
	tw.tween_property(nd, "scale", s, 0.18)

func _shake(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var o  := nd.position
	var tw := nd.create_tween()
	for _i in 6:
		tw.tween_property(nd, "position", o + Vector2(randf_range(-7, 7), randf_range(-4, 4)), 0.04)
	tw.tween_property(nd, "position", o, 0.04)

func _float_label(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new(); lbl.text = text; lbl.z_index = 200
	if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	par.add_child(lbl); lbl.position = nd.position + Vector2(-20, -44)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0, -40), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  CLOCK / HUD
# ─────────────────────────────────────────────────────────────────────────────
func _tick_clock() -> void:
	_time_left -= 1.0
	_timer_lbl.text = "⏱ %d" % max(0, int(_time_left))
	if _time_left <= 0.0: _end_game(false)

func _refresh_lives() -> void:
	for c in _lives_row.get_children(): c.queue_free()
	for i in 3:
		var lbl := Label.new(); lbl.text = "❤" if i < _lives else "🖤"
		lbl.add_theme_font_size_override("font_size", 22); _lives_row.add_child(lbl)

func _accuracy() -> float:
	var total := _stat_total_decisions()
	return 100.0 if total == 0 else float(_stat["correct"]) / float(total) * 100.0

func _stat_total_decisions() -> int:
	return _stat["correct"] + _stat["fifo_violation"] + \
		   _stat["service_miss"] + _stat["lane_miss"] + _stat["peek_miss"]

# ─────────────────────────────────────────────────────────────────────────────
#  ANALYTICS
# ─────────────────────────────────────────────────────────────────────────────
func _log(_action: String, _value: int) -> void:
	pass  # saved via PlayerProfile.save_chapter_result at end-of-game

# ─────────────────────────────────────────────────────────────────────────────
#  END GAME
# ─────────────────────────────────────────────────────────────────────────────
func _end_game(success: bool) -> void:
	if not _alive: return
	_alive = false; _spawn_tmr.stop(); _game_tmr.stop()

	var final_correct: int  = _stat["dequeue_count"] + _stat["monster_defeated"]
	var final_wrongs:  int  = _stat["fifo_violation"] + _stat["service_miss"] + \
							  _stat["lane_miss"] + _stat["peek_miss"]
	var final_total:   int  = final_correct + final_wrongs
	var final_acc:     float = 100.0 if final_total == 0 else \
		float(final_correct) / float(final_total) * 100.0
	var grade: String = _calc_grade(success, final_acc)
	var stars: int    = _grade_to_stars(grade)
	var current_tier: int = TIER_PARAMS.find(_p)

	var stats: Dictionary = {
		"success": success, "score": _score, "grade": grade, "stars": stars,
		"accuracy": final_acc, "correct": final_correct,
		"fifo_violation": _stat["fifo_violation"], "service_miss": _stat["service_miss"],
		"lane_miss": _stat["lane_miss"], "vip_ignored": _stat["vip_ignored"],
		"patience_lost": _stat["patience_lost"], "monster_defeated": _stat["monster_defeated"],
		"monster_escaped": _stat["monster_escaped"], "monster_blocked": _stat["monster_blocked"],
		"enqueue_count": _stat["enqueue_count"], "dequeue_count": _stat["dequeue_count"],
		"overflow_count": _stat["overflow_count"],
		"peek_count": _stat["peek_count"], "peek_miss": _stat["peek_miss"],
		"tier": current_tier, "tier_concept": _p.get("concept", "FIFO"),
	}

	var screen_chapter_id: int = current_tier + 1
	if has_node("/root/PlayerProfile"):
		var mistakes: Dictionary = {
			"fifo_violation": _stat["fifo_violation"],
			"service_miss":   _stat["service_miss"],
			"lane_miss":      _stat["lane_miss"],
			"peek_miss":      _stat["peek_miss"],
			"overflow":       _stat["overflow_count"],
		}
		# Update progress in memory immediately (save_chapter_result also fires
		# the async Firestore write, but we need in-memory to be correct NOW).
		PlayerProfile.save_chapter_result(screen_chapter_id, _score, stars, final_acc, mistakes)

	if is_instance_valid(_fail_summary):
		_fail_summary.visible = true
		_fail_lbl.text = "%s  Grade: %s  |  Acc: %.0f%%  |  Peek:%d  Enq:%d  Deq:%d" % [
			"✓ CLEARED!" if success else "✗ FAILED",
			grade, final_acc, _stat["peek_count"],
			_stat["enqueue_count"], _stat["dequeue_count"]
		]

	await get_tree().create_timer(1.2).timeout

	if has_node("/root/ChapterCompleteScreen"):
		var ccs := get_node("/root/ChapterCompleteScreen")
		ccs.call("show_result", screen_chapter_id, stats)
	elif has_node("/root/GameRouter"):
		get_node("/root/GameRouter").call("chapter_complete", screen_chapter_id, _score, stars)
	else:
		_advance_to_next_tier(success, current_tier)

func _advance_to_next_tier(success: bool, from_tier: int) -> void:
	if not success:
		# Retry: reload at the same tier. Force PlayerProfile in-memory so
		# the tier detection in _ready() reads the correct (incomplete) chapter.
		get_tree().reload_current_scene()
		return
	# Mark current chapter complete in PlayerProfile memory RIGHT NOW so the
	# tier detection in _ready() sees it even if Firestore hasn't responded yet.
	var completed_chapter: int = from_tier + 1
	if has_node("/root/PlayerProfile"):
		var existing := PlayerProfile.progress.get(completed_chapter, {}) as Dictionary
		PlayerProfile.progress[completed_chapter] = {
			"best_score": max(_score, existing.get("best_score", 0) as int),
			"stars":      max(_grade_to_stars(_calc_grade(true, _accuracy())),
						existing.get("stars", 0) as int),
			"complete":   true,
			"accuracy":   _accuracy(),
		}
	# Navigate to the next chapter
	var next_chapter_id: int = clamp(from_tier + 1, 0, TIER_PARAMS.size() - 1) + 1
	if has_node("/root/GameRouter"):
		get_node("/root/GameRouter").call("go_to_chapter", next_chapter_id)
	else:
		get_tree().reload_current_scene()

func _calc_grade(success: bool, acc: float) -> String:
	if not success: return "C" if acc >= 60.0 else "F"
	var total := _stat_total_decisions()
	var effective_acc := 100.0 if total == 0 else acc
	if effective_acc >= 95.0: return "S"
	if effective_acc >= 82.0: return "A"
	if effective_acc >= 68.0: return "B"
	return "C"

func _grade_to_stars(grade: String) -> int:
	match grade:
		"S", "A": return 3
		"B":      return 2
		"C":      return 1
		_:        return 0

func on_retry_requested() -> void:
	_advance_to_next_tier(false, TIER_PARAMS.find(_p))

func on_next_requested() -> void:
	# GameRouter.current_chapter is already set correctly by ChapterCompleteScreen
	# before this is called — _ready() reads it directly. Just reload.
	get_tree().reload_current_scene()
