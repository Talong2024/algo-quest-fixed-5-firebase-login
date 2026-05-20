# =============================================================================
# AlgoQuest — Chapters 1–5: Queue Town
# File: scripts/chapters/queue/QueueGame.gd
#
# Chapter / Tier map (from GameRouter):
#   Ch 1 → Tier 0  ENQUEUE    Values visible, drag holding → ANY queue slot (free placement)
#   Ch 2 → Tier 1  DEQUEUE    Queue PRE-FILLED in wrong order; must dequeue to fix
#   Ch 3 → Tier 2  PEEK       Values hidden, click to reveal (free), then sort
#   Ch 4 → Tier 3  ISEMPTY/ISFULL  Boundary checks + bomb citizens to reject
#   Ch 5 → Tier 4  SCHEDULER  Hidden values + limited move budget
#
# MECHANIC:
#   • Citizens are animated sprites (value 1–9)
#   • Holding area: right side, up to N tokens waiting.
#   • Queue lane: centre, MAX_QUEUE slots in a horizontal row.
#   • Goal: sort queue ASCENDING left→right (lowest at FRONT [0]).
#
#   Tier 0 (ENQUEUE) — FREE PLACEMENT:
#     Drag any holding token → any empty queue slot (not just the back).
#     Submit when sorted.
#
#   Tier 1 (DEQUEUE) — PRE-FILLED QUEUE:
#     Queue starts filled in random (wrong) order — no holding tokens.
#     Drag front [0] → holding area  = dequeue()
#     Drag holding  → queue          = enqueue() (appends to back)
#     Submit when sorted.
#
#   Tier 2+ — same as before.
# =============================================================================

extends Node2D

# ── Assets ────────────────────────────────────────────────────────────────────
const PATH_FONT     := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_OK   := "res://assets/codemon/audio/sfx/success.ogg"
const PATH_SFX_FAIL := "res://assets/codemon/audio/sfx/fail.ogg"
const PATH_BGM      := "res://assets/medieval/audio/music/silverbook_loop.ogg"

const PATH_PORTAL   := "res://assets/art/fx/Purple_Portal_Sprite_Sheet.png"

const PATH_BG_SKY      := "res://assets/art/bg/layer_5_sky.png"
const PATH_BG_MOUNT    := "res://assets/art/bg/layer_4_mountains.png"
const PATH_BG_CASTLE   := "res://assets/art/bg/layer_castle.png"
const PATH_BG_FAR      := "res://assets/art/bg/layer_3_trees_far.png"
const PATH_BG_MID      := "res://assets/art/bg/layer_2_trees_mid.png"
const PATH_BG_FRONT    := "res://assets/art/bg/layer_1_trees_front.png"

# ── Animated character sprites ────────────────────────────────────────────────
const SPRITE_W    : int = 24
const SPRITE_H    : int = 24
const SPRITE_SCALE: int = 3

const CHAR_KEYS : Array[String] = [
	"peasant_boy",
	"peasant_girl",
	"peasant_young_man_a",
	"peasant_young_woman_a",
	"peasant_mid_man",
	"peasant_mid_woman",
	"merchant",
	"noble_king",
	"noble_queen",
]

const ANIM_FRAMES : Array[String] = ["_walk1", "_stand", "_walk2"]
const ANIM_PATH   := "res://assets/art/character/anim/"

# ── Layout constants ──────────────────────────────────────────────────────────
const SW           := 1280.0
const SH           := 720.0

const MAX_QUEUE    := 6
const LANE_X0      := 220.0   # pushed right so portal has room on the left
const LANE_Y_CEN   := 380.0   # slightly lower — more vertical breathing room
const SLOT_W       := 128.0
const SLOT_H       := 110.0
const TOKEN_R      := 38.0

const HOLD_X       := 1140.0  # holding column centre
const HOLD_Y0      := 200.0   # start lower so badge doesn't clip top HUD
const HOLD_GAP     := 100.0
const MAX_HOLD     := 5

# Portal / submit zone sits left of the lane with plenty of space
const SUB_X        := 96.0
const SUB_Y        := 380.0
const SUB_R        := 60.0

const DROP_R       := 64.0

# ── Colors ────────────────────────────────────────────────────────────────────
const COL_BG       := Color(0.055, 0.043, 0.141)
const COL_PANEL    := Color(0.10,  0.09,  0.22,  0.9)
const COL_BORDER   := Color(0.55,  0.45,  0.18)
const COL_GOLD     := Color(0.92,  0.75,  0.22)
const COL_GREEN    := Color(0.22,  0.80,  0.42)
const COL_RED      := Color(0.85,  0.20,  0.20)
const COL_BLUE     := Color(0.35,  0.55,  0.90)
const COL_AMBER    := Color(0.85,  0.58,  0.14)
const COL_PARCH    := Color(0.88,  0.82,  0.60)
const COL_WHITE    := Color(0.94,  0.92,  0.86)
const COL_GRAY     := Color(0.38,  0.38,  0.48)
const COL_DARK     := Color(0.05,  0.04,  0.14)
const COL_FRONT    := Color(0.22,  0.80,  0.42)

const COL_PARCH_BG  := Color(0.18, 0.14, 0.08, 0.97)
const COL_PARCH_LT  := Color(0.88, 0.82, 0.60)
const COL_SCROLL_BD := Color(0.55, 0.40, 0.12)
const COL_FOREST_DK := Color(0.10, 0.16, 0.08)
const COL_FOREST_BD := Color(0.22, 0.42, 0.18)

const TOKEN_COLS : Array = [
	Color(0.85, 0.35, 0.25),
	Color(0.85, 0.58, 0.14),
	Color(0.78, 0.78, 0.20),
	Color(0.25, 0.72, 0.38),
	Color(0.20, 0.65, 0.80),
	Color(0.30, 0.45, 0.85),
	Color(0.58, 0.32, 0.85),
	Color(0.85, 0.30, 0.60),
	Color(0.50, 0.80, 0.80),
]

# ── Tier params ───────────────────────────────────────────────────────────────
# NOTE:
#   "free_place" = true  →  enqueue drag inserts into the clicked slot (Tier 0)
#   "prefill"    = true  →  queue starts already filled in random order (Tier 1)
const TIER_PARAMS : Array[Dictionary] = [
	{ "mode":"enqueue",   "hidden":false, "bombs":false, "move_budget":0,
	  "citizens":4, "rounds":3, "concept":"ENQUEUE",
	  "free_place":true,  "prefill":false },   # Ch1 — place anywhere

	{ "mode":"dequeue",   "hidden":false, "bombs":false, "move_budget":0,
	  "citizens":5, "rounds":4, "concept":"DEQUEUE",
	  "free_place":false, "prefill":true },    # Ch2 — pre-filled, must dequeue to fix

	{ "mode":"peek",      "hidden":true,  "bombs":false, "move_budget":0,
	  "citizens":5, "rounds":4, "concept":"PEEK",
	  "free_place":false, "prefill":false },

	{ "mode":"bounds",    "hidden":false, "bombs":true,  "move_budget":0,
	  "citizens":6, "rounds":4, "concept":"BOUNDS",
	  "free_place":false, "prefill":false },

	{ "mode":"scheduler", "hidden":true,  "bombs":false, "move_budget":12,
	  "citizens":6, "rounds":5, "concept":"SCHEDULER",
	  "free_place":false, "prefill":false },
]

# ── Node refs (@onready from tscn) ────────────────────────────────────────────
@onready var _world      : Node2D         = $WorldLayer
@onready var _game_timer : Timer          = $GameTimer
@onready var _spawn_timer: Timer          = $SpawnTimer
@onready var _score_lbl  : Label          = $HUD/ScoreLabel
@onready var _round_lbl  : Label          = $HUD/RoundLabel
@onready var _moves_lbl  : Label          = $HUD/MovesLabel
@onready var _acc_lbl    : Label          = $HUD/AccLabel
@onready var _lives_row  : HBoxContainer  = $HUD/LivesRow
@onready var _concept_lbl: Label          = $HUD/ConceptBar/ConceptLabel
@onready var _hint_lbl   : Label          = $HUD/HintBar/HintLabel
@onready var _peek_lbl   : Label          = $HUD/PeekLabel
@onready var _drag_ghost : Node2D         = $DragGhost

# ── Runtime state ─────────────────────────────────────────────────────────────
var _p           : Dictionary = {}
var _chapter_id  : int        = 1
var _tier        : int        = 0
var _pixel_font  : Font       = null
var _tex_cache   : Dictionary = {}
var _anim_tick   : float      = 0.0
var _anim_frame  : int        = 0
var _alive       : bool       = false

var _par_offsets : Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const PAR_SPEEDS : Array[float] = [4.0, 8.0, 12.0, 18.0, 28.0, 42.0]
var _par_tex     : Array        = []

# _cq        = the live queue (index 0 = FRONT)
# _holding   = tokens in the holding area
# _cq_slots  = Array[int or -1], size MAX_QUEUE — for free-place mode (Tier 0)
#              stores the uid of the token in each slot, or -1 if empty
var _cq          : Array = []
var _holding     : Array = []
var _cq_slots    : Array = []   # only used when _p["free_place"] == true

var _uid         : int   = 0
var _dyn_hold_gap: float = 120.0
var _score       : int   = 0
var _lives       : int   = 3
var _moves_left  : int   = 0
var _round       : int   = 0
var _correct     : int   = 0
var _wrong       : int   = 0

var _dragging    : bool       = false
var _drag_tok    : Dictionary = {}
var _drag_src    : String     = ""   # "holding_N", "queue_front", "queue_slot_N"
var _drag_origin : Vector2    = Vector2.ZERO
var _drag_pos    : Vector2    = Vector2.ZERO

# ── Portal AnimatedSprite2D (created in _build_world_chrome) ─────────────────
var _portal_sprite   : AnimatedSprite2D = null

# Walk-to-portal sequence (triggered on correct submit)
var _exit_walking    : bool      = false   # tokens are walking toward portal
var _exit_tokens     : Array     = []      # copies of sorted tokens walking out
var _exit_progress   : float     = 0.0    # 0.0 → 1.0 walk progress per token
var _exit_done_count : int       = 0      # how many have entered the portal
var _exit_callback   : Callable  = Callable()  # called when all tokens gone

var _intro_canvas : CanvasLayer = null
var _intro_slides : Array       = []
var _intro_idx    : int         = 0
var _intro_vis    : bool        = false

var _SLIDES       : Dictionary  = {}

# ── Inner class — diagram drawer ─────────────────────────────────────────────
class _DiagramDrawer extends Node2D:
	var draw_fn    : Callable
	var pixel_font : Font
	func _draw() -> void:
		if draw_fn.is_valid(): draw_fn.call(self, pixel_font)

# =============================================================================
#  READY
# =============================================================================
func _ready() -> void:
	if ResourceLoader.exists(PATH_FONT):
		_pixel_font = load(PATH_FONT) as Font
	else:
		_pixel_font = ThemeDB.fallback_font

	_preload_textures()

	# Portal sprite is created as AnimatedSprite2D in _build_world_chrome

	_chapter_id = 1
	if has_node("/root/GameRouter"):
		_chapter_id = clamp(GameRouter.current_chapter, 1, 5)
	_tier = _chapter_id - 1
	if has_node("/root/DifficultyManager"):
		_tier = clamp(DifficultyManager.current_tier, 0, 4)
	_p = TIER_PARAMS[_tier]

	_build_parallax()
	_build_slides()
	_setup_hud()
	_build_world_chrome()

	if has_node("/root/AudioManager") and AudioManager.has_method("play_bgm"):
		AudioManager.play_bgm(PATH_BGM)

	_alive = true
	_show_intro()

# =============================================================================
#  PARALLAX BACKGROUND
# =============================================================================
func _build_parallax() -> void:
	var paths : Array[String] = [
		PATH_BG_SKY, PATH_BG_MOUNT, PATH_BG_CASTLE,
		PATH_BG_FAR, PATH_BG_MID,   PATH_BG_FRONT,
	]
	var cl := CanvasLayer.new()
	cl.layer = -10; cl.name = "ParallaxLayer"
	add_child(cl)

	var sky_fill := ColorRect.new()
	sky_fill.color   = Color(0.56, 0.80, 0.82)
	sky_fill.size    = Vector2(SW, SH)
	sky_fill.z_index = -100
	cl.add_child(sky_fill)

	_par_tex.resize(paths.size())
	for i in range(paths.size()):
		_par_tex[i] = load(paths[i]) as Texture2D if ResourceLoader.exists(paths[i]) else null

	var drawer      := _ParallaxDrawer.new()
	drawer.name     = "ParallaxDrawer"
	drawer.gd       = self
	cl.add_child(drawer)

