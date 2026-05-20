# =============================================================================
# AlgoQuest — Chapter 2: Castle of Echoes (Stack) v6
# File: res://scripts/chapters/stack/StackGame.gd
#
# KEY CHANGES FROM v5:
#   • RUNES updated to match actual asset filenames:
#       fire, ice, wind, earth, dark, light  (was plus/minus/multiply/divide/modulo/equal)
#   • Shadow sprite (demonic.png) is a CHILD of every rune node — sits flush at
#     the base of each rune so it looks grounded on the stack below it.
#   • Runes stack flush against each other — SLOT_H now matches scaled sprite
#     height (32px * 2.0 scale = 64px, but we use 60 for a 4px overlap to avoid gaps).
#   • 5 tiers total (was 4):
#       0 (ch 6)  PUSH_POP   Discover push() and pop(). LIFO.
#       1 (ch 7)  PEEK       peek() reads top. isEmpty() before pop().
#       2 (ch 8)  OVERFLOW   Bounded stack, sequence goals, plan push order.
#       3 (ch 9)  UNDO       Undo/redo pattern — stack reverses history.
#       4 (ch 10) BRACKETS   Balanced bracket algorithm using a stack.
#   • TutDiagram inner class retained — draws tutorial diagrams in GDScript.
#   • _make_rune_node() centralises rune+shadow sprite construction.
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
const PATH_BGM      := "res://assets/audio/music/song18.ogg"

# Rune sprites — filenames now match the uploaded PNGs
const RUNE_BASE     := "res://assets/art/character/"
const PATH_SHADOW   := "res://assets/art/character/demonic.png"   # shadow decal

# ─────────────────────────────────────────────────────────────────────────────
#  RUNES  (key = exact filename without .png)
# ─────────────────────────────────────────────────────────────────────────────
const RUNES: Array[Dictionary] = [
	{"key": "fire",  "name": "Fire",  "color": Color(0.89, 0.29, 0.10)},
	{"key": "ice",   "name": "Ice",   "color": Color(0.22, 0.54, 0.87)},
	{"key": "wind",  "name": "Wind",  "color": Color(0.38, 0.78, 0.50)},
	{"key": "earth", "name": "Earth", "color": Color(0.39, 0.60, 0.13)},
	{"key": "dark",  "name": "Dark",  "color": Color(0.50, 0.47, 0.87)},
	{"key": "light", "name": "Light", "color": Color(0.80, 0.78, 0.65)},
]

# ─────────────────────────────────────────────────────────────────────────────
#  LAYOUT
# ─────────────────────────────────────────────────────────────────────────────
const COL_A_X    := 400.0
const BASE_Y     := 580.0

# Sprite is 32x32 JPEG. Rune art occupies rows 8-30 (23px tall, 32px wide).
# region_rect crops to that + shader discards near-black background pixels.
# Rendered size = 32x23 px * scale 3 = 96x69 px.
# SLOT_H = 46: runes overlap by ~23px so the lower rune's top face peeks
# out below the upper one — matching the stacked isometric cube look.
const SLOT_H     := 46.0
const RUNE_SCALE := Vector2(3.0, 3.0)

# Shadow is now a thin ColorRect inside _make_rune_node — no separate sprite.
const SHADOW_OFFSET := Vector2(0.0, 34.0)  # kept for compat, not used
const SHADOW_SCALE  := Vector2(3.0, 0.5)   # kept for compat, not used

const STAGE_POS  := Vector2(640.0, 80.0)
const SNAP_DIST  := 90.0
const HIT_R      := 40.0

const COL_TOP   := CastleTheme.C_GOLD
const COL_PEEK  := CastleTheme.C_SAPPHIRE
const COL_WRONG := CastleTheme.C_CRIMSON
const COL_WHITE := Color.WHITE

# ─────────────────────────────────────────────────────────────────────────────
#  TIER PARAMS  (5 tiers)
# ─────────────────────────────────────────────────────────────────────────────
const TIER_PARAMS: Array[Dictionary] = [
	# 0 — PUSH_POP
	{
		"concept":        "PUSH_POP",
		"mode":           "push_pop",
		"max_height":     6,
		"target_correct": 8,
		"time_limit":     0.0,
		"penalty":        0,
	},
	# 1 — PEEK
	{
		"concept":        "PEEK",
		"mode":           "peek",
		"max_height":     5,
		"target_correct": 10,
		"time_limit":     0.0,
		"penalty":        10,
	},
	# 2 — OVERFLOW
	{
		"concept":        "OVERFLOW",
		"mode":           "overflow",
		"max_height":     4,
		"target_correct": 12,
		"time_limit":     90.0,
		"penalty":        15,
	},
	# 3 — UNDO
	{
		"concept":        "UNDO",
		"mode":           "undo",
		"max_height":     5,
		"target_correct": 10,
		"time_limit":     90.0,
		"penalty":        20,
	},
	# 4 — BRACKETS  (new tier — balanced bracket algorithm)
	{
		"concept":        "BRACKETS",
		"mode":           "brackets",
		"max_height":     8,
		"target_correct": 8,
		"time_limit":     120.0,
		"penalty":        20,
	},
]

# ─────────────────────────────────────────────────────────────────────────────
#  CONCEPT SLIDES
# ─────────────────────────────────────────────────────────────────────────────
const CONCEPT_SLIDES: Dictionary = {
	"PUSH_POP": [
		{
			"title":   "The Stack — LIFO Structure",
			"body":    "A stack stores runes in a tower — only the TOP rune is accessible.\nRunes below are locked until everything above is removed.\nThis rule is called LIFO: Last In, First Out.",
			"diagram": "stack_intro",
		},
		{
			"title":   "push()  —  Add to Top",
			"body":    "push(rune) places a rune on top of the stack.\nThe new rune becomes the top — others are buried below.\nOnly the topmost rune can be acted on next.",
			"diagram": "push_demo",
		},
		{
			"title":   "pop()  —  Remove from Top",
			"body":    "pop() removes the top rune and returns it.\nThe rune pushed LAST always pops FIRST — that's LIFO.\nThe rune below becomes the new top after popping.",
			"diagram": "pop_demo",
		},
		{
			"title":   "Your Task",
			"body":    "Drag a rune onto the column  →  push()\nClick the ♛ crown on the top rune  →  pop()\nWatch the array panel and the Python call label.",
			"diagram": "task_preview",
		},
	],
	"PEEK": [
		{
			"title":   "peek()  —  Look Without Removing",
			"body":    "peek() reads the top rune without removing it.\nstack[-1] returns the top value — stack size stays the same.\nUse peek to check what's on top before deciding to pop.",
			"diagram": "peek_demo",
		},
		{
			"title":   "isEmpty()  —  Guard Before pop()!",
			"body":    "Popping an empty stack crashes your program.\nAlways check isEmpty() before calling pop().\nIf the stack is empty, skip the pop — never force it.",
			"diagram": "isempty_demo",
		},
		{
			"title":   "Your Task",
			"body":    "👁 PEEK  — click Peek to read the top rune\n♛ POP   — click the crown to remove the top\n▶ PUSH  — drag a rune onto the column\nPopping when empty counts as a mistake!",
			"diagram": "task_preview",
		},
	],
	"OVERFLOW": [
		{
			"title":   "Bounded Stacks & Overflow",
			"body":    "Real stacks have a size limit — here it's 4 runes.\nPushing onto a full stack causes an overflow crash.\nWatch the height bar: red means one push from danger.",
			"diagram": "overflow_full",
		},
		{
			"title":   "Planning Push Order",
			"body":    "LIFO means the last thing pushed comes out first.\nTo pop Fire → Ice → Wind, push Wind first, then Ice, then Fire.\nAlways plan your push order in REVERSE of the goal.",
			"diagram": "sequence_plan",
		},
		{
			"title":   "Your Task",
			"body":    "The sequence banner shows the pop order you need.\nPush runes in REVERSE of that order.\nPop before the stack fills up — don't overflow!",
			"diagram": "task_preview",
		},
	],
	"UNDO": [
		{
			"title":   "Real Use: Undo History",
			"body":    "Every text editor uses a stack for Ctrl+Z undo.\nEach action is pushed when performed.\nCtrl+Z pops the last action — LIFO gives correct undo order.",
			"diagram": "undo_concept",
		},
		{
			"title":   "LIFO = Perfect Undo Order",
			"body":    "4 spells cast → 4 runes pushed.\nUndo × 2 = pop() × 2: last two spells reversed in order.\nThe stack always undoes the most-recent action first.",
			"diagram": "undo_lifo",
		},
		{
			"title":   "Your Task",
			"body":    "Spells are cast one by one — each is auto-pushed.\nOnce all are cast, click ♛ to undo each one.\nPop every rune in reverse to fully restore the original state.",
			"diagram": "task_preview",
		},
	],
	"BRACKETS": [
		{
			"title":   "Bracket Matching with a Stack",
			"body":    "A stack checks if brackets are balanced — a classic problem.\nOpen bracket ( [ {  →  PUSH it onto the stack.\nClose bracket ) ] }  →  POP and check it matches.",
			"diagram": "brackets_intro",
		},
		{
			"title":   "Step-by-Step: \"([])\"",
			"body":    "( → push   [ → push   ] → pop ✓   ) → pop ✓\nStack empty at end = BALANCED ✓\nNot empty, or a mismatch = UNBALANCED ✗",
			"diagram": "brackets_algo",
		},
		{
			"title":   "Your Task",
			"body":    "A bracket string appears — work left to right.\nOpen bracket → drag the shown rune to PUSH.\nClose bracket → click ♛ to POP and match.\nEmpty stack at end = success!",
			"diagram": "task_preview",
		},
	],
}

# ─────────────────────────────────────────────────────────────────────────────
#  CODE SNIPPETS  (shown at tier completion)
# ─────────────────────────────────────────────────────────────────────────────
const CODE_SNIPPETS: Dictionary = {
	"PUSH_POP":
"""# Python — push, pop, LIFO
stack = []
stack.append("Fire")    # push  →  top is "Fire"
stack.append("Ice")     # push  →  top is "Ice"
stack.pop()             # pop   →  removes "Ice"  (Last In, First Out)
stack.pop()             # pop   →  removes "Fire"
# Stack is now empty — len(stack) == 0
""",
	"PEEK":
"""# Python — peek and isEmpty guard
stack = ["Fire", "Ice", "Wind"]

top = stack[-1]         # peek  →  "Wind"  (stack UNCHANGED)

if stack:               # isEmpty check — ALWAYS before pop!
    val = stack.pop()   # safe pop  →  "Wind"
else:
    print("Underflow!")  # never pop an empty stack
""",
	"OVERFLOW":
"""# Python — bounded stack + sequence planning
MAX = 4
stack = []

if len(stack) < MAX:    # overflow guard before every push
    stack.append(item)
else:
    raise OverflowError("Stack is full!")

# LIFO forces reverse push order:
# Goal pop: Fire → Ice → Wind
# Push:  Wind first, Ice, Fire last (Fire = top = pops first)
""",
	"UNDO":
"""# Python — undo history pattern
undo_stack = []

def do_action(action):
    apply(action)
    undo_stack.append(action)    # push every edit

def undo():
    if undo_stack:               # isEmpty check first!
        action = undo_stack.pop()    # most recent edit
        reverse(action)          # undo it
    # LIFO = automatic correct undo order
""",
	"BRACKETS":
"""# Python — balanced bracket checker  O(n)
def is_balanced(s: str) -> bool:
    stack = []
	pairs = {')': '(', ']': '[', '}': '{'}

    for ch in s:
		if ch in '([{':
            stack.append(ch)          # push open bracket
		elif ch in ')]}':
            if not stack:             # isEmpty → unbalanced
                return False
            if stack[-1] != pairs[ch]:  # peek to verify match
                return False
            stack.pop()               # pop the matched open

    return len(stack) == 0            # empty at end → balanced

print(is_balanced("({[]})"))  # True
print(is_balanced("({[)]}"))  # False
""",
}

