# AudioManager.gd — Autoload
# Add as "AudioManager" in Project > Autoload
extends Node

@onready var _bgm: AudioStreamPlayer = $BGM
@onready var _sfx: AudioStreamPlayer = $SFX

func _ready() -> void:
	_bgm.bus = "Music"
	_sfx.bus = "SFX"

func play_bgm(path: String, loop: bool = true) -> void:
	if not ResourceLoader.exists(path): return
	if _bgm.stream and _bgm.stream.resource_path == path and _bgm.playing: return
	_bgm.stream = load(path)
	if _bgm.stream is AudioStreamOggVorbis:
		(_bgm.stream as AudioStreamOggVorbis).loop = loop
	_bgm.play()

func stop_bgm() -> void:
	_bgm.stop()

func play_sfx(path: String) -> void:
	if not ResourceLoader.exists(path): return
	_sfx.stream = load(path)
	_sfx.play()

func set_bgm_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"),
		linear_to_db(clampf(linear, 0.0, 1.0)))

func set_sfx_volume(linear: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"),
		linear_to_db(clampf(linear, 0.0, 1.0)))
