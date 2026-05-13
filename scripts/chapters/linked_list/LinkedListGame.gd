# =============================================================================
# AlgoQuest — Chapter 4: Oracle's Forest (BST) v4
# File: scripts/chapters/tree/TreeGame.gd
#
# ARCHITECTURE: Operation-Round Loop
#   The tree is an instrument, not a destination.
#   Each round assigns one BST operation. The tree persists and changes.
#   Player is scored on HOW they operate, not just whether they finish.
#
# TIER MAP (5 tiers, each adds one new operation type):
#   BEGINNER  — INSERT only, fully guided. Learns the BST rule.
#   EASY      — INSERT unguided + SEARCH (tap the path). Learns lookup cost.
#   NORMAL    — INSERT + SEARCH + TRAVERSE (all 3 orders). Learns output order.
#   HARD      — All above + DELETE (all 3 cases). Learns structural mutation.
#   EXPERT    — All above + REBALANCE. Learns why balance matters for O(log n).
#
# ROUND FLOW:
#   _start_round(type) → player acts → _end_round(success) → next round
#
# SCORING:
#   INSERT   — 100 pts at depth 1, scaled down by depth (shallow = fast = good)
#   SEARCH   — 80 pts full path correct, -20 per wrong tap
#   TRAVERSE — 100 pts per full correct sequence
#   DELETE   — 60 pts base + 40 bonus for predicting successor correctly
#   REBALANCE— 30 pts per round the tree stays balanced; 80 bonus on completion
# =============================================================================

extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  ASSETS
# ─────────────────────────────────────────────────────────────────────────────
const PATH_FONT        := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_OK      := "res://assets/audio/sfx/tile_place.ogg"
const PATH_SFX_FAIL    := "res://assets/audio/sfx/fail.ogg"
const PATH_SFX_WIN     := "res://assets/audio/sfx/level_up.ogg"
const PATH_SFX_PICKUP  := "res://assets/audio/sfx/tile_pickup.wav"
const PATH_SFX_GHOST   := "res://assets/audio/sfx/tile_pickup.wav"
const PATH_BGM         := "res://assets/audio/music/forest.ogg"

const NODE_ICONS: Array[String] = [
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
	"res://assets/art/tree/nodes/runeBlack_tile_036.png",
]
const ROOT_ICON := "res://assets/art/tree/nodes/runeBlack_tileOutline_036.png"

# ─────────────────────────────────────────────────────────────────────────────
#  LAYOUT
# ─────────────────────────────────────────────────────────────────────────────
const ROOT_POS   := Vector2(640.0, 100.0)
const LEVEL_H    := 85.0
const SPREAD_MUL := 180.0
const NODE_SCALE := Vector2(1.2, 1.2)
const POOL_Y     := 570.0
const SNAP_DIST  := 64.0
const MAGNET_R   := 100.0
const NODE_HIT   := 26.0
const MAX_DEPTH  := 4

const GHOST_R        := 30.0
const COL_GHOST_OK   := Color(0.3, 1.0, 0.5, 0.3)
const COL_GHOST_NO   := Color(1.0, 0.2, 0.2, 0.25)
const COL_GHOST_SNAP := Color(0.3, 1.0, 0.5, 0.75)
const COL_EDGE       := Color(0.55, 0.85, 0.45, 0.85)
const COL_OK         := Color(0.3, 1.0, 0.4)
const COL_WRONG      := Color(1.0, 0.15, 0.15)
const COL_WHITE      := Color.WHITE
const COL_HEAD       := Color(1.0, 0.85, 0.1)
const COL_TRAV       := Color(0.4, 0.9, 1.0)
const COL_TRACE      := Color(1.0, 0.9, 0.3, 0.85)
const COL_ANCESTRY   := Color(1.0, 0.85, 0.1, 0.9)
const COL_LEFT_SUB   := Color(0.45, 0.65, 1.0, 0.35)
const COL_RIGHT_SUB  := Color(1.0, 0.65, 0.3, 0.35)
const COL_BALANCE_OK := Color(0.3, 1.0, 0.4)
const COL_BALANCE_NO := Color(1.0, 0.15, 0.15)
const COL_PREORDER   := Color(1.0, 0.6, 0.2, 1.0)
const COL_POSTORDER  := Color(0.8, 0.4, 1.0, 1.0)
const COL_SEARCH_HI  := Color(0.4, 0.9, 1.0, 1.0)
const COL_ELIM       := Color(0.25, 0.25, 0.25, 0.4)
const COL_DELETE_HI  := Color(1.0, 0.45, 0.1, 1.0)
const COL_SUCC_HI    := Color(0.3, 1.0, 0.55, 1.0)

# ─────────────────────────────────────────────────────────────────────────────
#  ENUMS
# ─────────────────────────────────────────────────────────────────────────────
enum GameState { IDLE, DRAG, ROUND_INTRO, SEARCH, TRAVERSE, DELETE_PREDICT,
				 DELETE_EXEC, REBALANCE, REBALANCE_DELETE, REBALANCE_INSERT, COMPLETE }

enum RoundType  { INSERT, SEARCH, TRAVERSE, DELETE, REBALANCE }

enum TravMode   { INORDER, PREORDER, POSTORDER }

# ─────────────────────────────────────────────────────────────────────────────
#  TIER PARAMS
#  rounds_available  — which RoundTypes can appear
#  insert_guided     — ghost slots always visible
#  insert_count      — values added per INSERT round
#  total_rounds      — how many rounds before level completes
#  balance_required  — tree must stay |BF|≤1; violations penalised
#  allow_delete      — DELETE rounds enabled
#  hints             — contextual hint box shown
# ─────────────────────────────────────────────────────────────────────────────
const TIER_PARAMS: Array[Dictionary] = [
	# 0 — BEGINNER
	{
		"concept":          "BEGINNER",
		"rounds_available": [RoundType.INSERT],
		"insert_guided":    true,
		"insert_count":     1,
		"total_rounds":     5,
		"balance_required": false,
		"allow_delete":     false,
		"hints":            true,
		"subtree_tint":     false,
		"penalty":          0,
		"accuracy_target":  0.0,
	},
	# 1 — EASY
	{
		"concept":          "EASY",
		"rounds_available": [RoundType.INSERT, RoundType.SEARCH],
		"insert_guided":    false,
		"insert_count":     1,
		"total_rounds":     6,
		"balance_required": false,
		"allow_delete":     false,
		"hints":            true,
		"subtree_tint":     false,
		"penalty":          10,
		"accuracy_target":  60.0,
	},
	# 2 — NORMAL
	{
		"concept":          "NORMAL",
		"rounds_available": [RoundType.INSERT, RoundType.SEARCH, RoundType.TRAVERSE],
		"insert_guided":    false,
		"insert_count":     1,
		"total_rounds":     7,
		"balance_required": false,
		"allow_delete":     false,
		"hints":            false,
		"subtree_tint":     false,
		"penalty":          15,
		"accuracy_target":  65.0,
	},
	# 3 — HARD
	{
		"concept":          "HARD",
		"rounds_available": [RoundType.INSERT, RoundType.SEARCH,
							 RoundType.TRAVERSE, RoundType.DELETE],
		"insert_guided":    false,
		"insert_count":     1,
		"total_rounds":     8,
		"balance_required": false,
		"allow_delete":     true,
		"hints":            false,
		"subtree_tint":     true,
		"penalty":          25,
		"accuracy_target":  70.0,
	},
	# 4 — EXPERT
	{
		"concept":          "EXPERT",
		"rounds_available": [RoundType.INSERT, RoundType.SEARCH,
							 RoundType.TRAVERSE, RoundType.DELETE,
							 RoundType.REBALANCE],
		"insert_guided":    false,
		"insert_count":     1,
		"total_rounds":     10,
		"balance_required": true,
		"allow_delete":     true,
		"hints":            false,
		"subtree_tint":     true,
		"penalty":          40,
		"accuracy_target":  75.0,
	},
]

# Scenario strings for the round intro banner — forest/rune theme.
const SCENARIOS: Dictionary = {
	RoundType.INSERT: [
		"🌿 A new rune has been found.\nCarve it into the Oracle's tree.",
		"🌿 The forest spirits bring a new stone.\nPlace it where it belongs.",
		"🌿 A rune tile arrives at the grove.\nInsert it into the sacred order.",
	],
	RoundType.SEARCH: [
		"🔍 The Oracle seeks a rune.\nTrace the path through the branches.",
		"🔍 A spirit needs a stone.\nFollow the tree to find it.",
		"🔍 Seek the rune in the forest index.\nFewer branches crossed = faster magic.",
	],
	RoundType.TRAVERSE: [
		"📜 Read the runes in order.\nWalk the tree: Left → Root → Right.",
		"📜 Transcribe the grove.\nTouch each stone: Root → Left → Right.",
		"📜 Clear the forest safely.\nVisit leaves first: Left → Right → Root.",
	],
	RoundType.DELETE: [
		"🗡 A rune must be removed.\nCut it from the tree without breaking the order.",
		"🗡 The stone has crumbled.\nPrune it — keep the grove intact.",
		"🗡 Erase this rune from the index.\nMaintain the sacred BST structure.",
	],
	RoundType.REBALANCE: [
		"⚖ The grove leans too far.\nRebalance the branches or magic will slow.",
		"⚖ One side grows too deep.\nMove a stone — keep |BF| ≤ 1.",
		"⚖ The Oracle warns of imbalance.\nRestructure the tree to restore O(log n).",
	],
}

# ─────────────────────────────────────────────────────────────────────────────
#  NODE REFS
# ─────────────────────────────────────────────────────────────────────────────
@onready var _bg:              Sprite2D       = $Background
@onready var _tree_layer:      Node2D         = $TreeLayer
@onready var _edge_layer:      Node2D         = $EdgeLayer
@onready var _ghost_layer:     Node2D         = $GhostLayer
@onready var _trace_layer:     Node2D         = $TraceLayer
@onready var _pool_tray:       Node2D         = $PoolTray
@onready var _complete_banner: Label          = $CompleteBanner
@onready var _trav_dot:        Label          = $TraversalDot
@onready var _trav_timer:      Timer          = $TraversalTimer
@onready var _game_timer:      Timer          = $GameTimer
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
@onready var _balance_lbl:     Label          = $HUD/BalanceLabel
@onready var _trav_btn:        Button         = $HUD/TraversalBtn
@onready var _rot_hint_btn:    Button         = $HUD/RotationHintBtn
@onready var _trav_banner:     Label          = $HUD/TraversalBanner
@onready var _search_btn:      Button         = $HUD/SearchBtn
@onready var _trace_btn:       Button         = $HUD/TraceBtn
@onready var _trace_left_btn:  Button         = $HUD/TraceLeftBtn
@onready var _trace_right_btn: Button         = $HUD/TraceRightBtn
@onready var _trace_overlay:   Label          = $HUD/TraceOverlay
@onready var _trav_challenge_btn: Button      = $HUD/TravChallengeBtn
@onready var _complexity_lbl:  Label          = $HUD/ComplexityLabel
@onready var _fail_summary:    PanelContainer = $HUD/FailSummary
@onready var _fail_lbl:        Label          = $HUD/FailSummary/FailLabel

