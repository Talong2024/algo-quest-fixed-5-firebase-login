# =============================================================================
# AlgoQuest — Stack v9  "Face-Down Peek"
# StackGame.gd
#
# WHAT CHANGED FROM v6:
#
#  1. ITEM TYPE SYSTEM  (ItemType enum: RUNE | COLOR | NUMBER | WORD)
#     Each tier now declares its item_type. Tier 0/1/4 = RUNE (unchanged),
#     Tier 2 = COLOR (rainbow swatches), Tier 3 = WORD (text labels).
#     _make_item_node() dispatches to the right factory per type.
#     The code-flash label and stack display adapt their text format too.
#
#  2. MULTI-ITEM TRAY  (replaces single staged rune)
#     A row of 4–5 labelled buttons appears at the bottom of the screen.
#     ALL tray items are visible at once — player clicks whichever to push.
#     Clicking removes that button with a shrink animation, spawns the
#     world-space node, and drops it onto the column.
#     When the tray empties it refills with a fresh shuffled set.
#     Rainbow mode fills the tray with all 7 ROYGBIV colours every round.
#
#  3. RAINBOW GOAL  (overflow tier, COLOR mode)
#     Goal: pop Red → Orange → Yellow → Green → Blue → Indigo → Violet.
#     LIFO forces push in reverse: Violet first … Red last.
#     A dim swatch row below the column lights up each colour as it is
#     correctly popped, building the rainbow visually.
#     Stack limit = 4 so player must push in batches and pop between batches.
#
#  4. WORD UNDO  (undo tier, WORD mode)
#     Auto-push phase types words onto the stack one by one.
#     Player then pops them in reverse — teaching undo history with a
#     relatable metaphor (Ctrl+Z undoes last typed word first).
#
#  5. TutDiagram diagrams updated
#     stack_intro now shows rune+colour+number mixed to teach "any type".
#     push_demo / pop_demo use colour swatches.
#     overflow_full shows the ROYGBIV push-in-reverse strategy.
#     task_preview shows the tray UI.
# =============================================================================

extends Node2D

# ── ASSETS ───────────────────────────────────────────────────────────────────
const PATH_FONT     := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_OK   := "res://assets/audio/sfx/success.ogg"
const PATH_SFX_FAIL := "res://assets/audio/sfx/fail.ogg"
const PATH_SFX_PUSH := "res://assets/audio/sfx/jump_1.ogg"
const PATH_SFX_POP  := "res://assets/audio/sfx/jump_2.ogg"
const PATH_BGM      := "res://assets/audio/music/song18.ogg"
const RUNE_BASE     := "res://assets/art/character/"

# ── ITEM TYPE ─────────────────────────────────────────────────────────────────
enum ItemType { RUNE, COLOR, NUMBER, WORD }

# ── RUNE ITEMS ────────────────────────────────────────────────────────────────
const RUNES: Array[Dictionary] = [
	{"key":"fire",  "name":"Fire",  "color":Color(0.89,0.29,0.10)},
	{"key":"ice",   "name":"Ice",   "color":Color(0.22,0.54,0.87)},
	{"key":"wind",  "name":"Wind",  "color":Color(0.38,0.78,0.50)},
	{"key":"earth", "name":"Earth", "color":Color(0.39,0.60,0.13)},
	{"key":"dark",  "name":"Dark",  "color":Color(0.50,0.47,0.87)},
	{"key":"light", "name":"Light", "color":Color(0.80,0.78,0.65)},
]

# ── RAINBOW COLOUR ITEMS  (ROYGBIV — pop in this order) ──────────────────────
const RAINBOW_COLORS: Array[Dictionary] = [
	{"key":"red",    "name":"Red",    "color":Color(0.93,0.13,0.13), "hex":"#ED2020"},
	{"key":"orange", "name":"Orange", "color":Color(0.96,0.49,0.10), "hex":"#F57D19"},
	{"key":"yellow", "name":"Yellow", "color":Color(0.98,0.88,0.09), "hex":"#FAE017"},
	{"key":"green",  "name":"Green",  "color":Color(0.18,0.76,0.26), "hex":"#2DC242"},
	{"key":"blue",   "name":"Blue",   "color":Color(0.13,0.40,0.90), "hex":"#2165E5"},
	{"key":"indigo", "name":"Indigo", "color":Color(0.29,0.12,0.72), "hex":"#4A1FB8"},
	{"key":"violet", "name":"Violet", "color":Color(0.64,0.14,0.84), "hex":"#A424D6"},
]

const EXTRA_COLORS: Array[Dictionary] = [
	{"key":"pink",  "name":"Pink",  "color":Color(0.96,0.41,0.70), "hex":"#F568B3"},
	{"key":"teal",  "name":"Teal",  "color":Color(0.10,0.72,0.68), "hex":"#1AB8AE"},
	{"key":"white", "name":"White", "color":Color(0.94,0.94,0.94), "hex":"#F0F0F0"},
]

# ── NUMBER ITEMS ──────────────────────────────────────────────────────────────
const NUMBER_COLORS: Array[Color] = [
	Color(0.80,0.80,0.85),Color(0.75,0.85,0.95),Color(0.85,0.95,0.75),
	Color(0.95,0.85,0.75),Color(0.95,0.75,0.85),Color(0.85,0.75,0.95),
	Color(0.75,0.95,0.90),Color(0.95,0.90,0.75),Color(0.75,0.80,0.95),
	Color(0.95,0.80,0.80),
]

# ── WORD ITEMS ────────────────────────────────────────────────────────────────
const WORD_POOL: Array[String] = [
	"Hello","World","Stack","LIFO","Push","Pop","Peek",
	"Undo","Code","Magic","Rune","Fire","Quest",
]

# ── LAYOUT ───────────────────────────────────────────────────────────────────
const COL_A_X    := 400.0
const BASE_Y     := 580.0
const SLOT_H     := 46.0
const RUNE_SCALE := Vector2(3.0,3.0)
const STAGE_POS  := Vector2(640.0,80.0)
const SNAP_DIST  := 90.0
const HIT_R      := 40.0

const TRAY_Y        := 682.0
const TRAY_ITEM_W   := 90.0
const TRAY_ITEM_H   := 68.0
const TRAY_CENTER_X := 640.0
const TRAY_GAP      := 8.0

const COL_TOP   := CastleTheme.C_GOLD
const COL_PEEK  := CastleTheme.C_SAPPHIRE
const COL_WRONG := CastleTheme.C_CRIMSON
const COL_WHITE := Color.WHITE

# ── TIER PARAMS ───────────────────────────────────────────────────────────────
const TIER_PARAMS: Array[Dictionary] = [
	# Tier 0 — basic push/pop, rune tray, fully visible
	{"concept":"PUSH_POP", "mode":"push_pop", "max_height":7,
	 "target_correct":8,  "time_limit":0.0,  "penalty":0,
	 "item_type":ItemType.RUNE,  "tray_size":4},
	# Tier 1 — rainbow colours, bounded stack, reverse-push planning
	{"concept":"OVERFLOW", "mode":"overflow", "max_height":4,
	 "target_correct":12, "time_limit":90.0, "penalty":15,
	 "item_type":ItemType.COLOR, "tray_size":7},
	# Tier 2 — face-down stack; must peek to identify top before popping
	{"concept":"PEEK",     "mode":"peek",     "max_height":5,
	 "target_correct":10, "time_limit":0.0,  "penalty":10,
	 "item_type":ItemType.RUNE,  "tray_size":4,
	 "face_down":true, "peek_reveal_sec":2.2},
	# Tier 3 — word undo, auto-push then reverse
	{"concept":"UNDO",     "mode":"undo",     "max_height":5,
	 "target_correct":10, "time_limit":90.0, "penalty":20,
	 "item_type":ItemType.WORD,  "tray_size":4},
	# Tier 4 — bracket matching
	{"concept":"BRACKETS", "mode":"brackets", "max_height":8,
	 "target_correct":8,  "time_limit":120.0,"penalty":20,
	 "item_type":ItemType.RUNE,  "tray_size":1},
]

# ── CONCEPT SLIDES ────────────────────────────────────────────────────────────
const CONCEPT_SLIDES: Dictionary = {
	"PUSH_POP":[
		{"title":"Stacks Hold Any Value",
		 "body":"A stack stores items in a tower — not just numbers or runes.\nColours, words, objects — any data type can be stacked.\nOnly the TOP item is ever accessible (LIFO).",
		 "diagram":"stack_intro"},
		{"title":"The Item Tray",
		 "body":"A tray of several items is shown at once.\nClick any item in the tray to push it onto the stack.\nThink about LIFO before clicking — order matters!",
		 "diagram":"push_demo"},
		{"title":"pop()  —  Remove from Top",
		 "body":"Drag the ♛ crown UP to pop it.\nThe item pushed LAST always pops FIRST — LIFO.\nWatch the code panel update with every action.",
		 "diagram":"pop_demo"},
		{"title":"Your Task",
		 "body":"① Click any item in the tray to PUSH it onto the column.\n② Drag the ♛ crown UP to POP the top item.\n③ Match the goal shown above — remember LIFO!\nTip: plan your push order — the LAST pushed pops FIRST.",
		 "diagram":"task_preview"},
	],
	"PEEK":[
		{"title":"The Colour-Hidden Stack",
		 "body":"Every rune lands as the SAME dark silhouette — colour stripped away.\nYou can see the shape but not which rune it is.\npeek() is the only way to reveal the colour without popping.",
		 "diagram":"peek_facedown"},
		{"title":"peek()  —  Flip and Read",
		 "body":"Press and HOLD the top card to reveal its colour.\nRelease to hide it again — colour drains out instantly.\nstack[-1] — reads the top value, stack size UNCHANGED.",
		 "diagram":"peek_demo"},
		{"title":"isEmpty()  —  The Hidden Danger",
		 "body":"With a face-down stack you truly can not see if it is empty.\nAlways call isEmpty() before pop() — a hidden empty stack crashes!\nif stack: val = stack.pop()   — always guard first.",
		 "diagram":"isempty_demo"},
		{"title":"Your Task",
		 "body":"All runes land as dark silhouettes — same colour, no identity.\nClick the top rune to PEEK — its true colour floods in briefly.\nMatch the revealed colour to the correct answer button.\nPeeking first earns full points. Guessing blind earns 5.",
		 "diagram":"task_preview"},
	],
	"OVERFLOW":[
		{"title":"Rainbow Stack — Plan in Reverse",
		 "body":"Goal: pop Red first, Violet last (ROYGBIV order).\nLIFO forces you to push in REVERSE:\nPush Violet first — Red last (so Red pops first).",
		 "diagram":"overflow_full"},
		{"title":"Bounded Stack — Watch the Limit",
		 "body":"The stack holds only 4 colours at once.\nPushing past the limit = OverflowError crash.\nPop before pushing once the column is full!",
		 "diagram":"sequence_plan"},
		{"title":"Your Task",
		 "body":"The tray shows all 7 rainbow colours.\nPush in REVERSE order (Violet first).\nPop in ROYGBIV order to paint the rainbow!",
		 "diagram":"task_preview"},
	],
	"UNDO":[
		{"title":"Stack vs Queue — Two Ways to Store",
		 "body":"Queue (FIFO): first in, first out — like a line at a shop.\nStack (LIFO): last in, first out — like a pile of plates.\nUndo history needs LIFO: the LAST action must undo FIRST.",
		 "diagram":"undo_concept"},
		{"title":"Why LIFO, Not FIFO?",
		 "body":"Typed: Hello → World → Stack\nFIFO (queue) would undo: Hello first — WRONG!\nLIFO (stack) undoes: Stack first → World → Hello — CORRECT!\nOnly a stack gives the right undo order.",
		 "diagram":"undo_lifo"},
		{"title":"Your Task — 3 Steps",
		 "body":"① WATCH: words auto-push one by one (typing).\n② UNDO: drag the ♛ crown UP to pop each word.\n③ GOAL: pop ALL words — last typed pops FIRST (LIFO).\nPop until the stack is empty to win the round!",
		 "diagram":"task_preview"},
	],
	"BRACKETS":[
		{"title":"Bracket Matching with a Stack",
		 "body":"A stack checks if brackets are balanced.\nOpen bracket ( [ {  ->  PUSH onto the stack.\nClose bracket ) ] }  ->  POP and check match.",
		 "diagram":"brackets_intro"},
		{"title":"Step-by-Step",
		 "body":"( push   [ push   ] pop check   ) pop check\nStack empty at end = BALANCED\nNot empty or mismatch = UNBALANCED",
		 "diagram":"brackets_algo"},
		{"title":"Your Task",
		 "body":"A bracket string appears — work left to right.\nOpen bracket: drag the rune to PUSH.\nClose bracket: drag ♛ crown UP to POP and match.",
		 "diagram":"task_preview"},
	],
}

# ── CODE SNIPPETS ─────────────────────────────────────────────────────────────
const CODE_SNIPPETS: Dictionary = {
	"PUSH_POP":
"""# Stacks hold ANY type!
stack = []
stack.append("Fire")       # push a string
stack.append(Color.RED)    # push a colour
stack.append(42)           # push a number
stack.pop()   # -> 42       (LIFO)
stack.pop()   # -> Color.RED
stack.pop()   # -> "Fire"
""",
	"PEEK":
"""# Python -- peek and isEmpty guard
stack = ["Fire","Ice","Wind"]
top = stack[-1]       # peek -> "Wind" (unchanged)
if stack:             # isEmpty check first!
    val = stack.pop() # safe pop -> "Wind"
else:
    print("Underflow!")
""",
	"OVERFLOW":
"""# Rainbow stack -- push in reverse of pop goal
# Goal pop: Red -> Orange -> ... -> Violet
# So push: Violet first, Red last
stack = []
stack.append("Violet")  # buried deepest
stack.append("Indigo")
stack.append("Blue")
stack.append("Green")   # stack limit 4 -> pop + refill
# ...
stack.pop()  # -> Red first (LIFO)
""",
	"UNDO":
"""# Python -- undo typed words (Ctrl+Z pattern)
undo_stack = []
def type_word(word):
    document.append(word)
    undo_stack.append(word)   # push every addition
def undo():
    if undo_stack:            # isEmpty check!
        word = undo_stack.pop()  # last typed
        document.remove(word)    # undo it
""",
	"BRACKETS":
"""# Python -- balanced bracket checker O(n)
def is_balanced(s):
    stack = []
    pairs = {')':'(',']':'[','}':'{'}
    for ch in s:
        if ch in '([{':
            stack.append(ch)
        elif ch in ')]}':
            if not stack: return False
            if stack[-1] != pairs[ch]: return False
            stack.pop()
    return len(stack) == 0
""",
}

