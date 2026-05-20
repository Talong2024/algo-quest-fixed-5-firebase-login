# LoginScreen.gd — AlgoQuest
# Redesigned: styled card panel, themed inputs/buttons, star BG, centred layout
extends Control

const FB_API_KEY  := "AIzaSyC6r1sMMfdWqcSB2_-FH7ZsySKrPLVogrk"
const FB_SIGNUP   := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key="
const FB_LOGIN    := "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key="
const FS_BASE     := "https://firestore.googleapis.com/v1/projects/algoquest-3f812/databases/(default)/documents"
const FS_QUERY    := "https://firestore.googleapis.com/v1/projects/algoquest-3f812/databases/(default)/documents:runQuery"
const PATH_FONT   := "res://assets/fonts/freepixel.ttf"
const JSON_HDR    := ["Content-Type: application/json"]

# Theme colours
const C_BG        := Color("#080912")
const C_CARD      := Color("#0e101e")
const C_BORDER    := Color("#2a3a6a")
const C_ACCENT    := Color("#4D96FF")
const C_GOLD      := Color("#FFD93D")
const C_TEXT      := Color("#c8cce8")
const C_DIM       := Color("#6668a0")
const C_INPUT_BG  := Color("#13152a")
const C_INPUT_BDR := Color("#2a3060")
const C_ERR       := Color("#ff5555")

# ── @onready — paths match the new tscn ──────────────────────────────────────
@onready var _logo:        Label        = $CenterAnchor/CardPanel/CardVBox/LogoLabel
@onready var _tabs:        TabContainer = $CenterAnchor/CardPanel/CardVBox/TabContainer
@onready var _email_in:    LineEdit     = $CenterAnchor/CardPanel/CardVBox/TabContainer/LoginTab/EmailInput
@onready var _pass_in:     LineEdit     = $CenterAnchor/CardPanel/CardVBox/TabContainer/LoginTab/PassInput
@onready var _login_btn:   Button       = $CenterAnchor/CardPanel/CardVBox/TabContainer/LoginTab/LoginBtn
@onready var _login_err:   Label        = $CenterAnchor/CardPanel/CardVBox/TabContainer/LoginTab/LoginError
@onready var _login_spin:  Label        = $CenterAnchor/CardPanel/CardVBox/TabContainer/LoginTab/SpinLabel
@onready var _name_in:     LineEdit     = $CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/NameInput
@onready var _email_in2:   LineEdit     = $CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/EmailInput2
@onready var _pass_in2:    LineEdit     = $CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/PassInput2
@onready var _signup_btn:  Button       = $CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/SignupBtn
@onready var _signup_err:  Label        = $CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/SignupError
@onready var _signup_spin: Label        = $CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/SpinLabel2
@onready var _http_auth:   HTTPRequest  = $HTTPAuth
@onready var _http_db:     HTTPRequest  = $HTTPDb
@onready var _card:        PanelContainer = $CenterAnchor/CardPanel
@onready var _guest_btn:   Button       = $CenterAnchor/GuestBtn

# Injected signup fields (appended to SignupTab at runtime)
var _course_in:  LineEdit = null
var _section_in: LineEdit = null
var _code_in:    LineEdit = null
var _http_fs2:   HTTPRequest = null

# State
var _pending_action:     String = ""
var _pending_name:       String = ""
var _pending_email:      String = ""
var _pending_uid:        String = ""
var _pending_token:      String = ""
var _pending_course:     String = ""
var _pending_section:    String = ""
var _pending_section_id: String = ""

var _pixel_font: Font = null
var _stars: Array = []

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_pixel_font = load(PATH_FONT) if ResourceLoader.exists(PATH_FONT) else null
	_generate_stars()
	_style_card()
	_style_inputs()
	_style_buttons()
	_setup_logic()
	_inject_signup_fields()
	_http_auth.request_completed.connect(_on_auth_response)
	_http_db.request_completed.connect(_on_firestore_response)
	_http_fs2 = HTTPRequest.new(); add_child(_http_fs2)
	_http_fs2.request_completed.connect(_on_firestore2_response)
	modulate = Color(1,1,1,0)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)

# ── Star field (drawn in _draw) ────────────────────────────────────────────────
func _generate_stars() -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 77
	for _i in range(160):
		_stars.append({"pos": Vector2(rng.randf_range(0,1280), rng.randf_range(0,720)),
					   "r": rng.randf_range(0.5, 1.8), "b": rng.randf_range(0.2, 0.7)})