# =============================================================================
#  TutDiagram  —  inner class, draws tutorial diagrams via _draw()
# =============================================================================
class TutDiagram extends Control:

	const _SDARK  := Color(0.12, 0.11, 0.15)
	const _SMID   := Color(0.20, 0.18, 0.24)
	const _SLIGHT := Color(0.30, 0.27, 0.36)
	const _GOLD   := Color(0.85, 0.68, 0.20)
	const _TORCH  := Color(0.95, 0.52, 0.12)
	const _PARCH  := Color(0.90, 0.85, 0.70)
	const _PDIM   := Color(0.60, 0.55, 0.43)
	const _RED    := Color(0.85, 0.15, 0.15)
	const _GREEN  := Color(0.22, 0.72, 0.38)
	const _BLUE   := Color(0.25, 0.55, 0.90)

	const _FIRE   := Color(0.89, 0.29, 0.10)
	const _ICE    := Color(0.22, 0.54, 0.87)
	const _WIND   := Color(0.38, 0.78, 0.50)
	const _EARTH  := Color(0.39, 0.60, 0.13)
	const _DARK   := Color(0.50, 0.47, 0.87)

	var slide_key: String = ""
	var _font:     Font   = null

	func set_slide(key: String, font: Font) -> void:
		slide_key = key
		_font     = font
		queue_redraw()

	func _draw() -> void:
		if slide_key == "": return
		match slide_key:
			"stack_intro":     _draw_stack_intro()
			"push_demo":       _draw_push_demo()
			"pop_demo":        _draw_pop_demo()
			"peek_demo":       _draw_peek_demo()
			"isempty_demo":    _draw_isempty_demo()
			"overflow_full":   _draw_overflow_full()
			"sequence_plan":   _draw_sequence_plan()
			"undo_concept":    _draw_undo_concept()
			"undo_lifo":       _draw_undo_lifo()
			"brackets_intro":  _draw_brackets_intro()
			"brackets_algo":   _draw_brackets_algo()
			"task_preview":    _draw_task_preview()

	# ── Helpers ──────────────────────────────────────────────────────────────

	func _txt(pos: Vector2, text: String, sz: int, color: Color,
			align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
		if _font == null: return
		draw_string(_font, pos + Vector2(0, sz * 0.78), text, align, -1, sz, color)

	func _box(rect: Rect2, fill: Color, border: Color, bw: float = 1.5) -> void:
		draw_rect(rect, fill)
		draw_rect(rect, border, false, bw)

	func _col(cx: float, by: float, items: Array,
			col_w: float = 72.0, ih: float = 26.0, gap: float = 1.0) -> void:
		# Draw a vertical stack column. items = [[name, color], ...]
		# gap=1 keeps runes flush — matching the in-game look.
		var total_h := items.size() * (ih + gap)
		var x := cx - col_w / 2.0
		draw_rect(Rect2(x - 2, by - total_h - 6, col_w + 4, total_h + 6),
				  Color(0.05, 0.04, 0.07))
		draw_rect(Rect2(x - 2, by - total_h - 6, col_w + 4, total_h + 6),
				  _SLIGHT, false, 1.0)
		draw_rect(Rect2(x - 2, by - total_h - 6, col_w + 4, 3), _GOLD)
		for i in range(items.size()):
			var nm: String = items[i][0]
			var c: Color   = items[i][1]
			var is_top: bool = (i == items.size() - 1)
			var iy := by - (i + 1) * (ih + gap) + gap
			var bg := Color(c.r * 0.22, c.g * 0.22, c.b * 0.22, 1.0)
			var border := c if is_top else c.darkened(0.45)
			_box(Rect2(x, iy, col_w, ih), bg, border, 2.0 if is_top else 1.0)
			_txt(Vector2(x + 5, iy + ih * 0.18), nm, 12, c)

	func _arrow_r(x1: float, y: float, x2: float, color: Color) -> void:
		draw_line(Vector2(x1, y), Vector2(x2 - 8, y), color, 2.0)
		draw_polygon([Vector2(x2, y), Vector2(x2-8, y-5), Vector2(x2-8, y+5)],
					 [color, color, color])

	func _arrow_u(x: float, y1: float, y2: float, color: Color) -> void:
		draw_line(Vector2(x, y1), Vector2(x, y2 + 8), color, 2.0)
		draw_polygon([Vector2(x, y2), Vector2(x-5, y2+8), Vector2(x+5, y2+8)],
					 [color, color, color])

	# ── Diagrams ─────────────────────────────────────────────────────────────
	# All diagrams use _rune_img() to draw actual rune textures from disk.
	# Each diagram is a step-by-step visual teaching the concept concretely.

	# Load a rune texture by key for use in draw_texture_rect
	func _rune_tex(key: String) -> Texture2D:
		var path := "res://assets/art/character/" + key + ".png"
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
		return null

	# Draw a rune tile at position with given size, tinted by its element colour.
	# The rune PNG is white/grey silhouette — we modulate it with the element
	# colour so Fire appears red, Ice appears blue, etc.
	func _rune_img(key: String, color: Color, x: float, y: float, sz: float) -> void:
		var tex := _rune_tex(key)
		var r   := Rect2(x, y, sz, sz)
		# Dark tinted background square
		draw_rect(r.grow(2), Color(color.r * 0.12, color.g * 0.12, color.b * 0.12, 1.0))
		draw_rect(r.grow(2), color, false, 1.5)
		if tex:
			# Draw texture modulated by the element colour so the silhouette
			# shows in the correct tint instead of pure white
			draw_texture_rect(tex, r, false, color)
		else:
			# Fallback: solid colour circle
			draw_circle(Vector2(x + sz * 0.5, y + sz * 0.5), sz * 0.38, color)

	# Draw a stack column of rune images, bottom-up, with realistic overlap stacking.
	# Rune sprites are 32x32 px JPEGs cropped to rows 8-30 (23 px of art).
	# We draw them with a vertical overlap so lower runes peek below upper ones,
	# matching the in-game look (photo 3: stacked ice cubes showing depth).
	# entries = [{key, color, label}]
	func _rune_col(cx: float, base_y: float, entries: Array,
				sz: float = 40.0, top_color: Color = Color(0.85,0.68,0.20)) -> void:
		var n        := entries.size()
		# Each rune tile is sz tall, but we overlap by ~33% so layers show depth —
		# matching the in-game SLOT_H = 46 vs rendered height 69 ratio.
		var step     := sz * 0.667  # vertical advance per rune (overlap = 33%)
		var col_w    := sz + 8.0
		var col_h    := (n - 1) * step + sz   # total visual height
		var lx       := cx - col_w * 0.5
		# Shaft / column background — dark stone pillar behind the rune stack
		draw_rect(Rect2(lx - 2, base_y - col_h - 8, col_w + 4, col_h + 8),
				  Color(0.07, 0.06, 0.10))
		draw_rect(Rect2(lx - 2, base_y - col_h - 8, col_w + 4, col_h + 8),
				  Color(0.25, 0.20, 0.35), false, 1.5)
		# Gold cap at top of shaft
		draw_rect(Rect2(lx - 2, base_y - col_h - 8, col_w + 4, 3), top_color)
		# Draw runes bottom-to-top so upper runes paint over lower ones (depth illusion)
		for i in range(n):
			var e: Dictionary = entries[i]
			var iy := base_y - (i + 1) * step - (sz - step)
			# Tinted side-face: a darker sliver below the rune tile to suggest 3-D depth
			var side_h := sz * 0.18
			var side_c := Color(e["color"].r*0.28, e["color"].g*0.28, e["color"].b*0.28, 1.0)
			draw_rect(Rect2(cx - sz*0.5, iy + sz - side_h, sz, side_h), side_c)
			# Main rune tile
			_rune_img(e["key"], e["color"], cx - sz*0.5, iy, sz)
			# Label to the right (only non-empty ones)
			var lbl: String = e.get("label", "")
			if lbl != "":
				_txt(Vector2(cx + sz*0.5 + 6, iy + sz*0.3), lbl, 11, e["color"])
		# Crown label above top rune
		_txt(Vector2(cx, base_y - col_h - 20), "♛ TOP", 11,
			  top_color, HORIZONTAL_ALIGNMENT_CENTER)

	# Arrow pointing right
	func _arr_r(x1: float, y: float, x2: float, c: Color, label: String = "") -> void:
		draw_line(Vector2(x1, y), Vector2(x2 - 8, y), c, 2.0)
		draw_polygon([Vector2(x2,y), Vector2(x2-8,y-5), Vector2(x2-8,y+5)], [c,c,c])
		if label != "":
			_txt(Vector2((x1+x2)*0.5, y - 16), label, 11, c, HORIZONTAL_ALIGNMENT_CENTER)

	# Arrow pointing down
	func _arr_d(x: float, y1: float, y2: float, c: Color, label: String = "") -> void:
		draw_line(Vector2(x, y1), Vector2(x, y2 - 8), c, 2.0)
		draw_polygon([Vector2(x,y2), Vector2(x-5,y2-8), Vector2(x+5,y2-8)], [c,c,c])
		if label != "":
			_txt(Vector2(x + 8, (y1+y2)*0.5), label, 11, c)

	# ── PUSH_POP tier diagrams ───────────────────────────────────────────────────

	func _draw_stack_intro() -> void:
		var W  := size.x; var H := size.y
		# Use a slightly larger rune size so the stacked tiles are clearly readable.
		var SZ := minf(W * 0.11, H * 0.19)
		# base_y is the floor the column sits on. Push it lower so the tall
		# stacked column (with overlap) still fits inside the panel.
		var base := H * 0.92

		# ── Left column: 3 stacked runes (Wind on top, Fire at bottom) ──────────
		# Labels shown beside each rune identify their position in the LIFO order.
		_rune_col(W*0.20, base, [
			{"key":"fire",  "color":_FIRE,  "label":"Fire  (bottom)"},
			{"key":"ice",   "color":_ICE,   "label":"Ice"},
			{"key":"wind",  "color":_WIND,  "label":"Wind  ← TOP"},
		], SZ)

		# ── Right side: two access-rule boxes ───────────────────────────────────
		# GREEN box — TOP is reachable
		_box(Rect2(W*0.36, H*0.03, W*0.61, H*0.43), _SDARK, _GREEN, 1.5)
		_txt(Vector2(W*0.38, H*0.05), "✓  TOP is accessible", 13, _GREEN)
		# Show the actual Wind rune (the accessible one)
		_rune_img("wind", _WIND, W*0.38, H*0.12, SZ * 0.85)
		_txt(Vector2(W*0.38, H*0.32), "pop() removes Wind first", 12, _WIND)
		_txt(Vector2(W*0.38, H*0.39), "(LAST IN = FIRST OUT)", 11, _PDIM)

		# RED box — middle & bottom are blocked
		_box(Rect2(W*0.36, H*0.50, W*0.61, H*0.43), _SDARK, _RED, 1.5)
		_txt(Vector2(W*0.38, H*0.52), "✗  Middle & bottom BLOCKED", 13, _RED)
		# Show the two blocked runes side by side
		_rune_img("ice",  _ICE,  W*0.38,        H*0.59, SZ * 0.85)
		_rune_img("fire", _FIRE, W*0.38 + SZ*0.95, H*0.59, SZ * 0.85)
		_txt(Vector2(W*0.38, H*0.79), "Can't reach Ice or Fire!", 12, _RED)
		_txt(Vector2(W*0.38, H*0.86), "Must pop Wind first.", 11, _PDIM)

	func _draw_push_demo() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.11, H * 0.20)
		var base := H * 0.88

		# Step label
		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _GOLD, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "push(item)  →  place new rune ON TOP", 13,
				_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		# Before column
		_txt(Vector2(W*0.12, H*0.14), "BEFORE:", 12, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rune_col(W*0.12, base, [
			{"key":"fire", "color":_FIRE, "label":""},
			{"key":"ice",  "color":_ICE,  "label":"← top"},
		], SZ)

		# Staged rune falling in
		_rune_img("wind", _WIND, W*0.30, H*0.14, SZ)
		_txt(Vector2(W*0.30 + SZ*0.5, H*0.14 + SZ*0.5), "Wind\n(staged)", 10,
				_WIND, HORIZONTAL_ALIGNMENT_CENTER)
		_arr_d(W*0.30 + SZ*0.5, H*0.14 + SZ + 4, H*0.88 - SZ*2, _WIND, "push()")

		# Arrow
		_arr_r(W*0.46, H*0.55, W*0.56, _GOLD)

		# After column
		_txt(Vector2(W*0.72, H*0.14), "AFTER:", 12, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rune_col(W*0.72, base, [
			{"key":"fire", "color":_FIRE, "label":""},
			{"key":"ice",  "color":_ICE,  "label":""},
			{"key":"wind", "color":_WIND, "label":"← NEW top"},
		], SZ)

		# Code
		_box(Rect2(W*0.02, H*0.80, W*0.96, H*0.18), Color(0.04,0.08,0.04), _GREEN, 1.0)
		_txt(Vector2(W*0.05, H*0.83), "stack.append(Wind)   # stack = [Fire, Ice, Wind]", 12, _PARCH)
		_txt(Vector2(W*0.05, H*0.91), "stack[-1]  →  Wind   # Wind is now on top", 11, _GREEN)

	func _draw_pop_demo() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.11, H * 0.20)
		var base := H * 0.88

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _GOLD, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "pop()  →  remove & return the TOP rune (LIFO)", 13,
				_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		# Before
		_txt(Vector2(W*0.12, H*0.14), "BEFORE:", 12, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rune_col(W*0.12, base, [
			{"key":"fire", "color":_FIRE, "label":""},
			{"key":"ice",  "color":_ICE,  "label":""},
			{"key":"wind", "color":_WIND, "label":"← top (pops FIRST)"},
		], SZ)

		# Popped rune flying up
		_arr_d(W*0.38, H*0.42, H*0.14 + SZ, _WIND, "pop()!")
		_rune_img("wind", _WIND, W*0.33, H*0.05, SZ)
		_box(Rect2(W*0.33, H*0.05 + SZ + 2, SZ + 8, 18), _SDARK, _WIND, 1.0)
		_txt(Vector2(W*0.33 + 4, H*0.05 + SZ + 4), "returned: Wind", 10, _WIND)

		# Arrow
		_arr_r(W*0.46, H*0.55, W*0.56, _GOLD)

		# After
		_txt(Vector2(W*0.72, H*0.14), "AFTER:", 12, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rune_col(W*0.72, base, [
			{"key":"fire", "color":_FIRE, "label":""},
			{"key":"ice",  "color":_ICE,  "label":"← new top"},
		], SZ)

		_box(Rect2(W*0.02, H*0.80, W*0.96, H*0.18), Color(0.04,0.08,0.04), _GREEN, 1.0)
		_txt(Vector2(W*0.05, H*0.83), "val = stack.pop()   # val = Wind", 12, _PARCH)
		_txt(Vector2(W*0.05, H*0.91), "LIFO: Wind pushed LAST → pops FIRST", 11, _GREEN)

	# ── PEEK tier diagrams ───────────────────────────────────────────────────────

	func _draw_peek_demo() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.11, H * 0.20)
		var base := H * 0.88

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _BLUE, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "peek()  →  READ top without removing it", 13,
				_BLUE, HORIZONTAL_ALIGNMENT_CENTER)

		_rune_col(W*0.18, base, [
			{"key":"fire", "color":_FIRE, "label":""},
			{"key":"ice",  "color":_ICE,  "label":""},
			{"key":"wind", "color":_WIND, "label":"← peek reads this"},
		], SZ)

		# Eye icon + line to top rune
		var ex := W*0.46; var ey := base - SZ*2.5
		draw_arc(Vector2(ex, ey), 18, 0, TAU, 32, _BLUE, 2.0)
		draw_circle(Vector2(ex, ey), 6, _BLUE)
		draw_line(Vector2(W*0.18 + SZ*0.5, base - SZ*2.5), Vector2(ex - 20, ey), _BLUE, 1.5)

		_box(Rect2(W*0.50, H*0.25, W*0.46, H*0.30), _SDARK, _BLUE, 1.5)
		_txt(Vector2(W*0.52, H*0.27), "peek() returns:", 12, _BLUE)
		_rune_img("wind", _WIND, W*0.52, H*0.34, SZ*0.9)
		_txt(Vector2(W*0.52 + SZ + 4, H*0.37), "Wind", 13, _WIND)

		_box(Rect2(W*0.50, H*0.60, W*0.46, H*0.28), Color(0.04,0.04,0.14), _BLUE, 1.5)
		_txt(Vector2(W*0.52, H*0.62), "Stack UNCHANGED:", 12, _BLUE)
		_txt(Vector2(W*0.52, H*0.72), "size still = 3", 11, _PARCH)
		_txt(Vector2(W*0.52, H*0.80), "Wind still on top", 11, _WIND)

		_box(Rect2(W*0.02, H*0.80, W*0.96, H*0.18), Color(0.04,0.04,0.14), _BLUE, 1.0)
		_txt(Vector2(W*0.05, H*0.83), "top = stack[-1]   # top = Wind, stack unchanged", 12, _PARCH)

	func _draw_isempty_demo() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.10, H * 0.19)
		var base := H * 0.75

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _RED, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "ALWAYS check isEmpty() before pop()!", 13,
				_RED, HORIZONTAL_ALIGNMENT_CENTER)

		# Empty stack left
		_txt(Vector2(W*0.18, H*0.14), "EMPTY stack:", 12, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		draw_rect(Rect2(W*0.10, H*0.22, W*0.16, H*0.48), Color(0.05,0.04,0.08))
		draw_rect(Rect2(W*0.10, H*0.22, W*0.16, H*0.48), Color(0.25,0.20,0.35), false, 1.5)
		draw_rect(Rect2(W*0.10, H*0.22, W*0.16, 3), _GOLD)
		_txt(Vector2(W*0.18, H*0.44), "empty", 11, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*0.06, H*0.72, W*0.24, H*0.14), Color(0.04,0.14,0.04), _GREEN, 1.5)
		_txt(Vector2(W*0.18, H*0.74), "isEmpty()", 12, _GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.18, H*0.82), "→  True", 13, _GREEN, HORIZONTAL_ALIGNMENT_CENTER)

		# Non-empty stack right — with real runes
		_txt(Vector2(W*0.68, H*0.14), "NON-EMPTY:", 12, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rune_col(W*0.68, base, [
			{"key":"earth", "color":_EARTH, "label":""},
			{"key":"wind",  "color":_WIND,  "label":"← top"},
		], SZ)
		_box(Rect2(W*0.56, H*0.72, W*0.24, H*0.14), Color(0.14,0.04,0.04), _RED, 1.5)
		_txt(Vector2(W*0.68, H*0.74), "isEmpty()", 12, _RED, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.68, H*0.82), "→  False", 13, _RED, HORIZONTAL_ALIGNMENT_CENTER)

		_box(Rect2(W*0.02, H*0.88, W*0.96, H*0.10), Color(0.20,0.04,0.04), _RED, 1.5)
		_txt(Vector2(W*0.50, H*0.90), "⚠  pop() on empty stack  →  IndexError CRASH!", 12,
				_RED, HORIZONTAL_ALIGNMENT_CENTER)

	# ── OVERFLOW tier diagrams ───────────────────────────────────────────────────

	func _draw_overflow_full() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.10, H * 0.18)
		var base := H * 0.86

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), Color(0.20,0.04,0.04), _RED, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "Stack FULL → pushing now = OVERFLOW CRASH!", 13,
				_RED, HORIZONTAL_ALIGNMENT_CENTER)

		# Full stack with all 4 runes and red glow border
		_rune_col(W*0.18, base, [
			{"key":"fire",  "color":_FIRE,  "label":""},
			{"key":"ice",   "color":_ICE,   "label":""},
			{"key":"earth", "color":_EARTH, "label":""},
			{"key":"wind",  "color":_WIND,  "label":"← TOP  (MAX!)"},
		], SZ)
		# Red glow
		draw_rect(Rect2(W*0.08, H*0.12, SZ + 22, H*0.76), _RED, false, 3.0)

		# Height bar visual
		_box(Rect2(W*0.36, H*0.14, W*0.06, H*0.68), Color(0.05,0.04,0.08), _SLIGHT, 1.0)
		draw_rect(Rect2(W*0.36, H*0.14, W*0.06, H*0.68), Color(0.8,0.1,0.1,0.85))
		_txt(Vector2(W*0.44, H*0.16), "4/4", 11, _RED)
		_txt(Vector2(W*0.44, H*0.24), "MAX!", 11, _RED)

		_box(Rect2(W*0.48, H*0.18, W*0.48, H*0.60), _SDARK, Color(0.25,0.20,0.35), 1.0)
		_txt(Vector2(W*0.50, H*0.20), "Stack is FULL (4/4)", 13, _RED)
		_txt(Vector2(W*0.50, H*0.32), "Pushing now →", 12, _PDIM)
		_txt(Vector2(W*0.50, H*0.42), "OverflowError!", 14, _RED)
		_txt(Vector2(W*0.50, H*0.56), "Fix: pop() first,", 12, _GREEN)
		_txt(Vector2(W*0.50, H*0.66), "THEN push.", 12, _GREEN)

		_box(Rect2(W*0.02, H*0.82, W*0.96, H*0.16), Color(0.04,0.08,0.04), _GREEN, 1.0)
		_txt(Vector2(W*0.05, H*0.84), "if len(stack) < MAX:   stack.append(item)", 12, _PARCH)
		_txt(Vector2(W*0.05, H*0.92), "else:                  raise OverflowError", 11, _RED)

	func _draw_sequence_plan() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.09, H * 0.17)
		var base := H * 0.88

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _GOLD, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "LIFO forces REVERSE push order!", 13,
				_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		# Goal pop order row (what we WANT out)
		_txt(Vector2(W*0.50, H*0.14), "Want to pop in this order:", 12,
				_PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		var goal := [
			{"key":"fire", "color":_FIRE, "n":"Fire"},
			{"key":"ice",  "color":_ICE,  "n":"Ice"},
			{"key":"wind", "color":_WIND, "n":"Wind"},
		]
		for i in range(goal.size()):
			var gx := W*0.12 + i * W*0.30
			_rune_img(goal[i]["key"], goal[i]["color"], gx, H*0.20, SZ)
			_txt(Vector2(gx + SZ*0.5, H*0.20 + SZ + 4),
					"pop %d" % (i+1), 10, goal[i]["color"], HORIZONTAL_ALIGNMENT_CENTER)
			if i < 2: _arr_r(gx + SZ + 2, H*0.20 + SZ*0.5, gx + W*0.30, goal[i]["color"])

		_txt(Vector2(W*0.50, H*0.46), "↓  Must push in REVERSE  ↓", 13,
				_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		# Required push order (reversed)
		_txt(Vector2(W*0.50, H*0.54), "So push in this order:", 12,
				_PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		var push_order := [
			{"key":"wind", "color":_WIND, "n":"Wind"},
			{"key":"ice",  "color":_ICE,  "n":"Ice"},
			{"key":"fire", "color":_FIRE, "n":"Fire"},
		]
		for i in range(push_order.size()):
			var px := W*0.12 + i * W*0.30
			_rune_img(push_order[i]["key"], push_order[i]["color"], px, H*0.60, SZ)
			_txt(Vector2(px + SZ*0.5, H*0.60 + SZ + 4),
					"push %d" % (i+1), 10, push_order[i]["color"], HORIZONTAL_ALIGNMENT_CENTER)
			if i < 2: _arr_r(px + SZ + 2, H*0.60 + SZ*0.5, px + W*0.30, push_order[i]["color"])

		# Result stack
		_rune_col(W*0.90, base, push_order, SZ)
		_txt(Vector2(W*0.90, H*0.46), "Result:", 10, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.90, H*0.53), "Fire on top", 9, _FIRE, HORIZONTAL_ALIGNMENT_CENTER)

	# ── UNDO tier diagrams ───────────────────────────────────────────────────────

	func _draw_undo_concept() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.09, H * 0.17)
		var base := H * 0.88

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _GOLD, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "Every Ctrl+Z uses a stack — LIFO = perfect undo", 12,
				_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		# 3 edits being pushed, each shown as a rune
		var edits := [
			{"key":"fire",  "color":_FIRE,  "n":"Cast Fire"},
			{"key":"ice",   "color":_ICE,   "n":"Cast Ice"},
			{"key":"earth", "color":_EARTH, "n":"Cast Earth"},
		]
		for i in range(edits.size()):
			var ey := H*0.16 + i * H*0.24
			_rune_img(edits[i]["key"], edits[i]["color"], W*0.05, ey, SZ)
			_txt(Vector2(W*0.05 + SZ + 4, ey + SZ*0.3),
					edits[i]["n"], 12, edits[i]["color"])
			_txt(Vector2(W*0.05 + SZ + 4, ey + SZ*0.6),
					"→ push()", 10, _GOLD)
			_arr_r(W*0.44, ey + SZ*0.5, W*0.52, _GOLD)

		# Stack column showing cast history
		_rune_col(W*0.65, base, edits, SZ)

		# Ctrl+Z panel
		_box(Rect2(W*0.72, H*0.18, W*0.24, H*0.26), Color(0.18,0.04,0.04), _RED, 1.5)
		_txt(Vector2(W*0.84, H*0.20), "Ctrl+Z", 14, _RED, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.84, H*0.30), "pop()", 12, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.84, H*0.38), "= undo!", 11, _GREEN, HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_undo_lifo() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.09, H * 0.17)
		var base := H * 0.88

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _GOLD, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "pop() undoes in the CORRECT order — automatically!", 12,
				_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		var all4 := [
			{"key":"fire",  "color":_FIRE},
			{"key":"ice",   "color":_ICE},
			{"key":"earth", "color":_EARTH},
			{"key":"wind",  "color":_WIND},
		]
		var remain2 := [
			{"key":"fire", "color":_FIRE},
			{"key":"ice",  "color":_ICE},
		]

		_txt(Vector2(W*0.18, H*0.14), "After 4 casts:", 11, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rune_col(W*0.18, base, all4, SZ)

		_box(Rect2(W*0.34, H*0.38, W*0.20, H*0.20), _SMID, _RED, 1.5)
		_txt(Vector2(W*0.44, H*0.41), "Undo x2", 11, _RED, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.44, H*0.50), "pop()x2", 10, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_arr_r(W*0.54, H*0.48, W*0.60, _GOLD)

		_txt(Vector2(W*0.74, H*0.14), "After 2 undos:", 11, _PDIM, HORIZONTAL_ALIGNMENT_CENTER)
		_rune_col(W*0.74, base, remain2, SZ)

		_box(Rect2(W*0.56, H*0.64, W*0.40, H*0.22), _SDARK, _GREEN, 1.5)
		_txt(Vector2(W*0.58, H*0.66), "Wind undone ✓", 12, _GREEN)
		_txt(Vector2(W*0.58, H*0.76), "Earth undone ✓", 12, _GREEN)

	# ── BRACKETS tier diagrams ───────────────────────────────────────────────────

	func _draw_brackets_intro() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.09, H * 0.17)

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _GOLD, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "Balanced Bracket Checker — classic stack algorithm", 12,
				_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		# Balanced example
		_box(Rect2(W*0.02, H*0.14, W*0.44, H*0.22), Color(0.04,0.14,0.04), _GREEN, 1.5)
		_txt(Vector2(W*0.24, H*0.16), "( { [ ] } )", 16, _GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.24, H*0.26), "BALANCED ✓", 12, _GREEN, HORIZONTAL_ALIGNMENT_CENTER)

		# Unbalanced example
		_box(Rect2(W*0.54, H*0.14, W*0.44, H*0.22), Color(0.14,0.04,0.04), _RED, 1.5)
		_txt(Vector2(W*0.76, H*0.16), "( { [ )", 16, _RED, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.76, H*0.26), "NOT BALANCED ✗", 12, _RED, HORIZONTAL_ALIGNMENT_CENTER)

		# Rules with rune icons
		_box(Rect2(W*0.02, H*0.40, W*0.96, H*0.52), _SDARK, _SLIGHT, 1.5)
		_txt(Vector2(W*0.04, H*0.42), "The Stack Rule:", 14, _GOLD)
		_rune_img("fire", _FIRE, W*0.04, H*0.52, SZ)
		_txt(Vector2(W*0.04 + SZ + 6, H*0.54), "See  ( [ {   →   PUSH onto stack", 13, _PARCH)
		_rune_img("ice",  _ICE,  W*0.04, H*0.68, SZ)
		_txt(Vector2(W*0.04 + SZ + 6, H*0.70), "See  ) ] }   →   POP and check match!", 13, _PARCH)
		_box(Rect2(W*0.04, H*0.82, W*0.88, H*0.08), Color(0.04,0.14,0.04), _GREEN, 1.0)
		_txt(Vector2(W*0.50, H*0.84), "Stack empty at end  →  BALANCED ✓", 12,
				_GREEN, HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_brackets_algo() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.08, H * 0.15)

		_box(Rect2(W*0.02, H*0.02, W*0.96, H*0.10), _SDARK, _GOLD, 1.5)
		_txt(Vector2(W*0.50, H*0.04), "Walk through  \"([])\"  step by step:", 13,
				_GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		var steps := [
			{"ch":"(", "op":"push", "rune":"fire",  "col":_FIRE,  "stack":"[Fire]",       "ok":true},
			{"ch":"[", "op":"push", "rune":"ice",   "col":_ICE,   "stack":"[Fire, Ice]",  "ok":true},
			{"ch":"]", "op":"pop",  "rune":"ice",   "col":_ICE,   "stack":"[Fire]",       "ok":true},
			{"ch":")", "op":"pop",  "rune":"fire",  "col":_FIRE,  "stack":"[] <- empty!", "ok":true},
		]

		for i in range(steps.size()):
			var s: Dictionary = steps[i]
			var sy := H*0.14 + i * H*0.19
			var bc: Color = _GREEN if s["ok"] else _RED
			# Step box
			_box(Rect2(W*0.02, sy, W*0.58, H*0.16),
					Color(bc.r*0.08, bc.g*0.08, bc.b*0.08), bc, 1.2)
			# Bracket char
			_txt(Vector2(W*0.04, sy + H*0.04), "'%s'" % s["ch"], 16, bc)
			# Op label
			_txt(Vector2(W*0.12, sy + H*0.03), "→  %s()" % s["op"], 13,
					_GOLD if s["op"]=="push" else _BLUE)
			# Rune icon
			_rune_img(s["rune"], s["col"], W*0.30, sy + H*0.01, SZ)
			# Stack state
			_txt(Vector2(W*0.62, sy + H*0.06), "stack: %s" % s["stack"], 11, _PARCH)

		_box(Rect2(W*0.02, H*0.92, W*0.96, H*0.07), Color(0.04,0.14,0.04), _GREEN, 1.5)
		_txt(Vector2(W*0.50, H*0.94), "Stack is empty at end  →  BALANCED ✓", 12,
				_GREEN, HORIZONTAL_ALIGNMENT_CENTER)

	# ── TASK PREVIEW (last slide of every tier) ─────────────────────────────────

	func _draw_task_preview() -> void:
		var W := size.x; var H := size.y
		var SZ := minf(W * 0.10, H * 0.18)

		_txt(Vector2(W*0.50, H*0.04), "Your Runes:", 14, _GOLD, HORIZONTAL_ALIGNMENT_CENTER)

		# Row of all 6 rune images using actual textures
		var runes := [
			["fire",  _FIRE,  "Fire"],
			["ice",   _ICE,   "Ice"],
			["wind",  _WIND,  "Wind"],
			["earth", _EARTH, "Earth"],
			["dark",  _DARK,  "Dark"],
			["light", Color(0.80,0.78,0.65), "Light"],
		]
		var n := runes.size()
		var cell_w := W / float(n)
		for i in range(n):
			var cx := cell_w * (i + 0.5) - SZ * 0.5
			_rune_img(runes[i][0], runes[i][1], cx, H*0.12, SZ)
			_txt(Vector2(cx + SZ*0.5, H*0.12 + SZ + 4),
					runes[i][2], 11, runes[i][1], HORIZONTAL_ALIGNMENT_CENTER)

		# How to play — two clear instruction boxes
		_box(Rect2(W*0.02, H*0.46, W*0.46, H*0.26), Color(0.04,0.10,0.04), _GREEN, 1.5)
		_txt(Vector2(W*0.25, H*0.48), "▶  PUSH", 15, _GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.25, H*0.58), "Drag rune", 12, _PARCH, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.25, H*0.66), "onto the column", 12, _PARCH, HORIZONTAL_ALIGNMENT_CENTER)

		_box(Rect2(W*0.54, H*0.46, W*0.44, H*0.26), Color(0.10,0.08,0.02), _GOLD, 1.5)
		_txt(Vector2(W*0.76, H*0.48), "♛  POP", 15, _GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.76, H*0.58), "Click the crown", 12, _PARCH, HORIZONTAL_ALIGNMENT_CENTER)
		_txt(Vector2(W*0.76, H*0.66), "on the top rune", 12, _PARCH, HORIZONTAL_ALIGNMENT_CENTER)

		# Stack repr example
		_box(Rect2(W*0.02, H*0.76, W*0.96, H*0.22), _SDARK, Color(0.25,0.20,0.35), 1.0)
		_txt(Vector2(W*0.04, H*0.78), "stack = [Fire, Ice, Wind]", 12, _PARCH)
		_txt(Vector2(W*0.04, H*0.86), "stack[-1]  →  Wind  (top)", 12, _GREEN)
		_txt(Vector2(W*0.04, H*0.92), "stack.pop()  →  removes Wind first (LIFO)", 12, _GOLD)


