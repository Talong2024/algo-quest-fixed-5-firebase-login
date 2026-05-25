# =============================================================================
# AlgoQuest — World Map  (Sprite Node Edition)
# File: scripts/world_map/WorldMap.gd
# =============================================================================

extends Node2D

const PATH_FONT  := "res://assets/fonts/freepixel.ttf"
# Tier labels — tier 0 = Beginner, tier 4 = Expert (5 tiers total, no Master)
const TIER_LABELS: Array[String] = ["Beginner", "Easy", "Normal", "Hard", "Expert"]

const CHAPTERS: Array = [
	{ "id":1,  "name":"Kingdom Gate",     "dsa":"Queue — FIFO",
	  "pos":Vector2(170, 460),  "color":Color("#6BCB77"),
	  "sprite":"res://assets/map/node_castle.png",      "icon":"🏰", "tiers":5 },
	{ "id":6,  "name":"Castle of Echoes", "dsa":"Stack — LIFO",
	  "pos":Vector2(400, 270),  "color":Color("#C77DFF"),
	  "sprite":"res://assets/map/node_tower.png",       "icon":"🗼", "tiers":5 },
	{ "id":11, "name":"Chain Station",    "dsa":"Linked List",
	  "pos":Vector2(640, 460),  "color":Color("#FFD93D"),
	  "sprite":"res://assets/map/node_station.png",     "icon":"🚂", "tiers":5 },
	{ "id":16, "name":"Oracle's Forest",  "dsa":"BST / AVL Tree",
	  "pos":Vector2(880, 270),  "color":Color("#88CC77"),
	  "sprite":"res://assets/map/node_forest.png",      "icon":"🌲", "tiers":5 },
	{ "id":21, "name":"Kingdom Roads",    "dsa":"Graph Algorithms",
	  "pos":Vector2(1110, 460), "color":Color("#4D96FF"),
	  "sprite":"res://assets/map/node_crossroads.png",  "icon":"🗺",  "tiers":5 },
]

const ROADS: Array = [[0,1],[0,2],[1,2],[1,3],[2,4],[3,4]]

# ── Node refs ─────────────────────────────────────────────────────────────────
@onready var _avatar:       Node2D          = $PlayerAvatar
@onready var _anim:         AnimationPlayer = $AnimationPlayer
@onready var _tooltip_bg:   Control         = $HUD/TooltipBG
@onready var _tooltip_lbl:  Label           = $HUD/TooltipBG/TooltipLbl
@onready var _chapter_root: Node2D          = $ChapterNodes

# ── State ─────────────────────────────────────────────────────────────────────
var _pixel_font:    Font       = null
var _map_data:      Dictionary = {}
var _hover_id:      int        = -1
var _avatar_pos:    Vector2    = Vector2(170, 460)
var _is_teacher:    bool       = false
var _stars:         Array      = []
var _sprite_nodes:  Dictionary = {}

var _badge_ring:    ColorRect  = null
var _badge_circle:  ColorRect  = null
var _badge_label:   Label      = null

var _panel_layer:       CanvasLayer    = null
var _panel_dim:         ColorRect      = null
var _panel_root:        PanelContainer = null
var _panel_vbox:        VBoxContainer  = null
var _tier_nodes:        Array          = []
var _selected_chapter:  Dictionary     = {}

# ── Theme state ───────────────────────────────────────────────────────────────
# light_mode is stored in PlayerProfile so it persists across sessions.
var _light_mode: bool = false

# ── Teacher Dashboard state ───────────────────────────────────────────────────
var _dash_layer:        CanvasLayer = null
var _dash_visible:      bool        = false
var _dash_students:     Array       = []
var _dash_active_tab:   int         = 0
var _dash_content_root: Control     = null
var _dash_tab_btns:     Array       = []

# ── Student Profile (in-game overlay, students only) ─────────────────────────
var _profile_layer:   CanvasLayer = null
var _profile_visible: bool        = false

# ── Settings overlay ──────────────────────────────────────────────────────────
var _settings_layer:   CanvasLayer = null
var _settings_visible: bool        = false
var _hud_bg_rect:      ColorRect   = null  # stored so we can recolour on theme change
var _hud_accent_rect:  ColorRect   = null

# ── Student detail modal (inside teacher dashboard) ───────────────────────────
var _student_detail_layer:   CanvasLayer = null
var _student_detail_visible: bool        = false

# ── Dashboard colour palette (dark-mode base — inverted for light mode) ───────
const DC_BG2     := Color("#0e1018")
const DC_BG3     := Color("#151824")
const DC_BORDER  := Color("#1e2235")
const DC_BORDER2 := Color("#2a3050")
const DC_TEXT    := Color("#e8e6f0")
const DC_TEXT2   := Color("#8a8aaa")
const DC_TEXT3   := Color("#4a4a6a")
const DC_GOLD    := Color("#ffd93d")
const DC_BLUE    := Color("#4d96ff")
const DC_PURPLE  := Color("#c77dff")
const DC_GREEN   := Color("#6bcb77")
const DC_RED     := Color("#ff6b6b")
const DC_ORANGE  := Color("#ff9f43")

# Light-mode equivalents
const LC_BG2     := Color("#f0f2f8")
const LC_BG3     := Color("#e4e8f5")
const LC_BORDER  := Color("#c8cedf")
const LC_BORDER2 := Color("#b0b8d4")
const LC_TEXT    := Color("#1a1c2e")
const LC_TEXT2   := Color("#4a4f6a")
const LC_TEXT3   := Color("#9098b8")
const LC_GOLD    := Color("#b07800")
const LC_BLUE    := Color("#1a5fd4")
const LC_PURPLE  := Color("#7c3aed")
const LC_GREEN   := Color("#16a34a")
const LC_RED     := Color("#dc2626")
const LC_ORANGE  := Color("#c2610a")

const CH_DATA: Array = [
	{ "id":1,  "name":"Kingdom Gate",     "dsa":"Queue — FIFO",      "icon":"🏰", "col":Color("#6BCB77") },
	{ "id":6,  "name":"Castle of Echoes", "dsa":"Stack — LIFO",      "icon":"🗼", "col":Color("#C77DFF") },
	{ "id":11, "name":"Chain Station",    "dsa":"Linked List",        "icon":"🚂", "col":Color("#FFD93D") },
	{ "id":16, "name":"Oracle's Forest",  "dsa":"BST / AVL Tree",    "icon":"🌲", "col":Color("#88CC77") },
	{ "id":21, "name":"Kingdom Roads",    "dsa":"Graph Algorithms",   "icon":"🗺",  "col":Color("#4D96FF") },
]

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font if ResourceLoader.exists(PATH_FONT) else null

	# Always make sure the node is visible — if the enter animation fails for
	# any reason we don't want to be stuck with modulate.a = 0 (blank screen).
	modulate = Color(1, 1, 1, 1)

	if has_node("/root/PlayerProfile"):
		if PlayerProfile.is_loaded():
			# Profile already available (returning from a chapter) — build immediately.
			_load_profile_data()
			_build_world()
		else:
			# Profile is still fetching from Firestore (just logged in).
			# Show a loading indicator and wait for the signal.
			_show_loading_screen()
			if not PlayerProfile.profile_loaded.is_connected(_on_profile_ready):
				PlayerProfile.profile_loaded.connect(_on_profile_ready, CONNECT_ONE_SHOT)
	else:
		# No PlayerProfile autoload (editor preview / guest) — build with empty data.
		_build_world()

func _load_profile_data() -> void:
	_map_data   = PlayerProfile.progress
	_is_teacher = PlayerProfile.is_teacher()
	if "light_mode" in PlayerProfile:
		_light_mode = PlayerProfile.light_mode as bool

	# Restore avatar to the chapter node the player last launched from.
	# GameRouter.current_chapter is set by go_to_chapter() and persists
	# across scene changes, so returning from a chapter puts us back at
	# the correct node instead of always defaulting to Kingdom Gate.
	if has_node("/root/GameRouter") and GameRouter.current_chapter > 0:
		var last_ch: int = GameRouter.current_chapter
		# Find which chapter family this belongs to (family start id)
		for ch: Dictionary in CHAPTERS:
			var fam_start: int = ch["id"] as int
			var fam_end:   int = fam_start + (ch.get("tiers",1) as int) - 1
			if last_ch >= fam_start and last_ch <= fam_end:
				_avatar_pos = ch["pos"] as Vector2
				break

func _on_profile_ready() -> void:
	# Called once when Firestore fetch completes after login.
	_hide_loading_screen()
	_load_profile_data()
	_build_world()

# ── Loading screen shown while Firestore profile is fetching ──────────────────
var _loading_layer: CanvasLayer = null

func _show_loading_screen() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 200
	add_child(_loading_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.12, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_layer.add_child(bg)

	var lbl := Label.new()
	lbl.text = "ALGOQUEST"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color("#4D96FF"))
	_loading_layer.add_child(lbl)

	var sub := Label.new()
	sub.text = "Loading your adventure…"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.offset_top = 52
	if _pixel_font: sub.add_theme_font_override("font", _pixel_font)
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", Color("#4a4a7a"))
	_loading_layer.add_child(sub)

func _hide_loading_screen() -> void:
	if is_instance_valid(_loading_layer):
		_loading_layer.queue_free()
		_loading_layer = null

# ── Full world build — called once profile data is ready ──────────────────────
func _build_world() -> void:
	_generate_stars()
	_build_sprite_nodes()
	_build_player_badge()
	_build_hud()
	_build_region_areas()
	_build_info_panel()
	_build_settings_overlay()

	if _is_teacher:
		_build_teacher_dashboard()
		_build_student_detail_modal()
	else:
		_build_student_profile()

	_play_enter_animation()
	queue_redraw()

# =============================================================================
#  THEME HELPERS
# =============================================================================
func _t(dark_val: Color, light_val: Color) -> Color:
	return light_val if _light_mode else dark_val

func _apply_theme_to_panel(pc: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = _t(DC_BG2, LC_BG2)
	sb.set_border_width_all(1)
	sb.border_color = _t(DC_BORDER, LC_BORDER)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	pc.add_theme_stylebox_override("panel", sb)

func _theme_bg2()    -> Color: return _t(DC_BG2,    LC_BG2)
func _theme_bg3()    -> Color: return _t(DC_BG3,    LC_BG3)
func _theme_border() -> Color: return _t(DC_BORDER, LC_BORDER)
func _theme_text()   -> Color: return _t(DC_TEXT,   LC_TEXT)
func _theme_text2()  -> Color: return _t(DC_TEXT2,  LC_TEXT2)
func _theme_text3()  -> Color: return _t(DC_TEXT3,  LC_TEXT3)
func _theme_gold()   -> Color: return _t(DC_GOLD,   LC_GOLD)
func _theme_blue()   -> Color: return _t(DC_BLUE,   LC_BLUE)
func _theme_purple() -> Color: return _t(DC_PURPLE, LC_PURPLE)
func _theme_green()  -> Color: return _t(DC_GREEN,  LC_GREEN)
func _theme_red()    -> Color: return _t(DC_RED,    LC_RED)
func _theme_orange() -> Color: return _t(DC_ORANGE, LC_ORANGE)

# ── Apply theme to every overlay that's built ─────────────────────────────────
func _rebuild_all_for_theme() -> void:
	# Re-tint HUD background
	if is_instance_valid(_hud_bg_rect):
		_hud_bg_rect.color = Color(0.95, 0.95, 0.97, 0.96) if _light_mode else Color(0, 0, 0, 0.84)
	if is_instance_valid(_hud_accent_rect):
		_hud_accent_rect.color = _theme_gold() if _is_teacher else _theme_blue()

	# Re-draw map (stars, roads, node overlays)
	queue_redraw()

	# Rebuild overlays that are currently visible so their colours update
	if _dash_visible:
		_dash_switch_tab(_dash_active_tab)
	if _profile_visible:
		_open_student_profile()
	if _settings_visible:
		_open_settings_overlay()

# =============================================================================
#  SPRITE NODES
# =============================================================================
func _build_sprite_nodes() -> void:
	for child in _chapter_root.get_children(): child.queue_free()
	_sprite_nodes.clear()
	for ch: Dictionary in CHAPTERS:
		var cid:  int     = ch["id"]     as int
		var pos:  Vector2 = ch["pos"]    as Vector2
		var col:  Color   = ch["color"]  as Color
		var path: String  = ch["sprite"] as String
		var texture: Texture2D = null
		if ResourceLoader.exists(path): texture = load(path) as Texture2D
		if texture == null: _sprite_nodes[cid] = null; continue
		var sprite := Sprite2D.new()
		sprite.texture = texture; sprite.position = pos; sprite.z_index = 3
		const TARGET_PX := 72.0
		var img_w: float   = float(texture.get_width())
		var img_h: float   = float(texture.get_height())
		var scale_f: float = TARGET_PX / max(img_w, img_h)
		sprite.scale = Vector2(scale_f, scale_f)
		sprite.modulate = _sprite_tint(cid, col)
		_chapter_root.add_child(sprite); _sprite_nodes[cid] = sprite

func _sprite_tint(cid: int, col: Color) -> Color:
	if not (_is_unlocked(cid) or _is_teacher): return Color(0.18, 0.18, 0.14, 0.75)
	return Color.WHITE.lerp(col, 0.25)

# =============================================================================
#  STAR FIELD
# =============================================================================
func _generate_stars() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 42
	for _i in range(130):
		_stars.append(Vector2(rng.randf_range(0, 1280), rng.randf_range(70, 530)))

# =============================================================================
#  PLAYER BADGE
# =============================================================================
func _build_player_badge() -> void:
	if not is_instance_valid(_avatar): return
	var uname: String = "?"
	if has_node("/root/PlayerProfile"): uname = PlayerProfile.get_username()
	var ring_col: Color  = Color("#FFD93D") if _is_teacher else Color("#4D96FF")
	var fill_col: Color  = Color("#2a1a00") if _is_teacher else Color("#0d1f3c")

	_badge_ring = ColorRect.new(); _badge_ring.color = ring_col
	_badge_ring.size = Vector2(44,44); _badge_ring.position = Vector2(-22,-22)
	_avatar.add_child(_badge_ring)

	_badge_circle = ColorRect.new(); _badge_circle.color = fill_col
	_badge_circle.size = Vector2(36,36); _badge_circle.position = Vector2(-18,-18); _badge_circle.z_index = 1
	_avatar.add_child(_badge_circle)

	_badge_label = Label.new(); _badge_label.text = "👑" if _is_teacher else uname.substr(0,1).to_upper()
	_badge_label.add_theme_font_size_override("font_size",16)
	_badge_label.add_theme_color_override("font_color", ring_col)
	_badge_label.position = Vector2(-9,-10); _badge_label.z_index = 2
	_avatar.add_child(_badge_label)

	var name_lbl := Label.new(); name_lbl.text = uname
	if _pixel_font: name_lbl.add_theme_font_override("font", _pixel_font)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", Color("#FFD93D") if _is_teacher else Color(1.0,0.95,0.6))
	name_lbl.position = Vector2(-24,-56); name_lbl.z_index = 2
	_avatar.add_child(name_lbl)

	if _is_teacher:
		var rl := Label.new(); rl.text = "TEACHER"
		if _pixel_font: rl.add_theme_font_override("font", _pixel_font)
		rl.add_theme_font_size_override("font_size", 9)
		rl.add_theme_color_override("font_color", Color("#FFD93D"))
		rl.position = Vector2(-22,-44); rl.z_index = 2
		_avatar.add_child(rl)

	_avatar.position = _avatar_pos
	var tw := create_tween(); tw.set_loops()
	tw.tween_property(_badge_ring,"color",Color(ring_col.r,ring_col.g,ring_col.b,0.28),1.1).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_badge_ring,"color",Color(ring_col.r,ring_col.g,ring_col.b,1.0), 1.1).set_trans(Tween.TRANS_SINE)