func _draw() -> void:
	for s in _stars:
		var p: Vector2 = s["pos"] as Vector2; var b: float = s["b"] as float
		draw_circle(p, s["r"] as float, Color(b*0.8, b*0.85, b, b))

# ── Card panel styling ────────────────────────────────────────────────────────
func _style_card() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color           = C_CARD
	sb.border_color       = C_BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.shadow_color       = Color(0, 0, 0, 0.55)
	sb.shadow_size        = 18
	sb.content_margin_left   = 32
	sb.content_margin_right  = 32
	sb.content_margin_top    = 28
	sb.content_margin_bottom = 28
	_card.add_theme_stylebox_override("panel", sb)

	# Logo
	if _pixel_font: _logo.add_theme_font_override("font", _pixel_font)
	_logo.add_theme_font_size_override("font_size", 46)
	_logo.add_theme_color_override("font_color", C_GOLD)
	_logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Subtitle
	var sub_lbl: Label = $CenterAnchor/CardPanel/CardVBox/SubtitleLabel as Label
	if is_instance_valid(sub_lbl):
		if _pixel_font: sub_lbl.add_theme_font_override("font", _pixel_font)
		sub_lbl.add_theme_font_size_override("font_size", 12)
		sub_lbl.add_theme_color_override("font_color", C_DIM)
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Tab container
	_tabs.add_theme_color_override("font_selected_color",   C_ACCENT)
	_tabs.add_theme_color_override("font_unselected_color", C_DIM)
	_tabs.add_theme_color_override("font_hovered_color",    C_TEXT)

	# Corner ornaments
	for nm in ["CornerTL","CornerTR","CornerBL","CornerBR"]:
		if has_node(nm):
			var lbl: Label = get_node(nm) as Label
			lbl.add_theme_color_override("font_color", C_BORDER)
			if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)

	# Guest button
	if is_instance_valid(_guest_btn):
		if _pixel_font: _guest_btn.add_theme_font_override("font", _pixel_font)
		_guest_btn.add_theme_font_size_override("font_size", 13)
		_guest_btn.add_theme_color_override("font_color", C_DIM)
		var gsb := StyleBoxFlat.new()
		gsb.bg_color = Color(0,0,0,0); gsb.border_color = C_BORDER
		gsb.set_border_width_all(1); gsb.set_corner_radius_all(6)
		_guest_btn.add_theme_stylebox_override("normal",  gsb)
		var ghsb := gsb.duplicate() as StyleBoxFlat
		ghsb.bg_color = C_CARD
		_guest_btn.add_theme_stylebox_override("hover",   ghsb)
		_guest_btn.add_theme_stylebox_override("pressed", ghsb)

# ── Input styling ─────────────────────────────────────────────────────────────
func _style_inputs() -> void:
	var inputs: Array[LineEdit] = [_email_in, _pass_in, _name_in, _email_in2, _pass_in2]
	for le: LineEdit in inputs:
		if not is_instance_valid(le): continue
		if _pixel_font: le.add_theme_font_override("font", _pixel_font)
		le.add_theme_font_size_override("font_size", 14)
		le.add_theme_color_override("font_color", C_TEXT)
		le.add_theme_color_override("font_placeholder_color", C_DIM)
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_INPUT_BG; sb.border_color = C_INPUT_BDR
		sb.set_border_width_all(1); sb.set_corner_radius_all(6)
		sb.content_margin_left = 12; sb.content_margin_right = 12
		sb.content_margin_top  = 10; sb.content_margin_bottom = 10
		le.add_theme_stylebox_override("normal", sb)
		var fsb := sb.duplicate() as StyleBoxFlat
		fsb.border_color = C_ACCENT
		le.add_theme_stylebox_override("focus", fsb)

	for lbl_path in [
		"CenterAnchor/CardPanel/CardVBox/TabContainer/LoginTab/EmailLabel",
		"CenterAnchor/CardPanel/CardVBox/TabContainer/LoginTab/PassLabel",
		"CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/NameLabel",
		"CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/EmailLabel2",
		"CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab/PassLabel2",
	]:
		if has_node(lbl_path):
			var l: Label = get_node(lbl_path) as Label
			l.add_theme_color_override("font_color", C_DIM)
			l.add_theme_font_size_override("font_size", 12)
			if _pixel_font: l.add_theme_font_override("font", _pixel_font)

	for lbl in [_login_err, _signup_err, _login_spin, _signup_spin]:
		if not is_instance_valid(lbl): continue
		if _pixel_font: lbl.add_theme_font_override("font", _pixel_font)
		lbl.add_theme_font_size_override("font_size", 12)

