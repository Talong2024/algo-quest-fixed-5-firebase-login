# =============================================================================
# PauseMenu.gd
# File: scripts/ui/PauseMenu.gd
# Attach to a CanvasLayer node named "PauseMenu" added to every chapter scene.
#
# SCENE TREE:
#   PauseMenu (CanvasLayer)           ← this script, layer=90
#   └── Overlay (ColorRect)           ← full screen, color=(0,0,0,0.6)
#       └── Panel (PanelContainer)    ← centered
#           └── VBox (VBoxContainer)
#               ├── TitleLabel  (Label)       "PAUSED"
#               ├── ResumeBtn   (Button)      "▶ Resume"
#               ├── RestartBtn  (Button)      "↺ Restart"
#               ├── HowToBtn    (Button)      "? How to Play"
#               ├── VolumeRow   (HBoxContainer)
#               │   ├── VolLabel (Label)      "Volume:"
#               │   └── VolSlider (HSlider)   min=0 max=1 step=0.05
#               ├── MapBtn      (Button)      "🗺 World Map"
#               └── HowToPanel  (PanelContainer)  visible=false
#                   └── HowToLabel (Label)
#
# ADD TO EACH CHAPTER SCENE:
#   PauseMenu (CanvasLayer) — attach this script
# CALL FROM EACH CHAPTER _unhandled_input:
#   if event.is_action_pressed("ui_cancel"): PauseMenu.toggle()
# =============================================================================

extends CanvasLayer

const PATH_SFX_BTN := "res://assets/codemon/audio/sfx/button.ogg"
const PATH_FONT    := "res://assets/codemon/font/freepixel.ttf"

# How-to text per chapter (set by chapter script or inferred from scene name)
const HOW_TO := {
	"QueueGame":      "FIFO Queue:\n• Citizens auto-join the line\n• Select the correct SERVICE type\n• DRAG the front citizen to the window\n• Clicking non-front = FIFO violation!",
	"StackGame":      "LIFO Stack:\n• DRAG staged rune → column to PUSH\n• CLICK top rune to POP\n• Only the TOP rune is accessible\n• Follow task cards for sequence goals",
	"LinkedListGame": "Linked List:\n• DRAG from ▶ port to connect nodes\n• DRAG node body to reposition\n• RIGHT-CLICK to delete (Normal+)\n• Build one chain: HEAD → ... → TAIL → NULL",
	"TreeGame":       "Binary Search Tree:\n• DRAG numbers from pool to tree\n• Left child < Parent < Right child\n• Green slots = valid positions\n• CLICK leaf to delete (Expert)",
	"GraphGame":      "Graph Algorithms:\n• DRAG between cities to connect\n• Select mode (BFS/Dijkstra) in HUD\n• Click nodes in correct traversal order\n• Find shortest weighted path",
}

@onready var _overlay:    ColorRect       = $Overlay
@onready var _resume_btn: Button          = $Overlay/Panel/VBox/ResumeBtn
@onready var _restart_btn:Button          = $Overlay/Panel/VBox/RestartBtn
@onready var _howto_btn:  Button          = $Overlay/Panel/VBox/HowToBtn
@onready var _vol_slider: HSlider         = $Overlay/Panel/VBox/VolumeRow/VolSlider
@onready var _map_btn:    Button          = $Overlay/Panel/VBox/MapBtn
@onready var _howto_panel:PanelContainer  = $Overlay/Panel/VBox/HowToPanel
@onready var _howto_lbl:  Label           = $Overlay/Panel/VBox/HowToPanel/HowToLabel

var _is_open: bool = false
var _pixel_font: Font = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer   = 90
	visible = false
	_pixel_font = load(PATH_FONT) as Font

	_resume_btn.pressed.connect(_on_resume)
	_restart_btn.pressed.connect(_on_restart)
	_howto_btn.pressed.connect(_on_howto)
	_map_btn.pressed.connect(_on_map)
	_vol_slider.value = AudioServer.get_bus_volume_linear(0)
	_vol_slider.value_changed.connect(_on_volume)

	_howto_panel.visible = false

	# Set how-to text based on parent scene
	var scene_name := get_tree().current_scene.name
	_howto_lbl.text = HOW_TO.get(scene_name, "Interact with the data structure to learn DSA!")
	for lbl: Label in [_howto_lbl]:
		lbl.add_theme_font_override("font", _pixel_font)
		lbl.add_theme_font_size_override("font_size", 15)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		toggle()

# ─────────────────────────────────────────────────────────────────────────────
#  TOGGLE
# ─────────────────────────────────────────────────────────────────────────────
func toggle() -> void:
	_is_open = not _is_open
	visible  = _is_open
	get_tree().paused = _is_open

	if _is_open:
		# Entrance animation
		_overlay.modulate = Color(1,1,1,0)
		_overlay.create_tween().tween_property(_overlay,"modulate:a",1.0,0.2)

func _on_resume() -> void:
	AudioManager.play_sfx(PATH_SFX_BTN)
	toggle()

func _on_restart() -> void:
	AudioManager.play_sfx(PATH_SFX_BTN)
	get_tree().paused = false
	_is_open = false; visible = false
	GameRouter.retry_chapter(GameRouter.current_chapter)

func _on_howto() -> void:
	AudioManager.play_sfx(PATH_SFX_BTN)
	_howto_panel.visible = not _howto_panel.visible

func _on_map() -> void:
	AudioManager.play_sfx(PATH_SFX_BTN)
	get_tree().paused = false
	_is_open = false; visible = false
	GameRouter.go_to_world_map()

func _on_volume(val: float) -> void:
	AudioServer.set_bus_volume_linear(0, val)