# ─────────────────────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────────────────────
var _p: Dictionary = {}

# BST: {value, sprite, left, right, parent, pos, depth, height, height_lbl}
var _bst:  Array = []
var _root: int   = -1

# Ghost slots for INSERT rounds
var _ghosts: Array = []

# Drag state (INSERT rounds)
var _drag_pool_idx:  int     = -1
var _drag_offset:    Vector2 = Vector2.ZERO
var _snap_ghost_idx: int     = -1

# Pool (values waiting to be inserted)
var _pool: Array = []

# ── Round system ──────────────────────────────────────────────────────────────
var _state:          GameState = GameState.IDLE
var _current_round:  RoundType = RoundType.INSERT
var _round_number:   int       = 0   # 1-based, shown in HUD
var _rounds_done:    int       = 0
var _round_score:    int       = 0   # points earned this round

# ── Search round state ────────────────────────────────────────────────────────
var _search_target:     int   = -1
var _search_path:       Array = []   # correct sequence of bst indices
var _search_tap_idx:    int   = 0    # how far into path the player is
var _search_mistakes:   int   = 0

# ── Traverse round state ──────────────────────────────────────────────────────
var _trav_mode:         TravMode = TravMode.INORDER
var _trav_order:        Array    = []
var _trav_tap_idx:      int      = 0
var _trav_visited:      Array    = []
var _trav_mistakes:     int      = 0
# Animated auto-traversal (used outside player-tap context)
var _trav_anim_idx:     int      = 0

# ── Delete round state ────────────────────────────────────────────────────────
var _delete_target:     int   = -1   # bst index to delete
var _delete_succ_idx:   int   = -1   # correct inorder successor bst index
var _delete_case:       int   = 0    # 1=leaf 2=one-child 3=two-children
var _delete_awaiting_predict: bool = false  # waiting for player to tap successor

# ── Rebalance round state ─────────────────────────────────────────────────────
var _rebalance_moves:   int   = 0

# ── Traversal animation (round-end summary) ───────────────────────────────────
var _trav_anim_order:   Array = []

# ── Analytics ─────────────────────────────────────────────────────────────────
var _stat := {
	"correct": 0, "wrong": 0,
	"inserts": 0, "searches": 0, "traversals": 0,
	"deletes": 0, "rebalances": 0,
}

var _score:       int   = 0
var _combo:       int   = 0
var _lives:       int   = 3
var _combo_decay: float = 0.0
const COMBO_TTL := 3.0

var _alive:       bool  = false
var _rule_animated: bool = false

var _parallax_layers: Array = []
var _bg_time:         float = 0.0
var _pixel_font:      Font  = null

# ── UI nodes built in code ────────────────────────────────────────────────────
var _instr_bar:   ColorRect = null
var _instr_task:  Label     = null
var _instr_rule:  Label     = null
var _round_banner: ColorRect = null   # full-width intro flash for each round
var _round_lbl:   Label     = null
var _round_sub:   Label     = null
var _round_counter: Label   = null   # "Round 3 / 7" top-right

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font
	var tier := 0
	if has_node("/root/DifficultyManager"):
		tier = DifficultyManager.current_tier
	_p = TIER_PARAMS[clamp(tier, 0, 4)]

	# Hide all optional HUD buttons (they're round-specific, shown per round)
	_trav_btn.visible         = false
	_search_btn.visible       = false
	_trace_btn.visible        = false
	_trace_left_btn.visible   = false
	_trace_right_btn.visible  = false
	_trav_challenge_btn.visible = false
	_rot_hint_btn.visible     = false
	_trace_overlay.visible    = false
	_trav_banner.visible      = false
	_complete_banner.visible  = false
	_trav_dot.visible         = false
	_fail_summary.visible     = false
	_balance_lbl.visible      = false

	_setup_bg()
	_setup_hud()
	_setup_instruction_bar()
	_setup_round_banner()

	# Seed the tree with a root node so the first round has context
	_generate_seed_tree()

	AudioManager.play_bgm(PATH_BGM)
	_alive = true

	# Brief intro then start round 1
	_show_tier_intro()
	get_tree().create_timer(2.8).timeout.connect(_begin_next_round)

# ─────────────────────────────────────────────────────────────────────────────
#  TIER INTRO
# ─────────────────────────────────────────────────────────────────────────────
func _show_tier_intro() -> void:
	var msgs: Dictionary = {
		"BEGINNER": "Welcome to the Oracle's Forest!\nDrag rune tiles onto the sacred tree.\nLeft branch holds smaller runes.\nRight branch holds larger ones.",
		"EASY":     "The forest grows.\nINSERT runes and SEARCH the branches.\nFewer steps to find a rune = stronger magic.",
		"NORMAL":   "Read the grove's order.\nTRAVERSE the tree: Inorder, Preorder, Postorder.\nEach walk reveals a different truth.",
		"HARD":     "The Oracle demands precision.\nDELETE damaged runes without breaking the tree.\nPredict which stone will rise to fill the gap.",
		"EXPERT":   "The grove must stay balanced.\nREBALANCE heavy branches to restore O(log n) magic.\nUnbalanced trees doom spells to O(n) searches.",
	}
	var concept: String = _p["concept"]
	_hint_lbl.text    = msgs.get(concept, "") + "\n\n[The ritual begins in 3 seconds…]"
	_hint_box.visible = true

# ─────────────────────────────────────────────────────────────────────────────
#  SEED TREE — builds a small valid BST before rounds begin
# ─────────────────────────────────────────────────────────────────────────────
func _generate_seed_tree() -> void:
	# Always start with 3 pre-placed nodes (root + left + right child)
	# so every round has a real tree to operate on from turn 1.
	var vals: Array[int] = []
	while vals.size() < 10:
		var v := randi() % 89 + 10   # 10-98 avoids single-digit layout edge cases
		if v not in vals: vals.append(v)

	# Sort and pick root near median so tree has room on both sides
	vals.sort()
	var root_val: int = vals[vals.size() / 2]
	var left_val: int = vals[vals.size() / 4]
	var right_val: int = vals[vals.size() * 3 / 4]

	# Keep the rest as the insert pool (shuffled)
	var remaining: Array[int] = []
	for v in vals:
		if v != root_val and v != left_val and v != right_val:
			remaining.append(v)
	remaining.shuffle()
	# Pool holds enough for the whole game
	for v in remaining:
		_pool.append(v)

	_silent_insert(root_val)
	_silent_insert(left_val)
	_silent_insert(right_val)
	_refresh_ghosts()
	# Build pool sprites now that _pool is populated
	_rebuild_pool_sprites()

# ─────────────────────────────────────────────────────────────────────────────
#  ROUND ORCHESTRATION
# ─────────────────────────────────────────────────────────────────────────────
func _begin_next_round() -> void:
	if _state == GameState.COMPLETE: return
	_rounds_done += 1
	_round_number = _rounds_done

	if _rounds_done > (_p["total_rounds"] as int):
		_play_completion()
		return

	# Pick round type — weighted so INSERT appears ~40% of the time
	# (tree must keep growing to have things to operate on)
	var available: Array = _p["rounds_available"]
	var chosen: RoundType

	# Need at least 2 nodes to do non-insert rounds
	var tree_size := _bst_live_count()
	if tree_size < 3:
		chosen = RoundType.INSERT
	else:
		# Weight INSERT more heavily; other types share the rest equally
		var roll := randi() % 100
		if roll < 40 or available.size() == 1:
			chosen = RoundType.INSERT
		else:
			# Pick from non-insert available types
			var others: Array = available.filter(func(r): return r != RoundType.INSERT)
			if others.is_empty():
				chosen = RoundType.INSERT
			else:
				chosen = others[randi() % others.size()] as RoundType

	_start_round(chosen)

func _start_round(rt: RoundType) -> void:
	_current_round = rt
	_round_score   = 0
	_state         = GameState.ROUND_INTRO
	_clear_trace()
	_restore_all_node_colors()

	# Pick scenario text
	var scenario_list: Array = SCENARIOS[rt]
	var scenario: String     = scenario_list[randi() % scenario_list.size()]

	# Build sub-text describing what the player will do
	var sub := _round_sub_text(rt)

	_show_round_banner(scenario, sub, rt)

	# After banner fades, activate the round
	get_tree().create_timer(2.2).timeout.connect(func(): _activate_round(rt))

func _round_sub_text(rt: RoundType) -> String:
	match rt:
		RoundType.INSERT:
			var v: int = _pool[0] if not _pool.is_empty() else 0
			return "Drag rune  %d  to its place in the tree." % v
		RoundType.SEARCH:
			return "Tap each stone the Oracle would visit."
		RoundType.TRAVERSE:
			var names: Array[String] = [
				"Inorder  (Left → Root → Right)",
				"Preorder  (Root → Left → Right)",
				"Postorder  (Left → Right → Root)",
			]
			_trav_mode = _pick_trav_mode()
			return "Touch stones in  %s  order." % names[_trav_mode]
		RoundType.DELETE:
			return "Click the glowing rune to remove it.\nPredict its replacement for a bonus."
		RoundType.REBALANCE:
			return "Delete a leaf from the heavy side.\nReinsert it on the lighter side."
	return ""

func _pick_trav_mode() -> TravMode:
	# Beginner/Easy only do inorder; Normal+ cycle all three
	if (_p["concept"] as String) in ["BEGINNER", "EASY"]:
		return TravMode.INORDER
	return [TravMode.INORDER, TravMode.PREORDER, TravMode.POSTORDER][randi() % 3]

func _activate_round(rt: RoundType) -> void:
	_state = GameState.IDLE
	match rt:
		RoundType.INSERT:   _activate_insert()
		RoundType.SEARCH:   _activate_search()
		RoundType.TRAVERSE: _activate_traverse()
		RoundType.DELETE:   _activate_delete()
		RoundType.REBALANCE: _activate_rebalance()

# ── INSERT ────────────────────────────────────────────────────────────────────
func _activate_insert() -> void:
	if _pool.is_empty():
		# Refill pool if needed
		_refill_pool(3)

	var v: int = _pool[0]
	_refresh_ghosts()
	_update_instr("INSERT  %d  into the tree — drag it to the correct slot." % v,
				  "Left < Parent < Right")
	_hint_lbl.text    = _insert_hint(v)
	_hint_box.visible = _p["hints"] as bool

	# Beginner: always show ghosts; others: hidden until drag
	if _p["insert_guided"]:
		_show_all_ghosts_colored(v)

# ── SEARCH ────────────────────────────────────────────────────────────────────
func _activate_search() -> void:
	if _bst_live_count() < 2:
		_begin_next_round(); return

	# Pick a random live node to search for
	var live := _live_bst_indices()
	var target_idx: int = live[randi() % live.size()]
	_search_target  = _bst[target_idx]["value"] as int
	_search_path    = _build_search_path(_search_target)
	_search_tap_idx = 0
	_search_mistakes = 0
	_state          = GameState.SEARCH

	_update_instr("SEARCH for  %d  — tap each node you'd visit." % _search_target,
				  "Binary search: go left if smaller, right if larger.")
	_highlight_node(_bst[_search_path[0]]["sprite"] as Node2D, COL_SEARCH_HI, false)