class _ParallaxDrawer extends Node2D:
	var gd : Node2D
	func _process(delta: float) -> void:
		if not is_instance_valid(gd): return
		for i in range(gd._par_offsets.size()):
			gd._par_offsets[i] += gd.PAR_SPEEDS[i] * delta
		queue_redraw()
	func _draw() -> void:
		if not is_instance_valid(gd): return
		for i in range(gd._par_tex.size()):
			var tex : Texture2D = gd._par_tex[i]
			if tex == null: continue
			var tex_w  : float = float(tex.get_width())
			var tex_h  : float = float(tex.get_height())
			var scale_y: float = gd.SH / tex_h
			var draw_w : float = tex_w * scale_y
			var off    : float = fmod(gd._par_offsets[i], draw_w)
			draw_texture_rect(tex, Rect2(Vector2(-off, 0),          Vector2(draw_w, gd.SH)), false)
			draw_texture_rect(tex, Rect2(Vector2(draw_w - off, 0),  Vector2(draw_w, gd.SH)), false)

# =============================================================================
#  TEXTURE HELPERS
# =============================================================================
func _preload_textures() -> void:
	for key in CHAR_KEYS:
		for anim in ["idle", "walk"]:
			for frame_sfx in ANIM_FRAMES:
				var fname     := "%s_%s%s.png" % [key, anim, frame_sfx]
				var path      := ANIM_PATH + fname
				var cache_key := "%s_%s%s" % [key, anim, frame_sfx]
				if ResourceLoader.exists(path):
					_tex_cache[cache_key] = load(path) as Texture2D

func _get_tex(char_key: String, anim_type: String, frame: int) -> Texture2D:
	var cache_key := "%s_%s%s" % [char_key, anim_type, ANIM_FRAMES[frame % 3]]
	return _tex_cache.get(cache_key, null)

func _char_key(val: int) -> String:
	return CHAR_KEYS[clamp(val - 1, 0, CHAR_KEYS.size() - 1)]

# =============================================================================
#  HUD SETUP
# =============================================================================
func _setup_hud() -> void:
	_score_lbl.text    = "Score: 0"
	_round_lbl.text    = "Round 1 / %d" % _p["rounds"]
	_moves_lbl.visible = _p["move_budget"] > 0
	_moves_lbl.text    = "Moves: %d" % _p["move_budget"]
	_acc_lbl.text      = "Acc: —"
	_peek_lbl.visible  = false
	_hint_lbl.text     = _hint_text()
	_concept_lbl.text  = "Sort ASCENDING:  smallest at FRONT [0]  →  largest at BACK  |  Place all tokens then SUBMIT"
	_refresh_lives()

func _hint_text() -> String:
	match _p["mode"]:
		"enqueue":
			return "Place tokens in ASCENDING ORDER: smallest at FRONT [0] → largest at BACK  |  Then SUBMIT"
		"dequeue":
			return "Queue is pre-filled in wrong order  |  Drag [0] → HOLDING to dequeue  |  Re-enqueue to fix"
		"peek":
			return "Click token to peek (FREE)  |  Then drag to sort"
		"bounds":
			return "Watch isEmpty / isFull  |  Drag 💣 → Reject Zone"
		"scheduler":
			return "Peek first (FREE)  |  Each drag = 1 move  |  Budget: %d" % _p["move_budget"]
	return ""

func _refresh_lives() -> void:
	for c in _lives_row.get_children(): c.queue_free()
	for i in range(3):
		var lbl := Label.new()
		lbl.text = "❤" if i < _lives else "🖤"
		lbl.add_theme_font_size_override("font_size", 24)
		_lives_row.add_child(lbl)

# =============================================================================
#  WORLD CHROME
# =============================================================================
func _build_world_chrome() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 5
	add_child(cl)
	var chrome        := _ChromeDrawer.new()
	chrome.name       = "Chrome"
	chrome.gd         = self
	chrome.pixel_font = _pixel_font
	cl.add_child(chrome)

	# ── Portal AnimatedSprite2D ──────────────────────────────────────────────
	# Use a dedicated CanvasLayer higher than chrome (layer 5) so the portal
	# always renders on top of the submit-zone glow ring.
	var portal_cl := CanvasLayer.new()
	portal_cl.layer = 8
	add_child(portal_cl)

	var portal := AnimatedSprite2D.new()
	portal.name     = "PortalSprite"
	portal.position = Vector2(SUB_X, SUB_Y)
	portal.z_index  = 10

	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_loop("idle", true)
	sprite_frames.set_animation_speed("idle", 10.0)

	# Try to load the portal sheet from several locations
	var portal_tex : Texture2D = null
	var portal_paths : Array[String] = [
		"res://assets/art/fx/Purple_Portal_Sprite_Sheet.png",
		"res://assets/art/Purple_Portal_Sprite_Sheet.png",
		"res://assets/Purple_Portal_Sprite_Sheet.png",
		"res://Purple_Portal_Sprite_Sheet.png",
		PATH_PORTAL,
	]
	for pp in portal_paths:
		if ResourceLoader.exists(pp):
			portal_tex = load(pp) as Texture2D
			break

	if portal_tex != null:
		# Sheet is 512×192: 8 cols × 3 rows, each frame 64×64
		# Row 0 (y=0) = main idle/open animation loop
		for frame_col in range(8):
			var atlas := AtlasTexture.new()
			atlas.atlas       = portal_tex
			atlas.region      = Rect2(frame_col * 64, 0, 64, 64)
			atlas.filter_clip = true
			sprite_frames.add_frame("idle", atlas)
		# Scale so 64px frame displays at ~192px (3× pixel art)
		portal.scale = Vector2(3.0, 3.0)
	else:
		# Fallback: single transparent placeholder; glow ring still shows
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.1, 0.8, 0.0))
		sprite_frames.add_frame("idle", ImageTexture.create_from_image(img))

	portal.sprite_frames = sprite_frames
	portal.animation     = "idle"
	# Additive blend: black pixels vanish, only the bright purple glow renders
	var portal_mat := CanvasItemMaterial.new()
	portal_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	portal.material = portal_mat
	portal.play()
	_portal_sprite = portal
	portal_cl.add_child(portal)

