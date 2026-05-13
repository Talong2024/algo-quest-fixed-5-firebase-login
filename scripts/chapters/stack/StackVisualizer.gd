# =============================================================================
# StackVisualizer.gd
# File: res://scripts/chapters/stack/StackVisualizer.gd
#
# A standalone teaching screen shown before the Beginner tier.
# Lets the player freely push, pop, and peek on a live stack so they can
# discover LIFO through experimentation rather than instruction.
#
# Layout (two columns, built entirely in code):
#
#  LEFT                          RIGHT
#  ─────────────────────         ─────────────────────────────
#  item picker (6 buttons)       array representation (live)
#  [push()] [pop()] [peek()]     last operation (live)
#  ↑ top indicator               operation log (scrolling)
#  ┌──────────────────┐          LIFO rule summary
#  │ Thunder  TOP [2] │
#  │ Ice          [1] │
#  │ Fire         [0] │
#  └──────────────────┘
#  ▓ bottom — inaccessible ▓
#  size=3  isEmpty=false  isFull=false
#
#  ───────── [ Start Playing → ] ─────────
#
# How to integrate:
#   Option A — pre-game screen:
#     In your chapter select or DifficultyManager, load this scene first.
#     The "Start Playing" button loads StackGame.tscn with tier 0.
#
#   Option B — in-game intro:
#     Call _show_visualizer() from StackGame._show_concept_intro() for LIFO
#     tier, then await its completion signal.
#
# Signals:
#   visualizer_done  — emitted when the player clicks "Start Playing"
# =============================================================================

extends Control

signal visualizer_done

# ─────────────────────────────────────────────────────────────────────────────
#  CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
const PATH_FONT     := "res://assets/fonts/freepixel.ttf"
const PATH_GAME     := "res://scenes/chapters/stack/StackGame.tscn"
const MAX_SIZE      := 6

# Element definitions — name + primary colour used for the item tile
const ITEMS: Array[Dictionary] = [
	{"name": "Fire",    "color": Color(0.89, 0.29, 0.29)},
	{"name": "Ice",     "color": Color(0.22, 0.54, 0.87)},
	{"name": "Thunder", "color": Color(0.73, 0.46, 0.09)},
	{"name": "Earth",   "color": Color(0.39, 0.60, 0.13)},
	{"name": "Shadow",  "color": Color(0.50, 0.47, 0.87)},
	{"name": "Light",   "color": Color(0.75, 0.73, 0.70)},
]

# ─────────────────────────────────────────────────────────────────────────────
#  COLOURS (all dark-fantasy tones to match the castle game)
# ─────────────────────────────────────────────────────────────────────────────
const C_BG          := CastleTheme.C_STONE_DEEP
const C_SURFACE     := CastleTheme.C_STONE_DARK
const C_BORDER      := CastleTheme.C_STONE_LIGHT
const C_TEXT        := CastleTheme.C_PARCHMENT
const C_MUTED       := CastleTheme.C_PARCHMENT_DIM
const C_SUCCESS     := CastleTheme.C_EMERALD
const C_DANGER      := CastleTheme.C_CRIMSON
const C_ACCENT      := CastleTheme.C_GOLD
const C_BOTTOM_CAP  := CastleTheme.C_STONE_DEEP

# ─────────────────────────────────────────────────────────────────────────────
#  RUNTIME STATE
# ─────────────────────────────────────────────────────────────────────────────
var _stack:         Array      = []
var _selected:      Dictionary = {}
var _log_lines:     Array      = []
var _font:          Font       = null

# ── UI node refs populated in _build_ui() ────────────────────────────────────
var _stack_vbox:    VBoxContainer  = null   # parent of item tiles
var _empty_lbl:     Label          = null   # "empty" hint inside stack col
var _array_lbl:     Label          = null   # array representation
var _op_lbl:        Label          = null   # last operation
var _op_panel:      PanelContainer = null   # border changes colour on op
var _log_vbox:      VBoxContainer  = null   # operation history
var _stat_size:     Label          = null
var _stat_empty:    Label          = null
var _stat_full:     Label          = null
var _picker_btns:   Array          = []     # Array[Button]

# ─────────────────────────────────────────────────────────────────────────────
#  READY
# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_font     = load(PATH_FONT) if ResourceLoader.exists(PATH_FONT) else null
	_selected = ITEMS[0]

	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		margin.add_theme_constant_override("margin_" + ["left","right","top","bottom"][side], 32)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 18)
	margin.add_child(root_vbox)

	_build_title(root_vbox)
	_build_columns(root_vbox)
	_build_continue_btn(root_vbox)

	_update_ui()