# =============================================================================
#  HUD
# =============================================================================
func _build_hud() -> void:
	var hud: CanvasLayer = $HUD as CanvasLayer
	var hud_h: int = 86 if _is_teacher else 62

	# ── Full-width background ─────────────────────────────────────────────────
	_hud_bg_rect = ColorRect.new()
	_hud_bg_rect.color    = Color(0.95,0.95,0.97,0.96) if _light_mode else Color(0,0,0,0.88)
	_hud_bg_rect.position = Vector2.ZERO
	_hud_bg_rect.size     = Vector2(4096, hud_h)   # oversized so it never gaps
	hud.add_child(_hud_bg_rect)

	_hud_accent_rect = ColorRect.new()
	_hud_accent_rect.color    = _theme_gold() if _is_teacher else _theme_blue()
	_hud_accent_rect.position = Vector2(0, hud_h - 2)
	_hud_accent_rect.size     = Vector2(4096, 2)
	hud.add_child(_hud_accent_rect)

	# Teacher bar
	if _is_teacher:
		var tbg := ColorRect.new()
		tbg.color    = Color(0.18,0.12,0.0,1.0) if not _light_mode else Color(1.0,0.95,0.7,1.0)
		tbg.position = Vector2(0, 62); tbg.size = Vector2(4096, 24)
		hud.add_child(tbg)

	# ── Anchor root — all Controls sit inside this so layout is reliable ───────
	var anchor := Control.new()
	anchor.set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(anchor)

	# ── TOP-LEFT: username + stats ────────────────────────────────────────────
	var left_vb := VBoxContainer.new()
	left_vb.add_theme_constant_override("separation", 2)
	left_vb.set_anchor_and_offset(SIDE_LEFT,   0,  10)
	left_vb.set_anchor_and_offset(SIDE_TOP,    0,   5)
	left_vb.set_anchor_and_offset(SIDE_RIGHT,  0, 260)
	left_vb.set_anchor_and_offset(SIDE_BOTTOM, 0, hud_h - 4)
	left_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(left_vb)

	var uname: String = "Guest"
	if has_node("/root/PlayerProfile"): uname = PlayerProfile.get_username()
	var u_lbl := Label.new(); u_lbl.text = uname
	if _pixel_font: u_lbl.add_theme_font_override("font", _pixel_font)
	u_lbl.add_theme_font_size_override("font_size", 11)
	u_lbl.add_theme_color_override("font_color", _theme_text2())
	u_lbl.clip_text = true; left_vb.add_child(u_lbl)

	if has_node("/root/PlayerProfile"):
		var st       := PlayerProfile.stats as Dictionary
		var score:   int = st.get("total_score",    0) as int
		var perfects:int = st.get("perfect_clears", 0) as int
		var streak:  int = st.get("login_streak",   0) as int

		var s_lbl := Label.new()
		s_lbl.text = "🏆 %d  ✨ %d perf" % [score, perfects]
		if _pixel_font: s_lbl.add_theme_font_override("font", _pixel_font)
		s_lbl.add_theme_font_size_override("font_size", 10)
		s_lbl.add_theme_color_override("font_color", _theme_gold())
		s_lbl.clip_text = true; left_vb.add_child(s_lbl)

		var k_lbl := Label.new()
		k_lbl.text = "🔥 %d day streak" % streak
		if _pixel_font: k_lbl.add_theme_font_override("font", _pixel_font)
		k_lbl.add_theme_font_size_override("font_size", 10)
		k_lbl.add_theme_color_override("font_color", _theme_gold())
		k_lbl.clip_text = true; left_vb.add_child(k_lbl)

	# ── CENTRE: ALGOQUEST + Kingdom Map ───────────────────────────────────────
	var centre_vb := VBoxContainer.new()
	centre_vb.add_theme_constant_override("separation", 0)
	centre_vb.set_anchor_and_offset(SIDE_LEFT,   0.5,  0)
	centre_vb.set_anchor_and_offset(SIDE_RIGHT,  0.5,  0)
	centre_vb.set_anchor_and_offset(SIDE_TOP,    0,    4)
	centre_vb.set_anchor_and_offset(SIDE_BOTTOM, 0,    hud_h - 4)
	centre_vb.alignment = BoxContainer.ALIGNMENT_CENTER
	centre_vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(centre_vb)

	var t1_lbl := Label.new(); t1_lbl.text = "ALGOQUEST"
	if _pixel_font: t1_lbl.add_theme_font_override("font", _pixel_font)
	t1_lbl.add_theme_font_size_override("font_size", 11)
	t1_lbl.add_theme_color_override("font_color", _theme_blue())
	t1_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_vb.add_child(t1_lbl)

	var t2_lbl := Label.new(); t2_lbl.text = "Kingdom Map"
	if _pixel_font: t2_lbl.add_theme_font_override("font", _pixel_font)
	t2_lbl.add_theme_font_size_override("font_size", 20)
	t2_lbl.add_theme_color_override("font_color", _theme_text())
	t2_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_vb.add_child(t2_lbl)

	if _is_teacher:
		var tm_lbl := Label.new(); tm_lbl.text = "🎓  Teacher Mode — All Levels Unlocked"
		if _pixel_font: tm_lbl.add_theme_font_override("font", _pixel_font)
		tm_lbl.add_theme_font_size_override("font_size", 11)
		tm_lbl.add_theme_color_override("font_color", _theme_gold())
		tm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tm_lbl.set_anchor_and_offset(SIDE_LEFT,  0.0,  0)
		tm_lbl.set_anchor_and_offset(SIDE_RIGHT, 1.0,  0)
		tm_lbl.set_anchor_and_offset(SIDE_TOP,   0.0, 65)
		tm_lbl.set_anchor_and_offset(SIDE_BOTTOM,0.0, 84)
		tm_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor.add_child(tm_lbl)

	# ── TOP-RIGHT: styled buttons anchored to right edge ──────────────────────
	var btn_w  := 110
	var btn_h  := 30
	var btn_gap := 8

	var btns: Array
	if _is_teacher:
		btns = [
			["Dashboard", "📊", Color("#c77dff"), func(): _toggle_teacher_dashboard()],
			["Settings",  "⚙",  Color("#4d96ff"), func(): _toggle_settings()],
		]
	else:
		btns = [
			["Profile",  "👤", Color("#4d96ff"), func(): _toggle_student_profile()],
			["Settings", "⚙",  Color("#6bcb77"), func(): _toggle_settings()],
		]

	var btn_y: int = (hud_h - btn_h) / 2
	for i in btns.size():
		var label_text: String = btns[i][0] as String
		var icon_text:  String = btns[i][1] as String
		var btn_col:    Color  = btns[i][2] as Color
		var callback:   Callable = btns[i][3] as Callable

		var b := Button.new()
		b.text = icon_text + "  " + label_text
		b.custom_minimum_size = Vector2(btn_w, btn_h)
		if _pixel_font: b.add_theme_font_override("font", _pixel_font)
		b.add_theme_font_size_override("font_size", 10)
		b.focus_mode = Control.FOCUS_NONE

		# Anchor to RIGHT edge — offset counts leftward from the right
		var right_off: int = 12 + (btns.size() - 1 - i) * (btn_w + btn_gap)
		b.set_anchor_and_offset(SIDE_RIGHT,  1.0, -right_off)
		b.set_anchor_and_offset(SIDE_LEFT,   1.0, -right_off - btn_w)
		b.set_anchor_and_offset(SIDE_TOP,    0.0,  btn_y)
		b.set_anchor_and_offset(SIDE_BOTTOM, 0.0,  btn_y + btn_h)

		var sb_n := StyleBoxFlat.new()
		sb_n.bg_color = Color(btn_col.r, btn_col.g, btn_col.b, 0.15)
		sb_n.set_border_width_all(1); sb_n.border_color = Color(btn_col.r, btn_col.g, btn_col.b, 0.7)
		sb_n.set_corner_radius_all(8)
		sb_n.content_margin_left = 10; sb_n.content_margin_right  = 10
		sb_n.content_margin_top  = 5;  sb_n.content_margin_bottom = 5
		b.add_theme_stylebox_override("normal", sb_n)

		var sb_h := sb_n.duplicate() as StyleBoxFlat
		sb_h.bg_color = Color(btn_col.r, btn_col.g, btn_col.b, 0.35)
		sb_h.border_color = btn_col
		b.add_theme_stylebox_override("hover", sb_h)

		var sb_p := sb_n.duplicate() as StyleBoxFlat
		sb_p.bg_color = Color(btn_col.r, btn_col.g, btn_col.b, 0.55)
		sb_p.set_border_width_all(2); sb_p.border_color = btn_col.lightened(0.3)
		b.add_theme_stylebox_override("pressed", sb_p)

		b.add_theme_color_override("font_color",         btn_col.lightened(0.4))
		b.add_theme_color_override("font_hover_color",   Color("#ffffff"))
		b.add_theme_color_override("font_pressed_color", Color("#ffffff"))
		b.pressed.connect(callback)
		anchor.add_child(b)

	# Completion dots — centred under title
	var fam_starts: Array[int] = [1, 6, 11, 16, 21]
	var tcols: Array[Color] = [Color("#6BCB77"),Color("#C77DFF"),Color("#FFD93D"),Color("#88CC77"),Color("#4D96FF")]
	var dot_total_w: int = fam_starts.size() * 16 + (fam_starts.size()-1) * 6
	for i: int in fam_starts.size():
		var ok := true
		if has_node("/root/PlayerProfile"):
			for t in range(5):
				var ld: Dictionary = (PlayerProfile.progress.get(fam_starts[i]+t,{}) as Dictionary)
				var lc: bool = ld.get("completed",false) as bool
				if not lc: lc = ld.get("complete",false) as bool
				if not lc:
					ok = false; break
		var dot := ColorRect.new()
		dot.color = tcols[i] if ok else (Color("#555566") if not _light_mode else Color("#b0b8cc"))
		dot.set_anchor_and_offset(SIDE_LEFT,   0.5, -dot_total_w/2 + i*22)
		dot.set_anchor_and_offset(SIDE_RIGHT,  0.5, -dot_total_w/2 + i*22 + 16)
		dot.set_anchor_and_offset(SIDE_TOP,    0.0,  hud_h - 10)
		dot.set_anchor_and_offset(SIDE_BOTTOM, 0.0,  hud_h - 4)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		anchor.add_child(dot)

	if is_instance_valid(_tooltip_bg):
		_tooltip_bg.visible = false
		if _pixel_font and is_instance_valid(_tooltip_lbl):
			_tooltip_lbl.add_theme_font_override("font", _pixel_font)
			_tooltip_lbl.add_theme_font_size_override("font_size", 13)

func _hud_lbl(p: Node, t: String, pos: Vector2, sz: int, col: Color) -> void:
	var l := Label.new(); l.text = t; l.position = pos
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if _pixel_font: l.add_theme_font_override("font", _pixel_font)
	p.add_child(l)

# =============================================================================
#  CLICK AREAS
# =============================================================================
func _build_region_areas() -> void:
	for ch: Dictionary in CHAPTERS:
		var cid: int = ch["id"] as int; var pos: Vector2 = ch["pos"] as Vector2
		var area := Area2D.new(); var shape := CollisionShape2D.new()
		var circ := CircleShape2D.new(); circ.radius = 54.0
		shape.shape = circ; area.position = pos; area.add_child(shape)
		area.input_event.connect(func(_vp, event: InputEvent, _i):
			if event is InputEventMouseButton:
				var mb := event as InputEventMouseButton
				if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
					_click(cid, _is_unlocked(cid), pos))
		area.mouse_entered.connect(func(): _hover(cid, pos))
		area.mouse_exited.connect(func():  _unhover())
		add_child(area)

# =============================================================================
#  INFO PANEL  (chapter tier selector)
# =============================================================================
func _build_info_panel() -> void:
	_panel_layer = CanvasLayer.new(); _panel_layer.layer = 20; _panel_layer.visible = false
	add_child(_panel_layer)
	_panel_dim = ColorRect.new(); _panel_dim.color = Color(0,0,0,0.62)
	_panel_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and \
		   (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_close_info_panel())
	_panel_layer.add_child(_panel_dim)
	_panel_root = PanelContainer.new()
	_panel_root.custom_minimum_size = Vector2(340,0)
	_panel_root.anchor_left = 0.5; _panel_root.anchor_right  = 0.5
	_panel_root.anchor_top  = 0.5; _panel_root.anchor_bottom = 0.5
	_panel_root.offset_left = -170; _panel_root.offset_right  = 170
	_panel_root.offset_top  = -270; _panel_root.offset_bottom = 270
	_panel_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel_root.grow_vertical   = Control.GROW_DIRECTION_BOTH
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0e0e1c"); sb.border_color = Color("#FFD93D")
	sb.set_border_width_all(2); sb.set_corner_radius_all(10)
	sb.content_margin_left = 24; sb.content_margin_right  = 24
	sb.content_margin_top  = 20; sb.content_margin_bottom = 24
	_panel_root.add_theme_stylebox_override("panel", sb)
	_panel_layer.add_child(_panel_root)
	_panel_vbox = VBoxContainer.new(); _panel_vbox.add_theme_constant_override("separation",10)
	_panel_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel_root.add_child(_panel_vbox)

func _open_info_panel(ch: Dictionary) -> void:
	if _dash_visible or _profile_visible or _settings_visible: return
	_selected_chapter = ch
	for n in _tier_nodes: if is_instance_valid(n): n.queue_free()
	_tier_nodes.clear()
	var cid: int = ch["id"] as int; var tiers: int = ch.get("tiers",1) as int
	var col: Color = ch["color"] as Color; var d: Dictionary = _map_data.get(cid,{}) as Dictionary
	var score: int = d.get("best_score",0) as int

	var header := HBoxContainer.new(); header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation",8)
	_panel_vbox.add_child(header); _tier_nodes.append(header)

	var sprite_path: String = ch.get("sprite","") as String
	if sprite_path != "" and ResourceLoader.exists(sprite_path):
		var thumb := TextureRect.new(); thumb.texture = load(sprite_path) as Texture2D
		thumb.custom_minimum_size = Vector2(36,36); thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumb.modulate = col; header.add_child(thumb)
	else:
		var il := Label.new(); il.text = ch.get("icon","?") as String
		il.add_theme_font_size_override("font_size",28); header.add_child(il)

	var title_lbl := Label.new(); title_lbl.text = ch["name"] as String
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _pixel_font: title_lbl.add_theme_font_override("font",_pixel_font)
	title_lbl.add_theme_font_size_override("font_size",20); title_lbl.add_theme_color_override("font_color",col)
	header.add_child(title_lbl)

	if _is_teacher:
		var tb := Label.new(); tb.text = "🎓 ALL"
		tb.add_theme_font_size_override("font_size",10); tb.add_theme_color_override("font_color",Color("#FFD93D"))
		header.add_child(tb)

	var xbtn := Button.new(); xbtn.text = "✕"; xbtn.flat = true; xbtn.custom_minimum_size = Vector2(30,30)
	if _pixel_font: xbtn.add_theme_font_override("font",_pixel_font)
	xbtn.add_theme_font_size_override("font_size",14); xbtn.add_theme_color_override("font_color",Color("#888888"))
	xbtn.pressed.connect(_close_info_panel); header.add_child(xbtn)

	var div := HSeparator.new(); var dsb := StyleBoxFlat.new()
	dsb.bg_color = col.darkened(0.3); dsb.content_margin_top = 1
	div.add_theme_stylebox_override("separator",dsb); _panel_vbox.add_child(div); _tier_nodes.append(div)

	var dsa := Label.new(); dsa.text = ch["dsa"] as String; dsa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: dsa.add_theme_font_override("font",_pixel_font)
	dsa.add_theme_font_size_override("font_size",12); dsa.add_theme_color_override("font_color",Color("#888860"))
	_panel_vbox.add_child(dsa); _tier_nodes.append(dsa)

	var sh := HBoxContainer.new(); sh.alignment = BoxContainer.ALIGNMENT_CENTER
	sh.add_theme_constant_override("separation",4); _panel_vbox.add_child(sh); _tier_nodes.append(sh)
	for t in range(tiers):
		var lvl_d: Dictionary = (_map_data.get(cid+t,{}) as Dictionary)
		var done: bool = lvl_d.get("completed",false) as bool
		if not done: done = lvl_d.get("complete",false) as bool
		var s := Label.new(); s.text = "⭐" if done else "☆"; s.add_theme_font_size_override("font_size",18)
		s.add_theme_color_override("font_color",Color("#FFD93D") if done else Color("#333322")); sh.add_child(s)

	var sc := Label.new(); sc.text = "Best: %d pts" % score if score > 0 else "Not yet played"
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: sc.add_theme_font_override("font",_pixel_font)
	sc.add_theme_font_size_override("font_size",12)
	sc.add_theme_color_override("font_color",Color("#FFD93D") if score > 0 else Color("#666650"))
	_panel_vbox.add_child(sc); _tier_nodes.append(sc)

	var dh := Label.new(); dh.text = "— Select Difficulty —"; dh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if _pixel_font: dh.add_theme_font_override("font",_pixel_font)
	dh.add_theme_font_size_override("font_size",11); dh.add_theme_color_override("font_color",Color("#666650"))
	_panel_vbox.add_child(dh); _tier_nodes.append(dh)

	for t in range(tiers):
		var tid: int = cid + t
		var tlvl: Dictionary = (_map_data.get(tid,{}) as Dictionary)
		var done: bool = tlvl.get("completed",false) as bool
		if not done: done = tlvl.get("complete",false) as bool
		var prev_lvl: Dictionary = (_map_data.get(cid+t-1,{}) as Dictionary)
		var prev_done: bool = prev_lvl.get("completed",false) as bool
		if not prev_done: prev_done = prev_lvl.get("complete",false) as bool
		var prev: bool = t == 0 or prev_done
		var ok: bool   = _is_teacher or prev or done
		var lbl: String = TIER_LABELS[t] if t < TIER_LABELS.size() else "Tier %d" % (t+1)
		var btn := Button.new(); btn.disabled = not ok
		btn.custom_minimum_size = Vector2(292,44); btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if _pixel_font: btn.add_theme_font_override("font",_pixel_font)
		btn.add_theme_font_size_override("font_size",15)
		var bc: Color = Color("#7a6000") if done else (col.darkened(0.55) if ok else Color("#1a1a14"))
		var sn := StyleBoxFlat.new(); var sv := StyleBoxFlat.new()
		var sp := StyleBoxFlat.new(); var sd := StyleBoxFlat.new()
		for sb2 in [sn,sv,sp,sd]:
			sb2.set_corner_radius_all(6); sb2.set_border_width_all(1)
			sb2.content_margin_left = 14; sb2.content_margin_right = 14
		sn.bg_color = bc; sn.border_color = col if ok else Color("#333322")
		sv.bg_color = bc.lightened(0.18) if ok else bc; sv.border_color = col.lightened(0.3) if ok else Color("#333322")
		sp.bg_color = bc.darkened(0.2); sp.border_color = Color("#FFD93D")
		sd.bg_color = Color("#111110"); sd.border_color = Color("#222218")
		btn.add_theme_stylebox_override("normal",sn); btn.add_theme_stylebox_override("hover",sv)
		btn.add_theme_stylebox_override("pressed",sp); btn.add_theme_stylebox_override("disabled",sd)
		var ico: String; var tc: Color
		if done: ico = "✓  "; tc = Color("#FFD93D")
		elif ok: ico = "▶  "; tc = col.lightened(0.4)
		else:    ico = "🔒 "; tc = Color("#444430")
		btn.text = ico + lbl
		btn.add_theme_color_override("font_color",tc)
		btn.add_theme_color_override("font_disabled_color",Color("#333322"))
		btn.add_theme_color_override("font_hover_color",tc.lightened(0.2))
		btn.add_theme_color_override("font_pressed_color",Color("#FFD93D"))
		var cap_tid: int = tid; var cap_pos: Vector2 = ch["pos"] as Vector2
		btn.pressed.connect(func():
			_close_info_panel()
			_walk_avatar_to(cap_pos, func(): GameRouter.go_to_chapter(cap_tid)))
		_panel_vbox.add_child(btn); _tier_nodes.append(btn)

	_panel_layer.visible = true