# =============================================================================
#  TutDiagram  inner class
# =============================================================================
class TutDiagram extends Control:
	const _SDARK  := Color(0.12,0.11,0.15)
	const _SMID   := Color(0.20,0.18,0.24)
	const _SLIGHT := Color(0.30,0.27,0.36)
	const _GOLD   := Color(0.85,0.68,0.20)
	const _PARCH  := Color(0.90,0.85,0.70)
	const _PDIM   := Color(0.60,0.55,0.43)
	const _RED    := Color(0.85,0.15,0.15)
	const _GREEN  := Color(0.22,0.72,0.38)
	const _BLUE   := Color(0.25,0.55,0.90)
	const _FIRE   := Color(0.89,0.29,0.10)
	const _ICE    := Color(0.22,0.54,0.87)
	const _WIND   := Color(0.38,0.78,0.50)
	const _EARTH  := Color(0.39,0.60,0.13)
	const _DARK   := Color(0.50,0.47,0.87)
	const _CRED   := Color(0.93,0.13,0.13)
	const _CORANGE:= Color(0.96,0.49,0.10)
	const _CYELLOW:= Color(0.98,0.88,0.09)
	const _CGREEN := Color(0.18,0.76,0.26)
	const _CBLUE  := Color(0.13,0.40,0.90)
	const _CINDIGO:= Color(0.29,0.12,0.72)
	const _CVIOLET:= Color(0.64,0.14,0.84)

	var slide_key:String=""; var _font:Font=null
	func set_slide(key:String,font:Font)->void: slide_key=key;_font=font;queue_redraw()
	func _draw()->void:
		if slide_key=="": return
		match slide_key:
			"stack_intro":    _draw_stack_intro()
			"push_demo":      _draw_push_demo()
			"pop_demo":       _draw_pop_demo()
			"peek_demo":      _draw_peek_demo()
			"isempty_demo":   _draw_isempty_demo()
			"overflow_full":  _draw_overflow_full()
			"sequence_plan":  _draw_sequence_plan()
			"undo_concept":   _draw_undo_concept()
			"undo_lifo":      _draw_undo_lifo()
			"brackets_intro": _draw_brackets_intro()
			"brackets_algo":  _draw_brackets_algo()
			"peek_facedown":  _draw_peek_facedown()
			"task_preview":   _draw_task_preview()

	func _t(pos:Vector2,text:String,sz:int,color:Color,
			al:HorizontalAlignment=HORIZONTAL_ALIGNMENT_LEFT)->void:
		if _font==null: return
		draw_string(_font,pos+Vector2(0,sz*0.78),text,al,-1,sz,color)
	func _box(r:Rect2,fill:Color,border:Color,bw:float=1.5)->void:
		draw_rect(r,fill); draw_rect(r,border,false,bw)
	func _rune_tex(key:String)->Texture2D:
		var p:="res://assets/art/character/"+key+".png"
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
		return null
	func _ri(key:String,c:Color,x:float,y:float,sz:float)->void:
		var tex:=_rune_tex(key); var r:=Rect2(x,y,sz,sz)
		draw_rect(r.grow(2),Color(c.r*.12,c.g*.12,c.b*.12)); draw_rect(r.grow(2),c,false,1.5)
		if tex: draw_texture_rect(tex,r,false,c)
		else: draw_circle(Vector2(x+sz*.5,y+sz*.5),sz*.38,c)
	func _swatch(c:Color,lbl:String,x:float,y:float,w:float,h:float)->void:
		draw_rect(Rect2(x,y,w,h),c); draw_rect(Rect2(x,y,w,h),Color(1,1,1,.3),false,1.5)
		var tc:=Color.BLACK if c.get_luminance()>.5 else Color.WHITE
		if _font: draw_string(_font,Vector2(x+3,y+h*.65),lbl,-1,-1,10,tc)
	func _col_stack(cx:float,by:float,entries:Array,sz:float=38.0)->void:
		var n:=entries.size(); var step:=sz*.80; var cw:=sz+6; var ch:=(n-1)*step+sz
		var lx:=cx-cw*.5
		draw_rect(Rect2(lx-2,by-ch-6,cw+4,ch+6),Color(.07,.06,.10))
		draw_rect(Rect2(lx-2,by-ch-6,cw+4,ch+6),Color(.25,.20,.35),false,1.5)
		draw_rect(Rect2(lx-2,by-ch-6,cw+4,3),_GOLD)
		for i in range(n):
			var e:Dictionary=entries[i]; var iy:=by-(i+1)*step-(sz-step)
			if e.get("is_color",false):
				draw_rect(Rect2(lx,iy,sz,sz*.75),e["color"])
				draw_rect(Rect2(lx,iy,sz,sz*.75),Color(1,1,1,.3),false,1.5)
				var tc2:=Color.BLACK if e["color"].get_luminance()>.5 else Color.WHITE
				if _font: draw_string(_font,Vector2(lx+3,iy+sz*.55),e.get("name",""),
						HORIZONTAL_ALIGNMENT_LEFT,-1,9,tc2)
			elif e.get("is_word",false):
				draw_rect(Rect2(lx,iy,sz,sz*.60),Color(.12,.10,.20))
				draw_rect(Rect2(lx,iy,sz,sz*.60),Color(.50,.47,.87,.6),false,1.5)
				if _font: draw_string(_font,Vector2(lx+3,iy+sz*.45),e.get("name",""),
						HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(.85,.82,1.0))
			else:
				draw_rect(Rect2(lx,iy+sz*.82,sz,sz*.18),Color(e["color"].r*.28,e["color"].g*.28,e["color"].b*.28))
				_ri(e["key"],e["color"],lx,iy,sz)
			var lbl2:String=e.get("label","")
			if lbl2!="": _t(Vector2(cx+sz*.5+5,iy+sz*.3),lbl2,10,e["color"])
		_t(Vector2(cx,by-ch-18),"TOP",10,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
	func _arrR(x1:float,y:float,x2:float,c:Color)->void:
		draw_line(Vector2(x1,y),Vector2(x2-7,y),c,2.0)
		draw_polygon([Vector2(x2,y),Vector2(x2-7,y-4),Vector2(x2-7,y+4)],[c,c,c])
	func _arrD(x:float,y1:float,y2:float,c:Color,lbl:String="")->void:
		draw_line(Vector2(x,y1),Vector2(x,y2-7),c,2.0)
		draw_polygon([Vector2(x,y2),Vector2(x-4,y2-7),Vector2(x+4,y2-7)],[c,c,c])
		if lbl!="": _t(Vector2(x+6,(y1+y2)*.5),lbl,10,c)

	# ── diagrams ────────────────────────────────────────────────────────────────
	func _draw_stack_intro()->void:
		var W:=size.x;var H:=size.y;var SZ:=minf(W*.10,H*.18);var by:=H*.90
		# Column with mixed types: number bottom, colour mid, rune top
		var cw:=SZ+6;var lx:=W*.18-cw*.5
		var ch:=3*SZ*.72
		draw_rect(Rect2(lx-2,by-ch-6,cw+4,ch+6),Color(.07,.06,.10))
		draw_rect(Rect2(lx-2,by-ch-6,cw+4,ch+6),Color(.25,.20,.35),false,1.5)
		draw_rect(Rect2(lx-2,by-ch-6,cw+4,3),_GOLD)
		# number
		draw_rect(Rect2(lx,by-SZ*.72,SZ,SZ*.72),Color(.08,.06,.16))
		draw_rect(Rect2(lx,by-SZ*.72,SZ,SZ*.72),Color(.80,.80,.85,.5),false,1.5)
		if _font: draw_string(_font,Vector2(lx+SZ*.25,by-SZ*.10),"42",-1,-1,int(SZ*.55),Color(.80,.80,.85))
		# colour
		var cy2:=by-2*SZ*.72; draw_rect(Rect2(lx,cy2,SZ,SZ*.72),_CBLUE)
		draw_rect(Rect2(lx,cy2,SZ,SZ*.72),Color(1,1,1,.3),false,1.5)
		if _font: draw_string(_font,Vector2(lx+3,cy2+SZ*.50),"Blue",-1,-1,9,Color.WHITE)
		# rune top
		var cy3:=by-3*SZ*.72; _ri("fire",_FIRE,lx,cy3,SZ)
		_t(Vector2(W*.18,by-ch-20),"TOP (only this accessible)",11,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		# annotation boxes
		_box(Rect2(W*.34,H*.03,W*.63,H*.44),_SDARK,_GREEN,1.5)
		_t(Vector2(W*.36,H*.06),"Stacks hold ANY type:",13,_GREEN)
		_t(Vector2(W*.38,H*.14),"strings, colours, numbers...",11,_PARCH)
		_t(Vector2(W*.38,H*.22),"anything at all!",11,_PARCH)
		_t(Vector2(W*.36,H*.32),"TOP is the only accessible item.",11,_GREEN)
		_t(Vector2(W*.36,H*.40),"LIFO: Last In = First Out",11,_PDIM)
		_box(Rect2(W*.34,H*.51,W*.63,H*.42),_SDARK,_RED,1.5)
		_t(Vector2(W*.36,H*.54),"Blue + 42 are BLOCKED",13,_RED)
		_t(Vector2(W*.38,H*.63),"You can't reach them until",11,_PARCH)
		_t(Vector2(W*.38,H*.71),"Fire is popped first.",11,_PARCH)
		_t(Vector2(W*.36,H*.82),"Must pop Fire to access Blue.",11,_RED)
		_t(Vector2(W*.36,H*.89),"Must pop Blue to access 42.",11,_RED)

	func _draw_push_demo()->void:
		# Layout: diagram area is 0..W x 0..H (H ≈ 480px when card is shown below).
		# Divide into 3 horizontal zones:
		#   left  (0..35%)  — BEFORE stack
		#   mid   (35..65%) — tray + push arrow
		#   right (65..100%)— AFTER stack
		var W:=size.x; var H:=size.y; var SZ:=minf(W*.11,H*.18)
		var by:=H*.92   # stack base y — stays inside diagram, not cut by card
		# ── Title bar ────────────────────────────────────────────────────────────
		_box(Rect2(W*.01,H*.01,W*.98,H*.10),_SDARK,_GOLD,1.5)
		_t(Vector2(W*.5,H*.03),"push()  —  Add to the TOP of the stack",14,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		# ── LEFT: BEFORE stack ──────────────────────────────────────────────────────
		_t(Vector2(W*.17,H*.13),"BEFORE  push()",13,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_col_stack(W*.17,by,[
			{"is_color":true,"color":_CRED,"name":"Red","label":"TOP"},
		],SZ)
		# ── MID: tray + click label + push arrow ──────────────────────────────────
		var tw:=SZ*1.05; var tray_y:=H*.14
		# Tray label
		_t(Vector2(W*.5,H*.13),"Click a tray swatch:",12,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		# One highlighted swatch (Violet) centred in mid zone
		var sx:=W*.5-tw*.5
		draw_rect(Rect2(sx,tray_y+H*.03,tw,tw*.72),_CVIOLET)
		draw_rect(Rect2(sx,tray_y+H*.03,tw,tw*.72),Color(1,1,1,.5),false,3.0)
		if _font: draw_string(_font,Vector2(sx+tw*.5,tray_y+H*.03+tw*.50),"Violet",
				HORIZONTAL_ALIGNMENT_CENTER,-1,12,Color.WHITE)
		# Cursor / click indicator
		_t(Vector2(W*.5,tray_y+H*.03+tw*.72+6),"↓ CLICK",10,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		# Arrow downward into column zone
		_arrD(W*.5,tray_y+H*.03+tw*.72+20,by-SZ*1.2,_CVIOLET,"push(Violet)")
		# ── RIGHT: AFTER stack ───────────────────────────────────────────────────────
		_t(Vector2(W*.83,H*.13),"AFTER  push()",13,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_col_stack(W*.83,by,[
			{"is_color":true,"color":_CRED,"name":"Red","label":""},
			{"is_color":true,"color":_CVIOLET,"name":"Violet","label":"← NEW TOP"},
		],SZ)
		# Separator arrows left → right
		_arrR(W*.30,H*.60,W*.38,_GOLD)
		_arrR(W*.62,H*.60,W*.70,_GOLD)
		# ── Code box ─────────────────────────────────────────────────────────────────────
		_box(Rect2(W*.01,H*.78,W*.98,H*.20),Color(.04,.08,.04),_GREEN,1.0)
		_t(Vector2(W*.04,H*.81),'stack.append("Violet")   # Violet is now on top',13,_PARCH)
		_t(Vector2(W*.04,H*.90),'stack[-1]  ->  "Violet"   # LIFO: last in = top',12,_GREEN)

	func _draw_pop_demo()->void:
		var W:=size.x;var H:=size.y;var SZ:=minf(W*.10,H*.19);var by:=H*.92
		_box(Rect2(W*.02,H*.02,W*.96,H*.09),_SDARK,_GOLD,1.5)
		_t(Vector2(W*.5,H*.04),"Click crown on top to pop — LIFO always",13,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.14,H*.13),"BEFORE:",12,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_col_stack(W*.14,by,[
			{"is_color":true,"color":_CBLUE,"name":"Blue","label":""},
			{"is_color":true,"color":_CRED,"name":"Red","label":"top -> pops FIRST"},
		],SZ)
		_arrD(W*.36,H*.55,H*.13+SZ,_CRED,"pop()!")
		draw_rect(Rect2(W*.28,H*.04,SZ,SZ*.75),_CRED)
		draw_rect(Rect2(W*.28,H*.04,SZ,SZ*.75),Color(1,1,1,.3),false,1.5)
		if _font: draw_string(_font,Vector2(W*.28+4,H*.04+SZ*.45),"Red",-1,-1,11,Color.WHITE)
		_t(Vector2(W*.28,H*.04+SZ*.75+4),"returned",10,_CRED)
		_arrR(W*.48,H*.56,W*.56,_GOLD)
		_t(Vector2(W*.72,H*.13),"AFTER:",12,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_col_stack(W*.72,by,[{"is_color":true,"color":_CBLUE,"name":"Blue","label":"new top"}],SZ)
		_box(Rect2(W*.02,H*.78,W*.98,H*.20),Color(.04,.08,.04),_GREEN,1.0)
		_t(Vector2(W*.05,H*.83),'val = stack.pop()   # val = "Red"',12,_PARCH)
		_t(Vector2(W*.05,H*.91),"LIFO: Red pushed last -> pops FIRST",11,_GREEN)

	func _draw_peek_demo()->void:
		var W:=size.x;var H:=size.y;var SZ:=minf(W*.10,H*.19);var by:=H*.92
		_box(Rect2(W*.02,H*.02,W*.96,H*.09),_SDARK,_BLUE,1.5)
		_t(Vector2(W*.5,H*.04),"peek() -- read top without removing",13,_BLUE,HORIZONTAL_ALIGNMENT_CENTER)
		_col_stack(W*.18,by,[
			{"key":"fire","color":_FIRE,"label":""},
			{"is_color":true,"color":_CBLUE,"name":"Blue","label":""},
			{"key":"wind","color":_WIND,"label":"top -- peek reads this"},
		],SZ)
		draw_arc(Vector2(W*.44,by-SZ*2.5),18,0,TAU,32,_BLUE,2.0)
		_arrR(W*.18+SZ*.5+4,by-SZ*2.5,W*.44-18,_BLUE)
		_box(Rect2(W*.55,H*.30,W*.41,H*.21),_SDARK,_BLUE,1.5)
		_t(Vector2(W*.57,H*.33),'stack[-1]  ->  Wind',12,_BLUE)
		_t(Vector2(W*.57,H*.40),"size UNCHANGED",11,_PDIM)
		_box(Rect2(W*.02,H*.72,W*.96,H*.22),Color(.04,.08,.04),_GREEN,1.0)
		_t(Vector2(W*.05,H*.75),'top = stack[-1]   # peek -> Wind',12,_PARCH)
		_t(Vector2(W*.05,H*.83),"len(stack) == 3   # UNCHANGED",11,_GREEN)

	func _draw_isempty_demo()->void:
		var W:=size.x;var H:=size.y
		_box(Rect2(W*.02,H*.02,W*.96,H*.09),_SDARK,_RED,1.5)
		_t(Vector2(W*.5,H*.04),"isEmpty() -- guard every pop() call",13,_RED,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.28,H*.14,W*.34,H*.34),Color(.14,.03,.03),_RED,1.5)
		_t(Vector2(W*.30,H*.17),"stack.pop()",13,_RED)
		_t(Vector2(W*.30,H*.26),"IndexError!",12,_RED)
		_t(Vector2(W*.30,H*.34),"Crash",11,_PDIM)
		_box(Rect2(W*.64,H*.14,W*.34,H*.34),Color(.03,.14,.03),_GREEN,1.5)
		_t(Vector2(W*.66,H*.17),"if stack:",13,_GREEN)
		_t(Vector2(W*.66,H*.26),"    stack.pop()",11,_PARCH)
		_t(Vector2(W*.66,H*.34),"Safe",11,_GREEN)
		_box(Rect2(W*.02,H*.58,W*.96,H*.36),Color(.04,.08,.04),_GREEN,1.0)
		_t(Vector2(W*.05,H*.62),"if stack:              # isEmpty check",12,_PARCH)
		_t(Vector2(W*.05,H*.71),"    val = stack.pop()  # safe",12,_GREEN)
		_t(Vector2(W*.05,H*.80),"else:",12,_PARCH)
		_t(Vector2(W*.05,H*.87),"    print('Stack empty!')",11,_PDIM)

	func _draw_overflow_full()->void:
		var W:=size.x;var H:=size.y;var sy:=H*.14
		_box(Rect2(W*.02,H*.02,W*.96,H*.10),_SDARK,_GOLD,1.5)
		_t(Vector2(W*.5,H*.04),"Push Violet first -> Red last  (LIFO -> pop Red first)",
				11,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		var rb:=[_CRED,_CORANGE,_CYELLOW,_CGREEN,_CBLUE,_CINDIGO,_CVIOLET]
		var rn:=["R","O","Y","G","B","I","V"]
		var n_rb:int=rb.size(); var gap_rb:=W*.008
		var sw_rb:=(W*.92 - float(n_rb-1)*gap_rb)/float(n_rb)
		for i in range(rb.size()):
			draw_rect(Rect2(W*.04+i*(sw_rb+gap_rb),sy,sw_rb,H*.10),rb[i])
			if _font: draw_string(_font,Vector2(W*.04+i*(sw_rb+gap_rb)+sw_rb*.5,sy+H*.075),rn[i],
					HORIZONTAL_ALIGNMENT_CENTER,-1,12,
					Color.BLACK if rb[i].get_luminance()>.5 else Color.WHITE)
		_t(Vector2(W*.5,sy+H*.10+4),"Target: pop Red first -> Violet last",10,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.5,H*.34),"Push order (REVERSE): Violet -> Indigo -> Blue -> ... -> Red",
				12,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.02,H*.44,W*.96,H*.22),Color(.04,.08,.04),_GREEN,1.0)
		_t(Vector2(W*.05,H*.47),'stack.append("Violet")   # buried deepest',12,_PARCH)
		_t(Vector2(W*.05,H*.56),'...                       # Indigo, Blue ...',12,_PDIM)
		_t(Vector2(W*.05,H*.65),'stack.append("Red")       # on top -> pops first',12,_GREEN)
		_box(Rect2(W*.02,H*.70,W*.96,H*.12),Color(.14,.03,.03),_RED,1.0)
		_t(Vector2(W*.05,H*.73),"Stack limit = 4 -- must pop and refill!",12,_RED)

	func _draw_sequence_plan()->void:
		var W:=size.x;var H:=size.y
		_box(Rect2(W*.02,H*.02,W*.96,H*.09),_SDARK,_GOLD,1.5)
		_t(Vector2(W*.5,H*.04),"Bounded stack -- push in groups of 4",13,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		var rb2:=[_CVIOLET,_CINDIGO,_CBLUE,_CGREEN]; var rn2:=["Violet","Indigo","Blue","Green"]
		var n_sq2:int=rb2.size(); var gap2:=W*.015
		var sw2:=(W*.92 - float(n_sq2-1)*gap2)/float(n_sq2)
		for i in range(rb2.size()):
			draw_rect(Rect2(W*.04+i*(sw2+gap2),H*.14,sw2,H*.14),rb2[i])
			draw_rect(Rect2(W*.04+i*(sw2+gap2),H*.14,sw2,H*.14),Color(1,1,1,.3),false,1.5)
			if _font: draw_string(_font,Vector2(W*.04+i*(sw2+gap2)+sw2*.5,H*.14+H*.10),rn2[i],
					HORIZONTAL_ALIGNMENT_CENTER,-1,9,Color.WHITE)
		_t(Vector2(W*.5,H*.32),"Push first 4 -> pop in order -> refill and finish",
				11,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.02,H*.40,W*.96,H*.54),Color(.04,.08,.04),_GREEN,1.0)
		_t(Vector2(W*.05,H*.43),"if len(stack) < MAX:   # overflow guard",12,_PARCH)
		_t(Vector2(W*.05,H*.52),"    stack.append(color)",12,_GREEN)
		_t(Vector2(W*.05,H*.60),"else:",12,_PARCH)
		_t(Vector2(W*.05,H*.68),"    raise OverflowError  # must pop first!",12,_RED)
		_t(Vector2(W*.05,H*.78),"val = stack.pop()        # LIFO pop",12,_GREEN)

	func _draw_undo_concept()->void:
		var W:=size.x;var H:=size.y;var SZ:=minf(W*.09,H*.17);var by:=H*.92
		_box(Rect2(W*.02,H*.02,W*.96,H*.09),_SDARK,_GOLD,1.5)
		_t(Vector2(W*.5,H*.04),"Stack (LIFO) vs Queue (FIFO) — why LIFO wins for Undo",12,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		# Left: Queue (FIFO) — wrong for undo
		_box(Rect2(W*.02,H*.14,W*.45,H*.38),Color(.14,.04,.04),_RED,1.5)
		_t(Vector2(W*.24,H*.16),"Queue  (FIFO)  ✗",12,_RED,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.24,H*.23),"First In, First Out",10,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		var qw:=["Hello","World","Stack"]; var qx:=W*.04; var qy:=H*.30
		for i in range(qw.size()):
			_box(Rect2(qx+i*(W*.14),qy,W*.13,H*.12),Color(.20,.08,.08),_RED,1.0)
			_t(Vector2(qx+i*(W*.14)+W*.065,qy+H*.07),qw[i],10,Color(.85,.55,.55),HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.24,H*.46),"Dequeue → Hello first  ✗",10,_RED,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.24,H*.52),"Wrong! 'Hello' was typed FIRST",9,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		# Right: Stack (LIFO) — correct for undo
		_box(Rect2(W*.54,H*.14,W*.44,H*.38),Color(.04,.14,.04),_GREEN,1.5)
		_t(Vector2(W*.76,H*.16),"Stack  (LIFO)  ✓",12,_GREEN,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.76,H*.23),"Last In, First Out",10,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_col_stack(W*.76,H*.60,[
			{"is_word":true,"name":"Hello","color":Color(.5,.47,.87),"label":""},
			{"is_word":true,"name":"World","color":Color(.5,.47,.87),"label":""},
			{"is_word":true,"name":"Stack","color":Color(.5,.47,.87),"label":"← pop first"},
		],SZ*.75)
		_t(Vector2(W*.76,H*.51),"Pop → Stack first  ✓",10,_GREEN,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.76,H*.56),"Correct! Last typed undoes first",9,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.02,H*.62,W*.96,H*.30),Color(.04,.08,.04),_GREEN,1.0)
		_t(Vector2(W*.05,H*.65),"# Python undo stack (Ctrl+Z pattern)",12,_PDIM)
		_t(Vector2(W*.05,H*.73),'undo_stack.append("Stack")   # push on type',12,_PARCH)
		_t(Vector2(W*.05,H*.82),'undo_stack.pop()  ->  "Stack"  # LIFO ✓',12,_GREEN)

	func _draw_undo_lifo()->void:
		var W:=size.x;var H:=size.y;var SZ:=minf(W*.09,H*.17);var by:=H*.92
		_box(Rect2(W*.02,H*.02,W*.96,H*.09),_SDARK,_GOLD,1.5)
		_t(Vector2(W*.5,H*.04),"LIFO = last typed word is first undone",
				12,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		_col_stack(W*.20,by,[
			{"is_word":true,"name":"Hello","color":Color(.5,.47,.87),"label":""},
			{"is_word":true,"name":"World","color":Color(.5,.47,.87),"label":""},
			{"is_word":true,"name":"Stack","color":Color(.5,.47,.87),"label":""},
			{"is_word":true,"name":"LIFO", "color":Color(.5,.47,.87),"label":"top"},
		],SZ)
		_col_stack(W*.74,by,[
			{"is_word":true,"name":"Hello","color":Color(.5,.47,.87),"label":""},
			{"is_word":true,"name":"World","color":Color(.5,.47,.87),"label":"top"},
		],SZ)
		_box(Rect2(W*.34,H*.38,W*.28,H*.20),_SMID,_RED,1.5)
		_t(Vector2(W*.48,H*.41),"Undo x2",12,_RED,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.48,H*.50),"pop()x2",10,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_arrR(W*.62,H*.48,W*.72,_GOLD)
		_box(Rect2(W*.56,H*.64,W*.40,H*.22),_SDARK,_GREEN,1.5)
		_t(Vector2(W*.58,H*.66),"LIFO undone",12,_GREEN)
		_t(Vector2(W*.58,H*.76),"Stack undone",12,_GREEN)

	func _draw_brackets_intro()->void:
		var W:=size.x;var H:=size.y;var SZ:=minf(W*.09,H*.17)
		_box(Rect2(W*.02,H*.02,W*.96,H*.09),_SDARK,_GOLD,1.5)
		_t(Vector2(W*.5,H*.04),"Bracket Matching -- classic stack algorithm",
				12,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.02,H*.13,W*.44,H*.21),Color(.04,.14,.04),_GREEN,1.5)
		_t(Vector2(W*.24,H*.15),"( { [ ] } )",16,_GREEN,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.24,H*.25),"BALANCED",12,_GREEN,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.54,H*.13,W*.44,H*.21),Color(.14,.04,.04),_RED,1.5)
		_t(Vector2(W*.76,H*.15),"( { [ )",16,_RED,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.76,H*.25),"NOT BALANCED",12,_RED,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.02,H*.38,W*.96,H*.54),_SDARK,_SLIGHT,1.5)
		_t(Vector2(W*.04,H*.40),"The Stack Rule:",14,_GOLD)
		_ri("fire",_FIRE,W*.04,H*.50,SZ)
		_t(Vector2(W*.04+SZ+6,H*.52),"See  ( [ {   ->  PUSH onto stack",13,_PARCH)
		_ri("ice",_ICE,W*.04,H*.66,SZ)
		_t(Vector2(W*.04+SZ+6,H*.68),"See  ) ] }   ->  POP and check match!",13,_PARCH)
		_box(Rect2(W*.04,H*.82,W*.88,H*.08),Color(.04,.14,.04),_GREEN,1.0)
		_t(Vector2(W*.5,H*.84),"Stack empty at end  ->  BALANCED",
				12,_GREEN,HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_brackets_algo()->void:
		var W:=size.x;var H:=size.y;var SZ:=minf(W*.08,H*.15)
		_box(Rect2(W*.02,H*.02,W*.96,H*.09),_SDARK,_GOLD,1.5)
		_t(Vector2(W*.5,H*.04),"Walk through \"([])\" step by step",
				13,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		var steps:=[
			{"ch":"(","op":"push","rune":"fire","col":_FIRE,"st":"[Fire]","ok":true},
			{"ch":"[","op":"push","rune":"ice","col":_ICE,"st":"[Fire,Ice]","ok":true},
			{"ch":"]","op":"pop","rune":"ice","col":_ICE,"st":"[Fire]","ok":true},
			{"ch":")","op":"pop","rune":"fire","col":_FIRE,"st":"[] empty","ok":true},
		]
		for i in range(steps.size()):
			var s:Dictionary=steps[i]; var sy:=H*.14+i*H*.19
			var bc:Color=_GREEN if s["ok"] else _RED
			_box(Rect2(W*.02,sy,W*.58,H*.16),Color(bc.r*.08,bc.g*.08,bc.b*.08),bc,1.2)
			_t(Vector2(W*.04,sy+H*.04),"'%s'" % s["ch"],16,bc)
			_t(Vector2(W*.12,sy+H*.03),"->  %s()" % s["op"],13,_GOLD if s["op"]=="push" else _BLUE)
			_ri(s["rune"],s["col"],W*.30,sy+H*.01,SZ)
			_t(Vector2(W*.62,sy+H*.06),"stack: %s" % s["st"],11,_PARCH)
		_box(Rect2(W*.02,H*.92,W*.96,H*.07),Color(.04,.14,.04),_GREEN,1.5)
		_t(Vector2(W*.5,H*.94),"Stack empty at end  ->  BALANCED",
				12,_GREEN,HORIZONTAL_ALIGNMENT_CENTER)

	func _draw_peek_facedown()->void:
		var W:=size.x; var H:=size.y; var SZ:=minf(W*0.10,H*0.18); var by:=H*0.90
		_box(Rect2(W*0.02,H*0.02,W*0.96,H*0.09),_SDARK,_BLUE,1.5)
		_t(Vector2(W*0.5,H*0.04),"Same shape, same dark colour — but which rune is it?",
				12,_BLUE,HORIZONTAL_ALIGNMENT_CENTER)
		# Draw 3 silhouette runes side by side (all same dark tint)
		var sil:=Color(0.22,0.18,0.30)
		var keys:Array[String]=["fire","ice","wind"]
		var base_x:Array[float]=[W*0.18,W*0.50,W*0.82]
		for i in range(3):
			var lx:float=base_x[i]-SZ*0.5; var ly:float=H*0.16
			draw_rect(Rect2(lx-2,ly-2,SZ+4,SZ+4),Color(0.07,0.06,0.10))
			_ri(keys[i],sil,lx,ly,SZ)   # silhouette: all same dark colour
		_t(Vector2(W*0.50,H*0.16+SZ+6),"All look identical — no colour, no label",
				10,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		# Arrow pointing to one silhouette with "peek()" label
		draw_line(Vector2(W*0.50,H*0.16+SZ+18),Vector2(W*0.50,H*0.50),_BLUE,2.0)
		draw_polygon([Vector2(W*0.50,H*0.52),Vector2(W*0.50-5,H*0.50),
				Vector2(W*0.50+5,H*0.50)],[_BLUE,_BLUE,_BLUE])
		_t(Vector2(W*0.54,H*0.43),"peek()",12,_BLUE)
		# After peek: same rune now glowing with true wind colour
		var lx2:=W*0.50-SZ*0.5; var ly2:=H*0.56
		_box(Rect2(lx2-4,ly2-4,SZ+8,SZ+8),Color(_WIND.r*0.15,_WIND.g*0.15,_WIND.b*0.15),_WIND,2.0)
		_ri("wind",_WIND,lx2,ly2,SZ)    # true colour revealed
		# Glow ring
		draw_arc(Vector2(W*0.50,ly2+SZ*0.50),SZ*0.70,0,TAU,40,Color(_WIND.r,_WIND.g,_WIND.b,0.35),8.0)
		_t(Vector2(W*0.50,ly2+SZ+6),"Colour floods in — it is Wind!",
				11,_WIND,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*0.02,H*0.82,W*0.96,H*0.16),Color(0.04,0.08,0.04),_GREEN,1.0)
		_t(Vector2(W*0.05,H*0.84),"top = stack[-1]   # peek -> colour revealed",12,_PARCH)
		_t(Vector2(W*0.05,H*0.92),"# Stack size UNCHANGED — peek never removes",11,_GREEN)

	func _draw_task_preview()->void:
		var W:=size.x;var H:=size.y;var SZ:=minf(W*.08,H*.16)
		_t(Vector2(W*.5,H*.02),"Multi-Item Tray -- click any item to push!",
				13,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		var cols2:=[_CRED,_CBLUE,_WIND,_DARK]; var ns2:=["Red","Blue","Wind","Dark"]
		var n_items2:int=cols2.size(); var tgap3:=SZ*.20
		var tw3:=minf(SZ*1.10, (W*.90 - float(n_items2-1)*tgap3)/float(n_items2))
		var tot3:=float(n_items2)*(tw3+tgap3)-tgap3; var tsx3:=W*.5-tot3*.5
		for i in range(cols2.size()):
			var tx:=tsx3+i*(tw3+tgap3); var ty:=H*.11
			draw_rect(Rect2(tx,ty,tw3,tw3*.75),cols2[i])
			draw_rect(Rect2(tx,ty,tw3,tw3*.75),Color(1,1,1,.4),false,2)
			if _font: draw_string(_font,Vector2(tx+tw3*.5,ty+tw3*.52),ns2[i],
					HORIZONTAL_ALIGNMENT_CENTER,-1,10,Color.WHITE)
		_t(Vector2(W*.5,H*.11+tw3*.75+4),"Click any item to push it",10,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.02,H*.34,W*.46,H*.24),Color(.04,.10,.04),_GREEN,1.5)
		_t(Vector2(W*.25,H*.36),"PUSH",15,_GREEN,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.25,H*.44),"Click any tray item",12,_PARCH,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.25,H*.52),"Order matters (LIFO)!",11,_PDIM,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.54,H*.34,W*.44,H*.24),Color(.10,.08,.02),_GOLD,1.5)
		_t(Vector2(W*.76,H*.36),"POP",15,_GOLD,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.76,H*.44),"Click the crown",12,_PARCH,HORIZONTAL_ALIGNMENT_CENTER)
		_t(Vector2(W*.76,H*.52),"on the top item",12,_PARCH,HORIZONTAL_ALIGNMENT_CENTER)
		_box(Rect2(W*.02,H*.64,W*.96,H*.30),_SDARK,Color(.25,.20,.35),1.0)
		_t(Vector2(W*.04,H*.66),"# Stacks hold any type!",12,_PDIM)
		_t(Vector2(W*.04,H*.74),'stack = [42, Color.RED, "Hello", Wind]',12,_PARCH)
		_t(Vector2(W*.04,H*.82),"stack[-1]  ->  Wind  (top)",12,_GREEN)
		_t(Vector2(W*.04,H*.89),"stack.pop()  ->  Wind first  (LIFO)",12,_GOLD)


