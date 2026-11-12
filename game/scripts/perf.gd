extends Node
## Performance: the 3D resolution in the browser, and a meter (F3; on the web also ?perf=1; -- --perf prints it).
##
## In the browser the page is drawn at the screen's real pixels: 2 per CSS pixel on a Retina Mac, 3 on many
## phones. The interface stays sharp at that resolution, but the 3D scene is drawn with one pixel per CSS pixel
## (scaling_3d_scale = 1 / devicePixelRatio, at least 0.5) and stretched to the frame: 4 times fewer pixels to
## light and shade.
## If the game still runs slower than ~40 fps, the 3D resolution goes down in steps (to 70 % of that) and comes
## back when there is room again. On the desktop the 3D view keeps the full resolution.

const LOW_MS := 25.0      # average frame time above this (slower than 40 fps): lower the 3D resolution ...
const HIGH_MS := 17.5     # ... at 60 fps (or faster) again: raise it back
const COOLDOWN := 20.0    # s after lowering before it may go up again (no flipping back and forth)
const STEP := 0.1         # share of the base resolution per step
const MIN_SHARE := 0.7    # never below 70 % of the base resolution
const WINDOW := 2.0       # seconds of frames averaged before a change
const HITCH_MS := 250.0   # longer frames (loading a floor) are not counted

var base := 1.0           # 3D resolution scale for this screen
var share := 1.0          # adaptive part (MIN_SHARE .. 1)
var adaptive := false
var _lbl: Label
var _log := false
var _t := 0.0
var _frames := 0
var _sum := 0.0
var _worst := 0.0
var _ad_t := 0.0
var _ad_sum := 0.0
var _ad_n := 0
var _cool := 0.0


func _ready() -> void:
	process_priority = 100   # after everything else
	var show := OS.get_cmdline_user_args().has("--perf")
	_log = show
	if OS.has_feature("web"):
		var dpr = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		base = clampf(1.0 / maxf(float(dpr), 1.0), 0.5, 1.0)   # phones (3 px per CSS px): 1.5 px per CSS px
		adaptive = true
		show = show or str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('perf') || ''", true)) == "1"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scale-3d="):   # testing
			base = clampf(float(a.substr(11)), 0.25, 1.0)
	_apply()
	if show:
		_toggle()


func _apply() -> void:
	get_viewport().scaling_3d_scale = base * share


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_toggle()


func _toggle() -> void:
	if _lbl:
		_lbl.get_parent().queue_free()
		_lbl = null
		return
	var layer := CanvasLayer.new()
	layer.layer = 120
	add_child(layer)
	_lbl = Label.new()
	_lbl.position = Vector2(8, 8)
	_lbl.add_theme_font_size_override("font_size", 13)
	_lbl.add_theme_color_override("font_color", Color.WHITE)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.set_content_margin_all(6)
	_lbl.add_theme_stylebox_override("normal", sb)
	_lbl.text = "…"
	layer.add_child(_lbl)


func _process(delta: float) -> void:
	var ms := delta * 1000.0
	# meter
	_t += delta
	_frames += 1
	_sum += ms
	_worst = maxf(_worst, ms)
	if _t >= 0.5:
		var avg := _sum / maxf(_frames, 1)
		var text := "%d fps · %.1f ms (worst %.0f) · 3D %.2f · draw calls %d · objects %d" % [
				roundi(_frames / _t), avg, _worst, base * share,
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
				Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)]
		if _lbl:
			_lbl.text = text
		if _log:
			print("PERF ", text)
		_t = 0.0
		_frames = 0
		_sum = 0.0
		_worst = 0.0
	# adaptive 3D resolution (web)
	if not adaptive or ms > HITCH_MS:
		return
	_cool = maxf(_cool - delta, 0.0)
	_ad_t += delta
	_ad_sum += ms
	_ad_n += 1
	if _ad_t < WINDOW:
		return
	var avg_ms := _ad_sum / _ad_n
	var want := share
	if avg_ms > LOW_MS:
		want = maxf(share - STEP, MIN_SHARE)
		_cool = COOLDOWN
	elif avg_ms < HIGH_MS and _cool <= 0.0:
		want = minf(share + STEP, 1.0)
	if want != share:
		share = want
		_apply()
	_ad_t = 0.0
	_ad_sum = 0.0
	_ad_n = 0