# =============================================================================
#  STACK GAME  —  main class
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
#  SCENE NODE REFS
# ─────────────────────────────────────────────────────────────────────────────
@onready var _bg:          Sprite2D       = $Background
@onready var _crown_a:     Node2D         = $CrownA
@onready var _hbar_a:      ProgressBar    = $HeightBar_A
@onready var _game_tmr:    Timer          = $GameTimer
@onready var _score_lbl:   Label          = $HUD/ScoreLabel
@onready var _combo_lbl:   Label          = $HUD/ComboLabel
@onready var _timer_lbl:   Label          = $HUD/TimerLabel
@onready var _goal_lbl:    Label          = $HUD/GoalLabel
@onready var _acc_lbl:     Label          = $HUD/AccuracyLabel
@onready var _lives_row:   HBoxContainer  = $HUD/LivesRow
@onready var _hint_lbl:    Label          = $HUD/HintBox/HintLabel
@onready var _hint_box:    PanelContainer = $HUD/HintBox
@onready var _task_card:   PanelContainer = $HUD/TaskCard
@onready var _task_lbl:    Label          = $HUD/TaskCard/TaskLabel
@onready var _seq_banner:  PanelContainer = $HUD/SeqBanner
@onready var _seq_lbl:     Label          = $HUD/SeqBanner/SeqLabel
@onready var _fail_summary:PanelContainer = $HUD/FailSummary
@onready var _fail_lbl:    Label          = $HUD/FailSummary/FailLabel