# =============================================================================
#  STACK GAME  main class
# =============================================================================

@onready var _bg:          Sprite2D       = $Background
@onready var _crown_a:     Node2D         = $CrownA
@onready var _hbar_a:      ProgressBar    = $HeightBar_A
@onready var _game_tmr:    Timer          = $GameTimer
@onready var _score_lbl:   Label          = $HUD/ScoreLabel
@onready var _combo_lbl:   Label          = $HUD/ComboLabel
@onready var _timer_lbl:   Label          = $HUD/TimerLabel
@onready var _goal_lbl:    Label          = $HUD/GoalLabel
@onready var _acc_lbl:     Label          = $HUD/AccuracyLabel
@onready var _lives_row:    HBoxContainer  = $HUD/LivesRow
@onready var _pause_btn:    Button         = $HUD/PauseButton
@onready var _hint_lbl:    Label          = $HUD/HintBox/HintLabel
@onready var _hint_box:    PanelContainer = $HUD/HintBox
@onready var _task_card:   PanelContainer = $HUD/TaskCard
@onready var _task_lbl:    Label          = $HUD/TaskCard/TaskLabel
@onready var _seq_banner:  PanelContainer = $HUD/SeqBanner
@onready var _seq_lbl:     Label          = $HUD/SeqBanner/SeqLabel
@onready var _fail_summary:PanelContainer = $HUD/FailSummary
@onready var _fail_lbl:    Label          = $HUD/FailSummary/FailLabel


# procedural nodes (same from v6 plus new tray + rainbow row)
# Intro overlay — CanvasLayer approach (same as TreeGame) so it sits above HUD
var _intro_canvas:Node=null  # the overlay root (CanvasLayer at runtime)
var _intro_title:Label=null
var _intro_diagram:TutDiagram=null; var _intro_body:Label=null
var _intro_page:Label=null; var _intro_back:Button=null; var _intro_next:Button=null
var _stack_disp_panel:PanelContainer=null; var _stack_disp_lbl:Label=null
var _op_flash_lbl:Label=null; var _peek_btn:Button=null
var _code_panel:PanelContainer=null; var _code_lbl:Label=null
var _prompt_panel:PanelContainer=null; var _prompt_q_lbl:Label=null
var _prompt_btns:Array=[]; var _prompt_res_lbl:Label=null
var _undo_panel:PanelContainer=null; var _undo_lbl:Label=null
var _bracket_panel:PanelContainer=null; var _bracket_lbl:Label=null
var _bracket_str_lbl:Label=null

# TRAY — point-and-click challenge
var _tray_container:HBoxContainer=null
var _tray_items:Array=[]       # current 3 choice items (1 correct + 2 decoys)
var _tray_buttons:Array=[]     # matching Button nodes

var _challenge_target:Dictionary={}   # the item player must click
var _challenge_nd:Node2D=null         # ghost preview shown above column
var _challenge_active:bool=false      # waiting for correct tray pick
var _challenge_attempts:int=0         # wrong clicks this round

# NEW — rainbow result row (overflow mode)
var _rainbow_result_row:HBoxContainer=null
var _rainbow_pop_idx:int=0
var _rainbow_goal:Array=[]

# ── PEEK FACE-DOWN STATE ─────────────────────────────────────────────────────
# Each rune node in face-down mode gets a "cover" ColorRect child as its last
# child. _peek_cover(nd) returns it. When peek is active the cover flips away
# via a ScaleX tween (card-flip illusion), then flips back after reveal_sec.
var _peek_awaiting_answer:bool=false # true after flip, before player answers
var _peek_riddle_correct:int=0       # index into _peek_answer_btns
var _peek_peeked:bool=false          # did player peek before answering?
# ── HOLD-TO-PEEK ─────────────────────────────────────────────────────────────
# Player holds mouse button down on the top card to reveal its colour.
# Releasing immediately hides it again. No click — pure hold.
var _peek_hold_active:bool=false     # true while player is holding the top card
var _peek_reveal_tween:Tween=null    # active reveal/hide tween

# Riddle UI (built in _setup_new_nodes for peek mode)
var _peek_riddle_panel:PanelContainer=null
var _peek_riddle_lbl:Label=null
var _peek_answer_btns:Array=[]       # Array[Button] — 3 choices

# brackets single-staged item (unchanged from v6)
var _bracket_staged:Dictionary={}
var _bracket_staged_nd:Node2D=null
var _is_dragging:bool=false; var _drag_offset:Vector2=Vector2.ZERO

# ── TRAY DRAG-DROP ────────────────────────────────────────────────────────────
# Instead of clicking a button, the player drags a ghost item from the tray
# and drops it onto the column shaft. The ghost follows the mouse.
var _tray_drag_active:bool=false       # true while dragging a tray ghost
var _tray_drag_nd:Node2D=null          # the ghost node being dragged
var _tray_drag_item:Dictionary={}      # item data for the dragged ghost
var _tray_drag_idx:int=-1             # which tray slot was grabbed
var _tray_drag_offset:Vector2=Vector2.ZERO

# ── CROWN DRAG-POP ────────────────────────────────────────────────────────────
# Player must click and drag the crown upward ≥ POP_DRAG_THRESHOLD px to pop.
const POP_DRAG_THRESHOLD:=55.0        # pixels upward needed to trigger pop
var _crown_drag_active:bool=false      # true while dragging crown
var _crown_drag_start:Vector2=Vector2.ZERO

# state
var _p:Dictionary={}; var _chapter_id:int=6; var _item_type:int=ItemType.RUNE
var _stack_a:Array=[]
var _goal_seq:Array=[]; var _goal_idx:int=0
var _current_task:String=""; var _push_count:int=0
var _undo_seq:Array=[]; var _undo_phase:String=""
var _bracket_string:String=""; var _bracket_pos:int=0
var _bracket_open_map:Dictionary={"(":")", "[":"]", "{":"}"}
var _bracket_close_map:Dictionary={")":"(", "]":"[", "}":"{"}
var _bracket_rune_map:Dictionary={}
var _intro_slides:Array=[]; var _intro_page_idx:int=0; var _intro_visible:bool=false
var _prompt_correct_idx:int=0; var _prompt_active:bool=false; var _ops_since_prompt:int=0
const PROMPT_INTERVAL:=5
var _stat:={  "correct":0,"wrong_pop":0,"wrong_push":0,
			  "sequence_break":0,"overflow":0,"bracket_mismatch":0 }
var _score:int=0; var _combo:int=0; var _lives:int=3; var _combo_decay:float=0.0
const COMBO_TTL:=3.0
var _time_left:float=0.0; var _alive:bool=false; var _pixel_font:Font=null
var _parallax_layers:Array=[]; var _bg_time:float=0.0

# ─────────────────────────────────────────────────────────────────────────────
func _ready()->void:
	_pixel_font=load(PATH_FONT) if ResourceLoader.exists(PATH_FONT) else null
	var tier:=0
	if has_node("/root/DifficultyManager"):
		tier=clamp(DifficultyManager.current_tier,0,4)
	_p=TIER_PARAMS[tier]; _chapter_id=6+tier
	_item_type=_p.get("item_type",ItemType.RUNE) as int
	_setup_bg(); _setup_new_nodes(); _setup_hud(); _setup_timer(); _setup_columns()
	_task_card.visible=false; _seq_banner.visible=false
	_fail_summary.visible=false; _code_panel.visible=false; _hint_box.visible=false
	_update_stack_display(); _apply_castle_theme()
	if has_node("/root/AudioManager"): AudioManager.play_bgm(PATH_BGM)
	_alive=true; _show_intro()

func _process(delta:float)->void:
	if not _alive: return
	if _combo>0:
		_combo_decay-=delta
		if _combo_decay<=0.0: _combo=0; _combo_lbl.text=""
	_bg_time+=delta
	for sp in _parallax_layers:
		if not is_instance_valid(sp): continue
		var speed:float=sp.get_meta("scroll_speed") as float
		if speed==0.0: continue
		sp.position.x-=speed*delta
		if sp.position.x<=-1280.0: sp.position.x+=1280.0*2.0