func _close_info_panel() -> void:
	if is_instance_valid(_panel_layer): _panel_layer.visible = false
	for n in _tier_nodes: if is_instance_valid(n): n.queue_free()
	_tier_nodes.clear(); _selected_chapter = {}

# =============================================================================
#  SETTINGS OVERLAY  (both roles — dark/light toggle + logout)
# =============================================================================
func _build_settings_overlay() -> void:
	_settings_layer = CanvasLayer.new(); _settings_layer.layer = 40; _settings_layer.visible = false
	add_child(_settings_layer)

	var dim := ColorRect.new(); dim.color = Color(0,0,0,0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_toggle_settings())
	_settings_layer.add_child(dim)

func _open_settings_overlay() -> void:
	# Clear and rebuild so theme colours are always fresh
	for child in _settings_layer.get_children():
		if child is PanelContainer: child.queue_free()

	var win := PanelContainer.new()
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.custom_minimum_size = Vector2(420, 0)
	win.offset_left = -210; win.offset_right  = 210
	win.offset_top  = -180; win.offset_bottom = 180
	var win_sb := StyleBoxFlat.new()
	win_sb.bg_color = _theme_bg2()
	win_sb.set_border_width_all(1); win_sb.border_color = _theme_purple()
	win_sb.set_corner_radius_all(14); win_sb.set_content_margin_all(0)
	win.add_theme_stylebox_override("panel", win_sb)
	win.gui_input.connect(func(ev: InputEvent): get_viewport().set_input_as_handled())
	_settings_layer.add_child(win)

	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation",0); win.add_child(vb)

	# Header
	var hdr := PanelContainer.new()
	var hdr_sb := StyleBoxFlat.new(); hdr_sb.bg_color = _theme_bg3()
	hdr_sb.border_width_bottom = 1; hdr_sb.border_color = _theme_border(); hdr_sb.set_content_margin_all(0)
	hdr.add_theme_stylebox_override("panel", hdr_sb); vb.add_child(hdr)
	var hdr_hb := HBoxContainer.new(); hdr_hb.add_theme_constant_override("separation",0); hdr.add_child(hdr_hb)
	var hdr_m := MarginContainer.new(); hdr_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_m.add_theme_constant_override("margin_left",20); hdr_m.add_theme_constant_override("margin_top",14)
	hdr_m.add_theme_constant_override("margin_bottom",14); hdr_hb.add_child(hdr_m)
	var title_l := Label.new(); title_l.text = "⚙  SETTINGS"
	if _pixel_font: title_l.add_theme_font_override("font",_pixel_font)
	title_l.add_theme_font_size_override("font_size",11); title_l.add_theme_color_override("font_color",_theme_purple())
	hdr_m.add_child(title_l)
	var close_m := MarginContainer.new()
	close_m.add_theme_constant_override("margin_right",14); close_m.add_theme_constant_override("margin_top",10)
	hdr_hb.add_child(close_m)
	var close_btn := Button.new(); close_btn.text = "✕"
	if _pixel_font: close_btn.add_theme_font_override("font",_pixel_font)
	close_btn.add_theme_font_size_override("font_size",12)
	close_btn.add_theme_color_override("font_color",_theme_text2())
	close_btn.add_theme_color_override("font_hover_color",_theme_red())
	var cb_sb := StyleBoxFlat.new(); cb_sb.bg_color = Color(0,0,0,0); cb_sb.set_border_width_all(0); cb_sb.set_content_margin_all(6)
	close_btn.add_theme_stylebox_override("normal",cb_sb); close_btn.add_theme_stylebox_override("hover",cb_sb)
	close_btn.pressed.connect(_toggle_settings); close_m.add_child(close_btn)

	# Body
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left",24); body.add_theme_constant_override("margin_right",24)
	body.add_theme_constant_override("margin_top",20); body.add_theme_constant_override("margin_bottom",24)
	vb.add_child(body)
	var body_vb := VBoxContainer.new(); body_vb.add_theme_constant_override("separation",16); body.add_child(body_vb)

	# ── Dark / Light toggle row ────────────────────────────────────────────────
	var theme_row := PanelContainer.new()
	var tr_sb := StyleBoxFlat.new(); tr_sb.bg_color = _theme_bg3()
	tr_sb.set_border_width_all(1); tr_sb.border_color = _theme_border()
	tr_sb.set_corner_radius_all(10); tr_sb.set_content_margin_all(16)
	theme_row.add_theme_stylebox_override("panel",tr_sb); body_vb.add_child(theme_row)
	var tr_hb := HBoxContainer.new(); tr_hb.add_theme_constant_override("separation",12); theme_row.add_child(tr_hb)
	var tr_vb := VBoxContainer.new(); tr_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr_vb.add_theme_constant_override("separation",2); tr_hb.add_child(tr_vb)
	var tr_title := Label.new(); tr_title.text = "🌙  Appearance"
	if _pixel_font: tr_title.add_theme_font_override("font",_pixel_font)
	tr_title.add_theme_font_size_override("font_size",10); tr_title.add_theme_color_override("font_color",_theme_text())
	tr_vb.add_child(tr_title)
	var tr_sub := Label.new(); tr_sub.text = "Dark mode / Light mode"
	tr_sub.add_theme_font_size_override("font_size",12); tr_sub.add_theme_color_override("font_color",_theme_text2())
	tr_vb.add_child(tr_sub)

	# Toggle button
	var toggle_btn := Button.new()
	toggle_btn.text = "☀ Light" if _light_mode else "🌑 Dark"
	if _pixel_font: toggle_btn.add_theme_font_override("font",_pixel_font)
	toggle_btn.add_theme_font_size_override("font_size",10)
	var tog_sb := StyleBoxFlat.new()
	tog_sb.bg_color = _theme_purple().darkened(0.3) if not _light_mode else _theme_blue()
	tog_sb.set_border_width_all(1); tog_sb.border_color = _theme_purple()
	tog_sb.set_corner_radius_all(20); tog_sb.set_content_margin_all(10)
	toggle_btn.add_theme_stylebox_override("normal",tog_sb)
	toggle_btn.add_theme_stylebox_override("hover",tog_sb)
	toggle_btn.add_theme_color_override("font_color",Color("#ffffff"))
	toggle_btn.custom_minimum_size = Vector2(100,36)
	toggle_btn.pressed.connect(func():
		_light_mode = not _light_mode
		# Persist to PlayerProfile — use set() to avoid the strict-property
		# assignment error that occurs when writing to autoload vars directly.
		if has_node("/root/PlayerProfile"):
			PlayerProfile.set("light_mode", _light_mode)
			if PlayerProfile.has_method("save_profile"): PlayerProfile.save_profile()
		_rebuild_all_for_theme()
		_open_settings_overlay())
	tr_hb.add_child(toggle_btn)

	# ── Account row ────────────────────────────────────────────────────────────
	var acc_row := PanelContainer.new()
	var ar_sb := StyleBoxFlat.new(); ar_sb.bg_color = _theme_bg3()
	ar_sb.set_border_width_all(1); ar_sb.border_color = _theme_border()
	ar_sb.set_corner_radius_all(10); ar_sb.set_content_margin_all(16)
	acc_row.add_theme_stylebox_override("panel",ar_sb); body_vb.add_child(acc_row)
	var ar_hb := HBoxContainer.new(); ar_hb.add_theme_constant_override("separation",12); acc_row.add_child(ar_hb)
	var ar_vb := VBoxContainer.new(); ar_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ar_vb.add_theme_constant_override("separation",2); ar_hb.add_child(ar_vb)
	var uname: String = PlayerProfile.get_username() if has_node("/root/PlayerProfile") else "—"
	var role_str: String  = "👑 Teacher" if _is_teacher else "🎮 Student"
	var ar_name := Label.new(); ar_name.text = uname
	if _pixel_font: ar_name.add_theme_font_override("font",_pixel_font)
	ar_name.add_theme_font_size_override("font_size",13); ar_name.add_theme_color_override("font_color",_theme_text())
	ar_vb.add_child(ar_name)
	var ar_role := Label.new(); ar_role.text = role_str
	ar_role.add_theme_font_size_override("font_size",12); ar_role.add_theme_color_override("font_color",_theme_text2())
	ar_vb.add_child(ar_role)
	var logout_btn := Button.new(); logout_btn.text = "↩  Log Out"
	if _pixel_font: logout_btn.add_theme_font_override("font",_pixel_font)
	logout_btn.add_theme_font_size_override("font_size",10)
	var lo_sb := StyleBoxFlat.new(); lo_sb.bg_color = Color(0,0,0,0)
	lo_sb.set_border_width_all(1); lo_sb.border_color = _theme_red()
	lo_sb.set_corner_radius_all(8); lo_sb.set_content_margin_all(10)
	logout_btn.add_theme_stylebox_override("normal",lo_sb)
	logout_btn.add_theme_color_override("font_color",_theme_red())
	logout_btn.pressed.connect(func():
		if has_node("/root/PlayerProfile") and PlayerProfile.has_method("logout"):
			PlayerProfile.logout()
		GameRouter.go_to_login())
	ar_hb.add_child(logout_btn)

	# ── Join Class row (students without a section only) ──────────────────────
	if not _is_teacher and has_node("/root/PlayerProfile"):
		var has_section: bool = not (PlayerProfile.section_id as String).is_empty()
		var join_row := PanelContainer.new()
		var jr_sb := StyleBoxFlat.new(); jr_sb.bg_color = _theme_bg3()
		jr_sb.set_border_width_all(1)
		jr_sb.border_color = _theme_blue() if not has_section else _theme_border()
		jr_sb.set_corner_radius_all(10); jr_sb.set_content_margin_all(16)
		join_row.add_theme_stylebox_override("panel",jr_sb); body_vb.add_child(join_row)

		var jr_vb := VBoxContainer.new(); jr_vb.add_theme_constant_override("separation",10); join_row.add_child(jr_vb)

		var jr_title := Label.new()
		jr_title.text = "🏫  Class Section"
		if _pixel_font: jr_title.add_theme_font_override("font",_pixel_font)
		jr_title.add_theme_font_size_override("font_size",10); jr_title.add_theme_color_override("font_color",_theme_text())
		jr_vb.add_child(jr_title)

		if has_section:
			var sec_lbl2 := Label.new()
			sec_lbl2.text = "✅  Enrolled: %s" % (PlayerProfile.section as String)
			sec_lbl2.add_theme_font_size_override("font_size",11)
			sec_lbl2.add_theme_color_override("font_color",_theme_green())
			jr_vb.add_child(sec_lbl2)
		else:
			var no_sec_lbl := Label.new()
			no_sec_lbl.text = "You are not enrolled in a class yet.\nEnter the join code your teacher gave you."
			no_sec_lbl.add_theme_font_size_override("font_size",11)
			no_sec_lbl.add_theme_color_override("font_color",_theme_text2())
			no_sec_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			jr_vb.add_child(no_sec_lbl)

			# Code input row
			var input_hb := HBoxContainer.new(); input_hb.add_theme_constant_override("separation",8); jr_vb.add_child(input_hb)

			var code_input := LineEdit.new()
			code_input.placeholder_text = "Enter join code…"
			code_input.max_length = 8
			code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var ci_sb := StyleBoxFlat.new(); ci_sb.bg_color = _theme_bg2()
			ci_sb.set_border_width_all(1); ci_sb.border_color = _theme_border()
			ci_sb.set_corner_radius_all(7); ci_sb.set_content_margin_all(10)
			code_input.add_theme_stylebox_override("normal",ci_sb)
			code_input.add_theme_stylebox_override("focus",ci_sb)
			code_input.add_theme_color_override("font_color",_theme_text())
			if _pixel_font: code_input.add_theme_font_override("font",_pixel_font)
			code_input.add_theme_font_size_override("font_size",12)
			input_hb.add_child(code_input)

			var status_lbl := Label.new(); status_lbl.text = ""
			status_lbl.add_theme_font_size_override("font_size",10)
			status_lbl.add_theme_color_override("font_color",_theme_green())

			var join_btn := Button.new(); join_btn.text = "Join"
			if _pixel_font: join_btn.add_theme_font_override("font",_pixel_font)
			join_btn.add_theme_font_size_override("font_size",10)
			var jb_sb := StyleBoxFlat.new(); jb_sb.bg_color = Color(_theme_blue().r,_theme_blue().g,_theme_blue().b,0.2)
			jb_sb.set_border_width_all(1); jb_sb.border_color = _theme_blue()
			jb_sb.set_corner_radius_all(7); jb_sb.set_content_margin_all(10)
			join_btn.add_theme_stylebox_override("normal",jb_sb)
			join_btn.add_theme_color_override("font_color",_theme_blue())
			join_btn.add_theme_color_override("font_hover_color",Color("#ffffff"))
			join_btn.pressed.connect(func():
				var code: String = code_input.text.strip_edges().to_upper()
				if code.is_empty():
					status_lbl.text = "Please enter a code."; status_lbl.add_theme_color_override("font_color",_theme_red()); return
				status_lbl.text = "Joining…"; status_lbl.add_theme_color_override("font_color",_theme_text2())
				if has_node("/root/PlayerProfile") and PlayerProfile.has_method("join_section_by_code"):
					PlayerProfile.join_section_by_code(code, func(ok: bool, msg: String):
						if ok:
							status_lbl.text = "✅ " + msg
							status_lbl.add_theme_color_override("font_color",_theme_green())
							# Refresh settings panel to show enrolled state
							await get_tree().create_timer(1.2).timeout
							_open_settings_overlay()
						else:
							status_lbl.text = "❌ " + msg
							status_lbl.add_theme_color_override("font_color",_theme_red()))
				else:
					status_lbl.text = "Join not available yet."
					status_lbl.add_theme_color_override("font_color",_theme_red()))
			input_hb.add_child(join_btn)
			jr_vb.add_child(status_lbl)

func _toggle_settings() -> void:
	if not is_instance_valid(_settings_layer): return
	_settings_visible = not _settings_visible
	_settings_layer.visible = _settings_visible
	if _settings_visible: _open_settings_overlay()

# =============================================================================
#  STUDENT PROFILE OVERLAY  (students only — shows own progress)
# =============================================================================
func _build_student_profile() -> void:
	_profile_layer = CanvasLayer.new(); _profile_layer.layer = 35; _profile_layer.visible = false
	add_child(_profile_layer)
	var dim := ColorRect.new(); dim.color = Color(0,0,0,0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_toggle_student_profile())
	_profile_layer.add_child(dim)

