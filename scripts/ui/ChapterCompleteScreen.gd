# =============================================================================
# ChapterCompleteScreen.gd
# File: scripts/ui/ChapterCompleteScreen.gd
#
# FIXES:
#   - Accuracy was always 0% — now computed from correct / total when the
#     "accuracy" key is absent or zero but "correct" + a total key exist.
#   - Celebratory design: confetti particles, star burst, glow animations,
#     gradient BG, animated entrance for each stat row, pulsing grade label.
# =============================================================================

extends CanvasLayer

const PATH_FONT     := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_WIN  := "res://assets/codemon/audio/sfx/level_up.ogg"
const PATH_SFX_FAIL := "res://assets/codemon/audio/sfx/fail.ogg"
const PATH_SFX_BTN  := "res://assets/codemon/audio/sfx/button.ogg"

const CHAPTER_NAMES := {
	1:  "Kingdom Gate  [Beginner]",
	2:  "Kingdom Gate  [Easy]",
	3:  "Kingdom Gate  [Normal]",
	4:  "Kingdom Gate  [Hard]",
	5:  "Kingdom Gate  [Expert]",
	6:  "Castle of Echoes  [Beginner]",
	7:  "Castle of Echoes  [Easy]",
	8:  "Castle of Echoes  [Normal]",
	9:  "Castle of Echoes  [Hard]",
	10: "Castle of Echoes  [Expert]",
	11: "Chain Station  [Beginner]",
	12: "Chain Station  [Easy]",
	13: "Chain Station  [Normal]",
	14: "Chain Station  [Hard]",
	15: "Chain Station  [Expert]",
	16: "Oracle's Forest  [Beginner]",
	17: "Oracle's Forest  [Easy]",
	18: "Oracle's Forest  [Normal]",
	19: "Oracle's Forest  [Hard]",
	20: "Oracle's Forest  [Expert]",
	21: "Kingdom Roads  [Beginner]",
	22: "Kingdom Roads  [Easy]",
	23: "Kingdom Roads  [Normal]",
	24: "Kingdom Roads  [Hard]",
	25: "Kingdom Roads  [Expert]",
}

const CHAPTER_CONCEPTS := {
	1:  "FIFO — First In, First Out.\nEnqueue adds to the BACK. Dequeue removes from the FRONT.\nReal use: task scheduling, print queues, BFS.",
	2:  "SERVICE QUEUES — Peek first, select service, then dequeue.\nReal use: priority dispatching, customer service systems.",
	3:  "OVERFLOW — Queues have capacity limits.\nCannot enqueue when full — must dequeue first.\nReal use: bounded buffers, network packet queues.",
	4:  "MULTI-LANE — Two queues in parallel.\nEnqueue each item into the correct lane.\nReal use: multi-threaded task queues, lane routing.",
	5:  "EXPERT QUEUES — All rules active simultaneously.\nPriority items break FIFO order.\nReal use: priority queues, OS scheduling algorithms.",
	6:  "LIFO — Last In, First Out.\nPush adds to top. Pop removes from top.\nReal use: undo systems, function call stacks.",
	7:  "STACK EXPRESSIONS — Evaluate postfix with a stack.\nReal use: calculators, compilers, expression parsing.",
	8:  "STACK OVERFLOW — Stacks have depth limits.\nReal use: recursion limits, memory management.",
	9:  "BALANCED BRACKETS — Use a stack to match pairs.\nReal use: syntax checking, HTML/XML validation.",
	10: "EXPERT STACK — All stack rules combined.\nReal use: DFS graph traversal, backtracking algorithms.",
	11: "LINKED LIST — Nodes connected by pointers.\nInsertion/deletion O(1) at head. Access O(n).\nReal use: dynamic memory, music playlists.",
	12: "INSERTION — Add nodes at head, tail, or middle.\nReal use: dynamic arrays, hash chaining.",
	13: "DELETION — Remove nodes by value or position.\nMust update the previous node's pointer.\nReal use: LRU cache, memory deallocation.",
	14: "REVERSAL — Reverse a linked list in-place.\nClassic interview problem — three pointer technique.\nReal use: undo stacks, palindrome detection.",
	15: "EXPERT LIST — Merge, cycle detection, and sorting.\nReal use: mergesort, OS process scheduling.",
	16: "BST BASICS — Binary Search Tree.\nLeft child < Parent < Right child — always.\nDrag nodes to green slots to build a valid BST.",
	17: "BST WITHOUT GUIDES — Apply the rule yourself.\nAt every node: is my value less or greater?\nLeft < Parent < Right — no hints, same rule.",
	18: "INORDER TRAVERSAL — Visit Left → Root → Right.\nInorder BST traversal always produces sorted output.\nReal use: sorting, range queries, expression trees.",
	19: "AVL BALANCE — |Left height − Right height| ≤ 1.\nUnbalanced BST degrades to O(n) search.\nReal use: self-balancing trees used in databases.",
	20: "BST EXPERT — Place, delete leaves, rebalance.\nDeletion + rebalancing is the hardest BST operation.\nReal use: AVL trees, Red-Black trees, B-trees.",
	21: "GRAPH BASICS — Nodes connected by edges.\nBFS visits nearest neighbours first.\nReal use: maps, social networks, shortest path.",
	22: "BFS — Breadth-First Search uses a queue.\nVisits all nodes at distance d before d+1.\nReal use: shortest path in unweighted graphs.",
	23: "DFS — Depth-First Search uses a stack.\nGoes deep before backtracking.\nReal use: maze solving, topological sort, cycle detection.",
	24: "WEIGHTED GRAPHS — Edges have costs.\nDijkstra's algorithm finds the cheapest path.\nReal use: GPS navigation, network routing.",
	25: "EXPERT GRAPH — MST, connectivity, and flow.\nKruskal's and Prim's build minimum spanning trees.\nReal use: network design, clustering algorithms.",
}