# ─── INPUT ────────────────────────────────────────────────────────────────────
func _input(event:InputEvent)->void:
	if _intro_visible or not _alive or _prompt_active: return
	if _p["mode"]=="brackets": _input_brackets(event); return
	if _p["mode"]=="undo":
		# Undo mode: crown drag-up pops (same feel as pop in other modes)
		if event is InputEventMouseMotion:
			var m2:=event as InputEventMouseMotion
			if _crown_drag_active and is_instance_valid(_crown_a):
				_crown_a.global_position.y=m2.position.y
			return
		if event is InputEventMouseButton:
			var eu:=event as InputEventMouseButton
			if eu.button_index!=MOUSE_BUTTON_LEFT: return
			var crown_pos_u:=Vector2(COL_A_X,_col_slot_pos(_stack_a.size()-1).y-55) if not _stack_a.is_empty() else Vector2(-999,-999)
			if eu.pressed and _can_pop(_stack_a) and eu.position.distance_to(crown_pos_u)<HIT_R*1.4 and _undo_phase=="undoing":
				_crown_drag_active=true; _crown_drag_start=crown_pos_u
				if is_instance_valid(_crown_a):
					_crown_a.z_index=50
					_crown_a.create_tween().tween_property(_crown_a,"scale",Vector2(1.3,1.3),.08)
				_show_hint("Drag ♛ crown UP to UNDO (pop) the last word!")
			elif not eu.pressed and _crown_drag_active:
				_crown_drag_active=false
				if is_instance_valid(_crown_a):
					_crown_a.z_index=0; _crown_a.scale=Vector2.ONE
					_crown_a.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
						.tween_property(_crown_a,"global_position",_crown_drag_start,.2)
				var dy_u:=_crown_drag_start.y-eu.position.y
				if dy_u>=POP_DRAG_THRESHOLD:
					_pop(_stack_a)
				else:
					_show_hint("Drag ♛ crown further UP to undo!")
					if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)
		return

	# ── Mouse motion: move tray ghost or crown ghost ──────────────────────────
	if event is InputEventMouseMotion:
		var m:=event as InputEventMouseMotion
		# Hold-to-peek: cancel reveal if cursor slides off the top card
		if _peek_hold_active and _can_pop(_stack_a):
			if _top_nd(_stack_a).global_position.distance_to(m.position)>HIT_R*1.4:
				_end_peek_hold()
		if _tray_drag_active and is_instance_valid(_tray_drag_nd):
			_tray_drag_nd.global_position=m.position+_tray_drag_offset
			# Pulse the column drop zone when near it
			var near:=m.position.distance_to(Vector2(COL_A_X,BASE_Y-100.0))<SNAP_DIST*1.5
			if near and is_instance_valid(_challenge_nd):
				_challenge_nd.modulate=Color(1.0,1.0,0.5,0.85)
			elif is_instance_valid(_challenge_nd):
				_challenge_nd.modulate=Color(1.0,1.0,1.0,0.55)
		if _crown_drag_active and is_instance_valid(_crown_a):
			_crown_a.global_position.y=m.position.y
		return

	if not (event is InputEventMouseButton): return
	var e:=event as InputEventMouseButton
	if e.button_index!=MOUSE_BUTTON_LEFT: return

	# ── Face-down hold-to-peek mode ─────────────────────────────────────────
	if _p.get("face_down",false):
		if e.pressed:
			if _can_pop(_stack_a) and \
			   _top_nd(_stack_a).global_position.distance_to(e.position)<HIT_R:
				if not _peek_awaiting_answer:
					_start_peek_hold()
		else:
			# Released — hide the card again
			if _peek_hold_active:
				_end_peek_hold()
		return

	# ── RELEASE: finish tray drag or crown drag ───────────────────────────────
	if not e.pressed:
		if _tray_drag_active:
			_finish_tray_drag(e.position); return
		if _crown_drag_active:
			_finish_crown_drag(e.position); return
		return

	# ── PRESS: start crown drag or check non-top click ───────────────────────
	# Crown drag: clicking crown node (or close to its rendered position)
	var crown_pos:=Vector2(COL_A_X, _col_slot_pos(_stack_a.size()-1).y-55) if not _stack_a.is_empty() else Vector2(-999,-999)
	if _can_pop(_stack_a) and e.position.distance_to(crown_pos)<HIT_R*1.4:
		_crown_drag_active=true
		_crown_drag_start=crown_pos
		if is_instance_valid(_crown_a):
			_crown_a.z_index=50
			_crown_a.create_tween().tween_property(_crown_a,"scale",Vector2(1.3,1.3),.08)
		_show_hint("Drag the ♛ crown UPWARD to POP the top item!")
		return

	_check_non_top_click(e.position)

func _finish_tray_drag(release_pos:Vector2)->void:
	if not _tray_drag_active: return
	_tray_drag_active=false
	var nd:=_tray_drag_nd; _tray_drag_nd=null

	# Restore ghost opacity
	if is_instance_valid(_challenge_nd):
		_challenge_nd.modulate=Color(1.0,1.0,1.0,0.55)

	# Check if dropped near column top
	var col_snap:=_col_top_pos(_stack_a,COL_A_X)
	var close:=release_pos.distance_to(col_snap)<SNAP_DIST or \
			   release_pos.distance_to(Vector2(COL_A_X,BASE_Y))<SNAP_DIST*2.0
	if not close:
		# Snap back to tray with a bounce
		if is_instance_valid(nd):
			var tw:=nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_property(nd,"global_position",Vector2(TRAY_CENTER_X,TRAY_Y-40.0),.25)
			tw.parallel().tween_property(nd,"modulate:a",0.0,.25)
			tw.tween_callback(nd.queue_free)
			# Re-enable the source button
			var idx:=_tray_drag_idx
			if idx>=0 and idx<_tray_buttons.size() and is_instance_valid(_tray_buttons[idx]):
				_tray_buttons[idx].disabled=false
				_tray_buttons[idx].create_tween().tween_property(_tray_buttons[idx],"modulate:a",1.0,.2)
		_show_hint('Drop "%s" onto the column to push it!' % _tray_drag_item.get("name","?"))
		return

	# Dropped on column — treat as correct push (drag already verified correct item)
	# Overflow guard
	if _stack_a.size()>=_p["max_height"]:
		_stat["overflow"]+=1
		_apply_wrong(null,_p["penalty"],
			"Stack overflow! (%d/%d)\nPop before pushing!" \
			% [_stack_a.size(),_p["max_height"]])
		if is_instance_valid(nd):
			nd.create_tween().tween_property(nd,"modulate:a",0.0,.2).finished.connect(nd.queue_free)
		return

	_challenge_active=false
	_stat["correct"]+=1
	_combo+=1; _combo_decay=COMBO_TTL
	var pts:int=15 if _challenge_attempts==0 else max(5,15-_challenge_attempts*4)
	_score+=pts; _score_lbl.text="Score: %d" % _score
	_combo_lbl.text="x%d COMBO!" % _combo if _combo>1 else ""
	_acc_lbl.text="Accuracy: %.0f%%" % _accuracy()
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_OK)
	_flash_op_call('stack.append("%s")  # pushed!' % _tray_drag_item.get("name","?"), COL_TOP)

	# Ghost fades out
	if is_instance_valid(_challenge_nd):
		_challenge_nd.create_tween() \
			.tween_property(_challenge_nd,"modulate:a",0.0,.2) \
			.finished.connect(_challenge_nd.queue_free)
		_challenge_nd=null

	# Animate nd into the stack column
	nd.z_index=20
	_do_push_silent(nd,_tray_drag_item,_stack_a,COL_A_X)

	# Remove the tray button that was dragged
	var idx:=_tray_drag_idx
	if idx>=0 and idx<_tray_buttons.size() and is_instance_valid(_tray_buttons[idx]):
		_tray_buttons[idx].queue_free()
		_tray_buttons[idx]=null

	if _stat["correct"]>=_p["target_correct"] and _p["mode"] in ["push_pop","peek","overflow"]:
		_end_game(true); return

	await get_tree().create_timer(.45).timeout
	if not _alive: return
	if _p["mode"]=="overflow":
		if _stack_a.is_empty(): _fill_tray()
		else: _challenge_active=true  # re-enable tray dragging for remaining colours
	elif _p["mode"]=="peek":
		if not _peek_awaiting_answer: _issue_peek_riddle()
	else:
		_fill_tray()

func _finish_crown_drag(release_pos:Vector2)->void:
	if not _crown_drag_active: return
	_crown_drag_active=false
	# Snap crown back to proper bobbing position
	if is_instance_valid(_crown_a):
		_crown_a.z_index=0
		_crown_a.scale=Vector2.ONE
		_crown_a.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
			.tween_property(_crown_a,"global_position",_crown_drag_start,.2)
	# Check if dragged far enough upward
	var dy:=_crown_drag_start.y-release_pos.y  # positive = dragged up
	if dy>=POP_DRAG_THRESHOLD:
		_pop(_stack_a)
	else:
		# Not far enough — show hint
		_show_hint("Drag the ♛ crown further UP to pop!\n(Drag upward %d px)" % int(POP_DRAG_THRESHOLD))
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)

func _input_brackets(event:InputEvent)->void:
	# Motion: move dragging bracket staged node or crown
	if event is InputEventMouseMotion:
		var m:=event as InputEventMouseMotion
		if _is_dragging and _bracket_staged_nd!=null:
			_bracket_staged_nd.global_position=m.position+_drag_offset
		if _crown_drag_active and is_instance_valid(_crown_a):
			_crown_a.global_position.y=m.position.y
		return
	if not (event is InputEventMouseButton): return
	var e:=event as InputEventMouseButton
	if e.button_index!=MOUSE_BUTTON_LEFT: return

	if e.pressed:
		if _current_task=="push_bracket":
			if _bracket_staged_nd!=null and \
			   _bracket_staged_nd.global_position.distance_to(e.position)<HIT_R:
				_is_dragging=true; _drag_offset=_bracket_staged_nd.global_position-e.position
				_bracket_staged_nd.z_index=50; return
		elif _current_task=="pop_bracket":
			# Start crown drag-up to pop
			var crown_pos:=Vector2(COL_A_X, _col_slot_pos(_stack_a.size()-1).y-55) if not _stack_a.is_empty() else Vector2(-999,-999)
			if _can_pop(_stack_a) and e.position.distance_to(crown_pos)<HIT_R*1.4:
				_crown_drag_active=true; _crown_drag_start=crown_pos
				if is_instance_valid(_crown_a):
					_crown_a.z_index=50
					_crown_a.create_tween().tween_property(_crown_a,"scale",Vector2(1.3,1.3),.08)
				_show_hint("Drag the ♛ crown UP to POP and match the bracket!")
	else:
		# Release: finish crown drag for bracket pop
		if _crown_drag_active:
			_crown_drag_active=false
			if is_instance_valid(_crown_a):
				_crown_a.z_index=0; _crown_a.scale=Vector2.ONE
				_crown_a.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
					.tween_property(_crown_a,"global_position",_crown_drag_start,.2)
			var dy:=_crown_drag_start.y-e.position.y
			if dy>=POP_DRAG_THRESHOLD and _current_task=="pop_bracket":
				var ch:=_bracket_staged["bracket_char"] as String
				if _bracket_staged_nd: _bracket_staged_nd.queue_free(); _bracket_staged_nd=null
				_on_bracket_pop(ch)
			else:
				_show_hint("Drag ♛ further UP to match the bracket!")
				if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)

func _unhandled_input(event:InputEvent)->void:
	if event.is_action_pressed("ui_cancel"):
		var pm:=get_node_or_null("PauseMenu")
		if pm and pm.has_method("toggle"): pm.toggle()
		return
	if _p["mode"]!="brackets": return
	if not (event is InputEventMouseButton): return
	var e:=event as InputEventMouseButton
	if e.button_index!=MOUSE_BUTTON_LEFT or e.pressed: return
	if not _is_dragging or _bracket_staged_nd==null: return
	_is_dragging=false; _bracket_staged_nd.z_index=20
	if e.position.distance_to(_col_top_pos(_stack_a,COL_A_X))<SNAP_DIST:
		var ch:=_bracket_staged["bracket_char"] as String
		var nd:=_bracket_staged_nd; _bracket_staged_nd=null
		await _on_bracket_push(ch,nd)
	else:
		_bracket_staged_nd.create_tween().set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT) \
			.tween_property(_bracket_staged_nd,"global_position",STAGE_POS,0.3)

# ─── INTRO ────────────────────────────────────────────────────────────────────
func _show_intro()->void:
	_intro_slides=CONCEPT_SLIDES.get(_p["concept"],[]); _intro_page_idx=0
	_intro_visible=true
	_build_intro_canvas()
	_refresh_intro_slide()

# Builds the intro CanvasLayer overlay — modelled on TreeGame._show_intro_overlay()
# Layer 95 sits above HUD (20) and PauseMenu (90) during tutorial, below nothing.
func _build_intro_canvas()->void:
	# Clean up any existing canvas
	if is_instance_valid(_intro_canvas):
		_intro_canvas.queue_free()

	_intro_canvas = CanvasLayer.new()
	_intro_canvas.name        = "IntroCanvas"
	_intro_canvas.layer       = 95
	_intro_canvas.process_mode= Node.PROCESS_MODE_ALWAYS
	add_child(_intro_canvas)

	# ── Dark background dim ───────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color    = Color(0.04, 0.03, 0.08, 1.0)   # fully opaque — hides game world
	bg.size     = Vector2(1280, 720)
	bg.z_index  = 0
	_intro_canvas.add_child(bg)

	# ── Diagram area (TutDiagram draws here) ─────────────────────────────────
	# TutDiagram extends Control, which needs a Control-type parent to resolve
	# anchors. Wrap it in a full-screen Control container inside the CanvasLayer.
	var diagram_root := Control.new()
	diagram_root.name = "DiagramRoot"
	diagram_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	diagram_root.z_index = 1
	_intro_canvas.add_child(diagram_root)
	_intro_diagram = TutDiagram.new()
	_intro_diagram.name = "Diagram"
	# Constrain diagram to the area ABOVE the card panel (top 480 of 720px).
	_intro_diagram.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_intro_diagram.set_offset(SIDE_LEFT,   0)
	_intro_diagram.set_offset(SIDE_TOP,    0)
	_intro_diagram.set_offset(SIDE_RIGHT,  1280)
	_intro_diagram.set_offset(SIDE_BOTTOM, 480)
	diagram_root.add_child(_intro_diagram)

	# ── Card panel (cave-stone style, lower half) ─────────────────────────────
	var card := ColorRect.new()
	card.color    = Color(0.07, 0.05, 0.12, 0.97)
	card.size     = Vector2(1280, 240)
	card.position = Vector2(0, 480)
	card.z_index  = 4
	_intro_canvas.add_child(card)

	# Gold top rule on card
	var rule := ColorRect.new()
	rule.color    = CastleTheme.C_GOLD
	rule.size     = Vector2(1280, 2)
	rule.position = Vector2(0, 480)
	rule.z_index  = 5
	_intro_canvas.add_child(rule)

	# ── Progress dots ─────────────────────────────────────────────────────────
	var total := _intro_slides.size()
	var dot_total_w := total * 14 + (total - 1) * 6
	var dot_start_x := (1280 - dot_total_w) / 2
	for i in range(total):
		var dot := ColorRect.new()
		dot.name     = "Dot%d" % i
		dot.size     = Vector2(12, 4)
		dot.position = Vector2(dot_start_x + i * 20, 488)
		dot.color    = CastleTheme.C_GOLD_DIM
		dot.z_index  = 6
		_intro_canvas.add_child(dot)

	# ── Title ─────────────────────────────────────────────────────────────────
	_intro_title = Label.new()
	_intro_title.name = "Title"
	if _pixel_font: _intro_title.add_theme_font_override("font", _pixel_font)
	_intro_title.add_theme_font_size_override("font_size", 20)
	_intro_title.add_theme_color_override("font_color", CastleTheme.C_GOLD)
	_intro_title.position             = Vector2(60, 497)
	_intro_title.size                 = Vector2(1160, 34)
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.z_index              = 6
	_intro_canvas.add_child(_intro_title)

	# Gold divider
	var div := ColorRect.new()
	div.color    = Color(CastleTheme.C_GOLD.r, CastleTheme.C_GOLD.g, CastleTheme.C_GOLD.b, 0.45)
	div.size     = Vector2(900, 1)
	div.position = Vector2(190, 535)
	div.z_index  = 6
	_intro_canvas.add_child(div)

	# ── Body text ─────────────────────────────────────────────────────────────
	_intro_body = Label.new()
	_intro_body.name = "Body"
	if _pixel_font: _intro_body.add_theme_font_override("font", _pixel_font)
	_intro_body.add_theme_font_size_override("font_size", 14)
	_intro_body.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT)
	_intro_body.position             = Vector2(80, 540)
	_intro_body.size                 = Vector2(1120, 110)
	_intro_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_body.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	_intro_body.z_index              = 6
	_intro_canvas.add_child(_intro_body)

	# ── Page counter ──────────────────────────────────────────────────────────
	_intro_page = Label.new()
	_intro_page.name = "Counter"
	if _pixel_font: _intro_page.add_theme_font_override("font", _pixel_font)
	_intro_page.add_theme_font_size_override("font_size", 12)
	_intro_page.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT_DIM)
	_intro_page.position             = Vector2(480, 658)
	_intro_page.size                 = Vector2(320, 22)
	_intro_page.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_page.z_index              = 6
	_intro_canvas.add_child(_intro_page)

	# ── Back button ───────────────────────────────────────────────────────────
	_intro_back = Button.new()
	_intro_back.name = "Back"
	_intro_back.text = "◀  Back"
	_intro_back.position = Vector2(60, 655)
	_intro_back.size     = Vector2(160, 44)
	if _pixel_font: _intro_back.add_theme_font_override("font", _pixel_font)
	_intro_back.add_theme_font_size_override("font_size", 14)
	_intro_back.add_theme_color_override("font_color", CastleTheme.C_PARCHMENT_DIM)
	_intro_back.add_theme_stylebox_override("normal",  CastleTheme.btn_normal())
	_intro_back.add_theme_stylebox_override("hover",   CastleTheme.btn_hover())
	_intro_back.add_theme_stylebox_override("pressed", CastleTheme.btn_pressed())
	_intro_back.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	_intro_back.z_index = 6
	_intro_back.pressed.connect(_on_intro_back)
	_intro_canvas.add_child(_intro_back)

	# ── Next / Begin button ───────────────────────────────────────────────────
	_intro_next = Button.new()
	_intro_next.name = "Next"
	_intro_next.text = "Next  ▶"
	_intro_next.position = Vector2(1060, 655)
	_intro_next.size     = Vector2(160, 44)
	if _pixel_font: _intro_next.add_theme_font_override("font", _pixel_font)
	_intro_next.add_theme_font_size_override("font_size", 14)
	_intro_next.add_theme_color_override("font_color", CastleTheme.C_GOLD)
	_intro_next.add_theme_stylebox_override("normal",
		CastleTheme.stone_panel(CastleTheme.C_GOLD, 2))
	_intro_next.add_theme_stylebox_override("hover",   CastleTheme.btn_hover())
	_intro_next.add_theme_stylebox_override("pressed", CastleTheme.btn_pressed())
	_intro_next.add_theme_stylebox_override("focus",   StyleBoxEmpty.new())
	_intro_next.z_index = 6
	_intro_next.pressed.connect(_on_intro_next)
	_intro_canvas.add_child(_intro_next)


func _refresh_intro_slide()->void:
	if _intro_slides.is_empty(): _dismiss_intro(); return
	if not is_instance_valid(_intro_canvas): return
	var slide:Dictionary=_intro_slides[_intro_page_idx]
	var total:int=_intro_slides.size()

	# Update text nodes
	if is_instance_valid(_intro_title): _intro_title.text=slide.get("title","")
	if is_instance_valid(_intro_body):  _intro_body.text =slide.get("body","")
	if is_instance_valid(_intro_page):  _intro_page.text ="%d / %d" % [_intro_page_idx+1,total]
	if is_instance_valid(_intro_back):  _intro_back.visible=(_intro_page_idx>0)
	if is_instance_valid(_intro_next):
		_intro_next.text="Begin!" if _intro_page_idx==total-1 else "Next  ▶"

	# Update progress dots
	for i in range(total):
		var dot:=_intro_canvas.get_node_or_null("Dot%d" % i) as ColorRect
		if is_instance_valid(dot):
			dot.color = CastleTheme.C_GOLD if i==_intro_page_idx else CastleTheme.C_GOLD_DIM

	# Update diagram
	var key:String=slide.get("diagram","")
	if is_instance_valid(_intro_diagram):
		_intro_diagram.visible=(key!="")
		if key!="": _intro_diagram.set_slide(key,_pixel_font)

