# =============================================================================
# PlayerProfile.gd — Autoload
# File: scripts/autoload/PlayerProfile.gd
#
# CHANGES (CharacterSelect removal + teacher unlock + dashboard sync):
#   • Added `role` field — populated from Firestore ("teacher" / "student")
#   • Added is_teacher() helper — teachers bypass all unlock gates
#   • is_chapter_unlocked() now returns true for ALL chapters when teacher
#   • save_chapter_result() now also writes a timestamped activity record to
#     Firestore: game_results/{uid}_{chapter_id}_{timestamp}
#     → your web dashboard reads this collection for live updates
#   • Removed selected_hero read/write (CharacterSelect no longer exists)
#   • _build_firestore_doc() no longer emits selected_hero
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

# ─────────────────────────────────────────────────────────────────────────────
#  PROFILE DATA
# ─────────────────────────────────────────────────────────────────────────────
var uid:        String = ""
var email:      String = ""
var username:   String = ""
var title:      String = ""
var role:       String = "student"   # "teacher" | "student"
var course:     String = ""
var section:    String = ""
var section_id: String = ""
var id_token:   String = ""          # Firebase Auth token for REST calls
var _loaded:    bool   = false

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
var _http:           HTTPRequest = null
var _http_result:    HTTPRequest = null   # separate node for game_results writes
var _pending_action: String      = ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_response)

	# Second HTTPRequest used exclusively for writing game_results documents
	# so it never collides with the main profile save/load.
	_http_result = HTTPRequest.new()
	add_child(_http_result)

# ─────────────────────────────────────────────────────────────────────────────
#  INIT — called by LoginScreen after successful auth
# ─────────────────────────────────────────────────────────────────────────────
func init_from_login(p_uid: String, p_email: String, p_token: String) -> void:
	uid      = p_uid
	email    = p_email
	id_token = p_token
	_load_from_firestore()

# ─────────────────────────────────────────────────────────────────────────────
#  TEACHER CHECK
#  Returns true when the signed-in account has role == "teacher".
#  Used by WorldMap and unlock logic to bypass all chapter gates.
# ─────────────────────────────────────────────────────────────────────────────
func is_teacher() -> bool:
	return role == "teacher"

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
#  1. Updates local progress + stats
#  2. Saves full profile (users/{uid})
#  3. Writes a game_results record → your web/dashboard reads this collection
#     Collection path: game_results/{uid}_{chapter_id}_{unix_timestamp}
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

	# Update aggregate stats
	if score > prev_best:
		stats["total_score"] = (stats["total_score"] as int) + (score - prev_best)
	if stars == 3:
		stats["perfect_clears"] = (stats["perfect_clears"] as int) + 1

	# Placeholder so the next tier shows up in progress (student accounts only)
	if not is_teacher():
		var next := chapter_id + 1
		if next <= 25 and not progress.has(next):
			progress[next] = { "best_score": 0, "stars": 0, "complete": false }

	_check_title_unlock()
	save_profile()

	# ── Write activity record for the web dashboard ──────────────────────────
	_write_game_result(chapter_id, score, stars, accuracy)

# ─────────────────────────────────────────────────────────────────────────────
#  WRITE GAME RESULT (dashboard sync)
#  Creates a document in the `game_results` top-level collection.
#  Your Next.js / React dashboard should listen to:
#    db.collection("game_results").where("uid", "==", teacherUid's student list)
#  or per-student:
#    db.collection("game_results").where("uid", "==", studentUid)
# ─────────────────────────────────────────────────────────────────────────────
func _write_game_result(chapter_id: int, score: int, stars: int, accuracy: float) -> void:
	if uid.is_empty() or id_token.is_empty(): return
	var ts    := Time.get_unix_time_from_system()
	var doc_id := "%s_%d_%d" % [uid, chapter_id, int(ts)]
	var url   := "%s/game_results/%s?key=%s" % [FS_BASE, doc_id, FB_API_KEY]

	var chapter_name := _chapter_display_name(chapter_id)

	var doc := {
		"fields": {
			"uid":          {"stringValue": uid},
			"username":     {"stringValue": get_username()},
			"email":        {"stringValue": email},
			"section_id":   {"stringValue": section_id},
			"section":      {"stringValue": section},
			"course":       {"stringValue": course},
			"chapter_id":   {"integerValue": str(chapter_id)},
			"chapter_name": {"stringValue": chapter_name},
			"score":        {"integerValue": str(score)},
			"stars":        {"integerValue": str(stars)},
			"accuracy":     {"doubleValue":  accuracy},
			"completed_at": {"stringValue":  Time.get_datetime_string_from_system()},
			"timestamp":    {"integerValue": str(int(ts))},
		}
	}
	# Fire-and-forget — no response handler needed
	_http_result.request(url,
		JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_PATCH, JSON.stringify(doc))