# ─────────────────────────────────────────────────────────────────────────────
#  BUILDER HELPERS
# ─────────────────────────────────────────────────────────────────────────────

func _build_title(parent: Control) -> void:
	var lbl := _make_label("Stack Visualizer — explore LIFO before playing", 20, C_ACCENT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)
	var sub := _make_label(
		"Push adds to the top.  Pop removes from the top.  Peek reads the top without removing it.",
		13, C_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(sub)

func _build_columns(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(hbox)

	_build_left_col(hbox)
	_build_separator(hbox)
	_build_right_col(hbox)

# ── LEFT COLUMN ───────────────────────────────────────────────────────────────
func _build_left_col(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 0.45
	col.add_theme_constant_override("separation", 10)
	parent.add_child(col)

	# Item picker
	col.add_child(_make_label("Choose item to push:", 12, C_MUTED))
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 6)
	col.add_child(flow)
	_picker_btns.clear()
	for item: Dictionary in ITEMS:
		var btn := _make_item_picker_btn(item)
		_picker_btns.append(btn)
		flow.add_child(btn)

	# Action buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	col.add_child(btn_row)
	_add_action_btn(btn_row, "push()",  C_SUCCESS, _on_push)
	_add_action_btn(btn_row, "pop()",   C_DANGER,  _on_pop)
	_add_action_btn(btn_row, "peek()",  Color(0.35, 0.75, 0.95), _on_peek)

	# "↑ top" indicator
	var top_lbl := _make_label("↑  only entry & exit point  ↑", 12, Color(0.40, 0.95, 0.60))
	top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(top_lbl)

	# Stack column panel
	var col_panel := _make_panel()
	col_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(col_panel)

	# ScrollContainer so overflow doesn't break layout
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical    = Control.SIZE_EXPAND_FILL
	col_panel.add_child(scroll)

	_stack_vbox = VBoxContainer.new()
	_stack_vbox.add_theme_constant_override("separation", 5)
	_stack_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_stack_vbox)

	# Empty-state label (sits inside the vbox when stack is empty)
	_empty_lbl = _make_label("stack is empty\nisEmpty() → true", 13, C_MUTED)
	_empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stack_vbox.add_child(_empty_lbl)

	# Bottom cap
	var bottom_cap := ColorRect.new()
	bottom_cap.color = C_BOTTOM_CAP
	bottom_cap.custom_minimum_size = Vector2(0, 32)
	col.add_child(bottom_cap)
	var cap_lbl := _make_label("▓▓▓  bottom — inaccessible  ▓▓▓", 11, C_MUTED)
	cap_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_cap.add_child(cap_lbl)

	# Stats row
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 8)
	col.add_child(stats)
	_stat_size  = _build_stat_card(stats, "size()",    "0",     C_TEXT)
	_stat_empty = _build_stat_card(stats, "isEmpty()", "true",  C_SUCCESS)
	_stat_full  = _build_stat_card(stats, "isFull()",  "false", C_SUCCESS)

# ── RIGHT COLUMN ──────────────────────────────────────────────────────────────
func _build_right_col(parent: Control) -> void:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_stretch_ratio = 0.55
	col.add_theme_constant_override("separation", 10)
	parent.add_child(col)

	# Array representation
	col.add_child(_make_label("array representation", 12, C_MUTED))
	var arr_panel := _make_panel()
	col.add_child(arr_panel)
	_array_lbl = _make_label("", 14, C_TEXT)
	_array_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _font: _array_lbl.add_theme_font_override("font", _font)
	arr_panel.add_child(_array_lbl)

	# Last operation
	col.add_child(_make_label("last operation", 12, C_MUTED))
	_op_panel = _make_panel()
	col.add_child(_op_panel)
	_op_lbl = _make_label("—", 15, C_MUTED)
	if _font: _op_lbl.add_theme_font_override("font", _font)
	_op_panel.add_child(_op_lbl)

	# Operation log
	col.add_child(_make_label("operation log", 12, C_MUTED))
	var log_panel := _make_panel()
	log_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(log_panel)
	var log_scroll := ScrollContainer.new()
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_panel.add_child(log_scroll)
	_log_vbox = VBoxContainer.new()
	_log_vbox.add_theme_constant_override("separation", 3)
	_log_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(_log_vbox)

	# LIFO rule box
	var rule_panel := _make_panel(Color(0.14, 0.12, 0.22))
	col.add_child(rule_panel)
	var rule_vbox := VBoxContainer.new()
	rule_vbox.add_theme_constant_override("separation", 6)
	rule_panel.add_child(rule_vbox)
	rule_vbox.add_child(_make_label("LIFO  —  Last In, First Out", 14, C_ACCENT))
	for line: String in [
		"push()  adds to the top   →  newest item is always on top",
		"pop()   removes the top   →  newest item always leaves first",
		"peek()  reads the top     →  look without touching the stack",
		"Items below the top are trapped until everything above is removed.",
	]:
		rule_vbox.add_child(_make_label(line, 12, C_MUTED))