# ─────────────────────────────────────────────────────────────────────────────
#  PROCEDURAL NODES
# ─────────────────────────────────────────────────────────────────────────────
var _intro_overlay: PanelContainer = null
var _intro_title:   Label          = null
var _intro_diagram: TutDiagram     = null
var _intro_body:    Label          = null
var _intro_page:    Label          = null
var _intro_back:    Button         = null
var _intro_next:    Button         = null

var _stack_disp_panel: PanelContainer = null
var _stack_disp_lbl:   Label          = null
var _op_flash_lbl:     Label          = null
var _peek_btn:         Button         = null
var _code_panel:       PanelContainer = null
var _code_lbl:         Label          = null

var _prompt_panel:    PanelContainer = null
var _prompt_q_lbl:    Label          = null
var _prompt_btns:     Array          = []
var _prompt_res_lbl:  Label          = null

var _undo_panel: PanelContainer = null
var _undo_lbl:   Label          = null

# Brackets-mode HUD
var _bracket_panel: PanelContainer = null
var _bracket_lbl:   Label          = null
var _bracket_str_lbl: Label        = null

# ─────────────────────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────────────────────
var _p:          Dictionary = {}
var _chapter_id: int        = 6

var _stack_a:   Array      = []   # Array[Dictionary] — each entry has rune data + "node" key
var _staged:    Dictionary = {}
var _staged_nd: Node2D     = null

var _is_dragging: bool    = false
var _drag_offset: Vector2 = Vector2.ZERO

var _goal_seq: Array = []; var _goal_idx: int = 0
var _current_task: String = ""; var _push_count: int = 0

var _undo_seq: Array = []; var _undo_phase: String = ""

# Brackets state
var _bracket_string:  String = ""   # e.g. "({[]})"
var _bracket_pos:     int    = 0    # current character index
var _bracket_open_map: Dictionary = {"(": ")", "[": "]", "{": "}"}
var _bracket_close_map: Dictionary = {")": "(", "]": "[", "}": "{"}
# Rune assigned per bracket type so the same open/close share a rune look
var _bracket_rune_map: Dictionary = {}  # filled in _start_game

var _intro_slides: Array = []; var _intro_page_idx: int = 0
var _intro_visible: bool = false

var _prompt_correct_idx: int = 0
var _prompt_active: bool = false
var _ops_since_prompt: int = 0
const PROMPT_INTERVAL := 5

var _stat := {
	"correct": 0, "wrong_pop": 0, "wrong_push": 0,
	"sequence_break": 0, "overflow": 0, "bracket_mismatch": 0
}
var _score: int   = 0
var _combo: int   = 0
var _lives: int   = 3
var _combo_decay: float = 0.0
const COMBO_TTL := 3.0

var _time_left: float = 0.0
var _alive:     bool  = false
var _pixel_font: Font = null

# Parallax background
var _parallax_layers: Array = []
var _bg_time:         float = 0.0

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) if ResourceLoader.exists(PATH_FONT) else null

	var tier := 0
	if has_node("/root/DifficultyManager"):
		tier = clamp(DifficultyManager.current_tier, 0, 4)   # 0-4 now
	_p          = TIER_PARAMS[tier]
	_chapter_id = 6 + tier

	_setup_bg()
	_setup_new_nodes()
	_setup_hud()
	_setup_timer()
	_setup_columns()

	_task_card.visible     = false
	_seq_banner.visible    = false
	_fail_summary.visible  = false
	_code_panel.visible    = false
	_hint_box.visible      = false

	_update_stack_display()
	_apply_castle_theme()

	if has_node("/root/AudioManager"): AudioManager.play_bgm(PATH_BGM)
	_alive = true
	_show_intro()

# ─────────────────────────────────────────────────────────────────────────────
#  RUNE NODE FACTORY
#  Creates a Node2D containing:
#    • Sprite2D  — the rune image (child index 0)
#    • Sprite2D  — the demonic shadow (child index 1), positioned at base
#    • Label     — rune name floating below (child index 2)
# ─────────────────────────────────────────────────────────────────────────────
func _make_rune_node(rdef: Dictionary, include_label: bool = true) -> Node2D:
	var root := Node2D.new()

	# ── Main rune sprite ──────────────────────────────────────────────────────
	# JPEGs are 32x32 px. Rune art occupies rows 8-30 (23px tall, 32px wide).
	# We crop to that region and use a shader to discard the near-black bg pixels.
	const CROP_X  := 0;  const CROP_Y  := 8   # start of rune art
	const CROP_W  := 32; const CROP_H  := 23  # size of rune art area
	var sprite := Sprite2D.new()
	var tpath := RUNE_BASE + (rdef["key"] as String) + ".png"
	if ResourceLoader.exists(tpath):
		sprite.texture        = load(tpath)
		sprite.region_enabled = true
		sprite.region_rect    = Rect2(CROP_X, CROP_Y, CROP_W, CROP_H)
		# Shader: discard pixels whose RGB sum < threshold (the near-black bg)
		var mat := ShaderMaterial.new()
		var sh  := Shader.new()
		sh.code = """
			shader_type canvas_item;
			uniform float threshold : hint_range(0.0,1.0) = 0.18;
			void fragment() {
				vec4 c = texture(TEXTURE, UV);
				float brightness = c.r + c.g + c.b;
				if (brightness < threshold) discard;
				COLOR = c;
			}
		"""
		mat.shader = sh
		sprite.material = mat
	else:
		var cr := ColorRect.new()
		cr.size     = Vector2(32, 32)
		cr.position = Vector2(-16, -16)
		cr.color    = rdef["color"]
		sprite.add_child(cr)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale          = RUNE_SCALE   # 32x23 px * 3 = 96x69 px rendered
	sprite.modulate       = Color.WHITE
	root.add_child(sprite)       # child index 0

	# ── Thin shadow line at base ──────────────────────────────────────────────
	var shadow := ColorRect.new()
	shadow.color    = Color(0.0, 0.0, 0.0, 0.5)
	shadow.size     = Vector2(CROP_W * RUNE_SCALE.x * 0.70, 3)
	shadow.position = Vector2(-CROP_W * RUNE_SCALE.x * 0.35,
						   CROP_H * RUNE_SCALE.y * 0.5 - 2)
	shadow.z_index  = -1
	root.add_child(shadow)       # child index 1

	# ── Name label ────────────────────────────────────────────────────────────
	if include_label:
		var lbl := Label.new()
		lbl.text = rdef["name"]
		if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", rdef["color"] as Color)
		lbl.position = Vector2(-24, 35)     # below the 69px-tall cropped rune
		root.add_child(lbl)     # child index 2

	return root

# ─────────────────────────────────────────────────────────────────────────────
#  INTRO OVERLAY
# ─────────────────────────────────────────────────────────────────────────────
func _show_intro() -> void:
	_intro_slides   = CONCEPT_SLIDES.get(_p["concept"], [])
	_intro_page_idx = 0
	_intro_visible  = true
	_intro_overlay.visible = true
	_refresh_intro_slide()

func _refresh_intro_slide() -> void:
	if _intro_slides.is_empty(): _dismiss_intro(); return
	var slide: Dictionary = _intro_slides[_intro_page_idx]
	_intro_title.text = slide.get("title", "")
	_intro_body.text  = slide.get("body",  "")

	var key: String = slide.get("diagram", "")
	_intro_diagram.visible = (key != "")
	if key != "": _intro_diagram.set_slide(key, _pixel_font)

	_intro_page.text     = "%d / %d" % [_intro_page_idx + 1, _intro_slides.size()]
	_intro_back.disabled = (_intro_page_idx == 0)
	_intro_next.text     = "Begin!" if _intro_page_idx == _intro_slides.size() - 1 else "Next ▶"

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
	_intro_visible = false
	_intro_overlay.visible = false
	_hint_box.visible = true
	_start_game()

# ─────────────────────────────────────────────────────────────────────────────
#  GAME START
# ─────────────────────────────────────────────────────────────────────────────
func _start_game() -> void:
	match _p["mode"]:
		"push_pop":
			_push_count = 0
			_show_hint("Drag a rune onto the column to PUSH it!")
			_spawn_staged_rune()

		"peek":
			_show_hint("Read the task card and perform the correct operation.")
			_spawn_staged_rune()
			_issue_peek_task()

		"overflow":
			_seq_banner.visible = true
			_show_hint("Push in REVERSE of the goal order.\nDon't let the stack overflow!")
			_spawn_staged_rune()

		"undo":
			_undo_panel.visible = true
			_show_hint("Watch the spells cast...\nThen undo them all in reverse order!")
			_start_undo_round()

		"brackets":
			_bracket_panel.visible = true
			_show_hint("Match the brackets!\nPush opens (drag), pop closes (♛ crown).")
			_setup_bracket_rune_map()
			_issue_bracket_task()

# ─────────────────────────────────────────────────────────────────────────────
#  SETUP
# ─────────────────────────────────────────────────────────────────────────────
func _setup_bg() -> void:
	# Hide the placeholder scene Sprite2D
	if is_instance_valid(_bg): _bg.visible = false
	_parallax_layers.clear()

	# ── Layer definitions (back → front) ─────────────────────────────────────
	# cave_0003_color = solid teal fill  → static base, no scroll
	# cave_0002_back  = large formations → slowest scroll
	# cave_0001_mid   = medium stalactites → medium scroll
	# cave_0000_front = tall narrow stalactites → fastest scroll (foreground)
	const BASE_PATH := "res://assets/art/stack/bg/"
	var layers: Array[Dictionary] = [
		{
			"file":  "cave_0003_color.png",
			"z":     -20,
			"speed": 0.0,    # static — solid bg colour
			"alpha": 1.00,
		},
		{
			"file":  "cave_0002_back.png",
			"z":     -17,
			"speed": 6.0,
			"alpha": 0.88,
		},
		{
			"file":  "cave_0001_mid.png",
			"z":     -14,
			"speed": 14.0,
			"alpha": 0.92,
		},
		{
			"file":  "cave_0000_front.png",
			"z":     -11,
			"speed": 28.0,
			"alpha": 1.00,
		},
	]

	for d in layers:
		var path: String = BASE_PATH + (d["file"] as String)
		if not ResourceLoader.exists(path): continue
		var tex: Texture2D = load(path) as Texture2D
		if tex == null: continue

		var tw := float(tex.get_width())
		var th := float(tex.get_height())

		# Scale to fill 1280×720 exactly
		var sx := 1280.0 / tw
		var sy := 720.0  / th

		# For scrolling layers we need two copies side-by-side for seamless wrap
		var speed: float = d["speed"] as float
		var copies := 2 if speed > 0.0 else 1

		for c in range(copies):
			var sp := Sprite2D.new()
			sp.texture        = tex
			sp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			sp.centered       = false
			sp.scale          = Vector2(sx, sy)
			sp.modulate.a     = d["alpha"] as float
			sp.z_index        = d["z"] as int
			sp.position       = Vector2(c * 1280.0, 0.0)
			sp.set_meta("scroll_speed", speed)
			sp.set_meta("copy_index",   c)
			add_child(sp)
			_parallax_layers.append(sp)

	# Dark vignette overlay — keeps game elements readable over the bright whites
	var ov := ColorRect.new()
	ov.color    = Color(0.0, 0.0, 0.0, 0.48)
	ov.size     = Vector2(1280, 720)
	ov.position = Vector2.ZERO
	ov.z_index  = -10
	add_child(ov)

