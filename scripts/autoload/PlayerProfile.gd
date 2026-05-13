# =============================================================================
# PlayerProfile.gd — Autoload
# File: scripts/autoload/PlayerProfile.gd
#
# Single source of truth for the logged-in player.
# Reads/writes to Firestore: users/{uid}
# Works with LoginScreen.gd, WorldMap.gd, QueueGame.gd, StackGame.gd
#
# ADD TO: Project → Project Settings → Autoload
#   Name: PlayerProfile
#   Path: res://scripts/autoload/PlayerProfile.gd
# =============================================================================

extends Node

# ─────────────────────────────────────────────────────────────────────────────
#  FIREBASE CONFIG
# ─────────────────────────────────────────────────────────────────────────────
const FB_API_KEY := "AIzaSyC6r1sMMfdWqcSB2_-FH7ZsySKrPLVogrk"
const FS_BASE    := "https://firestore.googleapis.com/v1/projects/algoquest-3f812/databases/(default)/documents"
const JSON_HEADERS := ["Content-Type: application/json"]

# ─────────────────────────────────────────────────────────────────────────────
#  SIGNALS
# ─────────────────────────────────────────────────────────────────────────────
signal profile_loaded
signal profile_saved
signal hero_changed(hero_key: String)

# ─────────────────────────────────────────────────────────────────────────────
#  PROFILE DATA
# ─────────────────────────────────────────────────────────────────────────────
var uid:           String = ""
var email:         String = ""
var username:      String = ""
var title:         String = ""
var selected_hero: String = ""
var course:        String = ""
var section:       String = ""
var section_id:    String = ""
var id_token:      String = ""   # Firebase Auth token for REST calls
var is_first_run:  bool   = true
var _loaded:       bool   = false

var progress: Dictionary = {}
# chapter_id(int) → { best_score, stars, complete, accuracy, mistakes }

var stats: Dictionary = {
	"total_score":    0,
	"perfect_clears": 0,
	"login_streak":   0,
	"last_login":     "",
}

# ─────────────────────────────────────────────────────────────────────────────
#  HTTP NODE
# ─────────────────────────────────────────────────────────────────────────────
var _http: HTTPRequest = null
var _pending_action: String = ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_response)

# ─────────────────────────────────────────────────────────────────────────────
#  INIT — called by LoginScreen after successful auth
# ─────────────────────────────────────────────────────────────────────────────
func init_from_login(p_uid: String, p_email: String, p_token: String) -> void:
	uid      = p_uid
	email    = p_email
	id_token = p_token
	_load_from_firestore()

# ─────────────────────────────────────────────────────────────────────────────
#  LOAD FROM FIRESTORE
# ─────────────────────────────────────────────────────────────────────────────
func _load_from_firestore() -> void:
	if uid.is_empty() or id_token.is_empty(): return
	_pending_action = "load"
	var url := "%s/users/%s?key=%s" % [FS_BASE, uid, FB_API_KEY]
	_http.request(url,
		JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_GET, "")

# ─────────────────────────────────────────────────────────────────────────────
#  SAVE FULL PROFILE TO FIRESTORE
# ─────────────────────────────────────────────────────────────────────────────
func save_profile() -> void:
	if uid.is_empty() or id_token.is_empty(): return
	_pending_action = "save"
	var url := "%s/users/%s?key=%s" % [FS_BASE, uid, FB_API_KEY]
	var doc := _build_firestore_doc()
	_http.request(url,
		JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_PATCH, JSON.stringify(doc))

# ─────────────────────────────────────────────────────────────────────────────
#  SAVE CHAPTER RESULT
# ─────────────────────────────────────────────────────────────────────────────
func save_chapter_result(chapter_id: int, score: int, stars: int,
						  accuracy: float = 0.0,
						  mistakes: Dictionary = {}) -> void:
	var existing  := progress.get(chapter_id, {}) as Dictionary
	var prev_best := existing.get("best_score", 0) as int

	progress[chapter_id] = {
		"best_score": max(score, prev_best),
		"stars":      max(stars, existing.get("stars", 0) as int),
		"complete":   true,
		"accuracy":   accuracy,
		"mistakes":   mistakes,
	}

	# Update total score
	if score > prev_best:
		stats["total_score"] = (stats["total_score"] as int) + (score - prev_best)

	if stars == 3:
		stats["perfect_clears"] = (stats["perfect_clears"] as int) + 1

	# Unlock next chapter placeholder
	var next := chapter_id + 1
	if next <= 5 and not progress.has(next):
		progress[next] = { "best_score": 0, "stars": 0, "complete": false }

	_check_title_unlock()
	save_profile()

