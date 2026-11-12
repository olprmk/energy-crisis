extends Node
## Footsteps: assets/sounds/steps/<style>_<surface>_<n>.wav (made by src/sounds/footsteps.py).
## style: barefoot / paws / slippers / sneakers (CHARACTERS "steps"); surface: wood / tile (the room's floor).
## Every step takes a random recording (never the same twice in a row) with a slightly different pitch and loudness.

const DIR := "res://assets/sounds/steps/"
const TAKES := 5

var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _cache := {}   # "style_surface" -> Array[AudioStream]
var _last := {}    # "style_surface" -> index of the last take


func _ready() -> void:
	for i in 4:   # the dog's paws overlap
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(style: String, surface: String, gain_db := 0.0) -> void:
	var key := style + "_" + surface
	if not _cache.has(key):
		var takes: Array[AudioStream] = []
		for k in TAKES:
			var path := DIR + "%s_%d.wav" % [key, k + 1]
			if ResourceLoader.exists(path):
				takes.append(load(path))
		_cache[key] = takes
	var takes: Array = _cache[key]
	if takes.is_empty():
		return
	var k := randi() % takes.size()
	if takes.size() > 1 and k == int(_last.get(key, -1)):
		k = (k + 1 + randi() % (takes.size() - 1)) % takes.size()
	_last[key] = k
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = takes[k]
	p.pitch_scale = randf_range(0.94, 1.06)
	p.volume_db = GameConfig.STEP_VOLUME_DB + gain_db + randf_range(-1.5, 1.5)
	p.play()
