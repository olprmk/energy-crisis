class_name Packs
extends Node
## Content kept out of the first download (the CrazyGames build).
##
## In the browser the page fetches the whole main pack (index.pck) before the game starts, and CrazyGames counts
## everything fetched until the first round starts (gameplayStart) as the game's first download. So that build
## leaves out what the first floor does not need: the other apartments (floor<model>.glb with their textures and
## layouts) and the music beyond the calm track. They are in a second pack, index.extra.pck (export preset
## "CrazyGamesExtra"), fetched in the background once the first round is under way, or at once for a player who
## continues on a later floor, and mounted with ProjectSettings.load_resource_pack().
## In every other build (the editor, GitHub Pages) the files are in the main pack and nothing is fetched.

signal finished(ok: bool)

const FILE := "index.extra.pck"
const PROBE := "res://assets/models/apartment/floor2.glb"   # only in the extra pack
const TMP := "/tmp/ec_extra.pck"
const TRIES := 3

var needed := false    # the extra pack exists for this build and is not mounted yet
var state := "idle"    # idle | loading | ready | failed
var progress := 0.0    # 0..1 while loading
var _http: HTTPRequest
var _tries := 0


func _ready() -> void:
	needed = not ResourceLoader.exists(PROBE)
	if not needed:
		state = "ready"


## Start fetching the extra pack (does nothing if it is already there or on its way).
func fetch() -> void:
	if not needed or state == "loading" or state == "ready":
		return
	if not OS.has_feature("web"):
		state = "failed"
		finished.emit(false)
		return
	state = "loading"
	_tries += 1
	progress = 0.0
	var url := str(JavaScriptBridge.eval("new URL('%s', document.baseURI).href" % FILE, true))
	_http = HTTPRequest.new()
	_http.download_chunk_size = 1 << 20   # read per frame: the default 64 KiB would take ~160 frames for this pack
	add_child(_http)
	_http.request_completed.connect(_on_done)
	if _http.request(url) != OK:
		_http.queue_free()
		_http = null
		_fail()


func _process(_delta: float) -> void:
	if _http and _http.get_body_size() > 0:
		progress = clampf(float(_http.get_downloaded_bytes()) / _http.get_body_size(), 0.0, 1.0)


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_http.queue_free()
	_http = null
	var ok := result == HTTPRequest.RESULT_SUCCESS and code == 200 and body.size() > 0
	if ok:   # into the browser's in-memory file system, where load_resource_pack() can open it
		var f := FileAccess.open(TMP, FileAccess.WRITE)
		ok = f != null
		if ok:
			f.store_buffer(body)
			f.close()
			ok = ProjectSettings.load_resource_pack(TMP)
	if ok:
		needed = false
		state = "ready"
		progress = 1.0
		print("Extra pack loaded")
		finished.emit(true)
	else:
		push_warning("Extra pack: failed (result %d, HTTP %d, %d bytes, file error %d)" % [result, code, body.size(),
				FileAccess.get_open_error()])
		_fail()


func _fail() -> void:
	if _tries < TRIES:   # try again a little later
		state = "idle"
		get_tree().create_timer(2.0 * _tries).timeout.connect(fetch)
		return
	state = "failed"
	finished.emit(false)


## Wait until `path` can be loaded, fetching the extra pack if it is needed. False if it could not be fetched.
func ensure(path: String) -> bool:
	if ResourceLoader.exists(path):
		return true
	if state == "failed":   # a new attempt (the connection may be back)
		state = "idle"
		_tries = 0
	fetch()
	if state != "ready" and state != "failed":
		await finished
	return ResourceLoader.exists(path)
