class_name Hud
extends CanvasLayer
## All on-screen UI, following the Figma redesign (file "KeyLock", node 48:2814: six 1280 x 720 screens):
##  * pixel font Pixelify Sans (a variable font: Regular 400, Bold 700), accent #FFAE00, dark text #2C1E02;
##  * the start and result screens on a side panel (500 x 720 design px, light blue gradient #EAF2F4 -> #D7F0F7,
##    40 px padding): at the top the logo and "Energy Crisis" (or the stars and Success / Fail with the energy
##    used and the savings), at the bottom the floor to play and big buttons (420 x 70, radius 20; orange =
##    the main action, grey = start the game over). On a phone (portrait) the panel is a bottom sheet;
##  * in play: "Floor N" top left (white, bold, black shadow) and the grid load meter top right (260 x 26: white,
##    green fill, a bolt, the load in per cent of the limit); the countdown numbers and "Start" in the middle
##    (90 px, orange, 6 px black shadow);
##  * the controls (W A S D and the space bar, "Control" / "Turn off" with arrows) at the bottom when a game
##    starts, until the first appliance is switched off.
## The panel slides in from the left (from below on a phone); the camera keeps the character in the middle of
## the part of the view the panel leaves free (view_changed -> camera_rig.gd).

const FONT_PATH := "res://assets/fonts/PixelifySansUA.ttf"
const DARK := Color("2c1e02")
const ACCENT := Color("ffae00")
const TITLE := Color("ffa900")         # "Energy Crisis"
const GREEN := Color("5ccc73")         # "Success"
const RED := Color("f24c40")           # "Fail", the meter when overloaded
const BAR_GREEN := Color("00cf68")
const BTN_GREY := Color("cfd8db")      # "Restart game"
const PANEL_TOP := Color("eaf2f4")
const PANEL_BOTTOM := Color("d7f0f7")
const WHITE := Color(1, 1, 1)
const FLY_COLOR := Color("ffeaa0")   # power number flying from a switched-off appliance to the meter
const FLY_SIZE := 30
const FLY_RISE := 70.0               # px it rises above the appliance first
const FLY_RISE_TIME := 0.45
const FLY_TIME := 0.7                # then the flight to the meter
const FLY_END_SCALE := 0.3
# the side panel (design px of the 1280 x 720 screens)
const SHEET_W := 500.0
const SHEET_PAD := 40.0
const SHEET_MAX_SHARE := 0.5     # the side panel never takes more than this share of the frame's width
const SHEET_TIME := 0.5          # slide-in, s
const SHEET_SWAP_TIME := 0.2     # another page on a panel already shown: its content fades in
# phone (portrait): the same content at 0.8 of the size, on a bottom sheet of a 382 px wide mockup frame
const SHEET_PHONE_REF := 382.0
const SHEET_PHONE_SCALE := 0.8
const SHEET_PHONE_PAD := 19.0
# in play
const HUD_MIN_PX := 14.0         # the smallest play text (the meter's per cent, 24 design px) never smaller than this
const HUD_SMALL := 24

## The part of the game frame (window px) that the panel leaves free; the frame itself when it is hidden.
signal view_changed(rect: Rect2)

var font: FontFile
var font_bold: FontVariation
var root: Control

# in play
var floor_lbl: Label
var meter: LoadMeter
var controls: Controls
var dim_rect: ColorRect
var red_rect: ColorRect
var white_rect: ColorRect   # the flash when the fuses blow
var indicators: Indicators
var prompt_card: PanelContainer
var prompt_rtl: RichTextLabel
var big_lbl: Label
var toast_lbl: Label
var fade_rect: ColorRect
var _boosted: Array = []
var touch_keys := false   # a touch screen: the prompt names the on-screen button instead of the key

# the panel and its pages (one shown at a time)
var sheet_layer: Control          # at the frame's top-left corner, window px (not scaled with the HUD)
var sheet: Sheet
var sheet_side := "left"          # "left" (desktop, landscape) or "bottom" (phone, portrait)
var _pages: Array[Control] = []
var _cur_page: Control = null     # the page on the panel, null = hidden
var _sheet_off := 1.0             # slide: 0 = in place, 1 = fully out
var _sheet_tw: Tween
var _swap_tw: Tween
var _frame := Rect2()
var _hud_s := 1.0
var _view := Rect2()
var _sheet_look := []