func _open_student_profile() -> void:
	for child in _profile_layer.get_children():
		if child is PanelContainer: child.queue_free()

	if not has_node("/root/PlayerProfile"): return
	var pr := PlayerProfile.progress as Dictionary
	var st := PlayerProfile.stats as Dictionary

	var win := PanelContainer.new()
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.custom_minimum_size = Vector2(700, 0)
	win.offset_left = -350; win.offset_right  = 350
	win.offset_top  = -310; win.offset_bottom = 310
	var win_sb := StyleBoxFlat.new(); win_sb.bg_color = _theme_bg2()
	win_sb.set_border_width_all(1); win_sb.border_color = _theme_blue()
	win_sb.set_corner_radius_all(14); win_sb.set_content_margin_all(0)
	win.add_theme_stylebox_override("panel", win_sb)
	win.gui_input.connect(func(ev: InputEvent): get_viewport().set_input_as_handled())
	_profile_layer.add_child(win)

	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation",0); win.add_child(outer)

	# Header
	var hdr_pc := PanelContainer.new()
	var hdr_sb := StyleBoxFlat.new(); hdr_sb.bg_color = _theme_bg3()
	hdr_sb.border_width_bottom = 1; hdr_sb.border_color = _theme_blue(); hdr_sb.set_content_margin_all(0)
	hdr_pc.add_theme_stylebox_override("panel",hdr_sb); outer.add_child(hdr_pc)
	var hdr_hb := HBoxContainer.new(); hdr_hb.add_theme_constant_override("separation",0); hdr_pc.add_child(hdr_hb)
	var hdr_m := MarginContainer.new(); hdr_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hdr_m.add_theme_constant_override("margin_left",20); hdr_m.add_theme_constant_override("margin_top",14)
	hdr_m.add_theme_constant_override("margin_bottom",14); hdr_hb.add_child(hdr_m)
	var hdr_vb := VBoxContainer.new(); hdr_vb.add_theme_constant_override("separation",2); hdr_m.add_child(hdr_vb)
	var ht := Label.new(); ht.text = "🎮  MY PROGRESS"
	if _pixel_font: ht.add_theme_font_override("font",_pixel_font)
	ht.add_theme_font_size_override("font_size",11); ht.add_theme_color_override("font_color",_theme_blue())
	hdr_vb.add_child(ht)
	var hs := Label.new(); hs.text = PlayerProfile.get_username()
	hs.add_theme_font_size_override("font_size",12); hs.add_theme_color_override("font_color",_theme_text2())
	hdr_vb.add_child(hs)
	var close_m2 := MarginContainer.new()
	close_m2.add_theme_constant_override("margin_right",14); close_m2.add_theme_constant_override("margin_top",12)
	hdr_hb.add_child(close_m2)
	var cb2 := Button.new(); cb2.text = "✕  Close"
	if _pixel_font: cb2.add_theme_font_override("font",_pixel_font)
	cb2.add_theme_font_size_override("font_size",10)
	cb2.add_theme_color_override("font_color",_theme_text2()); cb2.add_theme_color_override("font_hover_color",_theme_red())
	var cb2_sb := StyleBoxFlat.new(); cb2_sb.bg_color = Color(0,0,0,0)
	cb2_sb.set_border_width_all(1); cb2_sb.border_color = _theme_border(); cb2_sb.set_corner_radius_all(6); cb2_sb.set_content_margin_all(8)
	cb2.add_theme_stylebox_override("normal",cb2_sb); cb2.pressed.connect(_toggle_student_profile); close_m2.add_child(cb2)

	# Scrollable body
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; outer.add_child(scroll)
	var body_m := MarginContainer.new(); body_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_m.add_theme_constant_override("margin_left",22); body_m.add_theme_constant_override("margin_right",22)
	body_m.add_theme_constant_override("margin_top",18); body_m.add_theme_constant_override("margin_bottom",22)
	scroll.add_child(body_m)
	var body_vb := VBoxContainer.new(); body_vb.add_theme_constant_override("separation",14)
	body_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body_m.add_child(body_vb)

	# Stat cards
	var total_stars: int = 0
	var done_count:  int = 0
	for v in pr.values():
		total_stars += (v as Dictionary).get("stars",0) as int
		# SaveManager writes "completed"; accept both for compatibility
		var is_done: bool = (v as Dictionary).get("completed",false) as bool
		if not is_done: is_done = (v as Dictionary).get("complete",false) as bool
		if is_done: done_count += 1
	var cards_hb := HBoxContainer.new(); cards_hb.add_theme_constant_override("separation",10); body_vb.add_child(cards_hb)
	for card_data in [
		["🏆", str(st.get("total_score",0) as int), "Total Score"],
		["⭐", "%d/75" % total_stars,               "Stars"],
		["✅", "%d/25" % done_count,                "Levels"],
		["🔥", str(st.get("login_streak",0) as int)+"d","Streak"],
	]:
		var c := _dash_stat_card(card_data[0] as String, card_data[1] as String, card_data[2] as String)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cards_hb.add_child(c)

	# Chapter progress — each row is a button that expands to show tier details
	var sec_lbl := Label.new(); sec_lbl.text = "CHAPTER PROGRESS  (tap to see tier details)"
	if _pixel_font: sec_lbl.add_theme_font_override("font",_pixel_font)
	sec_lbl.add_theme_font_size_override("font_size",9); sec_lbl.add_theme_color_override("font_color",_theme_text2())
	body_vb.add_child(sec_lbl)

	for ch in CH_DATA:
		var chid: int   = ch["id"] as int
		var tiers: int  = 5   # always 5 tiers per chapter
		# Summary stats from the first tier entry (chid) as chapter header
		var p0: Dictionary = pr.get(chid,{}) as Dictionary
		var any_done: bool = false
		var all_done: bool = true
		var best_score: int = 0
		var total_ch_stars: int = 0
		for t in range(tiers):
			var pt: Dictionary = pr.get(chid+t,{}) as Dictionary
			# SaveManager uses "completed"; accept both
			var lvl_done: bool = pt.get("completed",false) as bool
			if not lvl_done: lvl_done = pt.get("complete",false) as bool
			if lvl_done: any_done = true
			else: all_done = false
			best_score    = max(best_score, pt.get("best_score",0) as int)
			total_ch_stars += pt.get("stars",0) as int
		# Unlock: topic 1 (chid==1) always open.
		# Each other topic unlocks when the LAST level of the previous topic is done.
		# Previous topic's last level = chid - 1  (e.g. topic starting at 6 → check level 5)
		var prev_last_done: bool = false
		if chid > 1:
			var prev_last: Dictionary = pr.get(chid-1,{}) as Dictionary
			prev_last_done = prev_last.get("completed",false) as bool
			if not prev_last_done: prev_last_done = prev_last.get("complete",false) as bool
		var unlocked: bool = chid == 1 or prev_last_done or _is_teacher

		# ── Chapter header button (click to toggle tier rows) ─────────────────
		var ch_btn := Button.new()
		ch_btn.custom_minimum_size = Vector2(0, 52)
		ch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch_btn.focus_mode = Control.FOCUS_NONE
		var ch_n := StyleBoxFlat.new(); ch_n.bg_color = _theme_bg3()
		ch_n.set_border_width_all(1)
		if all_done: ch_n.border_color = ch["col"] as Color; ch_n.border_width_left = 3
		elif any_done: ch_n.border_color = (ch["col"] as Color).darkened(0.3); ch_n.border_width_left = 2
		else: ch_n.border_color = _theme_border()
		ch_n.set_corner_radius_all(8); ch_n.set_content_margin_all(0)
		var ch_h := ch_n.duplicate() as StyleBoxFlat
		ch_h.bg_color = _theme_bg3().lightened(0.06) if not _light_mode else _theme_bg3().darkened(0.04)
		ch_btn.add_theme_stylebox_override("normal",ch_n)
		ch_btn.add_theme_stylebox_override("hover",ch_h)
		ch_btn.add_theme_stylebox_override("pressed",ch_h)

		# Inner HBox for the header content
		var ch_hb := HBoxContainer.new(); ch_hb.add_theme_constant_override("separation",10)
		ch_hb.set_anchors_preset(Control.PRESET_FULL_RECT)
		ch_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ch_m := MarginContainer.new(); ch_m.set_anchors_preset(Control.PRESET_FULL_RECT)
		ch_m.add_theme_constant_override("margin_left",14); ch_m.add_theme_constant_override("margin_right",14)
		ch_m.add_theme_constant_override("margin_top",10); ch_m.add_theme_constant_override("margin_bottom",10)
		ch_m.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_btn.add_child(ch_m)
		ch_m.add_child(ch_hb)

		var ico_l := Label.new(); ico_l.text = ch["icon"] as String
		ico_l.add_theme_font_size_override("font_size",22); ico_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_hb.add_child(ico_l)

		var info_vb2 := VBoxContainer.new(); info_vb2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_vb2.add_theme_constant_override("separation",2); info_vb2.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_hb.add_child(info_vb2)
		var nm_l := Label.new(); nm_l.text = ch["name"] as String
		if _pixel_font: nm_l.add_theme_font_override("font",_pixel_font)
		nm_l.add_theme_font_size_override("font_size",12); nm_l.add_theme_color_override("font_color",_theme_text()); nm_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; info_vb2.add_child(nm_l)
		var dsa_l := Label.new(); dsa_l.text = ch["dsa"] as String
		dsa_l.add_theme_font_size_override("font_size",10); dsa_l.add_theme_color_override("font_color",_theme_text2()); dsa_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; info_vb2.add_child(dsa_l)
		if not unlocked:
			var lk_l := Label.new(); lk_l.text = "🔒 Locked"
			lk_l.add_theme_font_size_override("font_size",10); lk_l.add_theme_color_override("font_color",_theme_text3()); lk_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; info_vb2.add_child(lk_l)

		# Right side: stars summary + score
		var right_vb2 := VBoxContainer.new(); right_vb2.add_theme_constant_override("separation",2)
		right_vb2.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_hb.add_child(right_vb2)
		var stars_summary := Label.new()
		stars_summary.text = "★".repeat(min(total_ch_stars,15)) + "☆".repeat(max(0,15-total_ch_stars))
		stars_summary.add_theme_font_size_override("font_size",10); stars_summary.add_theme_color_override("font_color",_theme_gold())
		stars_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE; right_vb2.add_child(stars_summary)
		if best_score > 0:
			var sc_l := Label.new(); sc_l.text = "Best: %d" % best_score
			if _pixel_font: sc_l.add_theme_font_override("font",_pixel_font)
			sc_l.add_theme_font_size_override("font_size",8); sc_l.add_theme_color_override("font_color",_theme_text2())
			sc_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; right_vb2.add_child(sc_l)

		# Expand arrow
		var arrow_l := Label.new(); arrow_l.text = "▼"
		arrow_l.add_theme_font_size_override("font_size",10); arrow_l.add_theme_color_override("font_color",_theme_text3())
		arrow_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_hb.add_child(arrow_l)

		body_vb.add_child(ch_btn)

		# ── Tier rows container (hidden by default, toggled by button) ─────────
		var tier_container := VBoxContainer.new()
		tier_container.add_theme_constant_override("separation",4)
		tier_container.visible = false
		body_vb.add_child(tier_container)

		for t in range(tiers):
			var tid: int    = chid + t
			var pt: Dictionary = pr.get(tid,{}) as Dictionary
			var t_done_raw: bool  = pt.get("completed",false) as bool
			if not t_done_raw: t_done_raw = pt.get("complete",false) as bool
			var t_done:  bool  = t_done_raw
			var t_stars: int   = pt.get("stars",0) as int
			var t_score: int   = pt.get("best_score",0) as int
			var t_acc:   float = pt.get("accuracy",0.0) as float
			var prev_pt: Dictionary = pr.get(tid-1,{}) as Dictionary
			var t_prev_done: bool = prev_pt.get("completed",false) as bool
			if not t_prev_done: t_prev_done = prev_pt.get("complete",false) as bool
			var t_prev:  bool  = t == 0 or t_prev_done
			var t_unlocked: bool = unlocked and (t_prev or t_done)
			var mk: Dictionary = pt.get("mistakes",{}) as Dictionary

			var tier_pc := PanelContainer.new()
			var tier_sb := StyleBoxFlat.new()
			tier_sb.bg_color = Color(_theme_bg3().r,_theme_bg3().g,_theme_bg3().b,0.7)
			tier_sb.set_border_width_all(1)
			if t_done: tier_sb.border_color = (ch["col"] as Color).darkened(0.2); tier_sb.border_width_left = 2
			else: tier_sb.border_color = _theme_border()
			tier_sb.set_corner_radius_all(6); tier_sb.set_content_margin_all(12)
			tier_pc.add_theme_stylebox_override("panel",tier_sb)

			var tier_hb := HBoxContainer.new(); tier_hb.add_theme_constant_override("separation",10); tier_pc.add_child(tier_hb)

			# Tier index badge
			var idx_pc := PanelContainer.new()
			var idx_sb := StyleBoxFlat.new()
			idx_sb.bg_color = (ch["col"] as Color).darkened(0.5) if t_unlocked else _theme_bg3()
			idx_sb.set_corner_radius_all(4); idx_sb.set_content_margin_all(6)
			idx_pc.add_theme_stylebox_override("panel",idx_sb); idx_pc.custom_minimum_size = Vector2(36,0)
			var idx_l := Label.new(); idx_l.text = TIER_LABELS[t] if t < TIER_LABELS.size() else str(t+1)
			if _pixel_font: idx_l.add_theme_font_override("font",_pixel_font)
			idx_l.add_theme_font_size_override("font_size",8)
			idx_l.add_theme_color_override("font_color",ch["col"] as Color if t_unlocked else _theme_text3())
			idx_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			idx_pc.add_child(idx_l); tier_hb.add_child(idx_pc)

			# Status icon
			var status_l := Label.new()
			if not t_unlocked:  status_l.text = "🔒"
			elif t_done:        status_l.text = "✅"
			else:               status_l.text = "▶"
			status_l.add_theme_font_size_override("font_size",14); tier_hb.add_child(status_l)

			# Info
			var ti_vb := VBoxContainer.new(); ti_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ti_vb.add_theme_constant_override("separation",2); tier_hb.add_child(ti_vb)

			if t_done or t_score > 0:
				var sc_l2 := Label.new(); sc_l2.text = "%d pts" % t_score
				if _pixel_font: sc_l2.add_theme_font_override("font",_pixel_font)
				sc_l2.add_theme_font_size_override("font_size",9); sc_l2.add_theme_color_override("font_color",_theme_gold()); ti_vb.add_child(sc_l2)
			if t_acc > 0.0:
				var ac2: int = int(t_acc)
				var ac_col: Color = _theme_green() if ac2 >= 80 else (_theme_orange() if ac2 >= 60 else _theme_red())
				var ac_l := Label.new(); ac_l.text = "%d%% accuracy" % ac2
				ac_l.add_theme_font_size_override("font_size",10); ac_l.add_theme_color_override("font_color",ac_col); ti_vb.add_child(ac_l)

			# Mistake summary for this tier
			var mk_keys := ["fifo_violation","wrong_pop","overflow","service_miss","lane_miss"]
			var mk_lbls := {"fifo_violation":"FIFO","wrong_pop":"Pop","overflow":"Overflow","service_miss":"Svc","lane_miss":"Lane"}
			var mk_parts: Array = []
			for mk_key in mk_keys:
				var mv: int = mk.get(mk_key,0) as int
				if mv > 0: mk_parts.append("%s×%d" % [mk_lbls[mk_key] as String, mv])
			if not mk_parts.is_empty():
				var mk_l := Label.new(); mk_l.text = "Mistakes: " + ", ".join(mk_parts)
				mk_l.add_theme_font_size_override("font_size",9); mk_l.add_theme_color_override("font_color",_theme_red()); ti_vb.add_child(mk_l)
			elif not t_unlocked:
				var lk2 := Label.new(); lk2.text = "Complete previous tier first"
				lk2.add_theme_font_size_override("font_size",9); lk2.add_theme_color_override("font_color",_theme_text3()); ti_vb.add_child(lk2)
			elif not t_done:
				var nd_l := Label.new(); nd_l.text = "Not attempted yet"
				nd_l.add_theme_font_size_override("font_size",9); nd_l.add_theme_color_override("font_color",_theme_text3()); ti_vb.add_child(nd_l)

			# Stars for this tier
			var t_stars_l := Label.new(); t_stars_l.text = "★".repeat(t_stars)+"☆".repeat(3-t_stars)
			t_stars_l.add_theme_font_size_override("font_size",14); t_stars_l.add_theme_color_override("font_color",_theme_gold())
			tier_hb.add_child(t_stars_l)

			tier_container.add_child(tier_pc)

		# Wire toggle
		var cap_tc := tier_container; var cap_arrow := arrow_l
		ch_btn.pressed.connect(func():
			cap_tc.visible = not cap_tc.visible
			cap_arrow.text = "▲" if cap_tc.visible else "▼")

func _toggle_student_profile() -> void:
	if not is_instance_valid(_profile_layer): return
	_profile_visible = not _profile_visible
	_profile_layer.visible = _profile_visible
	if _profile_visible: _open_student_profile()