func _setup_hud() -> void:
	var lbls: Array = [
		_score_lbl, _combo_lbl, _timer_lbl, _goal_lbl, _acc_lbl,
		_hint_lbl, _task_lbl, _seq_lbl, _fail_lbl,
		_stack_disp_lbl, _op_flash_lbl, _prompt_q_lbl, _prompt_res_lbl,
		_bracket_lbl, _bracket_str_lbl,
	]
	for l in lbls:
		if not is_instance_valid(l): continue
		if _pixel_font: l.add_theme_font_override("font", _pixel_font)
		l.add_theme_font_size_override("font_size", 16)
	for b: Button in _prompt_btns:
		if not is_instance_valid(b): continue
		if _pixel_font: b.add_theme_font_override("font", _pixel_font)
		b.add_theme_font_size_override("font_size", 15)
	if is_instance_valid(_code_lbl):
		_code_lbl.add_theme_font_size_override("font_size", 14)
	if is_instance_valid(_stack_disp_lbl):
		_stack_disp_lbl.add_theme_font_size_override("font_size", 14)
	if is_instance_valid(_op_flash_lbl):
		_op_flash_lbl.add_theme_font_size_override("font_size", 22)
	if is_instance_valid(_prompt_q_lbl):
		_prompt_q_lbl.add_theme_font_size_override("font_size", 18)

	_score_lbl.text = "Score: 0"
	_combo_lbl.text = ""
	_acc_lbl.text   = "Accuracy: -"
	_goal_lbl.text  = _goal_text()
	_timer_lbl.visible = _p["time_limit"] > 0
	if _p["time_limit"] > 0:
		_time_left = _p["time_limit"]
		_timer_lbl.text = "⏱ %d" % int(_time_left)
	_refresh_lives()

	# ── Pause button (top-right HUD) — transparent bg, gold ⏸ glyph ──────────
	var hud := $HUD as CanvasLayer
	const PAUSE_ICON := "res://assets/art/ui/pause_icon.png"
	if ResourceLoader.exists(PAUSE_ICON):
		var tb := TextureButton.new()
		tb.texture_normal          = load(PAUSE_ICON) as Texture2D
		tb.ignore_texture_size     = false
		tb.stretch_mode            = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		tb.custom_minimum_size     = Vector2(44, 44)
		tb.position                = Vector2(1228, 4)
		tb.z_index                 = 95
		tb.modulate                = Color(0.95, 0.78, 0.25, 1.0)
		tb.pressed.connect(func():
			var pm := get_node_or_null("PauseMenu")
			if pm and pm.has_method("toggle"): pm.toggle()
		)
		hud.add_child(tb)
	else:
		# Fully transparent button — only the ⏸ glyph shows, no box at all
		var fb := Button.new()
		fb.text    = "⏸"
		fb.position = Vector2(1220, 2)
		fb.size     = Vector2(52, 40)
		fb.z_index  = 95
		if _pixel_font: fb.add_theme_font_override("font", _pixel_font)
		fb.add_theme_font_size_override("font_size", 26)   # larger glyph
		# All states fully transparent — nothing but the glyph
		var _transparent := StyleBoxEmpty.new()
		fb.add_theme_stylebox_override("normal",   _transparent)
		fb.add_theme_stylebox_override("hover",    _transparent)
		fb.add_theme_stylebox_override("pressed",  _transparent)
		fb.add_theme_stylebox_override("focus",    _transparent)
		fb.add_theme_stylebox_override("disabled", _transparent)
		fb.add_theme_color_override("font_color",         CastleTheme.C_GOLD)
		fb.add_theme_color_override("font_hover_color",   Color(1.0, 0.95, 0.55))
		fb.add_theme_color_override("font_pressed_color", CastleTheme.C_GOLD_DIM)
		fb.pressed.connect(func():
			var pm := get_node_or_null("PauseMenu")
			if pm and pm.has_method("toggle"): pm.toggle()
		)
		hud.add_child(fb)

	# ── Wire "How to Play" → reopen intro slides ──────────────────────────────
	var pm := get_node_or_null("PauseMenu")
	if pm and pm.has_signal("howto_requested"):
		pm.howto_requested.connect(_reopen_intro)

func _reopen_intro() -> void:
	_intro_page_idx = 0
	_intro_slides   = CONCEPT_SLIDES.get(_p["concept"], [])
	if not _intro_slides.is_empty():
		_intro_overlay.visible = true
		_refresh_intro_slide()

func _goal_text() -> String:
	match _p["mode"]:
		"push_pop":  return "Push & pop %d times"     % _p["target_correct"]
		"peek":      return "Complete %d tasks"        % _p["target_correct"]
		"overflow":  return "Complete %d sequences"    % _p["target_correct"]
		"undo":      return "Undo %d spell sequences"  % _p["target_correct"]
		"brackets":  return "Solve %d bracket strings" % _p["target_correct"]
	return ""

func _setup_timer() -> void:
	if _p["time_limit"] > 0:
		_game_tmr.wait_time = 1.0
		_game_tmr.one_shot  = false
		_game_tmr.timeout.connect(_tick_clock)
		_game_tmr.start()

func _setup_columns() -> void:
	_hbar_a.max_value = _p["max_height"]
	_hbar_a.value     = 0
	_hbar_a.add_theme_stylebox_override("background", CastleTheme.progress_bg())
	_hbar_a.add_theme_stylebox_override("fill",       CastleTheme.progress_fill())
	_add_column_shaft(COL_A_X)
	_bob_crown(_crown_a)

func _bob_crown(crown: Node2D) -> void:
	if not is_instance_valid(crown): return
	crown.visible = false
	var tw := crown.create_tween().set_loops()
	tw.tween_property(crown, "position:y", crown.position.y - 10, 0.5)
	tw.tween_property(crown, "position:y", crown.position.y,      0.5)

func _add_column_shaft(col_x: float) -> void:
	# Runes are 96px wide at scale 3; shaft is 120px wide (12px padding each side).
	const SHAFT_W := 112.0  # rune is 96px wide (32px*3) + 8px padding each side
	var h: float = float(_p["max_height"]) * SLOT_H + 80.0
	var x: float = col_x - SHAFT_W / 2.0
	var y: float = BASE_Y - h + 24.0

	# Outer dark border (gives depth)
	var border := ColorRect.new()
	border.color    = Color(0.08, 0.06, 0.12)
	border.size     = Vector2(SHAFT_W + 8, h + 8)
	border.position = Vector2(x - 4, y - 4)
	border.z_index  = -3
	add_child(border)

	# Main shaft background — dark stone
	var bg := ColorRect.new()
	bg.color    = Color(0.10, 0.08, 0.14)
	bg.size     = Vector2(SHAFT_W, h)
	bg.position = Vector2(x, y)
	bg.z_index  = -2
	add_child(bg)

	# Side pillars (stone texture lines)
	for xo: float in [0.0, SHAFT_W - 4.0]:
		var e := ColorRect.new()
		e.color    = Color(0.22, 0.18, 0.30)
		e.size     = Vector2(4, h)
		e.position = Vector2(x + xo, y)
		e.z_index  = -1
		add_child(e)

	# Gold battlement cap at top
	var cap := ColorRect.new()
	cap.color    = CastleTheme.C_GOLD
	cap.size     = Vector2(SHAFT_W + 8, 4)
	cap.position = Vector2(x - 4, y - 4)
	cap.z_index  = -1
	add_child(cap)

	# Bottom base plate
	var base := ColorRect.new()
	base.color    = Color(0.18, 0.14, 0.24)
	base.size     = Vector2(SHAFT_W + 8, 8)
	base.position = Vector2(x - 4, BASE_Y + 4)
	base.z_index  = -1
	add_child(base)

	# Torch accent top-left
	var torch := ColorRect.new()
	torch.color    = CastleTheme.C_TORCH
	torch.size     = Vector2(6, 12)
	torch.position = Vector2(x + 6, y + 8)
	torch.z_index  = -1
	add_child(torch)

# ─────────────────────────────────────────────────────────────────────────────
#  PROCEDURAL NODE CONSTRUCTION
# ─────────────────────────────────────────────────────────────────────────────
func _setup_new_nodes() -> void:
	var hud := $HUD as CanvasLayer

	# ── Intro overlay ─────────────────────────────────────────────────────────
	_intro_overlay = _panel_nd("IntroOverlay", 80, CastleTheme.royal_panel())
	_intro_overlay.visible = false
	_intro_overlay.set_offset(SIDE_LEFT,   120)
	_intro_overlay.set_offset(SIDE_TOP,     50)
	_intro_overlay.set_offset(SIDE_RIGHT, 1160)
	_intro_overlay.set_offset(SIDE_BOTTOM, 670)
	hud.add_child(_intro_overlay)

	var mg := MarginContainer.new()
	for s in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		mg.add_theme_constant_override(
			["margin_left","margin_right","margin_top","margin_bottom"][s], 22)
	_intro_overlay.add_child(mg)

	var ivb := VBoxContainer.new()
	ivb.add_theme_constant_override("separation", 12)
	ivb.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	ivb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mg.add_child(ivb)

	_intro_title = _lbl("", 22, CastleTheme.C_GOLD)
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ivb.add_child(_intro_title)

	_intro_diagram = TutDiagram.new()
	_intro_diagram.custom_minimum_size      = Vector2(0, 200)
	_intro_diagram.size_flags_horizontal    = Control.SIZE_EXPAND_FILL
	_intro_diagram.visible = false
	ivb.add_child(_intro_diagram)

	_intro_body = _lbl("", 14, CastleTheme.C_PARCHMENT)
	_intro_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# EXPAND_FILL pushes the nav buttons to the bottom of the panel
	_intro_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ivb.add_child(_intro_body)

	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 20)
	# Nav row sticks at bottom — give VBox expansion to the body above
	nav.size_flags_vertical = Control.SIZE_SHRINK_END
	ivb.add_child(nav)

	_intro_back = _btn("◀ Back", CastleTheme.btn_normal(), CastleTheme.btn_hover(),
						CastleTheme.C_PARCHMENT_DIM)
	_intro_back.pressed.connect(_on_intro_back)
	nav.add_child(_intro_back)

	_intro_page = _lbl("", 14, CastleTheme.C_PARCHMENT_DIM)
	_intro_page.custom_minimum_size          = Vector2(70, 0)
	_intro_page.horizontal_alignment         = HORIZONTAL_ALIGNMENT_CENTER
	nav.add_child(_intro_page)

	_intro_next = _btn("Next ▶", CastleTheme.stone_panel(CastleTheme.C_GOLD, 2),
						CastleTheme.btn_hover(), CastleTheme.C_GOLD)
	_intro_next.pressed.connect(_on_intro_next)
	nav.add_child(_intro_next)

	# ── Peek button ───────────────────────────────────────────────────────────
	_peek_btn = _btn("👁 Peek Top", CastleTheme.btn_info_normal(),
					  CastleTheme.btn_info_hover(), CastleTheme.C_SAPPHIRE)
	_peek_btn.visible = _p["mode"] in ["peek", "overflow", "undo"]
	_peek_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_peek_btn.set_offset(SIDE_LEFT,   10)
	_peek_btn.set_offset(SIDE_TOP,   114)
	_peek_btn.set_offset(SIDE_RIGHT, 155)
	_peek_btn.set_offset(SIDE_BOTTOM,142)
	_peek_btn.pressed.connect(_on_peek_pressed)
	hud.add_child(_peek_btn)

	# ── Live stack display ────────────────────────────────────────────────────
	_stack_disp_panel = _panel_nd("StackDisplay", 15,
								   CastleTheme.stone_panel(CastleTheme.C_STONE_LIGHT, 1))
	_stack_disp_panel.set_offset(SIDE_LEFT,   10)
	_stack_disp_panel.set_offset(SIDE_TOP,   150)
	_stack_disp_panel.set_offset(SIDE_RIGHT, 225)
	_stack_disp_panel.set_offset(SIDE_BOTTOM,590)
	hud.add_child(_stack_disp_panel)
	_stack_disp_lbl = _lbl("", 14, CastleTheme.C_PARCHMENT_DIM)
	_stack_disp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack_disp_panel.add_child(_stack_disp_lbl)

	# ── Op flash ─────────────────────────────────────────────────────────────
	_op_flash_lbl = _lbl("", 22, CastleTheme.C_GOLD)
	_op_flash_lbl.modulate.a = 0.0
	_op_flash_lbl.z_index    = 55
	_op_flash_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_op_flash_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_op_flash_lbl.set_offset(SIDE_LEFT,   330)
	_op_flash_lbl.set_offset(SIDE_TOP,    205)
	_op_flash_lbl.set_offset(SIDE_RIGHT,  950)
	_op_flash_lbl.set_offset(SIDE_BOTTOM, 255)
	hud.add_child(_op_flash_lbl)

	# ── Code panel ────────────────────────────────────────────────────────────
	_code_panel = _panel_nd("CodePanel", 60, CastleTheme.code_panel())
	_code_panel.visible = false
	_code_panel.set_offset(SIDE_LEFT,   140)
	_code_panel.set_offset(SIDE_TOP,     90)
	_code_panel.set_offset(SIDE_RIGHT, 1140)
	_code_panel.set_offset(SIDE_BOTTOM, 630)
	hud.add_child(_code_panel)
	_code_lbl = _lbl("", 14, CastleTheme.C_PARCHMENT_DIM)
	_code_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_code_panel.add_child(_code_lbl)

	# ── Comprehension prompt ──────────────────────────────────────────────────
	_prompt_panel = _panel_nd("Prompt", 70, CastleTheme.royal_panel())
	_prompt_panel.visible = false
	_prompt_panel.set_offset(SIDE_LEFT,   200)
	_prompt_panel.set_offset(SIDE_TOP,    180)
	_prompt_panel.set_offset(SIDE_RIGHT, 1080)
	_prompt_panel.set_offset(SIDE_BOTTOM, 520)
	hud.add_child(_prompt_panel)

	var pvb := VBoxContainer.new()
	pvb.add_theme_constant_override("separation", 14)
	_prompt_panel.add_child(pvb)

	_prompt_q_lbl = _lbl("", 18, CastleTheme.C_PARCHMENT)
	_prompt_q_lbl.autowrap_mode           = TextServer.AUTOWRAP_WORD_SMART
	_prompt_q_lbl.horizontal_alignment    = HORIZONTAL_ALIGNMENT_CENTER
	pvb.add_child(_prompt_q_lbl)

	var pbrow := HBoxContainer.new()
	pbrow.alignment = BoxContainer.ALIGNMENT_CENTER
	pbrow.add_theme_constant_override("separation", 20)
	pvb.add_child(pbrow)

	_prompt_btns.clear()
	for i in range(3):
		var b := _btn("?", CastleTheme.btn_normal(), CastleTheme.btn_hover(),
					  CastleTheme.C_PARCHMENT)
		b.custom_minimum_size = Vector2(200, 48)
		b.pressed.connect(_on_prompt_btn.bind(i))
		_prompt_btns.append(b)
		pbrow.add_child(b)

	_prompt_res_lbl = _lbl("", 16, CastleTheme.C_PARCHMENT)
	_prompt_res_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_prompt_res_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_res_lbl.visible = false
	pvb.add_child(_prompt_res_lbl)

	# ── Undo history ──────────────────────────────────────────────────────────
	_undo_panel = _panel_nd("UndoHistory", 15, CastleTheme.scroll_panel())
	_undo_panel.visible = false
	_undo_panel.set_offset(SIDE_LEFT,   820)
	_undo_panel.set_offset(SIDE_TOP,    120)
	_undo_panel.set_offset(SIDE_RIGHT, 1270)
	_undo_panel.set_offset(SIDE_BOTTOM, 400)
	hud.add_child(_undo_panel)
	_undo_lbl = _lbl("Cast history:\n(nothing yet)", 14, CastleTheme.C_PARCHMENT)
	_undo_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_undo_panel.add_child(_undo_lbl)

	# ── Bracket panel ─────────────────────────────────────────────────────────
	_bracket_panel = _panel_nd("BracketPanel", 15, CastleTheme.scroll_panel())
	_bracket_panel.visible = false
	_bracket_panel.set_offset(SIDE_LEFT,   820)
	_bracket_panel.set_offset(SIDE_TOP,    120)
	_bracket_panel.set_offset(SIDE_RIGHT, 1270)
	_bracket_panel.set_offset(SIDE_BOTTOM, 450)
	hud.add_child(_bracket_panel)

	var bvb := VBoxContainer.new()
	bvb.add_theme_constant_override("separation", 8)
	_bracket_panel.add_child(bvb)

	_bracket_lbl = _lbl("BRACKET STRING", 13, CastleTheme.C_PARCHMENT_DIM)
	bvb.add_child(_bracket_lbl)
	_bracket_str_lbl = _lbl("", 22, CastleTheme.C_GOLD)
	_bracket_str_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bvb.add_child(_bracket_str_lbl)

