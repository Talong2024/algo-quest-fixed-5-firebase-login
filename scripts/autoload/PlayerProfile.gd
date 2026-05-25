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
var light_mode: bool   = false       # persisted UI theme preference

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
var _pending_action: String      = ""

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_http_response)
	# NOTE: _http_result removed — game_results writes now use _http_write_once()
	# which spawns a fresh HTTPRequest per call so rapid completions never get
	# dropped with ERR_BUSY.

# ─────────────────────────────────────────────────────────────────────────────
#  INIT — called by LoginScreen after successful auth
# ─────────────────────────────────────────────────────────────────────────────
func init_from_login(p_uid: String, p_email: String, p_token: String) -> void:
	uid      = p_uid
	email    = p_email
	id_token = p_token
	# FIX: sync credentials to SaveManager so its _push_to_firebase() can auth
	if has_node("/root/SaveManager"):
		SaveManager._data["uid"]      = p_uid
		SaveManager._data["id_token"] = p_token
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
	var ts     := Time.get_unix_time_from_system()
	var doc_id := "%s_%d_%d" % [uid, chapter_id, int(ts)]
	var url    := "%s/game_results/%s?key=%s" % [FS_BASE, doc_id, FB_API_KEY]

	var doc := {
		"fields": {
			"uid":          {"stringValue": uid},
			"username":     {"stringValue": get_username()},
			"email":        {"stringValue": email},
			"section_id":   {"stringValue": section_id},   # may be "" if not joined yet
			"section":      {"stringValue": section},
			"course":       {"stringValue": course},
			"chapter_id":   {"integerValue": str(chapter_id)},
			"chapter_name": {"stringValue": _chapter_display_name(chapter_id)},
			"score":        {"integerValue": str(score)},
			"stars":        {"integerValue": str(stars)},
			"accuracy":     {"doubleValue":  accuracy},
			"completed_at": {"stringValue":  Time.get_datetime_string_from_system()},
			"timestamp":    {"integerValue": str(int(ts))},
		}
	}
	# Use a fresh HTTPRequest node per write so rapid chapter completions never
	# hit ERR_BUSY on a shared node that's still in flight.
	_http_write_once(url, JSON.stringify(doc))

# Spawns a one-shot HTTPRequest, fires a PATCH, then frees itself on completion.
func _http_write_once(url: String, body: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(_r, _c, _h, _b): http.queue_free())
	http.request(url,
		JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_PATCH, body)

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
	_http_write_once(url, JSON.stringify(doc))

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

	username   = _fs_str(f,  "username",   get_username())
	title      = _fs_str(f,  "title",      "")
	role       = _fs_str(f,  "role",       "student")   # ← read role from Firestore
	course     = _fs_str(f,  "course",     "")
	section    = _fs_str(f,  "section",    "")
	section_id = _fs_str(f,  "section_id", "")
	light_mode = _fs_bool(f, "light_mode", false)       # ← UI theme preference

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
			"light_mode":  {"booleanValue": light_mode},
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

# =============================================================================
#  TEACHER — FETCH ALL STUDENTS
#
#  Flow:
#    1. Query sections collection for all docs where teacher_uid == uid
#       GET .../sections?structured query (POST runQuery)
#    2. For each section found, query sections/{id}/students subcollection
#    3. For each student uid found, fetch users/{uid}
#    4. Call the callback(students: Array) when all docs are loaded
#
#  The callback receives an Array of Dictionaries, each matching the same
#  shape that WorldMap.gd's dashboard helpers expect:
#    { uid, username, email, course, section, progress:{}, stats:{} }
# =============================================================================
signal students_loaded   # emitted with the Array when async fetch is done

var _teacher_fetch_callback: Callable = Callable()
var _pending_section_uids:   Array    = []
var _pending_student_uids:   Array    = []
var _fetched_students:       Array    = []
var _http_teacher:           HTTPRequest = null   # dedicated node for teacher queries

func fetch_teacher_students(callback: Callable) -> void:
	if not is_teacher() or uid.is_empty() or id_token.is_empty():
		callback.call([])
		return

	_teacher_fetch_callback = callback
	_fetched_students.clear()
	_pending_section_uids.clear()
	_pending_student_uids.clear()

	# Lazy-init a dedicated HTTPRequest node
	if not is_instance_valid(_http_teacher):
		_http_teacher = HTTPRequest.new()
		add_child(_http_teacher)
		_http_teacher.request_completed.connect(_on_teacher_http)

	# ── Step 1: runQuery to find sections where teacher_uid == uid ────────────
	var url := "%s:runQuery?key=%s" % [FS_BASE, FB_API_KEY]
	var body := JSON.stringify({
		"structuredQuery": {
			"from": [{"collectionId": "sections"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "teacher_uid"},
					"op": "EQUAL",
					"value": {"stringValue": uid}
				}
			}
		}
	})
	_teacher_pending = "query_sections"
	_http_teacher.request(url,
		JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_POST, body)

