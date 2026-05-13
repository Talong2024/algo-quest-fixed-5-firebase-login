# =============================================================================
# ProgressTracker.gd
# Autoload Singleton — Add as "ProgressTracker" in Project > Autoload
# File: scripts/autoload/ProgressTracker.gd
#
# Handles per-session analytics logging called from all chapter scripts.
# Bridges to SaveManager for persistence and Firebase for backend upload.
# =============================================================================

extends Node

# Session-level action log (cleared each chapter start)
var _session_log: Array = []
var _chapter_start_time: int = 0
var _current_chapter: int = 0

signal action_logged(chapter: String, action: String, data: Dictionary)

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	pass

# ─────────────────────────────────────────────────────────────────────────────
#  CALLED BY CHAPTER SCRIPTS
# ─────────────────────────────────────────────────────────────────────────────
func start_chapter(chapter_id: int) -> void:
	_current_chapter  = chapter_id
	_chapter_start_time = Time.get_ticks_msec()
	_session_log.clear()

func log_action(chapter: String, action: String, data: Dictionary) -> void:
	var entry := {
		"chapter":   chapter,
		"action":    action,
		"data":      data,
		"elapsed_ms": Time.get_ticks_msec() - _chapter_start_time,
	}
	_session_log.append(entry)
	action_logged.emit(chapter, action, data)
	# Forward to Firebase (non-blocking)
	if has_node("/root/SaveManager"):
		SaveManager.push_action_log(chapter, action, data)

func complete_chapter(chapter_id: int, stats: Dictionary) -> void:
	stats["time_seconds"] = (Time.get_ticks_msec() - _chapter_start_time) / 1000
	stats["action_count"] = _session_log.size()
	if has_node("/root/SaveManager"):
		SaveManager.save_chapter_result(chapter_id, stats)

# ─────────────────────────────────────────────────────────────────────────────
#  QUERIES (for adaptive difficulty or WorldMap display)
# ─────────────────────────────────────────────────────────────────────────────
func get_recent_accuracy(chapter_id: int) -> float:
	if not has_node("/root/SaveManager"): return 0.0
	var ch := SaveManager.get_chapter_data(chapter_id)
	var history: Array = ch.get("stats_history", [])
	if history.is_empty(): return 0.0
	# Average accuracy of last 3 attempts
	var count := mini(3, history.size())
	var total := 0.0
	for i in range(history.size()-count, history.size()):
		total += history[i].get("accuracy", 0.0)
	return total / count

func should_lower_difficulty(chapter_id: int) -> bool:
	# If last 3 attempts all failed and accuracy < 50%
	if not has_node("/root/SaveManager"): return false
	var ch := SaveManager.get_chapter_data(chapter_id)
	var history: Array = ch.get("stats_history", [])
	if history.size() < 3: return false
	var last3 := history.slice(history.size()-3)
	var fail_count := 0
	var acc_sum    := 0.0
	for entry in last3:
		if entry.get("grade","") in ["F","C"]: fail_count += 1
		acc_sum += entry.get("accuracy",0.0)
	return fail_count >= 2 and (acc_sum/3.0) < 50.0

func should_raise_difficulty(chapter_id: int) -> bool:
	# If last 3 attempts all S/A grade
	if not has_node("/root/SaveManager"): return false
	var ch := SaveManager.get_chapter_data(chapter_id)
	var history: Array = ch.get("stats_history", [])
	if history.size() < 3: return false
	var last3 := history.slice(history.size()-3)
	for entry in last3:
		if entry.get("grade","") not in ["S","A"]: return false
	return true
