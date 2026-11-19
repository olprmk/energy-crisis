extends Node3D
## Game flow (Figma "KeyLock" 48:2814): start screen -> countdown -> 60 s round -> result: success (next floor /
## restart the game) or fail (try the floor again / restart) -> ... floors 1..10, then endless floors.
## This version: English only, one character (the child; the others stay in the game for later updates).


enum State { START, COUNTDOWN, PLAY, RESULT, BUSY }

var state := State.BUSY
var floor_idx := 0
var char_idx := 0
var layout: Dictionary      # the apartment on screen: floor<model>_layout.json
var level: Node3D           # ... its model (floor<model>.glb)
var model := ""             # ... its id (GameConfig.FLOORS[i].model)
var apartments := {}        # model id -> built apartment (see _build_apartment)
var player: Player
var rig: CameraRig
var hud: Hud
var crazy: Crazy = null   # CrazyGames build only (scripts/crazy.gd): SDK events, username, mute
var sfx: Sfx
var steps   # scripts/footsteps.gd
var fx: ScreenFx
var music   # Music (scripts/music.gd); preloaded so it works before the editor refreshes its class list
var screen_layout   # scripts/layout.gd: the game frame on the background + touch controls (adapts to the window)
var sun: DirectionalLight3D
var env: Environment
var _sun_energy := 1.2       # daylight (the blackout after a short circuit dims it)
var _ambient_energy := 0.6
var lamps: Array = []        # [OmniLight3D, its energy] of the apartment on screen (they flicker near overload)
var _flick_left := 0.0       # s left of the current flicker
var _flick_dim := 1.0        # the lights' share during it
var apps: Array[Appliance] = []
var lift_label: Label3D   # floor number on the lift display
var spawn_pos := Vector3.ZERO
var rng := RandomNumberGenerator.new()

# round state
var t := 0.0
var countdown := 0.0
var next_spawn := 0.0
var consumed_wh := 0.0        # switchable appliances only (used for economy)
var fridge_wh := 0.0
var potential_wh := 0.0       # what spawned appliances would use if never switched off
var potential_rate_w := 0.0
var overload_t := 0.0
var alarm_t := 0.0
var spawned := 0
var switched := 0
var total_stars := 0
var _plug_t := 0.0           # smart plug: seconds of something being on since it last switched one off
var save            # SaveData (scripts/save_data.gd): last name + leaderboard, stored in user://save.json
var player_name := ""
var run_passed_wh := 0.0   # energy saved on floors already passed in this run
var result_win := false
# a game just started (from the start screen): the controls are shown at the bottom and the first appliance
# switches on next to the player, until the first appliance is switched off
var _controls := false
var _demo := false         # screenshot / test run (separate save)
var _char_scenes: Array = []   # the four characters' models, loaded once: switching characters must not reload them
var _switch_target: Appliance

# --- automated test mode (godot -- --autotest) -----------------------------
var autotest := false
var _auto_shots := ""
var _bot_speed := 6.0       # autotest bot speed, m/s (--bot-speed=2.4 for a human-like pace)
var _bot_react := 0.0       # autotest bot reaction time, s (--bot-react=0.8)
var _all_floors := false     # autotest: keep going after a failed floor (balance report)
var _last_reason := ""       # why the last round ended (autotest report)
var _physical := false       # autotest: the bot walks with collisions at the character's speed (finds stuck spots)
var _video := false          # autotest --video: real time, appliances from the first second (trailer recording)
var _bot_char := -1          # autotest: character (--char=1..4; default: the playable one)
var _step_count := {}        # autotest: footsteps heard per floor surface
var _floor_from := 0         # autotest: floors _floor_from + 1 .. _floor_to
var _floor_to := 0


func _ready() -> void:
	rng.randomize()
	var args := OS.get_cmdline_user_args()
	autotest = args.has("--autotest")
	for a in args:
		if a.begins_with("--shots="):
			_auto_shots = a.substr(8)
		elif a.begins_with("--bot-speed="):
			_bot_speed = float(a.substr(12))
		elif a.begins_with("--bot-react="):
			_bot_react = float(a.substr(12))
		elif a == "--all-floors":
			_all_floors = true
		elif a == "--physical":
			_physical = true
		elif a == "--video":
			_video = true
		elif a.begins_with("--char="):
			_bot_char = int(a.substr(7)) - 1
		elif a.begins_with("--floors="):   # e.g. --floors=7-10: only these floors (balance runs)
			var r := a.substr(9).split("-")
			_floor_from = int(r[0]) - 1
			_floor_to = int(r[r.size() - 1])
	if Crazy.enabled:
		crazy = Crazy.new()
		add_child(crazy)
		await crazy.setup()   # the page initialises the SDK; it also decides the language there
	Lang.code = "en"   # this version: English only (lang.gd keeps the Ukrainian texts for later)
	_setup_window()
	_setup_input()
	_setup_world()

	add_child(preload("res://scripts/perf.gd").new())   # 3D resolution in the browser, F3 meter
	sfx = Sfx.new()
	add_child(sfx)
	steps = preload("res://scripts/footsteps.gd").new()
	add_child(steps)
	fx = ScreenFx.new()
	add_child(fx)
	music = preload("res://scripts/music.gd").new()
	add_child(music)
	rig = CameraRig.new()
	add_child(rig)
	player = Player.new()
	add_child(player)
	player.cam = rig.cam
	player.switch_hit.connect(_on_switch_hit)
	player.step.connect(_on_step)
	rig.target = player
	_use_apartment(0)
	hud = Hud.new()
	add_child(hud)
	hud.view_changed.connect(func(r: Rect2) -> void: rig.view = r)   # the menu sheet covers part of the frame
	screen_layout = preload("res://scripts/layout.gd").new()
	add_child(screen_layout)
	screen_layout.layout_changed.connect(_on_layout_changed)
	var demo := false   # screenshot / test runs use a separate save file
	for a in args:
		if a.begins_with("--ui-shots=") or a.begins_with("--floor-shots=") or a.begins_with("--stick-shots=") \
				or a.begins_with("--og-shot=") or a.begins_with("--fx-shots=") or a.begins_with("--play-shots=") \
				or a == "--autotest":
			demo = true
	_demo = demo
	save = preload("res://scripts/save_data.gd").new("user://save_demo.json" if demo else "user://save.json",
			Crazy.enabled and not demo)
	if demo:   # test runs start with no progress
		save.stars = {}
		save.bank = 0.0
		save.upgrades = {}
		save.best_floor = 0
		save.next_floor = 0
		save.controls_day = ""
	player_name = save.last_name
	if Crazy.enabled and crazy and crazy.username != "":
		player_name = crazy.username
	char_idx = _playable()
	for c in GameConfig.CHARACTERS:
		_char_scenes.append(load(c["file"]))
	if not demo:
		await _warm_up()
	enter_start()   # one click (Start) from the game
	for arg in args:
		if arg.begins_with("--ui-shots="):
			_run_ui_shots(arg.substr(11))
			return
		if arg.begins_with("--floor-shots="):
			_run_floor_shots(arg.substr(14))
			return
		if arg.begins_with("--stick-shots="):
			_run_stick_shots(arg.substr(14))
			return
		if arg.begins_with("--og-shot="):
			_run_og_shot(arg.substr(10))
			return
		if arg.begins_with("--fx-shots="):
			_run_fx_shots(arg.substr(11))
			return
		if arg.begins_with("--play-shots="):
			_run_play_shots(arg.substr(13))
			return
	if autotest:
		_run_autotest()


# ------------------------------------------------------------------ setup
func _setup_window() -> void:
	## 1280x720 logical; on Retina/HiDPI make the window 1280 *points* wide instead of 1280 physical pixels.
	# the window's title (on the web the page's) in the game's language; deferred: the engine sets the project's
	# name after the main scene's _ready
	DisplayServer.window_set_title.call_deferred(Lang.t("Енергетична криза"))
	var win := get_window()
	if OS.has_feature("mobile") or OS.get_cmdline_args().has("--resolution") or win.size.y > win.size.x:
		return   # phones / an explicit size / a portrait window: keep it as it is (layout.gd adapts to it)
	var scale := DisplayServer.screen_get_scale()
	var want := Vector2i(Vector2(GameConfig.WINDOW_SIZE) * maxf(scale, 1.0))
	var usable := DisplayServer.screen_get_usable_rect().size
	if usable.x > 0:
		want = want.min(Vector2i(Vector2(usable) * 0.95))
	if win.mode == Window.MODE_WINDOWED and win.size.x < want.x:
		win.size = want
		win.move_to_center()


func _on_layout_changed(frame: Rect2) -> void:
	## Window resized / rotated: the HUD, the camera and the noise effect follow the game frame.
	hud.set_touch_keys(screen_layout.touch_hints)
	hud.pad = screen_layout.pad
	rig.frame = frame
	if state in [State.START, State.RESULT]:
		rig.zoom = _menu_zoom()   # turned between portrait and landscape on a menu screen
	hud.set_frame(frame, screen_layout.hud_scale, screen_layout.mode, screen_layout.unit, screen_layout.area,
			screen_layout.screen)
	rig.screen = screen_layout.screen
	rig.snap()
	fx.set_frame(frame)


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_SPACE, KEY_E], "confirm": [KEY_ENTER, KEY_KP_ENTER],
		"restart": [KEY_R], "back": [KEY_Q, KEY_BACKSPACE] if Crazy.enabled else [KEY_ESCAPE],   # Esc leaves CrazyGames' fullscreen
		"zoom_in": [KEY_EQUAL, KEY_KP_ADD], "zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
		"music": [KEY_M],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k   # physical keys: works with the Ukrainian layout too
			InputMap.action_add_event(action, ev)


