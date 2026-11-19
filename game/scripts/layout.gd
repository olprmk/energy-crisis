extends Node
## Adaptive layout. The game is shown in a frame that follows the window:
##   * landscape (desktop): the frame fills the window;
##   * portrait (phone, Figma "KeyLock" 56:1162): the game view on top, the controls panel at the bottom (the
##     panel's gradient, rounded top corners, covering the view's bottom edge a little) with the stick on the
##     left and the switch-off button on the right;
##   * landscape on a touch screen: the game fills the window, the stick at the bottom left, the button at the
##     bottom right, over the game.
## Phone sizes are in pt of the mockup's 402 pt wide phone (GameConfig.PHONE): `unit` window px per pt.
## The 3D view renders the whole window; the camera is shifted and zoomed so the scene sits in the frame
## (camera_rig.gd), the HUD is laid out inside the frame and scaled to it (hud.gd), and everything outside the
## frame is painted with the background colour, the controls panel with its gradient (this node).

signal layout_changed(frame: Rect2)

const BACKDROP_SHADER := """
shader_type canvas_item;
uniform vec4 bg : source_color = vec4(0.898, 0.925, 0.933, 1.0);
uniform vec2 screen = vec2(1280.0, 720.0);   // logical size of the window
uniform vec4 frame = vec4(0.0, 0.0, 1280.0, 720.0);   // x, y, w, h (logical)
uniform vec4 panel = vec4(0.0, 0.0, 0.0, 0.0);        // the controls panel (portrait), none when w = 0
uniform float panel_radius = 0.0;                     // its top corners
uniform vec4 panel_top : source_color = vec4(0.918, 0.949, 0.957, 1.0);
uniform vec4 panel_bottom : source_color = vec4(0.843, 0.941, 0.969, 1.0);

float box(vec2 p, vec4 r, float rad) {   // rounded box, > 0 outside
	vec2 c = r.xy + r.zw * 0.5;
	vec2 q = abs(p - c) - r.zw * 0.5 + vec2(rad);
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rad;
}

void fragment() {
	vec2 p = UV * screen;
	float d = box(p, frame, 0.0);
	float aa = max(fwidth(d), 0.0001);
	vec4 col = vec4(bg.rgb, bg.a * clamp(d / aa + 0.5, 0.0, 1.0));
	if (panel.z > 0.0) {
		// the panel's bottom corners are below the window: only the top ones are round
		float dp = box(p, vec4(panel.xy, panel.z, panel.w + panel_radius), panel_radius);
		float a = clamp(-dp / max(fwidth(dp), 0.0001) + 0.5, 0.0, 1.0);
		vec3 g = mix(panel_top.rgb, panel_bottom.rgb, clamp((p.y - panel.y) / max(panel.w, 1.0), 0.0, 1.0));
		col = vec4(mix(col.rgb, g, a), max(col.a, a));
	}
	COLOR = col;
}
"""

var frame := Rect2(0, 0, 1280, 720)
var screen := Vector2(1280, 720)
var area := Rect2(0, 0, 1280, 720)   # the window without the notch / home indicator (logical)
var mode := "landscape"          # "landscape", "portrait" or "landscape_touch"
var touch_hints := false         # a touch screen: the hints name the on-screen button instead of the key
var hud_scale := 1.0
var unit := 1.0                  # phone modes: window px per mockup pt
var panel := Rect2()             # portrait: the controls panel
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
	_mat.set_shader_parameter("panel_top", Hud.PANEL_TOP)
	_mat.set_shader_parameter("panel_bottom", Hud.PANEL_BOTTOM)
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
	var ins := _safe_insets(screen)
	area = Rect2(ins[0], ins[1], screen.x - ins[0] - ins[2], screen.y - ins[1] - ins[3])
	var P: Dictionary = GameConfig.PHONE
	var fill := OS.get_cmdline_user_args().has("--fill-frame")   # covers / trailers: the game over the whole window
	var portrait := area.size.y > area.size.x * 1.1 and not fill
	var buttons := {}
	panel = Rect2()
	if portrait:
		mode = "portrait"
		unit = area.size.x / P["ref"]
		var top: float = area.end.y - P["panel"] * unit
		panel = Rect2(0.0, top, screen.x, screen.y - top)   # to the window's bottom edge (under the home bar too)
		frame = Rect2(area.position.x, area.position.y, area.size.x, top + P["panel_overlap"] * unit - area.position.y)
		buttons = {"stick": [Vector2(area.position.x, top) + P["stick_c"] * unit, P["stick_r"] * unit],
				"a": [Vector2(area.position.x, top) + P["button_c"] * unit, P["coin_r"] * unit]}
	elif _touch() and not fill:
		mode = "landscape_touch"
		unit = area.size.y / P["ref"]
		frame = area
		var bl: Vector2 = P["stick_c"]
		var br: Vector2 = P["button_c_land"]
		buttons = {"stick": [Vector2(area.position.x + bl.x * unit, area.end.y - bl.y * unit), P["stick_r"] * unit],
				"a": [Vector2(area.end.x - br.x * unit, area.end.y - br.y * unit), P["coin_r"] * unit]}
	else:
		mode = "landscape"
		unit = 1.0
		frame = area
	touch_hints = _touch()
	hud_scale = minf(frame.size.x / GameConfig.UI_REF_SIZE.x, frame.size.y / GameConfig.UI_REF_SIZE.y)
	_mat.set_shader_parameter("screen", screen)
	_mat.set_shader_parameter("frame", Vector4(frame.position.x, frame.position.y, frame.size.x, frame.size.y))
	_mat.set_shader_parameter("panel", Vector4(panel.position.x, panel.position.y, panel.size.x, panel.size.y))
	_mat.set_shader_parameter("panel_radius", P["panel_radius"] * unit)
	pad.set_buttons(buttons, unit, mode, frame, panel)
	layout_changed.emit(frame)


