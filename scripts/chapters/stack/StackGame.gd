# =============================================================================
# AlgoQuest — Chapter 2: Castle of Echoes (LIFO Stack) v3
# File: scripts/chapters/stack/StackGame.gd
#
# v3 PEDAGOGICAL IMPROVEMENTS over v2:
#  1. PEEK operation (Easy+) — PeekButton reads top without removing it;
#     clicking peek on an empty stack teaches isEmpty as a concept.
#  2. Stack UNDERFLOW teaching (Normal+) — clicking an empty column zone shows
#     the underflow error and explains the isEmpty() guard. No life lost.
#  3. Push task card now shown explicitly (was silently assumed before) — both
#     push AND pop task cards are visible so mixed-ops is fair and clear.
#  4. highlight_top always ON — removing it at higher tiers hid the core visual
#     cue without teaching anything new. Difficulty comes from other mechanics.
#  5. Code snippet panel at tier completion — bridges the game metaphor to
#     real Python syntax (push/pop/peek/isEmpty/overflow/reverse).
#  6. Real-world anchors in every concept intro — undo, call stack, browser
#     back, bracket matching, parser algorithms.
#  7. Tutorial softlock fix — step 4 handles a correct click gracefully instead
#     of hanging; tut_step is set to 5 so _pop() finishes the flow.
#  8. Expert reverse-stack algorithm challenge — mid-game task where popped
#     runes from Stack A return to staging so the player physically moves them
#     to Stack B, teaching the classic 2-stack reverse pattern.
#  9. isEmpty concept reinforced in two places: peek on empty + underflow demo.
# 10. BUG FIX: captured push_node before _staged_nd = null in _try_push().
# 11. BUG FIX: _apply_wrong() gains count_as_mistake param so teaching moments
#     (underflow demo, wrong reverse move) don't cost lives.
#
# SCENE TREE (additions marked NEW):
#   StackGame (Node2D)
#   ├── Background / Column_A / Column_B / CrownA / CrownB
#   ├── StagingArea / HeightBar_A / HeightBar_B / TutorialBlocker / GameTimer
#   └── HUD (CanvasLayer)
#       ├── ScoreLabel / ComboLabel / TimerLabel / GoalLabel / AccuracyLabel
#       ├── PeekButton   (Button)          pos=(10,114)    ← NEW
#       ├── LivesRow / HintBox/HintLabel
#       ├── TaskCard/TaskLabel / SeqBanner/SeqLabel
#       ├── FailSummary/FailLabel
#       └── CodePanel    (PanelContainer)  pos=(140,90)    ← NEW
#           └── CodeLabel (Label)
# =============================================================================

extends Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  ASSETS
# ─────────────────────────────────────────────────────────────────────────────
const PATH_BG       := "res://assets/art/map/mountain.png"
const PATH_FONT     := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_OK   := "res://assets/audio/sfx/success.ogg"
const PATH_SFX_FAIL := "res://assets/audio/sfx/fail.ogg"
const PATH_SFX_PUSH := "res://assets/audio/sfx/jump_1.ogg"
const PATH_SFX_POP  := "res://assets/audio/sfx/jump_2.ogg"
const PATH_BGM      := "res://assets/audio/music/mountain.ogg"

const RUNE_BASE := "res://assets/art/character/"

# Rune definitions
const RUNES: Array[Dictionary] = [
	{"key":"plus",     "name":"Fire",    "color":Color(1.0,0.35,0.1)},
	{"key":"minus",    "name":"Ice",     "color":Color(0.4,0.8, 1.0)},
	{"key":"multiply", "name":"Thunder", "color":Color(1.0,0.9, 0.1)},
	{"key":"divide",   "name":"Earth",   "color":Color(0.5,0.85,0.3)},
	{"key":"modulo",   "name":"Shadow",  "color":Color(0.6,0.3, 0.9)},
	{"key":"equal",    "name":"Light",   "color":Color(1.0,1.0, 0.9)},
]

# ─────────────────────────────────────────────────────────────────────────────
#  LAYOUT
# ─────────────────────────────────────────────────────────────────────────────
const COL_A_X    := 400.0
const COL_B_X    := 800.0
const BASE_Y     := 580.0
const SLOT_H     := 68.0
const RUNE_SCALE := Vector2(2.0, 2.0)
const STAGE_POS  := Vector2(640.0, 80.0)
const SNAP_DIST  := 90.0
const HIT_R      := 40.0

const COL_TOP   := CastleTheme.C_GOLD      # gold   — top item / correct feedback
const COL_PEEK  := CastleTheme.C_SAPPHIRE  # sapphire — peek highlight
const COL_WRONG := CastleTheme.C_CRIMSON   # crimson  — LIFO violation / error
const COL_WHITE := CastleTheme.C_PARCHMENT # parchment — rune default tint

# ─────────────────────────────────────────────────────────────────────────────
#  DIFFICULTY TIERS
#  CHANGED: highlight_top is now always true — the crown is the core LIFO cue
#           and should never be hidden. New keys: peek, underflow_demo,
#           reverse_challenge.
# ─────────────────────────────────────────────────────────────────────────────
const TIER_PARAMS: Array[Dictionary] = [
	# ── BEGINNER: LIFO only ──────────────────────────────────────────────────
	{
		"concept":           "LIFO",
		"max_height":        6,    "highlight_top":     true,
		"sequence_goal":     false,"mixed_ops":         false,
		"time_limit":        0.0,  "multi_stack":       false,
		"hidden_items":      false,"penalty":           0,
		"target_correct":    8,    "accuracy_target":   0.0,
		"tutorial":          true,
		"peek":              false,"underflow_demo":     false,
		"reverse_challenge": false,
	},
	# ── EASY: LIFO + height limit + PEEK ─────────────────────────────────────
	# NEW: peek=true — PeekButton appears; player learns top-read without pop.
	{
		"concept":           "HEIGHT",
		"max_height":        4,    "highlight_top":     true,
		"sequence_goal":     false,"mixed_ops":         false,
		"time_limit":        0.0,  "multi_stack":       false,
		"hidden_items":      false,"penalty":           10,
		"target_correct":    12,   "accuracy_target":   60.0,
		"tutorial":          false,
		"peek":              true, "underflow_demo":     false,
		"reverse_challenge": false,
	},
	# ── NORMAL: LIFO + height + sequence + UNDERFLOW DEMO ────────────────────
	# CHANGED: highlight_top restored to true. NEW: underflow_demo=true.
	{
		"concept":           "SEQUENCE",
		"max_height":        5,    "highlight_top":     true,
		"sequence_goal":     true, "mixed_ops":         false,
		"time_limit":        90.0, "multi_stack":       false,
		"hidden_items":      false,"penalty":           15,
		"target_correct":    15,   "accuracy_target":   65.0,
		"tutorial":          false,
		"peek":              true, "underflow_demo":     true,
		"reverse_challenge": false,
	},
	# ── HARD: all above + explicit mixed ops (push card now shown) ────────────
	# CHANGED: highlight_top restored to true.
	{
		"concept":           "MIXED_OPS",
		"max_height":        6,    "highlight_top":     true,
		"sequence_goal":     true, "mixed_ops":         true,
		"time_limit":        75.0, "multi_stack":       false,
		"hidden_items":      false,"penalty":           25,
		"target_correct":    18,   "accuracy_target":   70.0,
		"tutorial":          false,
		"peek":              true, "underflow_demo":     true,
		"reverse_challenge": false,
	},
	# ── EXPERT: all + two stacks + hidden items + REVERSE CHALLENGE ───────────
	# CHANGED: highlight_top restored to true. NEW: reverse_challenge=true.
	{
		"concept":           "EXPERT",
		"max_height":        7,    "highlight_top":     true,
		"sequence_goal":     true, "mixed_ops":         true,
		"time_limit":        55.0, "multi_stack":       true,
		"hidden_items":      true, "penalty":           40,
		"target_correct":    22,   "accuracy_target":   75.0,
		"tutorial":          false,
		"peek":              true, "underflow_demo":     true,
		"reverse_challenge": true,
	},
]

