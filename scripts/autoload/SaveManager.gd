# =============================================================================
# SaveManager.gd
# Autoload Singleton — Add as "SaveManager" in Project > Autoload
# File: scripts/autoload/SaveManager.gd
#
# Chapters 1-25 across five topics:
#   Queue      1-5   (Kingdom Gate)
#   Stack      6-10  (Castle of Echoes)
#   LinkedList 11-15 (Chain Station)
#   Tree       16-20 (Oracle's Forest)
#   Graph      21-25 (Kingdom Roads)
#
# Unlock rules:
#   - Chapter 1  always unlocked.
#   - Within a topic (e.g. 6-10): previous chapter must be completed.
#   - First chapter of each new topic (6,11,16,21): the last chapter of the
#     previous topic must be completed (ch 5, 10, 15, 20).
# =============================================================================

extends Node

const SAVE_PATH := "user://algoquest_save.json"

const DEFAULT_CHAPTER := {
	"best_score": 0, "best_grade": "", "stars": 0,
	"attempts": 0, "completed": false, "stats_history": []
}

# Helper to produce a clean chapter slot — used in DEFAULT_SAVE below
const _CH := {
	"best_score":0,"best_grade":"","stars":0,
	"attempts":0,"completed":false,"stats_history":[]
}

const DEFAULT_SAVE := {
	"player_name":        "Player",
	"selected_hero":      "",   # hero key chosen in CharacterSelect
	"total_score":        0,
	"current_tier":       0,
	"chapters": {
		# ── Queue (Kingdom Gate) ──────────────────────────────────────────────
		"1":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"2":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"3":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"4":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"5":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		# ── Stack (Castle of Echoes) ─────────────────────────────────────────
		"6":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"7":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"8":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"9":  {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"10": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		# ── LinkedList (Chain Station) ───────────────────────────────────────
		"11": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"12": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"13": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"14": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"15": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		# ── Tree (Oracle's Forest) ───────────────────────────────────────────
		"16": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"17": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"18": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"19": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"20": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		# ── Graph (Kingdom Roads) ────────────────────────────────────────────
		"21": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"22": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"23": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"24": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
		"25": {"best_score":0,"best_grade":"","stars":0,"attempts":0,"completed":false,"stats_history":[]},
	},
	"total_playtime_sec": 0,
}

var _data: Dictionary = {}
var _session_start: int = 0

signal save_completed
signal chapter_unlocked(chapter_id: int)

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_session_start = Time.get_ticks_msec()
	load_game()

# ─────────────────────────────────────────────────────────────────────────────
#  LOAD / SAVE
# ─────────────────────────────────────────────────────────────────────────────
func load_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var result = JSON.parse_string(f.get_as_text())
		f.close()
		if result is Dictionary:
			_data = _merge_with_default(result)
			return
	_data = DEFAULT_SAVE.duplicate(true)

func _merge_with_default(loaded: Dictionary) -> Dictionary:
	var merged: Dictionary = DEFAULT_SAVE.duplicate(true)
	for key in loaded:
		if key == "chapters":
			for ch: String in loaded["chapters"]:
				if ch in merged["chapters"]:
					(merged["chapters"][ch] as Dictionary).merge(
						loaded["chapters"][ch] as Dictionary, true)
				else:
					# Slot not in default (save from older version) — keep it
					merged["chapters"][ch] = loaded["chapters"][ch]
		else:
			merged[key] = loaded[key]
	return merged

func save_game() -> void:
	var elapsed: int = (Time.get_ticks_msec() - _session_start) / 1000
	_data["total_playtime_sec"] = _data.get("total_playtime_sec", 0) + elapsed
	_session_start = Time.get_ticks_msec()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(_data, "\t"))
	f.close()
	save_completed.emit()
	_push_to_firebase()

# ─────────────────────────────────────────────────────────────────────────────
#  CHAPTER RESULTS
# ─────────────────────────────────────────────────────────────────────────────
func save_chapter_result(chapter_id: int, stats: Dictionary) -> void:
	var key: String = str(chapter_id)
	if key not in _data["chapters"]:
		_data["chapters"][key] = DEFAULT_CHAPTER.duplicate(true)

	var ch: Dictionary = _data["chapters"][key] as Dictionary
	ch["attempts"] = ch.get("attempts", 0) + 1

	var new_score: int    = stats.get("score", 0)
	var new_grade: String = stats.get("grade", "")
	var new_stars: int    = stats.get("stars", 0)
	var success:   bool   = stats.get("success", false)

	if new_score > ch.get("best_score", 0):   ch["best_score"] = new_score
	if new_stars > ch.get("stars",      0):   ch["stars"]      = new_stars
	if _grade_rank(new_grade) > _grade_rank(ch.get("best_grade", "")):
		ch["best_grade"] = new_grade

	if success and not ch.get("completed", false):
		ch["completed"] = true
		# Emit unlock for the next chapter (if one exists within the 1-25 range)
		if chapter_id < 25:
			chapter_unlocked.emit(chapter_id + 1)

	var history: Array = ch.get("stats_history", [])
	history.append({
		"score":    new_score,
		"grade":    new_grade,
		"accuracy": stats.get("accuracy", 0.0),
		"time":     Time.get_datetime_string_from_system(),
	})
	if history.size() > 10:
		history = history.slice(history.size() - 10)
	ch["stats_history"] = history

	_data["total_score"] = _data.get("total_score", 0) + new_score
	save_game()

