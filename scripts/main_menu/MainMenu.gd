# MainMenu.gd — Video background + character parade + menu buttons
extends Node2D

const PATH_FONT  := "res://assets/fonts/freepixel.ttf"
const PATH_VIDEO := "res://assets/video/intro.ogv"
const PATH_BGM   := "res://assets/audio/bgm/main_theme.ogg"

const PARADE_CHARS: Array[String] = [
	"m_warrior","f_warrior","m_magician","f_magician",
	"m_healer","merchant","m_ninja","f_ninja",
	"king","queen","paladin","bard",
]
const PARADE_Y    := 580.0
const PARADE_SPEED:= 55.0
const WALK_FPS    := 6.0

@onready var _video:         VideoStreamPlayer = $VideoPlayer
@onready var _overlay:       ColorRect         = $Overlay
@onready var _title:         Label             = $TitleLabel
@onready var _subtitle:      Label             = $SubtitleLabel
@onready var _parade:        Node2D            = $CharacterParade
@onready var _start:         Button            = $ButtonsPanel/StartBtn
@onready var _credits:       Button            = $ButtonsPanel/CreditsBtn
@onready var _quit:          Button            = $ButtonsPanel/QuitBtn
@onready var _credits_panel: PanelContainer    = $CreditsPanel
@onready var _credits_lbl:   Label             = $CreditsPanel/CreditsLabel
@onready var _ver_lbl:       Label             = $VersionLabel

var _parade_sprites: Array = []
var _pixel_font: Font = null

func _ready() -> void:
	_pixel_font = load(PATH_FONT) if ResourceLoader.exists(PATH_FONT) else null
	_setup_video()
	_setup_text()
	_setup_buttons()
	_spawn_parade()
	_credits_panel.visible = false

func _setup_video() -> void:
	# Godot 4: load the .ogv as a resource directly
	if not ResourceLoader.exists(PATH_VIDEO):
		_video.visible = false
		_overlay.color = Color(0.05, 0.05, 0.12, 1.0)
		return

	# Load stream via ResourceLoader — works for both .ogv Theora files
	var stream: VideoStream = load(PATH_VIDEO) as VideoStream
	if stream == null:
		_video.visible = false
		_overlay.color = Color(0.05, 0.05, 0.12, 1.0)
		return

	_video.stream   = stream
	_video.loop     = true
	_video.autoplay = false   # we call play() manually after anchors set
	# Stretch to fill the full 1280×720 viewport
	_video.offset_left   = 0
	_video.offset_top    = 0
	_video.offset_right  = 1280
	_video.offset_bottom = 720
	_video.expand        = true
	_video.z_index       = -1
	_video.play()

	_overlay.color   = Color(0.0, 0.0, 0.08, 0.55)
	_overlay.z_index = 0

func _setup_text() -> void:
	if _pixel_font:
		for lbl: Label in [_title, _subtitle, _ver_lbl]:
			lbl.add_theme_font_override("font", _pixel_font)

	_title.text = "AlgoQuest"
	_title.add_theme_font_size_override("font_size", 72)
	_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	_title.add_theme_color_override("font_shadow_color", Color(0,0,0,0.8))
	_title.add_theme_constant_override("shadow_offset_x", 3)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.z_index = 2

	_title.scale = Vector2(0.1, 0.1)
	_title.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT) \
		.tween_property(_title, "scale", Vector2(1,1), 0.6)

	_subtitle.text = "Learn Data Structures & Algorithms Through Adventure"
	_subtitle.add_theme_font_size_override("font_size", 18)
	_subtitle.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.z_index = 2
	_subtitle.modulate = Color(1,1,1,0)
	_subtitle.create_tween().tween_property(_subtitle,"modulate:a",1.0,0.8).set_delay(0.5)

	_ver_lbl.text = "v1.0  |  Godot 4"
	_ver_lbl.add_theme_font_size_override("font_size", 13)
	_ver_lbl.add_theme_color_override("font_color", Color(0.45,0.45,0.45))
	_ver_lbl.z_index = 2

	if _pixel_font:
		_credits_lbl.add_theme_font_override("font", _pixel_font)
	_credits_lbl.text = (
		"AlgoQuest — Educational DSA Game\n\n"
		+ "Character Sprites: Charles Gabriel (CC-BY 3.0)\n"
		+ "Repack: Jorhlok\n"
		+ "opengameart.org/content/twelve-16x18-rpg-sprites-plus-base\n\n"
		+ "Engine: Godot 4\n\n"
		+ "[Click anywhere to close]"
	)

func _setup_buttons() -> void:
	if _pixel_font:
		for btn: Button in [_start, _credits, _quit]:
			btn.add_theme_font_override("font", _pixel_font)

	_start.text   = "▶  Start Game"
	_credits.text = "★  Credits"
	_quit.text    = "✕  Quit"

	var panel := $ButtonsPanel as Control
	panel.z_index = 3
	panel.modulate = Color(1,1,1,0)
	panel.create_tween().tween_property(panel,"modulate:a",1.0,0.5).set_delay(0.7)

	_start.pressed.connect(_on_start)
	_credits.pressed.connect(_on_credits)
	_quit.pressed.connect(_on_quit)

func _spawn_parade() -> void:
	if not is_instance_valid(SpriteHelper) or SpriteHelper._sheet_tex == null:
		return
	var spacing := 160.0
	for i in range(PARADE_CHARS.size()):
		var char_key: String = PARADE_CHARS[i]
		var sprite := Sprite2D.new()
		sprite.texture        = SpriteHelper._sheet_tex
		sprite.region_enabled = true
		sprite.region_rect    = SpriteHelper.get_frame_region(char_key, 2, 1)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.scale          = Vector2(3.5, 3.5)
		sprite.z_index        = 2
		_parade.add_child(sprite)
		var start_x := -200.0 + i * spacing
		sprite.position = Vector2(start_x, PARADE_Y)
		_parade_sprites.append({
			"sprite":   sprite,
			"char_key": char_key,
			"x":        start_x,
			"frame":    0,
			"frame_t":  randf() * (1.0 / WALK_FPS),
		})

func _process(delta: float) -> void:
	for entry in _parade_sprites:
		var data: Dictionary = entry as Dictionary
		data["x"] += PARADE_SPEED * delta
		if (data["x"] as float) > 1340.0:
			data["x"] = -150.0
		data["frame_t"] = (data["frame_t"] as float) + delta
		if (data["frame_t"] as float) >= 1.0 / WALK_FPS:
			data["frame_t"] = (data["frame_t"] as float) - (1.0 / WALK_FPS)
			data["frame"] = ((data["frame"] as int) + 1) % 3
			var region := SpriteHelper.get_frame_region(
				data["char_key"] as String, 2, data["frame"] as int)
			(data["sprite"] as Sprite2D).region_rect = region
		(data["sprite"] as Sprite2D).position = Vector2(data["x"] as float, PARADE_Y)

func _on_start() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func():
		# If PlayerProfile already has a uid (logged in via autoload),
		# go straight to the world map. Otherwise go to login first.
		if has_node("/root/PlayerProfile") and PlayerProfile.uid != "":
			GameRouter.go_to_world_map()
		else:
			GameRouter.go_to_login()
	)

func _on_credits() -> void:
	_credits_panel.visible = true

func _on_quit() -> void:
	get_tree().quit()

func _unhandled_input(event: InputEvent) -> void:
	if _credits_panel.visible and event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_credits_panel.visible = false
