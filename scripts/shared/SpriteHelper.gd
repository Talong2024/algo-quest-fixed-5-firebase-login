# SpriteHelper.gd — Autoload
# Add as "SpriteHelper" in Project > Autoload
# Maps game character roles to their regions in CGabrielChars24x24.png
# Sheet: 240px wide (10 sprites × 24px), 3816px tall (159 rows × 24px)
# Each character occupies 3 rows: [0]=down [1]=up [2]=right
# Frame order: Walk1, Stand, Walk2, Punch1, Punch2, Punch3, Cast1, Cast2, Cast3, Cast4
extends Node

const SHEET_PATH  := "res://assets/sprites/characters/CGabrielChars24x24.png"
const FACES_PATH  := "res://assets/sprites/characters/CGabrielFaces48x48.png"
const SPRITE_W    := 24
const SPRITE_H    := 24
const FACE_W      := 48
const FACE_H      := 48

# Character index → first row in sheet (index × 3)
const CHAR_INDEX := {
	"adult_template": 0,  "child_template": 1,
	"m_warrior": 2,       "m_magician": 3,     "m_healer": 4,
	"m_ninja": 5,         "m_ranger": 6,        "middle_aged_man": 7,
	"f_warrior": 8,       "f_magician": 9,      "f_healer": 10,
	"f_ninja": 11,        "f_ranger": 12,       "middle_aged_woman": 13,
	"m_monk": 14,         "m_berserker": 15,    "m_dark_knight": 16,
	"m_soldier": 17,      "young_man_a": 18,    "young_man_b": 19,
	"f_monk": 20,         "f_berserker": 21,    "f_dark_knight": 22,
	"f_soldier": 23,      "young_woman_a": 24,  "young_woman_b": 25,
	"fire_elemental": 26, "water_elemental": 27,"wind_elemental": 28,
	"earth_elemental": 29,"light_elemental": 30,"dark_elemental": 31,
	"priest": 32,         "nun": 33,            "merchant": 34,
	"cultist": 35,        "pirate": 36,         "captain": 37,
	"m_samurai": 38,      "f_samurai": 39,      "boy": 40,
	"girl": 41,           "f_dancer": 42,       "king": 43,
	"queen": 44,          "old_man": 45,        "old_woman": 46,
	"vampire": 47,        "bard": 48,           "paladin": 49,
	"bunny_girl": 50,     "m_angel": 51,        "f_angel": 52,
}

# DSA chapter role → character key
const QUEUE_CITIZENS  := ["m_warrior",  "merchant",  "m_healer",  "king"]
const STACK_RUNES     := ["fire_elemental","water_elemental","wind_elemental",
                           "earth_elemental","light_elemental","dark_elemental"]
const LIST_NODES      := ["m_ninja","f_ninja","pirate","bard","boy","girl","m_angel","f_angel"]
const TREE_NODES      := ["m_magician","f_magician","vampire","m_dark_knight","f_dark_knight"]
const GRAPH_CITIES    := ["m_soldier","captain","m_samurai","f_samurai",
                           "m_berserker","f_berserker","paladin","m_ranger"]

var _sheet_tex:  Texture2D = null
var _faces_tex:  Texture2D = null

func _ready() -> void:
	if ResourceLoader.exists(SHEET_PATH): _sheet_tex = load(SHEET_PATH)
	if ResourceLoader.exists(FACES_PATH): _faces_tex = load(FACES_PATH)

# ── Public API ────────────────────────────────────────────────────────────────

## Returns an AtlasTexture for the character's standing frame facing down.
func get_stand_texture(char_key: String) -> AtlasTexture:
	return _frame_tex(char_key, 0, 1)   # direction=down, frame=1 (Stand)

## Returns AtlasTexture for a specific direction and frame index.
func get_frame_texture(char_key: String, direction: int, frame: int) -> AtlasTexture:
	return _frame_tex(char_key, direction, frame)

## Returns the Rect2 region for a character frame (use with Sprite2D.region_rect).
func get_frame_region(char_key: String, direction: int, frame: int) -> Rect2:
	var char_idx: int = CHAR_INDEX.get(char_key, 0)
	var row := char_idx * 3 + direction
	return Rect2(frame * SPRITE_W, row * SPRITE_H, SPRITE_W, SPRITE_H)

## Configures a Sprite2D to show a specific character stand frame.
func setup_sprite(sprite: Sprite2D, char_key: String, direction: int = 0) -> void:
	if _sheet_tex == null: return
	sprite.texture        = _sheet_tex
	sprite.region_enabled = true
	sprite.region_rect    = get_frame_region(char_key, direction, 1)  # Stand frame
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

## Returns a face AtlasTexture for display in UI (first 8 faces per row).
func get_face_texture(face_idx: int) -> AtlasTexture:
	if _faces_tex == null: return null
	var col := face_idx % 8
	var row := face_idx / 8
	var at  := AtlasTexture.new()
	at.atlas  = _faces_tex
	at.region = Rect2(col * FACE_W, row * FACE_H, FACE_W, FACE_H)
	return at

# ── Helpers ───────────────────────────────────────────────────────────────────
func _frame_tex(char_key: String, direction: int, frame: int) -> AtlasTexture:
	if _sheet_tex == null: return null
	var at := AtlasTexture.new()
	at.atlas  = _sheet_tex
	at.region = get_frame_region(char_key, direction, frame)
	return at