func _build_continue_btn(parent: Control) -> void:
	var btn := Button.new()
	btn.text = "Start Playing  →"
	btn.custom_minimum_size = Vector2(0, 48)
	if _font:
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", CastleTheme.C_GOLD)
	var style := CastleTheme.stone_panel(CastleTheme.C_GOLD, 3, 20)
	btn.add_theme_stylebox_override("normal",  style)
	var style_h := CastleTheme.stone_panel(CastleTheme.C_GOLD, 3, 20)
	style_h.bg_color = CastleTheme.C_STONE_LIGHT
	btn.add_theme_stylebox_override("hover",   style_h)
	btn.add_theme_stylebox_override("pressed", CastleTheme.btn_pressed())
	btn.pressed.connect(_on_continue)
	parent.add_child(btn)

# ─────────────────────────────────────────────────────────────────────────────
#  ACTIONS
# ─────────────────────────────────────────────────────────────────────────────
func _on_push() -> void:
	if _stack.size() >= MAX_SIZE:
		_set_op("push(\"%s\")  →  OverflowError! stack is full (%d/%d)" % [
			_selected["name"], MAX_SIZE, MAX_SIZE], C_DANGER)
		_add_log("push(\"%s\")  ×  full" % _selected["name"], C_DANGER)
		return
	_stack.append(_selected.duplicate())
	_set_op("push(\"%s\")  →  size now %d" % [_selected["name"], _stack.size()],
		_selected["color"])
	_add_log("push(\"%s\")" % _selected["name"], _selected["color"])
	_update_ui()

func _on_pop() -> void:
	if _stack.is_empty():
		_set_op("pop()  →  IndexError! isEmpty() is true", C_DANGER)
		_add_log("pop()  ×  empty", C_DANGER)
		return
	var item: Dictionary = _stack.back()
	_stack.pop_back()
	_set_op("pop()  →  \"%s\"    (size now %d)" % [item["name"], _stack.size()],
		item["color"])
	_add_log("pop()  →  \"%s\"" % item["name"], item["color"])
	_update_ui()

func _on_peek() -> void:
	if _stack.is_empty():
		_set_op("peek()  →  IndexError! isEmpty() is true", C_DANGER)
		_add_log("peek()  ×  empty", C_DANGER)
		return
	var item: Dictionary = _stack.back()
	_set_op("stack[-1]  →  \"%s\"    (stack UNCHANGED, size still %d)" % [
		item["name"], _stack.size()], Color(0.35, 0.75, 0.95))
	_add_log("peek()  →  \"%s\"  (unchanged)" % item["name"],
		Color(0.35, 0.75, 0.95))
	# Briefly highlight the top tile
	if _stack_vbox.get_child_count() > 0:
		var top_tile: Control = _stack_vbox.get_child(0)
		var tw := top_tile.create_tween()
		tw.tween_property(top_tile, "modulate", Color(1.4, 1.4, 1.4), 0.08)
		tw.tween_property(top_tile, "modulate", Color.WHITE, 0.5)

func _on_item_selected(item: Dictionary) -> void:
	_selected = item
	_refresh_picker()

func _on_continue() -> void:
	emit_signal("visualizer_done")
	# Route through GameRouter so current_chapter and DifficultyManager are
	# both set correctly before StackGame._ready() reads them.
	if has_node("/root/GameRouter"):
		GameRouter.go_to_chapter(6)   # 6 = Stack Beginner
	else:
		# Fallback: set tier manually and load directly
		if has_node("/root/DifficultyManager"):
			DifficultyManager.set_tier(0)
		if ResourceLoader.exists(PATH_GAME):
			get_tree().change_scene_to_file(PATH_GAME)