# ── Button styling ────────────────────────────────────────────────────────────
func _style_buttons() -> void:
	_style_primary_btn(_login_btn,  C_ACCENT)
	_style_primary_btn(_signup_btn, C_GOLD)

func _style_primary_btn(btn: Button, accent: Color) -> void:
	if not is_instance_valid(btn): return
	if _pixel_font: btn.add_theme_font_override("font", _pixel_font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color("#0a0a18"))
	btn.add_theme_color_override("font_hover_color",   Color("#0a0a18"))
	btn.add_theme_color_override("font_pressed_color", Color("#0a0a18"))
	btn.add_theme_color_override("font_disabled_color", C_DIM)
	var sn := StyleBoxFlat.new()
	sn.bg_color = accent; sn.border_color = accent.lightened(0.25)
	sn.set_border_width_all(0); sn.set_corner_radius_all(8)
	sn.content_margin_top = 10; sn.content_margin_bottom = 10
	var sh := sn.duplicate() as StyleBoxFlat; sh.bg_color = accent.lightened(0.18)
	var sp := sn.duplicate() as StyleBoxFlat; sp.bg_color = accent.darkened(0.18)
	var sd := sn.duplicate() as StyleBoxFlat; sd.bg_color = Color("#1a1a2a")
	btn.add_theme_stylebox_override("normal",   sn)
	btn.add_theme_stylebox_override("hover",    sh)
	btn.add_theme_stylebox_override("pressed",  sp)
	btn.add_theme_stylebox_override("disabled", sd)

# ── Logic wiring ──────────────────────────────────────────────────────────────
func _setup_logic() -> void:
	_login_err.visible   = false; _signup_err.visible  = false
	_login_spin.visible  = false; _signup_spin.visible = false
	_login_btn.text      = "▶  Login"
	_signup_btn.text     = "★  Create Account"
	_login_btn.pressed.connect(_on_login_pressed)
	_signup_btn.pressed.connect(_on_signup_pressed)
	_pass_in.text_submitted.connect(func(_t): _on_login_pressed())
	if is_instance_valid(_guest_btn):
		_guest_btn.text = "👤  Play as Guest"
		_guest_btn.pressed.connect(_on_guest)

