# =============================================================================
# QueueGame.gd  —  "Queue Town: Sort the Line!"
#
# CORE MECHANIC (new):
#   • Citizens spawn in the HOLDING AREA (right side) with a hidden VALUE (1–9).
#   • Player uses peek() to reveal a citizen's value before deciding where they go.
#   • Player drags citizens between the HOLDING AREA and the QUEUE LANE.
#   • Goal: arrange the queue so values are ASCENDING left→right
#     (lowest value at FRONT [slot 0], highest at BACK).
#   • Because it's a queue, you can only enqueue to the BACK and dequeue from
#     the FRONT — so sorting requires deliberate enqueue/dequeue planning.
#   • A "SUBMIT" zone checks the queue order and scores the round.
#
# QUEUE CONCEPTS TAUGHT:
#   Tier 0 — OBSERVE    Watch auto-sort happen, values shown immediately
#   Tier 1 — ENQUEUE    Drag holders into queue slots (values shown)
#   Tier 2 — DEQUEUE    Must dequeue-to-holding then re-enqueue to fix order
#   Tier 3 — PEEK       Values hidden until player peeks; plan before committing
#   Tier 4 — SCHEDULER  Limited moves budget — efficient sorting needed
# =============================================================================

extends Node2D

# ── Safe helpers ──────────────────────────────────────────────────────────────
func _apply_font(node: Control) -> void:
	if _pixel_font == null or not is_instance_valid(node): return
	node.add_theme_font_override("font", _pixel_font)

func _safe_sfx(path: String) -> void:
	if has_node("/root/AudioManager") and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx(path)

func _safe_bgm(path: String) -> void:
	if has_node("/root/AudioManager") and AudioManager.has_method("play_bgm"):
		AudioManager.play_bgm(path)

# ── Assets ────────────────────────────────────────────────────────────────────
const PATH_FONT    := "res://assets/medieval/font/medieval.ttf"
const PATH_BG      := "res://assets/medieval/art/map/grass.jpg"
const PATH_SPRITE  := "res://assets/characters/CGabrielChars24x24.png"
const PATH_SFX_OK  := "res://assets/codemon/audio/sfx/success.ogg"
const PATH_SFX_FAIL:= "res://assets/codemon/audio/sfx/fail.ogg"
const PATH_BGM     := "res://assets/medieval/audio/music/silverbook_loop.ogg"

# ── Sprite sheet config (CGabrielChars24x24.png) ──────────────────────────────
# 10 columns × 159 rows of 24×24 sprites.
# We pick one idle frame (col 0) per citizen type from specific rows.
const SPRITE_W     := 24
const SPRITE_H     := 24
const SPRITE_COLS  := 10
const SPRITE_SCALE := 3   # render at 72×72

# Row in the sprite sheet for each citizen type (down-facing idle = col 0)
# Picked to match: merchant/tax, cook/food, guard/permit, noble/vip, dark-figure/bomb
const SPRITE_ROWS := {
	"TAX":    8,    # merchant-looking character
	"FOOD":   16,   # green-robed cook
	"PERMIT": 24,   # blue armoured guard
	"VIP":    0,    # golden noble at top
	"BOMB":   40,   # dark/red character
}

# ── Layout ────────────────────────────────────────────────────────────────────
const SCREEN_W      := 1280
const SCREEN_H      := 720
const MAX_QUEUE     := 6       # queue lane capacity (keep small for clarity)
const MAX_HOLDING   := 4       # holding area capacity
const SLOT_W        := 110.0   # queue slot width
const SLOT_H        := 100.0
const QUEUE_Y       := 480.0   # centre-y of queue lane citizens
const QUEUE_X0      := 160.0   # centre-x of slot [0]
const HOLD_Y        := 200.0   # centre-y of holding area citizens
const HOLD_X0       := 780.0   # centre-x of holding slot [0]
const HOLD_GAP      := 120.0
const SUBMIT_X      := 90.0
const SUBMIT_Y      := 480.0
const DROP_R        := 55.0    # drop-target radius

# ── Colors ────────────────────────────────────────────────────────────────────
const COL_BG      := Color(0.055, 0.043, 0.141)
const COL_PANEL   := Color(0.086, 0.075, 0.204, 0.88)
const COL_BORDER  := Color(0.549, 0.451, 0.149)
const COL_GOLD    := Color(0.922, 0.745, 0.216)
const COL_GREEN   := Color(0.235, 0.784, 0.392)
const COL_RED     := Color(0.843, 0.196, 0.196)
const COL_BLUE    := Color(0.353, 0.471, 0.784)
const COL_AMBER   := Color(0.824, 0.580, 0.137)
const COL_PARCH   := Color(0.882, 0.804, 0.580)
const COL_WHITE   := Color(0.933, 0.910, 0.843)
const COL_GRAY    := Color(0.353, 0.353, 0.431)
const COL_DARK    := Color(0.031, 0.027, 0.086)
const COL_PEEK    := Color(0.784, 0.627, 0.059, 0.94)