# ─────────────────────────────────────────────────────────────────────────────
#  UI UPDATER — rebuilds the stack column and all live labels
# ─────────────────────────────────────────────────────────────────────────────
func _update_ui() -> void:
	# ── Stack column ──────────────────────────────────────────────────────────
	# Remove existing item tiles (keep _empty_lbl at index 0)
	for ch in _stack_vbox.get_children():
		if ch != _empty_lbl:
			ch.queue_free()

	_empty_lbl.visible = _stack.is_empty()

	# Add tiles top-to-bottom so index 0 of VBox = top of stack
	for i in range(_stack.size() - 1, -1, -1):
		var item: Dictionary = _stack[i]
		var is_top := (i == _stack.size() - 1)
		var tile := _make_item_tile(item, is_top, i)
		_stack_vbox.add_child(tile)
		# Slide-in animation (scale from 0 → 1)
		tile.scale = Vector2(1.0, 0.0)
		tile.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)\
			.tween_property(tile, "scale", Vector2.ONE, 0.2)

	# ── Array representation ──────────────────────────────────────────────────
	if _stack.is_empty():
		_array_lbl.text = "stack = []\n\n# isEmpty() → true"
	else:
		var parts: Array = []
		for item: Dictionary in _stack:
			parts.append('"%s"' % item["name"])

		_array_lbl.text = (
			"stack = [%s]\n" % ", ".join(parts)
			+ "# size = %d  |  top index = %d\n" % [_stack.size(), _stack.size() - 1]
			+ "# stack[-1] = \"%s\"  ← top" % _stack.back()["name"]
		)

	# ── Stats ─────────────────────────────────────────────────────────────────
	_stat_size.text  = str(_stack.size())
	var is_empty := _stack.is_empty()
	var is_full  := _stack.size() >= MAX_SIZE
	_stat_empty.text  = "true"  if is_empty else "false"
	_stat_empty.add_theme_color_override("font_color",
		C_SUCCESS if is_empty else C_DANGER)
	_stat_full.text   = "true"  if is_full  else "false"
	_stat_full.add_theme_color_override("font_color",
		C_DANGER if is_full else C_SUCCESS)

# ─────────────────────────────────────────────────────────────────────────────
#  OPERATION DISPLAY & LOG
# ─────────────────────────────────────────────────────────────────────────────
func _set_op(text: String, color: Color) -> void:
	_op_lbl.text = text
	_op_lbl.add_theme_color_override("font_color", color)
	# Flash the op panel border in the operation colour
	var style := _op_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		var orig := style.border_color
		var tw   := _op_panel.create_tween()
		tw.tween_method(func(c: Color): style.border_color = c, color, orig, 1.2)

func _add_log(text: String, color: Color) -> void:
	_log_lines.push_front({"text": text, "color": color})
	if _log_lines.size() > 12:
		_log_lines.pop_back()

	# Clear and rebuild log lines
	for ch in _log_vbox.get_children():
		ch.queue_free()

	for i in range(_log_lines.size()):
		var entry: Dictionary = _log_lines[i]
		var lbl := _make_label(
			("→  " if i == 0 else "   ") + entry["text"],
			12,
			entry["color"] if i == 0 else C_MUTED)
		if _font: lbl.add_theme_font_override("font", _font)
		_log_vbox.add_child(lbl)

# ─────────────────────────────────────────────────────────────────────────────
#  ITEM PICKER
# ─────────────────────────────────────────────────────────────────────────────
func _make_item_picker_btn(item: Dictionary) -> Button:
	var btn := Button.new()
	btn.text = item["name"]
	btn.toggle_mode = false
	if _font:
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 13)

	var style_n := StyleBoxFlat.new()
	style_n.bg_color     = item["color"].darkened(0.75)
	style_n.border_color = item["color"].darkened(0.2)
	style_n.set_border_width_all(1)
	style_n.set_corner_radius_all(6)
	style_n.content_margin_left  = 10
	style_n.content_margin_right = 10
	style_n.content_margin_top   = 5
	style_n.content_margin_bottom = 5
	btn.add_theme_stylebox_override("normal", style_n)

	var style_h := style_n.duplicate() as StyleBoxFlat
	style_h.border_color = item["color"]
	style_h.set_border_width_all(2)
	btn.add_theme_stylebox_override("hover",   style_h)
	btn.add_theme_stylebox_override("pressed", style_h)

	btn.add_theme_color_override("font_color",          item["color"])
	btn.add_theme_color_override("font_hover_color",    item["color"])
	btn.add_theme_color_override("font_pressed_color",  item["color"])

	btn.pressed.connect(_on_item_selected.bind(item))
	return btn