func _setup_world() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("3e5a66")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.94)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_hdr_threshold = 0.9
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		_compat_lighting()


func _compat_lighting() -> void:
	## Browsers (and old GPUs) use the Compatibility renderer: it has no HDR, so the glow lifts the whole picture
	## to white and the sun comes out several times brighter than in Forward+. Settings that look like the desktop.
	var c: Dictionary = GameConfig.COMPAT_LIGHTING
	env.glow_enabled = c["glow"]
	env.ssao_enabled = false
	env.background_color = Color(c["background"])
	env.ambient_light_energy = c["ambient"]
	sun.light_energy = c["sun"]
	_sun_energy = c["sun"]
	_ambient_energy = c["ambient"]


func _bl(a: Array) -> Vector3:
	## Blender (x, y, z-up) -> Godot (x, y-up, -y)
	var z := float(a[2]) if a.size() > 2 else 0.0
	return Vector3(float(a[0]), z, -float(a[1]))


# ------------------------------------------------------------------ apartments
## Every floor has its apartment (GameConfig.FLOORS[i].model -> floor<model>.glb + floor<model>_layout.json).
## An apartment is built the first time it is needed (model, walls / furniture colliders, appliances, lift display)
## and kept: while another one is on screen it is just out of the scene tree.
func _use_apartment(fidx: int) -> void:
	var row: Dictionary = GameConfig.floor_cfg(fidx)
	var m: String = row.get("model", "1")
	if m != model:
		if apartments.has(model):
			for a in apps:
				a.set_on(false, 0.0)
			remove_child(apartments[model]["root"])
		if apartments.has(m):
			add_child(apartments[m]["root"])
		else:
			apartments[m] = _build_apartment(m)
		var ap: Dictionary = apartments[m]
		model = m
		level = ap["level"]
		layout = ap["layout"]
		apps = []
		apps.assign(ap["apps"])
		lift_label = ap["lift"]
		spawn_pos = ap["spawn"]
		lamps = ap["lamps"]
		rig.bounds = ap["bounds"]
		rig.scene_box = ap["box"]
	_recolor(apartments[m], row.get("recolor", false))


func _build_apartment(m: String) -> Dictionary:
	var root := Node3D.new()
	root.name = "Apartment" + m
	add_child(root)   # in the tree first: colliders and markers are placed in global coordinates
	var lvl := (load(GameConfig.APARTMENT_DIR + "floor%s.glb" % m) as PackedScene).instantiate() as Node3D
	root.add_child(lvl)
	var lay: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameConfig.APARTMENT_DIR + "floor%s_layout.json" % m))
	var ap := {"root": root, "level": lvl, "layout": lay, "boxes": []}
	_build_walls(ap)
	_build_furniture_colliders(ap, lvl)
	ap["apps"] = _collect_appliances(ap)
	ap["lift"] = _setup_lift_display(ap)
	ap["lamps"] = []
	for l in lvl.find_children("*", "OmniLight3D", true, false):
		var ol := l as OmniLight3D
		ol.light_energy = 0.9 * (GameConfig.COMPAT_LIGHTING["lamps"] if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)
		ol.omni_range = 2.4
		ol.shadow_enabled = false
		ap["lamps"].append([ol, ol.light_energy])
	var size: Array = lay.get("size", [11, 8])
	var w := float(size[0])
	var h := float(size[1])
	ap["size"] = Vector2(w, h)
	ap["bounds"] = AABB(Vector3(0.6, 0, -(h - 0.6)), Vector3(w - 1.2, 0, h - 1.2))   # camera stays over the floor
	var wall := float(lay.get("wall_height", 2.2))
	ap["box"] = AABB(Vector3(0, -0.3, -h), Vector3(w, wall + 0.3, h))   # the whole apartment (floor slab .. walls)
	ap["spawn"] = _bl(lay["spawn"])
	# room materials for the second floor's colours (RECOLOR): wall_<room>, floor_<room>
	var mats := {}
	for mi in lvl.find_children("*", "MeshInstance3D", true, false):
		var mesh := (mi as MeshInstance3D).mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i) as BaseMaterial3D
			if mat and not mats.has(mat.resource_name) and (mat.resource_name.begins_with("wall_") or mat.resource_name.begins_with("floor_")):
				mats[mat.resource_name] = {"mat": mat, "color": mat.albedo_color}
	ap["mats"] = mats
	# floor of each room for the footsteps: tiles (kitchen, bath, floor_tile_* textures) or wooden planks
	var surfaces := {}
	for r in lay["rooms"]:
		var e: Dictionary = mats.get("floor_" + String(r["id"]), {})
		var tex: Texture2D = (e["mat"] as BaseMaterial3D).albedo_texture if e.has("mat") else null
		var path := tex.resource_path.get_file() if tex else ""
		surfaces[r["id"]] = "tile" if path.contains("tile") or path.contains("kitchen") or path.contains("bath") else "wood"
	ap["surfaces"] = surfaces
	if not OS.get_cmdline_user_args().has("--no-merge") and not _og_shot():
		_merge_static(lvl)
	return ap


func _surface_at(p: Vector3) -> String:
	var x := p.x
	var y := -p.z
	for r in layout["rooms"]:
		var rc: Array = r["rect"]
		if x >= float(rc[0]) and x <= float(rc[2]) and y >= float(rc[1]) and y <= float(rc[3]):
			return apartments[model]["surfaces"].get(r["id"], "wood")
	return "wood"


func _on_step(i: int) -> void:
	var cfg: Dictionary = GameConfig.CHARACTERS[char_idx]
	var gains: Array = cfg.get("step_gains", [])
	var surface := _surface_at(player.global_position)
	steps.play(cfg.get("steps", "barefoot"), surface, gains[i] if i < gains.size() else 0.0)
	if autotest:
		_step_count[surface] = int(_step_count.get(surface, 0)) + 1


func _recolor(ap: Dictionary, alt: bool) -> void:
	var pal: Dictionary = GameConfig.RECOLOR.get(model, {}) if alt else {}
	for n in ap["mats"]:
		var e: Dictionary = ap["mats"][n]
		(e["mat"] as BaseMaterial3D).albedo_color = Color(pal[n]) if pal.has(n) else e["color"]