# ─────────────────────────────────────────────────────────────────────────────
#  CODE SNIPPETS — shown at tier completion to bridge game ↔ real syntax
#  NEW section.
# ─────────────────────────────────────────────────────────────────────────────
const CODE_SNIPPETS: Dictionary = {
	"LIFO":
"""# Python — LIFO stack fundamentals
stack = []

stack.append("Fire")    # push  → top is Fire
stack.append("Ice")     # push  → top is Ice

top = stack[-1]         # peek  → reads "Ice", stack UNCHANGED
                        #   ↑ reading without removing = peek

stack.pop()             # pop   → removes "Ice" (Last In, First Out)
stack.pop()             # pop   → removes "Fire"

# Stack is now empty — len(stack) == 0
""",

	"HEIGHT":
"""# Python — bounded stack with isEmpty guard

MAX_SIZE = 4
stack = []

# Always guard before pushing (overflow check):
if len(stack) < MAX_SIZE:
    stack.append(item)          # push OK
else:
    raise OverflowError("Stack is full!")

# Always guard before popping (underflow check):
if stack:                       # isEmpty → False means there IS something
    value = stack.pop()         # pop safe
else:
    raise IndexError("Stack underflow — nothing to pop!")

# Peek is always safe to guard too:
if stack:
    top = stack[-1]             # peek
""",

	"SEQUENCE":
"""# Python — LIFO means you must PLAN your push order

# Goal: pop in order  Fire → Ice → Thunder
# Push in REVERSE order so LIFO gives the right sequence:

stack = []
stack.append("Thunder")   # push first  → bottom
stack.append("Ice")       # push second
stack.append("Fire")      # push last   → top

stack.pop()   # → "Fire"     ✓  (last in, first out)
stack.pop()   # → "Ice"      ✓
stack.pop()   # → "Thunder"  ✓

# Real world: compilers use this to match brackets.
# '{' is pushed; when '}' is seen, pop and verify it matches.
""",

	"MIXED_OPS":
"""# Python — interleaved push & pop (typical real usage)

stack = []

# Task says PUSH → append
stack.append("Fire")
stack.append("Ice")

# Task says POP → pop (but ALWAYS check isEmpty first!)
while stack:                   # isEmpty guard
    item = stack.pop()
    process(item)

# Common bug — popping without the guard:
# stack.pop()  ← raises IndexError if stack is empty!

# Rule of thumb: before every pop(), ask "is the stack empty?"
""",

	"EXPERT":
"""# Python — classic 2-stack reverse algorithm

def reverse_stack(A: list) -> list:
    B = []
    while A:              # while A is not empty (isEmpty check)
        B.append(A.pop()) # pop top of A → push to B
	return B              # B holds A's items in reversed order

# Example:
A = ["Fire", "Ice", "Thunder"]   # Thunder is on top
# A (bottom→top): Fire, Ice, Thunder

B = reverse_stack(A)
# B (bottom→top): Thunder, Ice, Fire  ← reversed!

# Why it works: LIFO means B[top] = A[original bottom]
# Time complexity: O(n)  |  Space: O(n)
""",
}

# ─────────────────────────────────────────────────────────────────────────────
#  NODE REFS
# ─────────────────────────────────────────────────────────────────────────────
@onready var _bg:          Sprite2D        = $Background
@onready var _col_a:       Node2D          = $Column_A
@onready var _col_b:       Node2D          = $Column_B
@onready var _crown_a:     Node2D          = $CrownA
@onready var _crown_b:     Node2D          = $CrownB
@onready var _stage:       Node2D          = $StagingArea
@onready var _hbar_a:      ProgressBar     = $HeightBar_A
@onready var _hbar_b:      ProgressBar     = $HeightBar_B
@onready var _tut_blocker: ColorRect       = $TutorialBlocker
@onready var _game_tmr:    Timer           = $GameTimer
# HUD
@onready var _score_lbl:   Label           = $HUD/ScoreLabel
@onready var _combo_lbl:   Label           = $HUD/ComboLabel
@onready var _timer_lbl:   Label           = $HUD/TimerLabel
@onready var _goal_lbl:    Label           = $HUD/GoalLabel
@onready var _acc_lbl:     Label           = $HUD/AccuracyLabel
@onready var _lives_row:   HBoxContainer   = $HUD/LivesRow
@onready var _hint_lbl:    Label           = $HUD/HintBox/HintLabel
@onready var _hint_box:    PanelContainer  = $HUD/HintBox
@onready var _task_card:   PanelContainer  = $HUD/TaskCard
@onready var _task_lbl:    Label           = $HUD/TaskCard/TaskLabel
@onready var _seq_banner:  PanelContainer  = $HUD/SeqBanner
@onready var _seq_lbl:     Label           = $HUD/SeqBanner/SeqLabel
@onready var _fail_summary:PanelContainer  = $HUD/FailSummary
@onready var _fail_lbl:    Label           = $HUD/FailSummary/FailLabel
# NEW nodes — built procedurally in _setup_new_nodes() so the .tscn needs no changes
var _peek_btn:   Button         = null
var _code_panel: PanelContainer = null
var _code_lbl:   Label          = null

# ── A: Live stack display ──────────────────────────────────────────────────
var _stack_display_panel: PanelContainer = null
var _stack_display_lbl:   Label          = null

# ── B: Operation call flash ────────────────────────────────────────────────
var _op_flash_lbl: Label = null

# ── C: Comprehension prompts ───────────────────────────────────────────────
var _prompt_panel:        PanelContainer = null
var _prompt_question_lbl: Label          = null
var _prompt_btns:         Array          = []   # Array[Button]
var _prompt_result_lbl:   Label          = null
var _prompt_correct_idx:  int            = 0
var _prompt_active:       bool           = false
var _ops_since_prompt:    int            = 0
const PROMPT_INTERVAL := 5   # ask a comprehension question every N correct ops

# ─────────────────────────────────────────────────────────────────────────────
#  RUNTIME STATE
# ─────────────────────────────────────────────────────────────────────────────
var _p: Dictionary = {}

# Stacks — each entry: {key, name, color, node:Node2D}
var _stack_a: Array = []
var _stack_b: Array = []

# Staged rune waiting in staging area
var _staged:    Dictionary = {}
var _staged_nd: Node2D     = null

# Drag state
var _is_dragging:  bool    = false
var _drag_offset:  Vector2 = Vector2.ZERO

# Sequence goal
var _goal_seq:  Array  = []
var _goal_idx:  int    = 0

# Mixed ops task card
var _current_task: String = ""   # "push" | "pop_a" | "pop_b" | "reverse" | ""
var _push_count:   int    = 0

# NEW: Reverse challenge state (Expert tier)
var _reverse_challenge_active: bool  = false
var _reverse_source:           Array = []   # bottom-to-top snapshot of stack A

# Analytics
var _stat := {
	"correct":        0,
	"wrong_pop":      0,
	"wrong_push":     0,
	"sequence_break": 0,
	"overflow":       0,
}

var _score:       int   = 0
var _combo:       int   = 0
var _lives:       int   = 3
var _combo_decay: float = 0.0
const COMBO_TTL := 3.0

var _time_left:   float = 0.0
var _alive:       bool  = false
var _tut_step:    int   = 0
var _tut_locked:  bool  = false

# Stack chapters are 6 (Beginner) → 10 (Expert) in ChapterCompleteScreen.
# Computed from the active tier in _ready() — never hardcoded.
var _chapter_id:  int   = 6

var _pixel_font: Font = null

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font
	var tier := 0
	if has_node("/root/DifficultyManager"):
		tier = DifficultyManager.current_tier
	_p = TIER_PARAMS[clamp(tier, 0, 4)]
	# Stack chapters: 6 = Beginner, 7 = Easy, 8 = Normal, 9 = Hard, 10 = Expert
	_chapter_id = 6 + clamp(tier, 0, 4)

	_setup_bg()
	_setup_new_nodes()   # build PeekButton + CodePanel before _setup_hud reads them
	_setup_hud()
	_setup_timer()
	_setup_columns()

	_tut_blocker.visible  = false
	_task_card.visible    = false
	_seq_banner.visible   = _p["sequence_goal"]
	_fail_summary.visible = false
	_code_panel.visible   = false   # NEW
	_update_stack_display()         # A: show empty stack state on launch

	# NEW: connect peek button
	if is_instance_valid(_peek_btn):
		_peek_btn.pressed.connect(_on_peek_pressed)

	AudioManager.play_bgm(PATH_BGM)
	_alive = true
	_apply_castle_theme()   # stone + gold visual pass over all UI nodes

	if _p["tutorial"]:
		_run_tutorial()
	else:
		_show_concept_intro()

# ─────────────────────────────────────────────────────────────────────────────
#  SETUP
# ─────────────────────────────────────────────────────────────────────────────
# ─────────────────────────────────────────────────────────────────────────────
#  CASTLE THEME — applied after all nodes exist
#  Overrides StyleBoxes and font colours on both scene nodes and procedural
#  nodes so every surface shares the stone + gold palette.
# ─────────────────────────────────────────────────────────────────────────────
func _apply_castle_theme() -> void:
	# ── Scene panels (from original .tscn) ───────────────────────────────────
	_hint_box.add_theme_stylebox_override("panel",     CastleTheme.alcove_panel())
	_task_card.add_theme_stylebox_override("panel",    CastleTheme.royal_panel())
	_seq_banner.add_theme_stylebox_override("panel",   CastleTheme.scroll_panel())
	_fail_summary.add_theme_stylebox_override("panel", CastleTheme.stone_panel(CastleTheme.C_GOLD, 3))

	# ── Label colours ─────────────────────────────────────────────────────────
	for lbl: Label in [_score_lbl, _combo_lbl, _timer_lbl, _goal_lbl, _acc_lbl]:
		if is_instance_valid(lbl):
			lbl.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT)
	_hint_lbl.add_theme_color_override("font_color",  CastleTheme.C_PARCHMENT_DIM)
	_task_lbl.add_theme_color_override("font_color",  CastleTheme.C_GOLD)
	_seq_lbl.add_theme_color_override("font_color",   CastleTheme.C_PARCHMENT)
	_fail_lbl.add_theme_color_override("font_color",  CastleTheme.C_PARCHMENT)

	# ── Procedural nodes (built in _setup_new_nodes) ──────────────────────────
	if is_instance_valid(_peek_btn):
		_peek_btn.add_theme_stylebox_override("normal",  CastleTheme.btn_info_normal())
		_peek_btn.add_theme_stylebox_override("hover",   CastleTheme.btn_info_hover())
		_peek_btn.add_theme_stylebox_override("pressed", CastleTheme.btn_pressed())
		_peek_btn.add_theme_color_override("font_color",       CastleTheme.C_SAPPHIRE)
		_peek_btn.add_theme_color_override("font_hover_color", CastleTheme.C_GOLD)

	if is_instance_valid(_code_panel):
		_code_panel.add_theme_stylebox_override("panel", CastleTheme.code_panel())
	if is_instance_valid(_code_lbl):
		_code_lbl.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT_DIM)

	if is_instance_valid(_stack_display_panel):
		_stack_display_panel.add_theme_stylebox_override("panel",
			CastleTheme.stone_panel(CastleTheme.C_STONE_LIGHT, 1))
	if is_instance_valid(_stack_display_lbl):
		_stack_display_lbl.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT_DIM)

	if is_instance_valid(_op_flash_lbl):
		_op_flash_lbl.add_theme_color_override("font_color", CastleTheme.C_GOLD)

	if is_instance_valid(_prompt_panel):
		_prompt_panel.add_theme_stylebox_override("panel", CastleTheme.royal_panel())
	if is_instance_valid(_prompt_question_lbl):
		_prompt_question_lbl.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT)
	if is_instance_valid(_prompt_result_lbl):
		_prompt_result_lbl.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT)

	for btn: Button in _prompt_btns:
		if not is_instance_valid(btn): continue
		btn.add_theme_stylebox_override("normal",  CastleTheme.btn_normal())
		btn.add_theme_stylebox_override("hover",   CastleTheme.btn_hover())
		btn.add_theme_stylebox_override("pressed", CastleTheme.btn_pressed())
		btn.add_theme_color_override("font_color",       CastleTheme.C_PARCHMENT)
		btn.add_theme_color_override("font_hover_color", CastleTheme.C_GOLD)

