# LoginScreen.gd — Firebase Auth + Firestore for AlgoQuest
# Updated: writes to Firestore (matches web dashboard schema)
# Added:   course, section, join code fields on signup
extends Control

# ── Firebase config ───────────────────────────────────────────────────────────
const FB_API_KEY   := "AIzaSyC6r1sMMfdWqcSB2_-FH7ZsySKrPLVogrk"
const FB_PROJECT   := "algoquest-3f812"
const FB_SIGNUP    := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
const FB_LOGIN     := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key="
const FS_BASE      := "https://firestore.googleapis.com/v1/projects/algoquest-3f812/databases/(default)/documents"
const FS_QUERY     := "https://firestore.googleapis.com/v1/projects/algoquest-3f812/databases/(default)/documents:runQuery"

const PATH_FONT    := "res://assets/fonts/freepixel.ttf"
const JSON_HEADERS := ["Content-Type: application/json"]

# ── Node refs — all original names preserved ──────────────────────────────────
@onready var _logo:        Label        = $LogoLabel
@onready var _tabs:        TabContainer = $TabContainer
@onready var _email_in:    LineEdit     = $TabContainer/LoginTab/EmailInput
@onready var _pass_in:     LineEdit     = $TabContainer/LoginTab/PassInput
@onready var _login_btn:   Button       = $TabContainer/LoginTab/LoginBtn
@onready var _login_err:   Label        = $TabContainer/LoginTab/LoginError
@onready var _login_spin:  Label        = $TabContainer/LoginTab/SpinLabel
@onready var _name_in:     LineEdit     = $TabContainer/SignupTab/NameInput
@onready var _email_in2:   LineEdit     = $TabContainer/SignupTab/EmailInput2
@onready var _pass_in2:    LineEdit     = $TabContainer/SignupTab/PassInput2
@onready var _signup_btn:  Button       = $TabContainer/SignupTab/SignupBtn
@onready var _signup_err:  Label        = $TabContainer/SignupTab/SignupError
@onready var _signup_spin: Label        = $TabContainer/SignupTab/SpinLabel2
@onready var _http_auth:   HTTPRequest  = $HTTPAuth
@onready var _http_db:     HTTPRequest  = $HTTPDb

# New fields added dynamically (no tscn changes needed)
var _course_in:    LineEdit     = null
var _section_in:   LineEdit     = null
var _code_in:      LineEdit     = null
var _http_fs2:     HTTPRequest  = null

# ── State ─────────────────────────────────────────────────────────────────────
var _pending_action:     String = ""
var _pending_name:       String = ""
var _pending_email:      String = ""
var _pending_uid:        String = ""
var _pending_token:      String = ""
var _pending_course:     String = ""
var _pending_section:    String = ""
var _pending_section_id: String = ""

var _pixel_font: Font = null

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) if ResourceLoader.exists(PATH_FONT) else null
	_setup_ui()
	_http_auth.request_completed.connect(_on_auth_response)
	_http_db.request_completed.connect(_on_firestore_response)
	_http_fs2 = HTTPRequest.new()
	add_child(_http_fs2)
	_http_fs2.request_completed.connect(_on_firestore2_response)