# ── Inject course/section/code fields into SignupTab ─────────────────────────
func _inject_signup_fields() -> void:
	var stab: VBoxContainer = $CenterAnchor/CardPanel/CardVBox/TabContainer/SignupTab as VBoxContainer
	var idx: int = _signup_btn.get_index()

	var sep := Label.new(); sep.text = "Course & Section"
	if _pixel_font: sep.add_theme_font_override("font", _pixel_font)
	sep.add_theme_font_size_override("font_size", 12)
	sep.add_theme_color_override("font_color", C_DIM)
	stab.add_child(sep); stab.move_child(sep, idx)

	var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 10)
	stab.add_child(row); stab.move_child(row, idx + 1)

	_course_in = LineEdit.new()
	_course_in.placeholder_text = "Course (e.g. BSIT)"
	_course_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_course_in.custom_minimum_size   = Vector2(0, 44)
	row.add_child(_course_in)

	_section_in = LineEdit.new()
	_section_in.placeholder_text    = "Section (e.g. 2A)"
	_section_in.custom_minimum_size = Vector2(130, 44)
	row.add_child(_section_in)

	for le in [_course_in, _section_in]:
		if _pixel_font: le.add_theme_font_override("font", _pixel_font)
		le.add_theme_font_size_override("font_size", 14)
		le.add_theme_color_override("font_color", C_TEXT)
		le.add_theme_color_override("font_placeholder_color", C_DIM)
		var sb := StyleBoxFlat.new()
		sb.bg_color = C_INPUT_BG; sb.border_color = C_INPUT_BDR
		sb.set_border_width_all(1); sb.set_corner_radius_all(6)
		sb.content_margin_left = 12; sb.content_margin_right = 12
		sb.content_margin_top  = 10; sb.content_margin_bottom = 10
		le.add_theme_stylebox_override("normal", sb)
		var fsb := sb.duplicate() as StyleBoxFlat; fsb.border_color = C_ACCENT
		le.add_theme_stylebox_override("focus", fsb)

	var code_lbl := Label.new(); code_lbl.text = "Join Code (from your teacher)"
	if _pixel_font: code_lbl.add_theme_font_override("font", _pixel_font)
	code_lbl.add_theme_font_size_override("font_size", 12)
	code_lbl.add_theme_color_override("font_color", C_DIM)
	stab.add_child(code_lbl); stab.move_child(code_lbl, idx + 2)

	_code_in = LineEdit.new()
	_code_in.placeholder_text    = "Enter the join code"
	_code_in.custom_minimum_size = Vector2(460, 44)
	_code_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if _pixel_font: _code_in.add_theme_font_override("font", _pixel_font)
	_code_in.add_theme_font_size_override("font_size", 14)
	_code_in.add_theme_color_override("font_color", C_TEXT)
	_code_in.add_theme_color_override("font_placeholder_color", C_DIM)
	var csb := StyleBoxFlat.new()
	csb.bg_color = C_INPUT_BG; csb.border_color = C_INPUT_BDR
	csb.set_border_width_all(1); csb.set_corner_radius_all(6)
	csb.content_margin_left = 12; csb.content_margin_right = 12
	csb.content_margin_top  = 10; csb.content_margin_bottom = 10
	_code_in.add_theme_stylebox_override("normal", csb)
	var cfsb := csb.duplicate() as StyleBoxFlat; cfsb.border_color = C_ACCENT
	_code_in.add_theme_stylebox_override("focus", cfsb)
	_code_in.text_submitted.connect(func(_t): _on_signup_pressed())
	stab.add_child(_code_in); stab.move_child(_code_in, idx + 3)

# ── LOGIN ──────────────────────────────────────────────────────────────────────
func _on_login_pressed() -> void:
	var email := _email_in.text.strip_edges()
	var pwd   := _pass_in.text
	if email.is_empty() or pwd.is_empty():
		_show_err(_login_err, "Please fill in all fields."); return
	_set_busy(true, "login"); _pending_action = "login"; _pending_email = email
	_http_auth.request(FB_LOGIN + FB_API_KEY, JSON_HDR, HTTPClient.METHOD_POST,
		JSON.stringify({"email": email, "password": pwd, "returnSecureToken": true}))

# ── SIGNUP ─────────────────────────────────────────────────────────────────────
func _on_signup_pressed() -> void:
	var name_    := _name_in.text.strip_edges()
	var email_   := _email_in2.text.strip_edges()
	var pwd_     := _pass_in2.text
	var course_  := _course_in.text.strip_edges()  if _course_in  else ""
	var section_ := _section_in.text.strip_edges().to_upper() if _section_in else ""
	var code_    := _code_in.text.strip_edges().to_upper()    if _code_in    else ""
	if name_.is_empty() or email_.is_empty() or pwd_.is_empty():
		_show_err(_signup_err, "Please fill in all fields."); return
	if pwd_.length() < 6:
		_show_err(_signup_err, "Password must be at least 6 characters."); return
	if course_.is_empty() or section_.is_empty():
		_show_err(_signup_err, "Please enter your course and section."); return
	if code_.is_empty():
		_show_err(_signup_err, "Please enter the join code\nfrom your teacher."); return
	_set_busy(true, "signup"); _pending_action = "signup"
	_pending_name = name_; _pending_email = email_
	_pending_course = course_; _pending_section = section_; _pending_section_id = code_
	_http_auth.request(FB_SIGNUP + FB_API_KEY, JSON_HDR, HTTPClient.METHOD_POST,
		JSON.stringify({"email": email_, "password": pwd_, "returnSecureToken": true}))

# ── GUEST ──────────────────────────────────────────────────────────────────────
func _on_guest() -> void:
	_finish_login("Guest", "guest_%d" % randi(), "", "", "", "")

