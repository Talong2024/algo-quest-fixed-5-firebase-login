# =============================================================================
# GameRouter.gd
# Autoload Singleton — Registered as "GameRouter" in Project > Autoload
# File: scripts/autoload/GameRouter.gd
#
# Chapter layout (5 tiers per chapter family, Beginner → Expert):
#   1–5   → QueueGame      (tier 0=Beginner … tier 4=Expert)
#   6–10  → StackGame      (tier 0=Beginner … tier 4=Expert)
#   11–15 → LinkedListGame (tier 0=Beginner … tier 4=Expert)
#   16–20 → TreeGame       (tier 0=Beginner … tier 4=Expert)
#   21–25 → GraphGame      (tier 0=Beginner … tier 4=Expert)
# =============================================================================

extends Node

var current_chapter: int = 1   # Queue Beginner

const CHAPTER_SCENES: Dictionary = {
	1:  "res://scenes/chapters/queue/QueueGame.tscn",
	2:  "res://scenes/chapters/queue/QueueGame.tscn",
	3:  "res://scenes/chapters/queue/QueueGame.tscn",
	4:  "res://scenes/chapters/queue/QueueGame.tscn",
	5:  "res://scenes/chapters/queue/QueueGame.tscn",
	6:  "res://scenes/chapters/stack/StackGame.tscn",
	7:  "res://scenes/chapters/stack/StackGame.tscn",
	8:  "res://scenes/chapters/stack/StackGame.tscn",
	9:  "res://scenes/chapters/stack/StackGame.tscn",
	10: "res://scenes/chapters/stack/StackGame.tscn",
	11: "res://scenes/chapters/linked_list/LinkedListGame.tscn",
	12: "res://scenes/chapters/linked_list/LinkedListGame.tscn",
	13: "res://scenes/chapters/linked_list/LinkedListGame.tscn",
	14: "res://scenes/chapters/linked_list/LinkedListGame.tscn",
	15: "res://scenes/chapters/linked_list/LinkedListGame.tscn",
	16: "res://scenes/chapters/tree/TreeGame.tscn",
	17: "res://scenes/chapters/tree/TreeGame.tscn",
	18: "res://scenes/chapters/tree/TreeGame.tscn",
	19: "res://scenes/chapters/tree/TreeGame.tscn",
	20: "res://scenes/chapters/tree/TreeGame.tscn",
	21: "res://scenes/chapters/graph/GraphGame.tscn",
	22: "res://scenes/chapters/graph/GraphGame.tscn",
	23: "res://scenes/chapters/graph/GraphGame.tscn",
	24: "res://scenes/chapters/graph/GraphGame.tscn",
	25: "res://scenes/chapters/graph/GraphGame.tscn",
}

const CHAPTER_TIER: Dictionary = {
	1:  0, 2:  1, 3:  2, 4:  3, 5:  4,
	6:  0, 7:  1, 8:  2, 9:  3, 10: 4,
	11: 0, 12: 1, 13: 2, 14: 3, 15: 4,
	16: 0, 17: 1, 18: 2, 19: 3, 20: 4,
	21: 0, 22: 1, 23: 2, 24: 3, 25: 4,
}

const FAMILY_RANGES: Dictionary = {
	"queue":       [1,  5],
	"stack":       [6,  10],
	"linked_list": [11, 15],
	"tree":        [16, 20],
	"graph":       [21, 25],
}

# ── Navigation ────────────────────────────────────────────────────────────────
func go_to_login() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/LoginScreen.tscn")

func go_to_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/MainMenu.tscn")

func go_to_world_map() -> void:
	get_tree().change_scene_to_file("res://scenes/world_map/WorldMap.tscn")


func go_progress_screen() -> void:
	if ResourceLoader.exists("res://scenes/ui/ProgressScreen.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/ProgressScreen.tscn")

func go_settings() -> void:
	if ResourceLoader.exists("res://scenes/ui/Settings.tscn"):
		get_tree().change_scene_to_file("res://scenes/ui/Settings.tscn")

func go_to_chapter(chapter_id: int) -> void:
	if chapter_id not in CHAPTER_SCENES:
		go_to_world_map()
		return

	current_chapter = chapter_id

	var target_tier: int = CHAPTER_TIER.get(chapter_id, 0)
	if has_node("/root/DifficultyManager"):
		DifficultyManager.set_tier(target_tier)
	if has_node("/root/AdaptiveDifficulty"):
		AdaptiveDifficulty.evaluate(chapter_id)

	get_tree().change_scene_to_file(CHAPTER_SCENES[chapter_id])

func retry_chapter(chapter_id: int) -> void:
	current_chapter = chapter_id
	var target_tier: int = CHAPTER_TIER.get(chapter_id, 0)
	if has_node("/root/DifficultyManager"):
		DifficultyManager.set_tier(target_tier)
	if chapter_id in CHAPTER_SCENES:
		get_tree().change_scene_to_file(CHAPTER_SCENES[chapter_id])

