class_name Hud
extends CanvasLayer
## All on-screen UI, following the Figma design (file "KeyLock", page "game", frames 2–5):
##  * pixel font Pixelify Sans, accent #FFAE00, dark text #2C1E02;
##  * in-game HUD drawn straight on the scene (no panels): floor + timer top-left, grid meter top-right;
##  * the menu, the name input and the results on a white sheet (Figma node 35:49): a full-height panel on the
##    left of the game frame (desktop), a bottom sheet on a phone; it slides in from the left / from below, and
##    where it meets the 3D view its corners are concave, so the view keeps rounded corners. The camera keeps the
##    character in the middle of the part of the view the sheet leaves free (view_changed -> camera_rig.gd).

const FONT_PATH := "res://assets/fonts/PixelifySansUA.ttf"
const DARK := Color("2c1e02")
const ACCENT := Color("ffae00")
const GREEN := Color("5ccc73")
const RED := Color("f24c40")
const BAR_GREEN := Color("00cf68")
const WHITE := Color(1, 1, 1)
const C_GREEN := GREEN   # used by main.gd for "Старт!"
const DIM := Color("8a7a5c")
const ROW_HIGHLIGHT := Color("fff1cc")
const LEADERBOARD_ROWS := 8
const FLY_COLOR := Color("ffeaa0")   # power number flying from a switched-off appliance to the economy label
const FLY_SIZE := 30
const FLY_RISE := 70.0               # px it rises above the appliance first
const FLY_RISE_TIME := 0.45
const FLY_TIME := 0.7                # then the flight to the economy label
const FLY_END_SCALE := 0.3
# the menu sheet (design px of the desktop mockup "620", 1280x720)
const SHEET_W := 506.0           # desktop: width of the side panel
const SHEET_PAD := 40.0          # desktop: padding round the content (the content is centred vertically)
const SHEET_RADIUS := 20.0       # the concave corners (mockup px, desktop and phone)
const SHEET_MAX_SHARE := 0.5     # the side panel never takes more than this share of the frame's width
const SHEET_TIME := 0.5          # slide-in, s
const SHEET_SWAP_TIME := 0.2     # another page on a sheet already shown: its content fades in
# phone (mockup "iPhone 17 - 2", 382 px wide frame): the same content at 0.8 of the desktop size,
# 15 px padding, ~8 px between the rows
const SHEET_PHONE_REF := 382.0
const SHEET_PHONE_SCALE := 0.8
const SHEET_PHONE_PAD := 19.0    # 15 phone px in desktop units (15 / 0.8)

signal name_submitted(name: String)
## The part of the game frame (window px) that the menu sheet leaves free; the frame itself when it is hidden.
signal view_changed(rect: Rect2)

var font: FontFile
var root: Control

# in-game HUD
var hud_left: VBoxContainer
var hud_right: VBoxContainer
var floor_lbl: Label
var time_lbl: Label
var meter_title: Label
var meter_bar: PixelBar
var load_lbl: Label
var wh_lbl: Label
var econ_lbl: Label
var thr_lbl: Label
var on_lbl: Label
var _hud_labels: Array[Label] = []

var dim_rect: ColorRect
var red_rect: ColorRect
var indicators: Indicators
var _boosted: Array = []
var touch_keys := false   # hints name the on-screen buttons (0 / X) instead of Enter / Space / Esc
var _hints: Array = []    # [key label, key, enter icon or null] of every hint row
var prompt_card: PanelContainer
var prompt_rtl: RichTextLabel
var big_box: VBoxContainer
var big_lbl: Label
var sub_lbl: Label
var toast_lbl: Label
var fade_rect: ColorRect

# the menu sheet and its pages (one shown at a time)
var sheet_layer: Control          # at the frame's top-left corner, window px (not scaled with the HUD)
var sheet: Sheet
var sheet_side := "left"          # "left" (desktop, landscape) or "bottom" (phone, portrait)
var _pages: Array[Control] = []
var _cur_page: Control = null         # the page on the sheet, null = hidden
var _sheet_off := 1.0             # slide: 0 = in place, 1 = fully out
var _sheet_tw: Tween
var _swap_tw: Tween
var _gaps: Array = []             # [box, desktop separation, phone separation]
var _frame := Rect2()
var _hud_s := 1.0
var _view := Rect2()

