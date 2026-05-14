# =============================================================================
# AlgoQuest — Character Select
# File: scripts/ui/CharacterSelect.gd
# Attach to: scenes/ui/CharacterSelect.tscn
#
# Shown once after login (first run) or when player taps "Character" on the
# World Map HUD. Saves selection to SaveManager and returns to World Map.
#
# SCENE TREE:
#   CharacterSelect (Node2D)
#   ├── Background        (ColorRect)   fullscreen dark bg
#   ├── TitleLabel        (Label)       "Choose Your Hero  [N / Total]"
#   ├── CategoryRow       (HBoxContainer)  category filter buttons
#   ├── PreviewHolder     (Node2D)      center preview + idle animation
#   │   ├── PreviewSprite (AnimatedSprite2D)
#   │   ├── HeroNameLabel (Label)
#   │   ├── HeroClassLabel(Label)
#   │   └── HeroDescLabel (Label)
#   ├── ArrowLeft         (Button)      "◀"
#   ├── ArrowRight        (Button)      "▶"
#   ├── PortraitRow       (HBoxContainer) thumbnail strip (up to 5 visible)
#   ├── ConfirmBtn        (Button)      "Select Hero →"
#   └── BackBtn           (Button)      "← Back"
# =============================================================================

extends Node2D

const PATH_FONT    := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_OK  := "res://assets/audio/sfx/success.ogg"
const PATH_SFX_BTN := "res://assets/audio/sfx/button.ogg"
const HERO_BASE    := "res://assets/art/character/heroes/"

const ANIM_FRAME_NAMES: Array[String] = ["walk1", "stand", "walk2"]
const IDLE_FPS := 4.0
const WALK_FPS := 6.0

# ─────────────────────────────────────────────────────────────────────────────
#  HERO ROSTER
# ─────────────────────────────────────────────────────────────────────────────
const HEROES: Array[Dictionary] = [
	# Warriors
	{ "key":"m_warrior",    "name":"Warrior",      "class":"♂ Warrior",
	  "category":"warrior", "desc":"Brave frontliner.\nStrong and unyielding." },
	{ "key":"f_warrior",    "name":"Shieldmaiden", "class":"♀ Warrior",
	  "category":"warrior", "desc":"Fierce and disciplined.\nDefends with honour." },
	{ "key":"m_berserker",  "name":"Berserker",    "class":"♂ Berserker",
	  "category":"warrior", "desc":"Reckless fury.\nDeals damage, takes damage." },
	{ "key":"f_berserker",  "name":"Valkyrie",     "class":"♀ Berserker",
	  "category":"warrior", "desc":"Wild and powerful.\nFears nothing." },
	{ "key":"m_dark_knight","name":"Dark Knight",  "class":"♂ Dark Knight",
	  "category":"warrior", "desc":"Master of shadows.\nStrength through darkness." },
	{ "key":"f_dark_knight","name":"Shadow Blade", "class":"♀ Dark Knight",
	  "category":"warrior", "desc":"Swift and deadly.\nStrikes from the dark." },
	# Paladins
	{ "key":"paladin",      "name":"Paladin",      "class":"Paladin",
	  "category":"paladin", "desc":"Holy champion.\nLight in the darkest halls." },
	# Mages
	{ "key":"m_mage",       "name":"Mage",         "class":"♂ Mage",
	  "category":"mage",    "desc":"Scholar of arcane arts.\nLogic is his weapon." },
	{ "key":"f_mage",       "name":"Sorceress",    "class":"♀ Mage",
	  "category":"mage",    "desc":"Commands the elements.\nWisdom over brute force." },
	{ "key":"m_healer",     "name":"Healer",       "class":"♂ Healer",
	  "category":"mage",    "desc":"Restores balance.\nPatient and methodical." },
	{ "key":"f_healer",     "name":"Cleric",       "class":"♀ Healer",
	  "category":"mage",    "desc":"Light in the darkness.\nHeals the wounded." },
	{ "key":"m_monk",       "name":"Monk",         "class":"♂ Monk",
	  "category":"mage",    "desc":"Mind over matter.\nDiscipline is power." },
	{ "key":"f_monk",       "name":"Priestess",    "class":"♀ Monk",
	  "category":"mage",    "desc":"Calm and precise.\nFlow like water." },
	# Ninjas & Rangers
	{ "key":"m_ninja",      "name":"Ninja",        "class":"♂ Ninja",
	  "category":"rogue",   "desc":"Master of stealth.\nFast and invisible." },
	{ "key":"f_ninja",      "name":"Kunoichi",     "class":"♀ Ninja",
	  "category":"rogue",   "desc":"Silent precision.\nStrikes before seen." },
	{ "key":"m_ranger",     "name":"Ranger",       "class":"♂ Ranger",
	  "category":"rogue",   "desc":"Eyes of the forest.\nNever misses a mark." },
	# Samurai
	{ "key":"m_samurai",    "name":"Samurai",      "class":"♂ Samurai",
	  "category":"samurai", "desc":"Code of the blade.\nOrder above all." },
	{ "key":"f_samurai",    "name":"Onna-Bugeisha","class":"♀ Samurai",
	  "category":"samurai", "desc":"Honour and precision.\nThe perfect warrior." },
]

