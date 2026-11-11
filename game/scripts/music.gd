class_name Music
extends Node
## Adaptive background music.
## Three tracks (assets/music/calm, tension, urgent — .ogg, .wav or .mp3) are separate songs; they all play
## all the time and `intensity` 0..1 crossfades between them (equal power, so the loudness stays even):
##   calm — few appliances on; tension — several on; urgent — near the end of the round or near overload.
## In the last seconds the music speeds up and rises in pitch slightly (`hurry`).
## Result screens have their own tracks on the "Result" bus; the round music fades out under them and comes
## back on the next floor:
##   victory()  — floor passed: assets/music/victory
##   defeat()   — floor failed: assets/music/defeat
## Every file plays from its start once and then loops from LOOP_FROM (src/music/loop_tracks.py cuts the files
## so that the jump from the end back to that second is seamless).

const LAYERS := ["calm", "tension", "urgent"]
const RESULT_TRACKS := ["victory", "defeat"]
## Second from which each file loops (what comes before it plays only the first time).
const LOOP_FROM := {"calm": 2.76, "tension": 13.42, "urgent": 1.81, "victory": 2.09, "defeat": 17.83}
## Second from which a result track starts: defeat skips its quiet 16 s build-up (the result screen is short).
const START_AT := {"defeat": 16.0}

var players: Array[AudioStreamPlayer] = []
var intensity := 0.0
var target := 0.0
var hurry := 0.0
var enabled := true
var _bus := -1
var _fade := 1.0          # 0..1 master fade (power-down, result screens)
var _fade_target := 1.0
var _pitch_mul := 1.0     # power-down slows the tape
var _pitch_target := 1.0
var _fade_rate := 0.9      # how fast the round music fades out (per second)
var result_players := {}   # track name -> AudioStreamPlayer
var result_track := ""     # result track that is playing (or about to start), "" = none
var _rbus := -1
var _rvol := 0.0           # 0..1 result music fade
var _rvol_target := 0.0
var _rdelay := 0.0         # seconds until the result track starts (after a short circuit)


func _ready() -> void:
	_bus = AudioServer.get_bus_index("Music")
	if _bus < 0:
		_bus = AudioServer.bus_count
		AudioServer.add_bus(_bus)
		AudioServer.set_bus_name(_bus, "Music")
		AudioServer.set_bus_send(_bus, "Master")
	for layer in LAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		p.stream = _load(layer)
		p.volume_db = 0.0 if layer == "calm" else -80.0
		add_child(p)
		players.append(p)
	for p in players:
		if p.stream:
			p.play()   # all three run all the time; only their volumes change
	_rbus = AudioServer.get_bus_index("Result")
	if _rbus < 0:
		_rbus = AudioServer.bus_count
		AudioServer.add_bus(_rbus)
		AudioServer.set_bus_name(_rbus, "Result")
		AudioServer.set_bus_send(_rbus, "Master")
	for track in RESULT_TRACKS:
		var rp := AudioStreamPlayer.new()
		rp.bus = "Result"
		rp.stream = _load(track)
		add_child(rp)
		result_players[track] = rp
	if not GameConfig.MUSIC_ENABLED:
		toggle()
	_apply(0.0)


func _load(layer: String) -> AudioStream:
	## Imported resource if the editor has imported it; otherwise read the raw file directly,
	## so music works even before Godot rescans the project (new files dropped in from outside).
	for ext in ["ogg", "wav", "mp3"]:
		var path := "res://assets/music/%s.%s" % [layer, ext]
		var s: AudioStream = null
		if ResourceLoader.exists(path):
			s = load(path)
		elif FileAccess.file_exists(path):
			match ext:
				"ogg":
					s = AudioStreamOggVorbis.load_from_file(path)
				"wav":
					s = AudioStreamWAV.load_from_file(path)
				"mp3":
					var mp := AudioStreamMP3.new()
					mp.data = FileAccess.get_file_as_bytes(path)
					s = mp
		if s == null:
			continue
		var from: float = LOOP_FROM.get(layer, 0.0)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
			(s as AudioStreamOggVorbis).loop_offset = from
		elif s is AudioStreamMP3:
			(s as AudioStreamMP3).loop = true
			(s as AudioStreamMP3).loop_offset = from
		elif s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_begin = int(from * w.mix_rate)
			w.loop_end = int(w.get_length() * w.mix_rate)
		return s
	push_warning("Music layer not found: assets/music/%s.(ogg|wav|mp3)" % layer)
	return null


## Called every frame during a round.
func set_state(new_target: float, new_hurry: float) -> void:
	target = clampf(new_target, 0.0, 1.0)
	hurry = clampf(new_hurry, 0.0, 1.0)