# menu page
var select_panel: VBoxContainer
var sel_name: Label
var sel_speed: SegBar
var sel_switch: SegBar

# result page
var result_panel: VBoxContainer
var res_stars: HBoxContainer
var res_title: Label
var res_lines: VBoxContainer
var res_hints: VBoxContainer

# name input page
var name_panel: VBoxContainer
var name_edit: LineEdit

# leaderboard card
var board_panel: PanelContainer
var board_title: Label
var board_rows: VBoxContainer

var _toast_t := 0.0
var _flash := 0.0
var _flyers: Array[Label] = []
var _econ_tw: Tween


# ======================================================================= small custom controls
class PixelBar:
	## 290x10 meter with stepped ("pixel-rounded") ends, as in the Figma frame.
	extends Control
	var frac := 0.0
	var fill := Color("00cf68")
	var track := Color(0.17, 0.12, 0.01, 0.22)
	var track_tex: Texture2D = Icons.png("meter_track")
	var fill_tex: Texture2D     # set by the HUD: meter_fill_ok / _warn / _danger
	var light := false
	const STEPS := [2, 1, 0, 0, 1, 2]   # horizontal inset per row band (top..bottom)
	func _init() -> void:
		custom_minimum_size = Vector2(290, 10)
	func _draw_shape(w: float, c: Color) -> void:
		if w <= 0.0:
			return
		var h := size.y
		var band := h / STEPS.size()
		for i in STEPS.size():
			var inset: float = minf(STEPS[i], w / 2.0)
			draw_rect(Rect2(inset, i * band, maxf(w - inset * 2.0, 0.0), band + 0.01), c)
	func _draw() -> void:
		var f := clampf(frac, 0.0, 1.0)
		if track_tex and not light:
			draw_texture_rect(track_tex, Rect2(Vector2.ZERO, size), false)
		else:
			_draw_shape(size.x, track)
		if fill_tex:
			if f > 0.0:
				var ts := fill_tex.get_size()
				draw_texture_rect_region(fill_tex, Rect2(0, 0, size.x * f, size.y), Rect2(0, 0, ts.x * f, ts.y))
		else:
			_draw_shape(size.x * f, fill)


class SegBar:
	## 5 segments 6x12, filled = dark, empty = 2px dark outline.
	extends Control
	var value := 3
	var color := Color("2c1e02")
	var on_tex: Texture2D = Icons.png("seg_on")
	var off_tex: Texture2D = Icons.png("seg_off")
	func _init() -> void:
		custom_minimum_size = Vector2(38, 12)
	func _draw() -> void:
		for i in 5:
			var r := Rect2(i * 8, 0, 6, 12)
			var tex := on_tex if i < value else off_tex
			if tex:
				draw_texture_rect(tex, r, false)
			elif i < value:
				draw_rect(r, color)
			else:
				draw_rect(r.grow(-1), color, false, 2.0)


class Sheet:
	## The white menu panel. side "left": the panel's right edge meets the view, so its top-right and
	## bottom-right get concave corners outside the panel; side "bottom": its top edge meets the view (corners
	## top-left and top-right, above the panel). The outer corners are rounded by the frame (layout.gd).
	extends MarginContainer
	var side := "left"
	var radius := 20.0   # in the sheet's own units

	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color.WHITE)
		if side == "left":
			_fillet(Vector2(w, 0), Vector2(1, 1))
			_fillet(Vector2(w, h), Vector2(1, -1))
		else:
			_fillet(Vector2(0, 0), Vector2(1, -1))
			_fillet(Vector2(w, 0), Vector2(-1, -1))

	func _fillet(p: Vector2, d: Vector2) -> void:
		## The white piece at corner p, reaching into the view (direction d): the square p .. p + d * r without
		## the circle centred at its far corner.
		var r := radius
		var c := p + d * r
		var a0 := Vector2(0, -d.y).angle()      # from c to p + (d.x r, 0)
		var a1 := Vector2(-d.x, 0).angle()      # from c to p + (0, d.y r)
		var da := wrapf(a1 - a0, -PI, PI)
		var arc := PackedVector2Array()
		for i in 17:
			arc.append(c + Vector2.from_angle(a0 + da * i / 16.0) * r)
		var poly := PackedVector2Array([p])
		poly.append_array(arc)
		draw_colored_polygon(poly, Color.WHITE)
		draw_polyline(arc, Color.WHITE, 1.0, true)   # smooth edge