func _setup_bg() -> void:
	if ResourceLoader.exists(PATH_BG):
		_bg.texture        = load(PATH_BG)
		_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_bg.position       = Vector2(640, 360)
		_bg.scale          = Vector2(1280.0/320.0, 720.0/128.0)
		_bg.z_index        = -10
	else:
		# Fallback: solid stone-deep background
		var rect := ColorRect.new()
		rect.color    = CastleTheme.C_STONE_DEEP
		rect.size     = Vector2(1280, 720)
		rect.position = Vector2.ZERO
		rect.z_index  = -10
		add_child(rect)

	# Dark vignette overlay — deepens atmosphere and makes UI panels pop
	var overlay := ColorRect.new()
	overlay.color    = Color(0.0, 0.0, 0.0, 0.52)
	overlay.size     = Vector2(1280, 720)
	overlay.position = Vector2.ZERO
	overlay.z_index  = -9
	add_child(overlay)

	# Horizontal stone-mortar lines at 1/3 and 2/3 height (subtle wall texture)
	for y_frac in [0.33, 0.66]:
		var mortar := ColorRect.new()
		mortar.color    = Color(0.0, 0.0, 0.0, 0.18)
		mortar.size     = Vector2(1280, 2)
		mortar.position = Vector2(0, 720 * y_frac)
		mortar.z_index  = -8
		add_child(mortar)

# ─────────────────────────────────────────────────────────────────────────────
#  NEW NODE CREATION — keeps the original .tscn untouched
# ─────────────────────────────────────────────────────────────────────────────
func _setup_new_nodes() -> void:
	var hud := $HUD as CanvasLayer

	# ── Peek Button ───────────────────────────────────────────────────────────
	_peek_btn = Button.new()
	_peek_btn.name = "PeekButton"
	_peek_btn.text = "👁  Peek Top"
	_peek_btn.visible = false
	_peek_btn.z_index = 20
	# Anchor to top-left; sit below AccuracyLabel (offset_top ~88)
	_peek_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_peek_btn.set_offset(SIDE_LEFT,   10.0)
	_peek_btn.set_offset(SIDE_TOP,   114.0)
	_peek_btn.set_offset(SIDE_RIGHT, 160.0)
	_peek_btn.set_offset(SIDE_BOTTOM,142.0)
	hud.add_child(_peek_btn)

	# ── Code Panel (container) ────────────────────────────────────────────────
	_code_panel = PanelContainer.new()
	_code_panel.name = "CodePanel"
	_code_panel.visible = false
	_code_panel.z_index = 60
	_code_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_code_panel.set_offset(SIDE_LEFT,   140.0)
	_code_panel.set_offset(SIDE_TOP,     90.0)
	_code_panel.set_offset(SIDE_RIGHT, 1140.0)
	_code_panel.set_offset(SIDE_BOTTOM, 630.0)
	hud.add_child(_code_panel)

	# ── Code Label (inside panel) ─────────────────────────────────────────────
	_code_lbl = Label.new()
	_code_lbl.name = "CodeLabel"
	_code_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_code_panel.add_child(_code_lbl)

	# ══════════════════════════════════════════════════════════════════════════
	#  A — LIVE STACK DISPLAY (left rail, below PeekButton)
	#  Shows the stack contents as a real array, updating every push/pop.
	#  Players always see both the visual column AND the data structure.
	# ══════════════════════════════════════════════════════════════════════════
	_stack_display_panel = PanelContainer.new()
	_stack_display_panel.name = "StackDisplay"
	_stack_display_panel.z_index = 15
	_stack_display_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_stack_display_panel.set_offset(SIDE_LEFT,    10.0)
	_stack_display_panel.set_offset(SIDE_TOP,    150.0)
	_stack_display_panel.set_offset(SIDE_RIGHT,  225.0)
	_stack_display_panel.set_offset(SIDE_BOTTOM, 590.0)
	hud.add_child(_stack_display_panel)

	_stack_display_lbl = Label.new()
	_stack_display_lbl.name = "StackDisplayLabel"
	_stack_display_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack_display_panel.add_child(_stack_display_lbl)

	# ══════════════════════════════════════════════════════════════════════════
	#  B — OPERATION CALL FLASH (centre screen)
	#  Shows "stack.push('Fire')" or "stack.pop() → 'Ice'" for ~1.4 s
	#  every time the player performs an operation.
	# ══════════════════════════════════════════════════════════════════════════
	_op_flash_lbl = Label.new()
	_op_flash_lbl.name = "OpFlashLabel"
	_op_flash_lbl.modulate.a = 0.0          # invisible until triggered
	_op_flash_lbl.z_index = 55
	_op_flash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_op_flash_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_op_flash_lbl.set_offset(SIDE_LEFT,   330.0)
	_op_flash_lbl.set_offset(SIDE_TOP,    205.0)
	_op_flash_lbl.set_offset(SIDE_RIGHT,  950.0)
	_op_flash_lbl.set_offset(SIDE_BOTTOM, 255.0)
	hud.add_child(_op_flash_lbl)

	# ══════════════════════════════════════════════════════════════════════════
	#  C — COMPREHENSION PROMPT OVERLAY
	#  Pauses gameplay every PROMPT_INTERVAL ops and asks "What will pop()
	#  return?" — forces mental modelling rather than purely reactive play.
	# ══════════════════════════════════════════════════════════════════════════
	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "ComprehensionPrompt"
	_prompt_panel.visible = false
	_prompt_panel.z_index = 70
	_prompt_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_prompt_panel.set_offset(SIDE_LEFT,   200.0)
	_prompt_panel.set_offset(SIDE_TOP,    180.0)
	_prompt_panel.set_offset(SIDE_RIGHT, 1080.0)
	_prompt_panel.set_offset(SIDE_BOTTOM, 520.0)
	hud.add_child(_prompt_panel)

	var prompt_vbox := VBoxContainer.new()
	prompt_vbox.add_theme_constant_override("separation", 14)
	_prompt_panel.add_child(prompt_vbox)

	_prompt_question_lbl = Label.new()
	_prompt_question_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_question_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_vbox.add_child(_prompt_question_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 20)
	prompt_vbox.add_child(btn_row)

	_prompt_btns.clear()
	for i in range(3):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(200, 48)
		btn.pressed.connect(_on_prompt_btn.bind(i))
		_prompt_btns.append(btn)
		btn_row.add_child(btn)

	_prompt_result_lbl = Label.new()
	_prompt_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prompt_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_result_lbl.visible = false
	prompt_vbox.add_child(_prompt_result_lbl)

func _setup_hud() -> void:
	for lbl: Label in [_score_lbl, _combo_lbl, _timer_lbl, _goal_lbl,
						_acc_lbl, _hint_lbl, _task_lbl, _seq_lbl, _fail_lbl,
						_code_lbl, _stack_display_lbl, _op_flash_lbl,
						_prompt_question_lbl, _prompt_result_lbl]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", _pixel_font)
			lbl.add_theme_font_size_override("font_size", 16)

	for btn: Button in _prompt_btns:
		if is_instance_valid(btn):
			btn.add_theme_font_override("font", _pixel_font)
			btn.add_theme_font_size_override("font_size", 15)

	# Code label: smaller for multiline snippet
	if is_instance_valid(_code_lbl):
		_code_lbl.add_theme_font_size_override("font_size", 14)
	# Stack display: compact monospace-style
	if is_instance_valid(_stack_display_lbl):
		_stack_display_lbl.add_theme_font_size_override("font_size", 14)
	# Op flash: large so it reads at a glance
	if is_instance_valid(_op_flash_lbl):
		_op_flash_lbl.add_theme_font_size_override("font_size", 22)
	# Prompt question: prominent
	if is_instance_valid(_prompt_question_lbl):
		_prompt_question_lbl.add_theme_font_size_override("font_size", 18)

	_score_lbl.text  = "Score: 0"
	_combo_lbl.text  = ""
	_acc_lbl.text    = "Accuracy: -"
	_goal_lbl.text   = "Goal: %d correct" % _p["target_correct"]
	_timer_lbl.visible = _p["time_limit"] > 0
	if _p["time_limit"] > 0:
		_time_left = _p["time_limit"]
		_timer_lbl.text = "⏱ %d" % int(_time_left)
	_refresh_lives()

	# NEW: peek button setup
	if is_instance_valid(_peek_btn):
		_peek_btn.add_theme_font_override("font", _pixel_font)
		_peek_btn.add_theme_font_size_override("font_size", 14)
		_peek_btn.visible = _p.get("peek", false)