const CATEGORIES: Array[Dictionary] = [
	{ "id":"all",     "label":"All" },
	{ "id":"warrior", "label":"⚔ Warriors" },
	{ "id":"mage",    "label":"🔮 Mages" },
	{ "id":"rogue",   "label":"🗡 Rogues" },
	{ "id":"samurai", "label":"⛩ Samurai" },
	{ "id":"paladin", "label":"🛡 Paladins" },
]

# ─────────────────────────────────────────────────────────────────────────────
#  NODE REFS
# ─────────────────────────────────────────────────────────────────────────────
@onready var _bg:             ColorRect        = $Background
@onready var _title_lbl:      Label            = $TitleLabel
@onready var _preview_holder: Node2D           = $PreviewHolder
@onready var _preview_sprite: AnimatedSprite2D = $PreviewHolder/PreviewSprite
@onready var _hero_name_lbl:  Label            = $PreviewHolder/HeroNameLabel
@onready var _hero_class_lbl: Label            = $PreviewHolder/HeroClassLabel
@onready var _hero_desc_lbl:  Label            = $PreviewHolder/HeroDescLabel
@onready var _arrow_left:     Button           = $ArrowLeft
@onready var _arrow_right:    Button           = $ArrowRight
@onready var _portrait_row:   HBoxContainer    = $PortraitRow
@onready var _category_row:   HBoxContainer    = $CategoryRow
@onready var _confirm_btn:    Button           = $ConfirmBtn
@onready var _back_btn:       Button           = $BackBtn

# ─────────────────────────────────────────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────────────────────────────────────────
var _pixel_font:      Font       = null
var _frames_cache:    Dictionary = {}
var _filtered:        Array      = []   # currently visible hero list
var _current_idx:     int        = 0
var _active_category: String     = "all"
var _nav_direction:   int        = 1    # +1 = right, -1 = left (for tween slide)

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font

	_setup_bg()
	_setup_labels()
	_setup_category_buttons()
	_setup_arrows()
	_setup_confirm()

	_apply_category("all")

	# Pre-select saved hero if exists
	var saved: String = SaveManager.get_selected_hero() if has_node("/root/SaveManager") else ""
	if saved != "":
		for i in range(_filtered.size()):
			if _filtered[i]["key"] == saved:
				_current_idx = i
				break

	_refresh_preview()
	_refresh_portraits()

# ─────────────────────────────────────────────────────────────────────────────
#  KEYBOARD / GAMEPAD INPUT
# ─────────────────────────────────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_on_left()
	elif event.is_action_pressed("ui_right"):
		_on_right()
	elif event.is_action_pressed("ui_accept"):
		_on_confirm()
	elif event.is_action_pressed("ui_cancel"):
		_on_back()

# ─────────────────────────────────────────────────────────────────────────────
#  SETUP HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _setup_bg() -> void:
	_bg.color = Color(0.06, 0.06, 0.12)

func _setup_labels() -> void:
	_title_lbl.text = "Choose Your Hero"
	for lbl: Label in [_title_lbl, _hero_name_lbl, _hero_class_lbl, _hero_desc_lbl]:
		if is_instance_valid(lbl) and _pixel_font:
			lbl.add_theme_font_override("font", _pixel_font)
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_hero_name_lbl.add_theme_font_size_override("font_size", 22)
	_hero_class_lbl.add_theme_font_size_override("font_size", 14)
	_hero_class_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	_hero_desc_lbl.add_theme_font_size_override("font_size", 13)
	_hero_desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))

func _setup_category_buttons() -> void:
	for c in _category_row.get_children(): c.queue_free()
	for cat: Dictionary in CATEGORIES:
		var btn := Button.new()
		btn.text = cat["label"]
		btn.custom_minimum_size = Vector2(110, 36)
		if _pixel_font: btn.add_theme_font_override("font", _pixel_font)
		btn.add_theme_font_size_override("font_size", 13)
		var cat_id: String = cat["id"]
		btn.pressed.connect(func(): _apply_category(cat_id))
		_category_row.add_child(btn)