# =============================================================================
#  TEACHER DASHBOARD
# =============================================================================
func _build_teacher_dashboard() -> void:
	_dash_layer = CanvasLayer.new(); _dash_layer.layer = 30; _dash_layer.visible = false
	add_child(_dash_layer)
	var dim := ColorRect.new(); dim.color = Color(0,0,0,0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed and \
		   (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_toggle_teacher_dashboard())
	_dash_layer.add_child(dim)

	var win := PanelContainer.new()
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.custom_minimum_size = Vector2(1100, 640)
	win.offset_left = -550; win.offset_right  = 550
	win.offset_top  = -320; win.offset_bottom = 320
	var win_sb := StyleBoxFlat.new(); win_sb.bg_color = _theme_bg2()
	win_sb.set_border_width_all(1); win_sb.border_color = _theme_purple()
	win_sb.set_corner_radius_all(14); win_sb.set_content_margin_all(0)
	win.add_theme_stylebox_override("panel", win_sb)
	win.gui_input.connect(func(ev: InputEvent): get_viewport().set_input_as_handled())
	_dash_layer.add_child(win)

	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation",0); win.add_child(outer)
	outer.add_child(_build_dash_header())
	outer.add_child(_build_dash_tab_bar())

	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; outer.add_child(scroll)
	var margin := MarginContainer.new(); margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left",24); margin.add_theme_constant_override("margin_right",24)
	margin.add_theme_constant_override("margin_top",20); margin.add_theme_constant_override("margin_bottom",24)
	scroll.add_child(margin)
	_dash_content_root = VBoxContainer.new()
	_dash_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dash_content_root.add_theme_constant_override("separation",16)
	margin.add_child(_dash_content_root)

func _build_dash_header() -> Control:
	var hbar := PanelContainer.new()
	var hbar_sb := StyleBoxFlat.new()
	hbar_sb.bg_color = Color(0.08,0.06,0.02,1.0) if not _light_mode else Color(1.0,0.97,0.88,1.0)
	hbar_sb.border_width_bottom = 1; hbar_sb.border_color = _theme_gold().darkened(0.3)
	hbar_sb.set_content_margin_all(0); hbar.add_theme_stylebox_override("panel", hbar_sb)
	var hbox := HBoxContainer.new(); hbox.add_theme_constant_override("separation",0); hbar.add_child(hbox)
	var lm := MarginContainer.new(); lm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lm.add_theme_constant_override("margin_left",20); lm.add_theme_constant_override("margin_top",14); lm.add_theme_constant_override("margin_bottom",14); hbox.add_child(lm)
	var tvb := VBoxContainer.new(); tvb.add_theme_constant_override("separation",2); lm.add_child(tvb)
	var crown := Label.new(); crown.text = "👑  TEACHER DASHBOARD"
	if _pixel_font: crown.add_theme_font_override("font",_pixel_font)
	crown.add_theme_font_size_override("font_size",11); crown.add_theme_color_override("font_color",_theme_gold()); tvb.add_child(crown)
	var uname: String = PlayerProfile.get_username() if has_node("/root/PlayerProfile") else "Teacher"
	var sub := Label.new(); sub.text = "Logged in as: %s   —   Student progress overview" % uname
	sub.add_theme_font_size_override("font_size",12); sub.add_theme_color_override("font_color",_theme_text2()); tvb.add_child(sub)
	var rm := MarginContainer.new(); rm.add_theme_constant_override("margin_right",16); rm.add_theme_constant_override("margin_top",12); hbox.add_child(rm)
	var close_btn := Button.new(); close_btn.text = "✕  Close"
	if _pixel_font: close_btn.add_theme_font_override("font",_pixel_font)
	close_btn.add_theme_font_size_override("font_size",10)
	close_btn.add_theme_color_override("font_color",_theme_text2()); close_btn.add_theme_color_override("font_hover_color",_theme_red())
	var cb_sb := StyleBoxFlat.new(); cb_sb.bg_color = Color(0,0,0,0); cb_sb.set_border_width_all(1)
	cb_sb.border_color = _theme_border2(); cb_sb.set_corner_radius_all(6); cb_sb.set_content_margin_all(8)
	close_btn.add_theme_stylebox_override("normal",cb_sb)
	var cb_hov := cb_sb.duplicate() as StyleBoxFlat; cb_hov.border_color = _theme_red()
	close_btn.add_theme_stylebox_override("hover",cb_hov)
	close_btn.pressed.connect(_toggle_teacher_dashboard); rm.add_child(close_btn)
	return hbar

func _theme_border2() -> Color: return _t(DC_BORDER2, LC_BORDER2)

func _build_dash_tab_bar() -> Control:
	var tab_bg := PanelContainer.new()
	var tab_sb := StyleBoxFlat.new(); tab_sb.bg_color = _theme_bg3()
	tab_sb.border_width_bottom = 1; tab_sb.border_color = _theme_border(); tab_sb.set_content_margin_all(0)
	tab_bg.add_theme_stylebox_override("panel",tab_sb)
	var hbox := HBoxContainer.new(); hbox.add_theme_constant_override("separation",0); tab_bg.add_child(hbox)
	var tm := MarginContainer.new(); tm.add_theme_constant_override("margin_left",20)
	tm.add_theme_constant_override("margin_top",0); tm.add_theme_constant_override("margin_bottom",0); hbox.add_child(tm)
	var inner := HBoxContainer.new(); inner.add_theme_constant_override("separation",4); tm.add_child(inner)
	_dash_tab_btns.clear()
	for i in ["🗺  Overview","👥  Students","📈  Class Progress"].size():
		var labels := ["🗺  Overview","👥  Students","📈  Class Progress"]
		var tb := Button.new(); tb.text = labels[i]
		if _pixel_font: tb.add_theme_font_override("font",_pixel_font)
		tb.add_theme_font_size_override("font_size",9); tb.custom_minimum_size = Vector2(160,42)
		var n_sb := StyleBoxFlat.new(); n_sb.bg_color = Color(0,0,0,0)
		n_sb.border_width_bottom = 3; n_sb.border_color = Color(0,0,0,0); n_sb.set_content_margin_all(10)
		var h_sb := n_sb.duplicate() as StyleBoxFlat; h_sb.border_color = _theme_purple().darkened(0.4)
		tb.add_theme_stylebox_override("normal",n_sb); tb.add_theme_stylebox_override("hover",h_sb); tb.add_theme_stylebox_override("pressed",n_sb)
		tb.add_theme_color_override("font_color",_theme_text3()); tb.add_theme_color_override("font_hover_color",_theme_text())
		var cap_i := i; tb.pressed.connect(func(): _dash_switch_tab(cap_i))
		inner.add_child(tb); _dash_tab_btns.append(tb)
	return tab_bg

func _dash_switch_tab(idx: int) -> void:
	_dash_active_tab = idx
	for i in _dash_tab_btns.size():
		var tb: Button = _dash_tab_btns[i] as Button
		var active_sb := StyleBoxFlat.new(); active_sb.bg_color = Color(0,0,0,0)
		active_sb.border_width_bottom = 3; active_sb.set_content_margin_all(10)
		if i == idx:
			active_sb.border_color = _theme_purple()
			tb.add_theme_stylebox_override("normal",active_sb); tb.add_theme_color_override("font_color",_theme_purple())
		else:
			active_sb.border_color = Color(0,0,0,0)
			tb.add_theme_stylebox_override("normal",active_sb); tb.add_theme_color_override("font_color",_theme_text3())
	for child in _dash_content_root.get_children(): child.queue_free()
	match idx:
		0: _dash_build_overview()
		1: _dash_build_students()
		2: _dash_build_class_progress()

func _toggle_teacher_dashboard() -> void:
	if not is_instance_valid(_dash_layer): return
	_dash_visible = not _dash_visible
	_dash_layer.visible = _dash_visible
	if _dash_visible:
		_close_info_panel()
		_dash_switch_tab(_dash_active_tab)
		if has_node("/root/PlayerProfile"):
			PlayerProfile.fetch_teacher_students(func(students: Array):
				_dash_students = students
				if _dash_visible: _dash_switch_tab(_dash_active_tab))

# =============================================================================
#  DASHBOARD HELPERS
# =============================================================================
func _dash_panel(min_h: int = 0) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := StyleBoxFlat.new(); sb.bg_color = _theme_bg2()
	sb.set_border_width_all(1); sb.border_color = _theme_border()
	sb.set_corner_radius_all(10); sb.set_content_margin_all(18)
	if min_h > 0: pc.custom_minimum_size = Vector2(0, min_h)
	pc.add_theme_stylebox_override("panel",sb); return pc

func _dash_section_label(text: String) -> Label:
	var l := Label.new(); l.text = text
	if _pixel_font: l.add_theme_font_override("font",_pixel_font)
	l.add_theme_font_size_override("font_size",9); l.add_theme_color_override("font_color",_theme_text2()); return l

func _dash_stat_card(icon: String, value: String, label_text: String) -> PanelContainer:
	var card := _dash_panel(); card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation",6); card.add_child(vb)
	var il := Label.new(); il.text = icon; il.add_theme_font_size_override("font_size",22); vb.add_child(il)
	var vl := Label.new(); vl.text = value
	if _pixel_font: vl.add_theme_font_override("font",_pixel_font)
	vl.add_theme_font_size_override("font_size",17); vl.add_theme_color_override("font_color",_theme_text()); vb.add_child(vl)
	var sl := Label.new(); sl.text = label_text; sl.add_theme_font_size_override("font_size",12)
	sl.add_theme_color_override("font_color",_theme_text2()); vb.add_child(sl); return card

func _dash_bar_row(lbl_text: String, pct: float, col: Color, right_text: String) -> Control:
	var hb := HBoxContainer.new(); hb.add_theme_constant_override("separation",10)
	var lbl := Label.new(); lbl.text = lbl_text; lbl.custom_minimum_size = Vector2(170,0)
	lbl.add_theme_font_size_override("font_size",12); lbl.add_theme_color_override("font_color",_theme_text2()); hb.add_child(lbl)
	var bar_bg := PanelContainer.new(); bar_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_bg.custom_minimum_size = Vector2(0,8)
	var bar_sb := StyleBoxFlat.new(); bar_sb.bg_color = _theme_bg3(); bar_sb.set_corner_radius_all(4); bar_sb.set_content_margin_all(0)
	bar_bg.add_theme_stylebox_override("panel",bar_sb)
	var bar_inner := HBoxContainer.new(); bar_inner.add_theme_constant_override("separation",0); bar_bg.add_child(bar_inner)
	if pct > 0.0:
		var fill := ColorRect.new(); fill.color = col; fill.custom_minimum_size = Vector2(0,8)
		fill.size_flags_horizontal = Control.SIZE_FILL; fill.size_flags_stretch_ratio = pct/100.0; bar_inner.add_child(fill)
		if pct < 100.0:
			var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sp.size_flags_stretch_ratio = 1.0-(pct/100.0); bar_inner.add_child(sp)
	else:
		var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; bar_inner.add_child(sp)
	hb.add_child(bar_bg)
	var rl := Label.new(); rl.text = right_text; rl.custom_minimum_size = Vector2(52,0)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if _pixel_font: rl.add_theme_font_override("font",_pixel_font)
	rl.add_theme_font_size_override("font_size",8); rl.add_theme_color_override("font_color",_theme_text2()); hb.add_child(rl)
	return hb

func _dash_cell(text: String, min_w: int, col: Color, is_header: bool) -> Control:
	var m := MarginContainer.new(); m.custom_minimum_size = Vector2(min_w,0)
	m.add_theme_constant_override("margin_left",10); m.add_theme_constant_override("margin_right",10)
	m.add_theme_constant_override("margin_top",10);  m.add_theme_constant_override("margin_bottom",10)
	var lbl := Label.new(); lbl.text = text
	lbl.add_theme_font_size_override("font_size", 8 if is_header else 12)
	lbl.add_theme_color_override("font_color",col); lbl.clip_text = true
	if is_header and _pixel_font: lbl.add_theme_font_override("font",_pixel_font)
	m.add_child(lbl); return m

func _dash_loading_panel() -> PanelContainer:
	var p := _dash_panel(200)
	var l := Label.new(); l.text = "⏳  Loading student data from Firestore…"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",13); l.add_theme_color_override("font_color",_theme_text3()); p.add_child(l); return p

func _dash_empty(msg: String) -> Label:
	var l := Label.new(); l.text = msg; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size",13); l.add_theme_color_override("font_color",_theme_text3()); return l

# ── Student stat helpers ───────────────────────────────────────────────────────
func _total_stars(u: Dictionary) -> int:
	var t := 0
	for v in (u.get("progress",{}) as Dictionary).values():
		t += (v as Dictionary).get("stars",0) as int
	return t

func _avg_acc(u: Dictionary) -> float:
	var accs: Array = []
	for v in (u.get("progress",{}) as Dictionary).values():
		var a: float = (v as Dictionary).get("accuracy",0.0) as float
		if a > 0.0: accs.append(a)
	if accs.is_empty():
		return 0.0
	var s := 0.0
	for a in accs: s += a as float
	return s / accs.size()

func _chap_done(u: Dictionary) -> int:
	var n := 0
	for v in (u.get("progress",{}) as Dictionary).values():
		if (v as Dictionary).get("complete",false) as bool: n += 1
	return n

func _is_struggling(u: Dictionary) -> bool:
	var acc := _avg_acc(u); return acc > 0.0 and acc < 60.0

# =============================================================================
#  DASHBOARD — TAB 0: OVERVIEW
# =============================================================================
func _dash_build_overview() -> void:
	if _dash_students.is_empty():
		_dash_content_root.add_child(_dash_loading_panel()); return
	var total := _dash_students.size()
	var total_stars := 0; var acc_sum := 0.0; var acc_count := 0; var struggling := 0
	for u in _dash_students:
		total_stars += _total_stars(u); var a := _avg_acc(u)
		if a > 0.0: acc_sum += a; acc_count += 1
		if _is_struggling(u): struggling += 1
	var avg_acc_pct := int(acc_sum / acc_count) if acc_count > 0 else 0

	var cards_hb := HBoxContainer.new(); cards_hb.add_theme_constant_override("separation",12); _dash_content_root.add_child(cards_hb)
	cards_hb.add_child(_dash_stat_card("👥",str(total),"Total Students"))
	cards_hb.add_child(_dash_stat_card("📊",str(avg_acc_pct)+"%","Avg Accuracy"))
	cards_hb.add_child(_dash_stat_card("⭐",str(total_stars),"Stars Collected"))
	cards_hb.add_child(_dash_stat_card("⚠️",str(struggling),"Need Attention"))

	var two_col := HBoxContainer.new(); two_col.add_theme_constant_override("separation",12); _dash_content_root.add_child(two_col)

	var acc_p := _dash_panel(); acc_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; two_col.add_child(acc_p)
	var acc_vb := VBoxContainer.new(); acc_vb.add_theme_constant_override("separation",10); acc_p.add_child(acc_vb)
	acc_vb.add_child(_dash_section_label("CLASS ACCURACY PER CHAPTER"))
	if total == 0: acc_vb.add_child(_dash_empty("No students enrolled yet."))
	else:
		for ch in CH_DATA:
			var chid: int = ch["id"] as int; var accs: Array = []
			for u in _dash_students:
				var a2: float = ((u.get("progress",{}) as Dictionary).get(chid,{}) as Dictionary).get("accuracy",0.0) as float
				if a2 > 0.0: accs.append(a2)
			var a_avg := 0
			if not accs.is_empty():
				var s := 0.0; for a2 in accs: s += a2 as float; a_avg = int(s/accs.size())
			acc_vb.add_child(_dash_bar_row(ch["icon"] as String+" "+ch["name"] as String,float(a_avg),ch["col"] as Color,str(a_avg)+"%" if a_avg > 0 else "—"))

	var str_p := _dash_panel(); str_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; two_col.add_child(str_p)
	var str_vb := VBoxContainer.new(); str_vb.add_theme_constant_override("separation",8); str_p.add_child(str_vb)
	str_vb.add_child(_dash_section_label("STRUGGLING STUDENTS"))
	var sl: Array = []; for u in _dash_students: if _is_struggling(u): sl.append(u)
	if sl.is_empty(): str_vb.add_child(_dash_empty("🎉 No students struggling right now!"))
	else:
		for u in sl.slice(0,5):
			var rpc := PanelContainer.new()
			var rsb := StyleBoxFlat.new(); rsb.bg_color = _theme_bg3(); rsb.set_border_width_all(1)
			rsb.border_color = _theme_border(); rsb.set_corner_radius_all(7); rsb.set_content_margin_all(10)
			rpc.add_theme_stylebox_override("panel",rsb)
			var rhb := HBoxContainer.new(); rhb.add_theme_constant_override("separation",10); rpc.add_child(rhb)
			var nvb := VBoxContainer.new(); nvb.size_flags_horizontal = Control.SIZE_EXPAND_FILL; nvb.add_theme_constant_override("separation",2); rhb.add_child(nvb)
			var nl := Label.new(); nl.text = u.get("username","—") as String; nl.add_theme_font_size_override("font_size",13); nl.add_theme_color_override("font_color",_theme_text()); nvb.add_child(nl)
			var al := Label.new(); al.text = "Avg accuracy: %d%%" % int(_avg_acc(u)); al.add_theme_font_size_override("font_size",11); al.add_theme_color_override("font_color",_theme_red()); nvb.add_child(al)
			str_vb.add_child(rpc)

	var comp_p := _dash_panel(); _dash_content_root.add_child(comp_p)
	var comp_vb := VBoxContainer.new(); comp_vb.add_theme_constant_override("separation",10); comp_p.add_child(comp_vb)
	comp_vb.add_child(_dash_section_label("CHAPTER COMPLETION RATE"))
	if total == 0: comp_vb.add_child(_dash_empty("No students enrolled yet."))
	else:
		for ch in CH_DATA:
			var chid: int = ch["id"] as int; var dn := 0
			for u in _dash_students:
				if ((u.get("progress",{}) as Dictionary).get(chid,{}) as Dictionary).get("complete",false) as bool: dn += 1
			var pct := int((float(dn)/float(total))*100.0)
			comp_vb.add_child(_dash_bar_row(ch["icon"] as String+" "+ch["name"] as String,float(pct),ch["col"] as Color,"%d/%d"%[dn,total]))

# =============================================================================
#  DASHBOARD — TAB 1: STUDENTS  (clickable rows → student detail modal)
# =============================================================================
func _dash_build_students() -> void:
	if _dash_students.is_empty():
		_dash_content_root.add_child(_dash_loading_panel()); return

	var sorted: Array = _dash_students.duplicate()
	sorted.sort_custom(func(a, b):
		return (a.get("stats",{}) as Dictionary).get("total_score",0) as int > \
			   (b.get("stats",{}) as Dictionary).get("total_score",0) as int)

	var table_p := _dash_panel(); _dash_content_root.add_child(table_p)
	var table_vb := VBoxContainer.new(); table_vb.add_theme_constant_override("separation",0); table_p.add_child(table_vb)
	table_vb.add_child(_dash_section_label("STUDENT ROSTER  (%d students)  — click a row for details" % sorted.size()))

	var header_cols := ["#","USERNAME","SCORE","STARS","ACCURACY","CHAPTERS","STATUS"]
	var col_widths   := [44,  200,       100,    130,    100,       100,       150]
	var th := HBoxContainer.new(); th.add_theme_constant_override("separation",0); table_vb.add_child(th)
	for i in header_cols.size():
		th.add_child(_dash_cell(header_cols[i] as String, col_widths[i] as int, _theme_text3(), true))

	var sep_sb := StyleBoxFlat.new(); sep_sb.bg_color = _theme_border()
	var h_sep := HSeparator.new(); h_sep.add_theme_stylebox_override("separator",sep_sb); table_vb.add_child(h_sep)

	for i in sorted.size():
		var u: Dictionary  = sorted[i] as Dictionary
		var st: Dictionary = u.get("stats",{}) as Dictionary
		var score: int  = st.get("total_score",0) as int
		var stars: int  = _total_stars(u)
		var acc:   int  = int(_avg_acc(u))
		var done:  int  = _chap_done(u)
		var status_txt: String; var status_col: Color
		if _is_struggling(u):   status_txt = "⚠ Struggling"; status_col = _theme_red()
		elif done > 0:          status_txt = "✓ Active";     status_col = _theme_green()
		else:                   status_txt = "Not started";  status_col = _theme_text3()
		var acc_col: Color = _theme_green() if acc >= 80 else (_theme_orange() if acc >= 60 else _theme_red())

		# Clickable row container
		var row_btn := Button.new()
		row_btn.flat = true
		row_btn.custom_minimum_size = Vector2(0, 44)
		row_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var row_n_sb := StyleBoxFlat.new()
		row_n_sb.bg_color = _theme_bg3() if i % 2 == 1 else Color(0,0,0,0)
		row_n_sb.set_content_margin_all(0)
		var row_h_sb := StyleBoxFlat.new()
		row_h_sb.bg_color = _theme_purple().darkened(0.6) if not _light_mode else _theme_purple().lightened(0.7)
		row_h_sb.set_content_margin_all(0)
		row_btn.add_theme_stylebox_override("normal",row_n_sb)
		row_btn.add_theme_stylebox_override("hover",row_h_sb)
		row_btn.add_theme_stylebox_override("pressed",row_h_sb)
		var cap_u := u
		row_btn.pressed.connect(func(): _open_student_detail(cap_u))
		table_vb.add_child(row_btn)

		# Cells inside the row
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation",0)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row_btn.add_child(row)
		row.add_child(_dash_cell(str(i+1),                                         44, _theme_text3(),false))
		row.add_child(_dash_cell(u.get("username","—") as String,                200, _theme_text(),  false))
		row.add_child(_dash_cell(str(score),                                       100, _theme_gold(), false))
		row.add_child(_dash_cell("★".repeat(stars)+"☆".repeat(max(0,15-stars)),  130, _theme_gold(), false))
		row.add_child(_dash_cell(str(acc)+"%" if acc > 0 else "—",               100, acc_col,        false))
		row.add_child(_dash_cell("%d / 5" % done,                                 100, _theme_text2(),false))
		row.add_child(_dash_cell(status_txt,                                       150, status_col,    false))

		var row_sep := HSeparator.new(); row_sep.add_theme_stylebox_override("separator",sep_sb); table_vb.add_child(row_sep)

# =============================================================================
#  STUDENT DETAIL MODAL  (opened from Students tab)
# =============================================================================
func _build_student_detail_modal() -> void:
	_student_detail_layer = CanvasLayer.new()
	_student_detail_layer.layer = 50; _student_detail_layer.visible = false
	add_child(_student_detail_layer)
	var dim := ColorRect.new(); dim.color = Color(0,0,0,0.75)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed:
			_close_student_detail())
	_student_detail_layer.add_child(dim)

