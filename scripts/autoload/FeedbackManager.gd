# FeedbackManager.gd
# Autoload Singleton — Add as "FeedbackManager" in Project > Autoload
# Central hub for all correct/wrong visual + audio feedback and score tracking.
extends Node

signal score_changed(v: int)
signal combo_changed(v: int)
signal lives_changed(v: int)

var score: int = 0
var combo: int = 0
var lives: int = 3
var _combo_decay: float = 0.0
const COMBO_TTL := 3.0
const C_OK  := Color(0.2, 1.0, 0.35)
const C_BAD := Color(1.0, 0.15, 0.15)
const C_WHT := Color.WHITE

func _process(delta: float) -> void:
	if combo > 0:
		_combo_decay -= delta
		if _combo_decay <= 0.0:
			combo = 0
			combo_changed.emit(0)

func reset(starting_lives: int = 3) -> void:
	score = 0; combo = 0; lives = starting_lives
	score_changed.emit(0); combo_changed.emit(0); lives_changed.emit(lives)

# ── Correct action ────────────────────────────────────────────────────────────
func correct(node: CanvasItem, base_pts: int = 10) -> void:
	combo += 1
	_combo_decay = COMBO_TTL
	combo_changed.emit(combo)
	var earned := base_pts * (1 + combo / 5)
	score += earned
	score_changed.emit(score)
	_flash(node, C_OK)
	_bounce(node)
	_float_label(node, "+%d" % earned, C_OK, Vector2(0, -40))
	if combo > 1:
		_float_label(node, "×%d COMBO!" % combo, Color(1,0.9,0), Vector2(0,-64))
	_sfx("success")

# ── Wrong action ──────────────────────────────────────────────────────────────
func wrong(node: CanvasItem, penalty: int = 0) -> void:
	combo = 0; combo_changed.emit(0)
	if penalty > 0:
		score = max(0, score - penalty)
		score_changed.emit(score)
	lives -= 1; lives_changed.emit(lives)
	_flash(node, C_BAD)
	_shake(node)
	_float_label(node, "✗ -%d" % penalty if penalty > 0 else "✗", C_BAD, Vector2(0,-40))
	_sfx("fail")

# ── Info label (no score change) ─────────────────────────────────────────────
func info(node: CanvasItem, text: String) -> void:
	_float_label(node, text, Color(0.9,0.9,0.9), Vector2(0,-40))

# ── Animations ───────────────────────────────────────────────────────────────
func _flash(node: CanvasItem, c: Color) -> void:
	if not is_instance_valid(node): return
	var tw := node.create_tween()
	tw.tween_property(node,"modulate",c,0.06)
	tw.tween_property(node,"modulate",C_WHT,0.22)

func _bounce(node: CanvasItem) -> void:
	if not is_instance_valid(node): return
	var s: Vector2 = node.scale
	var tw := node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node,"scale",s*1.4,0.08)
	tw.tween_property(node,"scale",s,0.18)

func _shake(node: CanvasItem) -> void:
	if not is_instance_valid(node): return
	var o: Vector2 = node.position
	var tw := node.create_tween()
	for i in 6:
		tw.tween_property(node,"position",o+Vector2(randf_range(-7,7),randf_range(-4,4)),0.04)
	tw.tween_property(node,"position",o,0.04)

func _float_label(node: CanvasItem, text: String, c: Color, off: Vector2) -> void:
	if not is_instance_valid(node): return
	var par := node.get_parent()
	if not par: return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", c)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.z_index = 200
	par.add_child(lbl)
	lbl.global_position = node.global_position + off
	var tw := lbl.create_tween()
	tw.tween_property(lbl,"position",lbl.position+Vector2(0,-44),0.75)
	tw.parallel().tween_property(lbl,"modulate:a",0.0,0.75)
	tw.tween_callback(lbl.queue_free)

func _sfx(key: String) -> void:
	if has_node("/root/AudioManager"):
		AudioManager.play_sfx(key)