# Confetti colours
const CONFETTI_COLORS := [
	Color(1.0, 0.85, 0.1),   # gold
	Color(0.3, 1.0,  0.5),   # mint
	Color(0.4, 0.8,  1.0),   # sky
	Color(1.0, 0.45, 0.7),   # pink
	Color(0.7, 0.4,  1.0),   # violet
	Color(1.0, 0.6,  0.2),   # orange
]

@onready var _bg:           ColorRect       = $BG
@onready var _title_lbl:    Label           = $Panel/VBox/TitleLabel
@onready var _chapter_lbl:  Label           = $Panel/VBox/ChapterLabel
@onready var _grade_lbl:    Label           = $Panel/VBox/GradeLabel
@onready var _stars_row:    HBoxContainer   = $Panel/VBox/StarsRow
@onready var _stats_grid:   GridContainer   = $Panel/VBox/StatsGrid
@onready var _concept_lbl:  Label           = $Panel/VBox/ConceptLabel
@onready var _retry_btn:    Button          = $Panel/VBox/ButtonRow/RetryBtn
@onready var _next_btn:     Button          = $Panel/VBox/ButtonRow/NextBtn
@onready var _map_btn:      Button          = $Panel/VBox/ButtonRow/MapBtn

var _current_chapter: int  = -1
var _success:         bool = false
var _pixel_font:      Font = null

# Confetti nodes kept so we can clean them up on retry/next
var _confetti_nodes: Array[Node2D] = []
# Grade pulse tween reference
var _grade_tween: Tween = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font
	layer   = 100
	visible = false

	for lbl: Label in [_title_lbl, _chapter_lbl, _grade_lbl, _concept_lbl]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", _pixel_font)
	_grade_lbl.add_theme_font_size_override("font_size", 80)

	_retry_btn.pressed.connect(_on_retry)
	_next_btn.pressed.connect(_on_next)
	_map_btn.pressed.connect(_on_map)

	_style_buttons()