func _open_student_detail(u: Dictionary) -> void:
	# Clear previous content
	for child in _student_detail_layer.get_children():
		if child is PanelContainer: child.queue_free()

	_student_detail_visible = true
	_student_detail_layer.visible = true

	var pr: Dictionary = u.get("progress",{}) as Dictionary
	var st: Dictionary = u.get("stats",{}) as Dictionary
	var uname: String  = u.get("username","—") as String

	var win := PanelContainer.new()
	win.set_anchors_preset(Control.PRESET_CENTER)
	win.custom_minimum_size = Vector2(680, 0)
	win.offset_left = -340; win.offset_right  = 340
	win.offset_top  = -320; win.offset_bottom = 320
	var win_sb := StyleBoxFlat.new(); win_sb.bg_color = _theme_bg2()
	win_sb.set_border_width_all(1); win_sb.border_color = _theme_purple()
	win_sb.set_corner_radius_all(14); win_sb.set_content_margin_all(0)
	win.add_theme_stylebox_override("panel",win_sb)
	win.gui_input.connect(func(ev: InputEvent): get_viewport().set_input_as_handled())
	_student_detail_layer.add_child(win)

	var outer := VBoxContainer.new(); outer.add_theme_constant_override("separation",0); win.add_child(outer)

	# Header
	var hdr := PanelContainer.new()
	var hdr_sb := StyleBoxFlat.new(); hdr_sb.bg_color = _theme_bg3()
	hdr_sb.border_width_bottom = 1; hdr_sb.border_color = _theme_border(); hdr_sb.set_content_margin_all(0)
	hdr.add_theme_stylebox_override("panel",hdr_sb); outer.add_child(hdr)
	var hdr_hb := HBoxContainer.new(); hdr_hb.add_theme_constant_override("separation",0); hdr.add_child(hdr_hb)
	var hm := MarginContainer.new(); hm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hm.add_theme_constant_override("margin_left",20); hm.add_theme_constant_override("margin_top",14)
	hm.add_theme_constant_override("margin_bottom",14); hdr_hb.add_child(hm)
	var hvb := VBoxContainer.new(); hvb.add_theme_constant_override("separation",2); hm.add_child(hvb)
	var ht := Label.new(); ht.text = "👤  %s" % uname
	if _pixel_font: ht.add_theme_font_override("font",_pixel_font)
	ht.add_theme_font_size_override("font_size",13); ht.add_theme_color_override("font_color",_theme_purple()); hvb.add_child(ht)
	var hs := Label.new(); hs.text = "%s  ·  Section: %s" % [u.get("course","—") as String, u.get("section","—") as String]
	hs.add_theme_font_size_override("font_size",11); hs.add_theme_color_override("font_color",_theme_text2()); hvb.add_child(hs)
	var back_m := MarginContainer.new()
	back_m.add_theme_constant_override("margin_right",14); back_m.add_theme_constant_override("margin_top",12)
	hdr_hb.add_child(back_m)
	var back_btn := Button.new(); back_btn.text = "← Back"
	if _pixel_font: back_btn.add_theme_font_override("font",_pixel_font)
	back_btn.add_theme_font_size_override("font_size",10)
	back_btn.add_theme_color_override("font_color",_theme_text2())
	back_btn.add_theme_color_override("font_hover_color",_theme_purple())
	var bsb := StyleBoxFlat.new(); bsb.bg_color = Color(0,0,0,0); bsb.set_border_width_all(1)
	bsb.border_color = _theme_border(); bsb.set_corner_radius_all(6); bsb.set_content_margin_all(8)
	back_btn.add_theme_stylebox_override("normal",bsb)
	back_btn.pressed.connect(_close_student_detail); back_m.add_child(back_btn)

	# ── Mini tab bar ──────────────────────────────────────────────────────────
	var mtb_bg := PanelContainer.new()
	var mtb_sb := StyleBoxFlat.new(); mtb_sb.bg_color = _theme_bg3()
	mtb_sb.border_width_bottom = 1; mtb_sb.border_color = _theme_border(); mtb_sb.set_content_margin_all(0)
	mtb_bg.add_theme_stylebox_override("panel",mtb_sb); outer.add_child(mtb_bg)
	var mtb_hb := HBoxContainer.new(); mtb_hb.add_theme_constant_override("separation",0); mtb_bg.add_child(mtb_hb)
	var mtb_m := MarginContainer.new()
	mtb_m.add_theme_constant_override("margin_left",16); mtb_m.add_theme_constant_override("margin_top",0)
	mtb_m.add_theme_constant_override("margin_bottom",0); mtb_hb.add_child(mtb_m)
	var mtb_inner := HBoxContainer.new(); mtb_inner.add_theme_constant_override("separation",4); mtb_m.add_child(mtb_inner)

	# Scrollable body — single scroll container, two VBoxes switched by tabs
	var scroll := ScrollContainer.new(); scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; outer.add_child(scroll)
	var body_m := MarginContainer.new(); body_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_m.add_theme_constant_override("margin_left",22); body_m.add_theme_constant_override("margin_right",22)
	body_m.add_theme_constant_override("margin_top",16); body_m.add_theme_constant_override("margin_bottom",22)
	scroll.add_child(body_m)
	var body_wrap := VBoxContainer.new(); body_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_wrap.add_theme_constant_override("separation",0); body_m.add_child(body_wrap)

	var summary_root := VBoxContainer.new(); summary_root.add_theme_constant_override("separation",12)
	summary_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL; body_wrap.add_child(summary_root)
	var tier_root := VBoxContainer.new(); tier_root.add_theme_constant_override("separation",12)
	tier_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL; tier_root.visible = false; body_wrap.add_child(tier_root)

	# ── SUMMARY TAB CONTENT ────────────────────────────────────────────────────
	var tot_stars := _total_stars(u); var tot_done := _chap_done(u); var avg_a := int(_avg_acc(u))
	var cards_hb := HBoxContainer.new(); cards_hb.add_theme_constant_override("separation",10); summary_root.add_child(cards_hb)
	for cd in [["🏆",str(st.get("total_score",0) as int),"Score"],["⭐","%d/15"%tot_stars,"Stars"],
			   ["✅","%d/5"%tot_done,"Chapters"],["🎯",str(avg_a)+"%","Avg Acc"]]:
		var c := _dash_stat_card(cd[0] as String,cd[1] as String,cd[2] as String)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; cards_hb.add_child(c)

	summary_root.add_child(_dash_section_label("CHAPTER OVERVIEW  —  click to expand tier detail"))
	for ch in CH_DATA:
		var chid: int = ch["id"] as int
		var ch_stars_t: int = 0; var ch_best: int = 0; var ch_done_c: int = 0
		var ch_acc_s := 0.0; var ch_acc_n := 0
		for t in range(5):
			var pt: Dictionary = pr.get(chid+t,{}) as Dictionary
			ch_stars_t += pt.get("stars",0) as int
			ch_best = max(ch_best,pt.get("best_score",0) as int)
			if pt.get("complete",false) as bool: ch_done_c += 1
			var pa: float = pt.get("accuracy",0.0) as float
			if pa > 0.0: ch_acc_s += pa; ch_acc_n += 1
		var ch_avg: int = int(ch_acc_s/ch_acc_n) if ch_acc_n > 0 else 0
		var ac_c: Color = _theme_green() if ch_avg>=80 else (_theme_orange() if ch_avg>=60 else (_theme_red() if ch_avg>0 else _theme_text3()))

		# ── Clickable chapter header button ───────────────────────────────────
		var ch_toggle := Button.new()
		ch_toggle.custom_minimum_size = Vector2(0, 52)
		ch_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch_toggle.focus_mode = Control.FOCUS_NONE
		var ct_n := StyleBoxFlat.new(); ct_n.bg_color = _theme_bg3()
		ct_n.set_border_width_all(1)
		ct_n.border_color = (ch["col"] as Color) if ch_done_c == 5 else _theme_border()
		if ch_done_c == 5: ct_n.border_width_left = 3
		ct_n.set_corner_radius_all(8); ct_n.set_content_margin_all(0)
		var ct_h := ct_n.duplicate() as StyleBoxFlat
		ct_h.bg_color = _theme_bg3().lightened(0.06) if not _light_mode else _theme_bg3().darkened(0.04)
		ch_toggle.add_theme_stylebox_override("normal", ct_n)
		ch_toggle.add_theme_stylebox_override("hover",  ct_h)
		ch_toggle.add_theme_stylebox_override("pressed",ct_h)

		# Content inside the button — use IGNORE so clicks pass through to Button
		var ct_m := MarginContainer.new()
		ct_m.set_anchors_preset(Control.PRESET_FULL_RECT)
		ct_m.add_theme_constant_override("margin_left",  12)
		ct_m.add_theme_constant_override("margin_right", 12)
		ct_m.add_theme_constant_override("margin_top",   10)
		ct_m.add_theme_constant_override("margin_bottom",10)
		ct_m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ch_toggle.add_child(ct_m)

		var ct_hb := HBoxContainer.new()
		ct_hb.add_theme_constant_override("separation", 10)
		ct_hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ct_m.add_child(ct_hb)

		var ic_l := Label.new(); ic_l.text = ch["icon"] as String
		ic_l.add_theme_font_size_override("font_size", 20)
		ic_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; ct_hb.add_child(ic_l)

		var if_v := VBoxContainer.new(); if_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if_v.add_theme_constant_override("separation", 2)
		if_v.mouse_filter = Control.MOUSE_FILTER_IGNORE; ct_hb.add_child(if_v)

		var nm_l := Label.new(); nm_l.text = ch["name"] as String
		if _pixel_font: nm_l.add_theme_font_override("font",_pixel_font)
		nm_l.add_theme_font_size_override("font_size", 12)
		nm_l.add_theme_color_override("font_color", _theme_text())
		nm_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; if_v.add_child(nm_l)

		var ds_l := Label.new(); ds_l.text = ch["dsa"] as String
		ds_l.add_theme_font_size_override("font_size", 10)
		ds_l.add_theme_color_override("font_color", _theme_text2())
		ds_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; if_v.add_child(ds_l)

		var pg_l := Label.new(); pg_l.text = "%d/5 tiers complete" % ch_done_c
		pg_l.add_theme_font_size_override("font_size", 10)
		pg_l.add_theme_color_override("font_color", _theme_green() if ch_done_c==5 else _theme_text2())
		pg_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; if_v.add_child(pg_l)

		var rv := VBoxContainer.new(); rv.add_theme_constant_override("separation",2)
		rv.mouse_filter = Control.MOUSE_FILTER_IGNORE; ct_hb.add_child(rv)

		var sl := Label.new(); sl.text = "★".repeat(min(ch_stars_t,15))+"☆".repeat(max(0,15-ch_stars_t))
		sl.add_theme_font_size_override("font_size", 9)
		sl.add_theme_color_override("font_color", _theme_gold())
		sl.mouse_filter = Control.MOUSE_FILTER_IGNORE; rv.add_child(sl)

		if ch_best > 0:
			var sc_l := Label.new(); sc_l.text = "Best: %d" % ch_best
			if _pixel_font: sc_l.add_theme_font_override("font",_pixel_font)
			sc_l.add_theme_font_size_override("font_size", 8)
			sc_l.add_theme_color_override("font_color", _theme_text2())
			sc_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; rv.add_child(sc_l)

		if ch_avg > 0:
			var ac_l := Label.new(); ac_l.text = "%d%% avg" % ch_avg
			ac_l.add_theme_font_size_override("font_size", 10)
			ac_l.add_theme_color_override("font_color", ac_c)
			ac_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; rv.add_child(ac_l)

		# Arrow indicator
		var arr_l := Label.new(); arr_l.text = "▼"
		arr_l.add_theme_font_size_override("font_size", 10)
		arr_l.add_theme_color_override("font_color", _theme_text3())
		arr_l.mouse_filter = Control.MOUSE_FILTER_IGNORE; ct_hb.add_child(arr_l)

		summary_root.add_child(ch_toggle)

		# ── Inline tier detail rows (hidden until toggled) ────────────────────
		var tier_expand := VBoxContainer.new()
		tier_expand.add_theme_constant_override("separation", 4)
		tier_expand.visible = false
		summary_root.add_child(tier_expand)

		for t in range(5):
			var tid: int = chid + t
			var pt: Dictionary = pr.get(tid,{}) as Dictionary
			var t_done:  bool  = pt.get("complete",false) as bool
			var t_stars: int   = pt.get("stars",0) as int
			var t_score: int   = pt.get("best_score",0) as int
			var t_acc:   float = pt.get("accuracy",0.0) as float
			var mk: Dictionary = pt.get("mistakes",{}) as Dictionary
			var t_prev: bool   = t==0 or (pr.get(tid-1,{}) as Dictionary).get("complete",false) as bool
			var t_un:   bool   = t_prev or t_done

			var tpc := PanelContainer.new()
			var tsb := StyleBoxFlat.new()
			tsb.bg_color = Color(_theme_bg3().r, _theme_bg3().g, _theme_bg3().b, 0.7)
			tsb.set_border_width_all(1)
			tsb.border_color = (ch["col"] as Color).darkened(0.2) if t_done else _theme_border()
			if t_done: tsb.border_width_left = 2
			tsb.set_corner_radius_all(6); tsb.set_content_margin_all(12)
			tpc.add_theme_stylebox_override("panel", tsb)

			var thb := HBoxContainer.new(); thb.add_theme_constant_override("separation",10); tpc.add_child(thb)

			# Tier badge
			var bdg := PanelContainer.new()
			var bdg_sb := StyleBoxFlat.new()
			bdg_sb.bg_color = (ch["col"] as Color).darkened(0.45) if t_un else _theme_bg3()
			bdg_sb.set_corner_radius_all(5); bdg_sb.set_content_margin_all(6)
			bdg.add_theme_stylebox_override("panel", bdg_sb); bdg.custom_minimum_size = Vector2(60,0)
			var bdg_l := Label.new()
			bdg_l.text = TIER_LABELS[t] if t < TIER_LABELS.size() else "T%d"%(t+1)
			if _pixel_font: bdg_l.add_theme_font_override("font",_pixel_font)
			bdg_l.add_theme_font_size_override("font_size", 7)
			bdg_l.add_theme_color_override("font_color", ch["col"] as Color if t_un else _theme_text3())
			bdg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			bdg.add_child(bdg_l); thb.add_child(bdg)

			# Status
			var st_l := Label.new()
			if not t_un:   st_l.text = "🔒"
			elif t_done:   st_l.text = "✅"
			else:          st_l.text = "▶"
			st_l.add_theme_font_size_override("font_size", 16); thb.add_child(st_l)

			# Info
			var ti_v := VBoxContainer.new(); ti_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ti_v.add_theme_constant_override("separation", 2); thb.add_child(ti_v)

			if t_score > 0:
				var sc2 := Label.new(); sc2.text = "Score: %d pts" % t_score
				if _pixel_font: sc2.add_theme_font_override("font",_pixel_font)
				sc2.add_theme_font_size_override("font_size", 9)
				sc2.add_theme_color_override("font_color", _theme_gold()); ti_v.add_child(sc2)
			if t_acc > 0.0:
				var ac2: int = int(t_acc)
				var ac2c: Color = _theme_green() if ac2>=80 else (_theme_orange() if ac2>=60 else _theme_red())
				var al2 := Label.new(); al2.text = "Accuracy: %d%%" % ac2
				al2.add_theme_font_size_override("font_size", 10)
				al2.add_theme_color_override("font_color", ac2c); ti_v.add_child(al2)

			# Mistakes
			var mk_keys := ["fifo_violation","wrong_pop","overflow","service_miss","lane_miss"]
			var mk_lbls := {"fifo_violation":"FIFO Violations","wrong_pop":"Wrong Pops","overflow":"Overflows",
							"service_miss":"Service Misses","lane_miss":"Lane Misses"}
			for mk_k in mk_keys:
				var mv: int = mk.get(mk_k, 0) as int
				if mv > 0:
					var ml := Label.new(); ml.text = "%s: %d" % [mk_lbls[mk_k] as String, mv]
					ml.add_theme_font_size_override("font_size", 9)
					ml.add_theme_color_override("font_color", _theme_red() if mv>5 else _theme_orange())
					ti_v.add_child(ml)

			if not t_un:
				var lk := Label.new(); lk.text = "Complete previous tier first"
				lk.add_theme_font_size_override("font_size", 9)
				lk.add_theme_color_override("font_color", _theme_text3()); ti_v.add_child(lk)
			elif not t_done and t_score == 0:
				var nd := Label.new(); nd.text = "Not attempted yet"
				nd.add_theme_font_size_override("font_size", 9)
				nd.add_theme_color_override("font_color", _theme_text3()); ti_v.add_child(nd)

			# Stars
			var ts := Label.new(); ts.text = "★".repeat(t_stars)+"☆".repeat(3-t_stars)
			ts.add_theme_font_size_override("font_size", 14)
			ts.add_theme_color_override("font_color", _theme_gold()); thb.add_child(ts)

			tier_expand.add_child(tpc)

		# Wire toggle
		var cap_te := tier_expand; var cap_al := arr_l
		ch_toggle.pressed.connect(func():
			cap_te.visible = not cap_te.visible
			cap_al.text = "▲" if cap_te.visible else "▼")

	# ── TIER DETAIL TAB CONTENT ────────────────────────────────────────────────
	tier_root.add_child(_dash_section_label("TIER-BY-TIER BREAKDOWN  —  click chapter to expand"))
	for ch in CH_DATA:
		var chid: int = ch["id"] as int
		# Chapter toggle button
		var ch_btn := Button.new()
		ch_btn.custom_minimum_size = Vector2(0,46); ch_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ch_btn.focus_mode = Control.FOCUS_NONE
		var cbn := StyleBoxFlat.new(); cbn.bg_color = _theme_bg3()
		cbn.set_border_width_all(1); cbn.border_color = ch["col"] as Color; cbn.border_width_left = 3
		cbn.set_corner_radius_all(8); cbn.set_content_margin_all(0)
		var cbh := cbn.duplicate() as StyleBoxFlat
		cbh.bg_color = _theme_bg3().lightened(0.05) if not _light_mode else _theme_bg3().darkened(0.04)
		ch_btn.add_theme_stylebox_override("normal",cbn); ch_btn.add_theme_stylebox_override("hover",cbh)
		ch_btn.add_theme_stylebox_override("pressed",cbh)
		var cbm := MarginContainer.new(); cbm.set_anchors_preset(Control.PRESET_FULL_RECT)
		cbm.add_theme_constant_override("margin_left",14); cbm.add_theme_constant_override("margin_right",14)
		cbm.add_theme_constant_override("margin_top",10); cbm.add_theme_constant_override("margin_bottom",10)
		cbm.mouse_filter = Control.MOUSE_FILTER_IGNORE; ch_btn.add_child(cbm)
		var cbhb := HBoxContainer.new(); cbhb.add_theme_constant_override("separation",10)
		cbhb.mouse_filter = Control.MOUSE_FILTER_IGNORE; cbm.add_child(cbhb)
		var ic3 := Label.new(); ic3.text = ch["icon"] as String
		ic3.add_theme_font_size_override("font_size",22); ic3.mouse_filter = Control.MOUSE_FILTER_IGNORE; cbhb.add_child(ic3)
		var if3 := VBoxContainer.new(); if3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if3.add_theme_constant_override("separation",1); if3.mouse_filter = Control.MOUSE_FILTER_IGNORE; cbhb.add_child(if3)
		var n3 := Label.new(); n3.text = ch["name"] as String
		if _pixel_font: n3.add_theme_font_override("font",_pixel_font)
		n3.add_theme_font_size_override("font_size",12); n3.add_theme_color_override("font_color",_theme_text())
		n3.mouse_filter = Control.MOUSE_FILTER_IGNORE; if3.add_child(n3)
		var d3 := Label.new(); d3.text = ch["dsa"] as String
		d3.add_theme_font_size_override("font_size",10); d3.add_theme_color_override("font_color",_theme_text2())
		d3.mouse_filter = Control.MOUSE_FILTER_IGNORE; if3.add_child(d3)
		var ar3 := Label.new(); ar3.text = "▼"
		ar3.add_theme_font_size_override("font_size",10); ar3.add_theme_color_override("font_color",_theme_text3())
		ar3.mouse_filter = Control.MOUSE_FILTER_IGNORE; cbhb.add_child(ar3)
		tier_root.add_child(ch_btn)

		var tier_vc := VBoxContainer.new(); tier_vc.add_theme_constant_override("separation",4)
		tier_vc.visible = false; tier_root.add_child(tier_vc)

		for t in range(5):
			var tid: int = chid + t
			var pt: Dictionary = pr.get(tid,{}) as Dictionary
			var t_done:  bool  = pt.get("complete",false) as bool
			var t_stars: int   = pt.get("stars",0) as int
			var t_score: int   = pt.get("best_score",0) as int
			var t_acc:   float = pt.get("accuracy",0.0) as float
			var mk: Dictionary = pt.get("mistakes",{}) as Dictionary
			var t_prev: bool   = t==0 or (pr.get(tid-1,{}) as Dictionary).get("complete",false) as bool
			var t_un:   bool   = t_prev or t_done

			var tpc := PanelContainer.new()
			var tsb := StyleBoxFlat.new(); tsb.bg_color = Color(_theme_bg3().r,_theme_bg3().g,_theme_bg3().b,0.7)
			tsb.set_border_width_all(1)
			tsb.border_color = (ch["col"] as Color).darkened(0.2) if t_done else _theme_border()
			if t_done: tsb.border_width_left = 2
			tsb.set_corner_radius_all(6); tsb.set_content_margin_all(12)
			tpc.add_theme_stylebox_override("panel",tsb)
			var thb := HBoxContainer.new(); thb.add_theme_constant_override("separation",10); tpc.add_child(thb)

			var bdg_pc := PanelContainer.new()
			var bdg_sb := StyleBoxFlat.new()
			bdg_sb.bg_color = (ch["col"] as Color).darkened(0.45) if t_un else _theme_bg3()
			bdg_sb.set_corner_radius_all(5); bdg_sb.set_content_margin_all(6)
			bdg_pc.add_theme_stylebox_override("panel",bdg_sb); bdg_pc.custom_minimum_size = Vector2(60,0)
			var bdg_l := Label.new(); bdg_l.text = TIER_LABELS[t] if t < TIER_LABELS.size() else "T%d"%(t+1)
			if _pixel_font: bdg_l.add_theme_font_override("font",_pixel_font)
			bdg_l.add_theme_font_size_override("font_size",7)
			bdg_l.add_theme_color_override("font_color",ch["col"] as Color if t_un else _theme_text3())
			bdg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; bdg_pc.add_child(bdg_l); thb.add_child(bdg_pc)

			var st_l := Label.new()
			if not t_un: st_l.text = "🔒"
			elif t_done: st_l.text = "✅"
			else:        st_l.text = "▶"
			st_l.add_theme_font_size_override("font_size",16); thb.add_child(st_l)

			var ti_v := VBoxContainer.new(); ti_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ti_v.add_theme_constant_override("separation",2); thb.add_child(ti_v)

			if t_score > 0:
				var sc4 := Label.new(); sc4.text = "Score: %d pts" % t_score
				if _pixel_font: sc4.add_theme_font_override("font",_pixel_font)
				sc4.add_theme_font_size_override("font_size",9); sc4.add_theme_color_override("font_color",_theme_gold()); ti_v.add_child(sc4)
			if t_acc > 0.0:
				var ac4: int = int(t_acc)
				var ac4c: Color = _theme_green() if ac4>=80 else (_theme_orange() if ac4>=60 else _theme_red())
				var al4 := Label.new(); al4.text = "Accuracy: %d%%" % ac4
				al4.add_theme_font_size_override("font_size",10); al4.add_theme_color_override("font_color",ac4c); ti_v.add_child(al4)

			var mk_keys := ["fifo_violation","wrong_pop","overflow","service_miss","lane_miss"]
			var mk_lbls := {"fifo_violation":"FIFO Violations","wrong_pop":"Wrong Pops","overflow":"Overflows",
							"service_miss":"Service Misses","lane_miss":"Lane Misses"}
			var any_mk := false
			for mk_k in mk_keys:
				var mv: int = mk.get(mk_k,0) as int
				if mv > 0:
					any_mk = true
					var ml := Label.new(); ml.text = "%s: %d" % [mk_lbls[mk_k] as String, mv]
					ml.add_theme_font_size_override("font_size",9)
					ml.add_theme_color_override("font_color",_theme_red() if mv>5 else _theme_orange()); ti_v.add_child(ml)
			if not t_un:
				var lk4 := Label.new(); lk4.text = "Complete previous tier first"
				lk4.add_theme_font_size_override("font_size",9); lk4.add_theme_color_override("font_color",_theme_text3()); ti_v.add_child(lk4)
			elif not t_done and t_score == 0:
				var nd4 := Label.new(); nd4.text = "Not attempted yet"
				nd4.add_theme_font_size_override("font_size",9); nd4.add_theme_color_override("font_color",_theme_text3()); ti_v.add_child(nd4)

			var ts4 := Label.new(); ts4.text = "★".repeat(t_stars)+"☆".repeat(3-t_stars)
			ts4.add_theme_font_size_override("font_size",14); ts4.add_theme_color_override("font_color",_theme_gold()); thb.add_child(ts4)
			tier_vc.add_child(tpc)

		var cap_vc := tier_vc; var cap_ar := ar3
		ch_btn.pressed.connect(func():
			cap_vc.visible = not cap_vc.visible
			cap_ar.text = "▲" if cap_vc.visible else "▼")

	# ── Wire mini tabs ─────────────────────────────────────────────────────────
	var tab_labels := ["📊  Summary", "📖  Tier Detail"]
	var tab_roots  : Array = [summary_root, tier_root]
	var tab_btns   : Array = []

	for i in tab_labels.size():
		var tb := Button.new(); tb.text = tab_labels[i] as String
		if _pixel_font: tb.add_theme_font_override("font",_pixel_font)
		tb.add_theme_font_size_override("font_size",9); tb.custom_minimum_size = Vector2(130,38)
		tb.focus_mode = Control.FOCUS_NONE
		var tb_n := StyleBoxFlat.new(); tb_n.bg_color = Color(0,0,0,0)
		tb_n.border_width_bottom = 3; tb_n.border_color = Color(0,0,0,0); tb_n.set_content_margin_all(8)
		tb.add_theme_stylebox_override("normal",tb_n); tb.add_theme_stylebox_override("hover",tb_n)
		tb.add_theme_stylebox_override("pressed",tb_n); tb.add_theme_color_override("font_color",_theme_text3())
		mtb_inner.add_child(tb); tab_btns.append(tb)

	var _switch_tab := func(idx: int) -> void:
		for j in tab_btns.size():
			var tb2: Button = tab_btns[j] as Button
			var asb := StyleBoxFlat.new(); asb.bg_color = Color(0,0,0,0)
			asb.border_width_bottom = 3; asb.set_content_margin_all(8)
			asb.border_color = _theme_purple() if j==idx else Color(0,0,0,0)
			tb2.add_theme_stylebox_override("normal",asb)
			tb2.add_theme_color_override("font_color",_theme_purple() if j==idx else _theme_text3())
			(tab_roots[j] as Control).visible = (j==idx)

	for i in tab_btns.size():
		var cap_i := i
		(tab_btns[i] as Button).pressed.connect(func(): _switch_tab.call(cap_i))

	_switch_tab.call(0)   # start on Summary