func _on_intro_back()->void:
	_intro_page_idx=max(0,_intro_page_idx-1); _refresh_intro_slide()
func _on_intro_next()->void:
	if _intro_page_idx<_intro_slides.size()-1: _intro_page_idx+=1; _refresh_intro_slide()
	else: _dismiss_intro()
func _dismiss_intro()->void:
	_intro_visible=false
	if is_instance_valid(_intro_canvas):
		_intro_canvas.queue_free(); _intro_canvas=null
	_hint_box.visible=true
	_start_game()
# Called by PauseMenu when the player presses "? How to Play"
func _reopen_intro()->void:
	_intro_page_idx=0; _intro_slides=CONCEPT_SLIDES.get(_p["concept"],[])
	if not _intro_slides.is_empty():
		_intro_visible=true
		# Rebuild the canvas overlay fresh (old one may have been freed)
		if not is_instance_valid(_intro_canvas):
			_build_intro_canvas()
		_refresh_intro_slide()

# ─── GAME START ───────────────────────────────────────────────────────────────
func _start_game()->void:
	match _p["mode"]:
		"push_pop":
			_show_hint("Drag items from the tray onto the column to PUSH.\nDrag the ♛ crown UPWARD to POP.")
			_fill_tray()
		"peek":
			_show_hint("Items land FACE-DOWN.\nPress and HOLD the top card to reveal it. Release to hide and answer!")
			_fill_tray()
			_issue_peek_riddle()
		"overflow":
			_rainbow_goal=RAINBOW_COLORS.duplicate(); _rainbow_pop_idx=0
			_seq_banner.visible=true; _update_rainbow_banner()
			_show_hint("Drag colours onto the column in REVERSE order!\nViolet first, Red last.")
			_fill_tray()
			_show_task_card("Rainbow goal: Red -> ... -> Violet\nPush REVERSE. Limit = %d!" % _p["max_height"])
		"undo":
			_undo_panel.visible=true
			_show_hint("Words are typed one by one...\nDrag the ♛ crown UP to undo each one!")
			_start_undo_round()
		"brackets":
			_bracket_panel.visible=true; _tray_container.visible=false
			_show_hint("Match brackets!\nDrag open bracket to PUSH. Drag ♛ crown UP to POP+match.")
			_setup_bracket_rune_map(); _issue_bracket_task()

# ─── TRAY ─────────────────────────────────────────────────────────────────────
# Generate a new challenge: pick a random target item, build 3-choice tray.
# The target is shown as a ghost preview above the column.
# Player must click the matching button in the tray.
func _fill_tray()->void:
	_clear_tray()
	_challenge_attempts=0

	# ── Pick the correct target item ─────────────────────────────────────────
	var pool:Array=[]
	match _item_type:
		ItemType.RUNE:   pool=RUNES.duplicate()
		ItemType.COLOR:  pool=RAINBOW_COLORS.duplicate()
		ItemType.NUMBER:
			for n in range(10):
				pool.append({"key":"num_%d"%n,"name":str(n),
					"color":NUMBER_COLORS[n],"is_number":true,"value":n})
		ItemType.WORD:
			for w in WORD_POOL:
				pool.append({"key":"word_%s"%w,"name":w,
					"color":Color(.50,.47,.87),"is_word":true})
	pool.shuffle()
	_challenge_target=pool[0].duplicate()

	# ── Build tray: COLOR mode shows all items freely; others use 3-choice ──
	var choices:Array
	if _item_type == ItemType.COLOR:
		# Overflow tier: show every colour so player can plan LIFO push order freely
		choices = pool  # already a duplicate; order preserved (ROYGBIV)
	else:
		choices = [_challenge_target.duplicate()]
		var decoy_pool:Array = pool.slice(1)
		decoy_pool.shuffle()
		for i in range(mini(2, decoy_pool.size())):
			choices.append(decoy_pool[i].duplicate())
		choices.shuffle()
	_build_tray_buttons(choices)
	_challenge_active=true

	# ── Show ghost preview above column ──────────────────────────────────────
	_show_challenge_ghost()

	# ── Hint text ─────────────────────────────────────────────────────────────
	var hint_name:String=_challenge_target.get("name","?")
	match _item_type:
		ItemType.RUNE:
			_show_hint('Drag "%s" from the tray onto the column to push!' % hint_name)
		ItemType.COLOR:
			_show_hint('Drag the colour shown above onto the column to push!
"%s"' % hint_name)
		ItemType.WORD:
			_show_hint('Drag "%s" from the tray onto the column to push!' % hint_name)
		_:
			_show_hint('Drag the matching item onto the column!')

# Show a ghost/preview of the target item floating above the stack column.
func _show_challenge_ghost()->void:
	# Clear any existing ghost
	if is_instance_valid(_challenge_nd): _challenge_nd.queue_free()
	var nd:=_make_item_node(_challenge_target, true)
	nd.z_index   = 25
	nd.modulate  = Color(1.0, 1.0, 1.0, 0.55)  # semi-transparent ghost
	add_child(nd)
	nd.global_position = Vector2(COL_A_X, 48.0)  # above the column
	_challenge_nd = nd
	# Gentle float tween so it looks like a "target card" hovering
	var tw:=nd.create_tween().set_loops()
	tw.tween_property(nd,"global_position:y", 38.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(nd,"global_position:y", 58.0, 0.9).set_trans(Tween.TRANS_SINE)

func _build_tray_buttons(items:Array)->void:
	_tray_items=items.duplicate(); _tray_buttons.clear()
	for c in _tray_container.get_children(): c.queue_free()
	for i in range(_tray_items.size()):
		var item:Dictionary=_tray_items[i]
		var btn:=_make_tray_button(item,i)
		_tray_container.add_child(btn); _tray_buttons.append(btn)
		btn.modulate.a=0.0; btn.scale=Vector2(.6,.6)
		var tw:=btn.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(i*.06)
		tw.parallel().tween_property(btn,"modulate:a",1.0,.18)
		tw.parallel().tween_property(btn,"scale",Vector2.ONE,.18)

func _make_tray_button(item:Dictionary,idx:int)->Button:
	var btn:=Button.new()
	var col:Color=item.get("color",Color.WHITE)
	var sty:=StyleBoxFlat.new()
	if item.get("hex","")!="":
		# Full vivid colour fill — the swatch IS the button
		sty.bg_color = col
	elif item.get("is_word",false):
		sty.bg_color=Color(col.r*.25,col.g*.25,col.b*.25)
	else:
		sty.bg_color=Color(col.r*.18,col.g*.18,col.b*.18)
	sty.border_color=col; sty.set_border_width_all(2); sty.set_corner_radius_all(6)
	sty.set_content_margin_all(5)
	var hov:=sty.duplicate() as StyleBoxFlat
	hov.bg_color=col.lightened(0.25)
	hov.border_color=Color.WHITE; hov.set_border_width_all(3)
	btn.add_theme_stylebox_override("normal",sty)
	btn.add_theme_stylebox_override("hover",hov)
	btn.add_theme_stylebox_override("pressed",sty)
	btn.add_theme_stylebox_override("disabled",sty)
	if _pixel_font: btn.add_theme_font_override("font",_pixel_font)
	var tc:=Color.WHITE
	if item.get("hex","")!="":
		# COLOR tray button: no text — the background colour IS the label
		btn.text=""
		btn.add_theme_font_size_override("font_size",10)
	elif item.get("is_number",false):
		btn.text="%s" % item["name"]; btn.add_theme_font_size_override("font_size",20)
		tc=Color(.80,.80,.85)
	elif item.get("is_word",false):
		btn.text="%s" % item["name"]; btn.add_theme_font_size_override("font_size",12)
		tc=Color(.85,.82,1.0)
	else:
		btn.text=""
		btn.add_theme_font_size_override("font_size",10)
		_embed_rune_sprite_in_btn(btn, item)
	btn.add_theme_color_override("font_color",tc)
	btn.add_theme_color_override("font_hover_color",Color.WHITE)
	# Adaptive width: more items in the tray → narrower buttons so they all fit evenly
	var n_items:int = _tray_items.size() if _tray_items.size() > 0 else _p.get("tray_size", 4)
	var tray_available:float = 1040.0 - 240.0  # SIDE_RIGHT - SIDE_LEFT of _tray_container
	var adaptive_w:float = clampf(
		(tray_available - float(n_items - 1) * TRAY_GAP) / float(n_items),
		60.0, TRAY_ITEM_W)
	btn.custom_minimum_size = Vector2(adaptive_w, TRAY_ITEM_H)
	# Wire button_down (press) to start drag — replaces pressed (click)
	btn.button_down.connect(_on_tray_item_drag_start.bind(idx))
	return btn

# Called on mouse-down on a tray button — spawns a draggable ghost.
func _on_tray_item_drag_start(idx:int)->void:
	if _intro_visible or not _alive or _prompt_active: return
	if not _challenge_active: return
	if _tray_drag_active: return
	if idx<0 or idx>=_tray_items.size(): return
	if idx>=_tray_buttons.size(): return
	var btn:Button=_tray_buttons[idx]
	if not is_instance_valid(btn) or btn.disabled: return

	var item:Dictionary=_tray_items[idx]

	# Wrong item dragged — shake the button and stay in challenge.
	# In COLOR (overflow) mode every tray item is valid; player chooses freely.
	if _item_type != ItemType.COLOR and item.get("key","") != _challenge_target.get("key",""):
		_challenge_attempts+=1
		_stat["wrong_push"]+=1
		_combo=0; _combo_lbl.text=""
		_score=max(0,_score-_p["penalty"])
		_score_lbl.text="Score: %d" % _score
		_acc_lbl.text="Accuracy: %.0f%%" % _accuracy()
		var wrong_col:=Color(0.90,0.12,0.12)
		var orig_sty:=btn.get_theme_stylebox("normal") as StyleBoxFlat
		var err_sty:=orig_sty.duplicate() as StyleBoxFlat
		err_sty.bg_color=Color(0.30,0.04,0.04); err_sty.border_color=wrong_col
		btn.add_theme_stylebox_override("normal",err_sty)
		btn.add_theme_stylebox_override("hover",err_sty)
		var orig_pos:=btn.position
		var tw_shake:=btn.create_tween()
		for _i in range(5):
			tw_shake.tween_property(btn,"position",
				orig_pos+Vector2(randf_range(-6,6),randf_range(-3,3)),.04)
		tw_shake.tween_property(btn,"position",orig_pos,.04)
		if is_instance_valid(_challenge_nd):
			var tw_g:=_challenge_nd.create_tween()
			tw_g.tween_property(_challenge_nd,"modulate",Color(1,.2,.2,.8),.1)
			tw_g.tween_property(_challenge_nd,"modulate",Color(1,1,1,.55),.2)
		_show_hint('Wrong item! Drag "%s" onto the column.' \
			% _challenge_target.get("name","?"))
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)
		return

	# Correct item — spawn a draggable ghost at the current mouse world position.
	# In COLOR mode, update challenge_target to whichever colour the player chose.
	if _item_type == ItemType.COLOR:
		_challenge_target = item.duplicate()
	var nd:=_make_item_node(item,true); nd.z_index=60; add_child(nd)
	nd.global_position=get_global_mouse_position()
	nd.scale=Vector2(1.1,1.1)
	_tray_drag_nd=nd; _tray_drag_item=item.duplicate()
	_tray_drag_idx=idx; _tray_drag_active=true
	_tray_drag_offset=Vector2.ZERO  # ghost already centred on cursor

	# Fade + shrink the source button so it looks "picked up"
	btn.disabled=true
	btn.create_tween().tween_property(btn,"modulate:a",0.35,.12)

	_show_hint('Drop "%s" onto the column ↑ to push it!' % item.get("name","?"))

# Embeds a cropped rune Sprite2D + name Label into a Button node.
# Called for ItemType.RUNE tray buttons so the actual sprite shows instead of text.
func _embed_rune_sprite_in_btn(btn:Button, item:Dictionary) -> void:
	var key:String = item.get("key","fire")
	var col:Color  = item.get("color", Color.WHITE)
	var tpath:String = RUNE_BASE + key + ".png"
	const CROP_X:=0; const CROP_Y:=8; const CROP_W:=32; const CROP_H:=23

	# Container centres the sprite + label vertically inside the button
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	if ResourceLoader.exists(tpath):
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(tpath)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.custom_minimum_size = Vector2(36, 26)
		tex_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		tex_rect.modulate = col
		tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(tex_rect)
	else:
		# Fallback: coloured square
		var cr := ColorRect.new()
		cr.color = col; cr.custom_minimum_size = Vector2(28, 20)
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cr)

	var lbl := Label.new()
	lbl.text = item.get("name","?")
	if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(lbl)
	btn.add_child(vbox)


# _on_tray_item_picked removed — tray items now use drag-drop via _on_tray_item_drag_start

func _clear_tray()->void:
	_tray_items.clear(); _tray_buttons.clear()
	if is_instance_valid(_tray_container):
		for c in _tray_container.get_children(): c.queue_free()

# ─── ITEM NODE FACTORIES ──────────────────────────────────────────────────────
func _make_item_node(item:Dictionary,include_label:bool=true)->Node2D:
	match _item_type:
		ItemType.COLOR:  return _make_color_node(item,include_label)
		ItemType.NUMBER: return _make_number_node(item,include_label)
		ItemType.WORD:   return _make_word_node(item,include_label)
		_:               return _make_rune_node(item,include_label)

func _make_rune_node(rdef:Dictionary,include_label:bool=true)->Node2D:
	var root:=Node2D.new()
	const CX:=0;const CY:=8;const CW:=32;const CH:=23
	var sprite:=Sprite2D.new()
	var tpath:=RUNE_BASE+(rdef["key"] as String)+".png"
	if ResourceLoader.exists(tpath):
		sprite.texture=load(tpath); sprite.region_enabled=true
		sprite.region_rect=Rect2(CX,CY,CW,CH)
		var mat:=ShaderMaterial.new(); var sh:=Shader.new()
		sh.code="""shader_type canvas_item;
uniform float threshold:hint_range(0.0,1.0)=0.18;
void fragment(){vec4 c=texture(TEXTURE,UV);if(c.r+c.g+c.b<threshold)discard;COLOR=c;}"""
		mat.shader=sh; sprite.material=mat
	else:
		var cr:=ColorRect.new(); cr.size=Vector2(32,32); cr.position=Vector2(-16,-16)
		cr.color=rdef["color"]; sprite.add_child(cr)
	sprite.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale=RUNE_SCALE; sprite.modulate=Color.WHITE; root.add_child(sprite)
	var shadow:=ColorRect.new(); shadow.color=Color(0,0,0,.5)
	shadow.size=Vector2(CW*RUNE_SCALE.x*.70,3)
	shadow.position=Vector2(-CW*RUNE_SCALE.x*.35,CH*RUNE_SCALE.y*.5-2)
	shadow.z_index=-1; root.add_child(shadow)
	if include_label:
		var lbl:=Label.new(); lbl.text=rdef["name"]
		if _pixel_font: lbl.add_theme_font_override("font",_pixel_font)
		lbl.add_theme_font_size_override("font_size",11)
		lbl.add_theme_color_override("font_color",rdef["color"] as Color)
		lbl.position=Vector2(-24,35); root.add_child(lbl)
	return root

func _make_color_node(item:Dictionary,include_label:bool=true)->Node2D:
	var root:=Node2D.new()
	const W:=72.0;const H:=46.0
	var col:Color=item.get("color",Color.WHITE)
	var body:=ColorRect.new(); body.color=col; body.size=Vector2(W,H)
	body.position=Vector2(-W*.5,-H*.5); root.add_child(body)
	var sheen:=ColorRect.new(); sheen.color=Color(1,1,1,.10); sheen.size=Vector2(W,H)
	sheen.position=Vector2(-W*.5,-H*.5); root.add_child(sheen)
	var border:=ColorRect.new()
	border.color=Color(1,1,1,.25) if col.get_luminance()<.5 else Color(0,0,0,.25)
	border.size=Vector2(W,2); border.position=Vector2(-W*.5,-H*.5); root.add_child(border)
	if include_label:
		var tc:=Color.BLACK if col.get_luminance()>.55 else Color.WHITE
		var nl:=Label.new(); nl.text=item.get("name","")
		if _pixel_font: nl.add_theme_font_override("font",_pixel_font)
		nl.add_theme_font_size_override("font_size",12)
		nl.add_theme_color_override("font_color",tc)
		nl.position=Vector2(-W*.5+4,-H*.5+5); root.add_child(nl)
		if item.get("hex","")!="":
			var hl:=Label.new(); hl.text=item["hex"]
			if _pixel_font: hl.add_theme_font_override("font",_pixel_font)
			hl.add_theme_font_size_override("font_size",9)
			hl.add_theme_color_override("font_color",Color(tc.r,tc.g,tc.b,.65))
			hl.position=Vector2(-W*.5+4,H*.5-13); root.add_child(hl)
	return root

func _make_number_node(item:Dictionary,include_label:bool=true)->Node2D:
	var root:=Node2D.new()
	const W:=50.0;const H:=50.0
	var col:Color=item.get("color",Color.WHITE)
	var bg:=ColorRect.new(); bg.color=Color(.08,.06,.16); bg.size=Vector2(W,H)
	bg.position=Vector2(-W*.5,-H*.5); root.add_child(bg)
	var bd:=ColorRect.new(); bd.color=Color(col.r,col.g,col.b,.55); bd.size=Vector2(W,H)
	bd.position=Vector2(-W*.5,-H*.5); root.add_child(bd)
	var inn:=ColorRect.new(); inn.color=Color(.08,.06,.16); inn.size=Vector2(W-4,H-4)
	inn.position=Vector2(-W*.5+2,-H*.5+2); root.add_child(inn)
	if include_label:
		var lbl:=Label.new(); lbl.text=item.get("name","?")
		if _pixel_font: lbl.add_theme_font_override("font",_pixel_font)
		lbl.add_theme_font_size_override("font_size",26)
		lbl.add_theme_color_override("font_color",col)
		lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		lbl.position=Vector2(-W*.5,H*.5-34); root.add_child(lbl)
	return root

func _make_word_node(item:Dictionary,include_label:bool=true)->Node2D:
	var root:=Node2D.new()
	var word:String=item.get("name","?")
	const H:=38.0; var W:=float(max(78,word.length()*9))
	var bg:=ColorRect.new(); bg.color=Color(.12,.10,.20); bg.size=Vector2(W,H)
	bg.position=Vector2(-W*.5,-H*.5); root.add_child(bg)
	var bd:=ColorRect.new(); bd.color=Color(.50,.47,.87,.55); bd.size=Vector2(W,H)
	bd.position=Vector2(-W*.5,-H*.5); root.add_child(bd)
	var inn:=ColorRect.new(); inn.color=Color(.12,.10,.20); inn.size=Vector2(W-3,H-3)
	inn.position=Vector2(-W*.5+1.5,-H*.5+1.5); root.add_child(inn)
	if include_label:
		var lbl:=Label.new(); lbl.text=word
		if _pixel_font: lbl.add_theme_font_override("font",_pixel_font)
		lbl.add_theme_font_size_override("font_size",13)
		lbl.add_theme_color_override("font_color",Color(.85,.82,1.0))
		lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		lbl.position=Vector2(-W*.5,H*.5-20); root.add_child(lbl)
	return root