func _refresh_picker() -> void:
	for i in range(_picker_btns.size()):
		var btn := _picker_btns[i] as Button
		var item: Dictionary = ITEMS[i]
		var is_sel: bool = (item["name"] as String) == (_selected["name"] as String)
		var style := btn.get_theme_stylebox("normal") as StyleBoxFlat
		if style:
			style.set_border_width_all(2 if is_sel else 1)
			style.bg_color = item["color"].darkened(0.55 if is_sel else 0.75)

# ─────────────────────────────────────────────────────────────────────────────
#  NODE FACTORIES
# ─────────────────────────────────────────────────────────────────────────────

func _make_item_tile(item: Dictionary, is_top: bool, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color     = item["color"].darkened(0.70)
	style.border_color = item["color"] if is_top else item["color"].darkened(0.35)
	style.set_border_width_all(2 if is_top else 1)
	style.set_corner_radius_all(6)
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	panel.add_child(hbox)

	# Item name
	var name_lbl := _make_label(item["name"], 14, item["color"])
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_lbl)

	# TOP badge (only on top item)
	if is_top:
		var badge := _make_label("TOP", 11, item["color"].darkened(0.3))
		var badge_panel := PanelContainer.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color    = item["color"]
		bs.set_corner_radius_all(4)
		bs.content_margin_left  = 5
		bs.content_margin_right = 5
		bs.content_margin_top   = 2
		bs.content_margin_bottom = 2
		badge_panel.add_theme_stylebox_override("panel", bs)
		badge_panel.add_child(badge)
		badge.add_theme_color_override("font_color", item["color"].darkened(0.7))
		hbox.add_child(badge_panel)

	# Index label
	var idx_lbl := _make_label("[%d]" % index, 11, C_MUTED)
	hbox.add_child(idx_lbl)

	return panel

func _make_panel(bg: Color = C_SURFACE) -> PanelContainer:
	var panel := PanelContainer.new()
	# Use CastleTheme for all panels; bg param is ignored (kept for signature compat)
	panel.add_theme_stylebox_override("panel", CastleTheme.stone_panel())
	return panel

func _make_label(text: String, size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	if _font:
		lbl.add_theme_font_override("font", _font)
		lbl.add_theme_font_size_override("font_size", size)
	return lbl

func _add_action_btn(parent: Control, text: String, color: Color, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size   = Vector2(0, 40)
	if _font:
		btn.add_theme_font_override("font", _font)
		btn.add_theme_font_size_override("font_size", 14)

	# Pick the right CastleTheme button style based on colour role
	var is_danger  := color.r > 0.6 and color.g < 0.4   # red-ish = pop
	var is_info    := color.b > 0.6 and color.r < 0.5   # blue-ish = peek
	if is_danger:
		btn.add_theme_stylebox_override("normal",  CastleTheme.btn_danger_normal())
		btn.add_theme_stylebox_override("hover",   CastleTheme.btn_danger_hover())
	elif is_info:
		btn.add_theme_stylebox_override("normal",  CastleTheme.btn_info_normal())
		btn.add_theme_stylebox_override("hover",   CastleTheme.btn_info_hover())
	else:
		btn.add_theme_stylebox_override("normal",  CastleTheme.btn_success_normal())
		btn.add_theme_stylebox_override("hover",   CastleTheme.btn_success_hover())
	btn.add_theme_stylebox_override("pressed", CastleTheme.btn_pressed())
	btn.add_theme_color_override("font_color",         CastleTheme.C_PARCHMENT)
	btn.add_theme_color_override("font_hover_color",   CastleTheme.C_GOLD)
	btn.add_theme_color_override("font_pressed_color", CastleTheme.C_PARCHMENT_DIM)
	btn.pressed.connect(cb)
	parent.add_child(btn)

func _build_stat_card(parent: Control, caption: String, initial: String,
		color: Color) -> Label:
	var panel := _make_panel()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	panel.add_child(vb)
	vb.add_child(_make_label(caption, 11, C_MUTED))
	var val_lbl := _make_label(initial, 16, color)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(val_lbl)
	return val_lbl

func _build_separator(parent: Control) -> void:
	var sep := VSeparator.new()
	sep.add_theme_color_override("color", C_BORDER)
	parent.add_child(sep)