# ── Node factory helpers ──────────────────────────────────────────────────────
func _lbl(text: String, sz: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if _pixel_font:
		l.add_theme_font_override("font", _pixel_font)
		l.add_theme_font_size_override("font_size", sz)
	return l

func _btn(text: String, n: StyleBoxFlat, h: StyleBoxFlat, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_stylebox_override("normal",  n)
	b.add_theme_stylebox_override("hover",   h)
	b.add_theme_stylebox_override("pressed", CastleTheme.btn_pressed())
	b.add_theme_color_override("font_color",       color)
	b.add_theme_color_override("font_hover_color", CastleTheme.C_GOLD)
	if _pixel_font:
		b.add_theme_font_override("font", _pixel_font)
		b.add_theme_font_size_override("font_size", 15)
	return b

func _panel_nd(nm: String, z: int, style: StyleBoxFlat) -> PanelContainer:
	var p := PanelContainer.new()
	p.name    = nm
	p.z_index = z
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.add_theme_stylebox_override("panel", style)
	return p

# ─────────────────────────────────────────────────────────────────────────────
#  CASTLE THEME
# ─────────────────────────────────────────────────────────────────────────────
func _apply_castle_theme() -> void:
	_hint_box.add_theme_stylebox_override("panel",     CastleTheme.alcove_panel())
	_task_card.add_theme_stylebox_override("panel",    CastleTheme.royal_panel())
	_seq_banner.add_theme_stylebox_override("panel",   CastleTheme.scroll_panel())
	_fail_summary.add_theme_stylebox_override("panel", CastleTheme.stone_panel(CastleTheme.C_GOLD, 3))
	for l: Label in [_score_lbl, _combo_lbl, _timer_lbl, _goal_lbl, _acc_lbl]:
		if is_instance_valid(l):
			l.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT)
	if is_instance_valid(_hint_lbl): _hint_lbl.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT_DIM)
	if is_instance_valid(_task_lbl): _task_lbl.add_theme_color_override("font_color", CastleTheme.C_GOLD)
	if is_instance_valid(_seq_lbl):  _seq_lbl.add_theme_color_override("font_color",  CastleTheme.C_PARCHMENT)
	if is_instance_valid(_fail_lbl): _fail_lbl.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT)

# ─────────────────────────────────────────────────────────────────────────────
#  PROCESS & INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if not _alive: return
	if _combo > 0:
		_combo_decay -= delta
		if _combo_decay <= 0.0:
			_combo = 0
			_combo_lbl.text = ""

	# ── Cave parallax scroll ──────────────────────────────────────────────────
	_bg_time += delta
	for sp in _parallax_layers:
		if not is_instance_valid(sp): continue
		var speed: float = sp.get_meta("scroll_speed") as float
		if speed == 0.0: continue   # static base layer
		var copy_idx: int = sp.get_meta("copy_index") as int
		# Move left continuously
		sp.position.x -= speed * delta
		# Seamless wrap: when copy 0 goes fully off-screen left, jump it right
		# of copy 1 (which is at position.x + 1280), keeping a gapless loop
		if sp.position.x <= -1280.0:
			sp.position.x += 1280.0 * 2.0

func _on_press(pos: Vector2) -> void:
	# If player must pop first, block dragging and redirect
	if _current_task == "must_pop":
		if _can_pop(_stack_a) and _top_nd(_stack_a).global_position.distance_to(pos) < HIT_R:
			_current_task = ""
			_pop(_stack_a)
			# After pop, spawn the next rune
			await get_tree().create_timer(0.4).timeout
			_maybe_show_comprehension_prompt()
			await get_tree().create_timer(0.2).timeout
			_spawn_staged_rune()
		else:
			_show_hint("Click the ♛ crown rune on top\nof the stack to POP it!")
			if _can_pop(_stack_a): _pulse(_top_nd(_stack_a), COL_PEEK)
		return

	# Dragging the staged rune
	if _staged_nd != null and _staged_nd.global_position.distance_to(pos) < HIT_R:
		if _current_task == "pop":
			_show_hint("Task says POP first!\nClick the ♛ crown.")
			return
		_is_dragging  = true
		_drag_offset  = _staged_nd.global_position - pos
		_staged_nd.z_index = 50
		return

	# Clicking the top (crown) rune to pop
	if _can_pop(_stack_a) and _top_nd(_stack_a).global_position.distance_to(pos) < HIT_R:
		_pop(_stack_a)
		return

	# Clicking a non-top rune (LIFO violation teaching moment)
	_check_non_top_click(pos)

# ─────────────────────────────────────────────────────────────────────────────
#  SPAWN STAGED RUNE
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_staged_rune() -> void:
	if not _alive: return
	# In brackets mode the staged rune is set by _issue_bracket_task()
	if _p["mode"] == "brackets": return

	var rdef: Dictionary = RUNES[randi() % RUNES.size()]
	var nd := _make_rune_node(rdef, true)
	nd.scale   = Vector2.ONE
	nd.z_index = 20
	add_child(nd)
	# Drop in from above the stage position
	var stage_drop_start := Vector2(STAGE_POS.x, STAGE_POS.y - 300.0)
	nd.global_position = stage_drop_start
	var tw := nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(nd, "global_position", STAGE_POS, 0.22)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "scale", Vector2(1.2, 0.8), 0.06)
	tw.tween_property(nd, "scale", Vector2.ONE, 0.08)

	_staged    = rdef.duplicate()
	_staged_nd = nd

	if _p["mode"] == "peek": _issue_peek_task()

# ─────────────────────────────────────────────────────────────────────────────
#  PUSH
# ─────────────────────────────────────────────────────────────────────────────
func _try_push(drop_pos: Vector2) -> void:
	if _staged_nd == null: return

	# Must land close enough to the column top slot
	if drop_pos.distance_to(_col_top_pos(_stack_a, COL_A_X)) >= SNAP_DIST:
		_return_staged_to_stage()
		return

	# Overflow guard
	if _stack_a.size() >= _p["max_height"]:
		_stat["overflow"] += 1
		_apply_wrong(
			_staged_nd, _p["penalty"],
			"Stack overflow! (%d/%d)\nPop before pushing." % [_stack_a.size(), _p["max_height"]]
		)
		_return_staged_to_stage()
		return

	# Peek-mode task guard
	if _p["mode"] == "peek" and _current_task == "pop":
		_stat["wrong_push"] += 1
		_apply_wrong(_staged_nd, _p["penalty"], "Task says POP first!")
		_return_staged_to_stage()
		return

	_do_push(_staged_nd, _staged, _stack_a, COL_A_X)
	_staged_nd = null

func _do_push(nd: Node2D, rdef: Dictionary, stack: Array, col_x: float) -> void:
	var dest := _col_top_pos(stack, col_x)
	# Fall from above the column top — rune drops in and squish-bounces on landing
	var fall_start := Vector2(dest.x, dest.y - 420.0)
	nd.global_position = fall_start
	nd.scale = Vector2.ONE
	# Phase 1: fall straight down fast
	var tw := nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(nd, "global_position", dest, 0.28)
	# Phase 2: squash on impact (scale x wide, y short)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "scale", Vector2(1.35, 0.65), 0.07)
	# Phase 3: stretch back up (overshoot)
	tw.tween_property(nd, "scale", Vector2(0.85, 1.20), 0.07)
	# Phase 4: settle to normal
	tw.tween_property(nd, "scale", Vector2.ONE, 0.10)

	var entry := rdef.duplicate()
	entry["node"] = nd
	stack.append(entry)
	# Hide the name label once rune is stacked — label gap breaks visual stacking
	if nd.get_child_count() >= 3:
		nd.get_child(2).visible = false

	_apply_correct(nd, 10)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_PUSH)
	_flash_op_call('stack.push("%s")' % entry["name"], COL_TOP)
	_ops_since_prompt += 1
	_push_count += 1
	_update_stack_visuals()
	_dismiss_task_card()

	if _p["mode"] == "overflow" and _goal_seq.is_empty() and _stack_a.size() >= 3:
		_generate_goal()

	# PUSH_POP tier: after every 2 pushes, force the player to pop
	if _p["mode"] == "push_pop" and _push_count % 2 == 0 and not _stack_a.is_empty():
		_show_hint("Now POP it!\nClick the ♛ crown rune on top of the stack.")
		_flash_op_call("Try: stack.pop()", COL_PEEK)
		_current_task = "must_pop"
		return   # don't spawn next rune until they pop

	_maybe_show_comprehension_prompt()
	await get_tree().create_timer(0.3).timeout
	_spawn_staged_rune()

func _return_staged_to_stage() -> void:
	if _staged_nd == null: return
	_staged_nd.create_tween() \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT) \
		.tween_property(_staged_nd, "global_position", STAGE_POS, 0.3)

# ─────────────────────────────────────────────────────────────────────────────
#  POP
# ─────────────────────────────────────────────────────────────────────────────
func _pop(stack: Array) -> void:
	if stack.is_empty(): return

	var entry := stack.back() as Dictionary
	var nd    := entry["node"] as Node2D

	# Peek-mode task guard
	if _p["mode"] == "peek" and _current_task == "push":
		_stat["wrong_pop"] += 1
		_apply_wrong(nd, _p["penalty"], "Task says PUSH!")
		return

	# Overflow sequence validation
	if _p["mode"] == "overflow" and not _goal_seq.is_empty():
		var exp: String = _goal_seq[_goal_idx]
		if entry["name"] != exp:
			_stat["sequence_break"] += 1
			_apply_wrong(nd, _p["penalty"],
				"Wrong order!\nExpected: %s\nYou popped: %s\n\nLIFO: plan push order in reverse!" \
				% [exp, entry["name"]])
			_update_seq_banner()
			return
		_goal_idx += 1
		if _goal_idx >= _goal_seq.size():
			_goal_seq.clear()
			_goal_idx = 0
			_seq_banner.visible = false
			_show_hint("✓ Sequence complete!")
			await get_tree().create_timer(1.2).timeout
			_seq_banner.visible = true

	# Undo-mode sequence check
	if _p["mode"] == "undo" and _undo_phase == "undoing":
		var exp_name: String = stack.back()["name"]
		if entry["name"] != exp_name:
			_stat["sequence_break"] += 1
			_apply_wrong(nd, _p["penalty"], "Wrong undo order!\nPop the MOST RECENT spell first.")
			return

	_do_pop(stack)

func _do_pop(stack: Array) -> void:
	var raw   = stack.pop_back()
	if typeof(raw) != TYPE_DICTIONARY: return   # safety guard
	var entry: Dictionary = raw as Dictionary
	var nd    := entry["node"] as Node2D

	_apply_correct(nd, 15)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_POP)
	_flash_op_call('stack.pop()  ->  "%s"' % entry["name"], COL_PEEK)
	if _p["mode"] == "push_pop":
		_show_hint("LIFO: Last In, First Out!\n\"%s\" was pushed last — it popped first.\n\nNow drag another rune to PUSH!" % entry["name"])
	_ops_since_prompt += 1
	_update_stack_visuals()
	_dismiss_task_card()

	# Animate rune flying off
	var tw := nd.create_tween()
	tw.tween_property(nd, "global_position", nd.global_position + Vector2(0, -80), 0.25)
	tw.parallel().tween_property(nd, "modulate:a", 0.0, 0.25)
	tw.tween_callback(nd.queue_free)

	if _p["mode"] == "undo" and _undo_phase == "undoing" and stack.is_empty():
		await _on_undo_round_complete()

