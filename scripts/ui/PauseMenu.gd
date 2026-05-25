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
const PATH_FONT    := "res://assets/fonts/freepixel.ttf"

# How-to text per chapter (set by chapter script or inferred from scene name)
const HOW_TO := {
	"QueueGame":      "FIFO Queue:\n• Citizens auto-join the line\n• Select the correct SERVICE type\n• DRAG the front citizen to the window\n• Clicking non-front = FIFO violation!",
	"StackGame":      "LIFO Stack — Last In, First Out:\n• Click any tray item to PUSH onto the column\n• Click the ♛ crown on the TOP item to POP\n\nTier 0 — Push & Pop: learn the basics\nTier 1 — Rainbow: push colours in REVERSE\n  (Violet first → Red last, so Red pops first)\nTier 2 — Peek: runes land as dark silhouettes\n  Click top rune to reveal its colour, then answer\nTier 3 — Undo: words auto-push one by one\n  Pop them all in reverse to undo your history\nTier 4 — Brackets: open ( [ { → drag to PUSH\n  close ) ] } → click crown to POP and match",
	"LinkedListGame": "Linked List:\n• DRAG from ▶ port to connect nodes\n• DRAG node body to reposition\n• RIGHT-CLICK to delete (Normal+)\n• Build one chain: HEAD → ... → TAIL → NULL",
	"TreeGame":       "Binary Search Tree:\n• DRAG numbers from pool to tree\n• Left child < Parent < Right child\n• Green slots = valid positions\n• CLICK leaf to delete (Expert)",
	"GraphGame":      "Graph Algorithms:\n• DRAG between cities to connect\n• Select mode (BFS/Dijkstra) in HUD\n• Click nodes in correct traversal order\n• Find shortest weighted path",
}

@onready var _overlay:      ColorRect       = $Overlay
@onready var _title_lbl:    Label           = $Overlay/Panel/VBox/TitleLabel
@onready var _resume_btn:   Button          = $Overlay/Panel/VBox/ResumeBtn
@onready var _restart_btn:  Button          = $Overlay/Panel/VBox/RestartBtn
@onready var _howto_btn:    Button          = $Overlay/Panel/VBox/HowToBtn
@onready var _vol_slider:   HSlider         = $Overlay/Panel/VBox/VolumeRow/VolSlider
@onready var _map_btn:      Button          = $Overlay/Panel/VBox/MapBtn

var _is_open:       bool = false
var _settings_mode: bool = false   # true = opened from WorldMap, hide game-only buttons
var _pixel_font:    Font = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	layer        = 90
	# CRITICAL: process_mode ALWAYS means this CanvasLayer and all its children
	# keep processing even when get_tree().paused = true.
	# Without this, the overlay is visible but buttons don't respond.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible      = false
	_pixel_font = load(PATH_FONT) as Font if ResourceLoader.exists(PATH_FONT) else null

	_resume_btn.pressed.connect(_on_resume)
	_restart_btn.pressed.connect(_on_restart)
	_howto_btn.pressed.connect(_on_howto)
	_map_btn.pressed.connect(_on_map)
	_vol_slider.value = AudioServer.get_bus_volume_linear(0)
	_vol_slider.value_changed.connect(_on_volume)

	# Remove blue focus rings from all buttons
	var empty_sb := StyleBoxEmpty.new()
	for btn: Button in [_resume_btn, _restart_btn, _howto_btn, _map_btn]:
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_stylebox_override("focus", empty_sb)


	var text_nodes: Array = [
		_title_lbl, _resume_btn, _restart_btn, _howto_btn,
		_map_btn,
		$Overlay/Panel/VBox/VolumeRow/VolLabel,
	]
	for n in text_nodes:
		if is_instance_valid(n) and _pixel_font:
			n.add_theme_font_override("font", _pixel_font)

	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))

## Called by the WorldMap Settings button — shows only volume + close, no game controls.
func open_settings() -> void:
	_settings_mode = true
	_resume_btn.text    = "✕  Close"
	_restart_btn.visible = false
	_howto_btn.visible   = false
	_map_btn.visible     = false
	_title_lbl.text      = "Settings"
	_show()

## Called by in-game pause button or Escape key.
func toggle() -> void:
	if _settings_mode:
		_close()
		return
	if _is_open:
		_close()
	else:
		_show()

func _show() -> void:
	_is_open = true
	visible  = true
	get_tree().paused = not _settings_mode   # don't pause tree from WorldMap
	_overlay.modulate = Color(1, 1, 1, 0)
	_overlay.create_tween().tween_property(_overlay, "modulate:a", 1.0, 0.2)

func _close() -> void:
	_is_open        = false
	visible         = false
	_settings_mode  = false
	_resume_btn.text     = "▶  Resume"
	_restart_btn.visible = true
	_howto_btn.visible   = true
	_map_btn.visible     = true
	_title_lbl.text      = "PAUSED"
	# Unpause immediately — before any scene change happens.
	# Using call_deferred here caused get_tree() to be null when the deferred
	# call fired after a scene transition (e.g. "Return to Map").
	_unpause_tree()

func _unpause_tree() -> void:
	# Guard: node may no longer be in the tree if a scene change already ran.
	if not is_inside_tree(): return
	var t := get_tree()
	if t != null:
		t.paused = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not _settings_mode:
		toggle()

func _on_resume() -> void:
	_play_sfx(PATH_SFX_BTN)
	_close()

func _on_restart() -> void:
	_play_sfx(PATH_SFX_BTN)
	_close()
	GameRouter.retry_chapter(GameRouter.current_chapter)

signal howto_requested

func _on_howto() -> void:
	_play_sfx(PATH_SFX_BTN)
	_close()
	# Tell the game scene to reopen the intro slides
	emit_signal("howto_requested")

func _on_map() -> void:
	_play_sfx(PATH_SFX_BTN)
	# Unpause the tree BEFORE changing scenes.
	# If we call _close() (which calls _unpause_tree via deferred) and then
	# immediately change scene, the node leaves the tree and get_tree() is null
	# by the time the deferred call runs — causing the error on line 131.
	_unpause_tree()
	visible  = false
	_is_open = false
	GameRouter.go_to_world_map()

func _on_volume(val: float) -> void:
	AudioServer.set_bus_volume_linear(0, val)
	if has_node("/root/AudioManager"):
		AudioManager.set_sfx_volume(val)

func _play_sfx(path: String) -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(path)