func _setup_arrows() -> void:
	_arrow_left.text  = "◀"
	_arrow_right.text = "▶"
	_arrow_left.custom_minimum_size  = Vector2(60, 60)
	_arrow_right.custom_minimum_size = Vector2(60, 60)
	if _pixel_font:
		_arrow_left.add_theme_font_override("font", _pixel_font)
		_arrow_right.add_theme_font_override("font", _pixel_font)
	_arrow_left.add_theme_font_size_override("font_size", 22)
	_arrow_right.add_theme_font_size_override("font_size", 22)
	_arrow_left.pressed.connect(_on_left)
	_arrow_right.pressed.connect(_on_right)

func _setup_confirm() -> void:
	_confirm_btn.text = "Select Hero  →"
	_back_btn.text    = "← Back"
	if _pixel_font:
		_confirm_btn.add_theme_font_override("font", _pixel_font)
		_back_btn.add_theme_font_override("font", _pixel_font)
	_confirm_btn.add_theme_font_size_override("font_size", 18)
	_confirm_btn.pressed.connect(_on_confirm)
	_back_btn.pressed.connect(_on_back)

# ─────────────────────────────────────────────────────────────────────────────
#  CATEGORY FILTER
# ─────────────────────────────────────────────────────────────────────────────
func _apply_category(cat_id: String) -> void:
	_active_category = cat_id
	if cat_id == "all":
		_filtered = HEROES.duplicate()
	else:
		_filtered = HEROES.filter(func(h): return h["category"] == cat_id)
	_current_idx   = 0
	_nav_direction = 1
	_refresh_preview()
	_refresh_portraits()

	# Highlight active category button
	var btns := _category_row.get_children()
	for i in range(btns.size()):
		var btn := btns[i] as Button
		var is_active: bool = CATEGORIES[i]["id"] == cat_id
		btn.modulate = Color(1.0, 0.9, 0.3) if is_active else Color(0.7, 0.7, 0.7)

# ─────────────────────────────────────────────────────────────────────────────
#  CAROUSEL NAVIGATION
# ─────────────────────────────────────────────────────────────────────────────
func _on_left() -> void:
	if _filtered.is_empty(): return
	_nav_direction = -1
	_current_idx   = (_current_idx - 1 + _filtered.size()) % _filtered.size()
	_play_sfx(PATH_SFX_BTN)
	_refresh_preview()
	_refresh_portraits()

func _on_right() -> void:
	if _filtered.is_empty(): return
	_nav_direction = 1
	_current_idx   = (_current_idx + 1) % _filtered.size()
	_play_sfx(PATH_SFX_BTN)
	_refresh_preview()
	_refresh_portraits()

# ─────────────────────────────────────────────────────────────────────────────
#  PREVIEW — large animated center sprite
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_preview() -> void:
	if _filtered.is_empty(): return
	var hero: Dictionary = _filtered[_current_idx]

	# Animated sprite — negative X scale mirrors the sprite so it faces forward
	_preview_sprite.sprite_frames  = _make_sprite_frames(hero["key"])
	_preview_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_preview_sprite.scale          = Vector2(-8.0, 8.0)   # flip X → faces player
	_preview_sprite.play("idle")

	# Labels
	_hero_name_lbl.text  = hero["name"]
	_hero_class_lbl.text = hero["class"]
	_hero_desc_lbl.text  = hero["desc"]

	# Counter in title
	_title_lbl.text = "Choose Your Hero  [%d / %d]" % [_current_idx + 1, _filtered.size()]

	# Entrance tween — slide from the correct direction
	var offset_x := 60.0 * _nav_direction
	_preview_holder.position.x = 640.0 + offset_x
	_preview_holder.modulate.a = 0.0
	var tw := _preview_holder.create_tween()
	tw.tween_property(_preview_holder, "position:x", 640.0, 0.18)
	tw.parallel().tween_property(_preview_holder, "modulate:a", 1.0, 0.18)