func _add_box(ap: Dictionary, center: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.position = center
	(ap["root"] as Node3D).add_child(body)
	ap["boxes"].append(AABB(center - size / 2.0, size))


func _build_walls(ap: Dictionary) -> void:
	# every room edge becomes a wall line (perimeter included, so the player can't walk off the floor)
	var lay: Dictionary = ap["layout"]
	var lines := {}
	for r in lay["rooms"]:
		var x0: float = r["rect"][0]
		var y0: float = r["rect"][1]
		var x1: float = r["rect"][2]
		var y1: float = r["rect"][3]
		for e in [["y", y0, x0, x1], ["y", y1, x0, x1], ["x", x0, y0, y1], ["x", x1, y0, y1]]:
			var key := "%s:%.2f" % [e[0], e[1]]
			if not lines.has(key):
				lines[key] = {"axis": e[0], "at": e[1], "spans": []}
			lines[key]["spans"].append(Vector2(e[2], e[3]))
	for key in lines:
		var ln: Dictionary = lines[key]
		var spans: Array = ln["spans"]
		spans.sort_custom(func(a, b): return a.x < b.x)
		var merged: Array[Vector2] = []
		for s in spans:
			if merged.size() > 0 and s.x <= merged[-1].y + 0.001:
				var last := merged[-1]
				last.y = maxf(last.y, s.y)
				merged[-1] = last
			else:
				merged.append(s)
		var gaps: Array[Vector2] = []
		for d in lay["doors"]:
			if d["axis"] == ln["axis"] and absf(float(d["at"]) - float(ln["at"])) < 0.01:
				gaps.append(Vector2(float(d["centre"]) - float(d["width"]) / 2.0, float(d["centre"]) + float(d["width"]) / 2.0))
		for m in merged:
			var pieces: Array[Vector2] = [m]
			for g in gaps:
				var nxt: Array[Vector2] = []
				for p in pieces:
					if g.y <= p.x or g.x >= p.y:
						nxt.append(p)
					else:
						if g.x > p.x:
							nxt.append(Vector2(p.x, g.x))
						if g.y < p.y:
							nxt.append(Vector2(g.y, p.y))
				pieces = nxt
			for p in pieces:
				var mid := (p.x + p.y) / 2.0
				var length := p.y - p.x + 0.1
				var at := float(ln["at"])
				if ln["axis"] == "y":
					_add_box(ap, Vector3(mid, 0.75, -at), Vector3(length, 1.5, 0.2))
				else:
					_add_box(ap, Vector3(at, 0.75, -mid), Vector3(0.2, 1.5, length))
	# floor
	var size: Array = lay.get("size", [11, 8])
	_add_box(ap, Vector3(float(size[0]) / 2.0, -0.1, -float(size[1]) / 2.0), Vector3(float(size[0]) + 1.0, 0.2, float(size[1]) + 1.0))


func _subtree_aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b: AABB = m.global_transform * m.get_aabb()
		if first:
			box = b
			first = false
		else:
			box = box.merge(b)
	return box


func _build_furniture_colliders(ap: Dictionary, n: Node) -> void:
	for c in n.get_children():
		var nm := String(c.name)
		if nm.begins_with("FURN_") or nm.begins_with("APPL_") or nm == "LIFT":
			if nm.contains("rug") or nm.contains("window") or nm.contains("art_"):
				continue
			var box := _subtree_aabb(c)
			if box.size.y > 0.06 and box.position.y < 0.3:
				var sz := box.size
				sz.x = maxf(sz.x - 0.08, 0.1)
				sz.z = maxf(sz.z - 0.08, 0.1)
				sz.y = 1.5
				var ctr := box.get_center()
				_add_box(ap, Vector3(ctr.x, 0.75, ctr.z), sz)
		else:
			_build_furniture_colliders(ap, c)


func _setup_lift_display(ap: Dictionary) -> Label3D:
	## The model has a static number on the lift display; replace it with a label that shows the current floor.
	var mesh := (ap["level"] as Node3D).find_child("floor_number", true, false) as MeshInstance3D
	if mesh == null:
		return null
	var box: AABB = mesh.global_transform * mesh.get_aabb()
	mesh.visible = false
	var lb := Label3D.new()
	lb.font = load("res://assets/fonts/PixelifySansUA.ttf")
	lb.font_size = 64
	lb.pixel_size = 0.17 / 64.0
	lb.outline_size = 0
	lb.modulate = Color("ff4a3d")
	lb.double_sided = false
	(ap["root"] as Node3D).add_child(lb)
	var c := box.get_center()
	if box.size.x <= box.size.z:   # display on a wall facing +X / -X
		lb.rotation_degrees.y = 90.0
		lb.global_position = Vector3(box.end.x + 0.004, c.y, c.z)
	else:
		lb.global_position = Vector3(c.x, c.y, box.end.z + 0.004)
	lb.text = "1"
	return lb


func _warm_up() -> void:
	## A browser compiles every shader the first time it is drawn, and the game stops for a moment while it
	## does: the first time an appliance switches on (its glow, its lamp's light, the "!" marker, the floor ring,
	## the noise burst) or another character is picked. So at the start all of it is drawn once, for a few frames,
	## under a cover in the background colour, which then fades out.
	var layer := CanvasLayer.new()
	layer.layer = 98   # above the HUD and the noise, below the frame's background (layout.gd: 99)
	var cover := ColorRect.new()
	cover.color = GameConfig.BACKGROUND_COLOR
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)
	add_child(layer)
	var size: Vector2 = apartments[model]["size"]
	rig.target = null
	rig.use_bounds = false
	rig.global_position = Vector3(size.x / 2.0, 0.3, -size.y / 2.0)
	rig.zoom = (size.x + size.y) * 0.5   # the whole apartment in view
	rig._size = rig.zoom
	rig._apply_frame()
	for a in apps:
		a.set_on(true, 0.0)
	var extra: Array[Node3D] = []
	for i in _char_scenes.size():
		var inst := (_char_scenes[i] as PackedScene).instantiate() as Node3D
		add_child(inst)
		inst.position = spawn_pos + Vector3(0.8 * (i + 1), 0.0, 0.0)
		extra.append(inst)
	fx.glitch(1.0, 0.5)
	for k in 3:
		await RenderingServer.frame_post_draw
	for a in apps:   # and with the lamps off again (the objects they lit, without them)
		if a.on_node:
			a.on_node.visible = false
	await RenderingServer.frame_post_draw
	for a in apps:
		a.set_on(false, 0.0)
	for e in extra:
		e.queue_free()
	rig.target = player
	var tw := create_tween()
	tw.tween_property(cover, "modulate:a", 0.0, 0.3)
	tw.tween_callback(layer.queue_free)


func _og_shot() -> bool:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--og-shot="):
			return true   # the picture for the link preview hides the pouf: keep the furniture separate
	return false


func _merge_static(lvl: Node3D) -> void:
	## The apartment is made of 350-560 small meshes, and every one is a separate draw call (and another one in
	## the sun's shadow pass): too many for a browser. The furniture, walls and floors never change, so in each
	## room they are merged into one mesh with a surface per material (~5x fewer draw calls). The rooms stay
	## separate, so a lamp lights only its own room and the camera skips rooms out of view. The glowing parts of
	## the appliances (shown while on, blinking) and hidden parts are left as they are. The materials are the same objects, so
	## the second colouring of the apartments (_recolor) still works.
	var groups := {}   # room node -> {material instance id: [material, SurfaceTool]}
	for node in lvl.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or _switched_part(mi):
			continue
		var tris := true
		for si in mi.mesh.get_surface_count():
			tris = tris and mi.mesh.surface_get_primitive_type(si) == Mesh.PRIMITIVE_TRIANGLES
		if not tris:
			continue
		var room := _room_node(mi, lvl)
		var to_room := room.global_transform.affine_inverse() * mi.global_transform
		if not groups.has(room):
			groups[room] = {}
		var g: Dictionary = groups[room]
		for si in mi.mesh.get_surface_count():
			var mat := mi.get_active_material(si)
			var key := mat.get_instance_id() if mat else 0
			if not g.has(key):
				g[key] = [mat, SurfaceTool.new()]
			(g[key][1] as SurfaceTool).append_from(mi.mesh, si, to_room)
		mi.mesh = null   # the node stays (other nodes may hang under it), it just draws nothing
	for room in groups:
		var mesh := ArrayMesh.new()
		for key in groups[room]:
			var st: SurfaceTool = groups[room][key][1]
			st.set_material(groups[room][key][0])
			st.commit(mesh)
		var out := MeshInstance3D.new()
		out.name = "merged_static"
		out.mesh = mesh
		(room as Node3D).add_child(out)


func _switched_part(n: Node) -> bool:
	## The glowing part of an appliance (APPL_<id>/<id>_on): shown only while it is on, and it blinks.
	while n:
		var p := n.get_parent()
		if p and String(p.name).begins_with("APPL_") and String(n.name).ends_with("_on"):
			return true
		n = p
	return false


func _room_node(n: Node, lvl: Node3D) -> Node3D:
	## The room the node belongs to (FLOOR_<n>/ROOM_<id>/...); the outer walls' caps and the floor slab
	## (straight under FLOOR_<n>) go together under FLOOR_<n>.
	while n.get_parent() and n.get_parent() != lvl:
		var p := n.get_parent()
		if String(p.name).begins_with("FLOOR_"):
			return n as Node3D if String(n.name).begins_with("ROOM_") and n is Node3D else p as Node3D
		n = p
	return lvl


func _set_lift_number(n: int) -> void:
	if lift_label:
		lift_label.text = str(n)


func _collect_appliances(ap: Dictionary) -> Array[Appliance]:
	var out: Array[Appliance] = []
	var lvl: Node3D = ap["level"]
	for a in ap["layout"]["appliances"]:
		var app := Appliance.new()
		app.id = a["id"]
		app.label = a["label_uk"]
		app.power = float(a["power_w"])
		app.min_floor = int(GameConfig.APPLIANCE_UNLOCK.get(app.id, int(a["min_floor"])))
		app.never_off = bool(a["never_off"])
		app.root = lvl.find_child("APPL_" + app.id, true, false)
		app.on_node = lvl.find_child(app.id + "_on", true, false)
		app.pos = app.root.global_position if app.root else _bl(a["pos"])
		app.interact = _bl(a["interact_point"])
		var box := _subtree_aabb(app.root) if app.root else AABB(app.pos, Vector3.ONE)
		app.top_y = box.end.y + 0.45
		app.box = box
		app.pos = Vector3(box.get_center().x, 0.0, box.get_center().z)
		app.setup_markers(ap["root"])
		out.append(app)
	return out


# ------------------------------------------------------------------ states
func enter_start() -> void:
	## The start screen (Figma "Start game"; a player who has passed floors before: "Start game second", with the
	## floor to continue from and "Restart game"). The child stands in the living room, the panel at the left.
	state = State.START
	if crazy:
		crazy.gameplay_stop()
	_use_apartment(0)
	_set_lift_number(1)
	_reset_appliances()
	_set_blackout(false)
	player.setup(GameConfig.CHARACTERS[char_idx])
	player.input_enabled = false
	player.position = GameConfig.SELECT_POS
	player.face_camera()
	rig.zoom = _menu_zoom()
	rig.use_bounds = false
	rig.height_offset = GameConfig.SELECT_HEIGHT
	rig.snap()
	hud.show_start(_continue_floor() + 1)
	music.power_up()
	music.calm(0.8)


func _playable() -> int:
	## This version's one character (GameConfig.PLAYABLE); the others stay in CHARACTERS for later.
	for i in GameConfig.CHARACTERS.size():
		if GameConfig.CHARACTERS[i]["id"] == GameConfig.PLAYABLE:
			return i
	return 0


func _new_game(idx: int) -> void:
	## Start / Restart game: a run from floor idx + 1.
	total_stars = 0
	run_passed_wh = 0.0
	start_floor(idx)