# ─────────────────────────────────────────────────────────────────────────────
#  PUBLIC ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────
func show_result(chapter_id: int, stats_or_score, stars_if_positional: int = -1) -> void:
	_current_chapter = chapter_id
	_clear_confetti()

	var stats: Dictionary
	if stats_or_score is Dictionary:
		stats = stats_or_score
	else:
		var raw_score: int = int(stats_or_score)
		var raw_stars: int = stars_if_positional if stars_if_positional >= 0 else 0
		stats = {
			"score":   raw_score,
			"stars":   raw_stars,
			"success": raw_stars > 0,
			"grade":   _stars_to_grade(raw_stars),
		}

	# ── Accuracy resolution ───────────────────────────────────────────────────
	# Compute accuracy from correct/total if the key is missing or still 0.
	# Run this FIRST — both the display and the save need the final value.
	if not stats.has("accuracy") or float(stats.get("accuracy", 0.0)) == 0.0:
		var correct: int = stats.get("correct", 0)
		var total:   int = _resolve_total(stats, correct)
		if total > 0:
			stats["accuracy"] = float(correct) / float(total) * 100.0

	_success = stats.get("success", false)

	# ── Title ─────────────────────────────────────────────────────────────────
	if _success:
		_title_lbl.text = "✦ CHAPTER COMPLETE! ✦"
		_title_lbl.add_theme_color_override("font_color", Color(0.25, 1.0, 0.55))
		_title_lbl.add_theme_font_size_override("font_size", 34)
	else:
		_title_lbl.text = "CHAPTER FAILED"
		_title_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		_title_lbl.add_theme_font_size_override("font_size", 28)

	_chapter_lbl.text = "Chapter %d — %s" % [
		chapter_id, CHAPTER_NAMES.get(chapter_id, "Chapter %d" % chapter_id)]
	_chapter_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.9))
	_chapter_lbl.add_theme_font_size_override("font_size", 17)

	var grade: String = stats.get("grade", _stars_to_grade(stats.get("stars", 0)))
	_grade_lbl.text = grade
	_grade_lbl.add_theme_color_override("font_color", _grade_color(grade))

	var stars: int = stats.get("stars", _grade_to_stars(grade))
	_build_stars(stars)
	_build_stats_grid(stats)

	_concept_lbl.text = CHAPTER_CONCEPTS.get(chapter_id,
		"Keep practising — every mistake teaches you something.")
	_concept_lbl.add_theme_color_override("font_color", Color(0.65, 0.75, 0.85))
	_concept_lbl.add_theme_font_size_override("font_size", 14)

	# Next button
	var next_ch: int = GameRouter.next_chapter(chapter_id) \
		if has_node("/root/GameRouter") else -1
	if next_ch > 0 and _success:
		_next_btn.disabled = false
		_next_btn.modulate = Color.WHITE
		_next_btn.text     = "Next: %s →" % CHAPTER_NAMES.get(next_ch, "Next Level")
	else:
		_next_btn.disabled = true
		_next_btn.modulate = Color(0.35, 0.35, 0.35)
		_next_btn.text     = "Next Level"

	visible = true
	_animate_entrance()

	if _success:
		_spawn_confetti()
		_pulse_grade()

	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(PATH_SFX_WIN if _success else PATH_SFX_FAIL)

	# ── Save progress ─────────────────────────────────────────────────────────
	# Only save on success so a failed run never overwrites a previous best.
	if _success and has_node("/root/PlayerProfile"):
		var save_score:    int   = stats.get("score",    0)    as int
		var save_stars:    int   = stats.get("stars",    0)    as int
		var save_accuracy: float = stats.get("accuracy", 0.0)  as float

		# Build the mistakes dict from every known mistake key in the stats.
		# This is what the teacher dashboard reads to show per-tier breakdowns.
		var save_mistakes: Dictionary = {}
		var mistake_keys := [
			"fifo_violation", "service_miss", "lane_miss", "overflow_count",
			"bad_link",       "wrong_reverse","bad_insert","structural_err",
			"array_shifts",   "wrong_bst",    "wrong_balance","wrong_delete",
			"wrong",          "errors",
		]
		for mk in mistake_keys:
			var mv = stats.get(mk, 0)
			if (mv is int or mv is float) and int(mv) > 0:
				save_mistakes[mk] = int(mv)

		# If the game passed a top-level "mistakes" dict, merge it in too.
		if stats.has("mistakes") and stats["mistakes"] is Dictionary:
			for mk in (stats["mistakes"] as Dictionary):
				var mv = (stats["mistakes"] as Dictionary)[mk]
				if (mv is int or mv is float) and int(mv) > 0:
					save_mistakes[mk] = int(mv)

		PlayerProfile.save_chapter_result(
			chapter_id, save_score, save_stars, save_accuracy, save_mistakes)