func _setup_timer() -> void:
	if _p["time_limit"] > 0:
		_game_tmr.wait_time = 1.0; _game_tmr.one_shot = false
		_game_tmr.timeout.connect(_tick_clock); _game_tmr.start()

func _setup_columns() -> void:
	_col_b.visible   = _p["multi_stack"]
	_crown_b.visible = _p["multi_stack"]
	_hbar_b.visible  = _p["multi_stack"]

	_hbar_a.max_value = _p["max_height"]; _hbar_a.value = 0
	_hbar_b.max_value = _p["max_height"]; _hbar_b.value = 0

	# Height bar castle styling
	for bar in ([_hbar_a, _hbar_b] if _p["multi_stack"] else [_hbar_a]):
		(bar as ProgressBar).add_theme_stylebox_override("background", CastleTheme.progress_bg())
		(bar as ProgressBar).add_theme_stylebox_override("fill",       CastleTheme.progress_fill())

	# Stone column shaft behind each stack (drawn before items so z_index stays clean)
	_add_column_shaft(COL_A_X)
	if _p["multi_stack"]: _add_column_shaft(COL_B_X)

	_bob_crown(_crown_a)
	if _p["multi_stack"]: _bob_crown(_crown_b)

# Draws a carved-stone tower shaft behind a stack column.
func _add_column_shaft(col_x: float) -> void:
	var shaft_h: float = _p["max_height"] * SLOT_H + 60.0
	var shaft_x: float = col_x - 46.0
	var shaft_y: float = BASE_Y - shaft_h + 24.0

	# Dark stone background
	var bg := ColorRect.new()
	bg.color    = Color(0.05, 0.04, 0.07)
	bg.size     = Vector2(92.0, shaft_h)
	bg.position = Vector2(shaft_x, shaft_y)
	bg.z_index  = -2
	add_child(bg)

	# Left border — light stone
	for x_off: float in [0.0, 89.0]:
		var edge := ColorRect.new()
		edge.color    = CastleTheme.C_STONE_LIGHT
		edge.size     = Vector2(3.0, shaft_h)
		edge.position = Vector2(shaft_x + x_off, shaft_y)
		edge.z_index  = -1
		add_child(edge)

	# Gold battlement cap across the top
	var cap := ColorRect.new()
	cap.color    = CastleTheme.C_GOLD
	cap.size     = Vector2(92.0, 3.0)
	cap.position = Vector2(shaft_x, shaft_y)
	cap.z_index  = -1
	add_child(cap)

	# Torch-bracket dot (small amber rect top-left of shaft)
	var torch := ColorRect.new()
	torch.color    = CastleTheme.C_TORCH
	torch.size     = Vector2(6.0, 10.0)
	torch.position = Vector2(shaft_x + 8.0, shaft_y + 6.0)
	torch.z_index  = -1
	add_child(torch)

func _bob_crown(crown: Node2D) -> void:
	if not is_instance_valid(crown): return
	crown.visible = false
	var tw := crown.create_tween().set_loops()
	tw.tween_property(crown,"position:y", crown.position.y - 10, 0.5)
	tw.tween_property(crown,"position:y", crown.position.y, 0.5)

# ─────────────────────────────────────────────────────────────────────────────
#  CONCEPT INTRO (Easy+)
#  CHANGED: each message now includes a real-world anchor so players understand
#  WHY the concept matters in actual software.
# ─────────────────────────────────────────────────────────────────────────────
func _show_concept_intro() -> void:
	# CHANGED: real-world anchors added to every message
	var msgs := {
		"LIFO":
"""LIFO: Last In, First Out.
Only the TOP rune can be pushed or popped.

💡 Real world: Ctrl+Z (Undo), the browser Back button,
and your CPU's function call stack all use LIFO!

[Click anywhere to begin]""",

		"HEIGHT":
"""NEW: Height limit + PEEK!
The stack has a cap — pop before pushing more.
The 👁 Peek button reads the top WITHOUT removing it.

💡 Real world: A stack of dishes — you can look at the top
plate (peek) before deciding whether to take it.

[Click anywhere to begin]""",

		"SEQUENCE":
"""NEW: Pop runes in the REQUIRED ORDER shown on the banner.
Plan your pushes carefully — LIFO forces reverse-order thinking!
Also: try clicking an EMPTY column to see what underflow means.

💡 Real world: Compilers match brackets { } using a stack.
Each open bracket is pushed; '}' pops and checks the match.

[Click anywhere to begin]""",

		"MIXED_OPS":
"""NEW: Task cards now tell you to PUSH or POP.
Both instructions are shown clearly — no more guessing!

💡 Real world: Each function call pushes a stack frame.
The return statement pops it. Push & pop must stay balanced.

[Click anywhere to begin]""",

		"EXPERT":
"""Expert: Two stacks + hidden items + Reverse Challenge!
Mid-game you will receive an algorithm task:
move ALL runes from Stack A to Stack B.
This teaches the classic 2-stack reverse pattern.

💡 Real world: Parser algorithms, undo/redo systems, and
DFS graph traversal all use multi-stack techniques.

[Click anywhere to begin]""",
	}

	var concept: String = _p["concept"]
	if concept not in msgs: return

	_tut_locked = true
	_tut_blocker.visible  = true
	_tut_blocker.modulate = Color(0,0,0,0.55)
	_hint_lbl.text = msgs[concept]
	_hint_box.visible = true

	await _wait_for_click()
	_tut_locked = false
	_tut_blocker.visible = false
	_hint_lbl.text = _idle_hint()
	_spawn_staged_rune()

func _idle_hint() -> String:
	match _p["concept"]:
		"LIFO":      return "Drag the rune → column to PUSH.\nClick the TOP rune to POP."
		"HEIGHT":    return "Stack is limited! Pop before it's full.\nUse 👁 Peek to check the top first."
		"SEQUENCE":  return "Check the banner — pop in the shown order.\nClick an empty column to learn about underflow."
		"MIXED_OPS": return "Follow the task card. Push card = drag to stack. Pop card = click top rune."
		_:           return ""

# ─────────────────────────────────────────────────────────────────────────────
#  TUTORIAL — enforced 4-step (Beginner)
#  CHANGED: step 4 softlock fixed — if player correctly pops at step 4
#  (instead of clicking the bottom), the tutorial advances gracefully.
# ─────────────────────────────────────────────────────────────────────────────
func _run_tutorial() -> void:
	_tut_step = 1; _tut_locked = true
	_tut_blocker.visible  = true
	_tut_blocker.modulate = Color(0,0,0,0.5)

	_hint_lbl.text = """Welcome to the Stack!

LIFO = Last In, First Out.
The LAST rune pushed is the FIRST you can pop.

[Click to spawn your first rune]"""
	await _wait_for_click()

	_tut_blocker.visible = false
	_tut_locked = false
	_spawn_staged_rune()
	_hint_lbl.text = "A rune appeared!\nDrag it onto the column to PUSH it."
	_tut_step = 2

func _advance_tutorial(step: int) -> void:
	match step:
		2:
			_tut_step   = 3
			_hint_lbl.text = "Pushed! Notice the CROWN — it marks the TOP.\n\nNow push 2 more runes."

		3:
			if _stack_a.size() < 2: return
			_tut_step   = 4
			_tut_blocker.visible  = true
			_tut_blocker.modulate = Color(0,0,0,0.5)
			_hint_lbl.text = "Two runes in the stack!\n\nNow — try clicking the BOTTOM rune (lower one).\nSee what happens."
			_tut_blocker.visible = false
			_tut_step = 4

		4:
			# Player clicked non-top (expected path for the tutorial demo)
			_tut_step   = 5
			_tut_locked = true
			_tut_blocker.visible  = true
			_tut_blocker.modulate = Color(0,0,0,0.5)
			_hint_lbl.text = """⚠ You can't pop the bottom!

LIFO means only the TOP rune is accessible.
You CANNOT skip or reach below the top — ever.

[Click to continue]"""
			await _wait_for_click()
			_tut_blocker.visible = false
			_hint_lbl.text = "Now click the TOP rune (with the crown) to POP it."
			_tut_locked = false; _tut_step = 5

		5:
			# Player popped top correctly — tutorial done
			_tut_step = -1; _tut_locked = false
			_hint_lbl.text = "Perfect! That's LIFO.\nKeep pushing and popping!"
			await get_tree().create_timer(2.5).timeout
			_hint_lbl.text = _idle_hint()