func _continue_floor() -> int:
	## Floor (index) a player coming back continues from: the one they reached (a new player: floor 1).
	return save.next_floor


func _controls_due() -> bool:
	## The controls are shown when a game starts until the first switch-off: for a new player (floor 1) and
	## again on the first game of every new day; once done, not again that day.
	return save.controls_day != Time.get_date_string_from_system()


func _player() -> String:
	return player_name if player_name != "" else "Player"


func start_floor(idx: int) -> void:
	state = State.BUSY
	floor_idx = idx
	save.set_next_floor(idx)    # coming back later: this floor
	_controls = _controls_due()
	if idx == 0:
		run_passed_wh = 0.0
	await hud.fade_to(1.0, 0.3)
	_use_apartment(idx)   # this floor's apartment, while the screen is dark
	_route_table()        # (routes between its appliances: for the last seconds of the round)
	_set_lift_number(idx + 1)
	_reset_appliances()
	_set_blackout(false)
	player.position = spawn_pos
	player.velocity = Vector3.ZERO
	player.face_camera()
	player.play("idle")
	rig.zoom = GameConfig.CAMERA_ZOOM
	rig.use_bounds = true
	rig.height_offset = 0.5
	rig.snap()
	t = 0.0
	consumed_wh = 0.0
	fridge_wh = 0.0
	potential_wh = 0.0
	potential_rate_w = 0.0
	overload_t = 0.0
	spawned = 0
	switched = 0
	next_spawn = GameConfig.FIRST_SPAWN
	countdown = 3.0
	_plug_t = 0.0
	player.speed = float(GameConfig.CHARACTERS[char_idx]["speed"]) * (1.0 + GameConfig.UPGRADE_SPEED * save.level("speed"))
	hud.show_play(idx + 1)
	_update_hud()
	hud.big("3")
	music.power_up()
	music.calm(1.0)
	await hud.fade_to(0.0, 0.3)
	state = State.COUNTDOWN
	if crazy:
		crazy.gameplay_start()


func _reset_appliances() -> void:
	for a in apps:
		a.set_on(a.never_off, 0.0)


func _set_blackout(on: bool) -> void:
	_flick_left = 0.0
	_set_lights(1.0)
	sun.light_energy = 0.05 if on else _sun_energy
	env.ambient_light_energy = 0.12 if on else _ambient_energy


func _set_lights(k: float) -> void:
	## Daylight and the lamps at share k (1 = normal): the flicker near overload.
	sun.light_energy = _sun_energy * lerpf(1.0, k, 0.6)
	env.ambient_light_energy = _ambient_energy * lerpf(1.0, k, 0.6)
	for l in lamps:
		(l[0] as OmniLight3D).light_energy = float(l[1]) * k


func _update_flicker(delta: float, frac: float) -> void:
	## Near the grid's limit the lights flicker now and then, more and more often; overloaded, they stutter.
	var f := clampf((frac - GameConfig.FLICKER_FROM) / (1.0 - GameConfig.FLICKER_FROM), 0.0, 1.0)
	if frac > 1.0:
		f = 2.0
	var was := _flick_left > 0.0
	_flick_left = maxf(_flick_left - delta, 0.0)
	if _flick_left <= 0.0 and f > 0.0 and rng.randf() < f * GameConfig.FLICKER_RATE * delta:
		_flick_left = rng.randf_range(0.04, 0.13)
		_flick_dim = rng.randf_range(0.25, 0.65)
		if frac > 1.0:
			sfx.play("spark")
	if _flick_left > 0.0 or was:
		_set_lights(_flick_dim if _flick_left > 0.0 else 1.0)


func _cfg() -> Dictionary:
	return GameConfig.floor_cfg(floor_idx)


func _grace() -> float:
	## Seconds of overload before the fuses blow: the floor's own + the stronger fuses bought.
	return float(_cfg().get("grace", GameConfig.OVERLOAD_GRACE)) + GameConfig.FUSE_EXTRA * save.level("fuse")


func _process(delta: float) -> void:
	for a in apps:
		a.update(delta, Time.get_ticks_msec() / 1000.0)
	match state:
		State.COUNTDOWN:   # 3, 2, 1, Start (Figma "Start"); then the controls if a game has just started
			var before := int(ceil(countdown))
			countdown -= delta
			var now := int(ceil(countdown))
			if countdown <= 0.0:
				state = State.PLAY
				player.input_enabled = true
				hud.big("Start")
				sfx.play("go")
				get_tree().create_timer(0.8).timeout.connect(_clear_go)
			elif now != before or countdown > 2.99:
				if now != before:
					sfx.play("tick")
				hud.big(str(now))
		State.PLAY:
			_play_tick(delta)


func _clear_go() -> void:
	## "Start" goes; a game that has just started shows its controls now (Figma "Control").
	if state == State.PLAY:
		hud.big("")
		hud.show_controls(_controls)


func _play_tick(delta: float) -> void:
	var cfg := _cfg()
	t += delta
	# spawning
	if t >= next_spawn and t < GameConfig.ROUND_TIME - GameConfig.NO_SPAWN_LAST:
		var n := 2 if rng.randf() < float(cfg["double"]) else 1
		for k in n:
			_spawn_one()
		var iv: Vector2 = cfg["interval"]
		next_spawn = t + rng.randf_range(iv.x, iv.y)
	_smart_plug(delta)
	# energy
	var load_w := 0.0
	var switch_w := 0.0
	var on_count := 0
	for a in apps:
		if a.is_on:
			load_w += a.power
			if not a.never_off:
				switch_w += a.power
				on_count += 1
	consumed_wh += switch_w * delta / 3600.0
	fridge_wh += (load_w - switch_w) * delta / 3600.0
	potential_wh += potential_rate_w * delta / 3600.0
	# overload
	var limit_kw: float = cfg["limit_kw"]
	_update_flicker(delta, load_w / 1000.0 / limit_kw)
	if load_w / 1000.0 > limit_kw:
		if overload_t == 0.0:
			hud.toast("Перевантаження!")
		overload_t += delta
		var danger := clampf(overload_t / _grace(), 0.0, 1.0)
		rig.shake(0.02 + 0.05 * danger, 0.2)   # the floor trembles, harder as the fuses near their end
		alarm_t -= delta
		if alarm_t <= 0.0:
			sfx.play("alarm")
			hud.overload(true)
			alarm_t = 0.4
		if overload_t >= _grace():
			_finish(false, "Коротке замикання! Вибило пробки.", true)
			return
	else:
		overload_t = 0.0
		alarm_t = 0.0
	# interaction prompt
	var near := _nearest_appliance()
	if near and not player.locked:
		if near.never_off:
			hud.prompt(Lang.t("%s — його не можна вимикати") % Lang.t(near.label))
		else:
			hud.prompt(Lang.t("Нажміть [color=#ffae00]%s[/color] щоб вимкнути: %s · %d Вт") % [hud.key_name("Пробіл"), Lang.t(near.label),
					int(near.power)])
	else:
		hud.prompt("")
	if _controls:
		hud.prompt("")   # the controls at the bottom say it (the space bar)
	_update_hud(load_w, on_count)
	_update_indicators()
	_update_music(load_w, on_count)
	if t >= GameConfig.ROUND_TIME:
		_end_round()


func _smart_plug(delta: float) -> void:
	## The smart plug (an upgrade): after PLUG_INTERVAL seconds of something being on it switches off the appliance
	## that has been on longest (not the one the player is switching off right now).
	var lvl: int = save.level("plug")
	if lvl <= 0:
		return
	var oldest: Appliance = null
	for a in apps:
		if a.is_on and not a.never_off and a != _switch_target and (oldest == null or a.t_on < oldest.t_on):
			oldest = a
	if oldest == null:
		return
	_plug_t += delta
	if _plug_t < float(GameConfig.PLUG_INTERVAL[mini(lvl, GameConfig.PLUG_INTERVAL.size() - 1)]):
		return
	_plug_t = 0.0
	oldest.set_on(false, t)
	switched += 1
	sfx.play("off")
	Effects.burst(self, oldest.top(), 18, 0.9, true)
	_fly_power(oldest)
	hud.toast("Розумна розетка!")


func _update_music(load_w: float, on_count: int) -> void:
	## Calm when the flat is quiet; tension with several appliances on; urgent near overload or at the end.
	var cfg := _cfg()
	const BY_COUNT := [0.0, 0.25, 0.55, 0.8, 1.0]
	var on_f: float = BY_COUNT[mini(on_count, BY_COUNT.size() - 1)]
	var load_f := clampf((load_w / 1000.0 / float(cfg["limit_kw"]) - 0.6) / 0.4, 0.0, 1.0)
	var left := GameConfig.ROUND_TIME - t
	var hurry := clampf((GameConfig.MUSIC_HURRY_TIME - left) / GameConfig.MUSIC_HURRY_TIME, 0.0, 1.0)
	music.set_state(maxf(maxf(on_f, load_f), hurry), hurry)


func _update_indicators() -> void:
	var items: Array = []
	for a in apps:
		if a.is_on and not a.never_off:
			var world := Vector3(a.pos.x, a.top_y - 0.3, a.pos.z)
			items.append({"pos": rig.cam.unproject_position(world), "label": Lang.t(a.label)})
	hud.set_indicators(items)