# ─────────────────────────────────────────────────────────────────────────────
#  ACCURACY HELPER
# ─────────────────────────────────────────────────────────────────────────────
## Returns the most plausible total-attempts count from a stats dict.
func _resolve_total(stats: Dictionary, correct: int) -> int:
	for key in ["total", "attempts", "questions", "total_questions",
				"total_attempts", "rounds", "total_rounds"]:
		var v = stats.get(key, 0)
		if v is int and v > 0:
			return v

	var mistakes: int = 0
	for key in ["wrong", "mistakes", "errors", "wrong_bst", "wrong_balance",
				"wrong_delete", "fifo_violation", "service_miss", "lane_miss",
				"overflow_count", "bad_link", "wrong_reverse", "bad_insert",
				"structural_err", "array_shifts"]:
		var v = stats.get(key, 0)
		if v is int:          # ← skip Dictionaries, only sum ints
			mistakes += v
		elif v is Dictionary: # ← sum the values inside a nested mistakes dict
			for mk in v:
				var mv = v[mk]
				if mv is int:
					mistakes += mv

	if mistakes > 0 or correct > 0:
		return correct + mistakes
	return 0

# ─────────────────────────────────────────────────────────────────────────────
#  STATS GRID
# ─────────────────────────────────────────────────────────────────────────────
func _build_stats_grid(stats: Dictionary) -> void:
	for c in _stats_grid.get_children(): c.queue_free()

	_add_stat_row("Score",    str(stats.get("score", 0)),
		Color(1.0, 0.92, 0.4))
	_add_stat_row("Accuracy", "%.0f%%" % float(stats.get("accuracy", 0.0)),
		_accuracy_color(float(stats.get("accuracy", 0.0))))
	_add_stat_row("Correct",  str(stats.get("correct", 0)),
		Color(0.4, 1.0, 0.6))

	if stats.get("enqueue_count", 0) > 0:
		_add_stat_row("Enqueued",  str(stats.get("enqueue_count", 0)))
	if stats.get("dequeue_count", 0) > 0:
		_add_stat_row("Dequeued",  str(stats.get("dequeue_count", 0)))
	if stats.get("peek_count", 0) > 0:
		_add_stat_row("Peek Used", str(stats.get("peek_count", 0)))

	if stats.get("wrong_bst", 0) > 0:
		_add_stat_row("BST Errors",     str(stats.get("wrong_bst")),     Color(1.0, 0.45, 0.35))
	if stats.get("wrong_balance", 0) > 0:
		_add_stat_row("Balance Errors", str(stats.get("wrong_balance")), Color(1.0, 0.45, 0.35))
	if stats.get("wrong_delete", 0) > 0:
		_add_stat_row("Delete Errors",  str(stats.get("wrong_delete")),  Color(1.0, 0.45, 0.35))

	var mistake_keys := {
		"fifo_violation":  "FIFO Violations",
		"service_miss":    "Wrong Service",
		"lane_miss":       "Wrong Lane",
		"overflow_count":  "Overflow Blocks",
		"bad_link":        "Bad Links",
		"wrong_reverse":   "Wrong Reversal",
		"bad_insert":      "Bad Inserts",
		"structural_err":  "Structure Errors",
		"array_shifts":    "Array Shifts",
	}
	for key: String in mistake_keys:
		if stats.get(key, 0) > 0:
			_add_stat_row(mistake_keys[key], str(stats[key]), Color(1.0, 0.45, 0.35))

func _add_stat_row(label: String, value: String,
		color: Color = Color(0.88, 0.88, 0.95)) -> void:
	var k := Label.new()
	k.text = label + " :"
	k.add_theme_font_override("font", _pixel_font)
	k.add_theme_font_size_override("font_size", 15)
	k.add_theme_color_override("font_color", Color(0.55, 0.6, 0.72))
	_stats_grid.add_child(k)

	var v := Label.new()
	v.text = value
	v.add_theme_font_override("font", _pixel_font)
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", color)
	_stats_grid.add_child(v)