# ─────────────────────────────────────────────────────────────────────────────
#  PEEK MODE
# ─────────────────────────────────────────────────────────────────────────────
func _on_peek_pressed() -> void:
	if not _alive or _prompt_active: return
	if _stack_a.is_empty():
		_show_hint("Stack is empty!\nisEmpty() → true\nPeeking on empty = error in real code.")
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)
		if _p["mode"] == "peek" and _current_task == "isempty":
			_apply_correct(null, 10)
			await get_tree().create_timer(0.5).timeout
			_issue_peek_task()
		return

	var top := _stack_a.back() as Dictionary
	var nd  := top["node"] as Node2D
	_pulse(nd, COL_PEEK)
	_float(nd, "👁 %s" % top["name"], COL_PEEK)
	_flash_op_call('stack[-1]  →  "%s"  (stack unchanged)' % top["name"], COL_PEEK)
	_show_hint('Peek → "%s" is on top.\nSize = %d — stack UNCHANGED.' % [top["name"], _stack_a.size()])

	if _p["mode"] == "peek" and _current_task == "peek":
		_apply_correct(nd, 12)
		_ops_since_prompt += 1
		await _maybe_show_comprehension_prompt()
		await get_tree().create_timer(0.5).timeout
		_issue_peek_task()

func _issue_peek_task() -> void:
	_push_count += 1
	if _stack_a.is_empty():
		_current_task = "isempty"
		_show_task_card("Stack is EMPTY!\nisEmpty() → true\nPeek to see the error, or push a rune.")
	elif _push_count % 3 == 0:
		_current_task = "pop"
		_show_task_card("⚠ POP the top rune!\nClick the ♛ crown rune.")
	elif _push_count % 3 == 1:
		_current_task = "peek"
		_show_task_card("👁 PEEK at the top!\nClick the Peek button.")
	else:
		_current_task = "push"
		_show_task_card("▶ PUSH a rune!\nDrag the staged rune onto the column.")

func _show_task_card(text: String) -> void:
	_task_card.visible = true
	_task_lbl.text = text
	var tw := _task_card.create_tween()
	tw.tween_property(_task_card, "modulate", COL_TOP,   0.1)
	tw.tween_property(_task_card, "modulate", COL_WHITE, 0.4)

func _dismiss_task_card() -> void:
	_task_card.visible = false
	_current_task = ""

# ─────────────────────────────────────────────────────────────────────────────
#  OVERFLOW MODE
# ─────────────────────────────────────────────────────────────────────────────
func _generate_goal() -> void:
	_goal_seq.clear()
	_goal_idx = 0
	var count := mini(_stack_a.size(), 3)
	for i in range(_stack_a.size() - 1, _stack_a.size() - 1 - count, -1):
		_goal_seq.append(_stack_a[i]["name"])
	_seq_banner.visible = true
	_update_seq_banner()
	_show_task_card("SEQUENCE GOAL!\nPop in order: %s" % " → ".join(_goal_seq))

func _update_seq_banner() -> void:
	if _goal_seq.is_empty():
		_seq_lbl.text = "No active sequence"
		return
	var parts: Array = []
	for i in range(_goal_seq.size()):
		if   i < _goal_idx:  parts.append("✓" + _goal_seq[i])
		elif i == _goal_idx: parts.append("▶" + _goal_seq[i] + "◀")
		else:                parts.append("  " + _goal_seq[i])
	_seq_lbl.text = "Goal: " + " → ".join(parts)

func _check_non_top_click(pos: Vector2) -> void:
	for i in range(_stack_a.size() - 1):
		var nd := _stack_a[i]["node"] as Node2D
		if is_instance_valid(nd) and nd.global_position.distance_to(pos) < HIT_R:
			_stat["wrong_pop"] += 1
			_apply_wrong(nd, _p["penalty"], "LIFO Violation!\nOnly the TOP rune (♛) can be removed.")
			if _can_pop(_stack_a): _pulse(_top_nd(_stack_a), COL_TOP)
			return

# ─────────────────────────────────────────────────────────────────────────────
#  UNDO MODE
# ─────────────────────────────────────────────────────────────────────────────
func _start_undo_round() -> void:
	_undo_seq.clear()
	for i in range(4):
		_undo_seq.append(RUNES[randi() % RUNES.size()].duplicate())
	_undo_phase = "casting"
	_undo_lbl.text = "Cast history:\n(casting...)"
	_show_hint("Watch the spells being cast...")
	await _auto_push_undo_seq()

func _auto_push_undo_seq() -> void:
	for rdef: Dictionary in _undo_seq:
		if not _alive: return
		var nd := _make_rune_node(rdef, false)
		nd.scale   = RUNE_SCALE
		nd.z_index = 20
		add_child(nd)
		nd.global_position = STAGE_POS

		var dest_undo := _col_top_pos(_stack_a, COL_A_X)
		var fall_undo := Vector2(dest_undo.x, dest_undo.y - 420.0)
		nd.global_position = fall_undo
		nd.scale = Vector2.ONE
		var tw := nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tw.tween_property(nd, "global_position", dest_undo, 0.28)
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(nd, "scale", Vector2(1.35, 0.65), 0.07)
		tw.tween_property(nd, "scale", Vector2(0.85, 1.20), 0.07)
		tw.tween_property(nd, "scale", Vector2.ONE, 0.10)
		await tw.finished

		var entry := rdef.duplicate()
		entry["node"] = nd
		_stack_a.append(entry)
		_flash_op_call('stack.push("%s")  ← CAST' % rdef["name"], rdef["color"] as Color)
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_PUSH)
		_update_stack_visuals()

		var lines: Array = ["Cast history:"]
		for e: Dictionary in _stack_a:
			lines.append("  ▶ " + (e["name"] as String))
		_undo_lbl.text = "\n".join(lines)
		await get_tree().create_timer(0.6).timeout

	_undo_phase = "undoing"
	_show_hint("Now UNDO all spells!\nClick the ♛ crown rune to pop each one.")
	_show_task_card("UNDO all %d spells in reverse order!" % _undo_seq.size())

func _on_undo_round_complete() -> void:
	_dismiss_task_card()
	_apply_correct(null, 25)
	_undo_lbl.text = "Cast history:\n(all undone! ✓)"
	_show_hint("✓ All spells undone!\nLIFO = automatic perfect undo order.")
	_flash_op_call("All edits reversed — undo complete!", COL_TOP)
	if _stat["correct"] >= _p["target_correct"]:
		await get_tree().create_timer(1.5).timeout
		_end_game(true)
		return
	await get_tree().create_timer(2.0).timeout
	_start_undo_round()

# ─────────────────────────────────────────────────────────────────────────────
#  BRACKETS MODE  (tier 4 — balanced bracket algorithm)
# ─────────────────────────────────────────────────────────────────────────────

# Each bracket type is bound to a rune so the visual makes sense:
#   ( )  →  Fire rune
#   [ ]  →  Ice rune
#   { }  →  Wind rune
func _setup_bracket_rune_map() -> void:
	_bracket_rune_map = {
		"(": RUNES[0],  # Fire
		")": RUNES[0],
		"[": RUNES[1],  # Ice
		"]": RUNES[1],
		"{": RUNES[2],  # Wind
		"}": RUNES[2],
	}

func _issue_bracket_task() -> void:
	if not _alive: return
	# Clear leftover stack from previous task
	for entry: Dictionary in _stack_a:
		if is_instance_valid(entry.get("node") as Node2D):
			(entry["node"] as Node2D).queue_free()
	_stack_a.clear()
	_update_stack_visuals()

	# Pick a bracket string (mix of balanced and unbalanced)
	var pool: Array[String] = [
		"()", "[]", "{}", "([])", "{()}", "([{}])", "(())",
		"({[]})", "()[]{}", "((()))",
		# Intentionally unbalanced — player must catch the mismatch via wrong pop
		"(]", "{)", "([)]",
	]
	_bracket_string = pool[randi() % pool.size()]
	_bracket_pos    = 0
	_bracket_str_lbl.text = _bracket_string
	_bracket_lbl.text     = "BRACKET STRING — match each one!"
	_update_bracket_display()
	_advance_bracket()

func _update_bracket_display() -> void:
	# Highlight the current character in the bracket string
	var s := ""
	for i in range(_bracket_string.length()):
		if   i < _bracket_pos:           s += "[color=#40c040]%s[/color]" % _bracket_string[i]
		elif i == _bracket_pos:           s += "[color=#f0c040][b]%s[/b][/color]" % _bracket_string[i]
		else:                             s += "[color=#555555]%s[/color]" % _bracket_string[i]
	_bracket_str_lbl.text = s
	_bracket_str_lbl.bbcode_enabled = true if _bracket_str_lbl.has_method("set_text") else false
	# Fallback plain text if bbcode not available
	_bracket_str_lbl.text = _bracket_string

func _advance_bracket() -> void:
	if _bracket_pos >= _bracket_string.length():
		_on_bracket_string_complete()
		return

	var ch := _bracket_string[_bracket_pos]
	var is_open: bool = ch in _bracket_open_map

	var rdef: Dictionary = _bracket_rune_map.get(ch, RUNES[0])
	var nd := _make_rune_node(rdef, true)
	nd.scale          = Vector2.ONE
	nd.z_index        = 20
	add_child(nd)
	# Drop in from above
	nd.global_position = Vector2(STAGE_POS.x, STAGE_POS.y - 300.0)
	var tw_b := nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw_b.tween_property(nd, "global_position", STAGE_POS, 0.22)
	tw_b.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_b.tween_property(nd, "scale", Vector2(1.2, 0.8), 0.06)
	tw_b.tween_property(nd, "scale", Vector2.ONE, 0.08)

	_staged    = rdef.duplicate()
	_staged["bracket_char"] = ch
	_staged_nd = nd

	if is_open:
		_show_hint('Open bracket  "%s"  →  Drag to PUSH it!' % ch)
		_show_task_card('PUSH  "%s"\nDrag the rune onto the column.' % ch)
		# Intercept drag for brackets
		_current_task = "push_bracket"
	else:
		_show_hint('Close bracket  "%s"  →  Click ♛ to POP and match!' % ch)
		_show_task_card('POP to match  "%s"\nClick the ♛ crown.' % ch)
		_current_task = "pop_bracket"

func _on_bracket_push(ch: String, nd: Node2D) -> void:
	# Push the open bracket rune
	_do_push(nd, _staged, _stack_a, COL_A_X)
	_staged_nd = null
	# Store which bracket char this slot represents
	_stack_a.back()["bracket_char"] = ch
	_bracket_pos += 1
	await get_tree().create_timer(0.2).timeout
	_advance_bracket()

func _on_bracket_pop(ch: String) -> void:
	# ch is a close bracket — validate against stack top
	if _stack_a.is_empty():
		_stat["bracket_mismatch"] += 1
		_apply_wrong(null, _p["penalty"],
			"Stack underflow!\nNo matching open bracket for  \"%s\"." % ch)
		_bracket_pos += 1
		await get_tree().create_timer(0.5).timeout
		_advance_bracket()
		return

	var top_entry    := _stack_a.back() as Dictionary
	var top_bracket  := top_entry.get("bracket_char", "") as String
	var expected_open: String = _bracket_close_map.get(ch, "")

	if top_bracket != expected_open:
		_stat["bracket_mismatch"] += 1
		_apply_wrong(top_entry["node"] as Node2D, _p["penalty"],
			"Mismatch!\n\"%s\" doesn't close \"%s\".\nExpected close for \"%s\"." \
			% [ch, top_bracket, top_bracket])
		_bracket_pos += 1
		await get_tree().create_timer(0.5).timeout
		_advance_bracket()
		return

	# Valid match — pop
	_do_pop(_stack_a)
	_flash_op_call('pop "%s" → matched "%s" ✓' % [top_bracket, ch], COL_TOP)
	_bracket_pos += 1
	await get_tree().create_timer(0.2).timeout
	_advance_bracket()

func _on_bracket_string_complete() -> void:
	if _stack_a.is_empty():
		# Balanced!
		_apply_correct(null, 30)
		_flash_op_call("BALANCED ✓  stack is empty", COL_TOP)
		_show_hint("✓ Balanced!\nAll brackets matched. Stack is empty.")
	else:
		# Unbalanced — unmatched opens remain
		_stat["bracket_mismatch"] += 1
		_apply_wrong(null, _p["penalty"],
			"Unbalanced!\n%d open bracket(s) never matched.\nStack must be empty at the end." \
			% _stack_a.size())
		# Clean up remaining nodes
		for entry: Dictionary in _stack_a:
			if is_instance_valid(entry.get("node") as Node2D):
				(entry["node"] as Node2D).queue_free()
		_stack_a.clear()
		_update_stack_visuals()

	if _stat["correct"] >= _p["target_correct"]:
		await get_tree().create_timer(1.5).timeout
		_end_game(true)
		return
	await get_tree().create_timer(1.5).timeout
	_issue_bracket_task()

func _input(event: InputEvent) -> void:
	if _intro_visible or not _alive or _prompt_active: return

	if _p["mode"] == "brackets":
		_input_brackets(event)
		return

	if _p["mode"] == "undo": return

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

func _input_brackets(event: InputEvent) -> void:
	if not (event is InputEventMouseButton): return
	var e := event as InputEventMouseButton
	if e.button_index != MOUSE_BUTTON_LEFT or not e.pressed: return

	if _current_task == "push_bracket":
		# Allow drag-drop OR click-on-column
		if _staged_nd != null and _staged_nd.global_position.distance_to(e.position) < HIT_R:
			_is_dragging  = true
			_drag_offset  = _staged_nd.global_position - e.position
			_staged_nd.z_index = 50
			return
		if _can_pop(_stack_a) and _top_nd(_stack_a).global_position.distance_to(e.position) < HIT_R:
			# Clicked crown while needing to push — gentle reminder
			_show_hint("This is an open bracket!\nDrag it to PUSH onto the column.")
			return

	elif _current_task == "pop_bracket":
		if _can_pop(_stack_a) and _top_nd(_stack_a).global_position.distance_to(e.position) < HIT_R:
			var ch := _staged["bracket_char"] as String
			if _staged_nd:
				_staged_nd.queue_free()
				_staged_nd = null
			_on_bracket_pop(ch)
			return
		if _staged_nd != null and _staged_nd.global_position.distance_to(e.position) < HIT_R:
			_show_hint("This is a close bracket!\nClick the ♛ crown to POP and match.")

