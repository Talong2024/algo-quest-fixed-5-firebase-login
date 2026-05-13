# =============================================================================
# ChapterCompleteScreen.gd
# File: scripts/ui/ChapterCompleteScreen.gd
#
# FIXES:
#   - _current_chapter default was 16 (Tree chapter) — now -1 so a bad state
#     is immediately obvious instead of silently retrying the wrong chapter.
#   - show_result() now accepts BOTH calling conventions that GameRouter uses:
#       A) show_result(chapter_id, stats_dict)          ← standard path
#       B) chapter_complete(chapter_id, score, stars)   ← LinkedList / old games
#     In convention B, score and stars arrive as positional args, not inside
#     a dict, which is why the score was always 0 on the results screen.
#   - _on_retry() guards against _current_chapter == -1 and falls back to
#     reload_current_scene() so it never routes to the wrong chapter.
# =============================================================================

extends CanvasLayer

const PATH_FONT     := "res://assets/fonts/freepixel.ttf"
const PATH_SFX_WIN  := "res://assets/codemon/audio/sfx/level_up.ogg"
const PATH_SFX_FAIL := "res://assets/codemon/audio/sfx/fail.ogg"
const PATH_SFX_BTN  := "res://assets/codemon/audio/sfx/button.ogg"

const CHAPTER_NAMES := {
	# Queue
	1:  "Kingdom Gate  [Beginner]",
	2:  "Kingdom Gate  [Easy]",
	3:  "Kingdom Gate  [Normal]",
	4:  "Kingdom Gate  [Hard]",
	5:  "Kingdom Gate  [Expert]",
	# Stack
	6:  "Castle of Echoes  [Beginner]",
	7:  "Castle of Echoes  [Easy]",
	8:  "Castle of Echoes  [Normal]",
	9:  "Castle of Echoes  [Hard]",
	10: "Castle of Echoes  [Expert]",
	# LinkedList
	11: "Chain Station  [Beginner]",
	12: "Chain Station  [Easy]",
	13: "Chain Station  [Normal]",
	14: "Chain Station  [Hard]",
	15: "Chain Station  [Expert]",
	# Tree
	16: "Oracle's Forest  [Beginner]",
	17: "Oracle's Forest  [Easy]",
	18: "Oracle's Forest  [Normal]",
	19: "Oracle's Forest  [Hard]",
	20: "Oracle's Forest  [Expert]",
	# Graph
	21: "Kingdom Roads  [Beginner]",
	22: "Kingdom Roads  [Easy]",
	23: "Kingdom Roads  [Normal]",
	24: "Kingdom Roads  [Hard]",
	25: "Kingdom Roads  [Expert]",
}

const CHAPTER_CONCEPTS := {
	# Queue
	1:  "FIFO — First In, First Out.\nEnqueue adds to the BACK. Dequeue removes from the FRONT.\nReal use: task scheduling, print queues, BFS.",
	2:  "SERVICE QUEUES — Peek first, select service, then dequeue.\nReal use: priority dispatching, customer service systems.",
	3:  "OVERFLOW — Queues have capacity limits.\nCannot enqueue when full — must dequeue first.\nReal use: bounded buffers, network packet queues.",
	4:  "MULTI-LANE — Two queues in parallel.\nEnqueue each item into the correct lane.\nReal use: multi-threaded task queues, lane routing.",
	5:  "EXPERT QUEUES — All rules active simultaneously.\nPriority items break FIFO order.\nReal use: priority queues, OS scheduling algorithms.",
	# Stack
	6:  "LIFO — Last In, First Out.\nPush adds to top. Pop removes from top.\nReal use: undo systems, function call stacks.",
	7:  "STACK EXPRESSIONS — Evaluate postfix with a stack.\nReal use: calculators, compilers, expression parsing.",
	8:  "STACK OVERFLOW — Stacks have depth limits.\nReal use: recursion limits, memory management.",
	9:  "BALANCED BRACKETS — Use a stack to match pairs.\nReal use: syntax checking, HTML/XML validation.",
	10: "EXPERT STACK — All stack rules combined.\nReal use: DFS graph traversal, backtracking algorithms.",
	# LinkedList
	11: "LINKED LIST — Nodes connected by pointers.\nInsertion/deletion O(1) at head. Access O(n).\nReal use: dynamic memory, music playlists.",
	12: "INSERTION — Add nodes at head, tail, or middle.\nReal use: dynamic arrays, hash chaining.",
	13: "DELETION — Remove nodes by value or position.\nMust update the previous node's pointer.\nReal use: LRU cache, memory deallocation.",
	14: "REVERSAL — Reverse a linked list in-place.\nClassic interview problem — three pointer technique.\nReal use: undo stacks, palindrome detection.",
	15: "EXPERT LIST — Merge, cycle detection, and sorting.\nReal use: mergesort, OS process scheduling.",
	# Tree
	16: "BST BASICS — Binary Search Tree.\nLeft child < Parent < Right child — always.\nDrag nodes to green slots to build a valid BST.",
	17: "BST WITHOUT GUIDES — Apply the rule yourself.\nAt every node: is my value less or greater?\nLeft < Parent < Right — no hints, same rule.",
	18: "INORDER TRAVERSAL — Visit Left → Root → Right.\nInorder BST traversal always produces sorted output.\nReal use: sorting, range queries, expression trees.",
	19: "AVL BALANCE — |Left height − Right height| ≤ 1.\nUnbalanced BST degrades to O(n) search.\nReal use: self-balancing trees used in databases.",
	20: "BST EXPERT — Place, delete leaves, rebalance.\nDeletion + rebalancing is the hardest BST operation.\nReal use: AVL trees, Red-Black trees, B-trees.",
	# Graph
	21: "GRAPH BASICS — Nodes connected by edges.\nBFS visits nearest neighbours first.\nReal use: maps, social networks, shortest path.",
	22: "BFS — Breadth-First Search uses a queue.\nVisits all nodes at distance d before d+1.\nReal use: shortest path in unweighted graphs.",
	23: "DFS — Depth-First Search uses a stack.\nGoes deep before backtracking.\nReal use: maze solving, topological sort, cycle detection.",
	24: "WEIGHTED GRAPHS — Edges have costs.\nDijkstra's algorithm finds the cheapest path.\nReal use: GPS navigation, network routing.",
	25: "EXPERT GRAPH — MST, connectivity, and flow.\nKruskal's and Prim's build minimum spanning trees.\nReal use: network design, clustering algorithms.",
}

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