func _accuracy_color(pct: float) -> Color:
	if pct >= 90.0: return Color(0.3, 1.0,  0.5)
	if pct >= 70.0: return Color(0.6, 1.0,  0.3)
	if pct >= 50.0: return Color(1.0, 0.85, 0.2)
	return Color(1.0, 0.4, 0.35)

# ─────────────────────────────────────────────────────────────────────────────
#  STARS
# ─────────────────────────────────────────────────────────────────────────────
func _build_stars(count: int) -> void:
	for c in _stars_row.get_children(): c.queue_free()
	for i in range(3):
		var lbl := Label.new()
		lbl.text = "★" if i < count else "☆"
		lbl.add_theme_font_size_override("font_size", 44)
		lbl.add_theme_color_override("font_color",
			Color(1.0, 0.88, 0.12) if i < count else Color(0.25, 0.25, 0.3))
		_stars_row.add_child(lbl)

		# Staggered pop-in for earned stars
		if i < count:
			lbl.scale = Vector2(0.3, 0.3)
			lbl.modulate.a = 0.0
			var tw := lbl.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tw.tween_interval(0.35 + i * 0.15)
			tw.tween_property(lbl, "scale",       Vector2(1.0, 1.0), 0.28)
			tw.parallel().tween_property(lbl, "modulate:a", 1.0,        0.20)

# ─────────────────────────────────────────────────────────────────────────────
#  ANIMATIONS
# ─────────────────────────────────────────────────────────────────────────────
func _animate_entrance() -> void:
	var panel := $Panel as Control

	# Style the panel background
	var sb := StyleBoxFlat.new()
	if _success:
		sb.bg_color         = Color(0.07, 0.09, 0.16, 0.97)
		sb.border_color     = Color(0.3, 0.85, 0.5, 0.9)
	else:
		sb.bg_color         = Color(0.10, 0.06, 0.08, 0.97)
		sb.border_color     = Color(0.85, 0.3, 0.3, 0.8)
	sb.border_width_left   = 2
	sb.border_width_right  = 2
	sb.border_width_top    = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left     = 12
	sb.corner_radius_top_right    = 12
	sb.corner_radius_bottom_left  = 12
	sb.corner_radius_bottom_right = 12
	sb.shadow_color  = Color(0, 0, 0, 0.6)
	sb.shadow_size   = 18
	panel.add_theme_stylebox_override("panel", sb)

	# BG overlay gradient feel — tint it slightly
	_bg.color = Color(0.02, 0.02, 0.06, 0.82) if _success else Color(0.08, 0.02, 0.02, 0.82)

	panel.modulate = Color(1, 1, 1, 0)
	panel.scale    = Vector2(0.80, 0.80)
	panel.pivot_offset = panel.size * 0.5

	var tw := panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0,         0.35)
	tw.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.35)

func _pulse_grade() -> void:
	if _grade_tween:
		_grade_tween.kill()
	_grade_tween = _grade_lbl.create_tween().set_loops()
	_grade_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_grade_tween.tween_property(_grade_lbl, "scale", Vector2(1.08, 1.08), 0.6)
	_grade_tween.tween_property(_grade_lbl, "scale", Vector2(1.0,  1.0),  0.6)
	_grade_lbl.pivot_offset = _grade_lbl.size * 0.5

# ─────────────────────────────────────────────────────────────────────────────
#  CONFETTI
# ─────────────────────────────────────────────────────────────────────────────
func _spawn_confetti() -> void:
	var viewport_size := Vector2(1280, 720)
	var count := 55

	for i in range(count):
		var piece := ColorRect.new()
		piece.size = Vector2(randf_range(6, 12), randf_range(6, 14))
		piece.color = CONFETTI_COLORS[randi() % CONFETTI_COLORS.size()]
		piece.rotation = randf() * TAU

		# Start above the screen at a random horizontal position
		var start_x := randf_range(50, viewport_size.x - 50)
		piece.position = Vector2(start_x, randf_range(-60, -10))

		add_child(piece)
		_confetti_nodes.append(piece)

		var fall_dur  := randf_range(1.6, 3.2)
		var end_y     := viewport_size.y + 40
		var drift_x   := randf_range(-120, 120)
		var end_rot   := piece.rotation + randf_range(-TAU * 2, TAU * 2)
		var delay     := randf_range(0.0, 1.0)

		var tw := piece.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(piece, "position",
			Vector2(start_x + drift_x, end_y), fall_dur).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(piece, "rotation", end_rot, fall_dur)
		tw.parallel().tween_property(piece, "modulate:a", 0.0, fall_dur * 0.5)\
			.set_delay(fall_dur * 0.5)
		tw.tween_callback(piece.queue_free)
		_confetti_nodes.erase(piece)   # will already be freed when callback fires