# ─── PUSH ─────────────────────────────────────────────────────────────────────
# _do_push_silent: physics/animation only — scoring already handled by tray pick
func _do_push_silent(nd:Node2D,item:Dictionary,stack:Array,col_x:float)->void:
	var dest:=_col_top_pos(stack,col_x)
	nd.global_position=Vector2(dest.x,dest.y-420.0); nd.scale=Vector2.ONE
	var tw:=nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(nd,"global_position",dest,.28)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd,"scale",Vector2(1.35,.65),.07)
	tw.tween_property(nd,"scale",Vector2(.85,1.20),.07)
	tw.tween_property(nd,"scale",Vector2.ONE,.10)
	var entry:=item.duplicate(); entry["node"]=nd; stack.append(entry)
	if nd.get_child_count()>=3: nd.get_child(2).visible=false
	if _p.get("face_down",false): _apply_silhouette(nd)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_PUSH)
	_ops_since_prompt+=1; _push_count+=1; _update_stack_visuals(); _dismiss_task_card()
	_maybe_show_comprehension_prompt()

func _do_push(nd:Node2D,item:Dictionary,stack:Array,col_x:float)->void:
	var dest:=_col_top_pos(stack,col_x)
	nd.global_position=Vector2(dest.x,dest.y-420.0); nd.scale=Vector2.ONE
	var tw:=nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw.tween_property(nd,"global_position",dest,.28)
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd,"scale",Vector2(1.35,.65),.07)
	tw.tween_property(nd,"scale",Vector2(.85,1.20),.07)
	tw.tween_property(nd,"scale",Vector2.ONE,.10)
	var entry:=item.duplicate(); entry["node"]=nd; stack.append(entry)
	if nd.get_child_count()>=3: nd.get_child(2).visible=false
	# Face-down mode: tint the rune sprite to the neutral silhouette colour.
	# The rune shape is visible but the colour — its identity — is hidden.
	if _p.get("face_down",false):
		_apply_silhouette(nd)
	_apply_correct(nd,10)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_PUSH)
	_flash_op_call('stack.append(%s)' % _item_display(item),COL_TOP)
	_ops_since_prompt+=1; _push_count+=1; _update_stack_visuals(); _dismiss_task_card()
	_maybe_show_comprehension_prompt()

# ─── POP ──────────────────────────────────────────────────────────────────────
func _pop(stack:Array)->void:
	if stack.is_empty(): return
	var entry:=stack.back() as Dictionary; var nd:=entry["node"] as Node2D
	if _p["mode"]=="peek" and _current_task=="push":
		_stat["wrong_pop"]+=1
		_apply_wrong(nd,_p["penalty"],"Task says PUSH first!
Drag an item from the tray!"); return
	if _p["mode"]=="overflow":
		var exp_idx:=_rainbow_pop_idx
		if exp_idx>=_rainbow_goal.size(): return
		var exp_name:String=_rainbow_goal[exp_idx]["name"]
		if entry["name"]!=exp_name:
			_stat["sequence_break"]+=1
			_apply_wrong(nd,_p["penalty"],
				"Wrong colour!\nExpected: %s\nGot: %s\n\nLIFO: push in reverse of pop goal!" \
				% [exp_name,entry["name"]])
			return
		_rainbow_pop_idx+=1; _update_rainbow_banner()
		if _rainbow_pop_idx>=_rainbow_goal.size():
			_do_pop(stack)
			_apply_correct(null,50)
			_show_hint("Rainbow complete! LIFO gave perfect order.\nPush a new set!")
			await get_tree().create_timer(1.5).timeout
			if _alive: _rainbow_pop_idx=0; _update_rainbow_banner(); _fill_tray()
			return
	if _p["mode"]=="undo" and _undo_phase=="undoing":
		if _undo_seq.is_empty(): _do_pop(stack); return
		var exp_name2:String=_undo_seq.back()["name"]
		if entry["name"]!=exp_name2:
			_stat["sequence_break"]+=1
			_apply_wrong(nd,_p["penalty"],
				"Wrong undo order!\nLast typed = first undone (LIFO).\nExpected: %s" % exp_name2)
			return
		_undo_seq.pop_back()
	_do_pop(stack)

func _do_pop(stack:Array)->void:
	var raw=stack.pop_back(); if typeof(raw)!=TYPE_DICTIONARY: return
	var entry:=raw as Dictionary; var nd:=entry["node"] as Node2D
	_apply_correct(nd,15)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_POP)
	_flash_op_call('stack.pop()  ->  %s   # LIFO' % _item_display(entry),COL_PEEK)
	_ops_since_prompt+=1; _update_stack_visuals(); _dismiss_task_card()
	# Face-down: flash the true colour as the rune flies out of the stack,
	# so the player briefly sees what they just popped.
	if _p.get("face_down",false):
		var sprite2:=nd.get_child(0) if nd.get_child_count()>0 else null
		if is_instance_valid(sprite2):
			var tc2:Color=entry.get("color",Color.WHITE)
			sprite2.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT) 				.tween_property(sprite2,"modulate",Color.WHITE,0.18)
			var tw_nd:=nd.create_tween()
			tw_nd.tween_property(nd,"modulate",tc2.lightened(0.35),0.10)
			tw_nd.tween_property(nd,"modulate",Color.WHITE,0.15)
	var tw:=nd.create_tween()
	tw.tween_property(nd,"global_position",nd.global_position+Vector2(0,-80),.25)
	tw.parallel().tween_property(nd,"modulate:a",0.0,.25)
	tw.tween_callback(nd.queue_free)
	if _p["mode"]=="undo" and _undo_phase=="undoing" and stack.is_empty():
		await _on_undo_round_complete()

# ─── RAINBOW BANNER ───────────────────────────────────────────────────────────
func _update_rainbow_banner()->void:
	var remaining:Array=[]
	for i in range(_rainbow_pop_idx,_rainbow_goal.size()):
		remaining.append((_rainbow_goal[i] as Dictionary)["name"])
	_seq_lbl.text="Pop next: "+" -> ".join(remaining)
	if not is_instance_valid(_rainbow_result_row): return
	var children:=_rainbow_result_row.get_children()
	for i in range(mini(children.size(),_rainbow_goal.size())):
		var sw:ColorRect=children[i] as ColorRect
		if not is_instance_valid(sw): continue
		sw.modulate=Color.WHITE if i<_rainbow_pop_idx else Color(.2,.2,.2,.6)

# ─── ITEM DISPLAY ─────────────────────────────────────────────────────────────
func _item_display(item:Dictionary)->String:
	if item.get("is_number",false): return str(item.get("value",0))
	return '"%s"' % item.get("name","?")

# ─── PEEK — FACE-DOWN CARD FLIP SYSTEM ───────────────────────────────────────

# Attach a dark stone cover as the last child of a rune node.
# The cover hides the sprite; removing/tweening it reveals the rune.
# ── SILHOUETTE COLOUR  used when rune is "face-down" (hidden) ────────────────
# Same dark neutral for every rune — indistinguishable from each other.
const SILHOUETTE_COLOR := Color(0.22, 0.18, 0.30)   # dark purple-grey

# Apply silhouette tint to the rune sprite (first child of nd).
# The rune shape is still fully visible — only the colour is hidden.
# A gentle pulse keeps it from looking completely static.
func _apply_silhouette(nd:Node2D)->void:
	var sprite:=nd.get_child(0) if nd.get_child_count()>0 else null
	if not is_instance_valid(sprite): return
	sprite.modulate=SILHOUETTE_COLOR
	# Subtle breathe tween so the silhouette feels alive
	var tw:=sprite.create_tween().set_loops()
	tw.tween_property(sprite,"modulate",Color(0.30,0.25,0.42),1.1)
	tw.tween_property(sprite,"modulate",SILHOUETTE_COLOR,1.1)

# Reveal the true colour by tweening the sprite modulate to White (full colour).
# Called during peek; reversed after reveal_sec to hide it again.
func _start_peek_hold()->void:
	if _peek_hold_active or not _alive: return
	if _stack_a.is_empty(): return
	var top:=_stack_a.back() as Dictionary
	var nd:=top["node"] as Node2D
	var sprite:=nd.get_child(0) if nd.get_child_count()>0 else null
	if not is_instance_valid(sprite): return
	_peek_hold_active=true; _peek_peeked=true
	var true_color:Color=top.get("color",Color.WHITE)
	# Kill any hide tween that might still be running
	if is_instance_valid(_peek_reveal_tween): _peek_reveal_tween.kill()
	# Flood colour in quickly (0.22s) -- responsive to hold gesture
	_peek_reveal_tween=sprite.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_peek_reveal_tween.tween_property(sprite,"modulate",Color.WHITE,0.22)
	# Glow pulse so the reveal feels satisfying
	var tw_glow:=nd.create_tween()
	tw_glow.tween_property(nd,"modulate",true_color.lightened(0.45),0.10)
	tw_glow.tween_property(nd,"modulate",Color.WHITE,0.18)
	_flash_op_call('stack[-1]  ->  "%s"  (stack unchanged, size=%d)' \
		% [top["name"],_stack_a.size()], COL_PEEK)
	_float(nd,"👁  %s  (hold to peek)" % top["name"],true_color.lightened(0.3))
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_OK)
	_show_hint("Holding  —  colour revealed!\nRelease to hide and answer the riddle.")

func _end_peek_hold()->void:
	if not _peek_hold_active: return
	_peek_hold_active=false
	if _stack_a.is_empty(): return
	var top2:=_stack_a.back() as Dictionary
	var nd2:=top2["node"] as Node2D
	var sprite2:=nd2.get_child(0) if nd2.get_child_count()>0 else null
	if not is_instance_valid(sprite2): return
	# Drain colour back to silhouette (0.30s)
	if is_instance_valid(_peek_reveal_tween): _peek_reveal_tween.kill()
	_peek_reveal_tween=sprite2.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_peek_reveal_tween.tween_property(sprite2,"modulate",SILHOUETTE_COLOR,0.30)
	# Open riddle after hide completes (only if not already open)
	if not _peek_awaiting_answer:
		await _peek_reveal_tween.finished
		if _alive and not _peek_awaiting_answer: _issue_peek_riddle()

func _issue_peek_riddle()->void:
	if _stack_a.is_empty():
		_show_hint("Stack is empty!\nPush items from the tray first.")
		_fill_tray(); return
	_peek_awaiting_answer=true; _peek_peeked=false
	var correct_item:Dictionary=_stack_a.back()
	var correct_name:String=correct_item["name"]
	# Build 3 choices: 1 correct + 2 wrong from other runes
	var wrong_pool:Array=[]
	for r:Dictionary in RUNES:
		if r["name"]!=correct_name: wrong_pool.append(r["name"])
	wrong_pool.shuffle()
	_peek_riddle_correct=randi()%3; var wi:=0
	# Pre-build name->color map for answer button tinting
	var rune_color_map:Dictionary={}
	for r:Dictionary in RUNES: rune_color_map[r["name"]]=r["color"]
	for i in range(3):
		var b:Button=_peek_answer_btns[i]
		var btn_name:String=correct_name if i==_peek_riddle_correct else wrong_pool[wi]
		b.text=btn_name; b.disabled=false; b.modulate=COL_WHITE
		# Tint each button border with that rune's true colour —
		# player must match colour memory to button, teaching colour = identity
		var btn_color:Color=rune_color_map.get(btn_name,CastleTheme.C_PARCHMENT)
		var btn_sty:=StyleBoxFlat.new()
		btn_sty.bg_color=Color(btn_color.r*0.18,btn_color.g*0.18,btn_color.b*0.18)
		btn_sty.border_color=btn_color; btn_sty.set_border_width_all(2)
		btn_sty.set_corner_radius_all(6); btn_sty.set_content_margin_all(8)
		var btn_hov:=btn_sty.duplicate() as StyleBoxFlat
		btn_hov.bg_color=Color(btn_color.r*0.35,btn_color.g*0.35,btn_color.b*0.35)
		btn_hov.border_color=Color.WHITE; btn_hov.set_border_width_all(3)
		b.add_theme_stylebox_override("normal",btn_sty)
		b.add_theme_stylebox_override("hover",btn_hov)
		b.add_theme_color_override("font_color",btn_color.lightened(0.3))
		if i!=_peek_riddle_correct: wi+=1
	_peek_riddle_lbl.text="❓  What colour is the top rune?\n\nPeek to reveal its colour — then match it to a button below.\nPeek first = +15 pts.  Blind guess = +5 pts."
	_peek_riddle_panel.visible=true
	_show_hint("Press and HOLD the top card to reveal its colour.\nRelease to hide it, then answer!")

func _on_peek_answer_btn(idx:int)->void:
	if not _peek_awaiting_answer or not _alive: return
	_peek_awaiting_answer=false; _peek_riddle_panel.visible=false
	var correct_name:String=_stack_a.back()["name"]
	var nd:=_top_nd(_stack_a)
	if idx==_peek_riddle_correct:
		var pts:=15 if _peek_peeked else 5
		_apply_correct(nd,pts)
		if _peek_peeked:
			_show_hint('Correct! "%s" was on top.\npeek() let you read it without removing it.' % correct_name)
		else:
			_show_hint("Lucky guess! +%d pts (vs +15 for peeking first).\nAlways peek — you cannot see the stack!" % pts)
		_flash_op_call('stack[-1]  ->  "%s"  # peek correct!' % correct_name, COL_PEEK)
	else:
		var guessed:String=(_peek_answer_btns[idx] as Button).text
		_apply_wrong(nd,_p["penalty"],
			'Wrong! Top was "%s", not "%s".\nYou needed to PEEK first — the stack is face-down!' 			% [correct_name,guessed])
		_flash_op_call('stack[-1]  ->  "%s"  # you guessed wrong' % correct_name, COL_WRONG)
	# After answering: rotate — push 2 more then new riddle
	_push_count+=1
	await get_tree().create_timer(1.2).timeout
	if _alive: _fill_tray()

# Legacy peek button handler — now triggers the flip in peek mode
func _on_peek_pressed()->void:
	if not _alive or _prompt_active: return
	if _p.get("face_down",false):
		_start_peek_hold()  # face-down tier: hold-reveal
		return
	# Normal (non-face-down) tiers: standard instant reveal
	if _stack_a.is_empty():
		_show_hint("Stack is empty!\nisEmpty() -> True\nDon't pop an empty stack!"); return
	var top:=_stack_a.back() as Dictionary; var nd:=top["node"] as Node2D
	_pulse(nd,COL_PEEK); _float(nd,"peek: %s" % top["name"],COL_PEEK)
	_flash_op_call('stack[-1]  ->  %s  (unchanged)' % _item_display(top),COL_PEEK)
	_show_hint('Peek: %s. Size=%d -- stack unchanged.' % [top["name"],_stack_a.size()])

# ─── UNDO ─────────────────────────────────────────────────────────────────────
func _start_undo_round()->void:
	_undo_seq.clear()
	var pool:=WORD_POOL.duplicate(); pool.shuffle()
	for i in range(4):
		_undo_seq.append({"key":"word_%d"%i,"name":pool[i],
			"color":Color(.50,.47,.87),"is_word":true})
	_undo_phase="casting"; _undo_lbl.text="Typing history:\n(typing...)"
	_show_hint("Watch the words being typed..."); await _auto_push_undo_seq()