# ── TRAVERSE ──────────────────────────────────────────────────────────────────
func _activate_traverse() -> void:
	_trav_order.clear()
	_trav_tap_idx  = 0
	_trav_visited.clear()
	_trav_mistakes = 0
	_collect_order(_root, _trav_mode, _trav_order)
	if _trav_order.is_empty():
		_begin_next_round(); return
	_state = GameState.TRAVERSE

	var mode_names := ["Inorder (Left → Root → Right)",
					   "Preorder (Root → Left → Right)",
					   "Postorder (Left → Right → Root)"]
	var mode_why := [
		"Result is always sorted in a BST.",
		"Used to copy or serialize a tree.",
		"Used to safely delete a tree (leaves before parents).",
	]
	_update_instr("TRAVERSE — tap nodes in %s order." % mode_names[_trav_mode],
				  mode_why[_trav_mode])
	_hint_lbl.text    = _traverse_hint()
	_hint_box.visible = true
	_show_trav_ring(_trav_order[0])

# ── DELETE ────────────────────────────────────────────────────────────────────
func _activate_delete() -> void:
	var live := _live_bst_indices()
	if live.size() < 2:
		_begin_next_round(); return

	# Pick a non-root target — prefer non-leaf so we get variety in cases
	var candidates := live.filter(func(i): return i != _root)
	if candidates.is_empty():
		_begin_next_round(); return

	_delete_target = candidates[randi() % candidates.size()]
	var lc: int    = _bst[_delete_target]["left"]  as int
	var rc: int    = _bst[_delete_target]["right"] as int

	if lc < 0 and rc < 0:
		_delete_case = 1
	elif (lc < 0) != (rc < 0):
		_delete_case = 2
	else:
		_delete_case = 3
		# Pre-compute inorder successor
		_delete_succ_idx = rc
		while _bst[_delete_succ_idx]["left"] as int >= 0:
			_delete_succ_idx = _bst[_delete_succ_idx]["left"] as int

	_state = GameState.IDLE   # will move to DELETE_PREDICT or DELETE_EXEC on tap

	# Highlight the target node
	var nd := _bst[_delete_target]["sprite"] as Node2D
	_highlight_node(nd, COL_DELETE_HI, true)

	var case_hint: String = (["",
		"Case 1: Leaf node — simply remove it.",
		"Case 2: One child — the child slides up.",
		"Case 3: Two children — tap the inorder successor first!",
	] as Array[String])[_delete_case]

	_update_instr("DELETE node  %d  — click it." % (_bst[_delete_target]["value"] as int),
				  case_hint)
	_hint_lbl.text    = _delete_hint()
	_hint_box.visible = true

	if _delete_case == 3:
		_state = GameState.DELETE_PREDICT
		_update_instr(
			"DELETE  %d  — it has two children. TAP the node that should replace it." \
				% (_bst[_delete_target]["value"] as int),
			"Inorder successor = smallest value in the right subtree.")
	else:
		_state = GameState.DELETE_EXEC

# ── REBALANCE ─────────────────────────────────────────────────────────────────
func _activate_rebalance() -> void:
	if _bst_live_count() < 4:
		_begin_next_round(); return

	_rebalance_moves     = 0
	_balance_lbl.visible = true
	_complexity_lbl.visible = true
	_update_balance_display()
	if _p["subtree_tint"]: _update_subtree_tints()
	_update_complexity_label()
	_enter_rebalance_delete_phase()

func _enter_rebalance_delete_phase() -> void:
	_state = GameState.REBALANCE_DELETE
	# Highlight all current leaf nodes so player knows what's tappable
	for i in _live_bst_indices():
		var nd := _bst[i]["sprite"] as Node2D
		if (_bst[i]["left"] as int) < 0 and (_bst[i]["right"] as int) < 0:
			_highlight_node(nd, COL_DELETE_HI, true)   # pulsing orange = deletable leaf
		else:
			nd.modulate = COL_WHITE
	_update_instr(
		"REBALANCE — tap a glowing leaf rune to remove it.",
		"Remove from the heavy (deeper) side to reduce the gap.")
	_hint_lbl.text    = "Glowing runes are leaves.\nDelete from the heavy side, then reinsert on the light side."
	_hint_box.visible = true

func _enter_rebalance_insert_phase(freed_val: int) -> void:
	_state = GameState.REBALANCE_INSERT
	_restore_all_node_colors()
	# The freed value is already appended to _pool and its sprite spawned by _try_rebalance_delete
	_refresh_ghosts()
	_update_instr(
		"Now drag rune  %d  to the lighter side of the grove." % freed_val,
		"Insert where |BF| ≤ 1 is maintained.")

# ─────────────────────────────────────────────────────────────────────────────
#  ROUND BANNER
# ─────────────────────────────────────────────────────────────────────────────
func _setup_round_banner() -> void:
	var hud := get_node_or_null("HUD") as CanvasLayer
	var parent: Node = hud if hud != null else self

	# Semi-transparent overlay covering full screen
	_round_banner = ColorRect.new()
	_round_banner.color    = Color(0.04, 0.04, 0.10, 0.0)
	_round_banner.size     = Vector2(1280, 720)
	_round_banner.z_index  = 95
	_round_banner.visible  = false
	parent.add_child(_round_banner)

	# Dark card in the centre — 800 wide so text never reaches screen edge
	var card := ColorRect.new()
	card.color    = Color(0.06, 0.06, 0.14, 0.92)
	card.size     = Vector2(820, 160)
	card.position = Vector2(230, 270)   # centred: (1280-820)/2, ~mid-screen
	card.z_index  = 96
	_round_banner.add_child(card)

	# Accent line across top of card
	var accent := ColorRect.new()
	accent.color = Color(0.4, 0.9, 0.5, 0.7)
	accent.size  = Vector2(820, 2)
	accent.position = Vector2(0, 0)
	card.add_child(accent)

	# Title label — inside card, full width, autowrap
	_round_lbl = Label.new()
	_round_lbl.add_theme_font_override("font", _pixel_font)
	_round_lbl.add_theme_font_size_override("font_size", 20)
	_round_lbl.add_theme_color_override("font_color", COL_HEAD)
	_round_lbl.position             = Vector2(20, 14)
	_round_lbl.size                 = Vector2(780, 70)
	_round_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_round_lbl.z_index              = 97
	card.add_child(_round_lbl)

	# Sub-text label — inside card, smaller font
	_round_sub = Label.new()
	_round_sub.add_theme_font_override("font", _pixel_font)
	_round_sub.add_theme_font_size_override("font_size", 13)
	_round_sub.add_theme_color_override("font_color", Color(0.85, 0.85, 0.65))
	_round_sub.position             = Vector2(20, 88)
	_round_sub.size                 = Vector2(780, 60)
	_round_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_sub.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_round_sub.z_index              = 97
	card.add_child(_round_sub)

	# Round counter — top-right, always visible, outside banner
	_round_counter = Label.new()
	_round_counter.add_theme_font_override("font", _pixel_font)
	_round_counter.add_theme_font_size_override("font_size", 14)
	_round_counter.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	_round_counter.position             = Vector2(960, 10)
	_round_counter.size                 = Vector2(300, 24)
	_round_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(_round_counter)

func _show_round_banner(title: String, sub: String, rt: RoundType) -> void:
	_round_counter.text = "Round  %d / %d" % [_round_number, _p["total_rounds"]]

	var accent_col: Color = {
		RoundType.INSERT:    COL_OK,
		RoundType.SEARCH:    COL_SEARCH_HI,
		RoundType.TRAVERSE:  COL_TRAV,
		RoundType.DELETE:    COL_DELETE_HI,
		RoundType.REBALANCE: COL_HEAD,
	}[rt]

	_round_lbl.text = title
	_round_lbl.add_theme_color_override("font_color", accent_col)
	_round_sub.text = sub
	_round_banner.visible = true

	var tw := _round_banner.create_tween()
	tw.tween_property(_round_banner, "color:a", 0.88, 0.18)
	tw.tween_interval(1.5)
	tw.tween_property(_round_banner, "color:a", 0.0,  0.35)
	tw.tween_callback(func(): _round_banner.visible = false)

# ─────────────────────────────────────────────────────────────────────────────
#  END ROUND
# ─────────────────────────────────────────────────────────────────────────────
func _end_round(success: bool, msg: String = "") -> void:
	_state = GameState.IDLE
	_clear_trace()
	_restore_all_node_colors()
	_hide_all_ghosts()
	_trav_banner.visible    = false
	_balance_lbl.visible    = false
	_complexity_lbl.visible = false

	if success:
		_stat["correct"] += 1
		_combo += 1; _combo_decay = COMBO_TTL
		_score += _round_score
		_score_lbl.text = "Score: %d" % _score
		_combo_lbl.text = "×%d COMBO!" % _combo if _combo > 1 else ""
		_combo_lbl.add_theme_color_override("font_color",
			COL_HEAD if _combo >= 3 else COL_WHITE)
		AudioManager.play_sfx(PATH_SFX_WIN)
		_update_instr("✓ " + msg if msg != "" else "✓ Round complete!", COL_OK)
	else:
		_stat["wrong"] += 1
		_combo = 0; _combo_lbl.text = ""
		_lives -= 1; _refresh_lives()
		AudioManager.play_sfx(PATH_SFX_FAIL)
		_update_instr("✗ " + msg if msg != "" else "✗ Round failed.", COL_WRONG)
		if _lives <= 0:
			_end_game(false); return

	_acc_lbl.text = "Accuracy: %.0f%%" % _accuracy()
	await get_tree().create_timer(1.6).timeout
	_begin_next_round()

# ─────────────────────────────────────────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _alive: return

	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index != MOUSE_BUTTON_LEFT: return

		if e.pressed:
			match _state:
				GameState.IDLE:
					if _current_round == RoundType.INSERT:
						_try_pickup(e.position)

				GameState.SEARCH:
					_handle_search_tap(e.position)

				GameState.TRAVERSE:
					_handle_traverse_tap(e.position)

				GameState.DELETE_EXEC:
					_handle_delete_exec_tap(e.position)

				GameState.DELETE_PREDICT:
					_handle_delete_predict_tap(e.position)

				GameState.REBALANCE_DELETE:
					_try_rebalance_delete(e.position)

				GameState.REBALANCE_INSERT:
					_try_pickup(e.position)

		else:   # mouse released
			if _state == GameState.DRAG:
				_try_drop()

	elif event is InputEventMouseMotion:
		if _state == GameState.DRAG and _drag_pool_idx >= 0:
			_move_drag_sprite(event.position + _drag_offset)

# ─────────────────────────────────────────────────────────────────────────────
#  INSERT MECHANICS
# ─────────────────────────────────────────────────────────────────────────────
func _try_pickup(pos: Vector2) -> void:
	for i in range(_pool.size()):
		# Each pool sprite is stored as child i of _pool_tray (same order as _pool array)
		if i >= _pool_tray.get_child_count(): break
		var sp := _pool_tray.get_child(i) as Node2D
		if not is_instance_valid(sp): continue
		if sp.global_position.distance_to(pos) > NODE_HIT * 1.8: continue
		_state         = GameState.DRAG
		_drag_pool_idx = i
		_drag_offset   = sp.global_position - pos
		sp.z_index     = 50
		AudioManager.play_sfx(PATH_SFX_PICKUP)
		var val: int = _pool[i] as int
		_show_comparison_trace(val)
		if _p["insert_guided"]:
			_show_all_ghosts_colored(val)
		else:
			_show_ghosts_for_drag(val)
		return