# ── Tier params ───────────────────────────────────────────────────────────────
# Tier 0 → ch 26   Tier 1 → ch 27   Tier 2 → ch 28   Tier 3 → ch 29   Tier 4 → ch 30
const TIER_PARAMS: Array[Dictionary] = [
	# 0 ENQUEUE — values visible, player drags citizens into queue in sorted order
	{"mode":"enqueue",   "hidden":false, "move_budget":0,  "round_count":3,
	 "citizens":4, "concept":"ENQUEUE"},
	# 1 DEQUEUE — values visible, must dequeue-to-hold to fix wrong order
	{"mode":"dequeue",   "hidden":false, "move_budget":0,  "round_count":4,
	 "citizens":5, "concept":"DEQUEUE"},
	# 2 PEEK — values hidden until player clicks to reveal
	{"mode":"peek",      "hidden":true,  "move_budget":0,  "round_count":4,
	 "citizens":5, "concept":"PEEK"},
	# 3 SCHEDULER — hidden values + limited move budget
	{"mode":"scheduler", "hidden":true,  "move_budget":12, "round_count":5,
	 "citizens":6, "concept":"SCHEDULER"},
	# 4 MASTER — all concepts, tighter budget, more citizens
	{"mode":"scheduler", "hidden":true,  "move_budget":10, "round_count":6,
	 "citizens":6, "concept":"MASTER"},
]

# ── Concept slides ────────────────────────────────────────────────────────────
const CONCEPT_SLIDES: Dictionary = {
	"ENQUEUE": [
		{
			"title": "Queue Town — Sort the Line!",
			"body":
"Welcome to Queue Town!\n\n" +
"Citizens arrive in the HOLDING AREA on the right.\n" +
"Each citizen has a NUMBER value shown above their head.\n\n" +
"Your job: arrange the queue so values go\n" +
"LOWEST  →  HIGHEST  from FRONT to BACK.\n\n" +
"A queue only lets you add to the BACK and remove from the FRONT.\nNo skipping ahead!",
		},
		{
			"title": "enqueue( citizen )",
			"body":
"enqueue() adds a citizen to the BACK of the queue.\n\n" +
"In code:\n" +
"  queue.push_back( citizen )\n\n" +
"The citizen always joins at the last slot.\n" +
"You cannot insert them in the middle!\n\n" +
"Plan your order BEFORE you drag — once someone is in,\n" +
"getting them back out costs extra moves later.",
		},
		{
			"title": "Your Task",
			"body":
"➤  Values are VISIBLE this round — use them to plan.\n\n" +
"1.  Look at all citizens in the HOLDING AREA.\n" +
"2.  Drag the LOWEST value citizen into the queue first.\n" +
"3.  Keep dragging in ascending order.\n" +
"4.  When sorted, drag slot [0] → ✅ SUBMIT to score!\n\n" +
"Remember: the LOWEST value must be at FRONT [0].",
		},
	],
	"DEQUEUE": [
		{
			"title": "dequeue()",
			"body":
"dequeue() removes the citizen at the FRONT of the queue.\n\n" +
"In code:\n" +
"  citizen = queue.pop_front()\n\n" +
"Only the FRONT [slot 0] can be removed.\n" +
"You cannot pull someone from the middle or back!\n\n" +
"Use dequeue to move a misplaced citizen back to\n" +
"the holding area, then re-enqueue them in the right order.",
		},
		{
			"title": "The Sort Problem",
			"body":
"Citizens will arrive in RANDOM order this round.\n\n" +
"If the wrong citizen ends up at the front, you must:\n\n" +
"  1.  dequeue() them back to the holding area\n" +
"  2.  enqueue() the correct lower-value citizen first\n" +
"  3.  enqueue() the dequeued citizen after\n\n" +
"This back-and-forth IS the lesson —\n" +
"it shows exactly why queue order matters!",
		},
		{
			"title": "Your Task",
			"body":
"➤  Drag holding → queue lane  =  enqueue()\n" +
"➤  Drag slot [0] → holding    =  dequeue()\n" +
"➤  Drag slot [0] → ✅ SUBMIT  =  check your sort!\n\n" +
"Sort all citizens LOWEST → HIGHEST from front to back.\n\n" +
"The right panel shows the live queue state\n" +
"and the last operation you performed.",
		},
	],
	"PEEK": [
		{
			"title": "peek() — Look Before You Commit",
			"body":
"Values are now HIDDEN — citizens show  ?  above their head.\n\n" +
"Click any citizen to PEEK and reveal their value:\n\n" +
"  value = queue.front()   # peek at front\n\n" +
"Peeking does NOT move anyone and costs ZERO moves.\n" +
"You can peek as many times as you like!\n\n" +
"The PEEK BANNER at the top always shows the\n" +
"current front citizen's revealed value.",
		},
		{
			"title": "Strategy — Peek First, Then Sort",
			"body":
"Before dragging anyone, click to peek ALL citizens\n" +
"in the holding area to learn their values.\n\n" +
"Then plan your enqueue order:\n" +
"  •  Enqueue the lowest value first\n" +
"  •  If you enqueue in the wrong order, dequeue\n" +
"     and fix it — but that costs extra moves!\n\n" +
"A well-planned peek session = a perfect sort.",
		},
	],
	"SCHEDULER": [
		{
			"title": "Move Budget — Efficiency Matters",
			"body":
"Values are hidden AND you now have a LIMITED move budget.\n\n" +
"  •  Each enqueue  =  1 move\n" +
"  •  Each dequeue  =  1 move\n" +
"  •  Peek          =  FREE  (always!)\n\n" +
"If you run out of moves before the queue is sorted,\n" +
"the round fails and you lose a life!\n\n" +
"Budget shown in the top-left corner.",
		},
		{
			"title": "Efficient Sorting",
			"body":
"The MINIMUM moves to sort N citizens:\n" +
"  N enqueues  (one per citizen, perfect order)\n\n" +
"Every mistake costs 2 extra moves:\n" +
"  1 dequeue to undo  +  1 re-enqueue to fix\n\n" +
"Strategy:\n" +
"  1.  Peek ALL citizens first (free!)\n" +
"  2.  Plan the exact enqueue order\n" +
"  3.  Execute without mistakes\n\n" +
"A perfect round = N moves exactly.",
		},
	],
	"MASTER": [
		{
			"title": "Master Round — All Concepts",
			"body":
"Final challenge! Everything at once:\n\n" +
"  •  Values HIDDEN — use peek() freely\n" +
"  •  Tight move budget — plan efficiently\n" +
"  •  More citizens per round\n" +
"  •  Multiple rounds to complete\n\n" +
"Concepts tested:\n" +
"  enqueue()  |  dequeue()  |  peek()\n" +
"  isEmpty()  |  isFull()  |  efficient sorting",
		},
		{
			"title": "You've Got This!",
			"body":
"Remember the golden rules:\n\n" +
"  1.  PEEK before you commit to any move\n" +
"  2.  ENQUEUE in ascending order from the start\n" +
"  3.  Only DEQUEUE when you absolutely must fix an error\n" +
"  4.  The queue is FIFO — respect the order!\n\n" +
"Sort LOWEST → HIGHEST, submit, and score.\n\n" +
"Good luck, Queue Master!",
		},
	],
}

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _world          : Node2D          = $WorldLayer
@onready var _game_timer     : Timer           = $GameTimer
@onready var _spawn_timer    : Timer           = $SpawnTimer
@onready var _hud            : CanvasLayer     = $HUD
@onready var _score_lbl      : Label           = $HUD/ScoreLabel
@onready var _round_lbl      : Label           = $HUD/RoundLabel
@onready var _moves_lbl      : Label           = $HUD/MovesLabel
@onready var _acc_lbl        : Label           = $HUD/AccuracyLabel
@onready var _combo_lbl      : Label           = $HUD/ComboLabel
@onready var _lives_row      : HBoxContainer   = $HUD/LivesRow
@onready var _hint_lbl       : Label           = $HUD/HintBox/HintLabel
@onready var _concept_lbl    : Label           = $HUD/RightPanel/ConceptPanel/ConceptLabel
@onready var _queue_disp     : VBoxContainer   = $HUD/RightPanel/QueueDisplay
@onready var _peek_banner    : PanelContainer  = $HUD/PeekBanner
@onready var _peek_lbl       : Label           = $HUD/PeekBanner/PeekLabel
@onready var _submit_zone    : Node2D          = $WorldLayer/SubmitZone
@onready var _intro_overlay  : PanelContainer  = $HUD/IntroOverlay
@onready var _intro_title    : Label           = $HUD/IntroOverlay/Margin/VBox/TitleLabel
@onready var _intro_body     : Label           = $HUD/IntroOverlay/Margin/VBox/BodyLabel
@onready var _intro_page     : Label           = $HUD/IntroOverlay/Margin/VBox/NavRow/PageLabel
@onready var _intro_back     : Button          = $HUD/IntroOverlay/Margin/VBox/NavRow/BackBtn
@onready var _intro_next     : Button          = $HUD/IntroOverlay/Margin/VBox/NavRow/NextBtn
@onready var _drag_ghost     : Node2D          = $DragGhost