func _setup_ui() -> void:
	for lbl in [_logo, _login_err, _signup_err, _login_spin, _signup_spin]:
		if is_instance_valid(lbl) and _pixel_font:
			lbl.add_theme_font_override("font", _pixel_font)
	for btn in [_login_btn, _signup_btn]:
		if is_instance_valid(btn) and _pixel_font:
			btn.add_theme_font_override("font", _pixel_font)
	for le in [_email_in, _pass_in, _name_in, _email_in2, _pass_in2]:
		if is_instance_valid(le) and _pixel_font:
			le.add_theme_font_override("font", _pixel_font)

	_logo.text = "⚔  AlgoQuest"
	_logo.add_theme_font_size_override("font_size", 52)
	_logo.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))

	_pass_in.secret  = true
	_pass_in2.secret = true

	_login_err.visible   = false
	_signup_err.visible  = false
	_login_spin.visible  = false
	_signup_spin.visible = false
	_login_spin.text     = "⏳ Signing in..."
	_signup_spin.text    = "⏳ Creating account..."
	_login_btn.text      = "▶  Login"
	_signup_btn.text     = "★  Create Account"

	_login_btn.pressed.connect(_on_login_pressed)
	_signup_btn.pressed.connect(_on_signup_pressed)
	_pass_in.text_submitted.connect(func(_t): _on_login_pressed())

	if is_instance_valid($GuestBtn):
		$GuestBtn.pressed.connect(_on_guest)
		$GuestBtn.text = "👤  Play as Guest"
		if _pixel_font: $GuestBtn.add_theme_font_override("font", _pixel_font)

	# ── Inject course / section / join code into SignupTab ───────────────────
	var stab := $TabContainer/SignupTab as VBoxContainer
	var btn_idx := _signup_btn.get_index()

	var sep := Label.new()
	sep.text = "Course & Section"
	sep.add_theme_color_override("font_color", Color(0.6, 0.6, 0.9))
	if _pixel_font: sep.add_theme_font_override("font", _pixel_font)
	stab.add_child(sep)
	stab.move_child(sep, btn_idx)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	stab.add_child(row)
	stab.move_child(row, btn_idx + 1)

	_course_in = LineEdit.new()
	_course_in.placeholder_text      = "Course (e.g. BSIT)"
	_course_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_course_in.custom_minimum_size   = Vector2(0, 42)
	if _pixel_font: _course_in.add_theme_font_override("font", _pixel_font)
	row.add_child(_course_in)

	_section_in = LineEdit.new()
	_section_in.placeholder_text   = "Section (e.g. 2A)"
	_section_in.custom_minimum_size = Vector2(120, 42)
	if _pixel_font: _section_in.add_theme_font_override("font", _pixel_font)
	row.add_child(_section_in)

	var code_lbl := Label.new()
	code_lbl.text = "Join Code (from your teacher)"
	code_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.9))
	if _pixel_font: code_lbl.add_theme_font_override("font", _pixel_font)
	stab.add_child(code_lbl)
	stab.move_child(code_lbl, btn_idx + 2)

	_code_in = LineEdit.new()
	_code_in.placeholder_text    = "Enter the join code"
	_code_in.custom_minimum_size = Vector2(420, 42)
	if _pixel_font: _code_in.add_theme_font_override("font", _pixel_font)
	_code_in.text_submitted.connect(func(_t): _on_signup_pressed())
	stab.add_child(_code_in)
	stab.move_child(_code_in, btn_idx + 3)

	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.5)

# ── LOGIN ──────────────────────────────────────────────────────────────────────
func _on_login_pressed() -> void:
	var email    := _email_in.text.strip_edges()
	var password := _pass_in.text
	if email.is_empty() or password.is_empty():
		_show_err(_login_err, "Please fill in all fields.")
		return
	_set_busy(true, "login")
	_pending_action = "login"
	_pending_email  = email
	var body := JSON.stringify({
		"email": email, "password": password, "returnSecureToken": true
	})
	_http_auth.request(FB_LOGIN + FB_API_KEY, JSON_HEADERS, HTTPClient.METHOD_POST, body)

# ── SIGNUP ─────────────────────────────────────────────────────────────────────
func _on_signup_pressed() -> void:
	var display_name := _name_in.text.strip_edges()
	var email        := _email_in2.text.strip_edges()
	var password     := _pass_in2.text
	var course       := _course_in.text.strip_edges()   if _course_in  else ""
	var section      := _section_in.text.strip_edges().to_upper() if _section_in else ""
	var join_code    := _code_in.text.strip_edges().to_upper()    if _code_in    else ""

	if display_name.is_empty() or email.is_empty() or password.is_empty():
		_show_err(_signup_err, "Please fill in all fields.")
		return
	if password.length() < 6:
		_show_err(_signup_err, "Password must be at least 6 characters.")
		return
	if course.is_empty() or section.is_empty():
		_show_err(_signup_err, "Please enter your course and section.")
		return
	if join_code.is_empty():
		_show_err(_signup_err, "Please enter the join code\nfrom your teacher.")
		return

	_set_busy(true, "signup")
	_pending_action     = "signup"
	_pending_name       = display_name
	_pending_email      = email
	_pending_course     = course
	_pending_section    = section
	_pending_section_id = join_code   # carry code until section is found

	var body := JSON.stringify({
		"email": email, "password": password, "returnSecureToken": true
	})
	_http_auth.request(FB_SIGNUP + FB_API_KEY, JSON_HEADERS, HTTPClient.METHOD_POST, body)

# ── GUEST ──────────────────────────────────────────────────────────────────────
func _on_guest() -> void:
	_finish_login("Guest", "guest_%d" % randi(), "", "", "", "")