# ─────────────────────────────────────────────────────────────────────────────
#  SETTERS
# ─────────────────────────────────────────────────────────────────────────────
func set_selected_hero(hero_key: String) -> void:
	selected_hero = hero_key
	_update_field("selected_hero", hero_key)
	emit_signal("hero_changed", hero_key)

func set_username(new_name: String) -> void:
	username = new_name
	_update_field("username", new_name)

func set_title(new_title: String) -> void:
	title = new_title
	_update_field("title", new_title)

# ─────────────────────────────────────────────────────────────────────────────
#  GETTERS
# ─────────────────────────────────────────────────────────────────────────────
func get_username() -> String:
	return username if username != "" else email.get_slice("@", 0)

func get_selected_hero() -> String:
	return selected_hero

func get_title() -> String:
	return title

func get_total_score() -> int:
	return stats.get("total_score", 0) as int

func get_login_streak() -> int:
	return stats.get("login_streak", 0) as int

func get_chapter_data(chapter_id: int) -> Dictionary:
	return progress.get(chapter_id, {
		"best_score": 0, "stars": 0, "complete": false, "accuracy": 0.0
	})

func is_chapter_unlocked(chapter_id: int) -> bool:
	if chapter_id == 1: return true
	return (progress.get(chapter_id - 1, {}) as Dictionary).get("complete", false) as bool

func is_loaded() -> bool:
	return _loaded

# ─────────────────────────────────────────────────────────────────────────────
#  PARTIAL FIELD UPDATE
# ─────────────────────────────────────────────────────────────────────────────
func _update_field(field: String, value: String) -> void:
	if uid.is_empty() or id_token.is_empty(): return
	var url := "%s/users/%s?updateMask.fieldPaths=%s&key=%s" % [FS_BASE, uid, field, FB_API_KEY]
	var doc := {"fields": {field: {"stringValue": value}}}
	var http := HTTPRequest.new()
	add_child(http)
	http.request(url,
		JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_PATCH, JSON.stringify(doc))
	# fire and forget — no response handler needed for simple field updates

# ─────────────────────────────────────────────────────────────────────────────
#  HTTP RESPONSE
# ─────────────────────────────────────────────────────────────────────────────
func _on_http_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	match _pending_action:
		"load": _handle_load(data)
		"save": emit_signal("profile_saved")

func _handle_load(data) -> void:
	if not data is Dictionary:
		is_first_run = true
		_loaded      = true
		emit_signal("profile_loaded")
		return

	if "error" in data:
		# 404 = no document yet (first run)
		is_first_run = true
		_loaded      = true
		emit_signal("profile_loaded")
		return

	is_first_run = false
	var f := data.get("fields", {}) as Dictionary

	username      = _fs_str(f, "username",      get_username())
	title         = _fs_str(f, "title",         "")
	selected_hero = _fs_str(f, "selected_hero", "")
	course        = _fs_str(f, "course",        "")
	section       = _fs_str(f, "section",       "")
	section_id    = _fs_str(f, "section_id",    "")

	# Stats
	var st_map := (f.get("stats", {}) as Dictionary).get("mapValue", {}) as Dictionary
	var st_fields := st_map.get("fields", {}) as Dictionary
	if not st_fields.is_empty():
		stats["total_score"]    = _fs_int(st_fields, "total_score",    0)
		stats["perfect_clears"] = _fs_int(st_fields, "perfect_clears", 0)
		stats["login_streak"]   = _fs_int(st_fields, "login_streak",   0)
		stats["last_login"]     = _fs_str(st_fields, "last_login",     "")

	# Progress
	var pr_map := (f.get("progress", {}) as Dictionary).get("mapValue", {}) as Dictionary
	var pr_fields := pr_map.get("fields", {}) as Dictionary
	for key in pr_fields:
		var ch_id : int = key.to_int()
		if ch_id > 0:
			var ch_map := (pr_fields[key] as Dictionary).get("mapValue", {}) as Dictionary
			var ch_f   := ch_map.get("fields", {}) as Dictionary
			progress[ch_id] = {
				"best_score": _fs_int(ch_f, "best_score", 0),
				"stars":      _fs_int(ch_f, "stars",      0),
				"complete":   _fs_bool(ch_f, "complete",  false),
				"accuracy":   _fs_float(ch_f, "accuracy", 0.0),
			}

	_update_login_streak()
	_loaded = true
	emit_signal("profile_loaded")