# ─────────────────────────────────────────────────────────────────────────────
#  SPAWN STAGED RUNE
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_staged_rune() -> void:
	if not _alive: return
	var rdef: Dictionary = RUNES[randi() % RUNES.size()]
	var sprite := Sprite2D.new()
	var tpath: String = RUNE_BASE + (rdef["key"] as String) + ".png"

	if ResourceLoader.exists(tpath):
		sprite.texture = load(tpath)
	else:
		var cr := ColorRect.new(); cr.size = Vector2(32,32); cr.position = Vector2(-16,-16)
		cr.color = rdef["color"]; sprite.add_child(cr)

	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale   = RUNE_SCALE
	sprite.modulate = rdef["color"]
	sprite.z_index = 20
	add_child(sprite)
	sprite.global_position = STAGE_POS

	var lbl := Label.new()
	lbl.text = rdef["name"]
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.position = Vector2(-20, -32)
	sprite.add_child(lbl)

	sprite.scale = RUNE_SCALE * 0.1
	var tw := sprite.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", RUNE_SCALE, 0.22)

	_staged    = rdef.duplicate()
	_staged_nd = sprite

	if _p["mixed_ops"]: _issue_task_card()

# ─────────────────────────────────────────────────────────────────────────────
#  MIXED OPS — TASK CARD SYSTEM
#  CHANGED: push task card is now also shown explicitly. Previously "push" was
#  the silent default; players could be penalized for popping without ever
#  seeing a push instruction. Both paths now display a card.
# ─────────────────────────────────────────────────────────────────────────────
func _issue_task_card() -> void:
	_push_count += 1
	if _push_count % 3 == 0 and (not _stack_a.is_empty() or not _stack_b.is_empty()):
		var which := "a" if not _stack_a.is_empty() else "b"
		_current_task = "pop_%s" % which
		_show_task_card("⚠ POP the TOP rune now!\n(Stack %s)" % which.to_upper())
	else:
		_current_task = "push"
		# CHANGED: push card now shown — was silent before
		_show_task_card("▶ PUSH a rune!\nDrag the staged rune onto a column.")

func _show_task_card(text: String) -> void:
	_task_card.visible = true
	_task_lbl.text     = text
	var tw := _task_card.create_tween()
	tw.tween_property(_task_card, "modulate", Color(1,1,0), 0.1)
	tw.tween_property(_task_card, "modulate", Color.WHITE, 0.4)

func _dismiss_task_card() -> void:
	_task_card.visible = false
	_current_task      = ""

# ─────────────────────────────────────────────────────────────────────────────
#  PROCESS — combo decay
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _alive: return
	if _combo > 0:
		_combo_decay -= delta
		if _combo_decay <= 0.0: _combo = 0; _combo_lbl.text = ""

# ─────────────────────────────────────────────────────────────────────────────
#  INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not _alive or _tut_locked or _prompt_active: return

	if event is InputEventMouseButton:
		var e := event as InputEventMouseButton
		if e.button_index != MOUSE_BUTTON_LEFT: return
		if e.pressed:
			_on_press(e.position)
		elif _is_dragging:
			_is_dragging = false
			if _staged_nd: _staged_nd.z_index = 20
			_try_push(e.position)

	elif event is InputEventMouseMotion and _is_dragging and _staged_nd != null:
		_staged_nd.global_position = event.position + _drag_offset

func _on_press(pos: Vector2) -> void:
	# Start dragging staged rune
	if _staged_nd != null and _staged_nd.global_position.distance_to(pos) < HIT_R:
		if _current_task.begins_with("pop"):
			_show_hint("Task says POP first!\nClick the top rune to pop it.")
			return
		# _current_task == "reverse" falls through to normal drag — correct,
		# the player just needs to drag the staged rune to Stack B.
		_is_dragging = true
		_drag_offset = _staged_nd.global_position - pos
		_staged_nd.z_index = 50
		return

	# Click top of stack A → POP
	if _can_pop(_stack_a) and _top_nd(_stack_a).global_position.distance_to(pos) < HIT_R:
		_pop(_stack_a, "a"); return

	# Click top of stack B → POP
	if _p["multi_stack"] and _can_pop(_stack_b) and \
			_top_nd(_stack_b).global_position.distance_to(pos) < HIT_R:
		_pop(_stack_b, "b"); return

	# NEW: Underflow demo — clicking near an empty column (Normal+)
	_check_underflow_click(pos)

	# LIFO violation — clicked a non-top rune
	_check_non_top_click(pos)

# ─────────────────────────────────────────────────────────────────────────────
#  PUSH
#  CHANGED: captured push_node before _staged_nd = null to fix the bug where
#  _apply_correct() always received null (dead-code condition).
# ─────────────────────────────────────────────────────────────────────────────
func _try_push(drop_pos: Vector2) -> void:
	if _staged_nd == null: return

	var dist_a := drop_pos.distance_to(_col_top_pos(_stack_a, COL_A_X))
	var dist_b := INF
	if _p["multi_stack"]:
		dist_b = drop_pos.distance_to(_col_top_pos(_stack_b, COL_B_X))

	var target_stack: Array; var col_x: float; var col_id: String
	if dist_a <= dist_b and dist_a < SNAP_DIST:
		target_stack = _stack_a; col_x = COL_A_X; col_id = "a"
	elif dist_b < SNAP_DIST:
		target_stack = _stack_b; col_x = COL_B_X; col_id = "b"
	else:
		_return_staged_to_stage()
		_show_hint("Drag the rune closer to the column top!")
		return

	# NEW: Reverse challenge — must push only to Stack B
	if _reverse_challenge_active and col_id == "a":
		_show_teaching_moment(
			"⚠ Push to Stack B!\nDuring the Reverse Challenge, A → B only.")
		_return_staged_to_stage()
		return

	# Height limit check
	if target_stack.size() >= _p["max_height"]:
		_stat["overflow"] += 1
		_apply_wrong(_staged_nd, _p["penalty"],
			"Stack is full! (%d/%d)\nPop a rune first." % [
				target_stack.size(), _p["max_height"]])
		_return_staged_to_stage()
		return

	# Mixed ops: pushing when task says pop
	if _current_task.begins_with("pop"):
		# FIX 6: increment wrong_push (was never incremented before)
		_stat["wrong_push"] += 1
		_apply_wrong(_staged_nd, _p["penalty"],
			"Task says POP first!\nFollow the task card.")
		_return_staged_to_stage()
		return

	# ── VALID PUSH ────────────────────────────────────────────────────────────
	var dest := _col_top_pos(target_stack, col_x)
	_staged_nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)\
		.tween_property(_staged_nd, "global_position", dest, 0.18)

	var entry := _staged.duplicate()
	entry["node"] = _staged_nd

	# CHANGED: capture node before nulling _staged_nd (bug fix)
	var push_node: Node2D = _staged_nd
	target_stack.append(entry)
	_staged_nd = null

	_apply_correct(push_node, 10)
	AudioManager.play_sfx(PATH_SFX_PUSH)
	# B: show the actual method call so the player connects action → code
	_flash_op_call('stack.push("%s")' % entry["name"], COL_TOP)
	_ops_since_prompt += 1

	_update_stack_visuals(target_stack, col_x, col_id)
	_dismiss_task_card()

	# Sequence goal: generate after 3+ items (Normal+)
	if _p["sequence_goal"] and _goal_seq.is_empty() and target_stack.size() >= 3:
		_generate_goal(target_stack)

	# Tutorial integration
	if _tut_step == 2: _advance_tutorial(2)
	elif _tut_step == 3: _advance_tutorial(3)

	# FIX 1: Trigger reverse challenge after a qualifying push to Stack A.
	# Must happen BEFORE the reverse-active guard below so the first push
	# that satisfies the conditions starts the challenge correctly.
	_maybe_trigger_reverse_challenge()

	# FIX 2: Pushed to B during challenge — check if it is complete.
	if _reverse_challenge_active and col_id == "b":
		_check_reverse_complete()
		# Only spawn a new rune if the challenge just finished.
		if not _reverse_challenge_active:
			await get_tree().create_timer(0.3).timeout
			_spawn_staged_rune()
		# else: player must keep popping from A → no new rune until done.
		return

	# FIX 2 (continued): While challenge is active and we pushed to A
	# (which is blocked above, so this is a safety net), do not spawn.
	if _reverse_challenge_active:
		return

	# C: comprehension prompt fires before the next rune appears
	await _maybe_show_comprehension_prompt()

	await get_tree().create_timer(0.3).timeout
	_spawn_staged_rune()

func _return_staged_to_stage() -> void:
	if _staged_nd == null: return
	_staged_nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
		.tween_property(_staged_nd, "global_position", STAGE_POS, 0.3)