var _teacher_pending: String = ""
var _section_ids_to_scan: Array = []
var _current_section_idx: int  = 0
var _student_uids_to_fetch: Array = []
var _current_student_idx:  int  = 0

func _on_teacher_http(_res: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text  := body.get_string_from_utf8()
	var data  = JSON.parse_string(text)

	match _teacher_pending:
		"query_sections":
			_handle_sections_query(data)
		"list_section_students":
			_handle_section_students(data)
		"fetch_student":
			_handle_student_doc(data)

# ── Step 1 result: parse section IDs ─────────────────────────────────────────
func _handle_sections_query(data) -> void:
	_section_ids_to_scan.clear()
	if data is Array:
		for item in data:
			if item is Dictionary and "document" in item:
				var doc: Dictionary = item["document"] as Dictionary
				var name_path: String = doc.get("name", "") as String
				# name = "projects/.../documents/sections/{id}"
				var parts := name_path.split("/")
				if parts.size() > 0:
					_section_ids_to_scan.append(parts[-1])

	if _section_ids_to_scan.is_empty():
		# No sections — return empty list
		_teacher_fetch_callback.call([])
		return

	_current_section_idx = 0
	_student_uids_to_fetch.clear()
	_fetch_next_section_students()

# ── Step 2: list students subcollection for each section ─────────────────────
func _fetch_next_section_students() -> void:
	if _current_section_idx >= _section_ids_to_scan.size():
		# All sections scanned — now fetch each student profile
		if _student_uids_to_fetch.is_empty():
			_teacher_fetch_callback.call([])
			return
		_current_student_idx = 0
		_fetched_students.clear()
		_fetch_next_student()
		return

	var sec_id: String = _section_ids_to_scan[_current_section_idx]
	var url := "%s/sections/%s/students?key=%s" % [FS_BASE, sec_id, FB_API_KEY]
	_teacher_pending = "list_section_students"
	_http_teacher.request(url,
		JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_GET, "")

func _handle_section_students(data) -> void:
	if data is Dictionary and "documents" in data:
		for doc in (data["documents"] as Array):
			if doc is Dictionary:
				var doc_name: String = (doc as Dictionary).get("name", "") as String
				var parts := doc_name.split("/")
				if parts.size() > 0:
					var s_uid: String = parts[-1]
					if s_uid not in _student_uids_to_fetch:
						_student_uids_to_fetch.append(s_uid)
	_current_section_idx += 1
	_fetch_next_section_students()

# ── Step 3: fetch each student's users/{uid} document ─────────────────────────
func _fetch_next_student() -> void:
	if _current_student_idx >= _student_uids_to_fetch.size():
		# Done — fire the callback
		_teacher_fetch_callback.call(_fetched_students.duplicate())
		return

	var s_uid: String = _student_uids_to_fetch[_current_student_idx]
	var url := "%s/users/%s?key=%s" % [FS_BASE, s_uid, FB_API_KEY]
	_teacher_pending = "fetch_student"
	_http_teacher.request(url,
		JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_GET, "")

func _handle_student_doc(data) -> void:
	if data is Dictionary and "fields" in data:
		var f: Dictionary = data["fields"] as Dictionary
		var s_uid: String = _student_uids_to_fetch[_current_student_idx]

		# Parse progress sub-map
		var pr_map    := (f.get("progress", {}) as Dictionary).get("mapValue", {}) as Dictionary
		var pr_fields := pr_map.get("fields", {}) as Dictionary
		var prog: Dictionary = {}
		for key in pr_fields:
			var ch_id: int = key.to_int()
			if ch_id > 0:
				var ch_map := (pr_fields[key] as Dictionary).get("mapValue", {}) as Dictionary
				var ch_f   := ch_map.get("fields", {}) as Dictionary
				prog[ch_id] = {
					"best_score": _fs_int(ch_f,   "best_score", 0),
					"stars":      _fs_int(ch_f,   "stars",      0),
					"complete":   _fs_bool(ch_f,  "complete",   false),
					"accuracy":   _fs_float(ch_f, "accuracy",   0.0),
					"mistakes":   {},
				}

		# Parse stats sub-map
		var st_map    := (f.get("stats", {}) as Dictionary).get("mapValue", {}) as Dictionary
		var st_fields := st_map.get("fields", {}) as Dictionary
		var st: Dictionary = {
			"total_score":    _fs_int(st_fields, "total_score",    0),
			"perfect_clears": _fs_int(st_fields, "perfect_clears", 0),
			"login_streak":   _fs_int(st_fields, "login_streak",   0),
		}

		_fetched_students.append({
			"uid":      s_uid,
			"username": _fs_str(f, "username", s_uid),
			"email":    _fs_str(f, "email",    ""),
			"course":   _fs_str(f, "course",   ""),
			"section":  _fs_str(f, "section",  ""),
			"role":     _fs_str(f, "role",      "student"),
			"progress": prog,
			"stats":    st,
		})

	_current_student_idx += 1
	_fetch_next_student()

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

# =============================================================================
#  JOIN SECTION BY CODE  (students only)
#
#  Flow:
#    1. runQuery on "sections" where join_code == code  (case-insensitive
#       because we store codes in uppercase and normalise the input)
#    2. If found, write the student's uid into sections/{id}/students/{uid}
#       and update their own users/{uid} doc with section_id + section name.
#    3. Call callback(ok: bool, message: String)
# =============================================================================
var _join_http:       HTTPRequest = null
var _join_code:       String      = ""
var _join_callback:   Callable    = Callable()
var _join_section_id: String      = ""
var _join_section_nm: String      = ""
var _join_pending:    String      = ""   # "query" | "write_member" | "write_user"

func join_section_by_code(code: String, callback: Callable) -> void:
	if uid.is_empty() or id_token.is_empty():
		callback.call(false, "Not logged in."); return
	_join_code     = code.to_upper()
	_join_callback = callback

	if not is_instance_valid(_join_http):
		_join_http = HTTPRequest.new(); add_child(_join_http)
		_join_http.request_completed.connect(_on_join_http)

	# Step 1 — query sections where join_code == code
	var url  := "%s:runQuery?key=%s" % [FS_BASE, FB_API_KEY]
	var body := JSON.stringify({
		"structuredQuery": {
			"from": [{"collectionId": "sections"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "join_code"},
					"op": "EQUAL",
					"value": {"stringValue": _join_code}
				}
			},
			"limit": 1
		}
	})
	_join_pending = "query"
	_join_http.request(url, JSON_HEADERS + ["Authorization: Bearer " + id_token],
		HTTPClient.METHOD_POST, body)