# ─────────────────────────────────────────────────────────────────────────────
#  BUILD FIRESTORE DOCUMENT
# ─────────────────────────────────────────────────────────────────────────────
func _build_firestore_doc() -> Dictionary:
	# Build progress map
	var pr_fields := {}
	for ch_id in progress:
		var p := progress[ch_id] as Dictionary
		pr_fields[str(ch_id)] = {"mapValue": {"fields": {
			"best_score": {"integerValue": str(p.get("best_score", 0))},
			"stars":      {"integerValue": str(p.get("stars",      0))},
			"complete":   {"booleanValue": p.get("complete", false)},
			"accuracy":   {"doubleValue":  p.get("accuracy", 0.0)},
		}}}

	return {
		"fields": {
			"username":      {"stringValue": username},
			"email":         {"stringValue": email},
			"role":          {"stringValue": "student"},
			"title":         {"stringValue": title},
			"selected_hero": {"stringValue": selected_hero},
			"course":        {"stringValue": course},
			"section":       {"stringValue": section},
			"section_id":    {"stringValue": section_id},
			"progress":      {"mapValue": {"fields": pr_fields}},
			"stats": {"mapValue": {"fields": {
				"total_score":    {"integerValue": str(stats.get("total_score",    0))},
				"perfect_clears": {"integerValue": str(stats.get("perfect_clears", 0))},
				"login_streak":   {"integerValue": str(stats.get("login_streak",   0))},
				"last_login":     {"stringValue":  str(stats.get("last_login",     ""))},
			}}},
		}
	}

# ─────────────────────────────────────────────────────────────────────────────
#  LOGIN STREAK
# ─────────────────────────────────────────────────────────────────────────────
func _update_login_streak() -> void:
	var today := Time.get_date_string_from_system()
	var last  := stats.get("last_login", "") as String
	if last == today: return
	var streak := stats.get("login_streak", 0) as int
	var yesterday := _date_subtract_one(today)
	stats["login_streak"] = streak + 1 if last == yesterday else 1
	stats["last_login"]   = today

func _date_subtract_one(date_str: String) -> String:
	var parts := date_str.split("-")
	if parts.size() != 3: return ""
	var d := {"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2])}
	var unix := Time.get_unix_time_from_datetime_dict(d)
	return Time.get_date_string_from_unix_time(unix - 86400)

# ─────────────────────────────────────────────────────────────────────────────
#  TITLE AUTO-UNLOCK
# ─────────────────────────────────────────────────────────────────────────────
const TITLES: Array[Dictionary] = [
	{"condition":"ch1_s3","label":"Queue Master"},
	{"condition":"ch2_s3","label":"Stack Wizard"},
	{"condition":"ch3_s3","label":"Chain Rider"},
	{"condition":"ch4_s3","label":"Tree Oracle"},
	{"condition":"ch5_s3","label":"Path Finder"},
	{"condition":"all",   "label":"Algo Knight"},
]

func _check_title_unlock() -> void:
	if title != "": return   # already has a title
	for t: Dictionary in TITLES:
		var cond: String = t["condition"] as String
		var earned := false
		if cond.begins_with("ch"):
			var ch_id := int(cond.substr(2, 1))
			earned = (progress.get(ch_id, {}) as Dictionary).get("stars", 0) as int >= 3
		elif cond == "all":
			earned = true
			for i in range(1, 6):
				if not (progress.get(i, {}) as Dictionary).get("complete", false) as bool:
					earned = false; break
		if earned:
			set_title(t["label"] as String)
			break

# ─────────────────────────────────────────────────────────────────────────────
#  FIRESTORE TYPE HELPERS
# ─────────────────────────────────────────────────────────────────────────────
func _fs_str(fields: Dictionary, key: String, default_val: String) -> String:
	if key in fields and fields[key] is Dictionary:
		return (fields[key] as Dictionary).get("stringValue", default_val) as String
	return default_val

func _fs_int(fields: Dictionary, key: String, default_val: int) -> int:
	if key in fields and fields[key] is Dictionary:
		var v = (fields[key] as Dictionary).get("integerValue", str(default_val))
		return int(str(v))
	return default_val

func _fs_float(fields: Dictionary, key: String, default_val: float) -> float:
	if key in fields and fields[key] is Dictionary:
		var f := fields[key] as Dictionary
		if "doubleValue"  in f: return float(f["doubleValue"])
		if "integerValue" in f: return float(int(str(f["integerValue"])))
	return default_val

func _fs_bool(fields: Dictionary, key: String, default_val: bool) -> bool:
	if key in fields and fields[key] is Dictionary:
		return (fields[key] as Dictionary).get("booleanValue", default_val) as bool
	return default_val