class Indicators:
	## Arrows at the screen edge pointing to active appliances that are off-screen.
	extends Control
	var items: Array = []
	var font: Font
	var nav_tex: Texture2D = Icons.png("nav_indicator")   # square, arrow points right, rotates around its centre
	const NAV_SIZE := 46.0   # on-screen diameter (design px)
	const MARGIN := 56.0
	func _draw() -> void:
		var inner := Rect2(Vector2(MARGIN, 170.0), size - Vector2(MARGIN * 2.0, 170.0 + MARGIN))
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
				draw_circle(q, 20.0, Color("2c1e02"), false, 2.0)
				draw_string(font, q + Vector2(-4, 9), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("2c1e02"))
			var lbl: String = it["label"]
			var w := font.get_string_size(lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
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
			draw_string(font, lp + Vector2(1, 1), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.85))
			draw_string(font, lp, lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))


# ======================================================================= build
func _ready() -> void:
	layer = 2
	process_priority = -10   # lay the sheet out before the camera reads the free view (same frame, no lag)
	font = load(FONT_PATH)
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
	indicators = Indicators.new()
	indicators.font = font
	indicators.set_anchors_preset(Control.PRESET_FULL_RECT)
	indicators.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(indicators)
	_build_hud()
	_build_prompt()
	_build_big()
	_build_board()
	# the sheet: above the HUD, below the fade (which now covers the whole window: outside the frame the
	# background of layout.gd is drawn on top anyway)
	sheet_layer = Control.new()
	sheet_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet_layer.theme = theme
	add_child(sheet_layer)
	sheet = Sheet.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheet.visible = false
	sheet_layer.add_child(sheet)
	_build_select()
	_build_result()
	_build_name()
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	_apply_side()
	_all_off()