func _economy() -> float:
	if potential_wh <= 0.000001:
		return 1.0
	return clampf(1.0 - consumed_wh / potential_wh, 0.0, 1.0)


func _update_hud(load_w := 150.0, _on_count := 0) -> void:
	hud.update_play(load_w / 1000.0, _cfg()["limit_kw"])


func _spawn_one() -> void:
	var cfg := _cfg()
	var on_count := 0
	var cands: Array[Appliance] = []
	for a in apps:
		if a.never_off:
			continue
		if a.is_on:
			on_count += 1
		elif a.min_floor <= int(cfg["floor"]) and a != _switch_target:
			cands.append(a)
	var left := GameConfig.ROUND_TIME - t
	if left < GameConfig.LATE_SPAWN_WINDOW and state == State.PLAY:
		# near the end: only an appliance that still lets the player switch everything off in time
		# (walking the routes through the doors: big flats, long corridors)
		var busy: Array[Appliance] = []
		for a in apps:
			if a.is_on and not a.never_off:
				busy.append(a)
		var start := {}
		for a in busy + cands:
			start[a.id] = _route_len(player.global_position, a)
		var near: Array[Appliance] = []
		for c in cands:
			var lst := busy.duplicate()
			lst.append(c)
			if _clear_time(lst, start) + GameConfig.LATE_SPAWN_MARGIN <= left:
				near.append(c)
		cands = near
	if on_count >= int(cfg["max_on"]) or cands.is_empty():
		return
	var a: Appliance = cands[rng.randi() % cands.size()]
	if _controls and spawned == 0:   # a game starting: the first one switches on close by
		var best := INF
		for c in cands:
			var d := _route_len(player.global_position, c)
			if d < best:
				best = d
				a = c
	a.set_on(true, t)
	potential_rate_w += a.power
	spawned += 1
	sfx.play("beep")
	Effects.burst(self, a.top(), 10, 0.8, false)   # it jumps to life with a few sparks
	fx.glitch(GameConfig.GLITCH_STRENGTH, GameConfig.GLITCH_TIME)


func _nearest_appliance() -> Appliance:
	var best: Appliance = null
	var best_d := 99.0
	var p := player.global_position
	p.y = 0
	for a in apps:
		if not a.is_on:
			continue
		var d1 := p.distance_to(Vector3(a.interact.x, 0, a.interact.z))
		var d2 := p.distance_to(a.pos)
		if d1 < 0.9 or d2 < 1.25:
			var d := minf(d1, d2)
			if d < best_d:
				best_d = d
				best = a
	return best


func _try_interact() -> void:
	if player.locked:
		return
	var a := _nearest_appliance()
	if a == null:
		return
	if a.never_off:
		hud.toast("Холодильник не можна вимикати!")
		sfx.play("nope")
		return
	_switch_target = a
	player.do_switch(a.pos)


func _on_switch_hit() -> void:
	var a := _switch_target
	_switch_target = null
	if a and a.is_on and state == State.PLAY:
		a.set_on(false, t)
		switched += 1
		sfx.play("off")   # click + the power winding down
		Effects.burst(self, a.top(), 26, 1.1, true)
		_fly_power(a)
		if _controls:   # the first appliance switched off: the controls have done their job (for today)
			_controls = false
			hud.show_controls(false)
			save.set_controls_day(Time.get_date_string_from_system())


func _fly_power(a: Appliance) -> void:
	## The switched-off power rises from the appliance and flies into the economy label.
	var world := Vector3(a.pos.x, a.top_y - GameConfig.FLY_FROM_BELOW_TOP, a.pos.z)   # on the appliance itself
	if rig.cam.is_position_behind(world):
		return
	hud.fly_power(rig.cam.unproject_position(world), int(a.power))


func _end_round() -> void:
	var all_off := true
	for a in apps:
		if a.is_on and not a.never_off:
			all_off = false
	var econ := _economy()
	var thr: float = _cfg()["threshold"]
	if not all_off:
		_finish(false, "Не всі прилади вимкнені.")
	elif econ < thr:
		_finish(false, Lang.t("Економія %d%% — нижче за поріг %d%%.") % [roundi(econ * 100), roundi(thr * 100)])
	else:
		_finish(true, "")


func _result_camera() -> void:
	## Same framing as the menu (Figma frames 3-5): character centred, card bottom-left.
	rig.zoom = _menu_zoom()
	rig.use_bounds = false
	rig.height_offset = GameConfig.SELECT_HEIGHT


func _menu_zoom() -> float:
	return GameConfig.SELECT_ZOOM_PHONE if screen_layout.mode == "portrait" else GameConfig.SELECT_ZOOM


func _finish(win: bool, reason: String, blackout := false) -> void:
	## A floor's end: Figma "Success" (stars, energy used, savings; Next floor / Restart game) or "Fail" (the same
	## and the floor; Start = try it again / Restart game).
	state = State.RESULT
	_flick_left = 0.0
	_set_lights(1.0)
	if crazy:
		crazy.gameplay_stop()
	_last_reason = reason
	_result_camera()
	result_win = win
	player.input_enabled = false
	hud.prompt("")
	var econ := _economy()
	var thr: float = _cfg()["threshold"]
	var stars := 0
	if win:
		stars = 1
		if econ >= thr + 0.10:
			stars = 2
		if econ >= thr + 0.20 and overload_t == 0.0:
			stars = 3
		total_stars += stars
		_record_win(stars)
		if not (music.enabled and music.has_track("victory")):
			sfx.play("win")   # the victory fanfare replaces the beep jingle
		player.celebrate()
	else:
		player.despair()
	if not win and (blackout or not (music.enabled and music.has_track("defeat"))):
		sfx.play("lose")   # the sad music replaces the beep (after a short circuit both are heard)
	if blackout:
		# the fuses blow: a bang, sparks fly off everything that was on, a white flash, the view jolts, darkness
		sfx.play("bang")
		for a in apps:
			if a.is_on:
				Effects.burst(self, a.top(), 26, 2.0, true)
			a.set_on(false, t)
		rig.shake(0.3, 0.8)
		hud.flash_white()
		_set_blackout(true)
		music.power_down()
		music.defeat(1.4)   # sad music once the "tape stop" has died away
	elif win:
		music.victory()
	else:
		music.defeat()
	# score: energy saved on passed floors + this attempt (a retry replaces a failed attempt, no farming)
	var attempt_saved := maxf(potential_wh - consumed_wh, 0.0)
	var run_score := run_passed_wh + attempt_saved
	if win:
		run_passed_wh += attempt_saved
	save.submit(_player(), run_score, floor_idx + 1, GameConfig.CHARACTERS[char_idx]["id"])
	save.add_bank(attempt_saved * (1.0 if win else GameConfig.FAIL_BANK_SHARE))   # the energy bank (upgrades)
	if win and floor_idx == GameConfig.FLOORS.size() - 1 and crazy:
		crazy.happytime()   # the whole building saved
	_controls = false
	var buttons := [["Next floor" if win else "Start", true, "confirm"], ["Restart game", false, "restart"]]
	hud.show_result(win, stars, consumed_wh + fridge_wh, econ, floor_idx + 1, buttons)


func _record_win(stars: int) -> void:
	## A passed floor: its stars (best kept), the highest floor passed and the next one (the start screen continues
	## from it).
	save.next_floor = floor_idx + 1   # coming back later: the next floor
	if floor_idx < GameConfig.FLOORS.size():
		save.record_floor(floor_idx + 1, stars)
	else:
		save.best_floor = maxi(save.best_floor, floor_idx + 1)
		save.save_data()


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("music") and not event.is_echo():
		hud.toast(Lang.t("Музика: %s") % Lang.t("увімкнено" if music.toggle() else "вимкнено"))
		return
	# zoom: + / - keys or mouse wheel (during play)
	if state == State.PLAY or state == State.COUNTDOWN:
		var dz := 0.0
		if event.is_action_pressed("zoom_in", true):
			dz = -0.5
		elif event.is_action_pressed("zoom_out", true):
			dz = 0.5
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				dz = -0.25
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				dz = 0.25
		if dz != 0.0:
			rig.zoom = clampf(rig.zoom + dz, GameConfig.ZOOM_MIN, GameConfig.ZOOM_MAX)
			hud.toast(Lang.t("Масштаб: %.1f") % rig.zoom)
			return
	if event.is_echo():
		return
	match state:
		State.START:   # Start (Enter / Space / the button), Restart game (R / the button)
			if event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
				_new_game(_continue_floor())
			elif event.is_action_pressed("restart"):
				_new_game(0)
		State.PLAY:
			if event.is_action_pressed("interact") or event.is_action_pressed("confirm"):
				_try_interact()   # Space, or Enter / the touch button
			elif event.is_action_pressed("restart"):
				start_floor(floor_idx)
			elif event.is_action_pressed("back"):
				enter_start()
		State.RESULT:   # Next floor / Start (try again) (Enter, the button), Restart game (R, the button)
			if event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
				start_floor(floor_idx + 1 if result_win else floor_idx)
			elif event.is_action_pressed("restart"):
				_new_game(0)
			elif event.is_action_pressed("back"):
				enter_start()