# ─────────────────────────────────────────────────────────────────────────────
#  SETTERS
# ─────────────────────────────────────────────────────────────────────────────
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

# Teachers always have every chapter unlocked — no gates at all.
func is_chapter_unlocked(chapter_id: int) -> bool:
	if chapter_id == 1: return true
	if is_teacher():    return true
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
		_loaded = true
		emit_signal("profile_loaded")
		return

	if "error" in data:
		_loaded = true
		emit_signal("profile_loaded")
		return

	var f := data.get("fields", {}) as Dictionary

	username   = _fs_str(f, "username",   get_username())
	title      = _fs_str(f, "title",      "")
	role       = _fs_str(f, "role",       "student")   # ← read role from Firestore
	course     = _fs_str(f, "course",     "")
	section    = _fs_str(f, "section",    "")
	section_id = _fs_str(f, "section_id", "")

	# Stats
	var st_map    := (f.get("stats", {}) as Dictionary).get("mapValue", {}) as Dictionary
	var st_fields := st_map.get("fields", {}) as Dictionary
	if not st_fields.is_empty():
		stats["total_score"]    = _fs_int(st_fields, "total_score",    0)
		stats["perfect_clears"] = _fs_int(st_fields, "perfect_clears", 0)
		stats["login_streak"]   = _fs_int(st_fields, "login_streak",   0)
		stats["last_login"]     = _fs_str(st_fields, "last_login",     "")

	# Progress
	var pr_map    := (f.get("progress", {}) as Dictionary).get("mapValue", {}) as Dictionary
	var pr_fields := pr_map.get("fields", {}) as Dictionary
	for key in pr_fields:
		var ch_id: int = key.to_int()
		if ch_id > 0:
			var ch_map := (pr_fields[key] as Dictionary).get("mapValue", {}) as Dictionary
			var ch_f   := ch_map.get("fields", {}) as Dictionary
			progress[ch_id] = {
				"best_score": _fs_int(ch_f,   "best_score", 0),
				"stars":      _fs_int(ch_f,   "stars",      0),
				"complete":   _fs_bool(ch_f,  "complete",   false),
				"accuracy":   _fs_float(ch_f, "accuracy",   0.0),
			}

	_update_login_streak()
	_loaded = true
	emit_signal("profile_loaded")

# ─────────────────────────────────────────────────────────────────────────────
#  BUILD FIRESTORE DOCUMENT
# ─────────────────────────────────────────────────────────────────────────────
func _build_firestore_doc() -> Dictionary:
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
			"username":    {"stringValue": username},
			"email":       {"stringValue": email},
			"role":        {"stringValue": role},
			"title":       {"stringValue": title},
			"course":      {"stringValue": course},
			"section":     {"stringValue": section},
			"section_id":  {"stringValue": section_id},
			"progress":    {"mapValue": {"fields": pr_fields}},
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
	var streak    := stats.get("login_streak", 0) as int
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
	{"condition":"ch1_s3", "label":"Queue Master"},
	{"condition":"ch2_s3", "label":"Stack Wizard"},
	{"condition":"ch3_s3", "label":"Chain Rider"},
	{"condition":"ch4_s3", "label":"Tree Oracle"},
	{"condition":"ch5_s3", "label":"Path Finder"},
	{"condition":"all",    "label":"Algo Knight"},
]

func _check_title_unlock() -> void:
	if title != "": return
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
#  CHAPTER DISPLAY NAME HELPER  (used for game_results records)
# ─────────────────────────────────────────────────────────────────────────────
func _chapter_display_name(ch_id: int) -> String:
	var families: Array = [
		[1,5,"Kingdom Gate"],
		[6,10,"Castle of Echoes"],
		[11,15,"Chain Station"],
		[16,20,"Oracle's Forest"],
		[21,25,"Kingdom Roads"],
	]
	var tiers: Array[String] = ["Beginner","Easy","Normal","Hard","Expert"]
	for fam in families:
		if ch_id >= fam[0] and ch_id <= fam[1]:
			var idx: int = ch_id - fam[0]
			return "%s [%s]" % [fam[2], tiers[idx] if idx < tiers.size() else str(idx+1)]
	return "Chapter %d" % ch_id

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