func _on_join_http(_res: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var text := body.get_string_from_utf8()
	var data  = JSON.parse_string(text)

	match _join_pending:
		"query":
			# Parse section id from runQuery response
			if data is Array and not (data as Array).is_empty():
				var item: Dictionary = (data as Array)[0] as Dictionary
				if "document" in item:
					var doc: Dictionary  = item["document"] as Dictionary
					var name_path: String = doc.get("name","") as String
					var parts := name_path.split("/")
					_join_section_id = parts[-1] if parts.size() > 0 else ""
					var f: Dictionary = doc.get("fields",{}) as Dictionary
					_join_section_nm = _fs_str(f, "name", "")
			if _join_section_id.is_empty():
				_join_callback.call(false, "Invalid join code. Check with your teacher."); return

			# Step 2 — write uid into sections/{id}/students/{uid}
			var url2 := "%s/sections/%s/students/%s?key=%s" % [FS_BASE, _join_section_id, uid, FB_API_KEY]
			var body2 := JSON.stringify({"fields": {"joined_at": {"stringValue": Time.get_date_string_from_system()}}})
			_join_pending = "write_member"
			_join_http.request(url2, JSON_HEADERS + ["Authorization: Bearer " + id_token],
				HTTPClient.METHOD_PATCH, body2)

		"write_member":
			if code < 200 or code > 299:
				_join_callback.call(false, "Failed to join. Try again."); return
			# Step 3 — update user's own doc with section info
			section_id = _join_section_id
			section    = _join_section_nm
			var url3   := "%s/users/%s?key=%s&updateMask.fieldPaths=section_id&updateMask.fieldPaths=section" % [FS_BASE, uid, FB_API_KEY]
			var body3  := JSON.stringify({
				"fields": {
					"section_id": {"stringValue": section_id},
					"section":    {"stringValue": section},
				}
			})
			_join_pending = "write_user"
			_join_http.request(url3, JSON_HEADERS + ["Authorization: Bearer " + id_token],
				HTTPClient.METHOD_PATCH, body3)

		"write_user":
			if code >= 200 and code <= 299:
				_join_callback.call(true, "Joined '%s' successfully!" % section)
			else:
				_join_callback.call(false, "Joined section but failed to update profile.")