# start page (first visit / a player coming back)
var start_panel: VBoxContainer
var start_floor_row: HBoxContainer
var start_floor_val: Label
var start_buttons: VBoxContainer

# result page (success / fail)
var result_panel: VBoxContainer
var res_stars: HBoxContainer
var res_title: Label
var res_used: Label
var res_econ: Label
var res_floor_row: HBoxContainer
var res_floor_val: Label
var res_buttons: VBoxContainer

var _toast_t := 0.0
var _flash := 0.0
var _flyers: Array[Label] = []
var _meter_tw: Tween


# ======================================================================= small custom controls
class LoadMeter:
	## The grid load (Figma "Frame 39", 260 x 26): white bar, the fill (green; orange near the limit, red over
	## it), a bolt at the left, the load in per cent of the limit at the right.
	extends Control
	var frac := 0.0
	var font: Font
	var bolt: Texture2D = Icons.svg_scaled("hud_bolt", Icons.HUD_BOLT_SVG, 4.0)
	const W := 260.0
	const H := 26.0
	func _init() -> void:
		custom_minimum_size = Vector2(W, H)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
		var f := clampf(frac, 0.0, 1.0)
		var fill := Hud.BAR_GREEN if frac < 0.7 else (Hud.ACCENT if frac <= 1.0 else Hud.RED)
		if f > 0.0:
			draw_rect(Rect2(0, 0, size.x * f, size.y), fill)
		if bolt:
			draw_texture_rect(bolt, Rect2(5.95, 4.63, 14.05, 15.75), false)
		var text := "%d%%" % roundi(frac * 100.0)
		var fs := 24
		var base := (size.y + font.get_ascent(fs) - font.get_descent(fs)) * 0.5
		draw_string(font, Vector2(0, base), text, HORIZONTAL_ALIGNMENT_RIGHT, size.x - 5.0, fs, Hud.DARK)


class Controls:
	## The controls shown when a game starts (Figma "Control"): W A S D at the bottom left with "Control" and an
	## arrow, the space bar in the middle with "Turn off" and an arrow. A key held down is drawn darker.
	extends Control
	var font: Font
	var font_bold: Font
	var arrow: Texture2D = Icons.svg_scaled("hint_arrow", Icons.HINT_ARROW_SVG, 4.0)
	var arrow_edge: Texture2D = Icons.svg_scaled("hint_arrow_edge", Icons.HINT_ARROW_EDGE_SVG, 4.0)
	var key_style := StyleBoxFlat.new()
	const KEY := 70.0
	const GAP := 6.0
	const SPACE_W := 309.0
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		key_style.set_corner_radius_all(20)
		key_style.anti_aliasing = true
	func _process(_delta: float) -> void:
		if visible:
			queue_redraw()
	func _key(r: Rect2, text: String, down: bool) -> void:
		key_style.bg_color = Color("e69a00") if down else Hud.ACCENT
		draw_style_box(key_style, r)
		var fs := 40
		var base := r.position.y + (r.size.y + font_bold.get_ascent(fs) - font_bold.get_descent(fs)) * 0.5
		draw_string(font_bold, Vector2(r.position.x, base), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, Hud.DARK)
	func _note(text: String, at: Vector2, arrow_at: Vector2) -> void:
		## A white label (top-left at `at`) and the curved arrow from it down to the key (rect at arrow_at).
		var base := at + Vector2(0, font.get_ascent(32))
		# a soft dark edge (not in the mockup): white text stays readable over the light floors and furniture
		draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 6, Color(0.17, 0.12, 0.01, 0.55))
		draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
		# the arrow: white as in the mockup, over the same soft dark edge as the label
		var pad := Icons.HINT_ARROW_PAD
		var r := Rect2(arrow_at - Vector2(pad, pad), Icons.HINT_ARROW_SIZE + Vector2(pad, pad) * 2.0)
		draw_texture_rect(arrow_edge, r, false, Color(1, 1, 1, 0.55))
		draw_texture_rect(arrow, r, false)
	func _draw() -> void:
		var h := size.y
		var x0 := 40.0
		var y1 := h - 40.0 - KEY            # the lower row (A S D, space bar)
		var y0 := y1 - GAP - KEY            # W
		_key(Rect2(x0 + KEY + GAP, y0, KEY, KEY), "W", Input.is_action_pressed("move_up"))
		_key(Rect2(x0, y1, KEY, KEY), "A", Input.is_action_pressed("move_left"))
		_key(Rect2(x0 + KEY + GAP, y1, KEY, KEY), "S", Input.is_action_pressed("move_down"))
		_key(Rect2(x0 + (KEY + GAP) * 2.0, y1, KEY, KEY), "D", Input.is_action_pressed("move_right"))
		_note("Control", Vector2(281, h - 195), Vector2(213, h - 175.96))
		var sx := maxf(size.x * 0.5 - 141.0, x0 + (KEY + GAP) * 3.0 + 120.0)   # the space bar: middle of the frame
		_key(Rect2(sx, y1, SPACE_W, KEY), "spacebar", Input.is_action_pressed("interact"))
		_note("Turn off", Vector2(sx + 341.0, h - 195), Vector2(sx + 273.0, h - 175.96))