# ======================================================================= touch controls
class TouchPad:
	## The phone controls (Figma "KeyLock" 56:1162): an analog stick and the switch-off button, both orange
	## "coins" (70 pt: a rim lit from above, a dished face): the knob has four arrows, the button a power sign.
	## The knob follows the finger (clamped to the base) and the move_* actions get analog strengths, so a small
	## push walks slowly and a full push runs; a decisive push also sends a "pressed" event. The button is
	## "confirm" (switch off). Works with several fingers at once, and with the mouse.
	## With `hints` on (a game starting, as the keys on a desktop) it also shows what to do above the controls,
	## "Control" / "Turn off" under / next to them, and curved arrows from the words to the controls.
	extends Control

	const COIN := Color("eaaa3c")           # the face
	const RIM_TOP := Color("f2b444")        # the rim, lit from above ...
	const RIM_BOTTOM := Color("c38a2e")     # ... darker below
	const GROOVE := Color("c99030")
	const SHADE := Color("d89c34")          # the face's upper edge (dished)
	const MARK := Color(0, 0, 0)            # arrows, power sign
	const BASE_PANEL := Color("dde8ea")     # the stick's base on the panel (portrait)
	const BASE_FILL := Color(1, 1, 1, 0.18) # ... over the game (landscape)
	const BASE_LINE := Color(1, 1, 1, 0.75)
	const NOTE_GREY := Color("818e94")      # "Control" / "Turn off" on the panel
	const GOAL := ["Turn off appliances to", "prevent power", "surges."]       # portrait: three lines
	const GOAL_WIDE := ["Turn off appliances to", "prevent power surges."]    # landscape: two
	const GRAB := 1.4             # a touch this far out (share of the radius) still counts
	const BUTTON_GRAB := 1.3      # the button is small: it takes touches up to 1.3 x 45 pt from its centre
	const DEAD := 0.12            # stick: no movement this close to the centre (share of the knob's travel)
	const FULL := 0.75            # full speed from this far out
	const PRESS := 0.55           # menu "press" (move_left / move_right event) from this far out ...
	const RELEASE := 0.3          # ... and released again below this
	const RETURN := 18.0          # knob springs back to the centre (rate) when let go
	## The hint arrow (a hand-drawn S, the head at the top pointing up and right), pt, tip at (0, 0).
	const ARROW := [Vector2(-3, 2), Vector2(-8, 15), Vector2(-6, 26), Vector2(7, 37), Vector2(19, 47), Vector2(25, 54)]
	const ARROW_HEAD := [Vector2(-11, 3), Vector2(1, 12)]

	var buttons := {}             # name -> [centre, radius] (window px)
	var font: Font = load("res://assets/fonts/PixelifySansUA.ttf")
	var unit := 1.0               # pt -> window px
	var mode := ""
	var view := Rect2()           # the game view (window px)
	var panel := Rect2()          # portrait: the controls panel
	var hints := false            # what to do, the names and the arrows (a game starting)
	var enabled := true           # off under a menu page (its buttons take the taps)
	var _touches := {}            # touch index -> control name
	var _down := {}               # button name -> held
	var _knob := Vector2.ZERO     # knob offset: share of its travel (length <= 1)
	var _held := false            # the stick is held
	var _str := {}                # move action -> strength set by the stick
	var _evt := {}                # move action -> a "pressed" event was sent

	func set_buttons(b: Dictionary, u: float, m: String, v: Rect2, p: Rect2) -> void:
		if b.is_empty():
			_release_all()
		buttons = b
		unit = u
		mode = m
		view = v
		panel = p
		_refresh()

	func set_enabled(on: bool) -> void:
		if not on:
			_release_all()
		enabled = on
		_refresh()

	func set_hints(on: bool) -> void:
		hints = on
		queue_redraw()

	func _refresh() -> void:
		visible = enabled and not buttons.is_empty()
		queue_redraw()

	func _hit(p: Vector2) -> String:
		var best := ""
		var best_d := INF
		for n in buttons:
			var c: Vector2 = buttons[n][0]
			var r: float = buttons[n][1] if n == "stick" else 45.0 * unit
			var d := p.distance_to(c) / r
			if d <= (GRAB if n == "stick" else BUTTON_GRAB) and d < best_d:
				best = n
				best_d = d
		return best

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
			if _touches.get(idx, "") == "stick":
				_stick(pos)
				get_viewport().set_input_as_handled()
			return
		if pressed:
			var n := _hit(pos)
			if n == "" or (n == "stick" and _held):
				return
			_touches[idx] = n
			if n == "stick":
				_held = true
				_stick(pos)
			else:
				_button(n, true)
			get_viewport().set_input_as_handled()
		elif _touches.has(idx):
			var n: String = _touches[idx]
			_touches.erase(idx)
			if n == "stick":
				_held = false
				_set_vector(Vector2.ZERO)
			else:
				_button(n, false)
			get_viewport().set_input_as_handled()

	func _travel() -> float:
		## How far the knob's centre can move from the stick's centre.
		return buttons["stick"][1] - GameConfig.PHONE["coin_r"] * unit * 0.7

	func _stick(p: Vector2) -> void:
		var d: Vector2 = (p - buttons["stick"][0]) / _travel()
		if d.length() > 1.0:
			d = d.normalized()
		_knob = d
		var s := clampf((d.length() - DEAD) / (FULL - DEAD), 0.0, 1.0)
		_set_vector(d.normalized() * s if s > 0.0 else Vector2.ZERO)
		queue_redraw()

	func _set_vector(v: Vector2) -> void:
		## v: the movement wanted (length 0..1, +y = move_down). Input.get_vector() takes the actions' dead zone
		## off the strengths, so it is added back here: the player walks at exactly |v| of the full speed.
		## The strengths are set silently (Input.action_press, no events: the menu would see every finger move);
		## only crossing PRESS / RELEASE sends a pressed / released event.
		var dz := InputMap.action_get_deadzone("move_left") if InputMap.has_action("move_left") else 0.0
		var send := v.normalized() * (dz + (1.0 - dz) * v.length()) if v != Vector2.ZERO else Vector2.ZERO
		var acts := {"move_left": Vector2(-1, 0), "move_right": Vector2(1, 0), "move_up": Vector2(0, -1),
				"move_down": Vector2(0, 1)}
		for act in acts:
			var axis: Vector2 = acts[act]
			var st := maxf(send.dot(axis), 0.0)
			var m := maxf(v.dot(axis), 0.0)
			if m >= PRESS and not _evt.get(act, false):
				_evt[act] = true
				_send(act, true, st)
			elif m < RELEASE and _evt.get(act, false):
				_evt[act] = false
				_send(act, false, 0.0)
			if st > 0.0:
				Input.action_press(act, st)
			elif _str.get(act, 0.0) > 0.0:
				Input.action_release(act)   # only what the stick pressed (the keyboard may hold the key)
			_str[act] = st

	func _button(n: String, on: bool) -> void:
		_down[n] = on
		_send("confirm", on)
		queue_redraw()

	func _send(act: String, on: bool, strength := 1.0) -> void:
		var ev := InputEventAction.new()
		ev.action = act
		ev.pressed = on
		ev.strength = strength if on else 0.0
		Input.parse_input_event(ev)

	func _release_all() -> void:
		_touches.clear()
		_held = false
		_knob = Vector2.ZERO
		_set_vector(Vector2.ZERO)
		for n in _down:
			if _down[n]:
				_button(n, false)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_release_all()

	func _process(delta: float) -> void:
		if not _held and _knob != Vector2.ZERO:   # let go: the knob springs back
			_knob = _knob.lerp(Vector2.ZERO, 1.0 - exp(-RETURN * delta))
			if _knob.length() < 0.01:
				_knob = Vector2.ZERO
			queue_redraw()

	# ------------------------------------------------------------------ drawing (sizes in pt x unit)
	func _disc_gradient(c: Vector2, r: float, top: Color, bottom: Color, top_share := 1.0) -> void:
		## A disc with a vertical gradient (top -> bottom over its upper `top_share` of the height, then flat).
		var strips := 24
		for i in strips:
			var y0 := -r + 2.0 * r * i / strips
			var y1 := -r + 2.0 * r * (i + 1) / strips
			var w0 := sqrt(maxf(r * r - y0 * y0, 0.0))
			var w1 := sqrt(maxf(r * r - y1 * y1, 0.0))
			var t0 := clampf((y0 + r) / (2.0 * r * top_share), 0.0, 1.0)
			var t1 := clampf((y1 + r) / (2.0 * r * top_share), 0.0, 1.0)
			var c0 := top.lerp(bottom, t0)
			var c1 := top.lerp(bottom, t1)
			draw_polygon(PackedVector2Array([c + Vector2(-w0, y0), c + Vector2(w0, y0), c + Vector2(w1, y1),
					c + Vector2(-w1, y1)]), PackedColorArray([c0, c0, c1, c1]))

	func _coin(c: Vector2, down: bool) -> void:
		var u := unit
		var r: float = GameConfig.PHONE["coin_r"] * u
		for i in 6:   # soft shadow below
			draw_circle(c + Vector2(0, 4.0 * u), r + (6 - i) * 1.2 * u, Color(0, 0, 0, 0.035))
		var k := 0.12 if down else 0.0   # held: a little darker
		_disc_gradient(c, r, RIM_TOP.darkened(k), RIM_BOTTOM.darkened(k))
		var f := r * 30.0 / 35.0
		_disc_gradient(c, f, SHADE.darkened(k), COIN.darkened(k), 0.35)
		draw_arc(c, f, 0.0, TAU, 64, Color(GROOVE.darkened(k), 0.8), maxf(u, 1.0), true)

	func _arrows(c: Vector2) -> void:
		## The knob's four arrows: black triangles, tip 25 pt from the centre, base 20 pt wide at 19 pt.
		var u := unit
		for d in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			var side := Vector2(-d.y, d.x)
			draw_colored_polygon(PackedVector2Array([c + d * 25.0 * u, c + d * 19.0 * u + side * 10.0 * u,
					c + d * 19.0 * u - side * 10.0 * u]), MARK)

	func _power(c: Vector2) -> void:
		## The power sign: a ring open at the top (radius 10 pt, 4 pt thick) and a bar into the gap.
		var u := unit
		var w := 4.0 * u
		var a0 := deg_to_rad(-35.0)
		var a1 := deg_to_rad(215.0)
		draw_arc(c, 10.0 * u, a0, a1, 40, MARK, w, true)
		for a in [a0, a1]:
			draw_circle(c + Vector2(cos(a), sin(a)) * 10.0 * u, w * 0.5, MARK)
		var p0 := c + Vector2(0, -10.0 * u)
		var p1 := c + Vector2(0, -2.2 * u)
		draw_line(p0, p1, MARK, w, true)
		draw_circle(p0, w * 0.5, MARK)
		draw_circle(p1, w * 0.5, MARK)

	func _text(pos: Vector2, text: String, size: float, color: Color, shadow: bool, width := -1.0) -> void:
		## pos: the baseline's left end (or the centre of `width` when given).
		var fs := int(roundf(size * unit))
		var align := HORIZONTAL_ALIGNMENT_CENTER if width > 0.0 else HORIZONTAL_ALIGNMENT_LEFT
		var p := pos - Vector2(width * 0.5, 0) if width > 0.0 else pos
		if shadow:
			draw_string(font, p + Vector2(2, 2) * unit, text, align, width, fs, Color(0, 0, 0))
		draw_string(font, p, text, align, width, fs, color)

	func _hint_arrow(tip: Vector2, rot: float, flip_x: bool, color: Color, shadow: bool) -> void:
		## The hint arrow with its tip at `tip` (window px), turned by `rot`, mirrored left-right if flip_x.
		var pts := PackedVector2Array()
		var xf := Transform2D(rot, Vector2.ZERO).scaled(Vector2(-unit if flip_x else unit, unit))
		var baked := _smooth(ARROW)
		for q in baked:
			pts.append(tip + xf * q)
		var head := [tip + xf * (ARROW_HEAD[0] as Vector2), tip, tip + xf * (ARROW_HEAD[1] as Vector2)]
		var w := 2.5 * unit
		for pass_i in (2 if shadow else 1):
			var off := Vector2(1.5, 1.5) * unit if pass_i == 0 and shadow else Vector2.ZERO
			var col := Color(0, 0, 0, 0.55) if pass_i == 0 and shadow else color
			var line := PackedVector2Array()
			for q in pts:
				line.append(q + off)
			line.insert(0, tip + off)
			draw_polyline(line, col, w, true)
			draw_polyline(PackedVector2Array([head[0] + off, head[1] + off, head[2] + off]), col, w, true)
			for q in [head[0], head[2], line[line.size() - 1] - off]:
				draw_circle((q as Vector2) + off, w * 0.5, col)

	func _smooth(ps: Array) -> Array:
		## Catmull-Rom through the points (a smooth hand-drawn curve).
		var out := []
		for i in ps.size() - 1:
			var p0: Vector2 = ps[maxi(i - 1, 0)]
			var p1: Vector2 = ps[i]
			var p2: Vector2 = ps[i + 1]
			var p3: Vector2 = ps[mini(i + 2, ps.size() - 1)]
			for k in 8:
				var t := k / 8.0
				var t2 := t * t
				var t3 := t2 * t
				out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
						+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
		out.append(ps[ps.size() - 1])
		return out

	func _draw() -> void:
		if buttons.is_empty():
			return
		var u := unit
		var land := mode == "landscape_touch"
		# the stick: base, then the knob where the finger holds it
		var sc: Vector2 = buttons["stick"][0]
		var sr: float = buttons["stick"][1]
		if land:
			draw_circle(sc, sr, BASE_FILL)
			draw_arc(sc, sr - 0.5 * u, 0.0, TAU, 96, BASE_LINE, maxf(u, 1.0), true)
		else:
			draw_circle(sc, sr, BASE_PANEL)
		var k := sc + _knob * _travel()
		_coin(k, _held)
		_arrows(k)
		# the switch-off button
		var bc: Vector2 = buttons["a"][0]
		_coin(bc, _down.get("a", false))
		_power(bc)
		if not hints:
			return
		# what to do, over the game; the names of the controls and arrows to them
		if land:
			var base := view.end.y - 139.0 * u
			for i in GOAL_WIDE.size():
				_text(Vector2(view.get_center().x, base + 29.0 * u * i), GOAL_WIDE[i], 32, Color.WHITE, true, 440.0 * u)
			var lb := view.end.y - 38.5 * u   # the names' baseline
			_text(Vector2(sc.x + sr + 7.0 * u, lb), "Control", 28, Color.WHITE, true)
			_text(Vector2(bc.x - 35.0 * u - 11.0 * u - _width("Turn off", 28), lb), "Turn off", 28, Color.WHITE, true)
			# arrows: from above the names up to the stick (pointing left) and the button (pointing right)
			_hint_arrow(sc + Vector2(sr + 8.0 * u, 4.0 * u), PI * 0.5, true, Color.WHITE, true)
			_hint_arrow(bc + Vector2(-35.0 * u - 8.0 * u, 4.0 * u), PI * 0.5, false, Color.WHITE, true)
		else:
			var base := view.end.y - 130.5 * u
			for i in GOAL.size():
				_text(Vector2(view.get_center().x, base + 29.0 * u * i), GOAL[i], 32, Color.WHITE, true, 380.0 * u)
			var top := panel.position.y
			var x0 := view.position.x
			_text(Vector2(x0 + 57.0 * u, top + 248.5 * u), "Control", 28, NOTE_GREY, false)
			_text(Vector2(x0 + 274.0 * u, top + 248.5 * u), "Turn off", 28, NOTE_GREY, false)
			_hint_arrow(Vector2(x0 + 71.0 * u, top + 177.0 * u), 0.0, false, NOTE_GREY, false)
			_hint_arrow(Vector2(x0 + 304.0 * u, top + 169.0 * u), 0.0, false, NOTE_GREY, false)

	func _width(text: String, size: float) -> float:
		return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, int(roundf(size * unit))).x