# ── State ─────────────────────────────────────────────────────────────────────
var _p            : Dictionary = {}
var _chapter_id   : int        = 26
var _pixel_font   : Font       = null
var _sprite_sheet : Texture2D  = null

# Queue and holding — arrays of citizen dicts
var _cq           : Array = []   # queue lane, index 0 = front
var _holding      : Array = []   # holding area on the right

# Citizen dict keys:
#   uid, value, ctype, revealed, vis_x, vis_y, walking, target_x, target_y, in_queue

var _uid          : int   = 0
var _alive        : bool  = false
var _intro_vis    : bool  = false
var _intro_slides : Array = []
var _intro_idx    : int   = 0

# Drag
var _dragging     : bool       = false
var _drag_c       : Dictionary = {}
var _drag_src     : String     = ""   # "queue_N" | "holding_N"
var _drag_origin  : Vector2    = Vector2.ZERO
var _drag_pos     : Vector2    = Vector2.ZERO

# Scoring / rounds
var _score        : int   = 0
var _combo        : int   = 0
var _lives        : int   = 3
var _moves_left   : int   = 0
var _round        : int   = 0
var _correct      : int   = 0
var _wrong        : int   = 0


# Citizen visual nodes keyed by uid
var _cnodes       : Dictionary = {}

# Tween registry for walking animations
var _walk_tweens  : Dictionary = {}

# ── Citizen types cycling list ────────────────────────────────────────────────
const CTYPES := ["TAX","FOOD","PERMIT","VIP","BOMB"]
const CTYPE_COLORS := {
	"TAX":    Color(0.843, 0.608, 0.157),
	"FOOD":   Color(0.255, 0.549, 0.298),
	"PERMIT": Color(0.392, 0.510, 0.667),
	"VIP":    Color(0.902, 0.800, 0.314),
	"BOMB":   Color(0.647, 0.176, 0.176),
}

# =============================================================================
#  READY
# =============================================================================
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font if ResourceLoader.exists(PATH_FONT) else null
	if ResourceLoader.exists(PATH_SPRITE):
		_sprite_sheet = load(PATH_SPRITE) as Texture2D

	if has_node("/root/GameRouter"):
		_chapter_id = GameRouter.current_chapter
	_chapter_id = clamp(_chapter_id, 26, 30)
	var tier : int = clamp(_chapter_id - 26, 0, 4)
	if has_node("/root/DifficultyManager"):
		tier = clamp(DifficultyManager.current_tier, 0, 4)
	_p = TIER_PARAMS[tier]

	_setup_world()
	_setup_hud()
	_safe_bgm(PATH_BGM)
	_show_intro()