# ─────────────────────────────────────────────────────────────────────────────
#  UNLOCK LOGIC
#
#  Topic groups and their gate chapters (last chapter of the previous topic):
#    Queue      1- 5  → always starts open
#    Stack      6-10  → requires ch 5  completed
#    LinkedList 11-15 → requires ch 10 completed
#    Tree       16-20 → requires ch 15 completed
#    Graph      21-25 → requires ch 20 completed
# ─────────────────────────────────────────────────────────────────────────────
func is_chapter_unlocked(chapter_id: int) -> bool:
	# Chapter 1 always unlocked
	if chapter_id <= 1:
		return true

	# Out of range
	if chapter_id > 25:
		return false

	# First chapter of each topic requires the previous topic's final chapter
	match chapter_id:
		6:  return _chapter_completed(5)
		11: return _chapter_completed(10)
		16: return _chapter_completed(15)
		21: return _chapter_completed(20)

	# All other chapters: just need the previous one completed
	return _chapter_completed(chapter_id - 1)

func _chapter_completed(chapter_id: int) -> bool:
	return (_data["chapters"].get(str(chapter_id), {}) as Dictionary).get("completed", false)

# ─────────────────────────────────────────────────────────────────────────────
#  GETTERS
# ─────────────────────────────────────────────────────────────────────────────
func get_chapter_data(chapter_id: int) -> Dictionary:
	return (_data["chapters"].get(str(chapter_id), {}) as Dictionary).duplicate()

func get_best_score(chapter_id: int) -> int:
	return (_data["chapters"].get(str(chapter_id), {}) as Dictionary).get("best_score", 0)

func get_stars(chapter_id: int) -> int:
	return (_data["chapters"].get(str(chapter_id), {}) as Dictionary).get("stars", 0)

func get_player_name() -> String:   return _data.get("player_name", "Player")
func get_total_score() -> int:      return _data.get("total_score", 0)
func get_playtime_seconds() -> int: return _data.get("total_playtime_sec", 0)

# ── Hero selection ─────────────────────────────────────────────────────────────
func get_selected_hero() -> String:
	return _data.get("selected_hero", "")

func set_selected_hero(hero_key: String) -> void:
	_data["selected_hero"] = hero_key
	save_game()

# ── Setters ────────────────────────────────────────────────────────────────────
func set_player_name(name: String) -> void:
	_data["player_name"] = name
	save_game()

func reset_all() -> void:
	_data = DEFAULT_SAVE.duplicate(true)
	save_game()

# ─────────────────────────────────────────────────────────────────────────────
#  FIREBASE
# ─────────────────────────────────────────────────────────────────────────────
const _FB_DB := "https://algoquest-3f812-default-rtdb.asia-southeast1.firebasedatabase.app"

func _push_to_firebase() -> void:
	var uid:   String = _data.get("uid", "")
	var token: String = _data.get("id_token", "")
	if uid.is_empty() or token.is_empty(): return
	var http := HTTPRequest.new()
	add_child(http)
	var url    := "%s/players/%s/save.json?auth=%s" % [_FB_DB, uid, token]
	var upload := _data.duplicate()
	upload.erase("id_token")
	http.request(url, ["Content-Type: application/json"],
		HTTPClient.METHOD_PUT, JSON.stringify(upload))
	http.request_completed.connect(func(_r,_c,_h,_b): http.queue_free())

func push_action_log(chapter: String, action: String, payload: Dictionary) -> void:
	var uid:   String = _data.get("uid", "")
	var token: String = _data.get("id_token", "")
	if uid.is_empty() or token.is_empty(): return
	var http := HTTPRequest.new()
	add_child(http)
	var ts  := str(Time.get_ticks_msec())
	var url := "%s/players/%s/logs/%s/%s.json?auth=%s" % [_FB_DB, uid, chapter, ts, token]
	http.request(url, ["Content-Type: application/json"],
		HTTPClient.METHOD_PUT, JSON.stringify({"action":action,"data":payload,"time":ts}))
	http.request_completed.connect(func(_r,_c,_h,_b): http.queue_free())

# ─────────────────────────────────────────────────────────────────────────────
func _grade_rank(grade: String) -> int:
	match grade:
		"S": return 5
		"A": return 4
		"B": return 3
		"C": return 2
		"F": return 1
		_:   return 0