func _move_drag_sprite(world_pos: Vector2) -> void:
	if _drag_pool_idx < 0 or _drag_pool_idx >= _pool_tray.get_child_count(): return
	var sp := _pool_tray.get_child(_drag_pool_idx) as Node2D
	if not is_instance_valid(sp): return
	sp.global_position = world_pos
	_update_snap_ghost(sp.global_position, _pool[_drag_pool_idx] as int)
	_apply_magnetic_pull(sp)

func _try_drop() -> void:
	if _drag_pool_idx < 0: return
	var sp  := _pool_tray.get_child(_drag_pool_idx) as Node2D
	var pos := sp.global_position if is_instance_valid(sp) else Vector2.ZERO
	var val := _pool[_drag_pool_idx] as int

	sp.z_index = 10
	_clear_trace()
	_hide_all_ghosts()

	# Dropped back in pool zone?
	if pos.y > POOL_Y - 50.0:
		_return_drag_to_home()
		_state = GameState.IDLE
		_drag_pool_idx = -1
		return

	# Find valid slot
	var slot = _find_snap_slot(pos, val)
	if slot == null:
		slot = _nearest_valid_slot(pos, val)

	if slot == null:
		# Wrong drop — explain why
		var near = _nearest_any_slot(pos)
		if near != null and (near["side"] as String) != "duplicate":
			var pv: int = _bst[near["parent_idx"]]["value"] if near["parent_idx"] >= 0 else -1
			_show_wrong_drop(sp, val, near, pv)
		else:
			_float_world(pos, "Drop on a slot!", COL_WRONG)
		_return_drag_to_home()
		_state = GameState.IDLE
		_drag_pool_idx = -1
		return

	# Commit insertion
	var dest: Vector2 = slot["pos"]
	sp.get_parent().remove_child(sp)
	_tree_layer.add_child(sp)
	sp.global_position = dest

	if slot["parent_idx"] >= 0:
		_animate_branch(_bst[slot["parent_idx"]]["pos"], dest)

	var new_idx := _bst.size()
	_bst.append({
		"value":  val, "sprite": sp,
		"left":  -1,  "right":  -1,
		"parent": slot["parent_idx"],
		"pos":    dest, "depth": _slot_depth(slot),
		"height": 1,   "height_lbl": null,
	})
	if slot["side"] == "root":
		_root = new_idx
	elif slot["parent_idx"] >= 0:
		if slot["side"] == "left":  _bst[slot["parent_idx"]]["left"]  = new_idx
		if slot["side"] == "right": _bst[slot["parent_idx"]]["right"] = new_idx

	_invalidate_heights_upward(new_idx)
	_pool.remove_at(_drag_pool_idx)
	_drag_pool_idx  = -1
	_snap_ghost_idx = -1
	_state          = GameState.IDLE

	_flash_ancestry(new_idx)
	_bounce(sp)
	AudioManager.play_sfx(PATH_SFX_OK)

	# Score: 100 at depth 0 (root), scale down per depth level
	var depth: int   = _bst[new_idx]["depth"] as int
	var pts: int     = maxi(100 - depth * 22, 20)
	_round_score    += pts
	_stat["inserts"] += 1
	_float_node(sp, "+%d" % pts, COL_OK)

	# Show the search path to this node automatically
	_animate_search_path_to(new_idx)

	_refresh_ghosts()
	_update_complexity_label_if_visible()

	# REBALANCE insert phase: check if inserting fixed the balance
	if _state == GameState.REBALANCE_INSERT or _current_round == RoundType.REBALANCE:
		_activate_rebalance_insert_mode()
		return

	# After a brief moment, end the insert round
	await get_tree().create_timer(1.4).timeout
	_end_round(true, "Inserted %d at depth %d — %d comparison%s to find it." \
		% [val, depth, depth + 1, "s" if depth + 1 != 1 else ""])

func _show_wrong_drop(sp: Node2D, val: int, near: Dictionary, pv: int) -> void:
	var msg := ""
	if near["side"] == "left":
		msg = "%d > %d  ✗  Left child must be LESS than parent." % [val, pv] if val >= pv \
			else "%d < %d  ✓  But that slot is occupied — go deeper." % [val, pv]
	elif near["side"] == "right":
		msg = "%d < %d  ✗  Right child must be GREATER than parent." % [val, pv] if val <= pv \
			else "%d > %d  ✓  But that slot is occupied — go deeper." % [val, pv]
	_flash(sp, COL_WRONG)
	_shake(sp)
	_float_node(sp, msg if msg.length() < 30 else "Wrong slot!", COL_WRONG)
	_lives -= 1; _refresh_lives()
	if _lives <= 0: _end_game(false)

# ─────────────────────────────────────────────────────────────────────────────
#  SEARCH MECHANICS
# ─────────────────────────────────────────────────────────────────────────────
func _build_search_path(target: int) -> Array:
	var path: Array = []
	var cur: int    = _root
	while cur >= 0 and cur < _bst.size():
		if not is_instance_valid(_bst[cur]["sprite"] as Node2D): break
		path.append(cur)
		var val: int = _bst[cur]["value"] as int
		if target == val: break
		elif target < val: cur = _bst[cur]["left"] as int
		else:              cur = _bst[cur]["right"] as int
	return path

func _handle_search_tap(pos: Vector2) -> void:
	for i in _live_bst_indices():
		var nd := _bst[i]["sprite"] as Node2D
		if nd.global_position.distance_to(pos) > NODE_HIT: continue

		var expected_idx: int = _search_path[_search_tap_idx]
		if i == expected_idx:
			# Correct tap
			_flash(nd, COL_OK)
			var val: int    = _bst[i]["value"] as int
			var target: int = _search_target
			var cmp: String = ""
			if val == target:
				cmp = "FOUND %d! ✓" % target
			elif target < val:
				cmp = "%d < %d → go LEFT" % [target, val]
			else:
				cmp = "%d > %d → go RIGHT" % [target, val]
			_float_node(nd, cmp, COL_OK)

			# Grey out eliminated subtree
			var go_left := target < val
			var elim: int = (_bst[i]["right"] if go_left else _bst[i]["left"]) as int
			_grey_subtree(elim)

			_search_tap_idx += 1
			AudioManager.play_sfx(PATH_SFX_OK)

			if _search_tap_idx >= _search_path.size():
				# Done
				var base_pts := 80
				var penalty  := _search_mistakes * 20
				_round_score  = maxi(base_pts - penalty, 10)
				_stat["searches"] += 1
				await get_tree().create_timer(0.7).timeout
				_end_round(true,
					"Found %d in %d step%s. %s" % [
						_search_target,
						_search_path.size(),
						"s" if _search_path.size() != 1 else "",
						"Perfect!" if _search_mistakes == 0 else "(%d mistake%s)" \
							% [_search_mistakes, "s" if _search_mistakes != 1 else ""],
					])
			else:
				# Pulse next expected node subtly
				var next_nd := _bst[_search_path[_search_tap_idx]]["sprite"] as Node2D
				_pulse_node(next_nd, COL_SEARCH_HI)
		else:
			# Wrong tap
			_flash(nd, COL_WRONG)
			_shake(nd)
			_search_mistakes += 1
			_lives -= 1; _refresh_lives()
			var cur_node_val: int = _bst[_search_path[_search_tap_idx]]["value"] as int
			var go_dir: String    = "LEFT" if _search_target < cur_node_val else "RIGHT"
			_update_instr(
				"✗ Wrong! Compare %d with node %d — go %s." \
					% [_search_target, cur_node_val, go_dir], "")
			if _lives <= 0: _end_game(false)
		return

# ─────────────────────────────────────────────────────────────────────────────
#  TRAVERSE MECHANICS
# ─────────────────────────────────────────────────────────────────────────────
func _collect_order(idx: int, mode: TravMode, out: Array) -> void:
	if idx < 0 or idx >= _bst.size(): return
	if not is_instance_valid(_bst[idx]["sprite"] as Node2D): return
	match mode:
		TravMode.INORDER:
			_collect_order(_bst[idx]["left"] as int,  mode, out)
			out.append(idx)
			_collect_order(_bst[idx]["right"] as int, mode, out)
		TravMode.PREORDER:
			out.append(idx)
			_collect_order(_bst[idx]["left"] as int,  mode, out)
			_collect_order(_bst[idx]["right"] as int, mode, out)
		TravMode.POSTORDER:
			_collect_order(_bst[idx]["left"] as int,  mode, out)
			_collect_order(_bst[idx]["right"] as int, mode, out)
			out.append(idx)

func _handle_traverse_tap(pos: Vector2) -> void:
	for i in _live_bst_indices():
		var nd := _bst[i]["sprite"] as Node2D
		if nd.global_position.distance_to(pos) > NODE_HIT: continue

		var expected_idx: int = _trav_order[_trav_tap_idx]
		if i == expected_idx:
			_flash(nd, [COL_TRAV, COL_PREORDER, COL_POSTORDER][_trav_mode])
			_trav_visited.append(_bst[i]["value"] as int)
			_trav_banner.text    = "Visited: " + " → ".join(_trav_visited.map(func(v): return str(v)))
			_trav_banner.visible = true
			_trav_tap_idx       += 1
			AudioManager.play_sfx(PATH_SFX_OK)

			if _trav_tap_idx >= _trav_order.size():
				_round_score = maxi(100 - _trav_mistakes * 15, 20)
				_stat["traversals"] += 1
				await get_tree().create_timer(0.6).timeout
				_end_round(true,
					"Traversal complete! %s" % (
						"BST Inorder = Always Sorted ✓" if _trav_mode == TravMode.INORDER \
						else "Preorder done ✓" if _trav_mode == TravMode.PREORDER \
						else "Postorder done ✓"))
			else:
				_show_trav_ring(_trav_order[_trav_tap_idx])
		else:
			_flash(nd, COL_WRONG)
			_shake(nd)
			_trav_mistakes += 1
			_lives -= 1; _refresh_lives()
			var exp_val: int = _bst[expected_idx]["value"] as int
			_update_instr("✗ Wrong! Next in sequence is %d." % exp_val, "")
			_show_trav_ring(expected_idx)   # re-hint the correct node
			if _lives <= 0: _end_game(false)
		return