# Handle mouseup for bracket drag-drop push
func _unhandled_input(event: InputEvent) -> void:
	# Escape → pause
	if event.is_action_pressed("ui_cancel"):
		var pm := get_node_or_null("PauseMenu")
		if pm and pm.has_method("toggle"): pm.toggle()
		return

	if _p["mode"] != "brackets": return
	if not (event is InputEventMouseButton): return
	var e := event as InputEventMouseButton
	if e.button_index != MOUSE_BUTTON_LEFT or e.pressed: return
	if not _is_dragging or _staged_nd == null: return

	_is_dragging = false
	_staged_nd.z_index = 20
	if e.position.distance_to(_col_top_pos(_stack_a, COL_A_X)) < SNAP_DIST:
		var ch := _staged["bracket_char"] as String
		var nd := _staged_nd
		_staged_nd = null
		await _on_bracket_push(ch, nd)
	else:
		_return_staged_to_stage()

# ─────────────────────────────────────────────────────────────────────────────
#  STACK VISUALS
#  Runes stack flush — each rune's global_position.y is recalculated so they
#  sit directly on top of one another with no gap.
# ─────────────────────────────────────────────────────────────────────────────
func _update_stack_visuals() -> void:
	for i in range(_stack_a.size()):
		var nd := _stack_a[i]["node"] as Node2D
		if not is_instance_valid(nd): continue
		# Dim all non-top runes — do NOT move them here (push tween handles position)
		nd.modulate = Color.WHITE if i == _stack_a.size() - 1 \
					  else Color(0.55, 0.55, 0.55, 1.0)

	# Crown sits just above the top rune
	if is_instance_valid(_crown_a):
		_crown_a.visible = not _stack_a.is_empty()
		if not _stack_a.is_empty():
			_crown_a.global_position = Vector2(COL_A_X, _col_slot_pos(_stack_a.size() - 1).y - 55)

	_hbar_a.value    = _stack_a.size()
	_hbar_a.modulate = COL_WRONG if _stack_a.size() >= _p["max_height"] - 1 else COL_WHITE
	_update_stack_display()

# Returns the world position (centre) for a rune at stack index i (0 = bottom).
# Slot 0 centre = BASE_Y - 35 so bottom edge sits at BASE_Y.
# Each slot above adds SLOT_H = 46px — runes overlap by ~23px so the lower
# rune's top face peeks below the upper one (stacked isometric cube look).
func _col_slot_pos(i: int) -> Vector2:
	return Vector2(COL_A_X, BASE_Y - 35.0 - i * SLOT_H)

# The position a new push would land (one slot above current top)
func _col_top_pos(stack: Array, col_x: float) -> Vector2:
	return Vector2(col_x, BASE_Y - 35.0 - stack.size() * SLOT_H)

func _update_stack_display() -> void:
	if not is_instance_valid(_stack_disp_lbl): return
	if _stack_a.is_empty():
		_stack_disp_lbl.text = "── Stack A ──\nstack = []\n\n# isEmpty() → true"
	else:
		var parts: Array = []
		for e: Dictionary in _stack_a: parts.append('"%s"' % e["name"])
		var top_name := _stack_a.back()["name"] as String
		_stack_disp_lbl.text = \
			"── Stack A ──\nstack = [%s]\n\n# size = %d / %d\n# stack[-1] = \"%s\"  ← top" \
			% [", ".join(parts), _stack_a.size(), _p["max_height"], top_name]

func _can_pop(stack: Array) -> bool: return not stack.is_empty()
func _top_nd(stack: Array)  -> Node2D: return stack.back()["node"] as Node2D

# ─────────────────────────────────────────────────────────────────────────────
#  OP FLASH
# ─────────────────────────────────────────────────────────────────────────────
func _flash_op_call(text: String, color: Color) -> void:
	if not is_instance_valid(_op_flash_lbl): return
	_op_flash_lbl.text = text
	_op_flash_lbl.add_theme_color_override("font_color", color)
	_op_flash_lbl.modulate.a = 0.0
	var tw := _op_flash_lbl.create_tween()
	tw.tween_property(_op_flash_lbl, "modulate:a", 1.0,  0.12)
	tw.tween_interval(0.9)
	tw.tween_property(_op_flash_lbl, "modulate:a", 0.0,  0.4)

# ─────────────────────────────────────────────────────────────────────────────
#  COMPREHENSION PROMPTS
# ─────────────────────────────────────────────────────────────────────────────
func _maybe_show_comprehension_prompt() -> void:
	if _ops_since_prompt < PROMPT_INTERVAL or _stack_a.size() < 2 \
	   or _p["mode"] in ["undo", "brackets"]:
		return
	_ops_since_prompt = 0
	await _show_comprehension_prompt()

func _show_comprehension_prompt() -> void:
	if not is_instance_valid(_prompt_panel): return
	_prompt_active = true

	var correct_name: String = _stack_a.back()["name"]
	var wrong_pool: Array = []
	for rdef: Dictionary in RUNES:
		if rdef["name"] != correct_name: wrong_pool.append(rdef["name"])
	wrong_pool.shuffle()
	_prompt_correct_idx = randi() % 3
	var wi := 0
	for i in range(3):
		var b: Button = _prompt_btns[i]
		b.text     = correct_name if i == _prompt_correct_idx else wrong_pool[wi]
		b.disabled = false
		b.modulate = COL_WHITE
		if i != _prompt_correct_idx: wi += 1

	var preview: Array = []
	for e: Dictionary in _stack_a: preview.append(e["name"])
	_prompt_q_lbl.text = \
		"⏸  Quick check!\n\nstack = %s\n\nWhat will  stack.pop()  return?" % str(preview)

	_prompt_res_lbl.visible = false
	_prompt_panel.visible   = true

func _on_prompt_btn(idx: int) -> void:
	if not _prompt_active: return
	var correct_name: String = _stack_a.back()["name"] if not _stack_a.is_empty() else "?"
	if idx == _prompt_correct_idx:
		_prompt_res_lbl.add_theme_color_override("font_color", COL_TOP)
		_prompt_res_lbl.text = \
			"✓ Correct!\npop() returns \"%s\".\nLIFO: pushed last → leaves first." % correct_name
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_OK)
	else:
		_prompt_res_lbl.add_theme_color_override("font_color", COL_WRONG)
		_prompt_res_lbl.text = \
			"✗  pop() returns \"%s\", not \"%s\".\nLIFO: the LAST pushed is always FIRST out." \
			% [correct_name, (_prompt_btns[idx] as Button).text]
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)

	for b: Button in _prompt_btns: (b as Button).disabled = true
	_prompt_res_lbl.visible = true
	await get_tree().create_timer(2.8).timeout
	_prompt_panel.visible = false
	_prompt_active        = false

# ─────────────────────────────────────────────────────────────────────────────
#  FEEDBACK
# ─────────────────────────────────────────────────────────────────────────────
func _apply_correct(nd: Node2D, pts: int) -> void:
	_stat["correct"] += 1
	_combo       += 1
	_combo_decay  = COMBO_TTL
	var earned := pts * (1 + _combo / 5)
	_score += earned
	_score_lbl.text = "Score: %d" % _score
	_combo_lbl.text = "×%d COMBO!" % _combo if _combo > 1 else ""
	_acc_lbl.text   = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd):
		_flash(nd, COL_TOP)
		_bounce(nd)
		_float(nd, "+%d" % earned, COL_TOP)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_OK)
	if _stat["correct"] >= _p["target_correct"] and _p["mode"] in ["push_pop", "peek", "overflow"]:
		_end_game(true)

func _apply_wrong(nd: Node2D, penalty: int, msg: String, count: bool = true) -> void:
	_combo = 0
	_combo_lbl.text = ""
	if penalty > 0:
		_score = max(0, _score - penalty)
		_score_lbl.text = "Score: %d" % _score
	_acc_lbl.text = "Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd):
		_flash(nd, COL_WRONG)
		_shake(nd)
	if not msg.is_empty(): _show_context_feedback(nd, msg)
	if count:
		_lives -= 1
		_refresh_lives()
		if _lives <= 0: _end_game(false)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)

func _show_hint(text: String) -> void:
	_hint_lbl.text    = text
	_hint_box.visible = true

func _show_context_feedback(nd: Node2D, text: String) -> void:
	_show_hint(text)
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new()
	lbl.text    = text
	lbl.z_index = 200
	if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color",         COL_WRONG)
	lbl.add_theme_color_override("font_shadow_color",  Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	par.add_child(lbl)
	lbl.global_position = nd.global_position + Vector2(-60, -70)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position",   lbl.position + Vector2(0, -55), 1.2)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.tween_callback(lbl.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
#  ANIMATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _flash(nd: Node2D, c: Color) -> void:
	if not is_instance_valid(nd): return
	nd.create_tween().tween_property(nd, "modulate", c,         0.06)
	nd.create_tween().tween_property(nd, "modulate", COL_WHITE, 0.28)

func _bounce(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var s := nd.scale
	var tw := nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd, "scale", s * 1.4, 0.08)
	tw.tween_property(nd, "scale", s,       0.18)

func _shake(nd: Node2D) -> void:
	if not is_instance_valid(nd): return
	var o := nd.position
	var tw := nd.create_tween()
	for _i in range(6):
		tw.tween_property(nd, "position", o + Vector2(randf_range(-7, 7), randf_range(-4, 4)), 0.04)
	tw.tween_property(nd, "position", o, 0.04)

func _pulse(nd: Node2D, color: Color) -> void:
	if not is_instance_valid(nd): return
	var tw := nd.create_tween()
	for _i in range(4):
		tw.tween_property(nd, "modulate", color,     0.07)
		tw.tween_property(nd, "modulate", COL_WHITE, 0.07)

func _float(nd: Node2D, text: String, color: Color) -> void:
	if not is_instance_valid(nd): return
	var par := nd.get_parent(); if not par: return
	var lbl := Label.new()
	lbl.text    = text
	lbl.z_index = 200
	if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	par.add_child(lbl)
	lbl.global_position = nd.global_position + Vector2(-20, -44)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position",   lbl.position + Vector2(0, -40), 0.8)
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
	for i in range(3):
		var l := Label.new()
		l.text = "❤" if i < _lives else "🖤"
		l.add_theme_font_size_override("font_size", 22)
		_lives_row.add_child(l)

func _accuracy() -> float:
	var t := int(_stat["correct"]) \
		   + int(_stat["wrong_pop"]) + int(_stat["wrong_push"]) \
		   + int(_stat["sequence_break"]) + int(_stat["overflow"]) \
		   + int(_stat["bracket_mismatch"])
	return 100.0 if t == 0 else float(_stat["correct"]) / float(t) * 100.0

# ─────────────────────────────────────────────────────────────────────────────
#  END GAME
# ─────────────────────────────────────────────────────────────────────────────
func _end_game(success: bool) -> void:
	if not _alive: return
	_alive = false
	_game_tmr.stop()

	var acc   := _accuracy()
	var grade := _calc_grade(success, acc)
	var summary: String
	if success:
		summary = "✓ Cleared! Grade: %s\nAccuracy: %.0f%%\n\n%s" % [grade, acc, _grade_tip(grade)]
	else:
		summary = "✗ Failed. Grade: %s\nAccuracy: %.0f%%\n\n%s" % [grade, acc, _dominant_mistake()]
	_fail_summary.visible = true
	_fail_lbl.text        = summary

	if has_node("/root/PlayerProfile"):
		PlayerProfile.save_chapter_result(
			_chapter_id, _score, _grade_to_stars(grade), acc,
			{
				"wrong_pop":         _stat["wrong_pop"],
				"wrong_push":        _stat["wrong_push"],
				"sequence_break":    _stat["sequence_break"],
				"overflow":          _stat["overflow"],
				"bracket_mismatch":  _stat["bracket_mismatch"],
			}
		)
	if has_node("/root/GameRouter"):
		GameRouter.current_chapter = _chapter_id

	await get_tree().create_timer(1.8).timeout
	_show_code_snippet()
	await get_tree().create_timer(5.0).timeout

	if has_node("/root/GameRouter"):
		GameRouter.chapter_complete(_chapter_id, _score, _grade_to_stars(grade))
	else:
		get_tree().change_scene_to_file("res://scenes/world_map/WorldMap.tscn")

func _show_code_snippet() -> void:
	var concept: String = _p["concept"]
	if concept not in CODE_SNIPPETS: return
	var tw_out := _fail_summary.create_tween()
	tw_out.tween_property(_fail_summary, "modulate:a", 0.0, 0.4)
	await tw_out.finished
	_fail_summary.visible    = false
	_fail_summary.modulate.a = 1.0
	_code_lbl.text = "What you just practiced — in real code:\n\n" + CODE_SNIPPETS[concept]
	_code_panel.modulate.a = 0.0
	_code_panel.visible    = true
	_code_panel.create_tween().tween_property(_code_panel, "modulate:a", 1.0, 0.6)

func _calc_grade(success: bool, acc: float) -> String:
	if not success: return "C" if acc >= 60.0 else "F"
	if acc >= 95.0: return "S"
	if acc >= 82.0: return "A"
	if acc >= 68.0: return "B"
	return "C"

func _dominant_mistake() -> String:
	var ranked: Array = [
		["wrong_pop",        "You kept clicking non-top runes (LIFO violation)."],
		["sequence_break",   "Wrong pop order — plan push order before starting."],
		["overflow",         "Pushed past the height limit without popping first."],
		["wrong_push",       "Pushed when the task required pop or peek."],
		["bracket_mismatch", "Bracket mismatches — check open/close pairs carefully."],
	]
	var best: String = "Keep practising!"
	var best_cnt := 0
	for pair in ranked:
		var cnt: int = _stat[pair[0]]
		if cnt > best_cnt:
			best_cnt = cnt
			best     = pair[1]
	return best

func _grade_tip(grade: String) -> String:
	match grade:
		"S": return "Flawless!"
		"A": return "Excellent."
		"B": return "Good — watch the order."
		"C": return "Review: only the TOP is accessible (LIFO)."
	return ""

func _grade_to_stars(grade: String) -> int:
	match grade:
		"S", "A": return 3
		"B":      return 2
		"C":      return 1
		_:        return 0