# ── AUTH RESPONSE ──────────────────────────────────────────────────────────────
func _on_auth_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_set_busy(false, _pending_action)
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		_show_err_by_action("Network error. Check your connection.")
		return
	if "error" in data:
		var msg: String = data["error"].get("message", "Unknown error")
		match msg:
			"EMAIL_EXISTS":
				_show_err_by_action("That email is already registered.\nPlease log in instead.")
			"EMAIL_NOT_FOUND", "INVALID_LOGIN_CREDENTIALS", "INVALID_PASSWORD":
				_show_err_by_action("Wrong email or password.")
			"WEAK_PASSWORD : Password should be at least 6 characters":
				_show_err_by_action("Password must be at least 6 characters.")
			"INVALID_EMAIL":
				_show_err_by_action("Please enter a valid email address.")
			_:
				_show_err_by_action("Error: " + msg)
		return

	_pending_uid   = data.get("localId", "")
	_pending_token = data.get("idToken", "")

	if _pending_action == "signup":
		_find_section_by_code(_pending_section_id)
	else:
		_read_user_from_firestore()

# ── FIND SECTION BY JOIN CODE ──────────────────────────────────────────────────
func _find_section_by_code(join_code: String) -> void:
	_pending_action   = "find_section"
	_set_busy(true, "signup")
	_signup_spin.text = "⏳ Verifying join code..."
	var body := JSON.stringify({
		"structuredQuery": {
			"from": [{"collectionId": "sections"}],
			"where": {
				"fieldFilter": {
					"field": {"fieldPath": "join_code"},
					"op": "EQUAL",
					"value": {"stringValue": join_code}
				}
			},
			"limit": 1
		}
	})
	_http_db.request(FS_QUERY + "?key=" + FB_API_KEY,
		JSON_HEADERS + ["Authorization: Bearer " + _pending_token],
		HTTPClient.METHOD_POST, body)

# ── READ USER (login) ──────────────────────────────────────────────────────────
func _read_user_from_firestore() -> void:
	_pending_action = "read_user"
	_http_db.request(
		"%s/users/%s?key=%s" % [FS_BASE, _pending_uid, FB_API_KEY],
		JSON_HEADERS + ["Authorization: Bearer " + _pending_token],
		HTTPClient.METHOD_GET, "")