# ─────────────────────────────────────────────────────────────────────────────
#  PORTRAIT STRIP — up to 5 thumbnails centered on current
# ─────────────────────────────────────────────────────────────────────────────
func _refresh_portraits() -> void:
	for c in _portrait_row.get_children(): c.queue_free()
	if _filtered.is_empty(): return

	# Use an odd visible count so there's always a true center slot.
	# Cap at whichever is smaller: 5 or the list size (forced odd).
	var max_visible := 5
	var count       := _filtered.size()
	var visible_count: int
	if count >= max_visible:
		visible_count = max_visible          # always odd (5)
	elif count % 2 == 1:
		visible_count = count                # already odd, show all
	else:
		visible_count = count - 1            # drop to nearest odd

	var half := visible_count / 2

	for offset in range(-half, half + 1):
		var idx    := (_current_idx + offset + count) % count
		var hero   := _filtered[idx] as Dictionary
		var is_cur := offset == 0

		var holder := PanelContainer.new()
		holder.custom_minimum_size = Vector2(80 if is_cur else 60,
											 90 if is_cur else 70)

		# Portrait sprite — south-facing stand frame sliced from master sheet.
		# col 3 (x=72) is the clean idle/stand frame; south row = block * 96.
		var portrait := TextureRect.new()
		var portrait_loaded := false
		if ResourceLoader.exists(MASTER_SHEET) and hero["key"] in HERO_SHEET_ROW:
			var s_y: int  = (HERO_SHEET_ROW[hero["key"]] as int) * 4 * 24
			var atlas     := AtlasTexture.new()
			atlas.atlas    = load(MASTER_SHEET) as Texture2D
			atlas.region   = Rect2(72, s_y, 24, 24)   # col 3, south row
			atlas.filter_clip = true
			portrait.texture  = atlas
			portrait_loaded   = true
		if not portrait_loaded:
			var per_sheet := "%s%s_sheet.png" % [HERO_BASE, hero["key"]]
			var port_path := "%s%s_portrait.png" % [HERO_BASE, hero["key"]]
			if ResourceLoader.exists(per_sheet):
				var atlas     := AtlasTexture.new()
				atlas.atlas    = load(per_sheet) as Texture2D
				atlas.region   = Rect2(72, 0, 24, 24)
				atlas.filter_clip = true
				portrait.texture  = atlas
			elif ResourceLoader.exists(port_path):
				portrait.texture = load(port_path)
		portrait.texture_filter      = CanvasItem.TEXTURE_FILTER_NEAREST
		portrait.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		portrait.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.flip_h              = true   # mirror to match preview (scale.x = -8)
		portrait.custom_minimum_size = Vector2(60 if is_cur else 44,
											   60 if is_cur else 44)
		holder.add_child(portrait)

		# Name label under portrait
		var lbl := Label.new()
		lbl.text = hero["name"]
		if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
		lbl.add_theme_font_size_override("font_size", 9)
		lbl.add_theme_color_override("font_color",
			Color(1.0, 0.9, 0.3) if is_cur else Color(0.55, 0.55, 0.55))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(lbl)

		# Highlight/dim for selected vs non-selected
		holder.modulate = Color.WHITE if is_cur else Color(0.5, 0.5, 0.5, 0.8)

		# Transparent button overlay — click to jump
		var jump_idx := idx
		var area     := Button.new()
		area.flat = true
		area.custom_minimum_size = holder.custom_minimum_size
		area.pressed.connect(func():
			_nav_direction = 1 if jump_idx > _current_idx else -1
			_current_idx   = jump_idx
			_refresh_preview()
			_refresh_portraits())
		holder.add_child(area)

		_portrait_row.add_child(holder)

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIRM / BACK
# ─────────────────────────────────────────────────────────────────────────────
func _on_confirm() -> void:
	if _filtered.is_empty(): return
	var hero: Dictionary = _filtered[_current_idx]

	if has_node("/root/SaveManager"):
		SaveManager.set_selected_hero(hero["key"])

	_play_sfx(PATH_SFX_OK)

	# Flash confirm button green then restore
	var tw := _confirm_btn.create_tween()
	tw.tween_property(_confirm_btn, "modulate", Color(0.3, 1.0, 0.4), 0.1)
	tw.tween_property(_confirm_btn, "modulate", Color.WHITE, 0.2)
	await tw.finished

	if has_node("/root/GameRouter"):
		GameRouter.go_to_world_map()

func _on_back() -> void:
	if has_node("/root/GameRouter"):
		GameRouter.go_to_world_map()

# ─────────────────────────────────────────────────────────────────────────────
#  AUDIO HELPER — guards against missing AudioManager autoload
# ─────────────────────────────────────────────────────────────────────────────
func _play_sfx(path: String) -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(path)