# ─────────────────────────────────────────────────────────────────────────────
#  POP
#  CHANGED: tutorial step 4 softlock fix — if the player correctly pops the
#  top at tut_step 4 (instead of clicking the non-top first), we advance them
#  to step 5 with a friendly note rather than hanging indefinitely.
#
#  NEW: Reverse challenge — popped rune from Stack A is re-staged instead of
#  destroyed, so the player can physically drag it to Stack B.
# ─────────────────────────────────────────────────────────────────────────────
func _pop(stack: Array, col_id: String) -> void:
	if stack.is_empty(): return
	var entry := stack.back() as Dictionary
	var nd    := entry["node"] as Node2D

	# Mixed ops: pop when task says push
	if _current_task == "push" and _p["mixed_ops"]:
		_stat["wrong_pop"] += 1
		_apply_wrong(nd, _p["penalty"], "Task says PUSH!\nRead the task card.")
		return

	# NEW: Reverse challenge — must pop from A, not B
	if _reverse_challenge_active and col_id == "b":
		_show_teaching_moment(
			"Pop from Stack A!\nThe challenge moves A → B.", nd)
		return

	# Sequence goal validation (Normal+)
	if _p["sequence_goal"] and not _goal_seq.is_empty():
		var expected: String = _goal_seq[_goal_idx]
		if entry["name"] != expected:
			_stat["sequence_break"] += 1
			_apply_wrong(nd, _p["penalty"],
				"Wrong pop order!\nExpected: %s\nYou popped: %s\n\nLIFO requires planning your pushes." % [
					expected, entry["name"]])
			_update_seq_banner()
			return
		_goal_idx += 1
		if _goal_idx >= _goal_seq.size():
			_goal_seq.clear(); _goal_idx = 0
			_seq_banner.visible = false
			_show_hint("✓ Sequence complete! Next sequence coming...")
			await get_tree().create_timer(1.2).timeout
			_seq_banner.visible = _p["sequence_goal"]

	# ── VALID POP ─────────────────────────────────────────────────────────────
	stack.pop_back()
	_apply_correct(nd, 15)
	AudioManager.play_sfx(PATH_SFX_POP)
	# B: show the actual method call with the returned value
	_flash_op_call('stack.pop()  →  "%s"' % entry["name"], COL_PEEK)
	_ops_since_prompt += 1

	var col_x := COL_A_X if col_id == "a" else COL_B_X
	_update_stack_visuals(stack, col_x, col_id)

	# FIX 3: Only dismiss the task card if we are NOT in the middle of a
	# reverse challenge — otherwise we clear _current_task = "reverse" and
	# the subsequent push guard in _try_push() stops working.
	if not _reverse_challenge_active:
		_dismiss_task_card()

	# CHANGED: tutorial step 4 softlock fix
	# If player pops correctly at step 4 (skipped the bottom-click demo),
	# advance to 5 immediately so the flow doesn't hang.
	if _tut_step == 4:
		_tut_step = 5
		_hint_lbl.text = "Good — you popped the top correctly!\n(Try clicking a lower rune next time to see the LIFO block.)"

	# NEW: Reverse challenge — instead of destroying the rune, re-stage it
	if _reverse_challenge_active and col_id == "a":
		_staged    = entry.duplicate()
		_staged_nd = nd
		nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)\
			.tween_property(nd, "global_position", STAGE_POS, 0.3)
		_show_hint("Rune moved to staging!\nNow drag it to Stack B to continue the reverse.")
		_show_task_card("🔄 Drag '%s' to Stack B →" % entry["name"])
		_current_task = "reverse"
		if _tut_step == 5: _advance_tutorial(5)
		return

	# Normal fly-off and destroy
	var tw := nd.create_tween()
	tw.tween_property(nd, "global_position", nd.global_position + Vector2(0,-80), 0.25)
	tw.parallel().tween_property(nd, "modulate:a", 0.0, 0.25)
	tw.tween_callback(nd.queue_free)

	if _tut_step == 5: _advance_tutorial(5)

# ─────────────────────────────────────────────────────────────────────────────
#  NON-TOP CLICK — LIFO violation
# ─────────────────────────────────────────────────────────────────────────────
func _check_non_top_click(pos: Vector2) -> void:
	for pair in [[_stack_a,"a"],[_stack_b,"b"]]:
		var stack: Array = pair[0]; var col_id: String = pair[1]
		for i in range(stack.size() - 1):
			var nd := stack[i]["node"] as Node2D
			if is_instance_valid(nd) and nd.global_position.distance_to(pos) < HIT_R:
				_stat["wrong_pop"] += 1
				_apply_wrong(nd, _p["penalty"],
					"LIFO Violation!\nOnly the TOP rune can be popped.\n(You clicked position %d from bottom)" % (i+1))
				if _can_pop(stack):
					_pulse(_top_nd(stack), COL_TOP)
				if _tut_step == 4: _advance_tutorial(4)
				return

# ─────────────────────────────────────────────────────────────────────────────
#  NEW: UNDERFLOW DEMO — clicking near an empty column (Normal+)
#  Teaches the isEmpty() guard without costing a life.
# ─────────────────────────────────────────────────────────────────────────────
func _check_underflow_click(pos: Vector2) -> void:
	if not _p.get("underflow_demo", false): return
	var cols := [[COL_A_X, _stack_a, "Stack A"]]
	if _p["multi_stack"]:
		cols.append([COL_B_X, _stack_b, "Stack B"])

	for trio in cols:
		var col_x:  float  = trio[0]
		var stack:  Array  = trio[1]
		var label:  String = trio[2]
		# Player clicked within the column's horizontal zone and below the staging area
		if stack.is_empty() and abs(pos.x - col_x) < 70.0 and pos.y > 200.0:
			_show_teaching_moment(
				"⚠ Stack Underflow!\n%s is empty — there is nothing to pop.\n\nAlways check isEmpty() before calling pop():\n  if stack:  →  stack.pop()" % label)
			return

# ─────────────────────────────────────────────────────────────────────────────
#  SEQUENCE GOAL
# ─────────────────────────────────────────────────────────────────────────────
func _generate_goal(stack: Array) -> void:
	_goal_seq.clear(); _goal_idx = 0
	var count := mini(stack.size(), 3)
	for i in range(stack.size() - 1, stack.size() - 1 - count, -1):
		_goal_seq.append(stack[i]["name"])
	_seq_banner.visible = true
	_update_seq_banner()
	_show_task_card("NEW SEQUENCE!\nPop in order: %s" % " → ".join(_goal_seq))

func _update_seq_banner() -> void:
	if _goal_seq.is_empty():
		_seq_lbl.text = "No active sequence"
		return
	var parts: Array = []
	for i in range(_goal_seq.size()):
		if i < _goal_idx:
			parts.append("✓ %s" % _goal_seq[i])
		elif i == _goal_idx:
			parts.append("▶ %s ◀" % _goal_seq[i])
		else:
			parts.append("  %s" % _goal_seq[i])
	_seq_lbl.text = "Sequence: " + " → ".join(parts)

# ─────────────────────────────────────────────────────────────────────────────
#  NEW: PEEK OPERATION (Easy+)
#  Reads the top rune without removing it. If the stack is empty, teaches
#  the isEmpty() concept instead.
# ─────────────────────────────────────────────────────────────────────────────
func _on_peek_pressed() -> void:
	if not _alive or _tut_locked: return

	# Prefer stack A; fall back to B
	var stack: Array = _stack_a if not _stack_a.is_empty() else _stack_b

	if stack.is_empty():
		# NEW: isEmpty teaching moment
		_show_hint(
			"👁 Peek on empty stack!\nstack is empty → isEmpty() returns True\nThere is nothing to peek at — call isEmpty() before peek!")
		AudioManager.play_sfx(PATH_SFX_FAIL)
		return

	var top := stack.back() as Dictionary
	var nd  := top["node"] as Node2D

	# Visual feedback: cyan pulse (distinct from green=correct, red=wrong)
	_pulse(nd, COL_PEEK)
	_float(nd, "👁 %s" % top["name"], COL_PEEK)
	# B: show the peek syntax as a code call
	_flash_op_call('stack[-1]  →  "%s"' % top["name"], COL_PEEK)

	_show_hint(
		"Peek → '%s' is on top.\nstack[-1] reads the top WITHOUT removing it.\nThe stack is unchanged: size = %d" % [
			top["name"], stack.size()])
	_log("peek", 0)

# ─────────────────────────────────────────────────────────────────────────────
#  A — LIVE STACK DISPLAY
#  Called after every push/pop to keep the text panel in sync.
#  Shows the stack as a Python-style list so the player always sees the actual
#  data structure alongside the visual column.
# ─────────────────────────────────────────────────────────────────────────────
func _update_stack_display() -> void:
	if not is_instance_valid(_stack_display_lbl): return

	# Build the array representation for Stack A
	var names_a: Array = []
	for entry in _stack_a:
		names_a.append('"%s"' % entry["name"])

	var display := "── Stack A ──\n"
	if names_a.is_empty():
		display += "stack = []  (empty)\nisEmpty() → True"
	else:
		# Show top → bottom so the top is always at the top of the text panel
		var lines: Array = []
		for i in range(names_a.size() - 1, -1, -1):
			var suffix := "  ← top" if i == names_a.size() - 1 else ""
			# In expert mode, hide items below top 2 (mirrors hidden_items rule)
			if _p["hidden_items"] and (names_a.size() - 1 - i) >= 2:
				lines.append("  ???%s" % suffix)
			else:
				lines.append("  %s%s" % [names_a[i], suffix])
		display += "stack = [\n" + "\n".join(lines) + "\n]\n"
		display += "size = %d / %d" % [_stack_a.size(), _p["max_height"]]
		if _stack_a.size() >= _p["max_height"]:
			display += "  ⚠ FULL"

	# In expert mode, also show Stack B below
	if _p["multi_stack"]:
		var names_b: Array = []
		for entry in _stack_b:
			names_b.append('"%s"' % entry["name"])
		display += "\n\n── Stack B ──\n"
		if names_b.is_empty():
			display += "stack = []  (empty)"
		else:
			var lines_b: Array = []
			for i in range(names_b.size() - 1, -1, -1):
				var suffix := "  ← top" if i == names_b.size() - 1 else ""
				lines_b.append("  %s%s" % [names_b[i], suffix])
			display += "stack = [\n" + "\n".join(lines_b) + "\n]"

	_stack_display_lbl.text = display

