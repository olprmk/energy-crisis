extends Node
## Adaptive layout (Figma "iPhone 17 - 1", node 29:2): the game is shown in a rounded frame on a light
## background, and the frame follows the window:
##   * landscape (desktop): the frame fills the window, with a small margin all round;
##   * portrait (phone): the frame takes the top half, the touch controls (d-pad + two buttons) sit below it;
##   * landscape on a touch screen: the frame in the middle, the d-pad on the left, the buttons on the right.
## The 3D view renders the whole window; the camera is shifted and zoomed so the scene sits in the frame
## (camera_rig.gd), the HUD is laid out inside the frame and scaled to it (hud.gd), and everything outside the
## frame is painted with the background colour (this node).

signal layout_changed(frame: Rect2)

const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec4 bg : source_color = vec4(0.898, 0.925, 0.933, 1.0);
uniform vec2 screen = vec2(1280.0, 720.0);   // logical size of the window
uniform vec4 frame = vec4(16.0, 16.0, 1248.0, 688.0);   // x, y, w, h (logical)
uniform float radius = 20.0;

void fragment() {
	vec2 p = UV * screen;
	vec2 c = frame.xy + frame.zw * 0.5;
	vec2 q = abs(p - c) - frame.zw * 0.5 + vec2(radius);
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;   // rounded box, > 0 outside
	float aa = max(fwidth(d), 0.0001);
	COLOR = vec4(bg.rgb, bg.a * clamp(d / aa + 0.5, 0.0, 1.0));
}
"""

var frame := Rect2(0, 0, 1280, 720)
var screen := Vector2(1280, 720)
var mode := "landscape"          # "landscape", "portrait" or "landscape_touch"
var touch_hints := false         # a touch screen: the hints name the on-screen buttons instead of the keys
var hud_scale := 1.0
var pad: TouchPad
var _backdrop: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 99               # above the 3D view, the noise and the HUD
	add_child(layer)
	_backdrop = ColorRect.new()
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BACKDROP_SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("bg", GameConfig.BACKGROUND_COLOR)
	_backdrop.material = _mat
	layer.add_child(_backdrop)
	var top := CanvasLayer.new()
	top.layer = 100
	add_child(top)
	pad = TouchPad.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(pad)
	get_viewport().size_changed.connect(relayout)
	relayout.call_deferred()


func _touch() -> bool:
	if OS.get_cmdline_user_args().has("--touch"):
		return true   # testing the touch layout on a desktop
	match GameConfig.TOUCH_CONTROLS:
		"always":
			return true
		"never":
			return false
	return DisplayServer.is_touchscreen_available()


func _safe_insets(scr: Vector2) -> Array:
	## Notch / home indicator on phones: [left, top, right, bottom] in logical units.
	if not OS.has_feature("mobile"):
		return [0.0, 0.0, 0.0, 0.0]
	var safe := DisplayServer.get_display_safe_area()
	var full := Vector2(DisplayServer.window_get_size())
	if safe.size.x <= 0 or full.x <= 0:
		return [0.0, 0.0, 0.0, 0.0]
	var k := scr.x / full.x
	return [safe.position.x * k, safe.position.y * k, (full.x - safe.end.x) * k, (full.y - safe.end.y) * k]


func relayout() -> void:
	screen = get_viewport().get_visible_rect().size
	var W := screen.x
	var H := screen.y
	var ins := _safe_insets(screen)
	var m := roundf(GameConfig.FRAME_MARGIN * minf(W, H))
	var area := Rect2(ins[0], ins[1], W - ins[0] - ins[2], H - ins[1] - ins[3])
	var D: Dictionary = GameConfig.TOUCH_LAYOUT   # mockup measurements (402 px wide phone)
	var buttons := {}
	var por := _portrait(area, m, D)
	var lan := _landscape_touch(area, m, D) if _touch() else {}
	var portrait := area.size.y > area.size.x * 1.1
	if not lan.is_empty() and not portrait:
		# a touch screen: controls below the frame or at its sides, whichever leaves the bigger game frame
		var a_por: float = por["frame"].size.x * minf(por["frame"].size.y, por["frame"].size.x * 9.0 / 16.0)
		var a_lan: float = lan["frame"].size.y * minf(lan["frame"].size.x, lan["frame"].size.y * 16.0 / 9.0)
		portrait = a_por > a_lan
	if portrait:
		mode = "portrait"
		frame = por["frame"]
		buttons = por["buttons"]
	elif not lan.is_empty():
		mode = "landscape_touch"
		frame = lan["frame"]
		buttons = lan["buttons"]
	else:
		mode = "landscape"
		frame = Rect2(area.position.x + m, area.position.y + m, area.size.x - 2.0 * m, area.size.y - 2.0 * m)
	touch_hints = _touch()
	hud_scale = minf(frame.size.x / GameConfig.UI_REF_SIZE.x, frame.size.y / GameConfig.UI_REF_SIZE.y)
	var radius := GameConfig.FRAME_RADIUS * minf(frame.size.x, frame.size.y)
	_mat.set_shader_parameter("screen", screen)
	_mat.set_shader_parameter("frame", Vector4(frame.position.x, frame.position.y, frame.size.x, frame.size.y))
	_mat.set_shader_parameter("radius", radius)
	pad.set_buttons(buttons, minf(W, H) / D["ref_width"])
	layout_changed.emit(frame)


func _portrait(area: Rect2, m: float, D: Dictionary) -> Dictionary:
	## The mockup: the frame on top (half the screen), the d-pad and the buttons under it.
	var c: float = area.size.x / D["ref_width"]
	var below: float = (D["gap"] + D["dpad"] + D["bottom"]) * c   # room the controls need under the frame
	var fh := maxf(minf(area.size.y * 0.5, area.size.y - m - below), area.size.y * 0.3)
	var f := Rect2(area.position.x + m, area.position.y + m, area.size.x - 2.0 * m, fh)
	var top: float = f.end.y + D["gap"] * c
	var side: float = D["side"] * c
	var r: float = D["dpad"] * 0.5 * c
	var b: float = D["button"] * 0.5 * c
	return {"frame": f, "buttons": {
		"dpad": [Vector2(area.position.x + side + r, top + r), r],
		"a": [Vector2(area.end.x - side - b, top + b), b],
		"b": [Vector2(area.end.x - side - 3.0 * b, top + D["button_drop"] * c + b), b]}}


func _landscape_touch(area: Rect2, m: float, D: Dictionary) -> Dictionary:
	## Phone on its side: the d-pad left of the frame, the buttons right of it.
	var c: float = minf(area.size.y, area.size.x * 0.5) / D["ref_width"]
	var side: float = D["side"] * c
	var r: float = D["dpad"] * 0.5 * c
	var b: float = D["button"] * 0.5 * c
	var col := side * 2.0 + 2.0 * r     # width of a controls column
	var f := Rect2(area.position.x + col, area.position.y + m, area.size.x - 2.0 * col, area.size.y - 2.0 * m)
	var cy := area.position.y + area.size.y * 0.62
	return {"frame": f, "buttons": {
		"dpad": [Vector2(area.position.x + side + r, cy), r],
		"a": [Vector2(area.end.x - side - b, cy - D["button_drop"] * c * 0.5), b],
		"b": [Vector2(area.end.x - side - 3.0 * b, cy + D["button_drop"] * c * 0.5), b]}}


# ======================================================================= touch controls
class TouchPad:
	## The d-pad and the two round buttons from the mockup. The d-pad sends the move_* actions (8 directions),
	## the upper right button "confirm" (Enter: name, start, switch off, next floor), the lower one "back" (Esc).
	## Works with several fingers at once, and with the mouse.
	extends Control

	const FILL := Color(1, 1, 1, 0.2)
	const FILL_DOWN := Color(1, 1, 1, 0.6)
	const LINE := Color("b3c5cb")
	const LINE_DOWN := Color("7f969d")
	const LABEL := Color("b3c5cb")   # button names (Pixelify Sans 40 px in the mockup, 1 px black shadow)
	const DEAD := 0.28            # d-pad dead zone (share of its radius)
	const GRAB := 1.25            # a touch this far out (share of the radius) still counts

	var buttons := {}             # name -> [centre, radius]
	var font: Font = load("res://assets/fonts/PixelifySansUA.ttf")
	var unit := 1.0               # mockup px -> logical px (line widths)
	var _touches := {}            # touch index -> control name
	var _dirs := {}               # move action -> held
	var _down := {}               # button name -> held

	func set_buttons(b: Dictionary, u: float) -> void:
		if b.is_empty():
			_release_all()
		buttons = b
		unit = u
		visible = not b.is_empty()
		queue_redraw()

	func _hit(p: Vector2) -> String:
		for n in buttons:
			var c: Vector2 = buttons[n][0]
			var r: float = buttons[n][1]
			if p.distance_to(c) <= r * GRAB:
				return n
		return ""

	func _input(event: InputEvent) -> void:
		if not visible:
			return
		var idx := -1
		var pos := Vector2.ZERO
		var pressed := false
		var moved := false
		if event is InputEventScreenTouch:
			idx = event.index
			pos = event.position
			pressed = event.pressed
		elif event is InputEventScreenDrag:
			idx = event.index
			pos = event.position
			moved = true
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
				and event.device != InputEvent.DEVICE_ID_EMULATION:
			idx = 1000                 # the mouse acts as one more finger
			pos = event.position
			pressed = event.pressed
		elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION \
				and _touches.has(1000):
			idx = 1000
			pos = event.position
			moved = true
		else:
			return
		pos = get_global_transform_with_canvas().affine_inverse() * pos
		if moved:
			if _touches.get(idx, "") == "dpad":
				_dpad(pos)
				get_viewport().set_input_as_handled()
			return
		if pressed:
			var n := _hit(pos)
			if n == "":
				return
			_touches[idx] = n
			if n == "dpad":
				_dpad(pos)
			else:
				_button(n, true)
			get_viewport().set_input_as_handled()
		elif _touches.has(idx):
			var n: String = _touches[idx]
			_touches.erase(idx)
			if n == "dpad":
				_set_dirs({})
			else:
				_button(n, false)
			get_viewport().set_input_as_handled()

	func _dpad(p: Vector2) -> void:
		var c: Vector2 = buttons["dpad"][0]
		var r: float = buttons["dpad"][1]
		var d := (p - c) / r
		var want := {}
		if d.length() > DEAD:
			var a := d.angle()   # 8 sectors of 45 degrees
			var k := wrapi(int(roundf(a / (PI / 4.0))), 0, 8)
			var dirs := [["move_right"], ["move_right", "move_down"], ["move_down"], ["move_down", "move_left"],
					["move_left"], ["move_left", "move_up"], ["move_up"], ["move_up", "move_right"]]
			for act in dirs[k]:
				want[act] = true
		_set_dirs(want)

	func _set_dirs(want: Dictionary) -> void:
		for act in ["move_up", "move_down", "move_left", "move_right"]:
			var on: bool = want.get(act, false)
			if on != _dirs.get(act, false):
				_dirs[act] = on
				_send(act, on)
		queue_redraw()

	func _button(n: String, on: bool) -> void:
		_down[n] = on
		_send("confirm" if n == "a" else "back", on)
		queue_redraw()

	func _send(act: String, on: bool) -> void:
		var ev := InputEventAction.new()
		ev.action = act
		ev.pressed = on
		ev.strength = 1.0 if on else 0.0
		Input.parse_input_event(ev)

	func _release_all() -> void:
		_touches.clear()
		_set_dirs({})
		for n in _down:
			if _down[n]:
				_button(n, false)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_release_all()

	func _draw() -> void:
		var lw := maxf(unit, 1.0)
		for n in buttons:
			var c: Vector2 = buttons[n][0]
			var r: float = buttons[n][1]
			var down: bool = _down.get(n, false) or (n == "dpad" and _dirs.values().has(true))
			draw_circle(c, r - lw * 0.5, FILL_DOWN if down and n != "dpad" else FILL)
			draw_arc(c, r - lw * 0.5, 0.0, TAU, 96, LINE, lw, true)
			if n != "dpad" and font:
				var txt: String = GameConfig.TOUCH_BUTTONS.get(n, "")
				var fs := int(roundf(40.0 * unit))
				var w := r * 2.0
				var base := Vector2(c.x - r, c.y + (font.get_ascent(fs) - font.get_descent(fs)) * 0.5)
				draw_string(font, base + Vector2(unit, unit), txt, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color(0, 0, 0))
				draw_string(font, base, txt, HORIZONTAL_ALIGNMENT_CENTER, w, fs, LINE_DOWN if down else LABEL)
			if n == "dpad":
				# four triangles 20 x 6 (mockup px), 10 px in from the edge
				var w := 20.0 * unit
				var h := 6.0 * unit
				var inset := 10.0 * unit
				var arrows := {"move_up": -PI / 2.0, "move_right": 0.0, "move_down": PI / 2.0, "move_left": PI}
				for act in arrows:
					var dir := Vector2.from_angle(arrows[act])
					var side := Vector2(-dir.y, dir.x)
					var tip := c + dir * (r - inset)
					var base := tip - dir * h
					var col := LINE_DOWN if _dirs.get(act, false) else LINE
					draw_colored_polygon(PackedVector2Array([tip, base + side * w * 0.5, base - side * w * 0.5]), col)