# ─────────────────────────────────────────────────────────────────────────────
#  ANIMATION HELPERS
#
#  Master sheet: CGabrielChars24x24.png  (10 cols × 159 rows, 24 px/frame)
#  Each character occupies a BLOCK of 4 rows:
#    block_row + 0  = South / facing player  ← ALWAYS USE THIS
#    block_row + 1  = West  (left)
#    block_row + 2  = East  (right)
#    block_row + 3  = North (back)
#
#  Column layout within any row (10 cols total):
#    x=  0  col 0  walk frame A
#    x= 24  col 1  walk frame B  (mid-stride)
#    x= 48  col 2  walk frame C
#    x= 72  col 3  idle / stand  ← best single preview frame
#    x= 96  col 4  walk frame D
#    x=120  col 5  walk frame E  (mid-stride)
#    x=144  col 6  walk frame F
#    x=168  col 7  attack / alt A
#    x=192  col 8  attack / alt B
#    x=216  col 9  attack / alt C
#
#  HERO_SHEET_ROW maps each hero key → its block index in the master sheet.
#  block_start_y = block_index * 4 * 24  (south row pixel y)
# ─────────────────────────────────────────────────────────────────────────────
const MASTER_SHEET := "res://assets/art/character/CGabrielChars24x24.png"

const HERO_SHEET_ROW: Dictionary = {
	# key            block_index  (south row y = index * 96)
	"m_warrior":     1,
	"f_warrior":     2,
	"m_berserker":   3,
	"f_berserker":   4,
	"m_dark_knight": 5,
	"f_dark_knight": 6,
	"paladin":        7,
	"m_mage":         9,
	"f_mage":         8,
	"m_healer":      10,
	"f_healer":      11,   # Cleric — south block y = 11*96 = 1056
	"m_monk":        12,
	"f_monk":        13,
	"m_ninja":       14,
	"f_ninja":       15,
	"m_ranger":      16,
	"m_samurai":     17,
	"f_samurai":     18,
}

func _make_sprite_frames(hero_key: String) -> SpriteFrames:
	if hero_key in _frames_cache:
		return _frames_cache[hero_key]

	var sf := SpriteFrames.new()
	sf.remove_animation("default")

	# ── Resolve texture source ────────────────────────────────────────────────
	# Priority 1: master CGabriel sheet (correct south row via HERO_SHEET_ROW)
	# Priority 2: per-hero sheet  {key}_sheet.png
	# Priority 3: individual PNGs {key}_idle_walk1.png etc. (may face wrong way)
	var sheet_tex:  Texture2D = null
	var south_y:    int       = 0     # pixel y of the south row for this hero
	var use_master: bool      = false
	var use_sheet:  bool      = false

	if ResourceLoader.exists(MASTER_SHEET) and hero_key in HERO_SHEET_ROW:
		sheet_tex  = load(MASTER_SHEET) as Texture2D
		south_y    = (HERO_SHEET_ROW[hero_key] as int) * 4 * 24
		use_master = true
	else:
		var per_sheet := "%s%s_sheet.png" % [HERO_BASE, hero_key]
		if ResourceLoader.exists(per_sheet):
			sheet_tex = load(per_sheet) as Texture2D
			south_y   = 0   # per-hero sheet: south row is always row 0
			use_sheet = true

	# AtlasTexture factory — slices one 24×24 frame from the resolved sheet
	var make_atlas := func(col_x: int, row_y: int) -> AtlasTexture:
		var a        := AtlasTexture.new()
		a.atlas       = sheet_tex
		a.region      = Rect2(col_x, row_y, 24, 24)
		a.filter_clip = true
		return a

	# ── idle animation — south row, 3 walk frames ─────────────────────────────
	sf.add_animation("idle")
	sf.set_animation_loop("idle", true)
	sf.set_animation_speed("idle", IDLE_FPS)
	if use_master or use_sheet:
		# cols x=0, x=72, x=144 give a smooth 3-frame south walk cycle
		for col_x in [0, 72, 144]:
			sf.add_frame("idle", make_atlas.call(col_x, south_y))
	else:
		for frame_name in ANIM_FRAME_NAMES:
			var path := "%s%s_idle_%s.png" % [HERO_BASE, hero_key, frame_name]
			if ResourceLoader.exists(path):
				sf.add_frame("idle", load(path))

	# ── walk animation — same south row, faster playback ─────────────────────
	sf.add_animation("walk")
	sf.set_animation_loop("walk", true)
	sf.set_animation_speed("walk", WALK_FPS)
	if use_master or use_sheet:
		for col_x in [0, 72, 144]:
			sf.add_frame("walk", make_atlas.call(col_x, south_y))
	else:
		for frame_name in ANIM_FRAME_NAMES:
			var path := "%s%s_walk_%s.png" % [HERO_BASE, hero_key, frame_name]
			if ResourceLoader.exists(path):
				sf.add_frame("walk", load(path))

	_frames_cache[hero_key] = sf
	return sf