func _show_trav_ring(bst_idx: int) -> void:
	if bst_idx < 0 or bst_idx >= _bst.size(): return
	var nd := _bst[bst_idx]["sprite"] as Node2D
	if not is_instance_valid(nd): return
	var ring := _make_ring(nd.global_position,
		[COL_TRAV, COL_PREORDER, COL_POSTORDER][_trav_mode])
	_trace_layer.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "modulate:a", 0.0, 1.4)
	tw.tween_callback(ring.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  DELETE MECHANICS
# ─────────────────────────────────────────────────────────────────────────────
func _handle_delete_predict_tap(pos: Vector2) -> void:
	# Player must tap the inorder successor before the delete executes
	for i in _live_bst_indices():
		var nd := _bst[i]["sprite"] as Node2D
		if nd.global_position.distance_to(pos) > NODE_HIT: continue

		if i == _delete_succ_idx:
			# Correct successor predicted!
			_flash(nd, COL_SUCC_HI)
			_float_node(nd, "Inorder successor ✓", COL_SUCC_HI)
			_round_score += 40   # bonus for correct prediction
			_update_instr(
				"✓ Correct! %d is the inorder successor. Now click the node to delete." \
					% (_bst[_delete_succ_idx]["value"] as int),
				"Smallest value in the right subtree.")
			# Re-highlight the target and switch to exec state
			var target_nd := _bst[_delete_target]["sprite"] as Node2D
			_highlight_node(target_nd, COL_DELETE_HI, true)
			_state = GameState.DELETE_EXEC
		else:
			# Wrong prediction
			_flash(nd, COL_WRONG)
			_shake(nd)
			_lives -= 1; _refresh_lives()
			var succ_val: int = _bst[_delete_succ_idx]["value"] as int
			_update_instr(
				"✗ Wrong! The inorder successor of %d is %d — the smallest in the right subtree." \
					% [_bst[_delete_target]["value"] as int, succ_val], "")
			if _lives <= 0: _end_game(false)
		return

func _handle_delete_exec_tap(pos: Vector2) -> void:
	for i in _live_bst_indices():
		var nd := _bst[i]["sprite"] as Node2D
		if nd.global_position.distance_to(pos) > NODE_HIT: continue

		if i == _delete_target:
			_execute_delete(i)
			return
		else:
			_flash(nd, COL_WRONG)
			_shake(nd)
			_update_instr(
				"✗ Click the highlighted (orange) node — that's the one to delete.", "")
			_lives -= 1; _refresh_lives()
			if _lives <= 0: _end_game(false)
			return

func _execute_delete(idx: int) -> void:
	_state = GameState.IDLE
	var lc: int = _bst[idx]["left"]  as int
	var rc: int = _bst[idx]["right"] as int
	var val: int = _bst[idx]["value"] as int

	_round_score += 60
	_stat["deletes"] += 1

	match _delete_case:
		1: await _delete_leaf(idx)
		2: await _delete_one_child(idx, lc if lc >= 0 else rc)
		3: await _delete_two_children(idx)

	_update_balance_display_if_visible()
	_refresh_ghosts()

	var case_names := ["", "Leaf removed ✓", "Child promoted ✓", "Successor swapped ✓"]
	await get_tree().create_timer(0.5).timeout
	_end_round(true, "%s — %d deleted." % [case_names[_delete_case], val])

func _delete_leaf(idx: int) -> void:
	var nd := _bst[idx]["sprite"] as Node2D
	_float_node(nd, "Case 1: Leaf — removed", COL_OK)
	var tw := nd.create_tween()
	tw.tween_property(nd, "scale", Vector2.ZERO, 0.3)
	tw.tween_callback(nd.queue_free)
	_detach_from_parent(idx)
	_bst[idx]["sprite"] = null
	_invalidate_heights_upward(_bst[idx]["parent"] as int)
	await get_tree().create_timer(0.35).timeout

func _delete_one_child(idx: int, child_idx: int) -> void:
	var nd    := _bst[idx]["sprite"]       as Node2D
	var child := _bst[child_idx]["sprite"] as Node2D
	_float_node(nd, "Case 2: Child promoted", COL_OK)
	var parent_pos: Vector2 = _bst[idx]["pos"] as Vector2
	if is_instance_valid(child):
		var tw := child.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(child, "global_position", parent_pos, 0.4)
		_bst[child_idx]["pos"]    = parent_pos
		_bst[child_idx]["depth"]  = _bst[idx]["depth"] as int
		_bst[child_idx]["parent"] = _bst[idx]["parent"] as int
	var fade := nd.create_tween()
	fade.tween_property(nd, "modulate:a", 0.0, 0.3)
	fade.tween_callback(nd.queue_free)
	_relink_parent(idx, child_idx)
	_bst[idx]["sprite"] = null
	_invalidate_heights_upward(child_idx)
	await get_tree().create_timer(0.5).timeout

func _delete_two_children(idx: int) -> void:
	var succ_idx: int = _delete_succ_idx
	var nd    := _bst[idx]["sprite"]      as Node2D
	var succ  := _bst[succ_idx]["sprite"] as Node2D
	_float_node(nd, "Case 3: Successor swap", COL_OK)
	if is_instance_valid(succ): _pulse_node(succ, COL_SUCC_HI)
	await get_tree().create_timer(0.5).timeout
	# Swap values
	var old_val: int = _bst[idx]["value"] as int
	var suc_val: int = _bst[succ_idx]["value"] as int
	_bst[idx]["value"] = suc_val
	if is_instance_valid(nd):
		for c in nd.get_children():
			if c is Label: (c as Label).text = str(suc_val)
	_float_node(nd, "%d → %d" % [old_val, suc_val], COL_HEAD)
	# Delete the successor (which is now a leaf or one-child)
	if (_bst[succ_idx]["left"] as int) < 0 and (_bst[succ_idx]["right"] as int) < 0:
		await _delete_leaf(succ_idx)
	else:
		var sc: int = _bst[succ_idx]["right"] as int
		await _delete_one_child(succ_idx, sc)

# ─────────────────────────────────────────────────────────────────────────────
#  REBALANCE MECHANICS
# ─────────────────────────────────────────────────────────────────────────────
func _try_rebalance_delete(pos: Vector2) -> void:
	for i in _live_bst_indices():
		var nd := _bst[i]["sprite"] as Node2D
		if nd.global_position.distance_to(pos) > NODE_HIT * 1.6: continue
		# Only leaves allowed
		if (_bst[i]["left"] as int) >= 0 or (_bst[i]["right"] as int) >= 0:
			_flash(nd, COL_WRONG)
			_float_node(nd, "Not a leaf!", COL_WRONG)
			_update_instr("Tap a glowing leaf rune — one with no branches below.", "")
			return
		# Valid leaf — delete it and push value back to pool
		var val: int = _bst[i]["value"] as int
		await _delete_leaf(i)
		_pool.append(val)
		_spawn_pool_sprite(val)
		_rebalance_moves += 1
		_update_balance_display()
		_update_complexity_label()
		_enter_rebalance_insert_phase(val)
		return

func _activate_rebalance_insert_mode() -> void:
	# Called from _try_drop after a tile is placed during REBALANCE_INSERT phase
	_refresh_ghosts()
	_update_balance_display()
	_update_complexity_label()
	if _root < 0: return
	var bf: int = abs(_balance_factor(_root))
	if bf <= 1:
		_round_score = 80 + _rebalance_moves * 10
		_stat["rebalances"] += 1
		await get_tree().create_timer(0.5).timeout
		_end_round(true, "The grove is balanced! |BF| ≤ 1 ✓  O(log n) magic restored.")
	else:
		# Still unbalanced — loop back to delete phase
		_update_instr("Still unbalanced (BF=%d) — remove another leaf." % bf, "")
		await get_tree().create_timer(0.6).timeout
		_enter_rebalance_delete_phase()

# ─────────────────────────────────────────────────────────────────────────────
#  POOL / SPRITE MANAGEMENT
# ─────────────────────────────────────────────────────────────────────────────
func _refill_pool(count: int) -> void:
	var existing: Array[int] = []
	for nd in _bst:
		if is_instance_valid(nd["sprite"] as Node2D):
			existing.append(nd["value"] as int)
	for v in _pool: existing.append(v as int)

	var added := 0
	var tries  := 0
	while added < count and tries < 200:
		tries += 1
		var v := randi() % 89 + 10
		if v not in existing:
			_pool.append(v)
			existing.append(v)
			added += 1

	_rebuild_pool_sprites()

func _rebuild_pool_sprites() -> void:
	for c in _pool_tray.get_children(): c.queue_free()
	var spacing := 900.0 / (_pool.size() + 1)
	for i in range(_pool.size()):
		var pos := Vector2(160.0 + spacing * (i + 1), POOL_Y)
		_spawn_pool_sprite_at(_pool[i] as int, pos)

func _spawn_pool_sprite(val: int) -> void:
	var count := _pool_tray.get_child_count()
	var spacing := 900.0 / (count + 2)
	var pos := Vector2(160.0 + spacing * (count + 1), POOL_Y)
	_spawn_pool_sprite_at(val, pos)

func _spawn_pool_sprite_at(val: int, pos: Vector2) -> void:
	var sp := _make_number_sprite(val)
	_pool_tray.add_child(sp)
	sp.global_position = pos

func _return_drag_to_home() -> void:
	if _drag_pool_idx < 0 or _drag_pool_idx >= _pool_tray.get_child_count(): return
	var sp := _pool_tray.get_child(_drag_pool_idx) as Node2D
	if not is_instance_valid(sp): return
	var spacing := 900.0 / (_pool.size() + 1)
	var home    := Vector2(160.0 + spacing * (_drag_pool_idx + 1), POOL_Y)
	var tw      := sp.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sp, "global_position", home, 0.3)

# ─────────────────────────────────────────────────────────────────────────────
#  BST SILENT INSERT (used for seed tree and rebalance)
# ─────────────────────────────────────────────────────────────────────────────
func _silent_insert(value: int) -> void:
	var slot := _find_insert_slot(value)
	if slot == null or (slot["side"] as String) == "duplicate": return
	var sp := _make_number_sprite(value)
	_tree_layer.add_child(sp)
	sp.global_position = slot["pos"]
	if slot["parent_idx"] >= 0:
		var line := Line2D.new()
		line.default_color = COL_EDGE; line.width = 3.0
		line.add_point(_bst[slot["parent_idx"]]["pos"])
		line.add_point(slot["pos"])
		_edge_layer.add_child(line)
	var new_idx := _bst.size()
	_bst.append({
		"value": value, "sprite": sp,
		"left": -1, "right": -1,
		"parent": slot["parent_idx"],
		"pos": slot["pos"], "depth": _slot_depth(slot),
		"height": 1, "height_lbl": null,
	})
	if slot["side"] == "root": _root = new_idx
	elif slot["parent_idx"] >= 0:
		if slot["side"] == "left":  _bst[slot["parent_idx"]]["left"]  = new_idx
		if slot["side"] == "right": _bst[slot["parent_idx"]]["right"] = new_idx
	if new_idx == _root: sp.modulate = COL_HEAD
	_invalidate_heights_upward(new_idx)

# ─────────────────────────────────────────────────────────────────────────────
#  GHOST SLOTS
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_ghosts() -> void:
	for c in _ghost_layer.get_children(): c.queue_free()
	_ghosts.clear()
	if _bst.is_empty():
		_add_ghost(ROOT_POS, -1, "root")
	else:
		_collect_slots(_root, ROOT_POS, 0)