# ── AUTH RESPONSE ──────────────────────────────────────────────────────────────
func _on_auth_response(_r, _c, _h, body: PackedByteArray) -> void:
	_set_busy(false, _pending_action)
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		_show_err_by_action("Network error. Check your connection."); return
	if "error" in data:
		var msg: String = data["error"].get("message", "Unknown error")
		match msg:
			"EMAIL_EXISTS":              _show_err_by_action("Email already registered.\nPlease log in instead.")
			"EMAIL_NOT_FOUND","INVALID_LOGIN_CREDENTIALS","INVALID_PASSWORD":
				_show_err_by_action("Wrong email or password.")
			"WEAK_PASSWORD : Password should be at least 6 characters":
				_show_err_by_action("Password must be at least 6 characters.")
			"INVALID_EMAIL":             _show_err_by_action("Please enter a valid email address.")
			_:                           _show_err_by_action("Error: " + msg)
		return
	_pending_uid   = data.get("localId", "")
	_pending_token = data.get("idToken", "")
	if _pending_action == "signup": _find_section_by_code(_pending_section_id)
	else:                           _read_user_from_firestore()

# ── FIND SECTION ───────────────────────────────────────────────────────────────
func _find_section_by_code(code: String) -> void:
	_pending_action = "find_section"; _set_busy(true, "signup")
	_signup_spin.text = "⏳ Verifying join code..."
	_http_db.request(FS_QUERY + "?key=" + FB_API_KEY,
		JSON_HDR + ["Authorization: Bearer " + _pending_token],
		HTTPClient.METHOD_POST,
		JSON.stringify({"structuredQuery": {"from": [{"collectionId": "sections"}],
			"where": {"fieldFilter": {"field": {"fieldPath": "join_code"},
				"op": "EQUAL", "value": {"stringValue": code}}}, "limit": 1}}))

# ── READ USER (login) ──────────────────────────────────────────────────────────
func _read_user_from_firestore() -> void:
	_pending_action = "read_user"
	_http_db.request("%s/users/%s?key=%s" % [FS_BASE, _pending_uid, FB_API_KEY],
		JSON_HDR + ["Authorization: Bearer " + _pending_token],
		HTTPClient.METHOD_GET, "")

# ── FIRESTORE RESPONSE ─────────────────────────────────────────────────────────
func _on_firestore_response(_r, _c, _h, body: PackedByteArray) -> void:
	var data = JSON.parse_string(body.get_string_from_utf8())
	match _pending_action:
		"find_section": _handle_find_section(data)
		"read_user":    _handle_read_user(data)
		"write_user":   _handle_write_user(data)

func _handle_find_section(data) -> void:
	_set_busy(false, "signup")
	var doc = null
	if data is Array and data.size() > 0:
		var f = data[0]
		if f is Dictionary and "document" in f: doc = f["document"]
	if doc == null:
		_show_err(_signup_err, "Join code not found.\nCheck with your teacher.")
		_delete_auth_user(); return
	var parts: Array = (doc.get("name","") as String).split("/")
	_pending_section_id = parts[-1]
	_write_user_to_firestore()

func _write_user_to_firestore() -> void:
	_pending_action = "write_user"; _set_busy(true, "signup")
	_signup_spin.text = "⏳ Creating your profile..."
	var today := Time.get_date_string_from_system()
	_http_db.request(
		"%s/users/%s?key=%s&currentDocument.exists=false" % [FS_BASE, _pending_uid, FB_API_KEY],
		JSON_HDR + ["Authorization: Bearer " + _pending_token],
		HTTPClient.METHOD_PATCH,
		JSON.stringify({"fields": {
			"username":   {"stringValue": _pending_name},
			"email":      {"stringValue": _pending_email},
			"role":       {"stringValue": "student"},
			"course":     {"stringValue": _pending_course},
			"section":    {"stringValue": _pending_section},
			"section_id": {"stringValue": _pending_section_id},
			"title":      {"stringValue": ""},
			"progress":   {"mapValue": {"fields": {}}},
			"stats": {"mapValue": {"fields": {
				"total_score":    {"integerValue": "0"},
				"perfect_clears": {"integerValue": "0"},
				"login_streak":   {"integerValue": "1"},
				"last_login":     {"stringValue": today},
			}}},
		}}))

func _handle_write_user(_data) -> void:
	_set_busy(false, "signup"); _join_section_in_firestore()

func _join_section_in_firestore() -> void:
	_pending_action = "join_section"; _set_busy(true, "signup")
	_signup_spin.text = "⏳ Joining section..."
	_http_fs2.request(
		"%s/sections/%s/students/%s?key=%s" % [FS_BASE, _pending_section_id, _pending_uid, FB_API_KEY],
		JSON_HDR + ["Authorization: Bearer " + _pending_token],
		HTTPClient.METHOD_PATCH,
		JSON.stringify({"fields": {
			"course":    {"stringValue": _pending_course},
			"section":   {"stringValue": _pending_section},
			"joined_at": {"stringValue": Time.get_date_string_from_system()},
		}}))