func _auto_push_undo_seq()->void:
	for item:Dictionary in _undo_seq:
		if not _alive: return
		var nd:=_make_word_node(item,false); nd.z_index=20; add_child(nd)
		nd.global_position=STAGE_POS
		var dest:=_col_top_pos(_stack_a,COL_A_X)
		nd.global_position=Vector2(dest.x,dest.y-420.0); nd.scale=Vector2.ONE
		var tw:=nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
		tw.tween_property(nd,"global_position",dest,.28)
		tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(nd,"scale",Vector2(1.35,.65),.07)
		tw.tween_property(nd,"scale",Vector2(.85,1.20),.07)
		tw.tween_property(nd,"scale",Vector2.ONE,.10); await tw.finished
		var entry:=item.duplicate(); entry["node"]=nd; _stack_a.append(entry)
		_flash_op_call('undo_stack.append("%s")  <- typed' % item["name"],Color(.50,.47,.87))
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_PUSH)
		_update_stack_visuals()
		var lines:Array=["Typing history:"]
		for e:Dictionary in _stack_a: lines.append('  append("%s")' % e["name"])
		_undo_lbl.text="\n".join(lines); await get_tree().create_timer(.7).timeout
	_undo_phase="undoing"
	_show_hint("Now UNDO the words!
Drag the ♛ crown UP -- last typed = first undone (LIFO).")
	_show_task_card("UNDO all %d words!\nLIFO reverses your typing." % _undo_seq.size())

func _on_undo_round_complete()->void:
	_dismiss_task_card(); _apply_correct(null,25); _undo_seq.clear()
	_undo_lbl.text="Typing history:\n(all undone!)"
	_show_hint("All words undone!\nLIFO perfectly reversed your typing history.")
	_flash_op_call("All words reversed -- undo complete! LIFO",COL_TOP)
	if _stat["correct"]>=_p["target_correct"]:
		await get_tree().create_timer(1.5).timeout; _end_game(true); return
	await get_tree().create_timer(2.0).timeout; _start_undo_round()

# ─── BRACKETS ─────────────────────────────────────────────────────────────────
func _setup_bracket_rune_map()->void:
	_bracket_rune_map={"(":RUNES[0],")":RUNES[0],"[":RUNES[1],"]":RUNES[1],"{":RUNES[2],"}":RUNES[2]}

func _issue_bracket_task()->void:
	if not _alive: return
	for entry:Dictionary in _stack_a:
		if is_instance_valid(entry.get("node") as Node2D): (entry["node"] as Node2D).queue_free()
	_stack_a.clear(); _update_stack_visuals()
	var pool:Array[String]=["()","[]","{}","([])","{}()","([{}])","(())","({[]})","()[]{}", "((()))","(]","{)","([)]"]
	_bracket_string=pool[randi()%pool.size()]; _bracket_pos=0
	_bracket_lbl.text="Bracket String:"; _bracket_str_lbl.text=_bracket_string
	_advance_bracket()

func _advance_bracket()->void:
	if _bracket_pos>=_bracket_string.length(): _on_bracket_string_complete(); return
	var ch:=_bracket_string[_bracket_pos]; var is_open:bool=ch in _bracket_open_map
	var rdef:Dictionary=_bracket_rune_map.get(ch,RUNES[0])
	var nd:=_make_rune_node(rdef,true); nd.scale=Vector2.ONE; nd.z_index=20; add_child(nd)
	nd.global_position=Vector2(STAGE_POS.x,STAGE_POS.y-300.0)
	var tw_b:=nd.create_tween().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tw_b.tween_property(nd,"global_position",STAGE_POS,.22)
	tw_b.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw_b.tween_property(nd,"scale",Vector2(1.2,.8),.06)
	tw_b.tween_property(nd,"scale",Vector2.ONE,.08)
	_bracket_staged=rdef.duplicate(); _bracket_staged["bracket_char"]=ch; _bracket_staged_nd=nd
	if is_open:
		_show_hint('Open "%s" ->  Drag to PUSH!' % ch)
		_show_task_card('PUSH  "%s"\nDrag the rune onto the column.' % ch); _current_task="push_bracket"
	else:
		_show_hint('Close "%s" -> Drag ♛ crown UP to POP and match!' % ch)
		_show_task_card('POP to match  "%s"\nDrag ♛ crown UP.' % ch); _current_task="pop_bracket"

func _on_bracket_push(ch:String,nd:Node2D)->void:
	_do_push(nd,_bracket_staged,_stack_a,COL_A_X); _bracket_staged_nd=null
	_stack_a.back()["bracket_char"]=ch; _bracket_pos+=1
	await get_tree().create_timer(.2).timeout; _advance_bracket()

func _on_bracket_pop(ch:String)->void:
	if _stack_a.is_empty():
		_stat["bracket_mismatch"]+=1
		_apply_wrong(null,_p["penalty"],
			'Stack underflow!\nNo open bracket for "%s".\nisEmpty() -> True!' % ch)
		_bracket_pos+=1; await get_tree().create_timer(.5).timeout; _advance_bracket(); return
	var top_entry:=_stack_a.back() as Dictionary
	var top_bracket:=top_entry.get("bracket_char","") as String
	var expected:=_bracket_close_map.get(ch,"") as String
	if top_bracket!=expected:
		_stat["bracket_mismatch"]+=1
		_apply_wrong(top_entry["node"] as Node2D,_p["penalty"],
			'Mismatch!\n"%s" does not close "%s".' % [ch,top_bracket])
		_bracket_pos+=1; await get_tree().create_timer(.5).timeout; _advance_bracket(); return
	_do_pop(_stack_a)
	_flash_op_call('pop "%s" -> matched "%s"' % [top_bracket,ch],COL_TOP)
	_bracket_pos+=1; await get_tree().create_timer(.2).timeout; _advance_bracket()

func _on_bracket_string_complete()->void:
	if _stack_a.is_empty():
		_apply_correct(null,30); _flash_op_call("BALANCED -- stack is empty",COL_TOP)
		_show_hint("Balanced! All brackets matched. Stack empty.")
	else:
		_stat["bracket_mismatch"]+=1
		_apply_wrong(null,_p["penalty"],
			"Unbalanced! %d open bracket(s) unmatched." % _stack_a.size())
		for entry:Dictionary in _stack_a:
			if is_instance_valid(entry.get("node") as Node2D): (entry["node"] as Node2D).queue_free()
		_stack_a.clear(); _update_stack_visuals()
	if _stat["correct"]>=_p["target_correct"]:
		await get_tree().create_timer(1.5).timeout; _end_game(true); return
	await get_tree().create_timer(1.5).timeout; _issue_bracket_task()

# ─── STACK VISUALS ────────────────────────────────────────────────────────────
func _update_stack_visuals()->void:
	for i in range(_stack_a.size()):
		var nd:=_stack_a[i]["node"] as Node2D; if not is_instance_valid(nd): continue
		nd.modulate=Color.WHITE if i==_stack_a.size()-1 else Color(.55,.55,.55,1.0)
	if is_instance_valid(_crown_a):
		_crown_a.visible=not _stack_a.is_empty()
		if not _stack_a.is_empty():
			_crown_a.global_position=Vector2(COL_A_X,_col_slot_pos(_stack_a.size()-1).y-55)
	_hbar_a.value=_stack_a.size()
	_hbar_a.modulate=COL_WRONG if _stack_a.size()>=_p["max_height"]-1 else COL_WHITE
	_update_stack_display()

func _col_slot_pos(i:int)->Vector2: return Vector2(COL_A_X,BASE_Y-35.0-i*SLOT_H)
func _col_top_pos(stack:Array,col_x:float)->Vector2:
	return Vector2(col_x,BASE_Y-35.0-stack.size()*SLOT_H)

func _update_stack_display()->void:
	if not is_instance_valid(_stack_disp_lbl): return
	if _stack_a.is_empty():
		_stack_disp_lbl.text="-- Stack --\nstack = []\n\n# isEmpty() -> True"
	else:
		var parts:Array=[]
		for e:Dictionary in _stack_a: parts.append(_item_display(e))
		_stack_disp_lbl.text="-- Stack --\nstack = [%s]\n\n# size = %d / %d\n# top -> %s" \
			% [", ".join(parts),_stack_a.size(),_p["max_height"],_item_display(_stack_a.back())]

func _can_pop(stack:Array)->bool: return not stack.is_empty()
func _top_nd(stack:Array)->Node2D: return stack.back()["node"] as Node2D
func _check_non_top_click(pos:Vector2)->void:
	for i in range(_stack_a.size()-1):
		var nd:=_stack_a[i]["node"] as Node2D
		if is_instance_valid(nd) and nd.global_position.distance_to(pos)<HIT_R:
			_stat["wrong_pop"]+=1
			_apply_wrong(nd,_p["penalty"],
				"LIFO Violation!\nOnly the TOP item can be popped.\nItems below are unreachable!")
			# Flash ALL buried items dark + show 🔒 so player sees they're locked
			_flash_lifo_lockout()
			if _can_pop(_stack_a): _pulse(_top_nd(_stack_a),COL_TOP); return

# Visually lock all non-top stack items: dim to near-black, show 🔒 floaters.
# Reinforces that LIFO means only the top slot is ever accessible.
func _flash_lifo_lockout()->void:
	for i in range(_stack_a.size()-1):
		var nd:=_stack_a[i]["node"] as Node2D
		if not is_instance_valid(nd): continue
		# Dim to near-black then restore
		var tw:=nd.create_tween()
		tw.tween_property(nd,"modulate",Color(0.08,0.06,0.10,1.0),.08)
		tw.tween_interval(.35)
		tw.tween_property(nd,"modulate",Color(0.55,0.55,0.55,1.0),.25)
		# Float a lock emoji from each buried item
		_float(nd,"🔒",COL_WRONG)

# ─── OP FLASH ─────────────────────────────────────────────────────────────────
func _flash_op_call(text:String,color:Color)->void:
	if not is_instance_valid(_op_flash_lbl): return
	_op_flash_lbl.text=text; _op_flash_lbl.add_theme_color_override("font_color",color)
	_op_flash_lbl.modulate.a=0.0
	var tw:=_op_flash_lbl.create_tween()
	tw.tween_property(_op_flash_lbl,"modulate:a",1.0,.12)
	tw.tween_interval(.9); tw.tween_property(_op_flash_lbl,"modulate:a",0.0,.4)

# ─── COMPREHENSION PROMPTS ────────────────────────────────────────────────────
func _maybe_show_comprehension_prompt()->void:
	if _ops_since_prompt<PROMPT_INTERVAL or _stack_a.size()<2 \
	   or _p["mode"] in ["undo","brackets"]: return
	_ops_since_prompt=0; await _show_comprehension_prompt()

func _show_comprehension_prompt()->void:
	if not is_instance_valid(_prompt_panel): return
	_prompt_active=true
	var correct_name:String=_stack_a.back()["name"]
	var wrong_pool:Array=[]
	for e:Dictionary in _stack_a.slice(0,_stack_a.size()-1): wrong_pool.append(e["name"])
	while wrong_pool.size()<3:
		var r:Dictionary=RUNES[randi()%RUNES.size()]
		if r["name"]!=correct_name: wrong_pool.append(r["name"])
	wrong_pool.shuffle(); _prompt_correct_idx=randi()%3; var wi:=0
	for i in range(3):
		var b:Button=_prompt_btns[i]
		b.text=correct_name if i==_prompt_correct_idx else wrong_pool[wi]
		b.disabled=false; b.modulate=COL_WHITE
		if i!=_prompt_correct_idx: wi+=1
	var preview:Array=[]
	for e:Dictionary in _stack_a: preview.append(_item_display(e))
	_prompt_q_lbl.text="Quick check!\n\nstack = [%s]\n\nstack.pop() returns what?" % ", ".join(preview)
	_prompt_res_lbl.visible=false; _prompt_panel.visible=true

func _on_prompt_btn(idx:int)->void:
	if not _prompt_active: return
	var correct_name:String=_stack_a.back()["name"] if not _stack_a.is_empty() else "?"
	if idx==_prompt_correct_idx:
		_prompt_res_lbl.add_theme_color_override("font_color",COL_TOP)
		_prompt_res_lbl.text='Correct! pop() returns "%s".\nLIFO: pushed last -> leaves first.' % correct_name
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_OK)
	else:
		_prompt_res_lbl.add_theme_color_override("font_color",COL_WRONG)
		_prompt_res_lbl.text='Wrong! pop() returns "%s", not "%s".\nLast In = First Out!' \
			% [correct_name,(_prompt_btns[idx] as Button).text]
		if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)
	for b:Button in _prompt_btns: b.disabled=true
	_prompt_res_lbl.visible=true
	await get_tree().create_timer(2.8).timeout
	_prompt_panel.visible=false; _prompt_active=false

# ─── FEEDBACK ─────────────────────────────────────────────────────────────────
func _apply_correct(nd:Node2D,pts:int)->void:
	_stat["correct"]+=1; _combo+=1; _combo_decay=COMBO_TTL
	var earned:=pts*(1+_combo/5); _score+=earned; _score_lbl.text="Score: %d" % _score
	_combo_lbl.text="x%d COMBO!" % _combo if _combo>1 else ""
	_acc_lbl.text="Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd): _flash(nd,COL_TOP); _bounce(nd); _float(nd,"+%d" % earned,COL_TOP)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_OK)
	if _stat["correct"]>=_p["target_correct"] and _p["mode"] in ["push_pop","peek","overflow"]:
		_end_game(true)

func _apply_wrong(nd:Node2D,penalty:int,msg:String,count:bool=true)->void:
	_combo=0; _combo_lbl.text=""
	if penalty>0: _score=max(0,_score-penalty); _score_lbl.text="Score: %d" % _score
	_acc_lbl.text="Accuracy: %.0f%%" % _accuracy()
	if is_instance_valid(nd): _flash(nd,COL_WRONG); _shake(nd)
	if not msg.is_empty(): _show_context_feedback(nd,msg)
	if count: _lives-=1; _refresh_lives(); if _lives<=0: _end_game(false)
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_FAIL)

func _show_hint(text:String)->void: _hint_lbl.text=text; _hint_box.visible=true

