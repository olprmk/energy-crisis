class_name Sfx
extends Node
## PC-speaker style sound effects, generated in code (square waves, noise) — no audio files needed.

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
		"off": return _join([_tone([320, 160], 0.035, 0.25), _sweep(700.0, 140.0, 0.16, 0.16)])
		"spark": return _noise(0.18, 0.28, 18.0, 0.55, true)
		"bang": return _mix(_noise(0.7, 0.5, 6.0, 0.18, false), _sweep(110.0, 38.0, 0.45, 0.4))
	return _tone([440], 0.1, 0.2)


func _sweep(f0: float, f1: float, dur: float, vol: float) -> AudioStreamWAV:
	## Square wave gliding from f0 to f1 (Hz), fading out: a "power down" whine / a low thump.
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for s in n:
		var k := float(s) / n
		ph += lerpf(f0, f1, k) / RATE
		var v := vol if fmod(ph, 1.0) < 0.5 else -vol
		data.encode_s16(s * 2, int(v * (1.0 - k) * 32767.0))
	return _wav(data)


func _noise(dur: float, vol: float, decay: float, smooth: float, crackle: bool) -> AudioStreamWAV:
	## Noise burst decaying exponentially; smooth 0..1 = a simple low-pass (higher = duller, a bang);
	## crackle: chopped into random little bits (electric sparks).
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var y := 0.0
	var gate := 1.0
	for s in n:
		var t := float(s) / RATE
		if crackle and s % 180 == 0:
			gate = 1.0 if randf() < 0.55 else 0.15
		y = lerpf(randf_range(-1.0, 1.0), y, smooth)
		var v := y * vol * exp(-t * decay) * gate * minf(1.0, float(s) / (RATE * 0.002))
		data.encode_s16(s * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _join(parts: Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	for p in parts:
		data.append_array((p as AudioStreamWAV).data)
	return _wav(data)


func _mix(a: AudioStreamWAV, b: AudioStreamWAV) -> AudioStreamWAV:
	var n := maxi(a.data.size(), b.data.size()) / 2
	var data := PackedByteArray()
	data.resize(n * 2)
	for s in n:
		var v := 0
		if s * 2 < a.data.size():
			v += a.data.decode_s16(s * 2)
		if s * 2 < b.data.size():
			v += b.data.decode_s16(s * 2)
		data.encode_s16(s * 2, clampi(v, -32767, 32767))
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


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
