# =============================================================================
# AdaptiveDifficulty.gd
# Autoload Singleton — Add as "AdaptiveDifficulty" in Project > Autoload
# File: scripts/autoload/AdaptiveDifficulty.gd
#
# Checks player performance BEFORE loading a chapter.
# Adjusts DifficultyManager.current_tier up or down based on recent history.
# GameRouter should call AdaptiveDifficulty.evaluate(chapter_id) before
# loading each chapter scene.
# =============================================================================
extends Node

const PATH_FONT := "res://assets/fonts/freepixel.ttf"

# Thresholds for tier adjustment
const RAISE_STARS_MIN  := 3     # perfect clears needed to raise
const LOWER_STARS_MAX  := 1     # stars at or below this triggers a lower
const HISTORY_CHAPTERS := 3     # how many recent chapters to look back

signal difficulty_adjusted(old_tier: int, new_tier: int, reason: String)

# ─────────────────────────────────────────────────────────────────────────────
#  MAIN API — call before loading each chapter
# ─────────────────────────────────────────────────────────────────────────────
func evaluate(chapter_id: int) -> void:
	if not has_node("/root/PlayerProfile"): return
	if not has_node("/root/DifficultyManager"): return

	var old_tier := DifficultyManager.current_tier

	if _should_lower_difficulty(chapter_id):
		var new_tier: int = max(0, old_tier - 1)
		if new_tier != old_tier:
			DifficultyManager.set_tier(new_tier)
			difficulty_adjusted.emit(old_tier, new_tier,
				"Difficulty lowered — keep practicing!")
			_show_adjustment_toast("Difficulty: %s" % DifficultyManager.tier_name(),
				Color(0.4, 0.8, 1.0))
	# NOTE: We intentionally do NOT raise difficulty here.
	# go_to_chapter() already sets DifficultyManager to the chapter's exact intended
	# tier via CHAPTER_TIER. Raising it further would skip a tier — for example,
	# loading chapter 14 (Hard, tier 3) would get bumped to tier 4 (Expert),
	# which is exactly the Normal→Expert skip bug. Lowering is kept as a player-
	# assist feature for struggling players.

# ─────────────────────────────────────────────────────────────────────────────
#  DIFFICULTY LOGIC — reads from PlayerProfile.progress
#
#  Lower if: any of the last HISTORY_CHAPTERS attempts scored <= LOWER_STARS_MAX
#  Raise if:  all of the last HISTORY_CHAPTERS attempts scored >= RAISE_STARS_MIN
# ─────────────────────────────────────────────────────────────────────────────
func _should_lower_difficulty(chapter_id: int) -> bool:
	var history := _get_recent_stars(chapter_id)
	if history.is_empty(): return false
	for s in history:
		if s <= LOWER_STARS_MAX: return true
	return false

func _should_raise_difficulty(chapter_id: int) -> bool:
	var history := _get_recent_stars(chapter_id)
	if history.size() < HISTORY_CHAPTERS: return false
	for s in history:
		if s < RAISE_STARS_MIN: return false
	return true

# Returns star counts for the HISTORY_CHAPTERS chapters ending at chapter_id - 1
func _get_recent_stars(chapter_id: int) -> Array[int]:
	var result: Array[int] = []
	for i in range(HISTORY_CHAPTERS):
		var cid := chapter_id - 1 - i
		if cid < 1: break
		var d := PlayerProfile.progress.get(cid, {}) as Dictionary
		if d.get("complete", false):
			result.append(d.get("stars", 0) as int)
	return result

# ─────────────────────────────────────────────────────────────────────────────
#  TOAST — small overlay notification shown briefly
# ─────────────────────────────────────────────────────────────────────────────
func _show_adjustment_toast(text: String, color: Color) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 200
	get_tree().root.add_child(cl)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", load(PATH_FONT) as Font)
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_shadow_color", Color.BLACK)
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(340, 40)
	cl.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(cl.queue_free)