# -1 = not yet set; prevents retry routing to the wrong chapter on first open
var _current_chapter: int  = -1
var _success:         bool = false
var _pixel_font:      Font = null

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) as Font
	layer   = 100
	visible = false

	for lbl: Label in [_title_lbl, _chapter_lbl, _grade_lbl, _concept_lbl]:
		if is_instance_valid(lbl):
			lbl.add_theme_font_override("font", _pixel_font)
	_grade_lbl.add_theme_font_size_override("font_size", 72)

	_retry_btn.pressed.connect(_on_retry)
	_next_btn.pressed.connect(_on_next)
	_map_btn.pressed.connect(_on_map)

# ─────────────────────────────────────────────────────────────────────────────
#  PUBLIC ENTRY POINT
#
#  Accepts two calling conventions so this screen works with every game module:
#
#  Convention A — full stats dict (new standard):
#    show_result(chapter_id: int, stats: Dictionary)
#    stats must contain at minimum: { "score": int, "success": bool }
#    optionally: "grade", "stars", "accuracy", "correct", plus game-specific keys
#
#  Convention B — positional score + stars (legacy / LinkedList):
#    show_result(chapter_id: int, score: int, stars: int)
#    This is what GameRouter.chapter_complete forwards when games call
#    chapter_complete(id, score, stars) instead of passing a full dict.
#    The screen builds a minimal stats dict from those three values.
# ─────────────────────────────────────────────────────────────────────────────
func show_result(chapter_id: int, stats_or_score, stars_if_positional: int = -1) -> void:
	_current_chapter = chapter_id

	# Normalise to a stats dict regardless of which convention was used
	var stats: Dictionary
	if stats_or_score is Dictionary:
		stats = stats_or_score
	else:
		# Convention B: stats_or_score is the raw score int
		var raw_score: int = int(stats_or_score)
		var raw_stars: int = stars_if_positional if stars_if_positional >= 0 else 0
		stats = {
			"score":   raw_score,
			"stars":   raw_stars,
			"success": raw_stars > 0,
			"grade":   _stars_to_grade(raw_stars),
		}

	_success = stats.get("success", false)

	_title_lbl.text = "CHAPTER COMPLETE!" if _success else "CHAPTER FAILED"
	_title_lbl.add_theme_color_override("font_color",
		Color(0.3, 1.0, 0.4) if _success else Color(1.0, 0.3, 0.3))

	_chapter_lbl.text = "Chapter %d — %s" % [
		chapter_id, CHAPTER_NAMES.get(chapter_id, "Chapter %d" % chapter_id)]

	var grade: String = stats.get("grade", _stars_to_grade(stats.get("stars", 0)))
	_grade_lbl.text = grade
	_grade_lbl.add_theme_color_override("font_color", _grade_color(grade))

	var stars: int = stats.get("stars", _grade_to_stars(grade))
	_build_stars(stars)
	_build_stats_grid(stats)

	_concept_lbl.text = CHAPTER_CONCEPTS.get(chapter_id,
		"Keep practising — every mistake teaches you something.")

	# Next button — only enabled on success and if a next chapter exists
	var next_ch: int = GameRouter.next_chapter(chapter_id) \
		if has_node("/root/GameRouter") else -1
	if next_ch > 0 and _success:
		_next_btn.disabled = false
		_next_btn.modulate = Color.WHITE
		_next_btn.text     = "Next: %s →" % CHAPTER_NAMES.get(next_ch, "Next Level")
	else:
		_next_btn.disabled = true
		_next_btn.modulate = Color(0.4, 0.4, 0.4)
		_next_btn.text     = "Next Level"

	visible = true
	_animate_entrance()

	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(PATH_SFX_WIN if _success else PATH_SFX_FAIL)
	# Note: save_chapter_result is called by GameRouter.chapter_complete before
	# this screen is shown — no need to save again here.