# =============================================================================
#  WORLD SETUP
# =============================================================================
func _setup_world() -> void:
	# Background
	if ResourceLoader.exists(PATH_BG):
		var bg := Sprite2D.new()
		bg.texture        = load(PATH_BG)
		bg.position       = Vector2(640, 360)
		bg.scale          = Vector2(1280.0/576.0, 720.0/384.0)
		bg.z_index        = -10
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(bg)

	# Queue lane trough
	_draw_queue_lane()

	# Holding area backdrop
	_draw_holding_area()

	# Submit zone
	_build_submit_zone()

# Draw the queue lane background + slot markers
func _draw_queue_lane() -> void:
	var lane := ColorRect.new()
	lane.position = Vector2(QUEUE_X0 - SLOT_W * 0.5 - 8,
							QUEUE_Y  - SLOT_H * 0.5 - 8)
	lane.size     = Vector2(MAX_QUEUE * SLOT_W + 16, SLOT_H + 16)
	lane.color    = Color(0.06, 0.05, 0.16, 0.78)
	_world.add_child(lane)

	# Slot dividers + index labels
	for i in range(MAX_QUEUE):
		var sx := QUEUE_X0 + i * SLOT_W

		# Divider
		if i > 0:
			var ln := Line2D.new()
			ln.add_point(Vector2(sx - SLOT_W * 0.5, QUEUE_Y - SLOT_H * 0.5))
			ln.add_point(Vector2(sx - SLOT_W * 0.5, QUEUE_Y + SLOT_H * 0.5))
			ln.width         = 1.5
			ln.default_color = Color(0.25, 0.22, 0.45, 0.6)
			_world.add_child(ln)

		# Index label
		var idx_lbl := Label.new()
		idx_lbl.text     = "[%d]" % i
		idx_lbl.position = Vector2(sx - 14, QUEUE_Y + SLOT_H * 0.5 + 4)
		_apply_font(idx_lbl)
		idx_lbl.add_theme_font_size_override("font_size", 12)
		idx_lbl.add_theme_color_override("font_color",
			COL_GREEN if i == 0 else COL_GRAY)
		_world.add_child(idx_lbl)

	# FRONT / BACK labels
	var fl := Label.new()
	fl.text     = "◀ FRONT"
	fl.position = Vector2(QUEUE_X0 - SLOT_W * 0.5 - 70, QUEUE_Y - 12)
	_apply_font(fl)
	fl.add_theme_font_size_override("font_size", 13)
	fl.add_theme_color_override("font_color", COL_GREEN)
	_world.add_child(fl)

	var bl := Label.new()
	bl.text     = "BACK ▶"
	bl.position = Vector2(QUEUE_X0 + MAX_QUEUE * SLOT_W - SLOT_W * 0.5 + 6, QUEUE_Y - 12)
	_apply_font(bl)
	bl.add_theme_font_size_override("font_size", 13)
	bl.add_theme_color_override("font_color", COL_AMBER)
	_world.add_child(bl)

	# Lane title
	var lt := Label.new()
	lt.text     = "— QUEUE LANE —"
	lt.position = Vector2(QUEUE_X0 - SLOT_W * 0.5, QUEUE_Y - SLOT_H * 0.5 - 28)
	_apply_font(lt)
	lt.add_theme_font_size_override("font_size", 14)
	lt.add_theme_color_override("font_color", COL_BLUE)
	_world.add_child(lt)

func _draw_holding_area() -> void:
	var bg := ColorRect.new()
	bg.position = Vector2(HOLD_X0 - SLOT_W * 0.5 - 8,
						  HOLD_Y  - SLOT_H * 0.5 - 8)
	bg.size     = Vector2(MAX_HOLDING * HOLD_GAP + 16, SLOT_H + 16)
	bg.color    = Color(0.05, 0.08, 0.05, 0.72)
	_world.add_child(bg)

	# Outline
	var ol := ColorRect.new()
	ol.position = bg.position - Vector2(2, 2)
	ol.size     = bg.size + Vector2(4, 4)
	ol.color    = Color(0.35, 0.55, 0.2, 0.5)
	ol.z_index  = -1
	_world.add_child(ol)

	var ht := Label.new()
	ht.text     = "— HOLDING AREA —"
	ht.position = Vector2(HOLD_X0 - SLOT_W * 0.5, HOLD_Y - SLOT_H * 0.5 - 28)
	_apply_font(ht)
	ht.add_theme_font_size_override("font_size", 14)
	ht.add_theme_color_override("font_color", COL_AMBER)
	_world.add_child(ht)

func _build_submit_zone() -> void:
	var sz := _submit_zone
	# Visual box
	var bg := ColorRect.new()
	bg.position = Vector2(-60, -50)
	bg.size     = Vector2(120, 90)
	bg.color    = Color(0.08, 0.35, 0.12, 0.9)
	sz.add_child(bg)

	var lbl := Label.new()
	lbl.text     = "✅\nSUBMIT"
	lbl.position = Vector2(-50, -48)
	lbl.size     = Vector2(100, 84)
	_apply_font(lbl)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", COL_GREEN)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	sz.add_child(lbl)

	_submit_zone.position = Vector2(SUBMIT_X, SUBMIT_Y)
	_submit_zone.visible  = false   # shown only when queue has ≥1 citizen