func _collect_slots(idx: int, pos: Vector2, depth: int) -> void:
	if idx < 0 or idx >= _bst.size(): return
	if depth >= MAX_DEPTH: return
	var ap: Vector2 = _bst[idx]["pos"]
	var spread := SPREAD_MUL / pow(2.0, float(depth))
	var lp := ap + Vector2(-spread, LEVEL_H)
	var rp := ap + Vector2( spread, LEVEL_H)
	var lc: int = _bst[idx]["left"]  as int
	var rc: int = _bst[idx]["right"] as int
	if lc < 0:
		if lp.x > 40 and lp.x < 1240 and lp.y < POOL_Y - 80:
			_add_ghost(lp, idx, "left")
	else: _collect_slots(lc, lp, depth + 1)
	if rc < 0:
		if rp.x > 40 and rp.x < 1240 and rp.y < POOL_Y - 80:
			_add_ghost(rp, idx, "right")
	else: _collect_slots(rc, rp, depth + 1)

func _add_ghost(pos: Vector2, parent_idx: int, side: String) -> void:
	var panel := Panel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = COL_GHOST_OK
	for r in ["corner_radius_top_left","corner_radius_top_right",
			  "corner_radius_bottom_left","corner_radius_bottom_right"]:
		style.set(r, int(GHOST_R))
	panel.add_theme_stylebox_override("panel", style)
	panel.size     = Vector2(GHOST_R*2, GHOST_R*2)
	panel.position = pos - Vector2(GHOST_R, GHOST_R)
	panel.modulate.a = 0.0
	_ghost_layer.add_child(panel)
	var clbl := Label.new()
	clbl.text = _slot_constraint_text(parent_idx, side)
	clbl.add_theme_font_override("font", _pixel_font)
	clbl.add_theme_font_size_override("font_size", 12)
	clbl.add_theme_color_override("font_color", Color(0.9, 1.0, 0.7))
	clbl.position   = pos + Vector2(-20, GHOST_R + 2)
	clbl.modulate.a = 0.0
	_ghost_layer.add_child(clbl)
	_ghosts.append({"pos":pos,"parent_idx":parent_idx,"side":side,"rect":panel,"clbl":clbl})

func _slot_constraint_text(parent_idx: int, side: String) -> String:
	if side == "root": return "root"
	if parent_idx < 0 or parent_idx >= _bst.size(): return ""
	var pv: int = _bst[parent_idx]["value"]
	return "< %d" % pv if side == "left" else "> %d" % pv

func _show_all_ghosts_colored(val: int) -> void:
	AudioManager.play_sfx(PATH_SFX_GHOST)
	for g in _ghosts:
		var valid := _bst_rule_ok(g["parent_idx"], g["side"], val)
		var style := StyleBoxFlat.new()
		style.bg_color = COL_GHOST_OK if valid else COL_GHOST_NO
		for r in ["corner_radius_top_left","corner_radius_top_right",
				  "corner_radius_bottom_left","corner_radius_bottom_right"]:
			style.set(r, int(GHOST_R))
		(g["rect"] as Panel).add_theme_stylebox_override("panel", style)
		(g["rect"] as Panel).create_tween().tween_property(g["rect"], "modulate:a", 1.0, 0.15)
		(g["clbl"] as Label).create_tween().tween_property(g["clbl"], "modulate:a", 1.0, 0.15)

func _show_ghosts_for_drag(val: int) -> void:
	_show_all_ghosts_colored(val)

func _hide_all_ghosts() -> void:
	for g in _ghosts:
		(g["rect"] as Panel).create_tween().tween_property(g["rect"], "modulate:a", 0.0, 0.12)
		(g["clbl"] as Label).create_tween().tween_property(g["clbl"], "modulate:a", 0.0, 0.12)

func _find_snap_slot(pos: Vector2, val: int):
	if _snap_ghost_idx >= 0 and _snap_ghost_idx < _ghosts.size():
		var g: Dictionary = _ghosts[_snap_ghost_idx]
		if _bst_rule_ok(g["parent_idx"], g["side"], val) \
				and pos.distance_to(g["pos"]) < SNAP_DIST * 1.5:
			return g
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
		var col     := COL_GHOST_SNAP if is_snap else (COL_GHOST_OK if valid else COL_GHOST_NO)
		var sc      := Vector2(1.3, 1.3) if is_snap else Vector2.ONE
		var style   := StyleBoxFlat.new()
		style.bg_color = col
		for r in ["corner_radius_top_left","corner_radius_top_right",
				  "corner_radius_bottom_left","corner_radius_bottom_right"]:
			style.set(r, int(GHOST_R))
		(g["rect"] as Panel).add_theme_stylebox_override("panel", style)
		(g["rect"] as Panel).scale = sc

func _apply_magnetic_pull(sp: Node2D) -> void:
	if _snap_ghost_idx < 0: return
	var g: Dictionary = _ghosts[_snap_ghost_idx]
	var dist: float   = sp.global_position.distance_to(g["pos"])
	if dist > MAGNET_R: return
	var strength := 0.18 * (1.0 - dist / MAGNET_R)
	sp.global_position = sp.global_position.lerp(g["pos"], strength)

func _bst_rule_ok(parent_idx: int, side: String, val: int) -> bool:
	if side == "root":      return true
	if side == "duplicate": return false
	if parent_idx < 0 or parent_idx >= _bst.size(): return false
	var pv: int = _bst[parent_idx]["value"]
	return val < pv if side == "left" else val > pv

func _find_insert_slot(value: int) -> Dictionary:
	if _bst.is_empty(): return {"pos":ROOT_POS,"parent_idx":-1,"side":"root"}
	return _find_slot_from(_root, ROOT_POS, 0, value)

func _find_slot_from(idx: int, pos: Vector2, depth: int, value: int) -> Dictionary:
	if depth >= MAX_DEPTH:
		return {"pos":pos,"parent_idx":idx,"side":"left" if value < (_bst[idx]["value"] as int) else "right"}
	var spread := SPREAD_MUL / pow(2.0, float(depth))
	var node_val: int = _bst[idx]["value"] as int
	if value == node_val:
		return {"pos":pos,"parent_idx":idx,"side":"duplicate"}
	elif value < node_val:
		var lp := pos + Vector2(-spread, LEVEL_H)
		if (_bst[idx]["left"] as int) < 0: return {"pos":lp,"parent_idx":idx,"side":"left"}
		return _find_slot_from(_bst[idx]["left"] as int, lp, depth+1, value)
	else:
		var rp := pos + Vector2( spread, LEVEL_H)
		if (_bst[idx]["right"] as int) < 0: return {"pos":rp,"parent_idx":idx,"side":"right"}
		return _find_slot_from(_bst[idx]["right"] as int, rp, depth+1, value)

func _slot_depth(slot: Dictionary) -> int:
	if slot["side"] == "root": return 0
	if slot["parent_idx"] < 0: return 1
	return (_bst[slot["parent_idx"]]["depth"] as int) + 1

# ─────────────────────────────────────────────────────────────────────────────
#  HEIGHT CACHE
# ─────────────────────────────────────────────────────────────────────────────
func _invalidate_heights_upward(start_idx: int) -> void:
	var cur := start_idx
	while cur >= 0 and cur < _bst.size():
		var lh := _cached_height(_bst[cur]["left"] as int)
		var rh := _cached_height(_bst[cur]["right"] as int)
		_bst[cur]["height"] = 1 + maxi(lh, rh)
		cur = _bst[cur]["parent"] as int

func _cached_height(idx: int) -> int:
	if idx < 0 or idx >= _bst.size(): return 0
	return _bst[idx]["height"] as int

func _height(idx: int) -> int: return _cached_height(idx)

func _balance_factor(idx: int) -> int:
	if idx < 0 or idx >= _bst.size(): return 0
	return _cached_height(_bst[idx]["left"] as int) - _cached_height(_bst[idx]["right"] as int)

func _simulated_balance_factor(parent_idx: int, side: String) -> int:
	if parent_idx < 0: return 0
	var lh := _cached_height(_bst[parent_idx]["left"] as int)
	var rh := _cached_height(_bst[parent_idx]["right"] as int)
	if side == "left":  lh = maxi(lh, 1)
	if side == "right": rh = maxi(rh, 1)
	return lh - rh

# ─────────────────────────────────────────────────────────────────────────────
#  COMPARISON PATH TRACE (shown on INSERT pickup)
# ─────────────────────────────────────────────────────────────────────────────
func _show_comparison_trace(value: int) -> void:
	_clear_trace()
	if _bst.is_empty(): return
	_trace_path(_root, ROOT_POS, 0, value)

func _trace_path(idx: int, pos: Vector2, depth: int, value: int) -> void:
	if idx < 0 or idx >= _bst.size(): return
	var node_val: int = _bst[idx]["value"]
	var spread := SPREAD_MUL / pow(2.0, float(depth))
	var go_left := value < node_val
	var lbl := Label.new()
	lbl.text = ("%d < %d → LEFT" if go_left else "%d > %d → RIGHT") % [value, node_val]
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", COL_TRACE)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.global_position = pos + Vector2(GHOST_R + 4, -16)
	lbl.z_index = 30
	_trace_layer.add_child(lbl)
	lbl.modulate.a = 0.0
	lbl.create_tween().tween_property(lbl, "modulate:a", 1.0, 0.18)
	var child_pos := pos + Vector2(-spread if go_left else spread, LEVEL_H)
	var child_idx: int = _bst[idx]["left"] as int if go_left else _bst[idx]["right"] as int
	for s in range(6):
		if s % 2 == 0:
			var line := Line2D.new()
			line.default_color = COL_TRACE; line.width = 2.5
			line.add_point(pos.lerp(child_pos, float(s)/6.0))
			line.add_point(pos.lerp(child_pos, float(s+1)/6.0))
			line.z_index = 25
			_trace_layer.add_child(line)
	if child_idx >= 0: _trace_path(child_idx, child_pos, depth+1, value)

func _clear_trace() -> void:
	for c in _trace_layer.get_children(): c.queue_free()