func _label(text: String, size: int, color := DARK, shadow := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow > 0:
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
		l.add_theme_constant_override("shadow_offset_x", shadow)
		l.add_theme_constant_override("shadow_offset_y", shadow)
		l.add_theme_constant_override("shadow_outline_size", 0)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


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


func _page(desktop_gap: int, phone_gap: int) -> VBoxContainer:
	## A page of the sheet (menu, name input, result): centred vertically on the side panel.
	var v: VBoxContainer = _gap(_box(true, desktop_gap), desktop_gap, phone_gap)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.visible = false
	sheet.add_child(v)
	_pages.append(v)
	return v


func _gap(b: BoxContainer, desktop: int, phone: int) -> BoxContainer:
	## Rows closer together on the phone's bottom sheet (mockup: ~8 px between the rows).
	_gaps.append([b, desktop, phone])
	return b


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


func _anchor(ctrl: Control, valign: BoxContainer.AlignmentMode, halign: Control.SizeFlags, margin := 32) -> void:
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


func _icon(tex: Texture2D, px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.custom_minimum_size = px
	t.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _tex(name: String, fallback: Texture2D) -> Texture2D:
	## PNG from assets/ui/ if present (redrawn art), otherwise the built-in version.
	var t := Icons.png(name)
	return t if t else fallback


func _hint_row(key: String, action: String, size := 16, enter_icon := false) -> HBoxContainer:
	## "Нажміть  Enter ↵  щоб …" (on a touch screen: "Нажміть  0  щоб …", the name of the on-screen button)
	var row: HBoxContainer = _box(false, 8)
	row.add_child(_label("Нажміть", size))
	var key_lbl := _label(key_name(key), size, ACCENT)
	row.add_child(key_lbl)
	var icon: TextureRect = null
	if enter_icon:
		icon = _icon(_tex("icon_enter", Icons.pixel("enter", Icons.ENTER, ACCENT)), Vector2(10, 10))
		icon.visible = not touch_keys
		row.add_child(icon)
	row.add_child(_label(action, size))
	_hints.append([key_lbl, key, icon])
	return row


## The key as the player sees it: on a touch screen the name of the on-screen button that does the same.
func key_name(key: String) -> String:
	if not touch_keys:
		return key
	var b: Dictionary = GameConfig.TOUCH_BUTTONS
	return {"Enter": b["a"], "Пробіл": b["a"], "Esc": b["b"]}.get(key, key)


## Touch screen or keyboard (layout.gd): rename the keys in the hints already on screen.
func set_touch_keys(on: bool) -> void:
	if on == touch_keys:
		return
	touch_keys = on
	_hints = _hints.filter(func(h): return is_instance_valid(h[0]))
	for h in _hints:
		(h[0] as Label).text = key_name(h[1])
		if h[2]:
			(h[2] as TextureRect).visible = not on


func _build_hud() -> void:
	# --- top-left: floor + timer
	hud_left = _box(true, 0)
	floor_lbl = _label("Поверх 1", 12)
	time_lbl = _label("01:00", 24)
	hud_left.add_child(floor_lbl)
	hud_left.add_child(time_lbl)
	_anchor(hud_left, BoxContainer.ALIGNMENT_BEGIN, Control.SIZE_SHRINK_BEGIN)
	# --- top-right: grid meter (290 px wide)
	hud_right = _box(true, 4)
	hud_right.custom_minimum_size.x = 290
	var top: VBoxContainer = _box(true, 3)
	meter_title = _label("Навантаження мережі", 12)
	top.add_child(meter_title)
	meter_bar = PixelBar.new()
	top.add_child(meter_bar)
	hud_right.add_child(top)
	var row1: HBoxContainer = _box(false, 8)
	load_lbl = _label("0.0 / 4.0 кВт", 24)
	load_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wh_lbl = _label("Спожито: 0.0 Вт • год", 12)
	wh_lbl.size_flags_vertical = Control.SIZE_SHRINK_END
	wh_lbl.add_theme_constant_override("line_spacing", 0)
	row1.add_child(load_lbl)
	row1.add_child(wh_lbl)
	hud_right.add_child(row1)
	var row2: HBoxContainer = _box(false, 8)
	econ_lbl = _label("100% економія", 24, ACCENT, 1)
	econ_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	thr_lbl = _label("≥ 50%", 24, ACCENT, 1)
	row2.add_child(econ_lbl)
	row2.add_child(thr_lbl)
	hud_right.add_child(row2)
	on_lbl = _label("Увімкнено приладів: 0", 12)
	hud_right.add_child(on_lbl)
	_anchor(hud_right, BoxContainer.ALIGNMENT_BEGIN, Control.SIZE_SHRINK_END)
	_hud_labels = [floor_lbl, time_lbl, meter_title, load_lbl, wh_lbl, on_lbl]


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
	prompt_rtl.add_theme_font_size_override("normal_font_size", 16)
	prompt_rtl.add_theme_color_override("default_color", DARK)
	prompt_card.add_child(prompt_rtl)
	_anchor(prompt_card, BoxContainer.ALIGNMENT_END, Control.SIZE_SHRINK_CENTER, 28)


func _build_big() -> void:
	big_box = _box(true, 4)
	big_box.alignment = BoxContainer.ALIGNMENT_CENTER
	big_lbl = _label("", 96, ACCENT, 4)
	sub_lbl = _label("", 24, WHITE, 2)
	for l in [big_lbl, sub_lbl]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		big_box.add_child(l)
	_anchor(big_box, BoxContainer.ALIGNMENT_CENTER, Control.SIZE_SHRINK_CENTER, 0)
	toast_lbl = _label("", 24, ACCENT, 2)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_anchor(toast_lbl, BoxContainer.ALIGNMENT_BEGIN, Control.SIZE_SHRINK_CENTER, 150)


func _build_select() -> void:
	## Mockup "620" (node 35:49): title, name + arrows, two stat bars, start hint; 426 x 217 at 40 px from the left.
	select_panel = _page(16, 8)
	var v := select_panel
	v.add_child(_title_row())
	var body: VBoxContainer = _gap(_box(true, 12), 12, 8)
	v.add_child(body)
	# name + arrows
	var name_row: HBoxContainer = _box(false, 9)
	sel_name = _label("Мати", 40)
	name_row.add_child(sel_name)
	var arrows: HBoxContainer = _box(false, 6)
	arrows.size_flags_vertical = Control.SIZE_SHRINK_END
	arrows.add_child(_icon(_tex("icon_arrow_left", Icons.pixel("al", Icons.ARROW_LEFT, ACCENT)), Vector2(10, 10)))
	arrows.add_child(_icon(_tex("icon_arrow_right", Icons.pixel("ar", Icons.ARROW_RIGHT, ACCENT)), Vector2(10, 10)))
	var arrows_wrap: VBoxContainer = _box(true, 0)
	arrows_wrap.alignment = BoxContainer.ALIGNMENT_END
	arrows_wrap.add_child(arrows)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 14)
	arrows_wrap.add_child(spacer)
	name_row.add_child(arrows_wrap)
	body.add_child(name_row)
	# stats + start hint
	var lower: VBoxContainer = _gap(_box(true, 16), 16, 8)
	body.add_child(lower)
	var stats: HBoxContainer = _box(false, 24)
	sel_speed = SegBar.new()
	sel_switch = SegBar.new()
	for pair in [["Швидкість", sel_speed], ["Вимикання", sel_switch]]:
		var col: VBoxContainer = _box(true, 4)
		col.add_child(_label(pair[0], 24))
		col.add_child(pair[1])
		stats.add_child(col)
	lower.add_child(stats)
	lower.add_child(_hint_row("Enter", "щоб почати", 24, true))


func _title_row() -> HBoxContainer:
	## Logo + "Енергетична криза" (accent, black shadow).
	var head: HBoxContainer = _box(false, 9)
	head.add_child(_icon(_tex("logo", Icons.svg("logo", Icons.LOGO_SVG, 32)), Vector2(32, 32)))
	head.add_child(_label("Енергетична криза", 40, ACCENT, 2))
	return head


func _build_result() -> void:
	## Same sheet as the menu: stars, title (green / red), a few lines (wrapped to the sheet), key hints.
	result_panel = _page(16, 8)
	var v := result_panel
	var head: VBoxContainer = _gap(_box(true, 8), 8, 4)
	res_stars = _box(false, 2)
	head.add_child(res_stars)
	res_title = _label("Поверх пройдено!", 40, GREEN, 2)
	head.add_child(res_title)
	v.add_child(head)
	res_lines = _gap(_box(true, 8), 8, 4)
	v.add_child(res_lines)
	res_hints = _gap(_box(true, 6), 6, 2)
	v.add_child(res_hints)


# ======================================================================= public API
# ======================================================================= name input + leaderboard
func _build_name() -> void:
	name_panel = _page(16, 8)
	var v := name_panel
	v.add_child(_title_row())
	var body: VBoxContainer = _gap(_box(true, 8), 8, 6)
	body.add_child(_label("Ім'я гравця", 24))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Нікнейм"
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(380, 52)
	name_edit.add_theme_font_size_override("font_size", 28)
	name_edit.add_theme_color_override("font_color", DARK)
	name_edit.add_theme_color_override("font_placeholder_color", Color(DIM, 0.7))
	name_edit.add_theme_color_override("caret_color", ACCENT)
	name_edit.add_theme_color_override("selection_color", Color(ACCENT, 0.35))
	for st in ["normal", "focus", "read_only"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("f7f2e8")
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(2)
		sb.border_color = ACCENT if st == "focus" else DARK
		sb.content_margin_left = 14
		sb.content_margin_right = 14
		name_edit.add_theme_stylebox_override(st, sb)
	name_edit.text_submitted.connect(_on_name_entered)
	body.add_child(name_edit)
	v.add_child(body)
	v.add_child(_hint_row("Enter", "щоб продовжити", 24, true))


func _on_name_entered(text: String) -> void:
	var n := text.strip_edges()
	if n.is_empty():
		toast("Введіть ім'я гравця")
		name_edit.grab_focus()
		return
	name_submitted.emit(n)


func submit_name() -> void:
	_on_name_entered(name_edit.text)


func show_name(default_name: String, leaders: Array) -> void:
	_all_off(true)
	_show_sheet(name_panel)
	name_edit.text = default_name
	name_edit.caret_column = default_name.length()
	name_edit.grab_focus.call_deferred()
	show_leaderboard(leaders, default_name, "Рейтинг енергії")


func _build_board() -> void:
	board_panel = _card(22, 24)
	board_panel.custom_minimum_size.x = 380
	var v: VBoxContainer = _box(true, 10)
	board_panel.add_child(v)
	board_title = _label("Рейтинг енергії", 28)
	v.add_child(board_title)
	var head := _board_row("№", "Гравець", "Енергія, Вт • год", DIM, 14)
	v.add_child(head)
	board_rows = _box(true, 2)
	v.add_child(board_rows)
	_anchor(board_panel, BoxContainer.ALIGNMENT_END, Control.SIZE_SHRINK_END)


func _board_row(pos: String, who: String, score: String, color: Color, size := 18, highlight := false) -> Control:
	var row: HBoxContainer = _box(false, 8)
	var p := _label(pos, size, ACCENT if (pos in ["1", "2", "3"]) and not highlight else color)
	p.custom_minimum_size.x = 36
	var n := _label(who, size, color)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var s := _label(score, size, color)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	s.custom_minimum_size.x = 120
	for c in [p, n, s]:
		row.add_child(c)
	if not highlight:
		return row
	var bg := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = ROW_HIGHLIGHT
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	bg.add_theme_stylebox_override("panel", sb)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(row)
	return bg


## entries: [{name, score}] sorted best first. The player's row is highlighted;
## if the player is below the visible rows, their row is appended after "…".
func show_leaderboard(entries: Array, player: String, title := "Рейтинг енергії") -> void:
	if not GameConfig.SHOW_LEADERBOARD:   # table hidden for now; results are still saved
		board_panel.visible = false
		return
	board_title.text = title
	for c in board_rows.get_children():
		c.queue_free()
	if entries.is_empty():
		board_rows.add_child(_label("Поки що порожньо — стань першим!", 16, DIM))
	var key := player.strip_edges().to_lower()
	var shown_player := false
	for i in mini(entries.size(), LEADERBOARD_ROWS):
		var e: Dictionary = entries[i]
		var me := str(e["name"]).strip_edges().to_lower() == key and key != ""
		shown_player = shown_player or me
		board_rows.add_child(_board_row(str(i + 1), str(e["name"]), "%.1f" % float(e["score"]), DARK, 18, me))
	if not shown_player and key != "":
		for i in entries.size():
			if str(entries[i]["name"]).strip_edges().to_lower() == key:
				board_rows.add_child(_label("…", 18, DIM))
				board_rows.add_child(_board_row(str(i + 1), str(entries[i]["name"]), "%.1f" % float(entries[i]["score"]), DARK, 18, true))
				break
	board_panel.visible = true


func show_select(cfg: Dictionary) -> void:
	_all_off(true)
	_show_sheet(select_panel)
	sel_name.text = cfg["name"]
	sel_speed.value = clampi(roundi(remap(cfg["speed"], 2.4, 4.0, 1, 5)), 1, 5)
	sel_switch.value = clampi(roundi(remap(cfg["switch_time"], 1.1, 0.25, 1, 5)), 1, 5)
	sel_speed.queue_redraw()
	sel_switch.queue_redraw()


func show_play(floor_num: int, total: int) -> void:
	_all_off()
	hud_left.visible = true
	hud_right.visible = true
	set_hud_light(false)
	floor_lbl.text = "Поверх %d з %d" % [floor_num, total]


func set_hud_light(on: bool) -> void:
	## White HUD text for dark scenes (blackout / dimmed result), dark text otherwise.
	for l in _hud_labels:
		l.add_theme_color_override("font_color", WHITE if on else DARK)
	meter_bar.track = Color(1, 1, 1, 0.25) if on else Color(0.17, 0.12, 0.01, 0.22)
	meter_bar.light = on
	meter_bar.queue_redraw()


func update_play(time_left: float, load_kw: float, limit_kw: float, wh: float, econ: float, thr: float, on_count: int) -> void:
	var s := int(ceil(maxf(time_left, 0.0)))
	time_lbl.text = "%02d:%02d" % [s / 60, s % 60]
	if time_left <= 10.0:
		time_lbl.add_theme_color_override("font_color", RED)
	var frac := load_kw / limit_kw
	meter_bar.frac = frac
	meter_bar.fill = BAR_GREEN if frac < 0.7 else (ACCENT if frac <= 1.0 else RED)
	meter_bar.fill_tex = Icons.png("meter_fill_ok" if frac < 0.7 else ("meter_fill_warn" if frac <= 1.0 else "meter_fill_danger"))
	meter_bar.queue_redraw()
	load_lbl.text = "%.1f / %.1f кВт" % [load_kw, limit_kw]
	wh_lbl.text = "Спожито: %.1f Вт • год" % wh
	econ_lbl.text = "%d%% економія" % roundi(econ * 100.0)
	thr_lbl.text = "≥ %d%%" % roundi(thr * 100.0)
	on_lbl.text = "Увімкнено приладів: %d" % on_count


func prompt(bbcode: String) -> void:
	prompt_card.visible = bbcode != ""
	if prompt_rtl.text != bbcode:
		prompt_rtl.text = bbcode


func big(text: String, sub := "", color := ACCENT) -> void:
	big_lbl.text = text
	sub_lbl.text = sub
	big_lbl.add_theme_color_override("font_color", color)


func toast(text: String) -> void:
	toast_lbl.text = text
	_toast_t = 2.2


## A switched-off appliance's power: the number pops up above the appliance (screen point `from`), rises, then
## flies into the economy label, shrinking and fading out; the label gives a small pulse when it arrives.
func fly_power(from: Vector2, watts: int) -> void:
	from = to_frame(from)
	from.y = maxf(from.y, FLY_RISE + 30.0)   # an appliance at the top edge: keep the number on screen
	var l := _label(str(watts), FLY_SIZE, FLY_COLOR)
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
	# 1) pop up and rise above the appliance
	tw.tween_property(l, "scale", Vector2.ONE * 1.15, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15).set_delay(0.18)
	tw.tween_property(l, "position:y", l.position.y - FLY_RISE, FLY_RISE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2) fly to the economy number, shrinking and fading
	var p0 := from - Vector2(0, FLY_RISE)
	tw.chain().tween_method(func(k: float) -> void: _fly_step(l, p0, k), 0.0, 1.0, FLY_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.chain().tween_callback(func() -> void:
		_flyers.erase(l)
		l.queue_free()
		_pulse_econ())


func _econ_target() -> Vector2:
	## Centre of the percentage ("74%") at the start of the economy label.
	var word := econ_lbl.text.split(" ")[0]
	var w := font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
	return to_frame(econ_lbl.get_global_transform() * Vector2(w / 2.0, econ_lbl.size.y / 2.0))


func _fly_step(l: Label, p0: Vector2, k: float) -> void:
	if not is_instance_valid(l):
		return
	var p1 := _econ_target()   # follows the label if the layout changes during the flight
	# a slight arc towards the label (kept on screen)
	var mid := (p0 + p1) / 2.0 + Vector2(0, -40)
	mid.y = maxf(mid.y, 24.0)
	var a := p0.lerp(mid, k)
	var b := mid.lerp(p1, k)
	l.position = a.lerp(b, k) - l.pivot_offset
	l.scale = Vector2.ONE * lerpf(1.0, FLY_END_SCALE, k)
	l.modulate.a = 1.0 - smoothstep(0.65, 1.0, k)


func _pulse_econ() -> void:
	if _econ_tw and _econ_tw.is_valid():
		_econ_tw.kill()
	econ_lbl.pivot_offset = Vector2(0, econ_lbl.size.y / 2.0)
	_econ_tw = create_tween()
	_econ_tw.tween_property(econ_lbl, "scale", Vector2.ONE * 1.12, 0.08)
	_econ_tw.tween_property(econ_lbl, "scale", Vector2.ONE, 0.18)


func _clear_flyers() -> void:
	for l in _flyers:
		if is_instance_valid(l):
			l.queue_free()
	_flyers.clear()
	if econ_lbl:
		econ_lbl.scale = Vector2.ONE


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
## play_boost: on a phone the frame is small, so the play HUD (timer, load meter, prompt, toast) is drawn this
## much larger again. side: where the menu sheet goes, "left" (landscape) or "bottom" (portrait phone).
func set_frame(r: Rect2, s: float, play_boost := 1.0, side := "left") -> void:
	root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root.scale = Vector2(s, s)
	root.position = r.position
	root.size = r.size / s
	# [control, extra scale, pivot as a share of its size: the corner / edge it is pinned to]
	_boosted = [[hud_left, play_boost, Vector2(0, 0)], [hud_right, play_boost, Vector2(1, 0)],
			[prompt_card, play_boost, Vector2(0.5, 1)], [toast_lbl, play_boost, Vector2(0.5, 0)]]
	for b in _boosted:
		(b[0] as Control).scale = Vector2.ONE * float(b[1])
	_pin_boosted()
	_frame = r
	_hud_s = s
	sheet_side = side
	_apply_side()
	_layout_sheet()


# ======================================================================= the menu sheet
func _apply_side() -> void:
	var phone := sheet_side == "bottom"
	sheet.side = sheet_side
	var pad := SHEET_PHONE_PAD if phone else SHEET_PAD
	for m in ["left", "right", "top", "bottom"]:
		sheet.add_theme_constant_override("margin_" + m, int(roundf(pad)))
	for g in _gaps:
		(g[0] as BoxContainer).add_theme_constant_override("separation", g[2] if phone else g[1])


## Window px of a sheet unit: desktop as the HUD (but at most SHEET_MAX_SHARE of the frame wide);
## phone 0.8 of the mockup size, the mockup being 382 px wide.
func _sheet_scale() -> float:
	if sheet_side == "bottom":
		return SHEET_PHONE_SCALE * _frame.size.x / SHEET_PHONE_REF
	return minf(_hud_s, SHEET_MAX_SHARE * _frame.size.x / SHEET_W)


func _layout_sheet() -> void:
	## Size and slide position of the sheet; the free part of the frame goes to the camera.
	var view := _frame
	if _cur_page != null and _frame.has_area():
		var s := _sheet_scale()
		sheet_layer.position = _frame.position
		sheet.scale = Vector2(s, s)
		var r_px := SHEET_RADIUS * (_frame.size.x / SHEET_PHONE_REF if sheet_side == "bottom" else _hud_s)
		sheet.radius = r_px / s
		if sheet_side == "left":
			var want := Vector2(SHEET_W, _frame.size.y / s)
			if sheet.size != want:
				sheet.size = want
			var w := sheet.size.x * s
			sheet.position = Vector2(-(w + r_px) * _sheet_off, 0.0)
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
			sheet.position = Vector2(0.0, _frame.size.y - h + (h + r_px) * _sheet_off)
			var shown := clampf(_frame.size.y - sheet.position.y, 0.0, _frame.size.y * 0.9)
			view = Rect2(_frame.position, _frame.size - Vector2(0.0, shown))
		sheet.queue_redraw()
	if view != _view:
		_view = view
		view_changed.emit(view)


func _show_sheet(page: Control) -> void:
	## Put `page` on the sheet: slides the sheet in if it was hidden, otherwise fades the new page in.
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
	if name_edit:
		name_edit.release_focus()
	_layout_sheet()


func _pin_boosted() -> void:
	for b in _boosted:
		var c: Control = b[0]
		c.pivot_offset = c.size * (b[2] as Vector2)


## Window point (e.g. Camera3D.unproject_position) -> HUD (frame) coordinates.
func to_frame(p: Vector2) -> Vector2:
	return root.get_global_transform().affine_inverse() * p


## lines: Array of String; hints: Array of [key, action, enter_icon]
func show_result(win: bool, title: String, lines: Array, stars: int, hints: Array) -> void:
	prompt_card.visible = false
	set_indicators([])
	big("")
	# design: passed -> clean scene; failed -> dimmed scene + white grid meter (not on a phone: the view
	# above the bottom sheet is small)
	hud_left.visible = false
	hud_right.visible = not win and sheet_side == "left"
	set_hud_light(not win)
	dim_rect.color.a = 0.0 if win else 0.45
	for c in res_stars.get_children():
		c.queue_free()
	res_stars.visible = win
	if win:
		for i in 3:
			var on := i < stars
			var fallback := Icons.svg("star_on" if on else "star_off", Icons.STAR_SVG if on else Icons.STAR_GREY_SVG, 32)
			res_stars.add_child(_icon(_tex("star_on" if on else "star_off", fallback), Vector2(32, 32)))
	res_title.text = title
	res_title.add_theme_color_override("font_color", GREEN if win else RED)
	for c in res_lines.get_children():
		c.queue_free()
	for l in lines:
		var lbl := _label(l, 20)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # long lines wrap to the sheet's width
		res_lines.add_child(lbl)
	for c in res_hints.get_children():
		c.queue_free()
	for h in hints:
		res_hints.add_child(_hint_row(h[0], h[1], 20, h.size() > 2 and h[2]))
	_show_sheet(result_panel)


func fade_to(alpha: float, time := 0.35) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", alpha, time)
	await tw.finished


func _all_off(keep_sheet := false) -> void:
	## Hide everything; keep_sheet: the next screen is a sheet page too (it changes pages without sliding out).
	_clear_flyers()
	if name_edit:
		name_edit.release_focus()
	for c in [hud_left, hud_right, prompt_card, board_panel]:
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