# ------------------------------------------------------------------ autotest (headless / CI)
func _shot(name: String) -> void:
	if _auto_shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_auto_shots.path_join(name + ".png"))
	print("shot ", name)


func _run_ui_shots(dir: String) -> void:
	## The six screens of the Figma redesign (KeyLock 48:2814): start (first visit), the countdown's "Start", the
	## controls, success, fail, the start screen for a player coming back.
	_auto_shots = dir
	await get_tree().create_timer(1.0).timeout
	await _shot("ui_1_start")
	_new_game(0)
	while state != State.COUNTDOWN:
		await get_tree().process_frame
	while state == State.COUNTDOWN:
		await get_tree().process_frame
	next_spawn = 999.0
	await get_tree().create_timer(0.15).timeout
	await _shot("ui_2_countdown_start")
	await get_tree().create_timer(1.0).timeout
	await _shot("ui_3_controls")
	potential_wh = 19.0   # the mockup's numbers: 4.9 Wh used, 74 % saved
	consumed_wh = 4.9
	fridge_wh = 0.0
	t = GameConfig.ROUND_TIME
	_finish(true, "")
	await get_tree().create_timer(1.6).timeout
	await _shot("ui_4_success")
	start_floor(1)
	while state != State.PLAY:
		await get_tree().process_frame
	potential_wh = 19.0
	consumed_wh = 4.9
	fridge_wh = 0.0
	t = GameConfig.ROUND_TIME
	_finish(false, "Не всі прилади вимкнені.")
	await get_tree().create_timer(1.6).timeout
	await _shot("ui_5_fail")
	enter_start()
	await get_tree().create_timer(1.2).timeout
	await _shot("ui_6_start_second")
	get_tree().quit()


func _run_fx_shots(dir: String) -> void:
	## The effects: appliances on (halo, sparks, steam), a switch-off burst, an overload (flicker, shaking meter,
	## red flash), the fuses blowing (flash, sparks) and the darkness after.
	_auto_shots = dir
	await get_tree().create_timer(0.5).timeout
	player.setup(GameConfig.CHARACTERS[char_idx])
	start_floor(0)
	while state != State.PLAY:
		await get_tree().process_frame
	next_spawn = 999.0
	var tv: Appliance = null
	for a in apps:
		if a.id in ["tv", "floor_lamp", "kettle"]:
			a.set_on(true, t)
			potential_rate_w += a.power
		if a.id == "tv":
			tv = a
	await get_tree().create_timer(1.5).timeout
	await _shot("fx_1_on")
	player.global_position = Vector3(tv.interact.x, player.global_position.y, tv.interact.z)
	_try_interact()
	while switched == 0:
		await get_tree().process_frame
	await get_tree().create_timer(0.08).timeout
	await _shot("fx_2_off")
	await get_tree().create_timer(1.2).timeout
	for a in apps:
		if not a.never_off:
			a.set_on(true, t)
	await get_tree().create_timer(0.7).timeout
	await _shot("fx_3_overload")
	while state == State.PLAY:
		await get_tree().process_frame
	await get_tree().create_timer(0.1).timeout
	await _shot("fx_4_blow")
	await get_tree().create_timer(1.5).timeout
	await _shot("fx_5_dark")
	get_tree().quit()


func _run_floor_shots(dir: String) -> void:
	## Every floor's apartment: in play (start of the round, a few appliances on) and seen whole from above.
	_auto_shots = dir
	await get_tree().create_timer(0.5).timeout
	for f in range(_floor_from, _floor_to if _floor_to > 0 else GameConfig.FLOORS.size()):
		await start_floor(f)
		state = State.BUSY
		hud.big("")
		for a in apps:
			if a.id in ["tv", "floor_lamp", "kettle", "computer", "bed_lamp", "mirror_light", "heater", "washer"]:
				a.set_on(true, 0.0)
		player.input_enabled = false
		await get_tree().create_timer(0.8).timeout
		await _shot("floor_%02d_play" % (f + 1))
		var size: Vector2 = apartments[model]["size"]
		rig.target = null
		hud.visible = false
		rig.global_position = Vector3(size.x / 2.0 - 0.3, 0.3, -size.y / 2.0 + 0.3)
		rig.zoom = (size.x + size.y) * 0.5
		rig._size = rig.zoom
		rig._apply_frame()
		await get_tree().create_timer(0.3).timeout
		await _shot("floor_%02d_whole" % (f + 1))
		hud.visible = true
		rig.target = player
	get_tree().quit()


func _exit_tree() -> void:
	# apartments of other floors are kept out of the scene tree: free them with the game
	for m in apartments:
		var r: Node = apartments[m]["root"]
		if is_instance_valid(r) and not r.is_inside_tree():
			r.free()


func _run_og_shot(path: String) -> void:
	## Picture for the web page's link preview (src/web/og.py adds the title): the child in the living room with
	## a few appliances on (glow, "!", rings), in the right part of the frame (the left part is left for the
	## text). Saved at 1200 x 630. --shot-family: the four characters instead (the earlier covers).
	## The same for the CrazyGames covers (src/web/covers.py adds the title), with -- --fill-frame and:
	##   --shot-size=WxH   picture size (1200x630)
	##   --shot-panel=P    share of the width kept free on the left for the text (500 / 1200)
	##   --shot-top=T      share of the height kept free at the top for the title (0)
	##   --shot-zoom=Z     metres of the scene in the free part's height (3.0)
	var size := Vector2i(1200, 630)
	var panel_share := 500.0 / 1200.0
	var top_share := 0.0
	var zoom := 3.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-size="):
			var wh := a.substr(12).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--shot-panel="):
			panel_share = float(a.substr(13))
		elif a.begins_with("--shot-top="):
			top_share = float(a.substr(11))
		elif a.begins_with("--shot-zoom="):
			zoom = float(a.substr(12))
	get_window().size = size
	await get_tree().create_timer(0.5).timeout
	hud.hide_sheet()
	hud.visible = false
	var family := OS.get_cmdline_user_args().has("--shot-family")
	var pouf: Node = apartments["1"]["root"].find_child("pouf*", true, false)
	if pouf is Node3D and family:
		(pouf as Node3D).visible = false   # it would hide the father's feet
	var right := Vector3(1, 0, -1).normalized()   # screen-horizontal in the isometric view
	var front := Vector3(1, 0, 1).normalized()    # towards the camera
	# [character, metres to the right, metres to the front]: a small group, the dog in front; or the child
	var group := [[2, -0.8, -0.25], [0, 0.0, -0.45], [3, 0.75, -0.2], [1, 0.3, 0.45]] if family \
			else [[_playable(), 0.0, 0.0]]
	if not family:   # what the game is about: appliances on round the child
		for a in apps:
			if a.id in ["tv", "floor_lamp", "heater"]:
				a.set_on(true, 0.0)
	for i in group.size():
		var g: Array = group[i]
		var p: Player = player if i == 0 else Player.new()
		if i > 0:
			add_child(p)
		p.setup(GameConfig.CHARACTERS[g[0]])
		p.input_enabled = false
		p.position = GameConfig.SELECT_POS + right * float(g[1]) + front * float(g[2])
		p.face_camera()
	rig.target = null
	rig.zoom = zoom
	rig.use_bounds = false
	rig.global_position = GameConfig.SELECT_POS + Vector3(0, GameConfig.SELECT_HEIGHT, 0)
	await get_tree().create_timer(0.3).timeout
	var f: Rect2 = screen_layout.frame
	var panel: float = panel_share * screen_layout.screen.x
	var top: float = top_share * screen_layout.screen.y
	rig.view = Rect2(f.position + Vector2(panel, top), f.size - Vector2(panel, top))
	rig._size = rig.zoom
	rig._apply_frame()
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("og shot ", path, " screen ", screen_layout.screen, " frame ", f, " panel ", panel)
	get_tree().quit()


func _run_stick_shots(dir: String) -> void:
	## The touch stick (run with --touch): the start screen, then play: pushes of different strength, the
	## player's speed for each, a screenshot with the stick held.
	_auto_shots = dir
	await get_tree().create_timer(0.3).timeout   # the layout is made a frame after start
	var pad: Object = screen_layout.pad
	if pad.buttons.is_empty():
		print("stick: no touch controls (run with --touch)")
		get_tree().quit()
		return
	var c: Vector2 = pad.buttons["stick"][0]
	var travel: float = pad._travel()
	var to_window := get_viewport().get_final_transform()   # events come in window pixels
	var touch := func(pressed: bool, p: Vector2) -> void:
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = to_window * p
		ev.pressed = pressed
		Input.parse_input_event(ev)
	var drag := func(p: Vector2) -> void:
		var ev := InputEventScreenDrag.new()
		ev.index = 0
		ev.position = to_window * p
		Input.parse_input_event(ev)
	await get_tree().create_timer(0.8).timeout
	await _shot("stick_1_start")
	await start_floor(0)
	state = State.PLAY
	hud.big("")
	player.input_enabled = true
	next_spawn = 999.0
	for share in [0.1, 0.3, 0.5, 0.75, 1.0]:
		player.position = spawn_pos
		var push := Vector2(-0.6, -0.8)
		touch.call(true, c)
		drag.call(c + push * travel * share)
		await get_tree().create_timer(0.5).timeout
		print("stick: push %.2f -> speed %.2f of %.2f" % [share, player.velocity.length(), player.speed])
		if share == 0.75:
			await _shot("stick_2_play_held")
		touch.call(false, c + push * travel * share)
		await get_tree().create_timer(0.2).timeout
	print("stick: released -> speed %.2f" % player.velocity.length())
	await _shot("stick_3_released")
	get_tree().quit()