# ─────────────────────────────────────────────────────────────────────────────
#  ANCESTRY FLASH
# ─────────────────────────────────────────────────────────────────────────────
func _flash_ancestry(new_idx: int) -> void:
	var chain: Array = []
	var cur := new_idx
	while cur >= 0 and cur < _bst.size():
		chain.append(cur); cur = _bst[cur]["parent"] as int
	for i in range(chain.size() - 1, -1, -1):
		var ni: int = chain[i]
		var nd := _bst[ni]["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var delay := (chain.size() - 1 - i) * 0.08
		var tw    := nd.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(nd, "modulate", COL_ANCESTRY, 0.06)
		tw.tween_property(nd, "modulate", COL_HEAD if ni == _root else COL_WHITE, 0.22)

# ─────────────────────────────────────────────────────────────────────────────
#  ANIMATED SEARCH PATH (shown after insert to teach lookup cost)
# ─────────────────────────────────────────────────────────────────────────────
func _animate_search_path_to(bst_idx: int) -> void:
	# Walk from root to bst_idx, flash each node in sequence
	var path := _build_search_path(_bst[bst_idx]["value"] as int)
	for i in range(path.size()):
		var ni: int = path[i]
		var nd := _bst[ni]["sprite"] as Node2D
		if not is_instance_valid(nd): continue
		var tw := nd.create_tween()
		tw.tween_interval(i * 0.2)
		tw.tween_property(nd, "modulate", COL_SEARCH_HI, 0.1)
		tw.tween_property(nd, "modulate", COL_HEAD if ni == _root else COL_WHITE, 0.2)

# ─────────────────────────────────────────────────────────────────────────────
#  SUBTREE TINTING + HEIGHT BADGES (HARD / EXPERT)
# ─────────────────────────────────────────────────────────────────────────────
func _update_subtree_tints() -> void:
	if not (_p["subtree_tint"] as bool) or _root < 0: return
	for c in _tree_layer.get_children():
		if c.has_meta("tint_overlay"): c.queue_free()
	if _bst[_root]["left"] as int >= 0:
		_tint_subtree(_bst[_root]["left"] as int, COL_LEFT_SUB)
	if _bst[_root]["right"] as int >= 0:
		_tint_subtree(_bst[_root]["right"] as int, COL_RIGHT_SUB)
	for i in _live_bst_indices(): _update_height_badge(i)

func _tint_subtree(idx: int, color: Color) -> void:
	if idx < 0 or idx >= _bst.size(): return
	var nd := _bst[idx]["sprite"] as Node2D
	if is_instance_valid(nd):
		var ov := ColorRect.new()
		ov.size     = Vector2(36,36); ov.position = Vector2(-18,-18)
		ov.color    = color; ov.z_index = -1
		ov.set_meta("tint_overlay", true)
		nd.add_child(ov)
	_tint_subtree(_bst[idx]["left"] as int, color)
	_tint_subtree(_bst[idx]["right"] as int, color)

func _update_height_badge(idx: int) -> void:
	if idx < 0 or idx >= _bst.size(): return
	var nd := _bst[idx]["sprite"] as Node2D
	if not is_instance_valid(nd): return
	var old = _bst[idx].get("height_lbl", null)
	if is_instance_valid(old): old.queue_free()
	var badge := Label.new()
	badge.text = "h:%d" % _cached_height(idx)
	badge.add_theme_font_override("font", _pixel_font)
	badge.add_theme_font_size_override("font_size", 10)
	badge.add_theme_color_override("font_color", Color(0.9,0.9,0.5))
	badge.position = Vector2(10,-28); badge.z_index = 15
	nd.add_child(badge)
	_bst[idx]["height_lbl"] = badge

# ─────────────────────────────────────────────────────────────────────────────
#  BALANCE DISPLAY
# ─────────────────────────────────────────────────────────────────────────────
func _update_balance_display() -> void:
	if _root < 0: return
	var bf  := _balance_factor(_root)
	var lh  := _cached_height(_bst[_root]["left"] as int)
	var rh  := _cached_height(_bst[_root]["right"] as int)
	var gap: int = abs(lh - rh)
	if gap > 1:
		_balance_lbl.text = "⚖ Left h=%d | Right h=%d | Gap=%d ❌" % [lh, rh, gap]
		_balance_lbl.add_theme_color_override("font_color", COL_BALANCE_NO)
		_droop_subtree(_bst[_root]["left"] as int if lh > rh else _bst[_root]["right"] as int)
	else:
		_balance_lbl.text = "⚖ Balanced ✓ (BF=%d)" % bf
		_balance_lbl.add_theme_color_override("font_color", COL_BALANCE_OK)
	_update_subtree_tints()

func _update_balance_display_if_visible() -> void:
	if _balance_lbl.visible: _update_balance_display()

func _droop_subtree(idx: int) -> void:
	if idx < 0 or idx >= _bst.size(): return
	var nd := _bst[idx]["sprite"] as Node2D
	if is_instance_valid(nd):
		var op := nd.global_position
		var tw := nd.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(nd, "global_position", op + Vector2(0,5), 0.15)
		tw.tween_property(nd, "global_position", op, 0.15)
	_droop_subtree(_bst[idx]["left"] as int)
	_droop_subtree(_bst[idx]["right"] as int)

# ─────────────────────────────────────────────────────────────────────────────
#  COMPLEXITY LABEL
# ─────────────────────────────────────────────────────────────────────────────
func _update_complexity_label() -> void:
	if not is_instance_valid(_complexity_lbl) or not _complexity_lbl.visible: return
	if _root < 0: return
	var h := _cached_height(_root)
	var n := _bst_live_count()
	var bf: int = abs(_balance_factor(_root))
	if bf > 1:
		_complexity_lbl.text = "Search O(h)=O(%d)  ⚠ Unbalanced → approaching O(n)=%d" % [h,n]
		_complexity_lbl.add_theme_color_override("font_color", COL_WRONG)
	else:
		_complexity_lbl.text = "Search O(h)=O(%d)  ✓ Balanced → O(log n)" % h
		_complexity_lbl.add_theme_color_override("font_color", Color(0.6,1.0,0.8))

func _update_complexity_label_if_visible() -> void:
	if _complexity_lbl.visible: _update_complexity_label()

# ─────────────────────────────────────────────────────────────────────────────
#  SUBTREE GREY / RESTORE
# ─────────────────────────────────────────────────────────────────────────────
func _grey_subtree(idx: int) -> void:
	if idx < 0 or idx >= _bst.size(): return
	var nd := _bst[idx]["sprite"] as Node2D
	if is_instance_valid(nd):
		nd.create_tween().tween_property(nd, "modulate", COL_ELIM, 0.25)
	_grey_subtree(_bst[idx]["left"] as int)
	_grey_subtree(_bst[idx]["right"] as int)

func _restore_all_node_colors() -> void:
	for i in range(_bst.size()):
		var nd := _bst[i]["sprite"] as Node2D
		if is_instance_valid(nd):
			nd.create_tween().tween_property(nd, "modulate",
				COL_HEAD if i == _root else COL_WHITE, 0.25)

# ─────────────────────────────────────────────────────────────────────────────
#  DELETE HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _detach_from_parent(idx: int) -> void:
	var par: int = _bst[idx]["parent"] as int
	if par >= 0 and par < _bst.size():
		if _bst[par]["left"]  == idx: _bst[par]["left"]  = -1
		if _bst[par]["right"] == idx: _bst[par]["right"] = -1

func _relink_parent(old_idx: int, new_idx: int) -> void:
	var par: int = _bst[old_idx]["parent"] as int
	if par >= 0 and par < _bst.size():
		if _bst[par]["left"]  == old_idx: _bst[par]["left"]  = new_idx
		if _bst[par]["right"] == old_idx: _bst[par]["right"] = new_idx

# ─────────────────────────────────────────────────────────────────────────────
#  PROCESS
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _alive: return
	if _combo > 0:
		_combo_decay -= delta
		if _combo_decay <= 0.0: _combo = 0; _combo_lbl.text = ""
	_bg_time += delta
	for sprite in _parallax_layers:
		if not is_instance_valid(sprite): continue
		var amount: float = sprite.get_meta("scroll_amount") as float
		sprite.position.x = 640.0 + sin(_bg_time * 0.18) * amount

# ─────────────────────────────────────────────────────────────────────────────
#  SETUP
# ─────────────────────────────────────────────────────────────────────────────
func _setup_bg() -> void:
	_bg.visible = false
	var layers := [
		{"file":"Layer_0011_0.png",      "scroll":0.0,  "z":-30},
		{"file":"Layer_0010_1.png",      "scroll":0.0,  "z":-29},
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
	var base := "res://assets/art/tree/bg/parallax/"
	for layer in layers:
		var path: String = base + layer["file"]
		if not ResourceLoader.exists(path): continue
		var tex: Texture2D = load(path)
		var sp := Sprite2D.new()
		sp.texture        = tex
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.z_index        = layer["z"] as int
		sp.scale          = Vector2(1280.0/tex.get_width(), 720.0/tex.get_height())
		sp.position       = Vector2(640, 360)
		sp.set_meta("scroll_amount", layer["scroll"] as float)
		add_child(sp)
		_parallax_layers.append(sp)

func _setup_hud() -> void:
	for lbl: Label in [_score_lbl,_combo_lbl,_timer_lbl,_goal_lbl,_acc_lbl,
						_hint_lbl,_task_lbl,_struct_lbl,_balance_lbl,
						_fail_lbl,_complete_banner,_trav_dot,_trav_banner,
						_complexity_lbl,_trace_overlay]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", _pixel_font)
			lbl.add_theme_font_size_override("font_size", 16)

	_score_lbl.text    = "Score: 0"
	_combo_lbl.text    = ""
	_acc_lbl.text      = "Accuracy: -"
	_goal_lbl.text     = "Rounds: 0 / %d" % _p["total_rounds"]
	_timer_lbl.visible = false
	_struct_lbl.text   = "Oracle's Law:  Left rune < Parent < Right rune"

	_trav_banner.add_theme_font_override("font", _pixel_font)
	_trav_banner.add_theme_color_override("font_color", COL_TRAV)
	_trav_banner.add_theme_font_size_override("font_size", 15)

	_complete_banner.add_theme_font_size_override("font_size", 52)
	_complete_banner.add_theme_color_override("font_color", COL_HEAD)
	_complete_banner.z_index = 100

	_trav_dot.text = "●"
	_trav_dot.add_theme_font_size_override("font_size", 24)
	_trav_dot.add_theme_color_override("font_color", COL_TRAV)
	_trav_dot.z_index = 50

	if is_instance_valid(_hint_lbl):
		_hint_lbl.add_theme_font_size_override("font_size", 13)
		_hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if is_instance_valid(_complexity_lbl):
		_complexity_lbl.add_theme_font_size_override("font_size", 13)
		_complexity_lbl.add_theme_color_override("font_color", Color(0.6,1.0,0.8))
		_complexity_lbl.visible = false

	_refresh_lives()

func _setup_instruction_bar() -> void:
	if is_instance_valid(_task_lbl): _task_lbl.visible = false
	var hud    := get_node_or_null("HUD") as CanvasLayer
	var parent : Node = hud if hud != null else self

	_instr_bar = ColorRect.new()
	_instr_bar.color   = Color(0.05,0.05,0.08,0.95)
	_instr_bar.size    = Vector2(1280,38)
	_instr_bar.position = Vector2(0,682)
	_instr_bar.z_index = 80
	parent.add_child(_instr_bar)

	var accent := ColorRect.new()
	accent.color = Color(0.3,0.9,0.5,0.6); accent.size = Vector2(1280,2)
	_instr_bar.add_child(accent)

	_instr_task = Label.new()
	_instr_task.add_theme_font_override("font", _pixel_font)
	_instr_task.add_theme_font_size_override("font_size", 14)
	_instr_task.add_theme_color_override("font_color", Color(0.95,0.95,0.7))
	_instr_task.position  = Vector2(14,9); _instr_task.size = Vector2(900,28)
	_instr_task.z_index   = 81; _instr_task.clip_text = true
	_instr_bar.add_child(_instr_task)

	_instr_rule = Label.new()
	_instr_rule.add_theme_font_override("font", _pixel_font)
	_instr_rule.add_theme_font_size_override("font_size", 13)
	_instr_rule.add_theme_color_override("font_color", Color(0.55,1.0,0.65))
	_instr_rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_instr_rule.position  = Vector2(910,10); _instr_rule.size = Vector2(357,24)
	_instr_rule.z_index   = 81; _instr_rule.clip_text = true
	_instr_bar.add_child(_instr_rule)

func _update_instr(task: String, rule = null) -> void:
	if is_instance_valid(_instr_task): _instr_task.text = task
	if is_instance_valid(_instr_rule):
		if rule is String and rule != "":
			_instr_rule.text = rule
		elif rule is Color:
			_instr_task.add_theme_color_override("font_color", rule)
		else:
			_instr_rule.text = "Left rune < Parent < Right rune"

# ─────────────────────────────────────────────────────────────────────────────
#  HINT STRINGS
# ─────────────────────────────────────────────────────────────────────────────
func _insert_hint(val: int) -> String:
	if _bst.is_empty(): return "Drag rune  %d  to the root of the grove." % val
	return "Drag rune  %d  — the trace shows LEFT/RIGHT at each stone." % val

func _traverse_hint() -> String:
	match _trav_mode:
		TravMode.INORDER:   return "Inorder: Left → Root → Right\nRunes appear in sorted order — the grove's true sequence."
		TravMode.PREORDER:  return "Preorder: Root → Left → Right\nUsed to copy or map the entire grove."
		TravMode.POSTORDER: return "Postorder: Left → Right → Root\nSafe removal order — leaves fall before their roots."
	return ""

func _delete_hint() -> String:
	match _delete_case:
		1: return "Leaf rune (Case 1):\nNo branches below — simply remove the stone."
		2: return "Single branch (Case 2):\nThe child stone rises to fill the gap."
		3: return ("Twin branches (Case 3):\n"
				+ "Find the inorder successor — smallest rune in the right branch.\n"
				+ "Swap values, then remove the successor leaf.")
	return ""

# ─────────────────────────────────────────────────────────────────────────────
#  SPRITE FACTORIES
# ─────────────────────────────────────────────────────────────────────────────
func _make_number_sprite(value: int) -> Sprite2D:
	var sp := Sprite2D.new()
	var icon := NODE_ICONS[value % NODE_ICONS.size()]
	if ResourceLoader.exists(icon):
		sp.texture = load(icon)
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.scale   = NODE_SCALE
	sp.z_index = 10
	var lbl := Label.new()
	lbl.text = str(value)
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color(0.95,0.95,0.7))
	lbl.add_theme_color_override("font_shadow_color", Color(0,0,0,0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.position = Vector2(-10,-8)
	sp.add_child(lbl)
	return sp

# ─────────────────────────────────────────────────────────────────────────────
#  ANIMATE BRANCH
# ─────────────────────────────────────────────────────────────────────────────
func _animate_branch(from: Vector2, to: Vector2) -> void:
	var line := Line2D.new()
	line.default_color = COL_EDGE; line.width = 3.0
	line.add_point(from); line.add_point(from)
	_edge_layer.add_child(line)
	line.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)\
		.tween_method(func(t: float): line.set_point_position(1, from.lerp(to,t)), 0.0, 1.0, 0.3)

# ─────────────────────────────────────────────────────────────────────────────
#  NODE HIGHLIGHTING
# ─────────────────────────────────────────────────────────────────────────────
func _highlight_node(nd: Node2D, color: Color, pulsing: bool) -> void:
	if not is_instance_valid(nd): return
	nd.modulate = color
	if pulsing:
		var tw := nd.create_tween().set_loops()
		tw.tween_property(nd, "modulate:a", 0.5, 0.4)
		tw.tween_property(nd, "modulate:a", 1.0, 0.4)

func _make_ring(world_pos: Vector2, color: Color) -> Node2D:
	var node := Node2D.new()
	node.z_index = 40
	var line := Line2D.new()
	line.default_color = Color(color.r, color.g, color.b, 0.75)
	line.width = 2.5
	for i in range(17):
		var angle := TAU * i / 16
		line.add_point(world_pos + Vector2(cos(angle), sin(angle)) * (GHOST_R + 8.0))
	node.add_child(line)
	return node

# ─────────────────────────────────────────────────────────────────────────────
#  FEEDBACK ANIMATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _flash(nd: Node2D, c: Color) -> void:
	if not is_instance_valid(nd): return
	nd.create_tween().tween_property(nd,"modulate",c,0.06)
	nd.create_tween().tween_property(nd,"modulate",COL_WHITE,0.28)

func _bounce(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var s := nd.scale
	var tw := nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd,"scale",s*1.4,0.08)
	tw.tween_property(nd,"scale",s,0.18)

func _shake(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var o := nd.position
	var tw := nd.create_tween()
	for _i in range(6):
		tw.tween_property(nd,"position",o+Vector2(randf_range(-7,7),randf_range(-4,4)),0.04)
	tw.tween_property(nd,"position",o,0.04)

func _pulse_node(nd: Node2D, color: Color) -> void:
	if not is_instance_valid(nd): return
	var tw := nd.create_tween()
	for _i in range(3):
		tw.tween_property(nd,"modulate",color,0.1)
		tw.tween_property(nd,"modulate",COL_WHITE,0.1)

func _float_node(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	_float_world(nd.global_position + Vector2(-20,-44), text, color)

func _float_world(pos: Vector2, text: String, color: Color) -> void:
	var par := _tree_layer
	var lbl := Label.new(); lbl.text = text; lbl.z_index = 200
	lbl.add_theme_font_override("font",_pixel_font)
	lbl.add_theme_font_size_override("font_size",16)
	lbl.add_theme_color_override("font_color",color)
	par.add_child(lbl); lbl.global_position = pos
	var tw := lbl.create_tween()
	tw.tween_property(lbl,"position",lbl.position+Vector2(0,-40),0.9)
	tw.parallel().tween_property(lbl,"modulate:a",0.0,0.9)
	tw.tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  BST UTILITIES
# ─────────────────────────────────────────────────────────────────────────────
func _live_bst_indices() -> Array:
	var out: Array = []
	for i in range(_bst.size()):
		if is_instance_valid(_bst[i]["sprite"] as Node2D): out.append(i)
	return out

func _bst_live_count() -> int:
	return _live_bst_indices().size()

# ─────────────────────────────────────────────────────────────────────────────
#  HUD HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_lives() -> void:
	for c in _lives_row.get_children(): c.queue_free()
	for i in range(3):
		var lbl := Label.new()
		lbl.text = "❤" if i < _lives else "🖤"
		lbl.add_theme_font_size_override("font_size",22)
		_lives_row.add_child(lbl)

func _accuracy() -> float:
	var total: int = (_stat["correct"] as int) + (_stat["wrong"] as int)
	return 100.0 if total == 0 else float(_stat["correct"]) / float(total) * 100.0

# ─────────────────────────────────────────────────────────────────────────────
#  COMPLETION
# ─────────────────────────────────────────────────────────────────────────────
func _play_completion() -> void:
	_state = GameState.COMPLETE
	AudioManager.play_sfx(PATH_SFX_WIN)

	var flash := ColorRect.new()
	flash.color = Color(0.4,1.0,0.6,0.0); flash.size = Vector2(1280,720); flash.z_index = 90
	add_child(flash)
	var ftw := flash.create_tween()
	ftw.tween_property(flash,"color:a",0.5,0.12)
	ftw.tween_property(flash,"color:a",0.0,0.5)
	ftw.tween_callback(flash.queue_free)

	_complete_banner.visible = true
	_complete_banner.text    = "THE GROVE IS COMPLETE!"
	_complete_banner.scale   = Vector2(0.1,0.1)
	_complete_banner.global_position = Vector2(280,290)
	_complete_banner.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
		.tween_property(_complete_banner,"scale",Vector2(1,1),0.4)

	# Auto-run final inorder traversal to show the sorted tree
	await get_tree().create_timer(0.7).timeout
	var order: Array = []
	_collect_order(_root, TravMode.INORDER, order)
	var visited: Array = []
	for ni in order:
		var nd := _bst[ni]["sprite"] as Node2D
		if is_instance_valid(nd): _pulse_node(nd, COL_TRAV)
		visited.append(_bst[ni]["value"] as int)
		await get_tree().create_timer(0.35).timeout
	_trav_banner.text    = "The runes in order: " + " → ".join(visited.map(func(v): return str(v)))
	_trav_banner.visible = true
	_trav_banner.add_theme_color_override("font_color", COL_OK)

	var _chapter_id: int = GameRouter.current_chapter if has_node("/root/GameRouter") else 16
	if has_node("/root/PlayerProfile"):
		var s := _build_stats(true)
		PlayerProfile.save_chapter_result(_chapter_id, int(s["score"]), _grade_to_stars(_calc_grade(true)), float(s.get("accuracy", 0.0)))
	await get_tree().create_timer(2.5).timeout
	GameRouter.chapter_complete(_chapter_id, _score, _grade_to_stars(_calc_grade(true)))

# ─────────────────────────────────────────────────────────────────────────────
#  END GAME
# ─────────────────────────────────────────────────────────────────────────────
func _end_game(success: bool) -> void:
	if _state == GameState.COMPLETE: return
	_alive  = false
	_state  = GameState.COMPLETE
	var grade := _calc_grade(success)

	var summary: String
	if success:
		summary = "✓ Grade: %s  Accuracy: %.0f%%" % [grade, _accuracy()]
	else:
		summary = ("✗ Grade: %s\nAccuracy: %.0f%%\n\n"
			+ "Rounds completed: %d / %d\n"
			+ "Inserts: %d  Searches: %d  Traversals: %d  Deletes: %d") \
			% [grade, _accuracy(), _rounds_done,
			   _p["total_rounds"],
			   _stat["inserts"], _stat["searches"],
			   _stat["traversals"], _stat["deletes"]]

	_fail_summary.visible = true
	_fail_lbl.text        = summary

	var _chapter_id: int = GameRouter.current_chapter if has_node("/root/GameRouter") else 16
	if has_node("/root/PlayerProfile"):
		var s := _build_stats(success)
		PlayerProfile.save_chapter_result(_chapter_id, int(s["score"]), _grade_to_stars(grade), float(s.get("accuracy", 0.0)))
	await get_tree().create_timer(3.0).timeout
	GameRouter.chapter_complete(_chapter_id, _score, _grade_to_stars(grade))

# ─────────────────────────────────────────────────────────────────────────────
#  GRADING
# ─────────────────────────────────────────────────────────────────────────────
func _build_stats(success: bool) -> Dictionary:
	return {"score":_score,"grade":_calc_grade(success),"accuracy":_accuracy(),
			"inserts":_stat["inserts"],"searches":_stat["searches"],
			"traversals":_stat["traversals"],"deletes":_stat["deletes"],
			"rebalances":_stat["rebalances"],"success":success}

func _calc_grade(success: bool) -> String:
	var acc := _accuracy()
	if not success: return "C" if acc >= 60.0 else "F"
	if acc >= 95.0: return "S"
	if acc >= 82.0: return "A"
	if acc >= 68.0: return "B"
	return "C"

func _grade_to_stars(grade: String) -> int:
	match grade:
		"S","A": return 3
		"B":     return 2
		"C":     return 1
		_:       return 0