func _handle_read_user(data) -> void:
	var username := _pending_email.get_slice("@", 0)
	var course := ""; var section := ""; var section_id := ""
	if data is Dictionary and "fields" in data:
		var f: Dictionary = data["fields"]
		username   = _fs_str(f, "username",   username)
		course     = _fs_str(f, "course",     "")
		section    = _fs_str(f, "section",    "")
		section_id = _fs_str(f, "section_id", "")
	_finish_login(username, _pending_uid, _pending_token, course, section, section_id)

func _on_firestore2_response(_r, _c, _h, _body: PackedByteArray) -> void:
	_set_busy(false, "signup")
	_finish_login(_pending_name, _pending_uid, _pending_token,
		_pending_course, _pending_section, _pending_section_id)

func _delete_auth_user() -> void:
	var http := HTTPRequest.new(); add_child(http)
	http.request("https://identitytoolkit.googleapis.com/v1/accounts:delete?key=" + FB_API_KEY,
		JSON_HDR, HTTPClient.METHOD_POST, JSON.stringify({"idToken": _pending_token}))

# ── FINISH LOGIN ───────────────────────────────────────────────────────────────
func _finish_login(display_name: String, uid: String, token: String,
				   course: String = "", section: String = "",
				   section_id: String = "") -> void:
	if has_node("/root/SaveManager"):
		SaveManager.set_player_name(display_name)
		SaveManager._data["uid"]      = uid
		SaveManager._data["id_token"] = token
		SaveManager._data["course"]   = course
		SaveManager._data["section"]  = section
		SaveManager.save_game()

	if uid.begins_with("guest_") or token.is_empty():
		if has_node("/root/PlayerProfile"):
			PlayerProfile.uid = uid; PlayerProfile.username = display_name
			PlayerProfile.email = _pending_email; PlayerProfile._loaded = true
		_fade_to_world_map(); return

	if has_node("/root/PlayerProfile"):
		PlayerProfile.username = display_name; PlayerProfile.email = _pending_email
		if "course"     in PlayerProfile: PlayerProfile.course     = course
		if "section"    in PlayerProfile: PlayerProfile.section    = section
		if "section_id" in PlayerProfile: PlayerProfile.section_id = section_id
		if not PlayerProfile.profile_loaded.is_connected(_on_profile_loaded):
			PlayerProfile.profile_loaded.connect(_on_profile_loaded, CONNECT_ONE_SHOT)
		PlayerProfile.init_from_login(uid, _pending_email, token)
	else:
		_fade_to_world_map()

func _on_profile_loaded() -> void: _fade_to_world_map()

func _fade_to_world_map() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	if has_node("/root/GameRouter"): tw.tween_callback(GameRouter.go_to_world_map)
	else: tw.tween_callback(get_tree().reload_current_scene)

# ── Helpers ────────────────────────────────────────────────────────────────────
func _fs_str(fields: Dictionary, key: String, default_val: String) -> String:
	if key in fields and fields[key] is Dictionary:
		return fields[key].get("stringValue", default_val)
	return default_val

func _set_busy(busy: bool, action: String) -> void:
	_login_btn.disabled = busy; _signup_btn.disabled = busy
	if is_instance_valid(_guest_btn): _guest_btn.disabled = busy
	if action == "login":
		_login_spin.visible = busy; if busy: _login_err.visible = false
	elif action in ["signup","find_section","write_user","join_section"]:
		_signup_spin.visible = busy; if busy: _signup_err.visible = false

func _show_err_by_action(msg: String) -> void:
	if _pending_action in ["login","read_user"]: _show_err(_login_err, msg)
	else: _show_err(_signup_err, msg)

func _show_err(lbl: Label, msg: String) -> void:
	lbl.text = msg; lbl.visible = true
	lbl.add_theme_color_override("font_color", C_ERR)
	var orig := lbl.position; var tw := lbl.create_tween()
	for _i in range(4):
		tw.tween_property(lbl, "position", orig + Vector2(6,0), 0.04)
		tw.tween_property(lbl, "position", orig, 0.04)