func _close_student_detail() -> void:
	_student_detail_visible = false
	if is_instance_valid(_student_detail_layer): _student_detail_layer.visible = false

# =============================================================================
#  DASHBOARD — TAB 2: CLASS PROGRESS
# =============================================================================
func _dash_build_class_progress() -> void:
	if _dash_students.is_empty():
		_dash_content_root.add_child(_dash_loading_panel()); return
	var total := _dash_students.size()
	var two_col := HBoxContainer.new(); two_col.add_theme_constant_override("separation",12); _dash_content_root.add_child(two_col)

	var comp_p := _dash_panel(); comp_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; two_col.add_child(comp_p)
	var comp_vb := VBoxContainer.new(); comp_vb.add_theme_constant_override("separation",10); comp_p.add_child(comp_vb)
	comp_vb.add_child(_dash_section_label("CHAPTER COMPLETION"))
	if total == 0: comp_vb.add_child(_dash_empty("No students yet."))
	else:
		for ch in CH_DATA:
			var chid: int = ch["id"] as int; var dn := 0
			for u in _dash_students:
				if ((u.get("progress",{}) as Dictionary).get(chid,{}) as Dictionary).get("complete",false) as bool: dn += 1
			var pct := int((float(dn)/float(total))*100.0)
			comp_vb.add_child(_dash_bar_row(ch["icon"] as String+" "+ch["name"] as String,float(pct),ch["col"] as Color,"%d/%d"%[dn,total]))

	var acc_p := _dash_panel(); acc_p.size_flags_horizontal = Control.SIZE_EXPAND_FILL; two_col.add_child(acc_p)
	var acc_vb := VBoxContainer.new(); acc_vb.add_theme_constant_override("separation",10); acc_p.add_child(acc_vb)
	acc_vb.add_child(_dash_section_label("AVERAGE ACCURACY"))
	if total == 0: acc_vb.add_child(_dash_empty("No students yet."))
	else:
		for ch in CH_DATA:
			var chid: int = ch["id"] as int; var accs: Array = []
			for u in _dash_students:
				var a2: float = ((u.get("progress",{}) as Dictionary).get(chid,{}) as Dictionary).get("accuracy",0.0) as float
				if a2 > 0.0: accs.append(a2)
			var a_avg := 0
			if not accs.is_empty():
				var s := 0.0; for a2 in accs: s += a2 as float; a_avg = int(s/accs.size())
			acc_vb.add_child(_dash_bar_row(ch["icon"] as String+" "+ch["name"] as String,float(a_avg),ch["col"] as Color,str(a_avg)+"%" if a_avg>0 else "—"))

	var mk_p := _dash_panel(); _dash_content_root.add_child(mk_p)
	var mk_vb := VBoxContainer.new(); mk_vb.add_theme_constant_override("separation",8); mk_p.add_child(mk_vb)
	mk_vb.add_child(_dash_section_label("COMMON MISTAKES ACROSS CLASS"))
	var mkeys  := ["fifo_violation","wrong_pop","overflow","service_miss","lane_miss"]
	var mlbls  := {"fifo_violation":"FIFO Violations","wrong_pop":"Wrong Pops","overflow":"Overflows","service_miss":"Service Misses","lane_miss":"Lane Misses"}
	var totals: Dictionary = {}; for k in mkeys: totals[k] = 0
	for u in _dash_students:
		for p in (u.get("progress",{}) as Dictionary).values():
			var mk := (p as Dictionary).get("mistakes",{}) as Dictionary
			for k in mkeys: totals[k] = (totals[k] as int)+(mk.get(k,0) as int)
	for k in mkeys:
		var v: int = totals[k] as int; var vc: Color = _theme_red() if v > 20 else (_theme_orange() if v > 8 else _theme_green())
		var rhb := HBoxContainer.new(); rhb.add_theme_constant_override("separation",12); mk_vb.add_child(rhb)
		var ml := Label.new(); ml.text = mlbls[k] as String; ml.custom_minimum_size = Vector2(180,0)
		ml.add_theme_font_size_override("font_size",12); ml.add_theme_color_override("font_color",_theme_text2()); rhb.add_child(ml)
		var vl := Label.new(); vl.text = str(v)+" total"
		if _pixel_font: vl.add_theme_font_override("font",_pixel_font)
		vl.add_theme_font_size_override("font_size",9); vl.add_theme_color_override("font_color",vc); rhb.add_child(vl)