class Sheet:
	## The panel: the light blue gradient (top -> bottom). side "left": full height at the left of the frame;
	## "bottom": full width at the bottom (phone, portrait).
	extends MarginContainer
	var side := "left"
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]),
				PackedColorArray([Hud.PANEL_TOP, Hud.PANEL_TOP, Hud.PANEL_BOTTOM, Hud.PANEL_BOTTOM]))


class Indicators:
	## Arrows at the screen edge pointing to active appliances that are off-screen.
	extends Control
	var items: Array = []
	var font: Font
	var nav_tex: Texture2D = Icons.png("nav_indicator")   # square, arrow points right, rotates around its centre
	const NAV_SIZE := 46.0   # on-screen diameter (design px)
	const MARGIN := 56.0
	const LABEL_SIZE := 20
	func _draw() -> void:
		var inner := Rect2(Vector2(MARGIN, 90.0), size - Vector2(MARGIN * 2.0, 90.0 + MARGIN))
		var c := inner.get_center()
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 120.0)
		var placed: Array[Vector2] = []
		for it in items:
			var p: Vector2 = it["pos"]
			if Rect2(Vector2.ZERO, size).grow(-24.0).has_point(p):
				continue   # visible on screen: the 3D "!" marker is enough
			var d := p - c
			var half := inner.size / 2.0
			var s := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
			var q := c + d * s
			var dir := d.normalized()
			var side := Vector2(-dir.y, dir.x)
			var tries := 0
			while tries < 6 and placed.any(func(o): return o.distance_to(q) < 52.0):
				q = (q + side * 52.0).clamp(inner.position, inner.end)
				tries += 1
			placed.append(q)
			if nav_tex:
				var ts := nav_tex.get_size()
				var sz := Vector2(NAV_SIZE, NAV_SIZE * ts.y / ts.x)
				draw_set_transform(q, dir.angle(), Vector2.ONE)
				draw_texture_rect(nav_tex, Rect2(-sz / 2.0, sz), false, Color(1, 1, 1, pulse))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var col := Color(1.0, 0.68, 0.0, pulse)
				draw_colored_polygon(PackedVector2Array([q + dir * 40.0, q + dir * 18.0 + side * 14.0, q + dir * 18.0 - side * 14.0]), col)
				draw_circle(q, 20.0, col)
			var lbl: String = it["label"]
			var w := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE).x
			var lp: Vector2
			if dir.x > 0.5:
				lp = q + Vector2(-28.0 - w, 6)
			elif dir.x < -0.5:
				lp = q + Vector2(28.0, 6)
			elif dir.y < 0.0:
				lp = q + Vector2(-w / 2.0, 44)
			else:
				lp = q + Vector2(-w / 2.0, -30)
			lp.x = clampf(lp.x, 6.0, size.x - w - 6.0)
			draw_string_outline(font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, 5, Color(0.17, 0.12, 0.01, 0.9))
			draw_string(font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Color(1, 1, 1))