# ─────────────────────────────────────────────────────────────────────────────
#  B — OPERATION CALL FLASH
#  Shows the Python method call for every push, pop, and peek action.
#  The label fades in quickly and out slowly so it's readable but not blocking.
# ─────────────────────────────────────────────────────────────────────────────
func _flash_op_call(text: String, color: Color) -> void:
	if not is_instance_valid(_op_flash_lbl): return
	_op_flash_lbl.text = text
	_op_flash_lbl.add_theme_color_override("font_color", color)
	# Kill any running tween and restart
	_op_flash_lbl.modulate.a = 0.0
	var tw := _op_flash_lbl.create_tween()
	tw.tween_property(_op_flash_lbl, "modulate:a", 1.0, 0.12)
	tw.tween_interval(0.9)
	tw.tween_property(_op_flash_lbl, "modulate:a", 0.0, 0.4)

# ─────────────────────────────────────────────────────────────────────────────
#  C — COMPREHENSION PROMPTS
#  Every PROMPT_INTERVAL correct ops, pause and ask "What will pop() return?"
#  with three answer choices. No life penalty — purely for understanding.
#  The player must think about the stack's current state rather than just
#  reacting to visual cues.
# ─────────────────────────────────────────────────────────────────────────────
func _maybe_show_comprehension_prompt() -> void:
	# Only trigger at the interval, with 2+ items, outside tutorial/challenge
	if _ops_since_prompt < PROMPT_INTERVAL: return
	if _stack_a.size() < 2: return
	if _tut_step > 0: return
	if _reverse_challenge_active: return
	_ops_since_prompt = 0
	await _show_comprehension_prompt()

func _show_comprehension_prompt() -> void:
	if not is_instance_valid(_prompt_panel): return
	_prompt_active = true

	# The correct answer is always the current top of Stack A
	var correct_name: String = _stack_a.back()["name"]

	# Build a pool of wrong answers from other rune names
	var wrong_pool: Array = []
	for rdef in RUNES:
		if rdef["name"] != correct_name:
			wrong_pool.append(rdef["name"])
	wrong_pool.shuffle()

	# Place correct answer at a random button index
	_prompt_correct_idx = randi() % 3
	var wrong_idx := 0
	for i in range(3):
		var btn: Button = _prompt_btns[i]
		if i == _prompt_correct_idx:
			btn.text = correct_name
		else:
			btn.text = wrong_pool[wrong_idx]
			wrong_idx += 1
		btn.disabled = false
		btn.modulate  = Color.WHITE

	# Show stack state in the question so it's a reasoning task, not a guess
	var stack_preview: Array = []
	for entry in _stack_a:
		stack_preview.append(entry["name"])

	_prompt_question_lbl.text = (
		"⏸  Quick check!\n\n"
		+ "stack = %s\n\n" % str(stack_preview)
		+ "What will  stack.pop()  return?"
	)
	_prompt_result_lbl.visible = false
	_prompt_panel.visible      = true

func _on_prompt_btn(idx: int) -> void:
	if not _prompt_active: return

	var correct_name: String = _stack_a.back()["name"] if not _stack_a.is_empty() else "?"

	if idx == _prompt_correct_idx:
		# Correct — explain WHY with LIFO reasoning
		_prompt_result_lbl.add_theme_color_override("font_color", COL_TOP)
		_prompt_result_lbl.text = (
			"✓ Correct!  pop() returns \"%s\".\n\n"
			% correct_name
			+ "LIFO: \"%s\" was pushed LAST, so it leaves FIRST.\n"
			% correct_name
			+ "stack[-1] always gives the most recently added item."
		)
		AudioManager.play_sfx(PATH_SFX_OK)
	else:
		# Wrong — show correct answer and explain
		var chosen_name: String = (_prompt_btns[idx] as Button).text
		_prompt_result_lbl.add_theme_color_override("font_color", COL_WRONG)
		_prompt_result_lbl.text = (
			"✗  \"%s\" is not on top.\n\n" % chosen_name
			+ "pop() returns \"%s\" — it was pushed LAST.\n" % correct_name
			+ "Rule: the LAST item pushed is ALWAYS the first to leave (LIFO)."
		)
		AudioManager.play_sfx(PATH_SFX_FAIL)

	# Disable buttons, show result, then resume after a read delay
	for btn: Button in _prompt_btns:
		(btn as Button).disabled = true
	_prompt_result_lbl.visible = true

	await get_tree().create_timer(2.8).timeout
	_prompt_panel.visible = false
	_prompt_active        = false

# ─────────────────────────────────────────────────────────────────────────────
#  NEW: REVERSE CHALLENGE (Expert tier)
#  Mid-game: player moves all runes from A to B one by one.
#  Popped runes return to staging; player must drag each to B.
#  On completion, B holds A's original contents in reversed order.
# ─────────────────────────────────────────────────────────────────────────────
func _start_reverse_challenge() -> void:
	if _reverse_challenge_active or _stack_a.is_empty(): return
	_reverse_challenge_active = true

	# Snapshot A's current order (bottom to top)
	_reverse_source.clear()
	for entry in _stack_a:
		_reverse_source.append(entry["name"])

	_current_task = "reverse"
	_show_task_card(
		"🔄 ALGORITHM CHALLENGE!\nMove ALL runes: Stack A → Stack B\n(Pop A, then push each rune to B)")
	_show_hint(
		"This teaches the 2-stack reverse pattern!\nPop from A → drag each rune to B.\nResult: B will hold A reversed.")
	_log("reverse_challenge_start", 0)

func _check_reverse_complete() -> void:
	if not _reverse_challenge_active: return
	if not _stack_a.is_empty(): return      # still items in A
	if _stack_b.size() != _reverse_source.size(): return

	# Validate that B is the reverse of the original A
	var b_names: Array = []
	for entry in _stack_b:
		b_names.append(entry["name"])
	var expected := _reverse_source.duplicate()
	expected.reverse()

	if b_names == expected:
		_reverse_challenge_active = false
		_dismiss_task_card()

		# FIX 4: Don't call _apply_correct() here because it calls _end_game()
		# if the target_correct threshold is crossed, which would interrupt the
		# challenge completion flow and cause a double code-panel. Instead we
		# credit score manually.
		var bonus := 30
		_score += bonus
		_score_lbl.text = "Score: %d" % _score

		_show_hint(
			"✓ Reverse Complete!\nStack B now holds Stack A in reversed order.\nThis is the classic 2-stack reverse algorithm!")
		_log("reverse_challenge_done", bonus)
		await get_tree().create_timer(2.5).timeout
		_show_code_snippet()       # show code panel inline
		await get_tree().create_timer(4.0).timeout
		_code_panel.visible = false
		_hint_lbl.text = _idle_hint()
	else:
		# Partial fill but wrong order (shouldn't happen in normal play)
		_reverse_challenge_active = false
		_show_hint("Challenge ended — order mismatch. Keep playing!")

# ─────────────────────────────────────────────────────────────────────────────
#  STACK VISUALS
# ─────────────────────────────────────────────────────────────────────────────
func _update_stack_visuals(stack: Array, col_x: float, col_id: String) -> void:
	for i in range(stack.size()):
		var nd := stack[i]["node"] as Node2D
		if not is_instance_valid(nd): continue

		var is_top := (i == stack.size() - 1)

		# Hidden items (Expert): only top 2 visible
		if _p["hidden_items"]:
			nd.visible = (stack.size() - 1 - i) < 2

		# CHANGED: highlight_top is always true now.
		# Top rune glows COL_TOP in all tiers; lower runes are dimmed.
		if is_top:
			nd.modulate = COL_TOP
		else:
			nd.modulate = stack[i]["color"].darkened(0.25)

	# Crown: float above top rune
	var crown := _crown_a if col_id == "a" else _crown_b
	if is_instance_valid(crown):
		if stack.is_empty():
			crown.visible = false
		else:
			crown.visible = true
			var top_pos := _col_top_pos(stack, col_x)
			crown.global_position = Vector2(col_x, top_pos.y - 50)

	# Height bar
	var hbar := _hbar_a if col_id == "a" else _hbar_b
	if is_instance_valid(hbar):
		hbar.value = stack.size()
		if stack.size() >= _p["max_height"] - 1:
			hbar.modulate = COL_WRONG
		else:
			hbar.modulate = COL_WHITE

	# A: refresh the live text display after every structural change
	_update_stack_display()

# ─────────────────────────────────────────────────────────────────────────────
#  COLUMN HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _col_top_pos(stack: Array, col_x: float) -> Vector2:
	return Vector2(col_x, BASE_Y - stack.size() * SLOT_H)

func _can_pop(stack: Array) -> bool:
	return not stack.is_empty()

func _top_nd(stack: Array) -> Node2D:
	return stack.back()["node"] as Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  FEEDBACK