# =============================================================================
#  HUD SETUP
# =============================================================================
func _setup_hud() -> void:
	for lbl in [_score_lbl, _round_lbl, _moves_lbl, _acc_lbl,
				_combo_lbl, _hint_lbl, _concept_lbl, _peek_lbl]:
		if is_instance_valid(lbl): _apply_font(lbl)

	_score_lbl.text   = "Score: 0"
	_round_lbl.text   = "Round 1 / %d" % _p["round_count"]
	_moves_lbl.visible = _p["move_budget"] > 0
	_acc_lbl.text     = "Accuracy: —"
	_peek_banner.visible = false
	_hint_lbl.text    = _hint_text()
	_concept_lbl.text = "Drag citizens to sort the queue\nlowest value → FRONT [0]"
	_refresh_lives()

func _hint_text() -> String:
	match _p["mode"]:
		"enqueue":   return "Drag from HOLDING → queue to enqueue.\nSort lowest → highest, then drag [0] → ✅ SUBMIT."
		"dequeue":   return "Drag [0] → HOLDING to dequeue.\nDrag HOLDING → queue to enqueue.\nSubmit when sorted!"
		"peek":      return "Click any citizen to PEEK (free).\nThen drag to sort. Submit when done."
		"scheduler": return "PEEK first (free). Each drag = 1 move.\nBudget: %d moves. Submit when sorted." % _p["move_budget"]
	return ""

# =============================================================================
#  INTRO OVERLAY
# =============================================================================
func _show_intro() -> void:
	var concept : String = _p["concept"]
	_intro_slides = CONCEPT_SLIDES.get(concept, [])
	if _intro_slides.is_empty():
		_dismiss_intro()
		return
	_intro_idx = 0
	_intro_vis = true
	_intro_overlay.visible = true
	_intro_back.pressed.connect(_on_intro_back)
	_intro_next.pressed.connect(_on_intro_next)
	_apply_font(_intro_title)
	_apply_font(_intro_body)
	_apply_font(_intro_page)
	_intro_title.add_theme_font_size_override("font_size", 22)
	_intro_body.add_theme_font_size_override("font_size", 16)
	_refresh_intro()

func _refresh_intro() -> void:
	var s : Dictionary = _intro_slides[_intro_idx]
	_intro_title.text    = s["title"]
	_intro_body.text     = s["body"]
	_intro_page.text     = "%d / %d" % [_intro_idx + 1, _intro_slides.size()]
	_intro_back.disabled = (_intro_idx == 0)
	_intro_next.text     = "Begin!" if _intro_idx == _intro_slides.size()-1 else "Next ▶"

func _on_intro_back() -> void:
	_intro_idx = max(0, _intro_idx - 1); _refresh_intro()

func _on_intro_next() -> void:
	if _intro_idx < _intro_slides.size()-1:
		_intro_idx += 1; _refresh_intro()
	else:
		_dismiss_intro()

func _dismiss_intro() -> void:
	_intro_vis = false
	_intro_overlay.visible = false
	_alive = true
	_start_round()

# =============================================================================
#  ROUND MANAGEMENT
# =============================================================================
func _start_round() -> void:
	_round += 1
	_round_lbl.text = "Round %d / %d" % [_round, _p["round_count"]]
	_cq      = []
	_holding = []
	_moves_left = _p["move_budget"] if _p["move_budget"] > 0 else 9999
	_refresh_moves_label()

	# Clear old citizen nodes
	for uid in _cnodes.keys():
		if is_instance_valid(_cnodes[uid]):
			_cnodes[uid].queue_free()
	_cnodes.clear()

	# Spawn citizens into holding area
	var count : int = _p["citizens"]
	var values := range(1, count + 1)
	values.shuffle()
	for i in range(count):
		_uid += 1
		var ct  : String = CTYPES[i % CTYPES.size()]
		var val := values[i] as int
		var c   := {
			"uid":      _uid,
			"value":    val,
			"ctype":    ct,
			"revealed": not _p["hidden"],
			"in_queue": false,
			"vis_x":    HOLD_X0 + i * HOLD_GAP,
			"vis_y":    HOLD_Y,
			"walking":  false,
		}
		_holding.append(c)
		_create_citizen_node(c)

	_submit_zone.visible = false

	_concept_text("Sort citizens LOWEST → HIGHEST\nPeek to reveal values, drag to sort, submit when done!")

func _next_round_or_end() -> void:
	if _round >= _p["round_count"]:
		_end_game(true)
	else:
		await get_tree().create_timer(1.2).timeout
		_start_round()

# =============================================================================
#  PROCESS
# =============================================================================
func _process(delta: float) -> void:
	if _intro_vis or not _alive: return

	_tick_walk_positions()
	_tick_peek_banner()
	_submit_zone.visible = not _cq.is_empty()
	_refresh_queue_display()

	if _dragging and is_instance_valid(_drag_ghost):
		_drag_ghost.visible = true
		_drag_ghost.position = _drag_pos
		_sync_ghost_sprite(_drag_c)

func _tick_walk_positions() -> void:
	# Citizens animate toward their target positions
	for c in _cq + _holding:
		var node := _cnodes.get(c["uid"]) as Node2D
		if not is_instance_valid(node): continue
		var target := Vector2(c["vis_x"], c["vis_y"])
		if node.position.distance_to(target) > 2.0:
			node.position = node.position.move_toward(target, 8.0)
		else:
			node.position = target


func _tick_peek_banner() -> void:
	if _cq.is_empty():
		_peek_banner.visible = false
		return
	_peek_banner.visible = true
	var front : Dictionary = _cq[0]
	if front["revealed"]:
		_peek_lbl.text = "peek()  →  front() value = %d  (%s)" % [
			front["value"], front["ctype"]]
	else:
		_peek_lbl.text = "peek()  →  front() = ?  (click to reveal)"