class _ChromeDrawer extends Node2D:
	var gd         : Node2D
	var pixel_font : Font

	func _process(_d: float) -> void: queue_redraw()

	func _draw() -> void:
		if not is_instance_valid(gd): return
		draw_rect(Rect2(Vector2.ZERO, Vector2(gd.SW, gd.SH)), Color(0.02, 0.01, 0.08, 0.62), true)
		_draw_lane()
		_draw_holding_area()
		_draw_submit_zone()
		_draw_tokens()
		_draw_drag_ghost_chrome()
		# Walk-to-portal exit sequence drawn on top
		if gd._exit_walking:
			gd._draw_exit_walk(self)

	func _get_font() -> Font:
		return pixel_font if pixel_font else ThemeDB.fallback_font

	func _draw_lane() -> void:
		var tx : float = gd.LANE_X0 - 6.0
		var ty : float = gd.LANE_Y_CEN - gd.SLOT_H * 0.5 - 6.0
		var tw : float = gd.MAX_QUEUE * gd.SLOT_W + 12.0
		var th : float = gd.SLOT_H + 12.0
		draw_rect(Rect2(Vector2(tx, ty), Vector2(tw, th)), gd.COL_PANEL, true)
		draw_rect(Rect2(Vector2(tx, ty), Vector2(tw, th)), gd.COL_BORDER, false, 2.0)

		for i in range(1, gd.MAX_QUEUE):
			var dx : float = gd.LANE_X0 + i * gd.SLOT_W
			draw_line(Vector2(dx, ty), Vector2(dx, ty + th), Color(0.3, 0.28, 0.48, 0.5), 1.0)

		var fnt := _get_font()

		# In free-place mode highlight empty slots so the player knows they can drop there
		if gd._p.get("free_place", false) and gd._cq_slots.size() == gd.MAX_QUEUE:
			for i in range(gd.MAX_QUEUE):
				if gd._cq_slots[i] == -1:
					var sx : float = gd.LANE_X0 + i * gd.SLOT_W
					draw_rect(Rect2(Vector2(sx, ty), Vector2(gd.SLOT_W, th)),
						Color(0.22, 0.80, 0.42, 0.08), true)

		for i in range(gd.MAX_QUEUE):
			var cx  : float = gd.LANE_X0 + i * gd.SLOT_W + gd.SLOT_W * 0.5
			var col : Color = gd.COL_GREEN if i == 0 else gd.COL_GRAY
			var lbl := "[%d]" % i
			var ts  := fnt.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
			draw_string(fnt, Vector2(cx - ts.x * 0.5, ty + th + 16),
				lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)

		# FRONT / BACK labels
		draw_string(fnt, Vector2(tx + 6, ty + th - 6),
			"◄ FRONT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gd.COL_GREEN)
		draw_string(fnt, Vector2(tx + tw - 68, ty + th - 6),
			"BACK ►", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, gd.COL_AMBER)

		var ttl := "QUEUE  LANE"
		var ts2 := fnt.get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(fnt, Vector2(tx + tw * 0.5 - ts2.x * 0.5, ty - 16),
			ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gd.COL_BLUE)

		# In normal mode highlight slot [0] as the only draggable position
		if not gd._p.get("free_place", false) and not gd._cq.is_empty():
			var fx : float = gd.LANE_X0
			var slot_col := Color(0.22, 0.80, 0.42, 0.12)
			draw_rect(Rect2(Vector2(fx, ty), Vector2(gd.SLOT_W, th)), slot_col, true)
			draw_rect(Rect2(Vector2(fx, ty), Vector2(gd.SLOT_W, th)),
				Color(0.22, 0.80, 0.42, 0.45), false, 2.0)

	func _draw_holding_area() -> void:
		# Holding panel sized to always contain sprites (72px wide + padding)
		var hw : float = 120.0
		var hx : float = gd.HOLD_X - hw * 0.5
		var hy : float = gd.HOLD_Y0 - 50.0
		var count : int = max(gd.MAX_HOLD, gd._holding.size())
		var hh : float = count * gd._dyn_hold_gap + 40.0
		draw_rect(Rect2(Vector2(hx, hy), Vector2(hw, hh)), gd.COL_PANEL, true)
		draw_rect(Rect2(Vector2(hx, hy), Vector2(hw, hh)), gd.COL_BORDER, false, 2.0)
		var fnt := _get_font()
		var ttl := "— HOLDING —"
		var ts  := fnt.get_string_size(ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(fnt, Vector2(gd.HOLD_X - ts.x * 0.5, hy - 20),
			ttl, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, gd.COL_AMBER)

	func _draw_submit_zone() -> void:
		var fnt := _get_font()
		var pos := Vector2(gd.SUB_X, gd.SUB_Y)
		# Pulsing glow ring drawn under the AnimatedSprite2D portal node
		var pulse : float = sin(Time.get_ticks_msec() * 0.004) * 0.5 + 0.5
		draw_circle(pos, 106.0, Color(0.40, 0.05, 0.70, 0.10 + pulse * 0.08))
		draw_arc(pos,   102.0, 0, TAU, 64,
			Color(0.75, 0.35, 1.0, 0.40 + pulse * 0.30), 4.0)
		# SUBMIT label below portal
		var lbl := "SUBMIT"
		var ts  := fnt.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(fnt, Vector2(pos.x - ts.x * 0.5, pos.y + 108.0),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, gd.COL_GREEN)

	# ── Token drawing ─────────────────────────────────────────────────────────
	func _draw_tokens() -> void:
		if gd._p.get("free_place", false) and gd._cq_slots.size() == gd.MAX_QUEUE:
			# Free-place mode: draw from _cq_slots (sparse array)
			for i in range(gd.MAX_QUEUE):
				var uid_in_slot : int = gd._cq_slots[i]
				if uid_in_slot == -1: continue
				var tok : Dictionary = gd._find_tok_by_uid(uid_in_slot)
				if tok.is_empty(): continue
				if gd._dragging and gd._drag_tok.get("uid", -1) == tok["uid"]: continue
				var qp : Vector2 = gd._queue_pos(i)
				_draw_token(tok, qp.x, qp.y, i == 0)
		else:
			# Normal queue mode
			for i in range(gd._cq.size()):
				var tok : Dictionary = gd._cq[i]
				if gd._dragging and gd._drag_tok.get("uid", -1) == tok["uid"]: continue
				var qp2 : Vector2 = gd._queue_pos(i)
				_draw_token(tok, qp2.x, qp2.y, i == 0)

		for i in range(gd._holding.size()):
			var tok : Dictionary = gd._holding[i]
			if gd._dragging and gd._drag_tok.get("uid", -1) == tok["uid"]: continue
			var hp : Vector2 = gd._holding_pos(i)
			_draw_token(tok, hp.x, hp.y, false)

	func _draw_token(tok: Dictionary, cx: float, cy: float, is_front: bool) -> void:
		# cx  = horizontal centre of slot
		# cy  = TOP of the container box (LANE_Y_CEN - SLOT_H/2 for queue,
		#        row_centre - block_half for holding)
		var val    : int   = tok["value"]
		var hidden : bool  = tok.get("hidden", false)
		var ss     : int   = gd.SPRITE_SCALE
		var sw     : float = gd.SPRITE_W * ss   # 72 px
		var sh     : float = gd.SPRITE_H * ss   # 72 px

		# Visually centre the sprite within the slot height
		var badge_h  : float = 20.0
		var gap      : float = 4.0
		var total_h  : float = badge_h + gap + sh   # 96 px block
		# Centre the whole block vertically within SLOT_H
		var pad      : float = (gd.SLOT_H - total_h) * 0.5
		# sprite_cy = vertical centre of the sprite
		var sprite_cy : float = cy + pad + badge_h + gap + sh * 0.5

		# ── sprite ───────────────────────────────────────────────────────────────
		if not hidden:
			var in_cq    : bool   = gd._cq.has(tok)
			var in_slots : bool   = gd._cq_slots.size() > 0 and gd._cq_slots.has(tok.get("uid", -2))
			var in_queue : bool   = in_cq or in_slots
			var anim_type : String = "walk" if in_queue else "idle"
			var char_key  : String = gd._char_key(val)
			var tex       : Texture2D = gd._get_tex(char_key, anim_type, gd._anim_frame)
			if tex != null:
				# Always draw with a positive Rect2 centred on (cx, sprite_cy)
				var half_w : float = sw * 0.5
				var half_h : float = sh * 0.5
				var draw_rect2 := Rect2(Vector2(cx - half_w, sprite_cy - half_h), Vector2(sw, sh))
				if in_queue:
					# Flip horizontally via transform so sprite faces left (walking toward front)
					draw_set_transform(Vector2(cx * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
					draw_texture_rect(tex, draw_rect2, false)
					draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
				else:
					draw_texture_rect(tex, draw_rect2, false)
			else:
				draw_circle(Vector2(cx, sprite_cy), gd.TOKEN_R, gd.TOKEN_COLS[val - 1])
				draw_arc(Vector2(cx, sprite_cy), gd.TOKEN_R, 0, TAU, 48,
					gd.TOKEN_COLS[val - 1].darkened(0.35), 2.0)
		else:
			draw_circle(Vector2(cx, sprite_cy), gd.TOKEN_R, gd.COL_GRAY)
			draw_arc(Vector2(cx, sprite_cy), gd.TOKEN_R, 0, TAU, 48,
				gd.COL_GRAY.darkened(0.35), 2.0)

		# ── value badge — above sprite, clear of the character head ─────────────
		var badge_w : float = 36.0
		# Badge top is cy + pad (top of the block), badge is badge_h tall
		var by2 : float = cy + pad
		var bx  : float = cx - badge_w * 0.5
		draw_rect(Rect2(Vector2(bx - 1, by2 - 1), Vector2(badge_w + 2, badge_h + 2)),
			Color(0, 0, 0, 0.92), true)
		draw_rect(Rect2(Vector2(bx, by2), Vector2(badge_w, badge_h)), gd.COL_DARK, true)
		var badge_col : Color = gd.COL_GOLD if not hidden else gd.COL_GRAY
		draw_rect(Rect2(Vector2(bx, by2), Vector2(badge_w, badge_h)), badge_col, false, 2.0)
		var txt := "?" if hidden else str(val)
		var fnt := _get_font()
		var ts  := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		draw_string(fnt, Vector2(cx - ts.x * 0.5, by2 + badge_h - 3.0),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, badge_col)

	func _draw_drag_ghost_chrome() -> void:
		if not gd._dragging or gd._drag_tok.is_empty(): return
		var tok    : Dictionary = gd._drag_tok
		var val    : int    = tok["value"]
		var hidden : bool   = tok.get("hidden", false)
		# pos = cursor position = sprite centre
		var pos    : Vector2 = gd._drag_pos
		var ss     : int    = gd.SPRITE_SCALE
		var hw     : float  = gd.SPRITE_W * ss * 0.5
		var hh     : float  = gd.SPRITE_H * ss * 0.5

		if not hidden:
			var char_key : String = gd._char_key(val)
			var tex : Texture2D = gd._get_tex(char_key, "idle", gd._anim_frame)
			if tex != null:
				# Perfectly centred on cursor using positive Rect2
				var draw_rect2 := Rect2(Vector2(pos.x - hw, pos.y - hh),
					Vector2(gd.SPRITE_W * ss, gd.SPRITE_H * ss))
				draw_texture_rect(tex, draw_rect2, false, Color(1, 1, 1, 0.85))
			else:
				var col : Color = gd.TOKEN_COLS[val - 1]
				draw_circle(pos, gd.TOKEN_R, Color(col.r, col.g, col.b, 0.72))
				draw_arc(pos, gd.TOKEN_R, 0, TAU, 48, col, 2.5)
		else:
			draw_circle(pos, gd.TOKEN_R, Color(0.38, 0.38, 0.48, 0.72))
			draw_arc(pos, gd.TOKEN_R, 0, TAU, 48, gd.COL_GRAY, 2.5)
			hh = gd.TOKEN_R

		# Badge above the ghost — clear of the sprite top
		var badge_w : float = 36.0; var badge_h : float = 20.0
		var bx  : float = pos.x - badge_w * 0.5
		var by2 : float = pos.y - hh - badge_h - 6.0
		draw_rect(Rect2(Vector2(bx - 1, by2 - 1), Vector2(badge_w + 2, badge_h + 2)),
			Color(0, 0, 0, 0.9), true)
		draw_rect(Rect2(Vector2(bx, by2), Vector2(badge_w, badge_h)), gd.COL_DARK, true)
		var badge_col : Color = gd.COL_GOLD if not hidden else gd.COL_GRAY
		draw_rect(Rect2(Vector2(bx, by2), Vector2(badge_w, badge_h)), badge_col, false, 2.0)
		var txt := "?" if hidden else str(val)
		var fnt := _get_font()
		var ts  := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15)
		draw_string(fnt, Vector2(pos.x - ts.x * 0.5, by2 + badge_h - 3.0),
			txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, badge_col)

# =============================================================================
#  INTRO OVERLAY
# =============================================================================
func _build_slides() -> void:
	_SLIDES = {
		"ENQUEUE": [
			{ "title": "What is a Queue?",
			  "body": "A Queue stores items in a line.\nFirst In = First Out  (FIFO).\nItems enter at the BACK and leave from the FRONT.",
			  "draw": Callable(self, "_slide_queue_intro") },
			{ "title": "enqueue( value )",
			  "body": "enqueue() adds a value to the queue.\n\nPlace tokens ANYWHERE in the lane — but they MUST be\nin ASCENDING ORDER (lowest number first).\nSmallest → FRONT [0]      Largest → BACK",
			  "draw": Callable(self, "_slide_enqueue") },
			{ "title": "Your Task — Sort Ascending!",
			  "body": "① Drag tokens from HOLDING into the queue slots\n② Place them in ORDER:  1 → 2 → 3 → 4  left to right\n   FRONT [0] must hold the SMALLEST value\n   BACK  [N] must hold the LARGEST value\n③ Once ALL tokens are placed IN THE RIGHT ORDER\n   drag to the SUBMIT portal on the left!\n\n⚠  Wrong order = points deducted. Plan before you drag!",
			  "draw": Callable(self, "_slide_task_enqueue") },
			{ "title": "The Submit Portal",
			  "body": "When ALL tokens are placed in ascending order:\n① The queue must have NO gaps — every slot filled\n② Drag the FRONT token [0] onto the Submit Portal\n③ The portal checks the whole queue automatically!\n\n✅ Sorted correctly  →  Score + next round!\n❌ Wrong order       →  Penalty + try again!",
			  "draw": Callable(self, "_slide_submit_portal") },
		],
		"DEQUEUE": [
			{ "title": "dequeue()",
			  "body": "dequeue() removes the item at the FRONT.\n\n  value = queue.pop_front()\n\nOnly the FRONT can be removed — not the middle!",
			  "draw": Callable(self, "_slide_dequeue") },
			{ "title": "The queue is already filled!",
			  "body": "This round the queue starts in WRONG order.\nYou cannot just sort while placing.\nYou must:\n  1. dequeue() wrong tokens from the FRONT\n  2. enqueue() them back in the correct order",
			  "draw": Callable(self, "_slide_sort_problem") },
			{ "title": "Your Task",
			  "body": "The queue starts filled in random order.\nDrag slot [0] → HOLDING  =  dequeue()\nDrag HOLDING  → queue     =  enqueue() (joins BACK)\nSort ascending, then drag [0] → SUBMIT.",
			  "draw": Callable(self, "_slide_task_dequeue") },
			{ "title": "Controls Quick Reference",
			  "body": "All the actions you can perform this chapter:\n\ndequeue()  — Drag slot [0] → Holding area\nenqueue()  — Drag Holding token → Queue lane\npeek()     — Click any token (always FREE)\nsubmit()   — Drag slot [0] → Submit Portal",
			  "draw": Callable(self, "_slide_controls_dequeue") },
		],
		"PEEK": [
			{ "title": "peek()  /  front()",
			  "body": "peek() reads the FRONT value WITHOUT removing it.\n\n  value = queue.front()\n\nThe queue is UNCHANGED after a peek.\nPeek is always FREE — no move cost!",
			  "draw": Callable(self, "_slide_peek") },
			{ "title": "Values are hidden!",
			  "body": "This round values start hidden.\nClick any token to peek and reveal its value.\nPlan your enqueue order BEFORE you drag.\nA smart peek saves moves later.",
			  "draw": Callable(self, "_slide_peek_strategy") },
			{ "title": "Your Task — Peek, Plan, Sort!",
			  "body": "① Click every token to reveal all values (FREE!)\n② Identify the smallest — that goes to FRONT [0]\n③ Drag tokens into the queue in ascending order\n④ Drag slot [0] → SUBMIT when done!\n\n💡 Tip: Peek ALL before moving anything!",
			  "draw": Callable(self, "_slide_task_peek") },
		],
		"BOUNDS": [
			{ "title": "isEmpty()  &  isFull()",
			  "body": "isEmpty() → true when queue has no items.\nCalling dequeue() on an empty queue = ERROR!\n\nisFull() → true when queue is at capacity.\nCalling enqueue() on a full queue = ERROR!",
			  "draw": Callable(self, "_slide_bounds") },
			{ "title": "Bomb tokens!",
			  "body": "💣 Bomb tokens must NEVER be enqueued.\nDrag bombs to the REJECT ZONE (bottom-left).\nIf a bomb enters the queue you lose a life!\nWatch isEmpty and isFull before every move.",
			  "draw": Callable(self, "_slide_bombs") },
			{ "title": "Your Task — Guard the Boundaries!",
			  "body": "① Check isEmpty() before every dequeue\n   → empty queue crash = life lost!\n② Check isFull() before every enqueue\n   → overflow crash = life lost!\n③ Spot the 💣 bomb — drag it to the REJECT ZONE\n④ Sort the rest ascending, then SUBMIT!",
			  "draw": Callable(self, "_slide_task_bounds") },
		],
		"SCHEDULER": [
			{ "title": "Move Budget",
			  "body": "You now have a LIMITED number of moves.\nEach enqueue = 1 move.  Each dequeue = 1 move.\nPeek is still FREE.\nRun out of moves before sorting = round fails!",
			  "draw": Callable(self, "_slide_scheduler") },
			{ "title": "Efficient Sorting",
			  "body": "Minimum moves to sort N items = N enqueues.\nEvery mistake costs +2 moves (dequeue + re-enqueue).\nStrategy:\n  1. Peek ALL tokens first (free!)\n  2. Plan the exact enqueue order\n  3. Execute without mistakes",
			  "draw": Callable(self, "_slide_efficient") },
			{ "title": "Your Task — Minimum Moves Wins!",
			  "body": "① Peek ALL hidden tokens first (always FREE — no limit!)\n② Mentally sort: plan your exact enqueue order\n③ Enqueue from lowest → highest — no wasted moves!\n④ Drag slot [0] → SUBMIT to score\n\n⚠  One wrong enqueue = +2 extra moves to fix it!\n   Budget runs out = round fails — plan carefully!",
			  "draw": Callable(self, "_slide_task_scheduler") },
		],
	}

func _style_button(btn: Button, primary: bool = true) -> void:
	if _pixel_font: btn.add_theme_font_override("font", _pixel_font)
	btn.add_theme_font_size_override("font_size", 15)
	var sbn := StyleBoxFlat.new()
	sbn.bg_color     = COL_FOREST_DK if primary else Color(0.12, 0.09, 0.04, 0.90)
	sbn.border_color = COL_GOLD if primary else COL_SCROLL_BD
	for side in ["left","right","top","bottom"]:
		sbn.set("border_width_" + side, 2)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		sbn.set("corner_radius_" + corner, 5)
	btn.add_theme_stylebox_override("normal", sbn)
	var sbh := sbn.duplicate() as StyleBoxFlat
	sbh.bg_color     = Color(0.18, 0.26, 0.10, 0.95) if primary else Color(0.20, 0.15, 0.06, 0.95)
	sbh.border_color = COL_GREEN if primary else COL_AMBER
	btn.add_theme_stylebox_override("hover", sbh)
	var sbp := sbn.duplicate() as StyleBoxFlat
	sbp.bg_color     = Color(0.10, 0.18, 0.06, 1.0) if primary else Color(0.14, 0.10, 0.03, 1.0)
	sbp.border_color = Color(1, 1, 1, 0.8)
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.add_theme_color_override("font_color",         COL_PARCH)
	btn.add_theme_color_override("font_hover_color",   COL_WHITE)
	btn.add_theme_color_override("font_pressed_color", COL_GOLD)

func _show_intro() -> void:
	var concept : String = _p["concept"]
	_intro_slides = _SLIDES.get(concept, [])
	if _intro_slides.is_empty(): _dismiss_intro(); return
	_intro_idx = 0; _intro_vis = true
	_intro_canvas = CanvasLayer.new()
	_intro_canvas.layer = 100
	add_child(_intro_canvas)

	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.06, 0.02, 0.96); bg.size = Vector2(SW, SH)
	_intro_canvas.add_child(bg)

	var tree_bar := ColorRect.new()
	tree_bar.color    = Color(0.06, 0.10, 0.04, 0.85)
	tree_bar.size     = Vector2(SW, 90); tree_bar.position = Vector2(0, SH - 90)
	_intro_canvas.add_child(tree_bar)

	var banner := ColorRect.new()
	banner.color = Color(0.16, 0.12, 0.05, 0.95)
	banner.size  = Vector2(SW, 48); banner.position = Vector2.ZERO
	_intro_canvas.add_child(banner)

	for yy in [48.0, SH - 90.0]:
		var rule := ColorRect.new()
		rule.color    = COL_SCROLL_BD
		rule.size     = Vector2(SW, 2); rule.position = Vector2(0, yy)
		_intro_canvas.add_child(rule)

	var scroll_x := 60.0; var scroll_y := 56.0
	var scroll_w := SW - 120.0; var scroll_h := SH - 56.0 - 100.0
	var scroll := Panel.new()
	scroll.position = Vector2(scroll_x, scroll_y); scroll.size = Vector2(scroll_w, scroll_h)
	var scroll_sty := StyleBoxFlat.new()
	scroll_sty.bg_color = Color(0.10, 0.08, 0.03, 0.92)
	scroll_sty.border_color = COL_SCROLL_BD
	for side in ["left","right","top","bottom"]: scroll_sty.set("border_width_" + side, 3)
	for corner in ["top_left","top_right","bottom_left","bottom_right"]:
		scroll_sty.set("corner_radius_" + corner, 8)
	scroll.add_theme_stylebox_override("panel", scroll_sty)
	_intro_canvas.add_child(scroll)

	for rv in [[scroll_x+14, scroll_y+14], [scroll_x+scroll_w-14, scroll_y+14],
			   [scroll_x+14, scroll_y+scroll_h-14], [scroll_x+scroll_w-14, scroll_y+scroll_h-14]]:
		var rivet := ColorRect.new()
		rivet.size     = Vector2(8, 8)
		rivet.position = Vector2(rv[0]-4, rv[1]-4); rivet.color = COL_GOLD
		_intro_canvas.add_child(rivet)

	var badge := Label.new(); badge.name = "Badge"
	if _pixel_font: badge.add_theme_font_override("font", _pixel_font)
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", COL_GOLD)
	badge.text = "⚔  Chapter %d  —  Queue Town  (Tier %d)  ⚔" % [_chapter_id, _tier]
	badge.position = Vector2(0, 10); badge.size = Vector2(SW, 28)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_canvas.add_child(badge)

	var ctr := Label.new(); ctr.name = "Counter"
	if _pixel_font: ctr.add_theme_font_override("font", _pixel_font)
	ctr.add_theme_font_size_override("font_size", 13)
	ctr.add_theme_color_override("font_color", Color(0.68, 0.60, 0.35))
	ctr.position = Vector2(SW-130, 12); ctr.size = Vector2(120, 24)
	ctr.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_intro_canvas.add_child(ctr)

	# Title — centred in a dedicated 54px strip at the very top of the scroll panel
	var ttl := Label.new(); ttl.name = "Title"
	if _pixel_font: ttl.add_theme_font_override("font", _pixel_font)
	ttl.add_theme_font_size_override("font_size", 22)
	ttl.add_theme_color_override("font_color", COL_GOLD)
	ttl.position = Vector2(scroll_x + 20, scroll_y + 8)
	ttl.size     = Vector2(scroll_w - 40, 48)
	ttl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ttl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	ttl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_canvas.add_child(ttl)

	# Thin gold line under title — fixed at scroll_y + 58
	var und := ColorRect.new(); und.name = "Underline"
	und.color    = COL_SCROLL_BD
	und.size     = Vector2(scroll_w - 80, 1)
	und.position = Vector2(scroll_x + 40, scroll_y + 58)
	_intro_canvas.add_child(und)

	# Diagram area occupies scroll_y+60 → body_top-6   (drawn via _DiagramDrawer)
	# Body text lives in a fixed 170px strip at the bottom of the scroll panel
	var body_top : float = scroll_y + scroll_h - 178.0
	var div := ColorRect.new(); div.name = "Divider"
	div.color    = Color(0.40, 0.30, 0.10, 0.60)
	div.size     = Vector2(scroll_w - 60, 1)
	div.position = Vector2(scroll_x + 30, body_top - 6)
	_intro_canvas.add_child(div)

	# Body text — fixed zone, font 13, autowrap, left-aligned with padding
	var body := Label.new(); body.name = "Body"
	if _pixel_font: body.add_theme_font_override("font", _pixel_font)
	body.add_theme_font_size_override("font_size", 13)
	body.add_theme_color_override("font_color", COL_PARCH_LT)
	body.position  = Vector2(scroll_x + 30, body_top)
	body.size      = Vector2(scroll_w - 60, 168.0)
	body.autowrap_mode         = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment  = HORIZONTAL_ALIGNMENT_LEFT
	body.vertical_alignment    = VERTICAL_ALIGNMENT_TOP
	_intro_canvas.add_child(body)

	var back := Button.new(); back.name = "Back"
	back.text = "◀  Back"; back.position = Vector2(80, SH-78); back.size = Vector2(180, 46)
	_style_button(back, false); back.pressed.connect(_intro_prev)
	_intro_canvas.add_child(back)

	var nxt := Button.new(); nxt.name = "Next"
	nxt.text = "Next  ▶"; nxt.position = Vector2(SW-260, SH-78); nxt.size = Vector2(180, 46)
	_style_button(nxt, true); nxt.pressed.connect(_intro_next)
	_intro_canvas.add_child(nxt)

	for i in range(_intro_slides.size()):
		var dot := ColorRect.new(); dot.name = "Dot%d" % i
		dot.size     = Vector2(10, 10)
		dot.position = Vector2(SW*0.5 - _intro_slides.size()*14.0*0.5 + i*20, SH-72)
		dot.color    = Color(0.28, 0.22, 0.08)
		_intro_canvas.add_child(dot)

	_refresh_intro()

func _refresh_intro() -> void:
	if not _intro_canvas: return
	var s     : Dictionary = _intro_slides[_intro_idx]
	var total : int        = _intro_slides.size()
	(_intro_canvas.get_node("Counter") as Label).text = "%d / %d" % [_intro_idx+1, total]
	(_intro_canvas.get_node("Title")   as Label).text = s["title"]
	(_intro_canvas.get_node("Body")    as Label).text = s["body"]
	var back_btn := _intro_canvas.get_node("Back") as Button
	back_btn.visible = _intro_idx > 0
	var nxt_btn := _intro_canvas.get_node("Next") as Button
	nxt_btn.text = "Begin Quest!  ▶" if _intro_idx == total-1 else "Next  ▶"
	_style_button(nxt_btn, true)
	for i in range(total):
		var dot := _intro_canvas.get_node("Dot%d" % i) as ColorRect
		dot.color = COL_GOLD if i == _intro_idx else Color(0.28, 0.22, 0.08)
		dot.size  = Vector2(12, 12) if i == _intro_idx else Vector2(8, 8)
	var old := _intro_canvas.get_node_or_null("Diagram")
	if old: old.name = "_dead"; old.free()
	var diag        := _DiagramDrawer.new(); diag.name = "Diagram"
	diag.pixel_font = _pixel_font
	# Offset so diagram draws inside the scroll panel, below the title (y≥60 → safe)
	# Diagram draw-functions use coordinates relative to this offset origin
	diag.position   = Vector2(0.0, 0.0)   # draw fns already use absolute slide coords
	if s.has("draw"): diag.draw_fn = s["draw"]
	_intro_canvas.add_child(diag)

func _intro_prev() -> void:
	_intro_idx = max(0, _intro_idx-1); _refresh_intro()

func _intro_next() -> void:
	if _intro_idx < _intro_slides.size()-1: _intro_idx += 1; _refresh_intro()
	else: _close_intro()

func _close_intro() -> void:
	var bg := _intro_canvas.get_child(0) as ColorRect
	_intro_canvas.create_tween()\
		.tween_property(bg, "color:a", 0.0, 0.28)\
		.finished.connect(func():
			_intro_canvas.queue_free(); _intro_canvas = null; _dismiss_intro())

func _dismiss_intro() -> void:
	_intro_vis = false; _start_round()

# =============================================================================
#  SLIDE DIAGRAM DRAW FUNCTIONS
# =============================================================================
func _get_draw_font() -> Font:
	return _pixel_font if _pixel_font else ThemeDB.fallback_font

func _tok_col(v: int) -> Color: return TOKEN_COLS[clamp(v-1, 0, 8)]

func _draw_token_at(ci: CanvasItem, cx: float, cy: float, val: int,
		hidden: bool = false, highlight: bool = false, r: float = 34.0) -> void:
	# cy = visual centre of the sprite. Badge drawn above with a clear gap.
	if not hidden:
		var tex : Texture2D = _get_tex(_char_key(val), "idle", _anim_frame)
		if tex != null:
			# Draw sprite centred on (cx, cy)
			ci.draw_texture_rect(tex, Rect2(Vector2(cx - r, cy - r), Vector2(r * 2.0, r * 2.0)), false)
		else:
			var col := _tok_col(val)
			ci.draw_circle(Vector2(cx, cy), r, col)
			ci.draw_arc(Vector2(cx, cy), r, 0, TAU, 48, col.darkened(0.35), 2.0)
	else:
		ci.draw_circle(Vector2(cx, cy), r, COL_GRAY)
		ci.draw_arc(Vector2(cx, cy), r, 0, TAU, 48, COL_GRAY.darkened(0.35), 2.0)
	if highlight: ci.draw_arc(Vector2(cx, cy), r + 4, 0, TAU, 48, COL_GREEN, 3.0)
	# Badge sits above the sprite top with a 4px gap
	var badge_w := 28.0; var badge_h := 16.0
	var bx  := cx - badge_w * 0.5
	var by2 := cy - r - 4.0 - badge_h   # above sprite top
	ci.draw_rect(Rect2(Vector2(bx, by2), Vector2(badge_w, badge_h)), COL_DARK, true)
	ci.draw_rect(Rect2(Vector2(bx, by2), Vector2(badge_w, badge_h)),
		COL_GOLD if not hidden else COL_GRAY, false, 1.5)
	var fnt := _get_draw_font()
	var txt := "?" if hidden else str(val)
	var ts  := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
	ci.draw_string(fnt, Vector2(cx - ts.x * 0.5, by2 + badge_h - 2.0),
		txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_GOLD if not hidden else COL_GRAY)

func _draw_queue_row(ci: CanvasItem, vals: Array, x0: float, cy: float,
		sw: float = 110.0, hidden: bool = false) -> void:
	# Centre the row horizontally if x0 == 0, otherwise use provided x0
	var n := vals.size()
	var total_w : float = n * sw + 8.0
	var actual_x0 : float = x0
	if x0 <= 0.0:
		actual_x0 = (SW - total_w) * 0.5 + 4.0
	var r : float = sw * 0.30   # slightly smaller so sprite fits inside slot
	var row_top  : float = cy - sw * 0.42
	var row_bot  : float = cy + sw * 0.42
	ci.draw_rect(Rect2(Vector2(actual_x0 - 4, row_top), Vector2(total_w, row_bot - row_top)),
		Color(0.08,0.07,0.02), true)
	ci.draw_rect(Rect2(Vector2(actual_x0 - 4, row_top), Vector2(total_w, row_bot - row_top)),
		COL_SCROLL_BD, false, 2.0)
	for i in range(1, n):
		ci.draw_line(Vector2(actual_x0 + i * sw, row_top),
			Vector2(actual_x0 + i * sw, row_bot),
			Color(0.35, 0.28, 0.10, 0.5), 1.0)
	var fnt := _get_draw_font()
	for i in range(n):
		var cx := actual_x0 + i * sw + sw * 0.5
		# Draw token — badge drawn ABOVE sprite by _draw_token_at, so sprite at cy
		_draw_token_at(ci, cx, cy, vals[i], hidden, i == 0, r)
		# Index label below the row border with a safe gap
		var lbl := "[%d]" % i
		var ts  := fnt.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11)
		ci.draw_string(fnt, Vector2(cx - ts.x * 0.5, row_bot + 16),
			lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, COL_GREEN if i == 0 else COL_GRAY)
	# FRONT / BACK labels at row vertical centre
	ci.draw_string(fnt, Vector2(actual_x0 - 78, cy + 6),
		"FRONT◄", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_GREEN)
	ci.draw_string(fnt, Vector2(actual_x0 + total_w + 4, cy + 6),
		"►BACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_AMBER)

func _dlc(ci: CanvasItem, cx: float, y: float, txt: String, col: Color, sz: int = 14) -> void:
	var fnt := _get_draw_font()
	var ts  := fnt.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, sz)
	ci.draw_string(fnt, Vector2(cx-ts.x*0.5, y), txt, HORIZONTAL_ALIGNMENT_LEFT,-1,sz,col)

func _dl(ci: CanvasItem, x: float, y: float, txt: String, col: Color, sz: int = 13) -> void:
	ci.draw_string(_get_draw_font(), Vector2(x, y), txt, HORIZONTAL_ALIGNMENT_LEFT,-1,sz,col)

func _darrow(ci: CanvasItem, x0: float, y: float, x1: float, col: Color = COL_GOLD) -> void:
	ci.draw_line(Vector2(x0, y), Vector2(x1, y), col, 2.5)
	var dx := 1 if x1 > x0 else -1
	ci.draw_polygon([Vector2(x1,y), Vector2(x1-dx*10,y-6), Vector2(x1-dx*10,y+6)], [col])

func _dbox(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float,
		fill: Color, outline: Color) -> void:
	ci.draw_rect(Rect2(Vector2(x0,y0), Vector2(x1-x0,y1-y0)), fill, true)
	ci.draw_rect(Rect2(Vector2(x0,y0), Vector2(x1-x0,y1-y0)), outline, false, 1.5)

func _slide_queue_intro(ci: CanvasItem, _font: Font) -> void:
	# Diagram area: y ≈ 112 → 430  (title label occupies y=64–112, never draw there)
	_dlc(ci, 640, 118, "WRONG  (unsorted)", COL_RED, 13)
	_draw_queue_row(ci, [3,1,4,2], 190, 196, 100)   # cy=196, row spans ~196±45
	_dlc(ci, 640, 258, "sort with  enqueue / dequeue", COL_GOLD, 13)
	_dlc(ci, 640, 276, "▼", COL_GOLD, 14)
	_dlc(ci, 640, 296, "CORRECT  (ascending)", COL_GREEN, 13)
	_draw_queue_row(ci, [1,2,3,4], 190, 378, 100)   # cy=378, row spans ~378±45

func _slide_enqueue(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "Free Placement — put tokens anywhere!", COL_GOLD, 18)
	_dlc(ci, 640, 140, "Drag each token into any empty queue slot", COL_PARCH, 13)
	# Show 4 empty slots with arrows pointing into them from holding
	var sw2 := 130.0; var x0 := 148.0; var cy := 280.0
	_dbox(ci, x0-4, cy-55, x0+4*sw2+4, cy+55, Color(0.08,0.07,0.02), COL_SCROLL_BD)
	for i in range(4):
		_dbox(ci, x0+i*sw2+6, cy-48, x0+(i+1)*sw2-6, cy+48,
			Color(0.12,0.10,0.03,0.5), COL_FOREST_BD)
		_dlc(ci, x0+i*sw2+sw2*0.5, cy+8, "[%d]" % i,
			COL_GREEN if i==0 else COL_GRAY, 12)
	_dlc(ci, 1080, cy-20, "HOLDING", COL_AMBER, 13)
	for i in range(4):
		_draw_token_at(ci, 1080, cy+40.0+i*30, i+3, false, false, 14)
	_darrow(ci, 1040, cy, x0+4*sw2+4, COL_AMBER)
	_dlc(ci, 640, 390, "Place lowest at [0], highest at the back, then SUBMIT", COL_PARCH, 13)

func _slide_task_enqueue(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "Place tokens in order — your way!", COL_GOLD, 22)
	var steps := [
		["Drag HOLDING → any slot","= place freely (no move cost)",COL_AMBER],
		["Drag token to SWAP",     "= drag an occupied slot to re-arrange", COL_BLUE],
		["Click SUBMIT",           "= checks if queue is sorted ascending",COL_GREEN],
	]
	for i in range(3):
		var ry := 160.0+i*90.0
		_dbox(ci, 60, ry, 1160, ry+80, Color(0.06,0.05,0.02), COL_SCROLL_BD)
		_dl(ci, 76, ry+16, steps[i][0], steps[i][2] as Color, 16)
		_dl(ci, 76, ry+40, steps[i][1], COL_PARCH, 13)

func _slide_dequeue(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "dequeue()  —  remove from the FRONT", COL_GOLD, 18)
	_dlc(ci, 500, 140, "BEFORE  (pre-filled, wrong order)", COL_RED, 13)
	_draw_queue_row(ci, [3,1,2], 0, 220, 110)
	_dl(ci, 215, 232, "WRONG FRONT!", COL_RED, 11)
	_dbox(ci, 8, 175, 92, 265, Color(0.14,0.03,0.03,0.8), COL_RED)
	_dlc(ci, 50, 195, "HOLD-", COL_RED, 10); _dlc(ci, 50, 210, "ING", COL_RED, 10)
	_draw_token_at(ci, 50, 245, 3, false, false, 18)
	ci.draw_line(Vector2(96,220),Vector2(58,220),COL_RED,2.5)
	ci.draw_polygon([Vector2(58,220),Vector2(68,214),Vector2(68,226)],[COL_RED])
	_dlc(ci, 500, 295, "AFTER  dequeue(3)  →  re-enqueue correctly", COL_GREEN, 13)
	_draw_queue_row(ci, [1,2,3], 0, 385, 110)
	_dl(ci, 215, 350, "1 is now FRONT", COL_GREEN, 11)
	_dbox(ci, 60, 420, 900, 448, Color(0.04,0.06,0.02), COL_FOREST_BD)
	_dlc(ci, 480, 432, "value = queue.pop_front()   # removes FRONT only", COL_PARCH, 13)

func _slide_sort_problem(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "Queue starts filled — you must dequeue to fix it", COL_RED, 15)
	var rows := [
		["①  Queue is ALREADY filled in wrong order","You cannot just enqueue sorted tokens", COL_RED],
		["②  dequeue() the wrong FRONT","Drag slot [0] back to holding area", COL_AMBER],
		["③  enqueue() in correct order","Drag lowest value first (joins the BACK)", COL_GREEN],
		["④  SUBMIT when sorted","Drag slot [0] onto the Submit Zone", COL_GREEN],
	]
	for i in range(4):
		var ry := 148.0+i*72.0
		_dbox(ci, 60, ry, 1160, ry+64, Color(0.06,0.05,0.02), COL_SCROLL_BD)
		_dl(ci, 76, ry+14, rows[i][0], rows[i][2] as Color, 16)
		_dl(ci, 76, ry+36, rows[i][1], COL_PARCH, 12)

func _slide_task_dequeue(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "Your Task — fix the pre-filled queue", COL_GOLD, 22)
	var ctrls := [
		["Drag slot [0] → HOLDING", "=  dequeue()   removes FRONT",COL_RED],
		["Drag HOLDING → queue",    "=  enqueue()   joins the BACK",COL_AMBER],
		["Click any token",         "=  peek()      FREE",COL_GOLD],
		["Drag slot [0] → SUBMIT",  "=  check sort!",COL_GREEN],
	]
	for i in range(4):
		var ry := 148.0+i*72.0
		_dbox(ci, 60, ry, 1160, ry+64, Color(0.06,0.05,0.02), COL_SCROLL_BD)
		_dl(ci, 76, ry+12, ctrls[i][0], ctrls[i][2] as Color, 15)
		_dl(ci, 76, ry+34, ctrls[i][1], COL_PARCH, 13)

func _slide_peek(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "peek()  /  front()  —  look without touching", COL_GOLD, 18)
	_dbox(ci, 30, 138, 580, 290, Color(0.08,0.06,0.02,0.6), COL_AMBER)
	_dlc(ci, 305, 155, "BEFORE peek", COL_AMBER, 13)
	for i in range(4): _draw_token_at(ci, 70.0+i*120.0, 240, i+1, true, false, 36)
	ci.draw_line(Vector2(600,138),Vector2(600,430),Color(0.35,0.30,0.10,0.4),1.5)
	_dbox(ci, 615, 138, 1190, 290, Color(0.04,0.08,0.03,0.6), COL_GREEN)
	_dlc(ci, 902, 155, "AFTER click — revealed!", COL_GREEN, 13)
	for i in range(4):
		_draw_token_at(ci, 645.0+i*135.0, 240, i+1, i != 1, i == 1, 36)
	_dlc(ci, 780, 282, "value = 2  (FREE!)", COL_GOLD, 11)
	_dbox(ci, 60, 304, 1160, 336, Color(0.10,0.08,0.02,0.9), COL_GOLD)
	_dlc(ci, 610, 317, "peek()  →  front() = value 2     Queue UNCHANGED", COL_GOLD, 14)

func _slide_peek_strategy(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "Strategy — Peek First, Then Sort", COL_GOLD, 18)
	var steps2 := [
		["Step 1","Click ALL tokens (peek is FREE — always do this first!)","",COL_GOLD],
		["Step 2","Find the lowest value — enqueue it FIRST","(plan before you drag anything)",COL_AMBER],
		["Step 3","Enqueue in ascending order  1 → 2 → 3…","(each enqueue costs 1 move)",COL_GREEN],
		["Step 4","Drag slot [0] → Submit Zone to score","(correct sort = full points!)",COL_GREEN],
	]
	for i in range(4):
		var ry := 148.0+i*72.0
		_dbox(ci, 60, ry, 1160, ry+64, Color(0.06,0.05,0.02), COL_SCROLL_BD)
		_dl(ci, 76, ry+8,  steps2[i][0], steps2[i][3] as Color, 15)
		_dl(ci, 160, ry+8, steps2[i][1], COL_WHITE, 15)
		_dl(ci, 76, ry+32, steps2[i][2], COL_GRAY, 12)

func _slide_bounds(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "isEmpty()  &  isFull()", COL_GOLD, 20)
	_dbox(ci, 30, 145, 590, 305, Color(0.03,0.08,0.03,0.7), COL_GREEN)
	_dlc(ci, 310, 162, "Queue with items  →  isEmpty() = false", COL_GREEN, 13)
	_draw_queue_row(ci, [2,4,6], 0, 245, 100)
	_dbox(ci, 620, 145, 1190, 305, Color(0.10,0.03,0.03,0.7), COL_RED)
	_dlc(ci, 905, 162, "Queue EMPTY  →  isEmpty() = true", COL_RED, 13)
	for i in range(3):
		ci.draw_circle(Vector2(660.0+i*110, 245), 42, Color(0.10,0.08,0.02))
		ci.draw_arc(Vector2(660.0+i*110, 245), 42, 0, TAU, 48, COL_GRAY, 2.0)
		ci.draw_string(_get_draw_font(), Vector2(660.0+i*110-8,252),
			"—", HORIZONTAL_ALIGNMENT_LEFT,-1,20,COL_GRAY)
	_dbox(ci, 30, 322, 1190, 392, Color(0.06,0.05,0.02), COL_SCROLL_BD)
	_dlc(ci, 610, 349, "Always check isEmpty() before dequeue()", COL_GOLD, 14)

func _slide_bombs(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "💣 Bomb Tokens — NEVER Enqueue!", COL_RED, 18)
	var bx := 320.0; var by := 250.0
	ci.draw_circle(Vector2(bx,by), 52, Color(0.40,0.08,0.08))
	ci.draw_arc(Vector2(bx,by), 52, 0, TAU, 48, COL_RED, 3.0)
	ci.draw_string(_get_draw_font(), Vector2(bx-16,by+10), "💣",
		HORIZONTAL_ALIGNMENT_LEFT,-1,36,COL_WHITE)
	_dlc(ci, bx, by+68, "BOMB", COL_RED, 14)
	_darrow(ci, bx+56, by, 740, COL_RED)
	_dbox(ci, 740, by-40, 980, by+40, Color(0.12,0.03,0.03,0.9), COL_RED)
	_dlc(ci, 860, by-18, "REJECT ZONE", COL_RED, 16)
	_dlc(ci, 860, by+6,  "Drag bomb here!", COL_PARCH, 13)

func _slide_scheduler(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "Move Budget — Plan Every Move!", COL_GOLD, 18)
	_dbox(ci, 30, 138, 1190, 235, Color(0.08,0.06,0.02,0.6), COL_AMBER)
	_dlc(ci, 610, 152, "HOLDING — values hidden", COL_AMBER, 13)
	for i in range(5): _draw_token_at(ci, 80.0+i*220, 197, i+1, true, false, 32)
	var costs := [
		["enqueue()","Drag holding → queue","1 move",COL_AMBER],
		["dequeue()","Drag [0] → holding",  "1 move",COL_RED],
		["peek()",   "Click to reveal",      "FREE",  COL_GOLD],
		["submit()", "Drag [0] → Submit",    "0 moves",COL_GREEN],
	]
	for i in range(4):
		var ry := 248.0+i*36.0
		_dbox(ci, 30, ry, 1190, ry+32, Color(0.06,0.05,0.02), COL_SCROLL_BD)
		_dl(ci, 46, ry+10, costs[i][0], costs[i][3] as Color, 13)
		_dl(ci, 200, ry+10, costs[i][1], COL_PARCH, 13)
		_dl(ci, 860, ry+10, costs[i][2], costs[i][3] as Color, 13)

func _slide_efficient(ci: CanvasItem, _font: Font) -> void:
	_dlc(ci, 640, 112, "Efficient Sorting — Minimum Moves", COL_GOLD, 18)
	_dbox(ci, 30, 145, 590, 380, Color(0.03,0.08,0.03), COL_GREEN)
	_dlc(ci, 310, 162, "Perfect Play", COL_GREEN, 16)
	var pg := [["Peek  × 5","FREE — 0 moves",COL_GOLD],
		["Enqueue × 5","1 move each = 5 total",COL_GREEN],
		["Total: 5 moves","Budget left: 7",COL_GREEN]]
	for i in range(3):
		_dl(ci, 48, 200.0+i*52, pg[i][0], pg[i][2] as Color, 15)
		_dl(ci, 48, 220.0+i*52, pg[i][1], COL_PARCH, 12)
	_dbox(ci, 620, 145, 1190, 380, Color(0.10,0.03,0.03), COL_RED)
	_dlc(ci, 905, 162, "One Mistake", COL_RED, 16)
	var mg := [["Peek  × 5","FREE",COL_GOLD],["Enqueue × 5","wrong order",COL_AMBER],
		["Dequeue × 1","+1 move",COL_RED],["Re-Enqueue × 1","+1 more move",COL_RED],
		["Total: 7 moves","Budget shrinks fast!",COL_RED]]
	for i in range(5):
		_dl(ci, 636, 185.0+i*38, mg[i][0], mg[i][2] as Color, 14)
		_dl(ci, 636, 201.0+i*38, mg[i][1], COL_PARCH, 11)

# ── NEW slides added for each chapter ─────────────────────────────────────────

func _slide_submit_portal(ci: CanvasItem, _font: Font) -> void:
	# ENQUEUE slide 4: explains how the portal / submit mechanic works
	_dlc(ci, 640, 112, "The Submit Portal — check your sort!", COL_GOLD, 18)
	# Sorted queue diagram
	_draw_queue_row(ci, [1,2,3,4], 230, 230, 110)
	# Portal circle on the left
	var px := 96.0; var py := 230.0
	ci.draw_circle(Vector2(px, py), 50, Color(0.30, 0.05, 0.55, 0.75))
	ci.draw_arc(Vector2(px, py), 50, 0, TAU, 64, Color(0.75, 0.35, 1.0, 0.85), 3.5)
	ci.draw_arc(Vector2(px, py), 56, 0, TAU, 64, Color(0.55, 0.10, 0.80, 0.30), 8.0)
	_dlc(ci, px, py + 68, "SUBMIT", COL_GREEN, 14)
	# Arrow from queue [0] toward portal
	_darrow(ci, 230, py, px + 56, COL_GREEN)
	_dlc(ci, 163, py - 28, "Drag [0] →", COL_GREEN, 12)
	# Divider
	ci.draw_line(Vector2(60, 308), Vector2(1200, 308), Color(0.40, 0.30, 0.10, 0.50), 1.5)
	# Result boxes
	_dlc(ci, 640, 326, "What happens next?", COL_PARCH, 13)
	_dbox(ci, 60, 345, 590, 415, Color(0.03, 0.08, 0.02, 0.85), COL_GREEN)
	_dlc(ci, 325, 362, "✅  Sorted correctly", COL_GREEN, 15)
	_dl(ci, 76, 386, "Score + next round begins!", COL_PARCH, 13)
	_dbox(ci, 620, 345, 1200, 415, Color(0.10, 0.03, 0.02, 0.85), COL_RED)
	_dlc(ci, 910, 362, "❌  Wrong order", COL_RED, 15)
	_dl(ci, 636, 386, "Penalty deducted — rearrange and retry!", COL_PARCH, 13)

func _slide_controls_dequeue(ci: CanvasItem, _font: Font) -> void:
	# DEQUEUE slide 4: quick-reference card for all controls
	_dlc(ci, 640, 112, "Controls Quick Reference", COL_GOLD, 20)
	var rows := [
		["dequeue()", "Drag slot [0]  →  Holding area",    "removes FRONT token",    COL_RED],
		["enqueue()", "Drag Holding   →  Queue lane",       "joins the BACK",         COL_AMBER],
		["peek()",    "Click any token",                    "reveals value  (FREE!)", COL_GOLD],
		["submit()",  "Drag slot [0]  →  Submit Portal",   "checks ascending order", COL_GREEN],
	]
	for i in range(4):
		var ry := 155.0 + i * 70.0
		_dbox(ci, 60, ry, 1200, ry + 62, Color(0.06, 0.05, 0.02), COL_SCROLL_BD)
		_dl(ci, 76,  ry + 10, rows[i][0], rows[i][3] as Color, 15)
		_dl(ci, 220, ry + 10, rows[i][1], COL_WHITE, 14)
		_dl(ci, 76,  ry + 34, rows[i][2], COL_GRAY,  12)

func _slide_task_peek(ci: CanvasItem, _font: Font) -> void:
	# PEEK slide 3: "Your Task" — structured step list
	_dlc(ci, 640, 112, "Your Task — Peek, Plan, then Sort!", COL_GOLD, 22)
	var steps := [
		["① Click every token",         "= peek()   reveals hidden value  (FREE — no limit!)", COL_GOLD],
		["② Find the lowest value",     "= that token goes to FRONT [0] of the queue",         COL_AMBER],
		["③ Drag in ascending order",   "= enqueue() lowest → highest left to right",          COL_GREEN],
		["④ Drag slot [0] → SUBMIT",   "= portal checks sort and awards score!",               COL_GREEN],
	]
	for i in range(4):
		var ry := 150.0 + i * 70.0
		_dbox(ci, 60, ry, 1200, ry + 62, Color(0.06, 0.05, 0.02), COL_SCROLL_BD)
		_dl(ci, 76, ry + 10, steps[i][0], steps[i][2] as Color, 15)
		_dl(ci, 76, ry + 34, steps[i][1], COL_PARCH, 13)
	# Hidden token row hint
	_dlc(ci, 640, 445, "Remember: values start hidden — peek FIRST!", COL_AMBER, 13)

func _slide_task_bounds(ci: CanvasItem, _font: Font) -> void:
	# BOUNDS slide 3: "Your Task" summary
	_dlc(ci, 640, 112, "Your Task — Guard the Boundaries!", COL_GOLD, 22)
	var steps := [
		["① Spot the 💣 bomb",            "= drag it to the REJECT ZONE (bottom-left!) immediately",  COL_RED],
		["② Check isEmpty()",             "= never dequeue if the queue is empty — crash!",           COL_RED],
		["③ Check isFull()",              "= never enqueue when the queue is full — crash!",          COL_AMBER],
		["④ Sort ascending → SUBMIT",    "= all non-bomb tokens placed lowest→highest",              COL_GREEN],
	]
	for i in range(4):
		var ry := 150.0 + i * 70.0
		_dbox(ci, 60, ry, 1200, ry + 62, Color(0.06, 0.05, 0.02), COL_SCROLL_BD)
		_dl(ci, 76, ry + 10, steps[i][0], steps[i][2] as Color, 15)
		_dl(ci, 76, ry + 34, steps[i][1], COL_PARCH, 13)
	# Reject zone reminder
	_dbox(ci, 60, 432, 560, 430, Color(0.14, 0.03, 0.03, 0.85), COL_RED)
	_dlc(ci, 310, 430, "REJECT ZONE  (bottom-left)", COL_RED, 13)

func _slide_task_scheduler(ci: CanvasItem, _font: Font) -> void:
	# SCHEDULER slide 3: "Your Task" final summary
	_dlc(ci, 640, 112, "Your Task — Minimum Moves Wins!", COL_GOLD, 22)
	var steps := [
		["① Peek ALL tokens",           "= click each one — FREE, no move cost — do this first!", COL_GOLD],
		["② Plan your exact order",     "= decide the full enqueue sequence before touching anything", COL_AMBER],
		["③ Enqueue lowest → highest", "= each drag = 1 move — no mistakes allowed!",             COL_GREEN],
		["④ Drag slot [0] → SUBMIT",   "= correct sort = score + budget saved = bonus points!",   COL_GREEN],
	]
	for i in range(4):
		var ry := 150.0 + i * 70.0
		_dbox(ci, 60, ry, 1200, ry + 62, Color(0.06, 0.05, 0.02), COL_SCROLL_BD)
		_dl(ci, 76, ry + 10, steps[i][0], steps[i][2] as Color, 15)
		_dl(ci, 76, ry + 34, steps[i][1], COL_PARCH, 13)
	# Budget warning
	_dbox(ci, 60, 432, 1200, 462, Color(0.12, 0.06, 0.02, 0.85), COL_AMBER)
	_dlc(ci, 630, 445, "⚠  One wrong enqueue = +2 extra moves to correct it!", COL_AMBER, 13)

# =============================================================================
#  ROUND MANAGEMENT
# =============================================================================
func _start_round() -> void:
	_round += 1
	_cq = []; _holding = []
	_moves_left = _p["move_budget"] if _p["move_budget"] > 0 else 9999
	_round_lbl.text = "Round %d / %d" % [_round, _p["rounds"]]
	_refresh_moves_label()

	for ch in _world.get_children():
		if ch.name != "Chrome": ch.queue_free()

	var count : int   = _p["citizens"]
	var vals  : Array = range(1, count + 1)
	vals.shuffle()

	if _p.get("prefill", false):
		# ── DEQUEUE mode: pre-fill the queue in shuffled (wrong) order ────────
		# Keep shuffling until the order is guaranteed unsorted
		while _is_array_sorted(vals):
			vals.shuffle()

		_cq_slots = []   # not used in normal queue mode
		for i in range(count):
			_uid += 1
			_cq.append({
				"uid":    _uid,
				"value":  vals[i] as int,
				"hidden": _p["hidden"],
				"bomb":   false,
			})
		# holding stays empty — nothing to enqueue from; player dequeues first

	elif _p.get("free_place", false):
		# ── ENQUEUE mode: sparse slot array, tokens come from holding ─────────
		_cq_slots = []
		_cq_slots.resize(MAX_QUEUE)
		_cq_slots.fill(-1)

		var avail_h : float = SH - HOLD_Y0 - 80.0
		var dyn_gap : float = min(HOLD_GAP, avail_h / max(count-1, 1)) if count > 1 else HOLD_GAP
		_dyn_hold_gap = dyn_gap

		for i in range(count):
			_uid += 1
			_holding.append({
				"uid":    _uid,
				"value":  vals[i] as int,
				"hidden": _p["hidden"],
				"bomb":   false,
			})

	else:
		# ── Normal mode (peek / bounds / scheduler): tokens in holding ────────
		var avail_h : float = SH - HOLD_Y0 - 80.0
		var dyn_gap : float = min(HOLD_GAP, avail_h / max(count-1, 1)) if count > 1 else HOLD_GAP
		_dyn_hold_gap = dyn_gap
		_cq_slots = []

		for i in range(count):
			_uid += 1
			var is_bomb : bool = _p["bombs"] and i == count-1 and randf() < 0.5
			_holding.append({
				"uid":    _uid,
				"value":  vals[i] as int,
				"hidden": _p["hidden"],
				"bomb":   is_bomb,
			})

func _is_array_sorted(arr: Array) -> bool:
	for i in range(1, arr.size()):
		if arr[i] < arr[i-1]: return false
	return true

func _next_round_or_end() -> void:
	if _round >= _p["rounds"]: _end_game(true)
	else:
		await get_tree().create_timer(1.2).timeout
		_start_round()

func _refresh_moves_label() -> void:
	if not _moves_lbl.visible: return
	_moves_lbl.text = "Moves: %d" % max(0, _moves_left)
	_moves_lbl.add_theme_color_override("font_color",
		COL_RED if _moves_left <= 3 else COL_GOLD)

# =============================================================================
#  PROCESS
# =============================================================================
func _process(delta: float) -> void:
	if _intro_vis or not _alive: return
	_tick_peek_banner()

	# Character walk animation
	_anim_tick += delta
	if _anim_tick >= 0.25:
		_anim_tick  = 0.0
		_anim_frame = (_anim_frame + 1) % 3

	# Portal AnimatedSprite2D plays automatically via its own timer

	# Walk-to-portal exit sequence
	if _exit_walking:
		_tick_exit_walk(delta)

func _tick_peek_banner() -> void:
	if _p.get("free_place", false):
		# In free-place mode show the front slot's value if occupied
		if _cq_slots.size() > 0 and _cq_slots[0] != -1:
			var tok := _find_tok_by_uid(_cq_slots[0])
			_peek_lbl.visible = not tok.is_empty()
			if not tok.is_empty():
				_peek_lbl.text = "peek()  →  front() = %d" % tok["value"] \
					if not tok.get("hidden", false) \
					else "peek()  →  front() = ?"
		else:
			_peek_lbl.visible = false
		return

	if _cq.is_empty():
		_peek_lbl.visible = false; return
	_peek_lbl.visible = true
	var front : Dictionary = _cq[0]
	_peek_lbl.text = "peek()  →  front() = ?" if front["hidden"] \
		else "peek()  →  front() = %d" % front["value"]

# =============================================================================
#  WALK-TO-PORTAL EXIT SEQUENCE
# =============================================================================
# Each token walks from its queue position toward the portal (SUB_X, SUB_Y).
# Tokens depart one at a time, staggered by 0.3 s so they don't pile up.
# When a token reaches the portal it "disappears" (shrinks to 0).
# Once all tokens have vanished, _exit_callback is fired (→ next round / end).

const EXIT_WALK_SPEED  : float = 380.0  # px per second
const EXIT_STAGGER     : float = 0.28   # seconds between each token departing

var _exit_tok_progress : Array = []   # float per token: distance walked
var _exit_tok_started  : Array = []   # bool per token: has this one begun?
var _exit_time         : float = 0.0  # elapsed since exit sequence began

func _start_exit_walk(tokens_in_order: Array, callback: Callable) -> void:
	_exit_walking    = true
	_exit_tokens     = tokens_in_order.duplicate()
	_exit_time       = 0.0
	_exit_done_count = 0
	_exit_callback   = callback
	_exit_tok_progress = []
	_exit_tok_started  = []
	for i in range(_exit_tokens.size()):
		_exit_tok_progress.append(0.0)
		_exit_tok_started.append(false)

	# Clear the queue visually — tokens will be drawn by _draw_exit_walk instead
	_cq.clear()
	if _cq_slots.size() > 0:
		_cq_slots.fill(-1)

func _tick_exit_walk(delta: float) -> void:
	_exit_time += delta
	var portal_pos := Vector2(SUB_X, SUB_Y)

	for i in range(_exit_tokens.size()):
		# Stagger: token i starts after i * EXIT_STAGGER seconds
		if _exit_time < i * EXIT_STAGGER:
			continue
		_exit_tok_started[i] = true

		# Calculate start position of this token in the sorted queue
		var start_x : float = LANE_X0 + i * SLOT_W + SLOT_W * 0.5
		var start_pos := Vector2(start_x, LANE_Y_CEN)
		var total_dist : float = start_pos.distance_to(portal_pos)
		if total_dist < 1.0: total_dist = 1.0

		_exit_tok_progress[i] = min(
			_exit_tok_progress[i] + EXIT_WALK_SPEED * delta, total_dist)

		if _exit_tok_progress[i] >= total_dist and _exit_tok_started[i]:
			# Token reached portal — count it once
			if _exit_tok_progress[i] < total_dist + EXIT_WALK_SPEED * delta * 0.5:
				pass  # will count below on first frame it completes
			_exit_tok_progress[i] = total_dist  # clamp

	# Count how many are fully done this frame
	var done : int = 0
	for i in range(_exit_tokens.size()):
		var start_x : float = LANE_X0 + i * SLOT_W + SLOT_W * 0.5
		var start_pos := Vector2(start_x, LANE_Y_CEN)
		var total_dist : float = start_pos.distance_to(Vector2(SUB_X, SUB_Y))
		if total_dist < 1.0: total_dist = 1.0
		if _exit_tok_started[i] and _exit_tok_progress[i] >= total_dist:
			done += 1

	if done == _exit_tokens.size():
		_exit_walking = false
		if _exit_callback.is_valid():
			_exit_callback.call()

func _draw_exit_walk(draw_node: Node2D) -> void:
	if not _exit_walking: return
	var portal_pos := Vector2(SUB_X, SUB_Y)
	for i in range(_exit_tokens.size()):
		if not _exit_tok_started[i]: continue
		var tok : Dictionary = _exit_tokens[i]
		var val : int = tok["value"]

		var start_x : float = LANE_X0 + i * SLOT_W + SLOT_W * 0.5
		var start_pos := Vector2(start_x, LANE_Y_CEN)
		var total_dist : float = start_pos.distance_to(portal_pos)
		if total_dist < 1.0: total_dist = 1.0

		var t : float = _exit_tok_progress[i] / total_dist
		var cur_pos : Vector2 = start_pos.lerp(portal_pos, t)

		# Shrink to 0 as they enter the portal (last 25% of walk)
		var scale_f : float = 1.0
		if t > 0.75:
			scale_f = 1.0 - ((t - 0.75) / 0.25)
		scale_f = max(scale_f, 0.0)
		if scale_f <= 0.01: continue

		var ss     : int   = SPRITE_SCALE
		var hw     : float = SPRITE_W * ss * 0.5 * scale_f
		var hh     : float = SPRITE_H * ss * 0.5 * scale_f
		var char_key : String = _char_key(val)
		var tex : Texture2D = _get_tex(char_key, "walk", _anim_frame)
		if tex != null:
			# Walk left toward portal — sprite centre = cur_pos, flipped via transform
			draw_node.draw_set_transform(Vector2(cur_pos.x * 2.0, 0.0), 0.0, Vector2(-1.0, 1.0))
			draw_node.draw_texture_rect(tex,
				Rect2(Vector2(cur_pos.x - hw, cur_pos.y - hh), Vector2(hw * 2.0, hh * 2.0)),
				false, Color(1, 1, 1, scale_f))
			draw_node.draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.0))
		else:
			draw_node.draw_circle(cur_pos, TOKEN_R * scale_f,
				Color(TOKEN_COLS[val-1].r, TOKEN_COLS[val-1].g,
					TOKEN_COLS[val-1].b, scale_f))