# ======================================================================= build
func _ready() -> void:
	layer = 2
	process_priority = -10   # lay the panel out before the camera reads the free view (same frame, no lag)
	font = load(FONT_PATH)
	font_bold = FontVariation.new()
	font_bold.base_font = font
	font_bold.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 700}
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 16
	root = Control.new()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	dim_rect = _rect(Color(0.05, 0.04, 0.08, 0.0))
	red_rect = _rect(Color(1, 0.1, 0.05, 0.0))
	white_rect = _rect(Color(1, 1, 0.92, 0.0))
	indicators = Indicators.new()
	indicators.font = font
	indicators.set_anchors_preset(Control.PRESET_FULL_RECT)
	indicators.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(indicators)
	controls = Controls.new()
	controls.font = font
	controls.font_bold = font_bold
	controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	controls.visible = false
	root.add_child(controls)
	_build_play()
	_build_prompt()
	_build_big()
	# the panel: above the HUD, below the fade (which covers the whole window)
	sheet_layer = Control.new()
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.theme = theme
	add_child(sheet_layer)
	sheet = Sheet.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.visible = false
	sheet_layer.add_child(sheet)
	_build_start()
	_build_result()
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	_apply_side()
	_all_off()


func _label(text: String, size: int, color := DARK, shadow := 0, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", font_bold)
	if shadow > 0:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
		l.add_theme_constant_override("shadow_offset_x", shadow)
		l.add_theme_constant_override("shadow_offset_y", shadow)
		l.add_theme_constant_override("shadow_outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _leading(l: Label, size: int, k: float, bold := false) -> void:
	## Line height = k x the font size (Figma "leading 0.9").
	var f: Font = font_bold if bold else font
	l.add_theme_constant_override("line_spacing", roundi(size * k - f.get_height(size)))


func _rect(c: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(r)
	return r


func _box(vertical: bool, sep: int) -> BoxContainer:
	var b: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


func _spacer(min_h := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, min_h)
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _page() -> VBoxContainer:
	## A page of the panel: fills it (its top group at the top, its buttons at the bottom).
	var v: VBoxContainer = _box(true, 0)
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.visible = false
	sheet.add_child(v)
	_pages.append(v)
	return v


func _card(radius := 22, pad := 32) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = WHITE
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad
	sb.content_margin_right = pad
	sb.content_margin_top = pad
	sb.content_margin_bottom = pad
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _anchor(ctrl: Control, valign: BoxContainer.AlignmentMode, halign: Control.SizeFlags, margin := 32) -> MarginContainer:
	## Full-screen margin container that pins `ctrl` to a corner / edge.
	var mc := MarginContainer.new()
	mc.set_anchors_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, margin)
	var box := VBoxContainer.new()
	box.alignment = valign
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ctrl.size_flags_horizontal = halign
	mc.add_child(box)
	box.add_child(ctrl)
	root.add_child(mc)
	return mc


func _icon(tex: Texture2D, px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = px
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _row(label: String, value: Label) -> HBoxContainer:
	## "Consumed:  4.9 Wh" — the label at the left, the value at the right edge (28 px, dark).
	var row: HBoxContainer = _box(false, 8)
	var l := _label(label, 28)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func _button(text: String, primary: bool, action: String) -> PanelContainer:
	## A big button (420 x 70, radius 20): orange for the main action, grey for "Restart game". A click or tap
	## presses its input action (the keys do the same: Enter, R).
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ACCENT if primary else BTN_GREY
	sb.set_corner_radius_all(20)
	sb.anti_aliasing = true
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(0, 70)
	var l := _label(text, 32, DARK, 0, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.size_flags_vertical = Control.SIZE_EXPAND_FILL
	p.add_child(l)
	_clickable(p, func() -> void: press_action(action))
	p.mouse_entered.connect(func() -> void: p.modulate = Color(1.07, 1.07, 1.07))
	p.mouse_exited.connect(func() -> void: p.modulate = Color.WHITE)
	return p


func _set_buttons(box: VBoxContainer, buttons: Array) -> void:
	## buttons: [[text, primary, action], ...]
	for c in box.get_children():
		c.queue_free()
	for b in buttons:
		box.add_child(_button(b[0], b[1], b[2]))


func _title_block(v: VBoxContainer) -> void:
	## Logo (66 px) + "Energy Crisis" (60 px bold, two lines, leading 0.9, #FFA900, 2 px black shadow).
	var head: VBoxContainer = _box(true, 16)
	head.add_child(_icon(Icons.svg_scaled("logo_big", Icons.LOGO_BIG_SVG, 4.0), Vector2(66, 66)))
	var title := _label("Energy\nCrisis", 60, TITLE, 2, true)
	_leading(title, 60, 0.9, true)
	head.add_child(title)
	v.add_child(head)


func _build_start() -> void:
	## Figma "Start game" / "Start game second".
	start_panel = _page()
	_title_block(start_panel)
	start_panel.add_child(_spacer(24))
	var bottom: VBoxContainer = _box(true, 20)
	start_floor_val = _label("2", 28)
	start_floor_row = _row("Floor", start_floor_val)
	bottom.add_child(start_floor_row)
	start_buttons = _box(true, 16)
	bottom.add_child(start_buttons)
	start_panel.add_child(bottom)


func _build_result() -> void:
	## Figma "Success" / "Fail": stars, the title, energy used and the savings; the floor; the buttons.
	result_panel = _page()
	var head: VBoxContainer = _box(true, 20)
	res_stars = _box(false, 0)
	head.add_child(res_stars)
	res_title = _label("Success", 60, GREEN, 2, true)
	_leading(res_title, 60, 0.9, true)
	head.add_child(res_title)
	var rows: VBoxContainer = _box(true, 8)
	res_used = _label("", 28)
	res_econ = _label("", 28)
	rows.add_child(_row("Consumed:", res_used))
	rows.add_child(_row("Savings", res_econ))
	var top: VBoxContainer = _box(true, 32)
	top.add_child(head)
	top.add_child(rows)
	result_panel.add_child(top)
	result_panel.add_child(_spacer(24))
	var bottom: VBoxContainer = _box(true, 20)
	res_floor_val = _label("1", 28)
	res_floor_row = _row("Floor", res_floor_val)
	bottom.add_child(res_floor_row)
	res_buttons = _box(true, 16)
	bottom.add_child(res_buttons)
	result_panel.add_child(bottom)


func _build_play() -> void:
	# --- top left: "Floor 1" (32 px bold, white, 2 px black shadow), 24 / 15 px from the corner
	floor_lbl = _label("Floor 1", 32, WHITE, 2, true)
	var mc := _anchor(floor_lbl, BoxContainer.ALIGNMENT_BEGIN, Control.SIZE_SHRINK_BEGIN, 0)
	mc.add_theme_constant_override("margin_left", 24)
	mc.add_theme_constant_override("margin_top", 15)
	# --- top right: the grid load meter, 16 px from the corner
	meter = LoadMeter.new()
	meter.font = font
	_anchor(meter, BoxContainer.ALIGNMENT_BEGIN, Control.SIZE_SHRINK_END, 16)


func _build_prompt() -> void:
	prompt_card = _card(16, 0)
	var sb := prompt_card.get_theme_stylebox("panel") as StyleBoxFlat
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	prompt_rtl = RichTextLabel.new()
	prompt_rtl.bbcode_enabled = true
	prompt_rtl.fit_content = true
	prompt_rtl.autowrap_mode = TextServer.AUTOWRAP_OFF
	prompt_rtl.scroll_active = false
	prompt_rtl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_rtl.add_theme_font_size_override("normal_font_size", 20)
	prompt_rtl.add_theme_color_override("default_color", DARK)
	prompt_card.add_child(prompt_rtl)
	_anchor(prompt_card, BoxContainer.ALIGNMENT_END, Control.SIZE_SHRINK_CENTER, 16)


func _build_big() -> void:
	## The countdown and "Start": 90 px, orange, 6 px black shadow, in the middle.
	big_lbl = _label("", 90, ACCENT, 6)
	big_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_leading(big_lbl, 90, 0.9)
	_anchor(big_lbl, BoxContainer.ALIGNMENT_CENTER, Control.SIZE_SHRINK_CENTER, 0)
	toast_lbl = _label("", 24, ACCENT, 2)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(toast_lbl, BoxContainer.ALIGNMENT_BEGIN, Control.SIZE_SHRINK_CENTER, 90)


# ======================================================================= input helpers
func _clickable(c: Control, on_click: Callable) -> void:
	## A click (or a tap) on it does what its key does.
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	c.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	c.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed:
			c.accept_event()
			on_click.call())


## Press and release an input action, as if its key was pressed.
func press_action(action: String) -> void:
	for down in [true, false]:
		var ev := InputEventAction.new()
		ev.action = action
		ev.pressed = down
		ev.strength = 1.0 if down else 0.0
		Input.parse_input_event(ev)


## The key as the player sees it: on a touch screen the name of the on-screen button that does the same.
func key_name(key: String) -> String:
	if not touch_keys:
		if key == "Esc" and Crazy.enabled:
			return "Q"   # the CrazyGames build: Esc leaves the site's fullscreen, "back" is Q there
		return Lang.t(key)   # "Пробіл" -> "Space"
	var b: Dictionary = GameConfig.TOUCH_BUTTONS
	return {"Enter": b["a"], "Пробіл": b["a"], "Esc": b["b"]}.get(key, key)


## Touch screen or keyboard (layout.gd).
func set_touch_keys(on: bool) -> void:
	touch_keys = on


# ======================================================================= public API
## The start screen. next_floor: the floor a player coming back continues from (shown with "Start" and
## "Restart game"); 0 or 1 = a first visit ("Start" only).
func show_start(next_floor: int) -> void:
	_all_off(true)
	start_floor_row.visible = next_floor > 1
	start_floor_val.text = str(next_floor)
	var buttons := [["Start", true, "confirm"]]
	if next_floor > 1:
		buttons.append(["Restart game", false, "restart"])
	_set_buttons(start_buttons, buttons)
	_show_sheet(start_panel)


## A floor's result. stars: 0..3 (shown on success); used_wh: energy used; econ: savings 0..1; floor_num: the
## floor (shown on fail); buttons as in _set_buttons.
func show_result(win: bool, stars: int, used_wh: float, econ: float, floor_num: int, buttons: Array) -> void:
	_all_off(true)
	res_stars.visible = win
	for c in res_stars.get_children():
		c.queue_free()
	if win:
		for i in 3:
			var on := i < stars
			var tex := Icons.svg_scaled("star_on" if on else "star_off", Icons.STAR_SVG if on else Icons.STAR_GREY_SVG, 4.0)
			var star := _icon(tex, Vector2(50, 50))
			res_stars.add_child(star)
			# the stars pop in one after another once the panel has slid in
			star.pivot_offset = Vector2(25, 25)
			star.scale = Vector2.ZERO
			var tw := star.create_tween()
			tw.tween_interval(SHEET_TIME * 0.6 + 0.22 * i)
			tw.tween_property(star, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	res_title.text = "Success" if win else "Fail"
	res_title.add_theme_color_override("font_color", GREEN if win else RED)
	res_used.text = "%.1f Wh" % used_wh
	res_econ.text = "%d%%" % roundi(econ * 100.0)
	res_floor_row.visible = not win
	res_floor_val.text = str(floor_num)
	_set_buttons(res_buttons, buttons)
	_show_sheet(result_panel)


func show_play(floor_num: int) -> void:
	_all_off()
	floor_lbl.visible = true
	meter.visible = true
	floor_lbl.text = "Floor %d" % floor_num


## The controls at the bottom (a game starting); not on a touch screen: its own stick and buttons are there.
func show_controls(on: bool) -> void:
	controls.visible = on and not touch_keys


func update_play(load_kw: float, limit_kw: float) -> void:
	var f := load_kw / maxf(limit_kw, 0.001)
	if absf(f - meter.frac) > 0.0005:
		meter.frac = f
		meter.queue_redraw()


func prompt(bbcode: String) -> void:
	prompt_card.visible = bbcode != ""
	if prompt_rtl.text != bbcode:
		prompt_rtl.text = bbcode


func big(text: String) -> void:
	big_lbl.text = text


func toast(text: String) -> void:
	toast_lbl.text = Lang.t(text)
	_toast_t = 2.2


## A switched-off appliance's power: the number pops up above the appliance (screen point `from`), rises, then
## flies into the load meter, shrinking and fading out; the meter gives a small pulse when it arrives.
func fly_power(from: Vector2, watts: int) -> void:
	from = to_frame(from)
	from.y = maxf(from.y, FLY_RISE + 30.0)   # an appliance at the top edge: keep the number on screen
	var l := _label(Lang.t("%d Вт") % watts, FLY_SIZE, FLY_COLOR)
	l.add_theme_color_override("font_outline_color", DARK)
	l.add_theme_constant_override("outline_size", 8)
	root.add_child(l)
	_flyers.append(l)
	l.size = l.get_minimum_size()
	l.pivot_offset = l.size / 2.0
	l.position = from - l.pivot_offset
	l.scale = Vector2.ONE * 0.4
	var tw := l.create_tween()   # bound to the label: freeing it (new screen) stops the animation too
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_delay(0.18)
	tw.tween_property(l, "position:y", l.position.y - FLY_RISE, FLY_RISE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var p0 := from - Vector2(0, FLY_RISE)
	tw.chain().tween_method(func(k: float) -> void: _fly_step(l, p0, k), 0.0, 1.0, FLY_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func() -> void:
		_flyers.erase(l)
		l.queue_free()
		_pulse_meter())


func _meter_target() -> Vector2:
	## The meter's per cent (its right end).
	return to_frame(meter.get_global_transform() * Vector2(meter.size.x - 28.0, meter.size.y / 2.0))


func _fly_step(l: Label, p0: Vector2, k: float) -> void:
	if not is_instance_valid(l):
		return
	var p1 := _meter_target()   # follows the meter if the layout changes during the flight
	var mid := (p0 + p1) / 2.0 + Vector2(0, -40)
	mid.y = maxf(mid.y, 24.0)
	var a := p0.lerp(mid, k)
	var b := mid.lerp(p1, k)
	l.position = a.lerp(b, k) - l.pivot_offset
	l.scale = Vector2.ONE * lerpf(1.0, FLY_END_SCALE, k)
	l.modulate.a = 1.0 - smoothstep(0.65, 1.0, k)


func _pulse_meter() -> void:
	if _meter_tw and _meter_tw.is_valid():
		_meter_tw.kill()
	meter.pivot_offset = Vector2(meter.size.x, meter.size.y / 2.0)
	_meter_tw = create_tween()
	_meter_tw.tween_property(meter, "scale", meter.scale * 1.08, 0.08)
	_meter_tw.tween_property(meter, "scale", meter.scale, 0.18)


func _clear_flyers() -> void:
	for l in _flyers:
		if is_instance_valid(l):
			l.queue_free()
	_flyers.clear()


## The fuses blow: a white flash over the frame, fading.
func flash_white() -> void:
	white_rect.color.a = 0.85
	var tw := create_tween()
	tw.tween_property(white_rect, "color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)


func overload(active: bool) -> void:
	if active:
		_flash = 1.0


func set_indicators(items: Array) -> void:
	## items: [{"pos": window point, "label": ...}] - drawn in the frame's own coordinates
	for it in items:
		it["pos"] = to_frame(it["pos"])
	indicators.items = items
	indicators.queue_redraw()


## The game frame (layout.gd): the HUD is laid out inside it and scaled to it (`s`), so it looks the same in a
## wide desktop window and in the top half of a phone screen.
## play_boost: on a phone the frame is small, so the play HUD (floor, meter, prompt, toast) is drawn this much
## larger again. side: where the panel goes, "left" (landscape) or "bottom" (portrait phone).
func set_frame(r: Rect2, s: float, play_boost := 1.0, side := "left") -> void:
	play_boost = maxf(play_boost, HUD_MIN_PX / (HUD_SMALL * s))   # a small frame: the play HUD stays readable
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.scale = Vector2(s, s)
	root.position = r.position
	root.size = r.size / s
	# [control, extra scale, pivot as a share of its size: the corner / edge it is pinned to]
	_boosted = [[floor_lbl, play_boost, Vector2(0, 0)], [meter, play_boost, Vector2(1, 0)],
			[prompt_card, play_boost, Vector2(0.5, 1)], [toast_lbl, play_boost, Vector2(0.5, 0)]]
	for b in _boosted:
		(b[0] as Control).scale = Vector2.ONE * float(b[1])
	_pin_boosted()
	_frame = r
	_hud_s = s
	sheet_side = side
	_apply_side()
	_layout_sheet()


# ======================================================================= the panel
func _apply_side() -> void:
	var phone := sheet_side == "bottom"
	sheet.side = sheet_side
	var pad := SHEET_PHONE_PAD if phone else SHEET_PAD
	for m in ["left", "right", "top", "bottom"]:
		sheet.add_theme_constant_override("margin_" + m, int(roundf(pad)))
	sheet.queue_redraw()


## Window px of a panel unit: desktop as the HUD (but at most SHEET_MAX_SHARE of the frame wide);
## phone 0.8 of the mockup size, the mockup being 382 px wide.
func _sheet_scale() -> float:
	if sheet_side == "bottom":
		return SHEET_PHONE_SCALE * _frame.size.x / SHEET_PHONE_REF
	return minf(_hud_s, SHEET_MAX_SHARE * _frame.size.x / SHEET_W)


func _layout_sheet() -> void:
	## Size and slide position of the panel; the free part of the frame goes to the camera.
	var view := _frame
	if _cur_page != null and _frame.has_area():
		var s := _sheet_scale()
		sheet_layer.position = _frame.position
		sheet.scale = Vector2(s, s)
		if sheet_side == "left":
			var want := Vector2(SHEET_W, _frame.size.y / s)
			if sheet.size != want:
				sheet.size = want
			var w := sheet.size.x * s
			sheet.position = Vector2(-w * _sheet_off, 0.0)
			var shown := clampf(w + sheet.position.x, 0.0, _frame.size.x * 0.9)
			view = Rect2(_frame.position + Vector2(shown, 0.0), _frame.size - Vector2(shown, 0.0))
		else:
			var width := _frame.size.x / s
			if absf(sheet.size.x - width) > 0.01:
				sheet.size = Vector2(width, 0.0)
			var hgt := sheet.get_combined_minimum_size().y
			if absf(sheet.size.y - hgt) > 0.01:
				sheet.size = Vector2(width, hgt)
			var h := sheet.size.y * s
			sheet.position = Vector2(0.0, _frame.size.y - h + h * _sheet_off)
			var shown := clampf(_frame.size.y - sheet.position.y, 0.0, _frame.size.y * 0.9)
			view = Rect2(_frame.position, _frame.size - Vector2(0.0, shown))
		var look := [sheet.size, sheet.side]
		if look != _sheet_look:   # redraw only when the panel's shape changed (moving it needs no redraw)
			_sheet_look = look
			sheet.queue_redraw()
	if view != _view:
		_view = view
		view_changed.emit(view)


func _show_sheet(page: Control) -> void:
	## Put `page` on the panel: slides the panel in if it was hidden, otherwise fades the new page in.
	var was_shown := _cur_page != null
	if page != _cur_page:
		for p in _pages:
			p.visible = p == page
		if was_shown:
			page.modulate.a = 0.0
			if _swap_tw and _swap_tw.is_valid():
				_swap_tw.kill()
			_swap_tw = create_tween()
			_swap_tw.tween_property(page, "modulate:a", 1.0, SHEET_SWAP_TIME)
		else:
			page.modulate.a = 1.0
	_cur_page = page
	sheet.visible = true
	if not was_shown:
		_sheet_off = 1.0
		if _sheet_tw and _sheet_tw.is_valid():
			_sheet_tw.kill()
		_sheet_tw = create_tween()
		_sheet_tw.tween_property(self, "_sheet_off", 0.0, SHEET_TIME) \
				.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_layout_sheet()


func hide_sheet() -> void:
	if _sheet_tw and _sheet_tw.is_valid():
		_sheet_tw.kill()
	_cur_page = null
	_sheet_off = 1.0
	sheet.visible = false
	for p in _pages:
		p.visible = false
	_layout_sheet()


func _pin_boosted() -> void:
	for b in _boosted:
		var c: Control = b[0]
		c.pivot_offset = c.size * (b[2] as Vector2)


## Window point (e.g. Camera3D.unproject_position) -> HUD (frame) coordinates.
func to_frame(p: Vector2) -> Vector2:
	return root.get_global_transform().affine_inverse() * p


func fade_to(alpha: float, time := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, time)
	await tw.finished


func _all_off(keep_sheet := false) -> void:
	## Hide everything; keep_sheet: the next screen is a panel page too (it changes pages without sliding out).
	_clear_flyers()
	for c in [floor_lbl, meter, prompt_card, controls]:
		c.visible = false
	if not keep_sheet:
		hide_sheet()
	dim_rect.color.a = 0.0
	set_indicators([])
	big("")


func _process(delta: float) -> void:
	_pin_boosted()   # their sizes change with the text
	_layout_sheet()  # slide animation, text changes
	if _toast_t > 0.0:
		_toast_t -= delta
		toast_lbl.modulate.a = clampf(_toast_t / 0.5, 0.0, 1.0)
	else:
		toast_lbl.modulate.a = 0.0
	_flash = maxf(_flash - delta * 2.5, 0.0)
	red_rect.color.a = 0.28 * _flash
	# overloaded: the meter shakes
	meter.rotation = sin(Time.get_ticks_msec() / 22.0) * 0.035 * _flash if _flash > 0.0 else 0.0