# =============================================================================
#  CITIZEN VISUAL NODES
# =============================================================================
func _create_citizen_node(c: Dictionary) -> void:
	var node := Node2D.new()
	node.name     = "Citizen_%d" % c["uid"]
	node.position = Vector2(c["vis_x"], c["vis_y"])
	node.z_index  = 10

	# Sprite from sheet
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	if _sprite_sheet:
		var row  : int = SPRITE_ROWS.get(c["ctype"], 0)
		var col  : int = 0   # idle down-facing frame
		var region := Rect2(col * SPRITE_W, row * SPRITE_H, SPRITE_W, SPRITE_H)
		sprite.texture        = _sprite_sheet
		sprite.region_enabled = true
		sprite.region_rect    = region
		sprite.scale          = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		# Fallback colored box
		var cr := ColorRect.new()
		cr.size     = Vector2(64, 64)
		cr.position = Vector2(-32, -32)
		cr.color    = CTYPE_COLORS.get(c["ctype"], COL_GRAY)
		node.add_child(cr)
	node.add_child(sprite)

	# Value badge
	var badge_bg := ColorRect.new()
	badge_bg.name     = "BadgeBG"
	badge_bg.size     = Vector2(28, 22)
	badge_bg.position = Vector2(-14, -52)
	badge_bg.color    = COL_DARK
	node.add_child(badge_bg)

	var val_lbl := Label.new()
	val_lbl.name = "ValueLabel"
	val_lbl.text = str(c["value"]) if c["revealed"] else "?"
	val_lbl.position = Vector2(-14, -52)
	val_lbl.size     = Vector2(28, 22)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_apply_font(val_lbl)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.add_theme_color_override("font_color",
		COL_GOLD if c["revealed"] else COL_GRAY)
	node.add_child(val_lbl)

	# Name label below
	var name_lbl := Label.new()
	name_lbl.name = "NameLabel"
	name_lbl.text = c["ctype"]
	name_lbl.position = Vector2(-32, 38)
	name_lbl.size     = Vector2(64, 16)
	_apply_font(name_lbl)
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.add_theme_color_override("font_color", COL_PARCH)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.add_child(name_lbl)

	_world.add_child(node)
	_cnodes[c["uid"]] = node

func _refresh_citizen_node(c: Dictionary) -> void:
	var node := _cnodes.get(c["uid"]) as Node2D
	if not is_instance_valid(node): return
	var vl := node.get_node_or_null("ValueLabel") as Label
	if vl:
		vl.text = str(c["value"]) if c["revealed"] else "?"
		vl.add_theme_color_override("font_color",
			COL_GOLD if c["revealed"] else COL_GRAY)

func _remove_citizen_node(uid: int) -> void:
	if _cnodes.has(uid):
		_cnodes[uid].queue_free()
		_cnodes.erase(uid)

func _sync_ghost_sprite(c: Dictionary) -> void:
	if c.is_empty(): return
	var lbl := _drag_ghost.get_node_or_null("ValueLabel") as Label
	if lbl:
		lbl.text = str(c["value"]) if c["revealed"] else "?"

# =============================================================================
#  POSITION HELPERS
# =============================================================================
func _reposition_queue() -> void:
	for i in range(_cq.size()):
		_cq[i]["vis_x"] = QUEUE_X0 + i * SLOT_W
		_cq[i]["vis_y"] = QUEUE_Y

func _reposition_holding() -> void:
	for i in range(_holding.size()):
		_holding[i]["vis_x"] = HOLD_X0 + i * HOLD_GAP
		_holding[i]["vis_y"] = HOLD_Y