# ─────────────────────────────────────────────────────────────────────────────
func _apply_correct(nd: Node2D, pts: int) -> void:
	_stat["correct"] += 1
	_combo += 1; _combo_decay = COMBO_TTL
	var earned := pts * (1 + _combo / 5)
	_score += earned
	_score_lbl.text  = "Score: %d" % _score
	_combo_lbl.text  = "×%d COMBO!" % _combo if _combo > 1 else ""
	_acc_lbl.text    = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd):
		_flash(nd, COL_TOP); _bounce(nd); _float(nd, "+%d" % earned, COL_TOP)
	AudioManager.play_sfx(PATH_SFX_OK)
	_log("correct", earned)

	# Win check
	if _stat["correct"] >= _p["target_correct"]:
		var acc := _accuracy()
		if _p["accuracy_target"] <= 0.0 or acc >= _p["accuracy_target"]:
			_end_game(true)
		else:
			_show_hint("Goal reached! Need %.0f%% accuracy (currently %.0f%%)" % [
				_p["accuracy_target"], acc])

# CHANGED: added count_as_mistake param.
# Teaching moments (underflow demo, wrong reverse move) pass false so the
# player learns without losing a life.
func _apply_wrong(nd: Node2D, penalty: int, msg: String,
		count_as_mistake: bool = true) -> void:
	_combo = 0; _combo_lbl.text = ""
	if penalty > 0:
		_score = max(0, _score - penalty)
		_score_lbl.text = "Score: %d" % _score
	_acc_lbl.text = "Accuracy: %.0f%%" % _accuracy()
	# FIX 5: was "if valid: _flash; _shake" — semicolon chain in GDScript only
	# applies the FIRST statement to the if; _shake() always ran. Fixed below.
	if is_instance_valid(nd):
		_flash(nd, COL_WRONG)
		_shake(nd)
	if not msg.is_empty(): _show_context_feedback(nd, msg, COL_WRONG)
	if count_as_mistake:
		_lives -= 1; _refresh_lives()
		if _lives <= 0: _end_game(false)
	AudioManager.play_sfx(PATH_SFX_FAIL)
	_log("wrong", -penalty)

# NEW: Teaching moment — shows feedback without affecting lives or score.
# Used for underflow demo and reverse challenge guidance.
func _show_teaching_moment(msg: String, nd: Node2D = null) -> void:
	_show_hint(msg)
	if is_instance_valid(nd):
		_pulse(nd, COL_PEEK)
	AudioManager.play_sfx(PATH_SFX_FAIL)
	_log("teaching_moment", 0)

func _show_hint(text: String) -> void:
	_hint_lbl.text = text
	_hint_box.visible = true

func _show_context_feedback(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new()
	lbl.text = text; lbl.z_index = 200
	lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	par.add_child(lbl)
	lbl.global_position = nd.global_position + Vector2(-60, -70)
	var tw := lbl.create_tween()
	tw.tween_property(lbl,"position",lbl.position+Vector2(0,-55),1.2)
	tw.parallel().tween_property(lbl,"modulate:a",0.0,1.2)
	tw.tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  ANIMATIONS
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

func _pulse(nd: Node2D, color: Color) -> void:
	if not is_instance_valid(nd): return
	var tw := nd.create_tween()
	for _i in range(4):
		tw.tween_property(nd,"modulate",color,0.07)
		tw.tween_property(nd,"modulate",COL_WHITE,0.07)

func _float(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new(); lbl.text = text; lbl.z_index = 200
	lbl.add_theme_font_override("font",_pixel_font)
	lbl.add_theme_font_size_override("font_size",18)
	lbl.add_theme_color_override("font_color",color)
	par.add_child(lbl); lbl.global_position = nd.global_position + Vector2(-20,-44)
	var tw := lbl.create_tween()
	tw.tween_property(lbl,"position",lbl.position+Vector2(0,-40),0.8)
	tw.parallel().tween_property(lbl,"modulate:a",0.0,0.8)
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
	for i in range(3):
		var lbl := Label.new()
		lbl.text = "❤" if i < _lives else "🖤"
		lbl.add_theme_font_size_override("font_size", 22)
		_lives_row.add_child(lbl)

func _accuracy() -> float:
	var total: int = (_stat["correct"] as int) + (_stat["wrong_pop"] as int) + \
				 (_stat["wrong_push"] as int) + (_stat["sequence_break"] as int) + (_stat["overflow"] as int)
	return 100.0 if total == 0 else float(_stat["correct"]) / float(total) * 100.0

# ─────────────────────────────────────────────────────────────────────────────
#  ANALYTICS
# ─────────────────────────────────────────────────────────────────────────────
func _log(action: String, value: int) -> void:
	pass   # ProgressTracker removed — session action logging not needed by PlayerProfile

# ─────────────────────────────────────────────────────────────────────────────
#  END GAME
#  CHANGED: shows code snippet panel after the summary, before transitioning.
#  Expert reverse challenge triggers the snippet inline; other tiers see it
#  as part of the completion screen.
# ─────────────────────────────────────────────────────────────────────────────
func _end_game(success: bool) -> void:
	if not _alive: return
	_alive = false; _game_tmr.stop()

	var acc   := _accuracy()
	var grade := _calc_grade(success, acc)
	var dominant := _dominant_mistake()

	var summary := ""
	if success:
		summary = "✓ Cleared! Grade: %s\nAccuracy: %.0f%%\n\n%s" % [grade, acc, _grade_tip(grade)]
	else:
		summary = "✗ Failed. Grade: %s\nAccuracy: %.0f%%\n\nMain issue:\n%s" % [grade, acc, dominant]

	_fail_summary.visible = true
	_fail_lbl.text        = summary

	# Save result to PlayerProfile (replaces ProgressTracker.complete_chapter)
	if has_node("/root/PlayerProfile"):
		PlayerProfile.save_chapter_result(
			_chapter_id,
			_score,
			_grade_to_stars(grade),
			acc,
			{
				"wrong_pop":      _stat["wrong_pop"],
				"wrong_push":     _stat["wrong_push"],
				"sequence_break": _stat["sequence_break"],
				"overflow":       _stat["overflow"],
			}
		)

	# Explicitly sync GameRouter so next_chapter() works correctly on the
	# results screen — chapter_complete() does not set current_chapter itself.
	if has_node("/root/GameRouter"):
		GameRouter.current_chapter = _chapter_id

	# NEW: show code snippet after a short pause, then transition
	await get_tree().create_timer(1.8).timeout
	_show_code_snippet()
	await get_tree().create_timer(5.0).timeout   # longer read time for code
	GameRouter.chapter_complete(_chapter_id, _score, _grade_to_stars(grade))

# NEW: Code snippet panel — fades in over the game view.
# Shows real Python syntax matching what the player just practiced.
func _show_code_snippet() -> void:
	var concept: String = _p["concept"]
	if concept not in CODE_SNIPPETS: return

	# Hide the summary first so it doesn't show through the code panel
	var tw_out := _fail_summary.create_tween()
	tw_out.tween_property(_fail_summary, "modulate:a", 0.0, 0.4)
	await tw_out.finished
	_fail_summary.visible = false
	_fail_summary.modulate.a = 1.0   # reset for any future use

	var header := "What you just practiced — in real code:\n\n"
	_code_lbl.text = header + CODE_SNIPPETS[concept]

	_code_panel.modulate.a = 0.0
	_code_panel.visible    = true
	_code_panel.create_tween()\
		.tween_property(_code_panel, "modulate:a", 1.0, 0.6)

# ─────────────────────────────────────────────────────────────────────────────
#  GRADE
# ─────────────────────────────────────────────────────────────────────────────
func _calc_grade(success: bool, acc: float) -> String:
	if not success: return "C" if acc >= 60.0 else "F"
	if acc >= 95.0: return "S"
	if acc >= 82.0: return "A"
	if acc >= 68.0: return "B"
	return "C"

func _dominant_mistake() -> String:
	var ranked := [
		["wrong_pop",      "You kept clicking non-top runes (LIFO violation)."],
		["sequence_break", "You broke the pop sequence too often — plan your pushes."],
		["overflow",       "You pushed past the height limit without popping first."],
		["wrong_push",     "You pushed when you were told to pop (task card ignored)."],
	]
	var best_msg := "Keep practicing!"; var best_cnt := 0
	for pair in ranked:
		var cnt: int = _stat[pair[0]]
		if cnt > best_cnt: best_cnt = cnt; best_msg = pair[1]
	return best_msg

func _grade_tip(grade: String) -> String:
	match grade:
		"S": return "Flawless LIFO execution!"
		"A": return "Excellent — barely any mistakes."
		"B": return "Good, but watch the sequence order."
		"C": return "Review: only the TOP rune is accessible."
		_:   return ""

func _grade_to_stars(grade: String) -> int:
	match grade:
		"S", "A": return 3
		"B":      return 2
		"C":      return 1
		_:        return 0

# ─────────────────────────────────────────────────────────────────────────────
#  EXPERT: REVERSE CHALLENGE TRIGGER
#  Called during Expert gameplay when Stack A reaches 3+ items for the first
#  time and the challenge hasn't started yet.
# ─────────────────────────────────────────────────────────────────────────────
func _maybe_trigger_reverse_challenge() -> void:
	if not _p.get("reverse_challenge", false): return
	if _reverse_challenge_active: return
	if _stack_a.size() < 3: return
	if _stat["correct"] < 4: return   # let player warm up first
	_start_reverse_challenge()

# ─────────────────────────────────────────────────────────────────────────────
#  HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _wait_for_click() -> void:
	while not Input.is_action_just_pressed("click"):
		await get_tree().process_frame