func _clear_confetti() -> void:
	for n in _confetti_nodes:
		if is_instance_valid(n):
			n.queue_free()
	_confetti_nodes.clear()

# ─────────────────────────────────────────────────────────────────────────────
#  BUTTON STYLING
# ─────────────────────────────────────────────────────────────────────────────
func _style_buttons() -> void:
	var btns := [_retry_btn, _next_btn, _map_btn]
	var colors := [
		Color(0.25, 0.45, 0.9),   # blue  — Retry
		Color(0.2,  0.75, 0.45),  # green — Next
		Color(0.55, 0.35, 0.85),  # purple — Map
	]
	for i in range(btns.size()):
		var btn: Button = btns[i]
		if not is_instance_valid(btn): continue
		btn.add_theme_font_override("font", _pixel_font)
		btn.add_theme_font_size_override("font_size", 15)

		var sb := StyleBoxFlat.new()
		sb.bg_color = colors[i]
		sb.corner_radius_top_left     = 8
		sb.corner_radius_top_right    = 8
		sb.corner_radius_bottom_left  = 8
		sb.corner_radius_bottom_right = 8
		sb.content_margin_left   = 16
		sb.content_margin_right  = 16
		sb.content_margin_top    = 10
		sb.content_margin_bottom = 10
		btn.add_theme_stylebox_override("normal", sb)

		var sb_hover := sb.duplicate() as StyleBoxFlat
		sb_hover.bg_color = colors[i].lightened(0.18)
		btn.add_theme_stylebox_override("hover", sb_hover)

		var sb_press := sb.duplicate() as StyleBoxFlat
		sb_press.bg_color = colors[i].darkened(0.15)
		btn.add_theme_stylebox_override("pressed", sb_press)

# ─────────────────────────────────────────────────────────────────────────────
#  BUTTON CALLBACKS
# ─────────────────────────────────────────────────────────────────────────────
func _on_retry() -> void:
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_BTN)
	_clear_confetti()
	if _grade_tween: _grade_tween.kill()
	visible = false
	if _current_chapter < 1:
		get_tree().reload_current_scene()
		return
	if has_node("/root/GameRouter"):
		GameRouter.retry_chapter(_current_chapter)
	else:
		get_tree().reload_current_scene()

func _on_next() -> void:
	if not _success: return
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_BTN)
	_clear_confetti()
	if _grade_tween: _grade_tween.kill()
	visible = false
	if has_node("/root/GameRouter"):
		var next_ch: int = GameRouter.next_chapter(_current_chapter)
		if next_ch > 0:
			GameRouter.go_to_chapter(next_ch)
		else:
			GameRouter.go_to_world_map()
	else:
		get_tree().reload_current_scene()

func _on_map() -> void:
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_BTN)
	_clear_confetti()
	if _grade_tween: _grade_tween.kill()
	visible = false
	if has_node("/root/GameRouter"):
		GameRouter.go_to_world_map()

# ─────────────────────────────────────────────────────────────────────────────
func _grade_color(grade: String) -> Color:
	match grade:
		"S": return Color(1.0, 0.9,  0.1)
		"A": return Color(0.3, 1.0,  0.45)
		"B": return Color(0.4, 0.85, 1.0)
		"C": return Color(1.0, 0.72, 0.3)
		_:   return Color(1.0, 0.3,  0.3)

func _grade_to_stars(grade: String) -> int:
	match grade:
		"S", "A": return 3
		"B":      return 2
		"C":      return 1
		_:        return 0

func _stars_to_grade(stars: int) -> String:
	match stars:
		3: return "A"
		2: return "B"
		1: return "C"
		_: return "F"