# =============================================================================
#  INPUT — drag & drop + click to peek
# =============================================================================
func _input(event: InputEvent) -> void:
	if _intro_vis: return
	if not _alive:  return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_handle_press(event.position)
		else:
			_handle_release(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_drag_pos = event.position

func _handle_press(pos: Vector2) -> void:
	# Click to peek (non-dragging)
	for c in _holding + _cq:
		if _hit(c, pos) and not c["revealed"]:
			_do_peek(c)
			return

	# Start drag from holding
	for i in range(_holding.size()):
		var c : Dictionary = _holding[i]
		if _hit(c, pos):
			_start_drag(c, "holding_%d" % i, Vector2(c["vis_x"], c["vis_y"]))
			return

	# Start drag from queue FRONT only (dequeue enforces FIFO)
	if not _cq.is_empty():
		var front : Dictionary = _cq[0]
		if _hit(front, pos):
			_start_drag(front, "queue_front", Vector2(front["vis_x"], front["vis_y"]))

func _hit(c: Dictionary, pos: Vector2) -> bool:
	return pos.distance_to(Vector2(c["vis_x"], c["vis_y"])) < DROP_R

func _start_drag(c: Dictionary, src: String, origin: Vector2) -> void:
	_dragging    = true
	_drag_c      = c
	_drag_src    = src
	_drag_origin = origin
	_drag_pos    = origin
	if _cnodes.has(c["uid"]):
		_cnodes[c["uid"]].modulate = Color(1,1,1,0.35)

func _handle_release(pos: Vector2) -> void:
	if not _dragging: return
	_dragging = false
	_drag_ghost.visible = false
	if _cnodes.has(_drag_c.get("uid",-1)):
		_cnodes[_drag_c["uid"]].modulate = Color(1,1,1,1)

	var handled := false

	# FROM HOLDING → queue lane
	if _drag_src.begins_with("holding"):
		for i in range(MAX_QUEUE):
			var tx := QUEUE_X0 + i * SLOT_W
			if pos.distance_to(Vector2(tx, QUEUE_Y)) < DROP_R * 1.2:
				_action_enqueue(_drag_c)
				handled = true
				break
		# FROM HOLDING → submit (not allowed — must be in queue)
		if not handled:
			_snap_back()

	# FROM QUEUE FRONT → holding (dequeue)
	elif _drag_src == "queue_front":
		# Check holding area drop
		for i in range(MAX_HOLDING + 1):
			var tx := HOLD_X0 + i * HOLD_GAP
			if pos.distance_to(Vector2(tx, HOLD_Y)) < DROP_R * 1.4:
				_action_dequeue_to_holding()
				handled = true
				break
		# Check submit zone
		if not handled:
			if pos.distance_to(Vector2(SUBMIT_X, SUBMIT_Y)) < DROP_R * 1.5:
				_action_submit()
				handled = true
		if not handled:
			_snap_back()

	_drag_c  = {}
	_drag_src = ""

func _snap_back() -> void:
	if _cnodes.has(_drag_c.get("uid",-1)):
		_cnodes[_drag_c["uid"]].position = _drag_origin

# =============================================================================
#  QUEUE OPERATIONS — educational core
# =============================================================================

## peek() — reveal value without moving
func _do_peek(c: Dictionary) -> void:
	c["revealed"] = true
	_refresh_citizen_node(c)
	_flash_node(_cnodes.get(c["uid"]), COL_GOLD)
	_concept_text(
		"peek()  →  revealed value = %d\nCitizen: %s\nQueue unchanged — peek is FREE!" % [
		c["value"], c["ctype"]])

## enqueue() — player drags from holding to queue
func _action_enqueue(c: Dictionary) -> void:
	if _cq.size() >= MAX_QUEUE:
		_apply_wrong(
			_cnodes.get(c["uid"]) as Node2D, 0,
			"isFull() → true\nQueue is full (%d/%d)!\nDequeue first." % [_cq.size(), MAX_QUEUE])
		_snap_back()
		return

	if _p["move_budget"] > 0:
		_moves_left -= 1
		_refresh_moves_label()
		if _moves_left < 0:
			_apply_wrong(null, 0, "No moves left!\nRound failed.")
			_lose_life()
			return

	_do_enqueue(c)
	var nd := _cnodes.get(c["uid"]) as Node2D
	_apply_correct(nd, 5)
	_concept_text(
		"enqueue(%s)\n→ queue.push_back()\nValue: %s\nQueue size: %d / %d" % [
		c["ctype"],
		str(c["value"]) if c["revealed"] else "?",
		_cq.size(), MAX_QUEUE])

## dequeue() — player drags front back to holding
func _action_dequeue_to_holding() -> void:
	if _cq.is_empty():
		_apply_wrong(null, 0, "isEmpty() → true\nNothing to dequeue!")
		return

	if _p["move_budget"] > 0:
		_moves_left -= 1
		_refresh_moves_label()
		if _moves_left < 0:
			_apply_wrong(null, 0, "No moves left!\nRound failed.")
			_lose_life()
			return

	var front : Dictionary = _cq[0]
	var nd    := _cnodes.get(front["uid"]) as Node2D
	_do_dequeue_to_holding()
	_apply_correct(nd, 2)
	_concept_text(
		"dequeue()\n→ queue.pop_front()\nReturned: %s (value %s)\nBack to holding area." % [
		front["ctype"],
		str(front["value"]) if front["revealed"] else "?"])

## submit — check if queue is sorted ascending
func _action_submit() -> void:
	if _cq.is_empty():
		_apply_wrong(null, 0, "Queue is empty!\nEnqueue citizens first.")
		return

	if _is_queue_sorted():
		_submit_queue()
	else:
		# Show where the order breaks
		var break_idx := _find_sort_break()
		_apply_wrong(
			_cnodes.get(_cq[break_idx]["uid"]) as Node2D, 10,
			"Not sorted!\nValue %d at [%d] should come after %d.\nTry dequeuing and re-enqueuing." % [
			_cq[break_idx]["value"], break_idx, _cq[break_idx-1]["value"]])
		_wrong += 1

func _submit_queue() -> void:
	_correct += 1
	var pts := 100 + (_cq.size() * 20)
	_score  += pts
	_score_lbl.text = "Score: %d" % _score
	_concept_text(
		"✅ Queue sorted correctly!\n[%s]\nLowest → Highest ✓\n+%d pts" % [
		_queue_value_str(), pts])
	_flash_all_green()
	_safe_sfx(PATH_SFX_OK)
	_next_round_or_end()

# =============================================================================
#  INTERNAL QUEUE HELPERS
# =============================================================================
func _do_enqueue(c: Dictionary) -> void:
	_holding.erase(c)
	c["in_queue"] = true
	_cq.append(c)
	_reposition_queue()
	_reposition_holding()

func _do_dequeue_to_holding() -> void:
	if _cq.is_empty(): return
	var front : Dictionary = _cq.pop_front()
	front["in_queue"] = false
	_holding.append(front)
	_reposition_queue()
	_reposition_holding()

func _is_queue_sorted() -> bool:
	for i in range(1, _cq.size()):
		if _cq[i]["value"] < _cq[i-1]["value"]:
			return false
	return true

func _find_sort_break() -> int:
	for i in range(1, _cq.size()):
		if _cq[i]["value"] < _cq[i-1]["value"]:
			return i
	return 0

func _queue_value_str() -> String:
	var parts : Array = []
	for c in _cq: parts.append(str(c["value"]))
	return " → ".join(parts)

# =============================================================================
#  FEEDBACK
# =============================================================================
func _apply_correct(nd: Node2D, pts: int) -> void:
	_combo += 1
	_score += pts * _combo
	_score_lbl.text = "Score: %d" % _score
	_combo_lbl.text = "×%d COMBO" % _combo if _combo > 1 else ""
	_acc_lbl.text   = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd):
		_flash_node(nd, COL_GREEN)
		_bounce_node(nd)
		_float_label(nd, "+%d" % (pts*_combo), COL_GREEN)
	_safe_sfx(PATH_SFX_OK)