# =============================================================================
#  UNLOCK / HOVER / CLICK / WALK / DRAW
# =============================================================================
func _is_unlocked(chapter_id: int) -> bool:
	if chapter_id == 1: return true
	if has_node("/root/PlayerProfile"): return PlayerProfile.is_chapter_unlocked(chapter_id)
	# Fallback (no PlayerProfile): check if previous level is completed
	var prev: Dictionary = (_map_data.get(chapter_id-1,{}) as Dictionary)
	var done: bool = prev.get("completed",false) as bool
	if not done: done = prev.get("complete",false) as bool
	return done

func _hover(cid: int, pos: Vector2) -> void:
	if _dash_visible or _profile_visible or _settings_visible: return
	_hover_id = cid
	var ch: Dictionary = CHAPTERS.filter(func(c): return c["id"] == cid)[0]
	var tiers:    int  = ch.get("tiers",1) as int
	var done_c := 0
	var all_done: bool = true
	for t in range(tiers):
		var ld: Dictionary = (_map_data.get(cid+t,{}) as Dictionary)
		var lc: bool = ld.get("completed",false) as bool
		if not lc: lc = ld.get("complete",false) as bool
		if lc: done_c += 1
		else: all_done = false
	var mastered: bool = done_c == tiers and (_map_data.get(cid,{}) as Dictionary).get("mastered",false) as bool
	var status: String
	if not _is_unlocked(cid) and not _is_teacher: status = "🔒 Complete previous chapter first"
	elif mastered: status = "★ Mastered! Click to select difficulty"
	elif all_done: status = "✓ Complete — click to replay"
	else:          status = "▶ Click to select difficulty!"
	if is_instance_valid(_tooltip_bg):
		_tooltip_bg.visible  = true
		_tooltip_bg.position = Vector2(min(pos.x+62,1010), pos.y-22)
		_tooltip_lbl.text    = "%s\nDSA: %s\nProgress: %d/%d levels\n%s" % [
			ch["name"] as String, ch["dsa"] as String, done_c, tiers, status]
	queue_redraw()

func _unhover() -> void:
	_hover_id = -1
	if is_instance_valid(_tooltip_bg): _tooltip_bg.visible = false
	queue_redraw()

func _click(cid: int, unlocked: bool, _pos: Vector2) -> void:
	if _dash_visible or _profile_visible or _settings_visible or _student_detail_visible: return
	if not unlocked and not _is_teacher:
		if has_node("/root/AudioManager"): AudioManager.play_sfx("wrong"); return
	if has_node("/root/AudioManager"): AudioManager.play_sfx("click")
	_close_info_panel()
	var ch: Dictionary = CHAPTERS.filter(func(c): return c["id"] == cid)[0]
	_open_info_panel(ch)

func _walk_avatar_to(target: Vector2, after: Callable) -> void:
	if not is_instance_valid(_avatar): after.call(); return
	if is_instance_valid(_badge_ring):
		var sq := create_tween()
		sq.tween_property(_badge_ring,"scale",Vector2(1.2,0.8),0.12)
		sq.tween_property(_badge_ring,"scale",Vector2(1.0,1.0),0.12)
	var tw := create_tween()
	tw.tween_property(_avatar,"position",target,0.55).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): _avatar_pos = target; after.call())

func _play_enter_animation() -> void:
	# Always start fully visible — the tween fades us in from 0.
	# If AnimationPlayer is unavailable we still ensure the node is visible.
	modulate = Color(1, 1, 1, 0)
	if not is_instance_valid(_anim):
		# No AnimationPlayer — just snap to fully visible.
		modulate = Color(1, 1, 1, 1)
		return
	var anim := Animation.new(); anim.length = 0.7
	var t: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, ".:modulate:a")
	anim.track_insert_key(t, 0.0, 0.0)
	anim.track_insert_key(t, 0.7, 1.0)
	var lib := AnimationLibrary.new()
	lib.add_animation("enter", anim)
	# Remove existing library first to avoid "already exists" errors on re-entry.
	if _anim.has_animation_library(""):
		_anim.remove_animation_library("")
	_anim.add_animation_library("", lib)
	_anim.play("enter")
	# Safety fallback: guarantee visibility after the animation time even if
	# the animation finishes before this callback fires.
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(self):
		modulate = Color(1, 1, 1, 1)

# =============================================================================
#  DRAW
# =============================================================================
func _draw() -> void:
	_draw_background(); _draw_roads(); _update_sprite_tints(); _draw_node_overlays()

func _update_sprite_tints() -> void:
	for ch: Dictionary in CHAPTERS:
		var cid: int = ch["id"] as int; var col: Color = ch["color"] as Color
		var sprite = _sprite_nodes.get(cid,null)
		if sprite != null and is_instance_valid(sprite):
			var nm := _sprite_tint(cid,col)
			if _hover_id == cid and (_is_unlocked(cid) or _is_teacher): nm = nm.lightened(0.15)
			sprite.modulate = nm

func _draw_background() -> void:
	# Sky gradient — lighter in light mode
	var sky_top: Color    = Color("#e8eef8") if _light_mode else Color("#080a14")
	var sky_mid: Color    = Color("#c8d8f0") if _light_mode else Color("#0d1a34")
	var sky_bot: Color    = Color("#b8cce8") if _light_mode else Color("#101e2e")
	var bands := 28
	for i in range(bands):
		var t2 := float(i)/float(bands); var col: Color
		if t2 < 0.65: col = sky_top.lerp(sky_mid, t2/0.65)
		else:         col = sky_mid.lerp(sky_bot, (t2-0.65)/0.35)
		draw_rect(Rect2(0,t2*720.0,1280,720.0/bands+1),col)

	var land1: Color = Color("#d0dcea") if _light_mode else Color("#0d1826")
	var land2: Color = Color("#c4d4e4") if _light_mode else Color("#0b1520")
	var land3: Color = Color("#b8c8dc") if _light_mode else Color("#080c14")
	draw_colored_polygon(PackedVector2Array([Vector2(0,720),Vector2(0,490),Vector2(100,440),Vector2(230,475),
		Vector2(360,415),Vector2(480,460),Vector2(590,400),Vector2(700,435),Vector2(810,395),Vector2(930,440),
		Vector2(1060,405),Vector2(1180,445),Vector2(1280,415),Vector2(1280,720)]),land1)
	draw_colored_polygon(PackedVector2Array([Vector2(0,720),Vector2(0,555),Vector2(70,515),Vector2(170,548),
		Vector2(280,505),Vector2(400,540),Vector2(510,500),Vector2(620,538),Vector2(730,498),Vector2(855,535),
		Vector2(970,498),Vector2(1090,530),Vector2(1200,500),Vector2(1280,520),Vector2(1280,720)]),land2)
	draw_rect(Rect2(0,598,1280,122),land3)
	draw_rect(Rect2(0,598,1280,3), Color(0.25,0.45,0.75,0.3))

	# Stars — hidden in light mode
	if not _light_mode:
		for s: Vector2 in _stars:
			var b := 0.3+fmod(s.x*0.0031+s.y*0.0019,0.65); draw_circle(s,1.0,Color(b,b,b+0.08,b))
		draw_circle(Vector2(1170,105),40,Color("#bdd0e8")); draw_circle(Vector2(1188,95),36,Color("#080a14"))
		draw_arc(Vector2(1170,105),50,0,TAU,32,Color(0.65,0.78,1.0,0.10),10.0)
	else:
		# Sun for light mode
		draw_circle(Vector2(1170,105),38,Color("#ffe066")); draw_arc(Vector2(1170,105),52,0,TAU,32,Color(1.0,0.9,0.2,0.3),6.0)

	for i in range(14):
		var bx := 300.0+i*48.0; var bh := 16.0+fmod(float(i)*8.1,30.0)
		var bc: Color = Color(0.55,0.6,0.7,0.6) if _light_mode else Color(0.12,0.18,0.30,0.75)
		draw_rect(Rect2(bx,598-bh,13,bh),bc)
		if int(fmod(float(i),2.0))==0:
			draw_rect(Rect2(bx+3,601-bh+4,4,3),Color(0.95,0.85,0.2,0.55))
	for i in range(7):
		draw_arc(Vector2(i*200.0+60,612),120,0,PI,16,Color(0.25,0.45,0.75,0.055),20.0)

func _draw_roads() -> void:
	for conn: Array in ROADS:
		var pa: Vector2 = CHAPTERS[conn[0]]["pos"] as Vector2
		var pb: Vector2 = CHAPTERS[conn[1]]["pos"] as Vector2
		# A topic is "done" when its last level (start_id + 4) is completed
		var src_last: Dictionary = (_map_data.get(CHAPTERS[conn[0]]["id"] as int + 4, {}) as Dictionary)
		var done: bool = src_last.get("completed", false) as bool
		if not done: done = src_last.get("complete", false) as bool
		draw_line(pa,pb,Color(0,0,0,0.3),9.0)
		draw_line(pa,pb,Color("#5a7820") if (done and _light_mode) else (Color("#3a2c10") if done else (Color("#8898aa") if _light_mode else Color("#1e1a0c"))),5.0)
		draw_line(pa,pb,Color("#8ab030") if (done and _light_mode) else (Color("#5a4820") if done else (Color("#aabbd0") if _light_mode else Color("#14100a"))),2.0)

func _draw_node_overlays() -> void:
	for ch: Dictionary in CHAPTERS:
		var cid:   int     = ch["id"]    as int
		var pos:   Vector2 = ch["pos"]   as Vector2
		var col:   Color   = ch["color"] as Color
		var d:     Dictionary = _map_data.get(cid,{}) as Dictionary
		var unlocked: bool = _is_unlocked(cid); var vis: bool = unlocked or _is_teacher
		var complete_raw: bool = d.get("completed",false) as bool
		if not complete_raw: complete_raw = d.get("complete",false) as bool
		# Topic "complete" = all 5 levels done
		var complete: bool = false
		var mastered: bool = d.get("mastered",false) as bool
		var topic_stars: int = 0
		for t2 in range(5):
			var ld2: Dictionary = _map_data.get(cid+t2,{}) as Dictionary
			var lvl_c: bool = ld2.get("completed",false) as bool
			if not lvl_c: lvl_c = ld2.get("complete",false) as bool
			if not lvl_c: complete = false
			topic_stars += ld2.get("stars",0) as int
		complete = true  # re-derive below properly
		complete = false
		var all_lvls_done: bool = true
		for t3 in range(5):
			var ld3: Dictionary = _map_data.get(cid+t3,{}) as Dictionary
			var lc: bool = ld3.get("completed",false) as bool
			if not lc: lc = ld3.get("complete",false) as bool
			if not lc: all_lvls_done = false; break
		complete = all_lvls_done
		if topic_stars >= 15: mastered = true
		var hover: bool = _hover_id == cid; var score: int = d.get("best_score",0) as int
		var tiers: int  = ch.get("tiers",1) as int; var has_sprite: bool = _sprite_nodes.get(cid,null) != null

		if not has_sprite:
			draw_circle(pos+Vector2(4,6),50,Color(0,0,0,0.28))
			if hover and vis: draw_circle(pos,60,col*Color(1,1,1,0.18))
			var circ_col: Color = col.darkened(0.45) if vis else Color("#111010")
			if _light_mode and vis: circ_col = col.lightened(0.2)
			draw_circle(pos,48,circ_col)
			draw_string(ThemeDB.fallback_font,pos+Vector2(-14,10),ch.get("icon","?") as String,HORIZONTAL_ALIGNMENT_LEFT,-1,26,col if vis else Color("#22200c"))
		else:
			draw_circle(pos+Vector2(4,6),50,Color(0,0,0,0.28))
			if hover and vis: draw_circle(pos,62,col*Color(1,1,1,0.20))

		var bc: Color
		if mastered:   bc = Color("#FFD93D")
		elif hover:    bc = col.lightened(0.4)
		elif vis:      bc = col
		else:          bc = Color("#2a2612") if not _light_mode else Color("#aab8cc")
		draw_arc(pos,50,0,TAU,48,bc,2.5)
		if vis: draw_arc(pos,42,0,TAU,40,col*Color(1,1,1,0.30),1.0)

		if not vis:
			draw_circle(pos,50,Color(0,0,0,0.45))
			draw_string(ThemeDB.fallback_font,pos+Vector2(-12,8),"🔒",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("#888844"))

		if complete:
			draw_string(ThemeDB.fallback_font,pos+Vector2(-10,-64),"⭐",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("#FFD93D"))
		if mastered:
			draw_string(ThemeDB.fallback_font,pos+Vector2(12,-64),"★",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("#FFD93D"))

		var nm: String = ch["name"] as String
		var nm_col: Color = col if vis else (Color("#444455") if _light_mode else Color("#282410"))
		draw_string(ThemeDB.fallback_font,Vector2(pos.x-nm.length()*3.5,pos.y+94),nm,HORIZONTAL_ALIGNMENT_LEFT,-1,13,nm_col)
		if score > 0:
			var sc := "%d pts" % score
			draw_string(ThemeDB.fallback_font,Vector2(pos.x-sc.length()*3.0,pos.y+110),sc,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("#887838"))

		for t in range(tiers):
			var tdot: Dictionary = (_map_data.get(cid+t,{}) as Dictionary)
			var tdone: bool = tdot.get("completed",false) as bool
			if not tdone: tdone = tdot.get("complete",false) as bool
			var pp: Vector2 = pos+Vector2(-((tiers-1)*9)+t*18,66)
			draw_circle(pp,5.5,col if tdone else (Color("#aabbcc") if _light_mode else Color("#1a1810")))
			draw_arc(pp,5.5,0,TAU,12,col.lightened(0.3) if tdone else (Color("#8898a8") if _light_mode else Color("#2e2c18")),1.5)

func _process(_delta: float) -> void:
	pass