func calm(fade := 1.0) -> void:
	target = 0.0
	hurry = 0.0
	_fade_target = fade
	_fade_rate = 0.9
	_pitch_target = 1.0
	_stop_result()


## Floor passed: fanfare + cheerful loop; the round music fades out quickly under it.
## Calling it again while it plays (e.g. the final screen) does not restart it.
func victory() -> void:
	if not has_track("victory"):
		calm(1.0)
		return
	_round_music_out(4.0)
	_play_result("victory", 0.0)


## Floor failed: a sad phrase + slow melancholic loop.
## delay > 0 (short circuit): the tape-stop of power_down() finishes first, then the sad music starts.
func defeat(delay := 0.0) -> void:
	if not has_track("defeat"):
		if delay <= 0.0:
			calm(0.6)
		return
	if delay <= 0.0:
		_round_music_out(2.5)
	_play_result("defeat", delay)


func has_track(track: String) -> bool:
	return result_players.has(track) and (result_players[track] as AudioStreamPlayer).stream != null


func _round_music_out(rate: float) -> void:
	target = 0.0
	hurry = 0.0
	_pitch_target = 1.0
	_fade_target = 0.0
	_fade_rate = rate


func _play_result(track: String, delay: float) -> void:
	var rp: AudioStreamPlayer = result_players[track]
	if result_track == track and _rvol_target >= 1.0 and (rp.playing or _rdelay > 0.0):
		return   # already playing: keep going
	for other in result_players:
		if other != track:
			(result_players[other] as AudioStreamPlayer).stop()
	result_track = track
	_rvol_target = 1.0
	_rdelay = delay
	if delay <= 0.0:
		_rvol = 1.0
		rp.play(START_AT.get(track, 0.0))
	else:
		rp.stop()


func _stop_result() -> void:
	_rvol_target = 0.0
	if _rdelay > 0.0:   # not started yet: just cancel it
		_rdelay = 0.0
		result_track = ""


## Fuses blown: the music winds down like a tape losing power.
func power_down() -> void:
	target = 0.0
	hurry = 0.0
	_pitch_target = 0.35
	_fade_target = 0.0
	_fade_rate = 0.9
	_stop_result()


func power_up() -> void:
	_pitch_target = 1.0
	_fade_target = 1.0
	_stop_result()


func toggle() -> bool:
	enabled = not enabled
	AudioServer.set_bus_mute(_bus, not enabled)
	if _rbus >= 0:
		AudioServer.set_bus_mute(_rbus, not enabled)
	return enabled


func _process(delta: float) -> void:
	# rise quickly, relax slowly
	var rate := 3.0 if target > intensity else 0.8
	intensity = lerpf(intensity, target, 1.0 - exp(-rate * delta))
	_fade = move_toward(_fade, _fade_target, delta * (_fade_rate if _fade_target < _fade else 1.5))
	if _rdelay > 0.0:
		_rdelay -= delta
		if _rdelay <= 0.0 and result_track != "":
			_rvol = 1.0
			(result_players[result_track] as AudioStreamPlayer).play(START_AT.get(result_track, 0.0))
	_rvol = move_toward(_rvol, _rvol_target, delta * 1.6)   # ~0.6 s fade-out on the next floor
	if result_track != "" and _rvol <= 0.0 and _rvol_target <= 0.0:
		(result_players[result_track] as AudioStreamPlayer).stop()
		result_track = ""
	_pitch_mul = lerpf(_pitch_mul, _pitch_target, 1.0 - exp(-(1.6 if _pitch_target < _pitch_mul else 6.0) * delta))
	_apply(delta)


func _apply(_delta: float) -> void:
	var i := intensity
	var to_tension := smoothstep(0.12, 0.5, i)
	var to_urgent := smoothstep(0.55, 0.92, i)
	# shares of the three songs; square roots = equal-power crossfade (unrelated songs add up in power)
	var vols := [sqrt(1.0 - to_tension), sqrt(to_tension * (1.0 - to_urgent)), sqrt(to_urgent)]
	for k in players.size():
		players[k].volume_db = maxf(linear_to_db(maxf(vols[k], 0.0001)), -60.0)
		players[k].pitch_scale = maxf((1.0 + 0.06 * hurry) * _pitch_mul, 0.05)
	AudioServer.set_bus_volume_db(_bus, GameConfig.MUSIC_VOLUME_DB + linear_to_db(maxf(_fade, 0.0001)))
	if _rbus >= 0:
		var base: float = GameConfig.DEFEAT_VOLUME_DB if result_track == "defeat" else GameConfig.VICTORY_VOLUME_DB
		AudioServer.set_bus_volume_db(_rbus, base + linear_to_db(maxf(_rvol, 0.0001)))