# ─────────────────────────────────────────────────────────────────────────────
func _build_stats_grid(stats: Dictionary) -> void:
	for c in _stats_grid.get_children(): c.queue_free()

	_add_stat_row("Score",    str(stats.get("score", 0)))
	_add_stat_row("Accuracy", "%.0f%%" % float(stats.get("accuracy", 0.0)))
	_add_stat_row("Correct",  str(stats.get("correct", 0)))

	# Queue-specific
	if stats.get("enqueue_count", 0) > 0:
		_add_stat_row("Enqueued",  str(stats.get("enqueue_count", 0)))
	if stats.get("dequeue_count", 0) > 0:
		_add_stat_row("Dequeued",  str(stats.get("dequeue_count", 0)))
	if stats.get("peek_count", 0) > 0:
		_add_stat_row("Peek Used", str(stats.get("peek_count", 0)))

	# Tree-specific
	if stats.get("wrong_bst", 0) > 0:
		_add_stat_row("BST Errors",     str(stats.get("wrong_bst")),     Color(1.0, 0.5, 0.4))
	if stats.get("wrong_balance", 0) > 0:
		_add_stat_row("Balance Errors", str(stats.get("wrong_balance")), Color(1.0, 0.5, 0.4))
	if stats.get("wrong_delete", 0) > 0:
		_add_stat_row("Delete Errors",  str(stats.get("wrong_delete")),  Color(1.0, 0.5, 0.4))

	# Generic mistakes
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
			_add_stat_row(mistake_keys[key], str(stats[key]), Color(1.0, 0.5, 0.4))

func _add_stat_row(label: String, value: String,
		color: Color = Color(0.9, 0.9, 0.9)) -> void:
	var k := Label.new()
	k.text = label
	k.add_theme_font_override("font", _pixel_font)
	k.add_theme_font_size_override("font_size", 15)
	k.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_stats_grid.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_font_override("font", _pixel_font)
	v.add_theme_font_size_override("font_size", 15)
	v.add_theme_color_override("font_color", color)
	_stats_grid.add_child(v)

func _build_stars(count: int) -> void:
	for c in _stars_row.get_children(): c.queue_free()
	for i in range(3):
		var lbl := Label.new()
		lbl.text = "★" if i < count else "☆"
		lbl.add_theme_font_size_override("font_size", 36)
		lbl.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.1) if i < count else Color(0.3, 0.3, 0.3))
		_stars_row.add_child(lbl)

func _animate_entrance() -> void:
	var panel := $Panel as Control
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale    = Vector2(0.85, 0.85)
	var tw := panel.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(panel, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(panel, "scale", Vector2(1, 1), 0.3)

# ─────────────────────────────────────────────────────────────────────────────
func _on_retry() -> void:
	if has_node("/root/AudioManager"): AudioManager.play_sfx(PATH_SFX_BTN)
	visible = false
	# Guard: if chapter was never set correctly, reload in place rather than
	# routing to whatever _current_chapter defaults to.
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
	visible = false
	if has_node("/root/GameRouter"):
		GameRouter.go_to_world_map()

# ─────────────────────────────────────────────────────────────────────────────
func _grade_color(grade: String) -> Color:
	match grade:
		"S": return Color(1.0, 0.85, 0.1)
		"A": return Color(0.3, 1.0,  0.4)
		"B": return Color(0.4, 0.8,  1.0)
		"C": return Color(1.0, 0.7,  0.3)
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