func _show_context_feedback(nd:Node2D,text:String)->void:
	_show_hint(text)
	if not is_instance_valid(nd): return
	var par:=nd.get_parent(); if not par: return
	var lbl:=Label.new(); lbl.text=text; lbl.z_index=200
	if _pixel_font: lbl.add_theme_font_override("font",_pixel_font)
	lbl.add_theme_font_size_override("font_size",14)
	lbl.add_theme_color_override("font_color",COL_WRONG)
	lbl.add_theme_color_override("font_shadow_color",Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x",1)
	lbl.add_theme_constant_override("shadow_offset_y",1)
	par.add_child(lbl); lbl.global_position=nd.global_position+Vector2(-60,-70)
	var tw:=lbl.create_tween()
	tw.tween_property(lbl,"position",lbl.position+Vector2(0,-55),1.2)
	tw.parallel().tween_property(lbl,"modulate:a",0.0,1.2)
	tw.tween_callback(lbl.queue_free)

func _show_task_card(text:String)->void:
	_task_card.visible=true; _task_lbl.text=text
	var tw:=_task_card.create_tween()
	tw.tween_property(_task_card,"modulate",COL_TOP,.1)
	tw.tween_property(_task_card,"modulate",COL_WHITE,.4)
func _dismiss_task_card()->void: _task_card.visible=false; _current_task=""

# ─── ANIMATIONS ───────────────────────────────────────────────────────────────
func _flash(nd:Node2D,c:Color)->void:
	if not is_instance_valid(nd): return
	nd.create_tween().tween_property(nd,"modulate",c,.06)
	nd.create_tween().tween_property(nd,"modulate",COL_WHITE,.28)
func _bounce(nd:Node2D)->void:
	if not is_instance_valid(nd): return
	var s:=nd.scale; var tw:=nd.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(nd,"scale",s*1.4,.08); tw.tween_property(nd,"scale",s,.18)
func _shake(nd:Node2D)->void:
	if not is_instance_valid(nd): return
	var o:=nd.position; var tw:=nd.create_tween()
	for _i in range(6):
		tw.tween_property(nd,"position",o+Vector2(randf_range(-7,7),randf_range(-4,4)),.04)
	tw.tween_property(nd,"position",o,.04)
func _pulse(nd:Node2D,color:Color)->void:
	if not is_instance_valid(nd): return
	var tw:=nd.create_tween()
	for _i in range(4):
		tw.tween_property(nd,"modulate",color,.07); tw.tween_property(nd,"modulate",COL_WHITE,.07)
func _float(nd:Node2D,text:String,color:Color)->void:
	if not is_instance_valid(nd): return
	var par:=nd.get_parent(); if not par: return
	var lbl:=Label.new(); lbl.text=text; lbl.z_index=200
	if _pixel_font: lbl.add_theme_font_override("font",_pixel_font)
	lbl.add_theme_font_size_override("font_size",18)
	lbl.add_theme_color_override("font_color",color)
	par.add_child(lbl); lbl.global_position=nd.global_position+Vector2(-20,-44)
	var tw:=lbl.create_tween()
	tw.tween_property(lbl,"position",lbl.position+Vector2(0,-40),.8)
	tw.parallel().tween_property(lbl,"modulate:a",0.0,.8)
	tw.tween_callback(lbl.queue_free)

# ─── CLOCK / HUD ──────────────────────────────────────────────────────────────
func _tick_clock()->void:
	_time_left-=1.0; _timer_lbl.text="T %d" % max(0,int(_time_left))
	if _time_left<=0.0: _end_game(false)
func _refresh_lives()->void:
	# queue_free() is deferred — old labels linger until end-of-frame causing
	# new labels to stack on top, so hearts never visually decrease.
	# free() removes them immediately so the row always reflects current lives.
	for c in _lives_row.get_children(): c.free()
	for i in range(3):
		var l:=Label.new()
		l.text = "♥" if i < _lives else "♡"
		if _pixel_font: l.add_theme_font_override("font", _pixel_font)
		l.add_theme_font_size_override("font_size", 22)
		l.add_theme_color_override("font_color",
			Color(0.93, 0.20, 0.20) if i < _lives else Color(0.35, 0.30, 0.40))
		_lives_row.add_child(l)
func _accuracy()->float:
	var t:=int(_stat["correct"])+int(_stat["wrong_pop"])+int(_stat["wrong_push"]) \
		+int(_stat["sequence_break"])+int(_stat["overflow"])+int(_stat["bracket_mismatch"])
	return 100.0 if t==0 else float(_stat["correct"])/float(t)*100.0

func _rune_emoji(key:String)->String:
	match key:
		"fire":  return "Fire"
		"ice":   return "Ice"
		"wind":  return "Wind"
		"earth": return "Earth"
		"dark":  return "Dark"
		"light": return "Light"
	return "*"

# ─── END GAME ─────────────────────────────────────────────────────────────────
func _end_game(success:bool)->void:
	if not _alive: return
	_alive=false; _game_tmr.stop()
	var acc:=_accuracy(); var grade:=_calc_grade(success,acc)
	var stars:=_grade_to_stars(grade)
	var summary:String
	if success: summary="Cleared! Grade: %s\nAccuracy: %.0f%%\n\n%s" % [grade,acc,_grade_tip(grade)]
	else:       summary="Failed. Grade: %s\nAccuracy: %.0f%%\n\n%s" % [grade,acc,_dominant_mistake()]
	_fail_summary.visible=true; _fail_lbl.text=summary
	if has_node("/root/GameRouter"): GameRouter.current_chapter=_chapter_id
	await get_tree().create_timer(1.8).timeout; _show_code_snippet()
	await get_tree().create_timer(5.0).timeout
	if has_node("/root/GameRouter"):
		# chapter_complete_with_stats already calls PlayerProfile.save_chapter_result
		# internally (no double-save), and passes a flat dict to ChapterCompleteScreen
		# so _resolve_total() only ever adds ints — never a nested Dictionary.
		GameRouter.chapter_complete_with_stats(_chapter_id, {
			"score":    _score,
			"stars":    stars,
			"grade":    grade,
			"accuracy": acc,
			"correct":  _stat["correct"],
			"success":  success,
		})
	else:
		get_tree().change_scene_to_file("res://scenes/world_map/WorldMap.tscn")

func _show_code_snippet()->void:
	var concept:String=_p["concept"]; if concept not in CODE_SNIPPETS: return
	var tw_out:=_fail_summary.create_tween()
	tw_out.tween_property(_fail_summary,"modulate:a",0.0,.4); await tw_out.finished
	_fail_summary.visible=false; _fail_summary.modulate.a=1.0
	_code_lbl.text="What you just practiced:\n\n"+CODE_SNIPPETS[concept]
	_code_panel.modulate.a=0.0; _code_panel.visible=true
	_code_panel.create_tween().tween_property(_code_panel,"modulate:a",1.0,.6)

func _calc_grade(success:bool,acc:float)->String:
	if not success:
		return "C" if acc>=60.0 else "F"
	if acc>=95.0:
		return "S"
	elif acc>=82.0:
		return "A"
	elif acc>=68.0:
		return "B"
	return "C"
func _dominant_mistake()->String:
	var ranked:Array=[
		["wrong_pop","You clicked non-top items (LIFO violation)."],
		["sequence_break","Wrong pop order -- plan push order in reverse!"],
		["overflow","Pushed past the limit without popping first."],
		["wrong_push","Pushed when pop or peek was required."],
		["bracket_mismatch","Bracket pairs mismatched."],
	]
	var best:="Keep practising!"; var best_cnt:=0
	for pair in ranked:
		var cnt:int=_stat[pair[0]]; if cnt>best_cnt: best_cnt=cnt; best=pair[1]
	return best
func _grade_tip(grade:String)->String:
	match grade:
		"S": return "Flawless!"
		"A": return "Excellent."
		"B": return "Good -- watch the order."
		"C": return "Review: only the TOP is accessible."
	return ""
func _grade_to_stars(grade:String)->int:
	match grade:
		"S","A": return 3
		"B":     return 2
		"C":     return 1
		_:       return 0

# ─── SETUP ────────────────────────────────────────────────────────────────────
func _setup_bg()->void:
	if is_instance_valid(_bg): _bg.visible=false
	_parallax_layers.clear()
	const BASE_PATH:="res://assets/art/stack/bg/"
	var layers:Array[Dictionary]=[
		{"file":"cave_0003_color.png","z":-20,"speed":0.0,"alpha":1.00},
		{"file":"cave_0002_back.png","z":-17,"speed":6.0,"alpha":0.88},
		{"file":"cave_0001_mid.png","z":-14,"speed":14.0,"alpha":0.92},
		{"file":"cave_0000_front.png","z":-11,"speed":28.0,"alpha":1.00},
	]
	for d in layers:
		var path:String=BASE_PATH+(d["file"] as String)
		if not ResourceLoader.exists(path): continue
		var tex:=load(path) as Texture2D; if tex==null: continue
		var sx:=1280.0/float(tex.get_width()); var sy:=720.0/float(tex.get_height())
		var speed:float=d["speed"]; var copies:=2 if speed>0.0 else 1
		for c in range(copies):
			var sp:=Sprite2D.new(); sp.texture=tex
			sp.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR; sp.centered=false
			sp.scale=Vector2(sx,sy); sp.modulate.a=d["alpha"]; sp.z_index=d["z"]
			sp.position=Vector2(c*1280.0,0.0); sp.set_meta("scroll_speed",speed)
			add_child(sp); _parallax_layers.append(sp)
	var ov:=ColorRect.new(); ov.color=Color(0,0,0,.48)
	ov.size=Vector2(1280,720); ov.position=Vector2.ZERO; ov.z_index=-10; add_child(ov)

func _setup_timer()->void:
	if _p["time_limit"]>0:
		_game_tmr.wait_time=1.0; _game_tmr.one_shot=false
		_game_tmr.timeout.connect(_tick_clock); _game_tmr.start()

func _setup_columns()->void:
	_hbar_a.max_value=_p["max_height"]; _hbar_a.value=0
	_hbar_a.add_theme_stylebox_override("background",CastleTheme.progress_bg())
	_hbar_a.add_theme_stylebox_override("fill",CastleTheme.progress_fill())
	_add_column_shaft(COL_A_X); _bob_crown(_crown_a)

func _bob_crown(crown:Node2D)->void:
	if not is_instance_valid(crown): return
	crown.visible=false; var tw:=crown.create_tween().set_loops()
	tw.tween_property(crown,"position:y",crown.position.y-10,.5)
	tw.tween_property(crown,"position:y",crown.position.y,.5)

func _add_column_shaft(col_x:float)->void:
	const SHAFT_W:=112.0
	var h:=float(_p["max_height"])*SLOT_H+80.0; var x:=col_x-SHAFT_W/2.0; var y:=BASE_Y-h+24.0
	var border:=ColorRect.new(); border.color=Color(.08,.06,.12)
	border.size=Vector2(SHAFT_W+8,h+8); border.position=Vector2(x-4,y-4); border.z_index=-3; add_child(border)
	var bg:=ColorRect.new(); bg.color=Color(.10,.08,.14)
	bg.size=Vector2(SHAFT_W,h); bg.position=Vector2(x,y); bg.z_index=-2; add_child(bg)
	for xo:float in [0.0,SHAFT_W-4.0]:
		var e:=ColorRect.new(); e.color=Color(.22,.18,.30)
		e.size=Vector2(4,h); e.position=Vector2(x+xo,y); e.z_index=-1; add_child(e)
	var cap:=ColorRect.new(); cap.color=CastleTheme.C_GOLD
	cap.size=Vector2(SHAFT_W+8,4); cap.position=Vector2(x-4,y-4); cap.z_index=-1; add_child(cap)
	var base_r:=ColorRect.new(); base_r.color=Color(.18,.14,.24)
	base_r.size=Vector2(SHAFT_W+8,8); base_r.position=Vector2(x-4,BASE_Y+4); base_r.z_index=-1; add_child(base_r)
	var torch:=ColorRect.new(); torch.color=CastleTheme.C_TORCH
	torch.size=Vector2(6,12); torch.position=Vector2(x+6,y+8); torch.z_index=-1; add_child(torch)

func _goal_text()->String:
	match _p["mode"]:
		"push_pop": return "Push & pop %d times" % _p["target_correct"]
		"peek":     return "Complete %d tasks" % _p["target_correct"]
		"overflow": return "Build %d rainbows" % (int(_p["target_correct"]) / 7)
		"undo":     return "Undo %d word sets" % _p["target_correct"]
		"brackets": return "Solve %d bracket strings" % _p["target_correct"]
	return ""

func _lbl(text:String,sz:int,color:Color)->Label:
	var l:=Label.new(); l.text=text; l.add_theme_color_override("font_color",color)
	if _pixel_font: l.add_theme_font_override("font",_pixel_font)
	l.add_theme_font_size_override("font_size",sz); return l

func _btn(text:String,n:StyleBoxFlat,h:StyleBoxFlat,color:Color)->Button:
	var b:=Button.new(); b.text=text
	b.add_theme_stylebox_override("normal",n); b.add_theme_stylebox_override("hover",h)
	b.add_theme_stylebox_override("pressed",CastleTheme.btn_pressed())
	b.add_theme_color_override("font_color",color)
	b.add_theme_color_override("font_hover_color",CastleTheme.C_GOLD)
	if _pixel_font: b.add_theme_font_override("font",_pixel_font)
	b.add_theme_font_size_override("font_size",15); return b

func _panel_nd(nm:String,z:int,style:StyleBoxFlat)->PanelContainer:
	var p:=PanelContainer.new(); p.name=nm; p.z_index=z
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.add_theme_stylebox_override("panel",style); return p

func _setup_new_nodes()->void:
	var hud:=$HUD as CanvasLayer

	# Intro overlay is now a CanvasLayer built in _build_intro_canvas()
	# called from _show_intro() — nothing to set up here

	# peek button
	_peek_btn=_btn("Peek Top",CastleTheme.btn_info_normal(),CastleTheme.btn_info_hover(),CastleTheme.C_SAPPHIRE)
	_peek_btn.visible=_p["mode"] in ["overflow","undo"]
	_peek_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_peek_btn.set_offset(SIDE_LEFT,10); _peek_btn.set_offset(SIDE_TOP,114)
	_peek_btn.set_offset(SIDE_RIGHT,155); _peek_btn.set_offset(SIDE_BOTTOM,142)
	_peek_btn.pressed.connect(_on_peek_pressed); hud.add_child(_peek_btn)

	# stack display
	_stack_disp_panel=_panel_nd("StackDisplay",15,CastleTheme.stone_panel(CastleTheme.C_STONE_LIGHT,1))
	_stack_disp_panel.set_offset(SIDE_LEFT,10); _stack_disp_panel.set_offset(SIDE_TOP,150)
	_stack_disp_panel.set_offset(SIDE_RIGHT,225); _stack_disp_panel.set_offset(SIDE_BOTTOM,590)
	hud.add_child(_stack_disp_panel)
	_stack_disp_lbl=_lbl("",14,CastleTheme.C_PARCHMENT_DIM)
	_stack_disp_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _stack_disp_panel.add_child(_stack_disp_lbl)

	# op flash
	_op_flash_lbl=_lbl("",22,CastleTheme.C_GOLD); _op_flash_lbl.modulate.a=0.0; _op_flash_lbl.z_index=55
	_op_flash_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_op_flash_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_op_flash_lbl.set_offset(SIDE_LEFT,330); _op_flash_lbl.set_offset(SIDE_TOP,205)
	_op_flash_lbl.set_offset(SIDE_RIGHT,950); _op_flash_lbl.set_offset(SIDE_BOTTOM,255)
	hud.add_child(_op_flash_lbl)

	# code panel
	_code_panel=_panel_nd("CodePanel",60,CastleTheme.code_panel()); _code_panel.visible=false
	_code_panel.set_offset(SIDE_LEFT,140); _code_panel.set_offset(SIDE_TOP,90)
	_code_panel.set_offset(SIDE_RIGHT,1140); _code_panel.set_offset(SIDE_BOTTOM,530)
	hud.add_child(_code_panel)
	_code_lbl=_lbl("",14,CastleTheme.C_PARCHMENT_DIM)
	_code_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _code_panel.add_child(_code_lbl)

	# comprehension prompt
	_prompt_panel=_panel_nd("Prompt",70,CastleTheme.royal_panel()); _prompt_panel.visible=false
	_prompt_panel.set_offset(SIDE_LEFT,200); _prompt_panel.set_offset(SIDE_TOP,180)
	_prompt_panel.set_offset(SIDE_RIGHT,1080); _prompt_panel.set_offset(SIDE_BOTTOM,520)
	hud.add_child(_prompt_panel)
	var pvb:=VBoxContainer.new(); pvb.add_theme_constant_override("separation",14); _prompt_panel.add_child(pvb)
	_prompt_q_lbl=_lbl("",18,CastleTheme.C_PARCHMENT)
	_prompt_q_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_prompt_q_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; pvb.add_child(_prompt_q_lbl)
	var pbrow:=HBoxContainer.new(); pbrow.alignment=BoxContainer.ALIGNMENT_CENTER
	pbrow.add_theme_constant_override("separation",20); pvb.add_child(pbrow)
	_prompt_btns.clear()
	for i in range(3):
		var b:=_btn("?",CastleTheme.btn_normal(),CastleTheme.btn_hover(),CastleTheme.C_PARCHMENT)
		b.custom_minimum_size=Vector2(200,48); b.pressed.connect(_on_prompt_btn.bind(i))
		_prompt_btns.append(b); pbrow.add_child(b)
	_prompt_res_lbl=_lbl("",16,CastleTheme.C_PARCHMENT)
	_prompt_res_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_prompt_res_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_prompt_res_lbl.visible=false; pvb.add_child(_prompt_res_lbl)

	# undo history
	_undo_panel=_panel_nd("UndoHistory",15,CastleTheme.scroll_panel()); _undo_panel.visible=false
	_undo_panel.set_offset(SIDE_LEFT,820); _undo_panel.set_offset(SIDE_TOP,120)
	_undo_panel.set_offset(SIDE_RIGHT,1270); _undo_panel.set_offset(SIDE_BOTTOM,400)
	hud.add_child(_undo_panel)
	_undo_lbl=_lbl("Typing history:\n(nothing yet)",14,CastleTheme.C_PARCHMENT)
	_undo_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; _undo_panel.add_child(_undo_lbl)

	# bracket panel
	_bracket_panel=_panel_nd("BracketPanel",15,CastleTheme.scroll_panel()); _bracket_panel.visible=false
	_bracket_panel.set_offset(SIDE_LEFT,820); _bracket_panel.set_offset(SIDE_TOP,120)
	_bracket_panel.set_offset(SIDE_RIGHT,1270); _bracket_panel.set_offset(SIDE_BOTTOM,450)
	hud.add_child(_bracket_panel)
	var bvb:=VBoxContainer.new(); bvb.add_theme_constant_override("separation",8); _bracket_panel.add_child(bvb)
	_bracket_lbl=_lbl("BRACKET STRING",13,CastleTheme.C_PARCHMENT_DIM); bvb.add_child(_bracket_lbl)
	_bracket_str_lbl=_lbl("",22,CastleTheme.C_GOLD)
	_bracket_str_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; bvb.add_child(_bracket_str_lbl)

	# NEW: item tray
	var tray_lbl:=_lbl("Click an item in the tray to PUSH it  •  Drag ♛ crown UP to POP",12,CastleTheme.C_PARCHMENT_DIM)
	tray_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	tray_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tray_lbl.set_offset(SIDE_LEFT,240); tray_lbl.set_offset(SIDE_TOP,614)
	tray_lbl.set_offset(SIDE_RIGHT,1040); tray_lbl.set_offset(SIDE_BOTTOM,632)
	hud.add_child(tray_lbl)
	_tray_container=HBoxContainer.new(); _tray_container.name="ItemTray"
	_tray_container.alignment=BoxContainer.ALIGNMENT_CENTER
	_tray_container.add_theme_constant_override("separation",int(TRAY_GAP))
	_tray_container.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tray_container.set_offset(SIDE_LEFT,240); _tray_container.set_offset(SIDE_TOP,634)
	_tray_container.set_offset(SIDE_RIGHT,1040); _tray_container.set_offset(SIDE_BOTTOM,714)
	hud.add_child(_tray_container)
	_tray_container.visible=(_p["mode"]!="brackets")

	# NEW: rainbow result row
	_rainbow_result_row=HBoxContainer.new(); _rainbow_result_row.name="RainbowResult"
	_rainbow_result_row.alignment=BoxContainer.ALIGNMENT_CENTER
	_rainbow_result_row.add_theme_constant_override("separation",2)
	_rainbow_result_row.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_rainbow_result_row.set_offset(SIDE_LEFT,240); _rainbow_result_row.set_offset(SIDE_TOP,506)
	_rainbow_result_row.set_offset(SIDE_RIGHT,1040); _rainbow_result_row.set_offset(SIDE_BOTTOM,534)
	_rainbow_result_row.visible=(_p["mode"]=="overflow")
	hud.add_child(_rainbow_result_row)
	if _p["mode"]=="overflow":
		for rc:Dictionary in RAINBOW_COLORS:
			var sw:=ColorRect.new(); sw.color=rc["color"]
			sw.custom_minimum_size=Vector2(110,24); sw.modulate=Color(.2,.2,.2,.5)
			_rainbow_result_row.add_child(sw)

	# ── PEEK: face-down riddle panel ─────────────────────────────────────────────
	_peek_riddle_panel=_panel_nd("PeekRiddle",40,CastleTheme.royal_panel())
	_peek_riddle_panel.visible=false
	_peek_riddle_panel.set_offset(SIDE_LEFT,240); _peek_riddle_panel.set_offset(SIDE_TOP,240)
	_peek_riddle_panel.set_offset(SIDE_RIGHT,1040); _peek_riddle_panel.set_offset(SIDE_BOTTOM,460)
	hud.add_child(_peek_riddle_panel)
	var rvb:=VBoxContainer.new(); rvb.add_theme_constant_override("separation",16)
	_peek_riddle_panel.add_child(rvb)
	_peek_riddle_lbl=_lbl("",17,CastleTheme.C_PARCHMENT)
	_peek_riddle_lbl.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_peek_riddle_lbl.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; rvb.add_child(_peek_riddle_lbl)
	# Peek button embedded in riddle panel
	var peek_in_panel:=_btn("👁 Press & Hold Top Card to Peek",
		CastleTheme.btn_info_normal(),CastleTheme.btn_info_hover(),CastleTheme.C_SAPPHIRE)
	peek_in_panel.pressed.connect(_start_peek_hold); rvb.add_child(peek_in_panel)
	var rbrow:=HBoxContainer.new(); rbrow.alignment=BoxContainer.ALIGNMENT_CENTER
	rbrow.add_theme_constant_override("separation",20); rvb.add_child(rbrow)
	_peek_answer_btns.clear()
	for i in range(3):
		var b:=_btn("?",CastleTheme.btn_normal(),CastleTheme.btn_hover(),CastleTheme.C_PARCHMENT)
		b.custom_minimum_size=Vector2(200,52); b.pressed.connect(_on_peek_answer_btn.bind(i))
		_peek_answer_btns.append(b); rbrow.add_child(b)

	# ── PEEK: standalone peek button (non-face-down tiers + hint area) ───────
	_peek_btn.visible=(_p["mode"] in ["overflow","undo"])

	# PauseButton is defined in StackGame.tscn — just style and wire it here
	_setup_pause_button()

func _setup_hud()->void:
	var lbls:Array=[_score_lbl,_combo_lbl,_timer_lbl,_goal_lbl,_acc_lbl,
		_hint_lbl,_task_lbl,_seq_lbl,_fail_lbl,_stack_disp_lbl,_op_flash_lbl,
		_prompt_q_lbl,_prompt_res_lbl,_bracket_lbl,_bracket_str_lbl]
	for l in lbls:
		if not is_instance_valid(l): continue
		if _pixel_font: l.add_theme_font_override("font",_pixel_font)
		l.add_theme_font_size_override("font_size",16)
	for b:Button in _prompt_btns:
		if not is_instance_valid(b): continue
		if _pixel_font: b.add_theme_font_override("font",_pixel_font)
		b.add_theme_font_size_override("font_size",15)
	if is_instance_valid(_code_lbl): _code_lbl.add_theme_font_size_override("font_size",14)
	if is_instance_valid(_stack_disp_lbl): _stack_disp_lbl.add_theme_font_size_override("font_size",14)
	if is_instance_valid(_op_flash_lbl): _op_flash_lbl.add_theme_font_size_override("font_size",22)
	if is_instance_valid(_prompt_q_lbl): _prompt_q_lbl.add_theme_font_size_override("font_size",18)
	_score_lbl.text="Score: 0"; _combo_lbl.text=""; _acc_lbl.text="Accuracy: -"
	_goal_lbl.text=_goal_text(); _timer_lbl.visible=_p["time_limit"]>0
	if _p["time_limit"]>0: _time_left=_p["time_limit"]; _timer_lbl.text="T %d" % int(_time_left)
	_refresh_lives()

func _setup_pause_button()->void:
	if not is_instance_valid(_pause_btn): return

	# Style — transparent background, gold icon, no focus ring
	var sty_normal:=StyleBoxFlat.new()
	sty_normal.bg_color      = Color(0.08, 0.06, 0.12, 0.72)
	sty_normal.border_color  = Color(0.50, 0.40, 0.70, 0.45)
	sty_normal.set_border_width_all(1)
	sty_normal.set_corner_radius_all(8)
	sty_normal.set_content_margin_all(6)

	var sty_hover:=sty_normal.duplicate() as StyleBoxFlat
	sty_hover.bg_color     = Color(0.18, 0.14, 0.28, 0.90)
	sty_hover.border_color = CastleTheme.C_GOLD
	sty_hover.set_border_width_all(2)

	var sty_pressed:=sty_hover.duplicate() as StyleBoxFlat
	sty_pressed.bg_color   = Color(0.10, 0.08, 0.18, 0.90)

	var sty_empty:=StyleBoxEmpty.new()

	for style_name in ["normal","hover","pressed"]:
		var s:StyleBoxFlat = sty_normal if style_name=="normal" 							else sty_hover if style_name=="hover" else sty_pressed
		_pause_btn.add_theme_stylebox_override(style_name, s)
	_pause_btn.add_theme_stylebox_override("focus", sty_empty)   # no blue ring

	if _pixel_font: _pause_btn.add_theme_font_override("font", _pixel_font)
	_pause_btn.add_theme_font_size_override("font_size", 22)
	_pause_btn.add_theme_color_override("font_color",         CastleTheme.C_GOLD)
	_pause_btn.add_theme_color_override("font_hover_color",   Color(1.0, 0.95, 0.55))
	_pause_btn.add_theme_color_override("font_pressed_color", CastleTheme.C_GOLD_DIM)

	# Wire to PauseMenu.toggle()
	_pause_btn.pressed.connect(func():
		var pm:=get_node_or_null("PauseMenu")
		if pm and pm.has_method("toggle"): pm.toggle())

	# Also wire PauseMenu.howto_requested so How-to-Play reopens the intro
	var pm:=get_node_or_null("PauseMenu")
	if pm and pm.has_signal("howto_requested"):
		if not pm.howto_requested.is_connected(_reopen_intro):
			pm.howto_requested.connect(_reopen_intro)

	# Animate a brief pulse on first appearance so player notices it
	_pause_btn.modulate.a = 0.0
	var tw:=_pause_btn.create_tween()
	tw.tween_property(_pause_btn, "modulate:a", 1.0, 0.6)
	tw.tween_property(_pause_btn, "scale", Vector2(1.08, 1.08), 0.12)
	tw.tween_property(_pause_btn, "scale", Vector2.ONE,         0.12)


func _apply_castle_theme()->void:
	_hint_box.add_theme_stylebox_override("panel",CastleTheme.alcove_panel())
	_task_card.add_theme_stylebox_override("panel",CastleTheme.royal_panel())
	_seq_banner.add_theme_stylebox_override("panel",CastleTheme.scroll_panel())
	_fail_summary.add_theme_stylebox_override("panel",CastleTheme.stone_panel(CastleTheme.C_GOLD,3))
	for l:Label in [_score_lbl,_combo_lbl,_timer_lbl,_goal_lbl,_acc_lbl]:
		if is_instance_valid(l): l.add_theme_color_override("font_color",CastleTheme.C_PARCHMENT)
	if is_instance_valid(_hint_lbl): _hint_lbl.add_theme_color_override("font_color",CastleTheme.C_PARCHMENT_DIM)
	if is_instance_valid(_task_lbl): _task_lbl.add_theme_color_override("font_color",CastleTheme.C_GOLD)
	if is_instance_valid(_seq_lbl):  _seq_lbl.add_theme_color_override("font_color",CastleTheme.C_PARCHMENT)
	if is_instance_valid(_fail_lbl): _fail_lbl.add_theme_color_override("font_color",CastleTheme.C_PARCHMENT)