func _run_play_shots(dir: String) -> void:
	## Pictures of a game in progress (for store pages; on a phone: run with --touch in a phone-sized window, either
	## orientation): a floor in play with appliances on (halo, "!", rings), the load meter nearing the limit, the
	## child running with the stick held; then a switch-off (sparks, the power flying to the meter).
	## --shot-floor=N picks the floor (default 1).
	_auto_shots = dir
	var floor_i := 0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot-floor="):
			floor_i = maxi(int(a.substr(13)) - 1, 0)
	await get_tree().create_timer(0.5).timeout
	start_floor(floor_i)
	while state != State.PLAY:
		await get_tree().process_frame
	next_spawn = 999.0
	# appliances on, nearest to the player first, while the load stays under the flicker (meter orange, ~75 %)
	var limit_w: float = float(_cfg()["limit_kw"]) * 1000.0
	var load_w := 0.0
	for a in apps:
		if a.is_on:
			load_w += a.power   # the fridge
	var near := player.global_position
	var list := apps.filter(func(a: Appliance) -> bool: return not a.is_on and not a.never_off)
	list.sort_custom(func(a: Appliance, b: Appliance) -> bool: return a.pos.distance_to(near) < b.pos.distance_to(near))
	var on: Array[Appliance] = []
	for a: Appliance in list:
		if on.size() >= 4:
			break
		if load_w + a.power <= limit_w * GameConfig.FLICKER_FROM * 0.97:
			a.set_on(true, t)
			potential_rate_w += a.power
			load_w += a.power
			on.append(a)
	print("play shots: floor %d, on %s, load %.0f of %.0f W" % [floor_i + 1, on.map(func(a): return a.id), load_w, limit_w])
	if on.is_empty():
		get_tree().quit()
		return
	await get_tree().create_timer(1.2).timeout
	# the biggest one on is the one switched off later; first the child runs from it towards the camera (down the
	# screen, so it faces us) with the stick held
	var target: Appliance = on[0]
	for a: Appliance in on:
		if a.power > target.power:
			target = a
	player.global_position = Vector3(target.interact.x, player.global_position.y, target.interact.z)
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(1.0).timeout
	var dir2 := Vector2(0.45, 0.89)
	var pad: Object = screen_layout.pad
	var to_window := get_viewport().get_final_transform()
	if pad and pad.visible:
		var c: Vector2 = pad.buttons["stick"][0]
		var travel: float = pad._travel()
		var ev := InputEventScreenTouch.new()
		ev.index = 0
		ev.position = to_window * c
		ev.pressed = true
		Input.parse_input_event(ev)
		var dr := InputEventScreenDrag.new()
		dr.index = 0
		dr.position = to_window * (c + dir2 * travel * 0.9)
		Input.parse_input_event(dr)
		await get_tree().create_timer(0.4).timeout
		await _shot("play_1_run")
		ev = InputEventScreenTouch.new()
		ev.index = 0
		ev.position = to_window * c
		ev.pressed = false
		Input.parse_input_event(ev)
	else:
		await _shot("play_1_run")
	# switch it off: sparks and the power flying to the meter
	player.global_position = Vector3(target.interact.x, player.global_position.y, target.interact.z)
	player.velocity = Vector3.ZERO
	await get_tree().create_timer(0.9).timeout
	_try_interact()
	while switched == 0:
		await get_tree().process_frame
	await get_tree().create_timer(0.12).timeout
	await _shot("play_2_switch")
	await get_tree().create_timer(0.35).timeout
	await _shot("play_3_fly")
	# next to another one that is on: the prompt names the key (on a phone: the button's picture)
	for a: Appliance in on:
		if a != target and a.is_on:
			player.global_position = Vector3(a.interact.x, player.global_position.y, a.interact.z)
			break
	await get_tree().create_timer(1.0).timeout
	await _shot("play_4_prompt")
	get_tree().quit()


func _result_music_info() -> String:
	var parts: Array[String] = []
	for k in music.result_players:
		var rp: AudioStreamPlayer = music.result_players[k]
		parts.append("%s(playing=%s loop=%s from %.2f)" % [k, rp.playing, rp.stream.loop if rp.stream else false,
			rp.stream.loop_offset if rp.stream else 0.0])
	return ", ".join(parts)


const NAV_CELL := 0.1       # route grid, m (late switch-ons and the autotest bot)
const NAV_RADIUS := 0.25   # routes keep this far from walls and furniture


func _nav_grid() -> AStarGrid2D:
	## Walkable grid of the apartment on screen, from the same boxes the player collides with.
	var ap: Dictionary = apartments[model]
	if ap.has("grid"):
		return ap["grid"]
	var size: Vector2 = ap["size"]
	var g := AStarGrid2D.new()
	g.region = Rect2i(0, 0, ceili(size.x / NAV_CELL), ceili(size.y / NAV_CELL))
	g.cell_size = Vector2(NAV_CELL, NAV_CELL)
	g.offset = Vector2(NAV_CELL, NAV_CELL) / 2.0
	g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	g.update()
	for b in ap["boxes"]:
		var box: AABB = b
		if box.position.y < -0.05:
			continue   # the floor
		# Godot (x, -z) = Blender (x, y): the grid's y axis points north
		var x0 := floori((box.position.x - NAV_RADIUS) / NAV_CELL)
		var x1 := ceili((box.end.x + NAV_RADIUS) / NAV_CELL)
		var y0 := floori((-box.end.z - NAV_RADIUS) / NAV_CELL)
		var y1 := ceili((-box.position.z + NAV_RADIUS) / NAV_CELL)
		g.fill_solid_region(Rect2i(x0, y0, x1 - x0, y1 - y0).intersection(g.region), true)
	ap["grid"] = g
	return g


func _nav_cell(g: AStarGrid2D, p: Vector3, near: float) -> Vector2i:
	## Free grid cell closest to p (within `near` m), or (-1, -1).
	var c := Vector2i(floori(p.x / NAV_CELL), floori(-p.z / NAV_CELL))
	if g.is_in_boundsv(c) and not g.is_point_solid(c):
		return c
	var best := Vector2i(-1, -1)
	var best_d := INF
	var r := ceili(near / NAV_CELL)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := c + Vector2i(dx, dy)
			if g.is_in_boundsv(q) and not g.is_point_solid(q):
				var d := Vector2(dx, dy).length()
				if d < best_d:
					best_d = d
					best = q
	return best if best_d * NAV_CELL <= near else Vector2i(-1, -1)


func _route(from: Vector3, a: Appliance) -> PackedVector2Array:
	## Shortest walk (grid points, Blender x / y) from `from` to a spot where `a` can be switched off
	## (_nearest_appliance: near its interaction point or near the appliance). Empty if there is none.
	var g := _nav_grid()
	var c0 := _nav_cell(g, from, 1.0)
	var c1 := _nav_cell(g, a.interact, 0.85)
	if c1.x < 0:
		c1 = _nav_cell(g, a.pos, 1.2)
	if c0.x < 0 or c1.x < 0:
		return PackedVector2Array()
	return g.get_point_path(c0, c1)


func _route_len(from: Vector3, a: Appliance) -> float:
	var p := _route(from, a)
	return _path_len(p) if not p.is_empty() else INF


func _route_table() -> Dictionary:
	## Route lengths between the appliances of the apartment on screen (id -> id -> m), worked out once.
	var ap: Dictionary = apartments[model]
	if ap.has("routes"):
		return ap["routes"]
	var g := _nav_grid()
	var cells: Array[Vector2i] = []
	for a in apps:
		var c := _nav_cell(g, a.interact, 0.85)
		if c.x < 0:
			c = _nav_cell(g, a.pos, 1.2)
		cells.append(c)
	var tab := {}
	for a in apps:
		tab[a.id] = {a.id: 0.0}
	for i in apps.size():
		for j in range(i + 1, apps.size()):
			var d := INF
			if cells[i].x >= 0 and cells[j].x >= 0:
				var p := g.get_point_path(cells[i], cells[j])
				if not p.is_empty():
					d = _path_len(p)
			tab[apps[i].id][apps[j].id] = d
			tab[apps[j].id][apps[i].id] = d
	ap["routes"] = tab
	return tab


func _clear_time(list: Array[Appliance], start: Dictionary) -> float:
	## Seconds the player needs to switch all of `list` off, always going to the nearest one next, at an easy pace
	## (start: route from the player to each of them).
	var tab := _route_table()
	var todo := list.duplicate()
	var total := 0.0
	var cur: Appliance = null
	while not todo.is_empty():
		var best_i := 0
		var best_d := INF
		for i in todo.size():
			var d: float = start[todo[i].id] if cur == null else tab[cur.id][todo[i].id]
			if d < best_d:
				best_d = d
				best_i = i
		if best_d == INF:
			return INF
		total += best_d / (player.speed * GameConfig.LATE_SPAWN_PACE) + GameConfig.LATE_SPAWN_REACT + player.switch_time
		cur = todo[best_i]
		todo.remove_at(best_i)
	return total