func _apply_wrong(nd: Node2D, penalty: int, msg: String) -> void:
	_combo = 0
	_combo_lbl.text = ""
	if penalty > 0:
		_score = max(0, _score - penalty)
		_score_lbl.text = "Score: %d" % _score
	_acc_lbl.text = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd):
		_flash_node(nd, COL_RED)
		_shake_node(nd)
	if not msg.is_empty():
		_concept_text(msg)
	_safe_sfx(PATH_SFX_FAIL)

func _lose_life() -> void:
	_lives -= 1
	_refresh_lives()
	if _lives <= 0: _end_game(false)

func _concept_text(txt: String) -> void:
	if is_instance_valid(_concept_lbl): _concept_lbl.text = txt

func _flash_node(nd: Node2D, col: Color) -> void:
	if not is_instance_valid(nd): return
	var tw := nd.create_tween()
	tw.tween_property(nd, "modulate", col,      0.07)
	tw.tween_property(nd, "modulate", COL_WHITE,0.25)

func _bounce_node(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var s  := nd.scale
	var tw := nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "scale", s * 1.35, 0.08)
	tw.tween_property(nd, "scale", s,        0.18)

func _shake_node(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var o  := nd.position
	var tw := nd.create_tween()
	for _i in range(6):
		tw.tween_property(nd, "position",
			o + Vector2(randf_range(-8,8), randf_range(-4,4)), 0.04)
	tw.tween_property(nd, "position", o, 0.04)

func _float_label(nd: Node2D, text: String, col: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent()
	if not par: return
	var lbl := Label.new()
	lbl.text = text; lbl.z_index = 200
	_apply_font(lbl)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", col)
	par.add_child(lbl)
	lbl.global_position = nd.global_position + Vector2(-20, -50)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position", lbl.position + Vector2(0,-40), 0.8)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.tween_callback(lbl.queue_free)

func _flash_all_green() -> void:
	for uid in _cnodes.keys():
		_flash_node(_cnodes[uid] as Node2D, COL_GREEN)

# =============================================================================
#  HUD HELPERS
# =============================================================================
func _refresh_lives() -> void:
	for c in _lives_row.get_children(): c.queue_free()
	for i in range(3):
		var lbl := Label.new()
		lbl.text = "❤" if i < _lives else "🖤"
		lbl.add_theme_font_size_override("font_size", 26)
		_lives_row.add_child(lbl)

func _refresh_moves_label() -> void:
	if not _moves_lbl.visible: return
	_moves_lbl.text = "Moves left: %d" % max(0, _moves_left)
	_moves_lbl.add_theme_color_override("font_color",
		COL_RED if _moves_left <= 3 else COL_GOLD)

func _refresh_queue_display() -> void:
	for ch in _queue_disp.get_children():
		if ch.name != "QueueHeader": ch.queue_free()
	for i in range(_cq.size()):
		var c   : Dictionary = _cq[i]
		var row := HBoxContainer.new()
		var il  := Label.new()
		il.text = "[%d]" % i
		_apply_font(il)
		il.add_theme_font_size_override("font_size", 13)
		il.add_theme_color_override("font_color",
			COL_GREEN if i==0 else COL_GRAY)
		il.custom_minimum_size = Vector2(32, 0)
		row.add_child(il)
		var cl := Label.new()
		cl.text = "%s  val=%s" % [c["ctype"], str(c["value"]) if c["revealed"] else "?"]
		_apply_font(cl)
		cl.add_theme_font_size_override("font_size", 13)
		cl.add_theme_color_override("font_color",
			CTYPE_COLORS.get(c["ctype"], COL_WHITE))
		row.add_child(cl)
		_queue_disp.add_child(row)
	if _cq.is_empty():
		var el := Label.new(); el.text = "  (empty)"
		_apply_font(el)
		el.add_theme_font_size_override("font_size", 13)
		el.add_theme_color_override("font_color", COL_GRAY)
		_queue_disp.add_child(el)

func _accuracy() -> float:
	var t := _correct + _wrong
	return 100.0 if t == 0 else float(_correct) / float(t) * 100.0

# =============================================================================
#  END GAME
# =============================================================================
func _end_game(win: bool) -> void:
	if not _alive: return
	_alive = false
	var grade := _calc_grade(win)
	var msg := ("✅ All rounds complete!\nGrade: %s  Score: %d  Accuracy: %.0f%%" if win
				else "💀 Game Over\nGrade: %s  Score: %d") % [grade, _score,
				_accuracy() if win else 0.0]
	_concept_text(msg)
	if has_node("/root/PlayerProfile"):
		PlayerProfile.save_chapter_result(_chapter_id, _score,
			_grade_to_stars(grade), _accuracy())
	await get_tree().create_timer(3.0).timeout
	if has_node("/root/GameRouter"):
		GameRouter.chapter_complete(_chapter_id, _score, _grade_to_stars(grade))
	else:
		get_tree().change_scene_to_file("res://scenes/world_map/WorldMap.tscn")

func _calc_grade(win: bool) -> String:
	var a := _accuracy()
	if not win:  return "C" if a >= 60 else "F"
	if a >= 95:  return "S"
	if a >= 82:  return "A"
	if a >= 68:  return "B"
	return "C"

func _grade_to_stars(g: String) -> int:
	match g:
		"S","A": return 3
		"B":     return 2
		"C":     return 1
	return 0
