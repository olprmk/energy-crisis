class_name Sfx
extends Node
## PC-speaker style sound effects, generated in code (square waves) — no audio files needed.

const RATE := 22050
var _players: Array[AudioStreamPlayer] = []
var _cache := {}


func _ready() -> void:
	for i in 6:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)


func play(sound: String) -> void:
	if not _cache.has(sound):
		_cache[sound] = _make(sound)
	for p in _players:
		if not p.playing:
			p.stream = _cache[sound]
			p.play()
			return
	_players[0].stream = _cache[sound]
	_players[0].play()


func _make(sound: String) -> AudioStreamWAV:
	match sound:
		"beep": return _tone([880, 0, 880], 0.07, 0.25)
		"click": return _tone([320, 160], 0.035, 0.25)
		"alarm": return _tone([620, 930], 0.16, 0.22)
		"tick": return _tone([1200], 0.04, 0.15)
		"go": return _tone([1047], 0.25, 0.22)
		"win": return _tone([523, 659, 784, 1047], 0.12, 0.22)
		"lose": return _tone([440, 370, 311, 220], 0.17, 0.22)
		"nope": return _tone([180, 0, 180], 0.08, 0.25)
		"select": return _tone([660], 0.04, 0.18)
	return _tone([440], 0.1, 0.2)


func _tone(freqs: Array, dur: float, vol: float) -> AudioStreamWAV:
	var seg := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(seg * freqs.size() * 2)
	var i := 0
	for f in freqs:
		var freq := float(f)
		for s in seg:
			var v := 0.0
			if freq > 0.0:
				v = vol if fmod(float(s) * freq / RATE, 1.0) < 0.5 else -vol
			var env := minf(1.0, float(seg - s) / (RATE * 0.008))
			data.encode_s16(i * 2, int(v * env * 32767.0))
			i += 1
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