# =============================================================================
#  INPUT
# =============================================================================
func _input(event: InputEvent) -> void:
	if _intro_vis or not _alive: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _handle_press(event.position)
		else:             _handle_release(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_drag_pos = event.position

func _handle_press(pos: Vector2) -> void:
	# Peek hidden tokens on click
	for c in _holding + _cq:
		if c["hidden"] and _hit(c, pos):
			_do_peek(c); return

	# Dragging from holding
	for i in range(_holding.size()):
		var c : Dictionary = _holding[i]
		# Hit test against sprite visual centre, not container top
		if _hit_pos(c, _holding_sprite_pos(i), pos):
			_start_drag(c, "holding_%d" % i, _holding_sprite_pos(i)); return

	if _p.get("free_place", false):
		# In free-place mode: can drag any token already placed in any slot
		for i in range(MAX_QUEUE):
			if _cq_slots[i] == -1: continue
			var tok : Dictionary = _find_tok_by_uid(_cq_slots[i])
			if tok.is_empty(): continue
			if _hit_pos(tok, _queue_sprite_pos(i), pos):
				_start_drag(tok, "queue_slot_%d" % i, _queue_sprite_pos(i)); return
	else:
		# Normal mode: only front [0] is draggable
		if not _cq.is_empty():
			var front : Dictionary = _cq[0]
			if _hit_pos(front, _queue_sprite_pos(0), pos):
				_start_drag(front, "queue_front", _queue_sprite_pos(0))

func _hit(c: Dictionary, pos: Vector2) -> bool:
	return pos.distance_to(_citizen_pos(c)) < _hit_radius()

func _hit_pos(_c: Dictionary, world_pos: Vector2, click: Vector2) -> bool:
	return click.distance_to(world_pos) < _hit_radius()

func _hit_radius() -> float:
	# Full sprite half-size — accurate since we now test against sprite centre
	return float(SPRITE_W * SPRITE_SCALE) * 0.5 if not _tex_cache.is_empty() else TOKEN_R

func _citizen_pos(c: Dictionary) -> Vector2:
	if _p.get("free_place", false):
		for i in range(_cq_slots.size()):
			if _cq_slots[i] == c.get("uid", -1): return _queue_sprite_pos(i)
	else:
		var qi := _cq.find(c)
		if qi >= 0: return _queue_sprite_pos(qi)
	var hi := _holding.find(c)
	if hi >= 0: return _holding_sprite_pos(hi)
	return Vector2.ZERO

func _queue_pos(i: int) -> Vector2:
	# Returns (slot_centre_x, slot_top_y) — slot_top used by _draw_token
	return Vector2(roundi(LANE_X0 + i * SLOT_W + SLOT_W * 0.5),
		roundi(LANE_Y_CEN - SLOT_H * 0.5))

func _queue_sprite_pos(i: int) -> Vector2:
	# Returns the visual centre of the sprite in slot i — used for hit testing
	var slot_top  : float = LANE_Y_CEN - SLOT_H * 0.5
	var badge_h   : float = 20.0
	var gap       : float = 4.0
	var sh        : float = float(SPRITE_H * SPRITE_SCALE)
	var block_h   : float = badge_h + gap + sh
	var pad       : float = (SLOT_H - block_h) * 0.5
	var sprite_cy : float = slot_top + pad + badge_h + gap + sh * 0.5
	return Vector2(roundi(LANE_X0 + i * SLOT_W + SLOT_W * 0.5), roundi(sprite_cy))

func _holding_sprite_pos(i: int) -> Vector2:
	# Returns the visual centre of the sprite in holding row i — used for hit testing
	var badge_h   : float = 20.0
	var gap       : float = 4.0
	var sh        : float = float(SPRITE_H * SPRITE_SCALE)
	var block_h   : float = badge_h + gap + sh
	var block_half: float = block_h * 0.5
	var row_centre: float = HOLD_Y0 + i * _dyn_hold_gap
	# _holding_pos returns container top = row_centre - block_half
	# sprite_cy = container_top + pad + badge_h + gap + sh*0.5
	var container_top : float = row_centre - block_half
	var pad : float = (SLOT_H - block_h) * 0.5  # same padding logic
	var sprite_cy : float = container_top + pad + badge_h + gap + sh * 0.5
	return Vector2(roundi(HOLD_X), roundi(sprite_cy))

func _holding_pos(i: int) -> Vector2:
	# Return the ROW CENTRE. _draw_token treats cy as container top,
	# so offset by half the total (badge+sprite) block height to keep centred.
	var block_half : float = (20.0 + 4.0 + float(SPRITE_H * SPRITE_SCALE)) * 0.5
	var row_centre : float = HOLD_Y0 + i * _dyn_hold_gap
	return Vector2(roundi(HOLD_X), roundi(row_centre - block_half))

func _start_drag(c: Dictionary, src: String, origin: Vector2) -> void:
	_dragging = true; _drag_tok = c; _drag_src = src
	_drag_origin = origin; _drag_pos = origin

# Helper: find a token dict by uid across cq + holding
func _find_tok_by_uid(uid: int) -> Dictionary:
	for t in _cq:
		if t["uid"] == uid: return t
	for t in _holding:
		if t["uid"] == uid: return t
	return {}

# =============================================================================
#  RELEASE / DROP
# =============================================================================
func _handle_release(pos: Vector2) -> void:
	if not _dragging: return
	_dragging = false

	if _p.get("free_place", false):
		_handle_release_free_place(pos)
	else:
		_handle_release_normal(pos)

	_drag_tok = {}; _drag_src = ""

# ── Free-place mode (Tier 0 ENQUEUE) ─────────────────────────────────────────
func _handle_release_free_place(pos: Vector2) -> void:
	var tok : Dictionary = _drag_tok

	# Submit — drag anywhere near the submit zone
	if pos.distance_to(Vector2(SUB_X, SUB_Y)) < DROP_R * 1.3:
		_action_submit_free_place(); return

	# Find the nearest queue slot
	var best_slot := -1
	var best_dist := DROP_R * 1.5
	for i in range(MAX_QUEUE):
		var d := pos.distance_to(_queue_pos(i))
		if d < best_dist:
			best_dist = d; best_slot = i

	if best_slot == -1:
		# Dropped outside — if it came from a queue slot, put it back to holding
		if _drag_src.begins_with("queue_slot_"):
			var src_slot := int(_drag_src.split("_")[2])
			_cq_slots[src_slot] = -1
			_holding.append(tok)
			_cq.erase(tok)
		return   # no-op drop, token returns visually (it was never removed from state)

	# Slot is occupied by a different token — swap with holding or swap two slots
	if _cq_slots[best_slot] != -1 and _cq_slots[best_slot] != tok["uid"]:
		var other_uid : int = _cq_slots[best_slot]
		var other_tok := _find_tok_by_uid(other_uid)

		if _drag_src.begins_with("holding_"):
			# FIFO rule: a token from HOLDING can only enter at the BACK (highest occupied slot + 1)
			# Swapping into an already-occupied slot from holding is not allowed —
			# the player must rearrange placed tokens using slot-to-slot swaps.
			_concept("Queue is FIFO!\nYou can't insert in front of %d.\nRearrange placed tokens by dragging slot → slot." % other_tok.get("value", "?"))
			_sfx(false)
			return

		elif _drag_src.begins_with("queue_slot_"):
			# Swap two in-queue tokens — always allowed
			var src_slot := int(_drag_src.split("_")[2])
			_cq_slots[src_slot]  = other_uid
			_cq_slots[best_slot] = tok["uid"]
			_concept("Swapped [%d]=%d  ↔  [%d]=%d" % [
				src_slot, tok["value"], best_slot, other_tok["value"]])
			_sfx(true)
		return

	# Slot is empty — place the token
	if _drag_src.begins_with("holding_"):
		_holding.erase(tok)
		_cq.append(tok)
		_cq_slots[best_slot] = tok["uid"]
		_concept("Placed %d into slot [%d]." % [tok["value"], best_slot])
		_sfx(true)

	elif _drag_src.begins_with("queue_slot_"):
		var src_slot := int(_drag_src.split("_")[2])
		if src_slot != best_slot:
			_cq_slots[src_slot]  = -1
			_cq_slots[best_slot] = tok["uid"]
			_concept("Moved %d from [%d] → [%d]." % [tok["value"], src_slot, best_slot])
			_sfx(true)

func _action_submit_free_place() -> void:
	# Build a sorted array from _cq_slots to verify order
	var ordered : Array = []
	for i in range(MAX_QUEUE):
		if _cq_slots[i] == -1: continue
		var tok := _find_tok_by_uid(_cq_slots[i])
		if not tok.is_empty(): ordered.append({"slot": i, "value": tok["value"]})

	if ordered.is_empty():
		_apply_wrong(0, "Queue is empty — place tokens first!"); return

	# Check ascending AND that there are no gaps between filled slots
	# (slots don't need to be at [0]..[n-1] — as long as relative order is correct)
	for i in range(1, ordered.size()):
		if ordered[i]["value"] < ordered[i-1]["value"]:
			_apply_wrong(10,
				"Not sorted! Value %d at slot [%d] should come after %d.\nRearrange and try again." % [
				ordered[i]["value"], ordered[i]["slot"], ordered[i-1]["value"]]); return

	# Also ensure all citizens are placed (holding must be empty)
	if not _holding.is_empty():
		_apply_wrong(0, "Place ALL tokens in the queue first!\n%d still in holding." % _holding.size())
		return

	var pts := 100 + ordered.size() * 20
	_score += pts; _score_lbl.text = "Score: %d" % _score
	_correct += 1; _acc_lbl.text = "Acc: %.0f%%" % _accuracy()
	var vals_str := " → ".join(ordered.map(func(e): return str(e["value"])))
	_concept("✅ Sorted correctly!\n[%s]\n+%d pts" % [vals_str, pts])
	_sfx(true)
	# Build token list in slot order for walk animation
	var walk_tokens : Array = []
	for entry in ordered:
		walk_tokens.append(_find_tok_by_uid(_cq_slots[entry["slot"]]))
	_start_exit_walk(walk_tokens, _next_round_or_end)

# ── Normal mode (Tiers 1–4) ───────────────────────────────────────────────────
func _handle_release_normal(pos: Vector2) -> void:
	var handled := false

	if _drag_src.begins_with("holding"):
		# FIFO: enqueue always goes to BACK — just check drop is inside lane area
		var lane_left  : float = LANE_X0 - DROP_R
		var lane_right : float = LANE_X0 + MAX_QUEUE * SLOT_W + DROP_R
		var lane_top   : float = LANE_Y_CEN - SLOT_H * 0.5 - DROP_R
		var lane_bot   : float = LANE_Y_CEN + SLOT_H * 0.5 + DROP_R
		if pos.x > lane_left and pos.x < lane_right and pos.y > lane_top and pos.y < lane_bot:
			_action_enqueue(_drag_tok); handled = true
		if not handled and _p["bombs"]:
			if pos.distance_to(Vector2(90, 620)) < DROP_R:
				_action_reject(_drag_tok); handled = true

	elif _drag_src == "queue_front":
		if pos.distance_to(Vector2(SUB_X, SUB_Y)) < DROP_R * 1.3:
			_action_submit(); handled = true
		# Dequeue: drag front token to the right (holding area) or anywhere right of lane
		elif pos.x > LANE_X0 + MAX_QUEUE * SLOT_W:
			_action_dequeue(); handled = true

# =============================================================================
#  QUEUE OPERATIONS
# =============================================================================
func _do_peek(c: Dictionary) -> void:
	c["hidden"] = false
	_concept("peek()  →  value = %d\nQueue UNCHANGED — peek is FREE!" % c["value"])
	_sfx(true)

func _action_enqueue(c: Dictionary) -> void:
	if c.get("bomb", false):
		_apply_wrong(0, "💣 BOMB! Never enqueue a bomb!\nDrag it to the Reject Zone.")
		_holding.erase(c); return

	if _cq.size() >= MAX_QUEUE:
		_apply_wrong(0,
			"isFull() → true\nQueue is full (%d/%d)!\nDequeue first." % [_cq.size(), MAX_QUEUE])
		return

	if _p["move_budget"] > 0:
		_moves_left -= 1; _refresh_moves_label()
		if _moves_left < 0:
			_apply_wrong(0, "Out of moves!\nRound failed."); _lose_life(); return

	_holding.erase(c); c["hidden"] = false
	_cq.append(c)
	_apply_correct(5)
	_concept("enqueue(%d)\n→ queue.push_back()\nSize: %d / %d\nQueue: [%s]" % [
		c["value"], _cq.size(), MAX_QUEUE, _queue_str()])

func _action_dequeue() -> void:
	if _cq.is_empty():
		_apply_wrong(0, "isEmpty() → true\nNothing to dequeue!"); return

	if _p["move_budget"] > 0:
		_moves_left -= 1; _refresh_moves_label()
		if _moves_left < 0:
			_apply_wrong(0, "Out of moves!\nRound failed."); _lose_life(); return

	var front : Dictionary = _cq.pop_front()
	_holding.append(front)
	_apply_correct(2)
	_concept("dequeue()\n→ queue.pop_front()\nReturned: %d  (back to holding)\nQueue: [%s]" % [
		front["value"], _queue_str()])

func _action_reject(c: Dictionary) -> void:
	_holding.erase(c)
	if c.get("bomb", false):
		_apply_correct(30)
		_concept("💣 BOMB rejected!\nCorrect — never enqueue a bomb.\n+30 pts")
	else:
		_apply_wrong(5, "Rejected %d — only reject bombs!" % c["value"])

func _action_submit() -> void:
	if _cq.is_empty():
		_apply_wrong(0, "Queue is empty — enqueue first!"); return
	if _is_sorted():
		var pts := 100 + _cq.size() * 20
		_score += pts; _score_lbl.text = "Score: %d" % _score
		_correct += 1; _acc_lbl.text = "Acc: %.0f%%" % _accuracy()
		_concept("✅ Sorted correctly!\n[%s]\n+%d pts" % [_queue_str(), pts])
		_sfx(true)
		# Walk sorted tokens into the portal before advancing
		var walk_tokens : Array = _cq.duplicate()
		_start_exit_walk(walk_tokens, _next_round_or_end)
	else:
		var brk := _sort_break()
		_apply_wrong(10,
			"Not sorted!\nValue %d at [%d] should come after %d.\nDequeue and fix the order." % [
			_cq[brk]["value"], brk, _cq[brk-1]["value"]])

func _is_sorted() -> bool:
	for i in range(1, _cq.size()):
		if _cq[i]["value"] < _cq[i-1]["value"]: return false
	return true

func _sort_break() -> int:
	for i in range(1, _cq.size()):
		if _cq[i]["value"] < _cq[i-1]["value"]: return i
	return 0

func _queue_str() -> String:
	if _cq.is_empty(): return "empty"
	var parts : Array = []
	for c in _cq: parts.append(str(c["value"]))
	return " → ".join(parts)

# =============================================================================
#  FEEDBACK
# =============================================================================
func _apply_correct(pts: int) -> void:
	_score += pts; _score_lbl.text = "Score: %d" % _score
	_correct += 1; _acc_lbl.text = "Acc: %.0f%%" % _accuracy()
	_sfx(true)

func _apply_wrong(penalty: int, msg: String) -> void:
	if penalty > 0: _score = max(0, _score - penalty); _score_lbl.text = "Score: %d" % _score
	_wrong += 1; _acc_lbl.text = "Acc: %.0f%%" % _accuracy()
	if not msg.is_empty(): _concept(msg)
	_sfx(false)

func _lose_life() -> void:
	_lives -= 1; _refresh_lives()
	if _lives <= 0: _end_game(false)

func _concept(txt: String) -> void:
	if _concept_lbl: _concept_lbl.text = txt

func _sfx(ok: bool) -> void:
	var p := PATH_SFX_OK if ok else PATH_SFX_FAIL
	if has_node("/root/AudioManager") and AudioManager.has_method("play_sfx"):
		AudioManager.play_sfx(p)

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
	_concept(("✅ Complete!\nGrade: %s   Score: %d   Acc: %.0f%%" if win
		else "💀 Game Over\nGrade: %s   Score: %d") % [grade, _score, _accuracy()])

	var stars := _grade_to_stars(grade)
	var end_stats := {
		"score":    _score,
		"stars":    stars,
		"grade":    grade,
		"accuracy": _accuracy(),
		"correct":  _correct,
		"success":  win,
	}

	if has_node("/root/GameRouter"):
		GameRouter.chapter_complete_with_stats(_chapter_id, end_stats)
	elif has_node("/root/PlayerProfile"):
		PlayerProfile.save_chapter_result(_chapter_id, _score, stars, _accuracy())
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://scenes/world_map/WorldMap.tscn")

func _calc_grade(win: bool) -> String:
	var a := _accuracy()
	if not win: return "C" if a >= 60 else "F"
	if a >= 95: return "S"
	if a >= 82: return "A"
	if a >= 68: return "B"
	return "C"

func _grade_to_stars(g: String) -> int:
	match g:
		"S","A": return 3
		"B":     return 2
		"C":     return 1
	return 0