# ── FIRESTORE RESPONSE ─────────────────────────────────────────────────────────
func _on_firestore_response(_result: int, _code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	match _pending_action:
		"find_section": _handle_find_section(data)
		"read_user":    _handle_read_user(data)
		"write_user":   _handle_write_user(data)

func _handle_find_section(data) -> void:
	_set_busy(false, "signup")
	var section_doc = null
	if data is Array and data.size() > 0:
		var first = data[0]
		if first is Dictionary and "document" in first:
			section_doc = first["document"]
	if section_doc == null:
		_show_err(_signup_err, "Join code not found.\nCheck with your teacher.")
		_delete_auth_user()
		return
	var parts := (section_doc.get("name", "") as String).split("/")
	_pending_section_id = parts[-1]
	_write_user_to_firestore()

func _write_user_to_firestore() -> void:
	_pending_action   = "write_user"
	_set_busy(true, "signup")
	_signup_spin.text = "⏳ Creating your profile..."
	var today := Time.get_date_string_from_system()
	var doc   := {
		"fields": {
			"username":      {"stringValue": _pending_name},
			"email":         {"stringValue": _pending_email},
			"role":          {"stringValue": "student"},
			"course":        {"stringValue": _pending_course},
			"section":       {"stringValue": _pending_section},
			"section_id":    {"stringValue": _pending_section_id},
			"title":         {"stringValue": ""},
			"selected_hero": {"stringValue": ""},
			"progress":      {"mapValue": {"fields": {}}},
			"stats": {"mapValue": {"fields": {
				"total_score":    {"integerValue": "0"},
				"perfect_clears": {"integerValue": "0"},
				"login_streak":   {"integerValue": "1"},
				"last_login":     {"stringValue": today},
			}}},
		}
	}
	_http_db.request(
		"%s/users/%s?key=%s&currentDocument.exists=false" % [FS_BASE, _pending_uid, FB_API_KEY],
		JSON_HEADERS + ["Authorization: Bearer " + _pending_token],
		HTTPClient.METHOD_PATCH, JSON.stringify(doc))

func _handle_write_user(_data) -> void:
	_set_busy(false, "signup")
	_join_section_in_firestore()

func _join_section_in_firestore() -> void:
	_pending_action   = "join_section"
	_set_busy(true, "signup")
	_signup_spin.text = "⏳ Joining section..."
	var today := Time.get_date_string_from_system()
	var doc   := {
		"fields": {
			"course":    {"stringValue": _pending_course},
			"section":   {"stringValue": _pending_section},
			"joined_at": {"stringValue": today},
		}
	}
	_http_fs2.request(
		"%s/sections/%s/students/%s?key=%s" % [FS_BASE, _pending_section_id, _pending_uid, FB_API_KEY],
		JSON_HEADERS + ["Authorization: Bearer " + _pending_token],
		HTTPClient.METHOD_PATCH, JSON.stringify(doc))

func _handle_read_user(data) -> void:
	var username := _pending_email.get_slice("@", 0)
	var hero := ""; var course := ""; var section := ""; var section_id := ""
	if data is Dictionary and "fields" in data:
		var f: Dictionary = data["fields"]
		username   = _fs_str(f, "username",      username)
		hero       = _fs_str(f, "selected_hero", "")
		course     = _fs_str(f, "course",        "")
		section    = _fs_str(f, "section",       "")
		section_id = _fs_str(f, "section_id",    "")
	_finish_login(username, _pending_uid, _pending_token, hero, course, section, section_id)

# ── FIRESTORE2 RESPONSE (section join) ────────────────────────────────────────
func _on_firestore2_response(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	_set_busy(false, "signup")
	_finish_login(_pending_name, _pending_uid, _pending_token,
		"", _pending_course, _pending_section, _pending_section_id)

# ── DELETE AUTH (cleanup on bad join code) ─────────────────────────────────────
func _delete_auth_user() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(
		"https://identitytoolkit.googleapis.com/v1/accounts:delete?key=" + FB_API_KEY,
		JSON_HEADERS, HTTPClient.METHOD_POST,
		JSON.stringify({"idToken": _pending_token}))

# ── FINISH ─────────────────────────────────────────────────────────────────────
func _finish_login(display_name: String, uid: String, token: String,
				   hero: String = "", course: String = "",
				   section: String = "", section_id: String = "") -> void:
	if has_node("/root/PlayerProfile"):
		PlayerProfile.uid      = uid
		PlayerProfile.username = display_name
		PlayerProfile.email    = _pending_email
		if "selected_hero" in PlayerProfile: PlayerProfile.selected_hero = hero
		if "course"        in PlayerProfile: PlayerProfile.course     = course
		if "section"       in PlayerProfile: PlayerProfile.section    = section
		if "section_id"    in PlayerProfile: PlayerProfile.section_id = section_id
		PlayerProfile._loaded = true
	if has_node("/root/SaveManager"):
		SaveManager.set_player_name(display_name)
		SaveManager._data["uid"]      = uid
		SaveManager._data["id_token"] = token
		SaveManager._data["hero"]     = hero
		SaveManager._data["course"]   = course
		SaveManager._data["section"]  = section
		SaveManager.save_game()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	if hero.is_empty() and has_node("/root/GameRouter"):
		tw.tween_callback(GameRouter.go_char_select)
	elif has_node("/root/GameRouter"):
		tw.tween_callback(GameRouter.go_to_world_map)
	else:
		tw.tween_callback(get_tree().reload_current_scene)

# ── HELPERS ────────────────────────────────────────────────────────────────────
func _fs_str(fields: Dictionary, key: String, default_val: String) -> String:
	if key in fields and fields[key] is Dictionary:
		return fields[key].get("stringValue", default_val)
	return default_val

func _set_busy(busy: bool, action: String) -> void:
	_login_btn.disabled  = busy
	_signup_btn.disabled = busy
	if is_instance_valid($GuestBtn): $GuestBtn.disabled = busy
	if action == "login":
		_login_spin.visible = busy
		if busy: _login_err.visible = false
	elif action in ["signup", "find_section", "write_user", "join_section"]:
		_signup_spin.visible = busy
		if busy: _signup_err.visible = false

func _show_err_by_action(msg: String) -> void:
	if _pending_action in ["login", "read_user"]:
		_show_err(_login_err, msg)
	else:
		_show_err(_signup_err, msg)

func _show_err(lbl: Label, msg: String) -> void:
	lbl.text    = msg
	lbl.visible = true
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
	var orig := lbl.position
	var tw   := lbl.create_tween()
	for _i in range(4):
		tw.tween_property(lbl, "position", orig + Vector2(6, 0), 0.04)
		tw.tween_property(lbl, "position", orig, 0.04)