var _stuck_t := 0.0
var _stuck_d := INF
var stuck_count := 0


func _bot_walk_physical(path: Array[Vector3]) -> void:
	## --physical: steer the player along the route and let it collide; report places where it gets stuck.
	var reach := maxf(0.12, player.speed * get_process_delta_time() * 1.2)   # a step can pass several grid points
	while not path.is_empty():
		var to := path[0] - player.global_position
		to.y = 0
		if to.length() < reach:
			path.remove_at(0)
			_stuck_t = 0.0
			_stuck_d = INF
			continue
		player.bot_dir = to.normalized()
		if to.length() < _stuck_d - 0.05:
			_stuck_d = to.length()
			_stuck_t = 0.0
		else:
			_stuck_t += get_process_delta_time()
			if _stuck_t > 1.5:
				stuck_count += 1
				print("  STUCK on floor %d at (%.2f, %.2f) going to (%.2f, %.2f)" % [floor_idx + 1, player.global_position.x,
					-player.global_position.z, path[0].x, -path[0].z])
				player.global_position = path[0]
				path.remove_at(0)
				_stuck_t = 0.0
				_stuck_d = INF
		return
	player.bot_dir = Vector3.ZERO


func _bot_route(a: Appliance) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var pts := _route(player.global_position, a)
	if pts.is_empty():
		print("  BOT: no route to ", a.id)
		out.append(Vector3(a.interact.x, 0, a.interact.z))
		return out
	for i in range(1, pts.size()):
		out.append(Vector3(pts[i].x, 0.0, -pts[i].y))
	return out


func _bot_pick(react: float) -> Appliance:
	## Like a player who knows the flat: the closest appliance by route; during an overload one that ends it.
	var load_w := 0.0
	for a in apps:
		if a.is_on:
			load_w += a.power
	var excess := load_w - float(_cfg()["limit_kw"]) * 1000.0
	var best: Appliance = null
	var best_d := INF
	for pass_ in 2:
		for a in apps:
			if a.is_on and not a.never_off and t - a.t_on >= react and (pass_ == 1 or excess <= 0.0 or a.power >= excess):
				var d := _route_len(player.global_position, a)
				if d < best_d:
					best_d = d
					best = a
		if best:
			break
	return best


func _overloaded() -> bool:
	var load_w := 0.0
	for a in apps:
		if a.is_on:
			load_w += a.power
	return load_w > float(_cfg()["limit_kw"]) * 1000.0


func _ends_overload(a: Appliance) -> bool:
	var load_w := 0.0
	for b in apps:
		if b.is_on:
			load_w += b.power
	return load_w - a.power <= float(_cfg()["limit_kw"]) * 1000.0


func _bot_report_routes() -> void:
	## Route lengths in this apartment: from the lift to every appliance and the mean between two appliances.
	var ap: Dictionary = apartments[model]
	if ap.has("reported"):
		return
	ap["reported"] = true
	var g := _nav_grid()
	var cells: Array[Vector2i] = []
	var bad: Array[String] = []
	for a in apps:
		var c := _nav_cell(g, a.interact, 0.85)
		if c.x < 0:
			c = _nav_cell(g, a.pos, 1.2)
		if c.x < 0:
			bad.append(a.id)
		cells.append(c)
	var start := _nav_cell(g, spawn_pos, 1.0)
	var total := 0.0
	var n := 0
	var far := 0.0
	for i in cells.size():
		if cells[i].x < 0:
			continue
		var p := g.get_point_path(start, cells[i])
		if p.is_empty():
			bad.append(apps[i].id)
			continue
		far = maxf(far, _path_len(p))
		for j in range(i + 1, cells.size()):
			if cells[j].x >= 0:
				var q := g.get_point_path(cells[i], cells[j])
				if not q.is_empty():
					total += _path_len(q)
					n += 1
	print("  apartment %s: routes between appliances %.1f m on average, farthest from the lift %.1f m, unreachable: %s" % [
		model, total / maxi(n, 1), far, bad if not bad.is_empty() else "none"])


func _path_len(p: PackedVector2Array) -> float:
	var d := 0.0
	for i in range(1, p.size()):
		d += p[i].distance_to(p[i - 1])
	return d


func _run_autotest() -> void:
	print("AUTOTEST start; appliances=", apps.size())
	await get_tree().create_timer(0.5).timeout
	await _shot("01_start")
	for ci in GameConfig.CHARACTERS.size():   # every character still loads (for later updates)
		player.setup(GameConfig.CHARACTERS[ci])
		await get_tree().process_frame
	char_idx = clampi(_bot_char, 0, GameConfig.CHARACTERS.size() - 1) if _bot_char >= 0 else _playable()
	player.setup(GameConfig.CHARACTERS[char_idx])
	Engine.time_scale = 1.0 if _auto_shots != "" or _video else 6.0
	if not _physical:
		player.collision_mask = 0   # the bot follows its route exactly (_bot_route keeps it off walls and furniture)
	var passed := 0
	var bot_target: Appliance = null
	var bot_path: Array[Vector3] = []
	for f in range(_floor_from, _floor_to if _floor_to > 0 else GameConfig.FLOORS.size()):
		start_floor(f)
		while state != State.PLAY:
			await get_tree().process_frame
		if _video:
			next_spawn = t + 0.3   # something to switch off right away
		bot_target = null
		_bot_report_routes()
		var shot_done := false
		while state == State.PLAY:
			# bot: walk (round the furniture, through the doors) to an active appliance and switch it off
			var target: Appliance = bot_target if bot_target and bot_target.is_on else null
			if target == null or (_overloaded() and not _ends_overload(target)):
				target = _bot_pick(_bot_react)
			var hold := _auto_shots != "" and f == 0 and not shot_done   # stand still for the screenshot
			if target and not player.locked and not hold:
				if target != bot_target:   # new target: route through the doors, round the furniture
					bot_target = target
					bot_path = _bot_route(target)
				if _physical:
					_bot_walk_physical(bot_path)
				var step := 0.0 if _physical else _bot_speed * get_process_delta_time()
				while step > 0.0 and not bot_path.is_empty():
					var to := bot_path[0] - player.global_position
					to.y = 0
					if to.length() <= step:
						player.global_position += to
						step -= to.length()
						bot_path.remove_at(0)
					else:
						player.global_position += to.normalized() * step
						step = 0.0
				if bot_path.is_empty():
					player.bot_dir = Vector3.ZERO
					_try_interact()
					bot_target = null
			elif target == null:
				bot_target = null
			if f == 0 and t > 57.0 and t < 57.2:
				print("  music@57s: intensity=%.2f hurry=%.2f vols=%s pitch=%.3f" % [music.intensity, music.hurry,
					music.players.map(func(p): return snappedf(p.volume_db, 0.1)), music.players[0].pitch_scale])
			if f == 1 and t > 5.0 and t < 5.2:
				print("  result music during floor 2: %s main fade=%.2f" % [_result_music_info(), music._fade])
			if not shot_done and t > 8.0 and f == 0:
				shot_done = true
				await _shot("02_play")
			await get_tree().process_frame
		var c := _cfg()
		print("FLOOR %d -> win=%s econ=%.2f (thr %.2f) spawned=%d switched=%d wh=%.2f t=%.1f | interval %s max_on %d limit %.1f double %.2f | %s" % [
			f + 1, result_win, _economy(), c["threshold"], spawned, switched, consumed_wh, t,
			c["interval"], c["max_on"], c["limit_kw"], c["double"], _last_reason])
		if result_win:
			passed += 1
		print("  music: streams=%s playing=%s intensity=%.2f vols=%s pitch=%.2f | result track=%s %s" % [
			music.players.map(func(p): return p.stream != null), music.players.map(func(p): return p.playing),
			music.intensity, music.players.map(func(p): return snappedf(p.volume_db, 0.1)), music.players[0].pitch_scale,
			music.result_track, _result_music_info()])
		if f == 0:
			await get_tree().create_timer(0.6).timeout
			await _shot("03_result")
			if _auto_shots != "":
				get_tree().quit()
				return
		if not result_win and not _all_floors:
			break
	print("PASSED %d of %d floors (bot speed %.1f m/s)" % [passed, GameConfig.FLOORS.size(), _bot_speed])
	if _physical:
		print("PHYSICAL: %s, stuck %d times, footsteps %s" % [GameConfig.CHARACTERS[char_idx]["id"], stuck_count, _step_count])
		player.bot_dir = Vector3.ZERO
	# overload test: force everything on at the last floor
	floor_idx = GameConfig.FLOORS.size() - 1
	state = State.PLAY
	t = 10.0
	for a in apps:
		if not a.never_off:
			a.set_on(true, t)
	var guard := 0
	while state == State.PLAY and guard < 2000:
		guard += 1
		await get_tree().process_frame
	print("OVERLOAD test -> state=", State.keys()[state], " win=", result_win)
	print("  right after the short circuit: result track=%s %s" % [music.result_track, _result_music_info()])
	await get_tree().create_timer(1.6).timeout
	print("  1.6 s later: result track=%s %s" % [music.result_track, _result_music_info()])
	print("AUTOTEST done")
	get_tree().quit()