func chapter_complete(chapter_id: int, score: int, stars: int) -> void:
	# Save result to PlayerProfile (Firestore) before showing the screen
	if has_node("/root/PlayerProfile"):
		PlayerProfile.save_chapter_result(chapter_id, score, stars)
	# FIX: also save to SaveManager (local + RTDB) so both systems stay in sync
	if has_node("/root/SaveManager"):
		SaveManager.save_chapter_result(chapter_id, {
			"score":    score,
			"stars":    stars,
			"grade":    _stars_to_grade(stars),
			"success":  stars > 0,
			"accuracy": 0.0,
		})

	var screen_scene := "res://scenes/ui/ChapterCompleteScreen.tscn"
	if not ResourceLoader.exists(screen_scene):
		go_to_world_map()
		return

	var screen: Node = load(screen_scene).instantiate()
	get_tree().root.add_child(screen)

	var ch_data: Dictionary = {}
	if has_node("/root/PlayerProfile"):
		ch_data = PlayerProfile.get_chapter_data(chapter_id)

	ch_data["score"]   = score
	ch_data["stars"]   = stars
	ch_data["success"] = stars > 0
	ch_data["grade"]   = _stars_to_grade(stars)

	if screen.has_method("show_result"):
		screen.call("show_result", chapter_id, ch_data)

# ── chapter_complete_with_stats ───────────────────────────────────────────────
# Called by QueueGame (and other game scenes) with full stats dict so that
# accuracy / correct count / grade all appear correctly on ChapterCompleteScreen.
# stats dict keys: score, stars, grade, accuracy, correct, success
func chapter_complete_with_stats(chapter_id: int, stats: Dictionary) -> void:
	if has_node("/root/PlayerProfile"):
		PlayerProfile.save_chapter_result(
			chapter_id,
			stats.get("score",    0),
			stats.get("stars",    0),
			stats.get("accuracy", 0.0)
		)
	# FIX: also save to SaveManager (local + RTDB) so both systems stay in sync
	if has_node("/root/SaveManager"):
		SaveManager.save_chapter_result(chapter_id, stats)

	var screen_scene := "res://scenes/ui/ChapterCompleteScreen.tscn"
	if not ResourceLoader.exists(screen_scene):
		go_to_world_map()
		return

	var screen: Node = load(screen_scene).instantiate()
	get_tree().root.add_child(screen)

	if screen.has_method("show_result"):
		screen.call("show_result", chapter_id, stats)

# ── Family helpers ─────────────────────────────────────────────────────────────
func get_family(chapter_id: int) -> String:
	for family in FAMILY_RANGES:
		var r: Array = FAMILY_RANGES[family]
		if chapter_id >= r[0] and chapter_id <= r[1]:
			return family
	return ""

func get_family_range(chapter_id: int) -> Array:
	var family := get_family(chapter_id)
	return FAMILY_RANGES.get(family, [chapter_id, chapter_id])

func family_start(chapter_id: int) -> int:
	return get_family_range(chapter_id)[0]

func family_end(chapter_id: int) -> int:
	return get_family_range(chapter_id)[1]

func tier_in_family(chapter_id: int) -> int:
	return chapter_id - family_start(chapter_id)

# Next chapter — stays within the same chapter FAMILY (same DSA topic).
# Returns -1 when the player has finished the last tier (Expert, tier 4)
# of the current family, which tells ChapterCompleteScreen to go back to
# the world map so the player can choose the next chapter themselves.
#
# Tier layout per family (5 chapters each):
#   family_start+0 = Beginner (tier 0)
#   family_start+1 = Easy     (tier 1)
#   family_start+2 = Normal   (tier 2)
#   family_start+3 = Hard     (tier 3)
#   family_start+4 = Expert   (tier 4)  ← last tier
#
# Example (Queue family, chapters 1–5):
#   next_chapter(1) → 2  (Beginner → Easy)
#   next_chapter(3) → 4  (Normal   → Hard)
#   next_chapter(4) → 5  (Hard     → Expert)
#   next_chapter(5) → -1 (Expert is last → return to world map)
func next_chapter(chapter_id: int) -> int:
	var fam_end: int = family_end(chapter_id)
	var next:    int = chapter_id + 1
	# Only advance if still inside the same family
	if next <= fam_end and next in CHAPTER_SCENES:
		return next
	# Expert tier (last in family) — caller returns player to world map
	return -1

func queue_tier_to_chapter(tier: int) -> int:
	return clamp(1  + tier, 1,  5)

func stack_tier_to_chapter(tier: int) -> int:
	return clamp(6  + tier, 6,  10)

func linked_list_tier_to_chapter(tier: int) -> int:
	return clamp(11 + tier, 11, 15)

func tree_tier_to_chapter(tier: int) -> int:
	return clamp(16 + tier, 16, 20)

func graph_tier_to_chapter(tier: int) -> int:
	return clamp(21 + tier, 21, 25)

func _stars_to_grade(stars: int) -> String:
	match stars:
		3: return "S"
		2: return "B"
		1: return "C"
		_: return "F"
