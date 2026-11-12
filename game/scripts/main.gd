extends Node3D
## Game flow: name -> character select -> countdown -> 60 s round -> result -> next floor (1..10).


enum State { NAME, SELECT, COUNTDOWN, PLAY, RESULT, COMPLETE, BUSY }

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
var sfx: Sfx
var steps   # scripts/footsteps.gd
var fx: ScreenFx
var music   # Music (scripts/music.gd); preloaded so it works before the editor refreshes its class list
var screen_layout   # scripts/layout.gd: the game frame on the background + touch controls (adapts to the window)
var sun: DirectionalLight3D
var env: Environment
var _sun_energy := 1.2       # daylight (the blackout after a short circuit dims it)
var _ambient_energy := 0.6
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
var save            # SaveData (scripts/save_data.gd): last name + leaderboard, stored in user://save.json
var player_name := ""
var run_passed_wh := 0.0   # energy saved on floors already passed in this run
var result_win := false
var _floor_sub := ""     # countdown subtitle: floor number + newly unlocked appliances
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
var _bot_char := 0           # autotest: character (--char=1..4)
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
		elif a.begins_with("--char="):
			_bot_char = int(a.substr(7)) - 1
		elif a.begins_with("--floors="):   # e.g. --floors=7-10: only these floors (balance runs)
			var r := a.substr(9).split("-")
			_floor_from = int(r[0]) - 1
			_floor_to = int(r[r.size() - 1])
	Lang.detect()   # Ukrainian in Ukraine, English elsewhere (lang.gd)
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
	hud.name_submitted.connect(_on_name_submitted)
	hud.view_changed.connect(func(r: Rect2) -> void: rig.view = r)   # the menu sheet covers part of the frame
	screen_layout = preload("res://scripts/layout.gd").new()
	add_child(screen_layout)
	screen_layout.layout_changed.connect(_on_layout_changed)
	var demo := false   # screenshot / test runs use a separate save file
	for a in args:
		if a.begins_with("--result-shots=") or a.begins_with("--select-shots=") or a.begins_with("--fail-shots=") \
				or a.begins_with("--floor-shots=") or a.begins_with("--stick-shots=") or a.begins_with("--og-shot=") \
				or a == "--autotest":
			demo = true
	save = preload("res://scripts/save_data.gd").new("user://save_demo.json" if demo else "user://save.json")
	player_name = save.last_name
	for c in GameConfig.CHARACTERS:
		_char_scenes.append(load(c["file"]))
	if not demo:
		await _warm_up()
	enter_name()
	for arg in args:
		if arg.begins_with("--select-shots="):
			_run_select_shots(arg.substr(15))
			return
		if arg.begins_with("--result-shots="):
			_run_result_shots(arg.substr(15))
			return
		if arg.begins_with("--floor-shots="):
			_run_floor_shots(arg.substr(14))
			return
		if arg.begins_with("--fail-shots="):
			_run_fail_shots(arg.substr(13))
			return
		if arg.begins_with("--stick-shots="):
			_run_stick_shots(arg.substr(14))
			return
		if arg.begins_with("--og-shot="):
			_run_og_shot(arg.substr(10))
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
	var boost: float = GameConfig.TOUCH_HUD_BOOST.get(screen_layout.mode, 1.0)
	rig.frame = frame
	if state in [State.SELECT, State.NAME, State.RESULT, State.COMPLETE]:
		rig.zoom = _menu_zoom()   # turned between portrait and landscape on a menu screen
	hud.set_frame(frame, screen_layout.hud_scale, boost, "bottom" if screen_layout.mode == "portrait" else "left")
	rig.screen = screen_layout.screen
	rig.snap()
	fx.set_frame(frame)


func _setup_input() -> void:
	var map := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_SPACE, KEY_E], "confirm": [KEY_ENTER, KEY_KP_ENTER],
		"restart": [KEY_R], "back": [KEY_ESCAPE],
		"zoom_in": [KEY_EQUAL, KEY_KP_ADD], "zoom_out": [KEY_MINUS, KEY_KP_SUBTRACT],
		"music": [KEY_M], "language": [KEY_L],
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
	var row: Dictionary = GameConfig.FLOORS[fidx]
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
		rig.bounds = ap["bounds"]
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
	for l in lvl.find_children("*", "OmniLight3D", true, false):
		var ol := l as OmniLight3D
		ol.light_energy = 0.9 * (GameConfig.COMPAT_LIGHTING["lamps"] if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 1.0)
		ol.omni_range = 2.4
		ol.shadow_enabled = false
	var size: Array = lay.get("size", [11, 8])
	var w := float(size[0])
	var h := float(size[1])
	ap["size"] = Vector2(w, h)
	ap["bounds"] = AABB(Vector3(0.6, 0, -(h - 0.6)), Vector3(w - 1.2, 0, h - 1.2))   # camera stays over the floor
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
		app.pos = Vector3(box.get_center().x, 0.0, box.get_center().z)
		app.setup_markers(ap["root"])
		out.append(app)
	return out


# ------------------------------------------------------------------ states
func enter_select() -> void:
	state = State.SELECT
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
	hud.show_select(GameConfig.CHARACTERS[char_idx])
	music.power_up()
	music.calm(0.8)


func enter_name() -> void:
	## First screen: nickname input (pre-filled with the last used name) + leaderboard.
	enter_select()
	state = State.NAME
	hud.show_name(player_name if player_name != "" else save.last_name, save.entries)


func _on_name_submitted(n: String) -> void:
	player_name = n
	save.set_last_name(n)
	sfx.play("select")
	enter_select()


func _player() -> String:
	return player_name if player_name != "" else "Гравець"


func start_floor(idx: int) -> void:
	state = State.BUSY
	floor_idx = idx
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
	hud.show_play(idx + 1, GameConfig.FLOORS.size())
	_update_hud()
	var fresh := _new_appliances(idx + 1)
	_floor_sub = Lang.t("Поверх %d з %d") % [idx + 1, GameConfig.FLOORS.size()]
	if not fresh.is_empty():
		_floor_sub += " · " + fresh
	hud.big(Lang.t("Поверх %d") % (idx + 1), fresh if fresh != "" else "Вимикай прилади, бережи енергію!")
	music.power_up()
	music.calm(1.0)
	await hud.fade_to(0.0, 0.3)
	state = State.COUNTDOWN


func _new_appliances(floor_num: int) -> String:
	## "Новий прилад: Праска · 1500 Вт" for appliances that join the game on this floor.
	var names: Array[String] = []
	for a in apps:
		if a.min_floor == floor_num and floor_num > 1 and not a.never_off:
			names.append(Lang.t("%s · %d Вт") % [Lang.t(a.label), int(a.power)])
	if names.is_empty():
		return ""
	return Lang.t("Новий прилад: " if names.size() == 1 else "Нові прилади: ") + ", ".join(names)


func _reset_appliances() -> void:
	for a in apps:
		a.set_on(a.never_off, 0.0)


func _set_blackout(on: bool) -> void:
	sun.light_energy = 0.05 if on else _sun_energy
	env.ambient_light_energy = 0.12 if on else _ambient_energy


func _cfg() -> Dictionary:
	return GameConfig.FLOORS[floor_idx]


func _process(delta: float) -> void:
	for a in apps:
		a.update(delta, Time.get_ticks_msec() / 1000.0)
	match state:
		State.COUNTDOWN:
			var before := int(ceil(countdown))
			countdown -= delta
			var now := int(ceil(countdown))
			if countdown <= 0.0:
				state = State.PLAY
				player.input_enabled = true
				hud.big("Старт!", "", hud.C_GREEN)
				sfx.play("go")
				get_tree().create_timer(0.8).timeout.connect(_clear_go)
			elif now != before or countdown > 2.99:
				if now != before:
					sfx.play("tick")
				hud.big(str(now), _floor_sub)
		State.PLAY:
			_play_tick(delta)


func _clear_go() -> void:
	if state == State.PLAY:
		hud.big("")


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
	if load_w / 1000.0 > limit_kw:
		overload_t += delta
		alarm_t -= delta
		if alarm_t <= 0.0:
			sfx.play("alarm")
			hud.overload(true)
			alarm_t = 0.4
		if overload_t >= float(cfg.get("grace", GameConfig.OVERLOAD_GRACE)):
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
	_update_hud(load_w, on_count)
	_update_indicators()
	_update_music(load_w, on_count)
	if t >= GameConfig.ROUND_TIME:
		_end_round()


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


func _update_hud(load_w := 150.0, on_count := 0) -> void:
	var cfg := _cfg()
	hud.update_play(GameConfig.ROUND_TIME - t, load_w / 1000.0, cfg["limit_kw"], consumed_wh + fridge_wh,
			_economy(), cfg["threshold"], on_count)


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
	a.set_on(true, t)
	potential_rate_w += a.power
	spawned += 1
	sfx.play("beep")
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
		sfx.play("click")
		_fly_power(a)


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
	state = State.RESULT
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
		if not (music.enabled and music.has_track("victory")):
			sfx.play("win")   # the victory fanfare replaces the beep jingle
		player.celebrate()
	else:
		player.despair()
	if not win and (blackout or not (music.enabled and music.has_track("defeat"))):
		sfx.play("lose")   # the sad music replaces the beep (after a short circuit both are heard)
	if blackout:
		for a in apps:
			a.set_on(false, t)
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
	var rank: int = save.submit(_player(), run_score, floor_idx + 1, GameConfig.CHARACTERS[char_idx]["id"])
	var lines: Array = []
	if reason != "":
		lines.append(Lang.t(reason))
	lines.append(Lang.t("Зекономлено: %.1f Вт • год") % attempt_saved)
	lines.append(Lang.t("Економія %d%%  (потрібно ≥ %d%%)") % [roundi(econ * 100), roundi(thr * 100)])
	var best: float = save.best_of(_player())
	if best > run_score + 0.05:
		lines.append(Lang.t("Рахунок гри: %.1f Вт • год  (рекорд %.1f)") % [run_score, best])
	else:
		lines.append(Lang.t("Рахунок гри: %.1f Вт • год  — новий рекорд!") % run_score if run_score > 0.0 else Lang.t("Рахунок гри: 0 Вт • год"))
	lines.append(Lang.t("Місце в рейтингу: %d") % rank)
	var last := floor_idx >= GameConfig.FLOORS.size() - 1
	var hints: Array = []
	if win:
		hints.append(["Enter", "до фіналу" if last else "щоб продовжити", true])
	else:
		hints.append(["Enter", "спробувати ще раз", true])
	hints.append(["Esc", "спочатку"])
	hud.show_result(win, "Поверх пройдено!" if win else "Поверх не пройдено!", lines, stars, hints)
	hud.show_leaderboard(save.entries, _player())


func _show_complete() -> void:
	state = State.COMPLETE
	music.victory()   # keeps playing from the last floor's result screen
	_result_camera()
	hud.show_result(true, "Будинок врятовано!",
			[Lang.t("Ви пройшли всі %d поверхів.") % GameConfig.FLOORS.size(),
			 Lang.t("Зірок зібрано: %d з %d") % [total_stars, GameConfig.FLOORS.size() * 3],
			 Lang.t("Рахунок гри: %.1f Вт • год") % run_passed_wh,
			 Lang.t("Місце в рейтингу: %d") % save.rank_of(_player())],
			clampi(roundi(3.0 * total_stars / (GameConfig.FLOORS.size() * 3.0)), 1, 3),
			[["Enter", "щоб грати знову", true], ["Esc", "спочатку"]])
	hud.show_leaderboard(save.entries, _player())


# ------------------------------------------------------------------ input
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("music") and not event.is_echo():
		hud.toast(Lang.t("Музика: %s") % Lang.t("увімкнено" if music.toggle() else "вимкнено"))
		return
	if event.is_action_pressed("language") and not event.is_echo() and state in [State.NAME, State.SELECT]:
		_switch_language()   # L in the menu (not while typing the name: the field takes the key)
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
		State.NAME:
			# the touch button (or Enter when the name field has lost focus) submits the name
			if event.is_action_pressed("confirm"):
				hud.submit_name()
		State.SELECT:
			var n := GameConfig.CHARACTERS.size()
			if event.is_action_pressed("back"):
				enter_name()
				return
			if event.is_action_pressed("move_left"):
				char_idx = (char_idx - 1 + n) % n
				_refresh_select()
			elif event.is_action_pressed("move_right"):
				char_idx = (char_idx + 1) % n
				_refresh_select()
			elif event.is_action_pressed("confirm") or event.is_action_pressed("interact"):
				total_stars = 0
				start_floor(0)
		State.PLAY:
			if event.is_action_pressed("interact") or event.is_action_pressed("confirm"):
				_try_interact()   # Space, or Enter / the touch button
			elif event.is_action_pressed("restart"):
				start_floor(floor_idx)
			elif event.is_action_pressed("back"):
				enter_select()
		State.RESULT:
			if event.is_action_pressed("confirm"):
				if result_win:
					if floor_idx >= GameConfig.FLOORS.size() - 1:
						_show_complete()
					else:
						start_floor(floor_idx + 1)
				else:
					start_floor(floor_idx)
			elif event.is_action_pressed("back"):
				enter_select()
		State.COMPLETE:
			if event.is_action_pressed("confirm"):
				total_stars = 0
				start_floor(0)
			elif event.is_action_pressed("back"):
				enter_select()


func _switch_language() -> void:
	Lang.toggle()
	DisplayServer.window_set_title(Lang.t("Енергетична криза"))
	hud.relabel()
	if state == State.SELECT:
		hud.show_select(GameConfig.CHARACTERS[char_idx])
	sfx.play("select")
	hud.toast("Мова: українська" if Lang.code == "uk" else "Language: English")


func _refresh_select() -> void:
	sfx.play("select")
	player.setup(GameConfig.CHARACTERS[char_idx])
	hud.show_select(GameConfig.CHARACTERS[char_idx])


# ------------------------------------------------------------------ autotest (headless / CI)
func _shot(name: String) -> void:
	if _auto_shots == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_auto_shots.path_join(name + ".png"))
	print("shot ", name)


func _run_select_shots(dir: String) -> void:
	## Screenshots of the menu for every character: with the menu card and clean (no UI).
	_auto_shots = dir
	state = State.SELECT
	await get_tree().create_timer(1.0).timeout
	for ci in GameConfig.CHARACTERS.size():
		char_idx = ci
		_refresh_select()
		await get_tree().create_timer(1.2).timeout
		var id: String = GameConfig.CHARACTERS[ci]["id"]
		await _shot("select_%d_%s" % [ci + 1, id])
		hud.hide_sheet()
		rig.snap()
		await get_tree().process_frame
		await _shot("select_%d_%s_clean" % [ci + 1, id])
	# the sheet sliding in (from the left; from below on a phone)
	hud.show_select(GameConfig.CHARACTERS[char_idx])
	for k in 4:
		await get_tree().create_timer(0.08).timeout
		await _shot("select_slide_%d" % (k + 1))
	# L: the other language on the spot
	await get_tree().create_timer(1.0).timeout
	_switch_language()
	await get_tree().create_timer(0.3).timeout
	await _shot("select_lang_switched")
	get_tree().quit()


func _prep_result(fidx: int, pos: Vector3, on_ids: Array) -> void:
	## Put the game into a mid-round state for a results screenshot (demo values).
	floor_idx = fidx
	_use_apartment(fidx)
	if model != "1":
		pos = spawn_pos + Vector3(1.6, 0.0, 0.0)   # in front of the lift (the demo spot is floor 1's)
	_set_lift_number(fidx + 1)
	state = State.PLAY
	_set_blackout(false)
	hud.show_play(fidx + 1, GameConfig.FLOORS.size())
	hud.big("")
	_reset_appliances()
	for a in apps:
		if on_ids.has(a.id):
			a.set_on(true, 30.0)
	player.position = pos
	player.velocity = Vector3.ZERO
	player._cur_anim = ""
	player.face_camera()
	player.play("idle")
	rig.zoom = GameConfig.CAMERA_ZOOM
	rig.use_bounds = true
	rig.height_offset = 0.5
	rig.snap()
	t = GameConfig.ROUND_TIME


func _freeze_pose(time: float, anim_name := "celebrate") -> void:
	## Hold an animation at a fixed moment (arms up / torso twisted) for screenshots.
	if player.anim and player.anim.has_animation(anim_name):
		player.anim.play(anim_name, 0.0)
		player.anim.seek(time, true)
		player.anim.speed_scale = 0.0


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


func _run_fail_shots(dir: String) -> void:
	## Every character on the "floor failed" screen, at two moments of the despair loop.
	_auto_shots = dir
	player_name = "Олексій"
	await get_tree().create_timer(0.5).timeout
	for ci in GameConfig.CHARACTERS.size():
		char_idx = ci
		player.setup(GameConfig.CHARACTERS[ci])
		_prep_result(0, Vector3(2.6, 0.0, -2.2), ["tv"])
		spawned = 6; switched = 5; consumed_wh = 3.0; potential_wh = 7.0; fridge_wh = 2.0
		_end_round()
		await get_tree().create_timer(1.0).timeout
		for k in 2:
			_freeze_pose(0.42 if k == 0 else 1.25, "fail")
			await get_tree().create_timer(0.2).timeout
			await _shot("fail_%d_%s_%d" % [ci + 1, GameConfig.CHARACTERS[ci]["id"], k + 1])
		player.anim.speed_scale = 1.0
	get_tree().quit()


func _run_og_shot(path: String) -> void:
	## Picture for the web page's link preview (src/web/og.py adds the title): the whole family in the living
	## room, in the right part of the frame (the left part is left for the text). Saved at 1200 x 630.
	get_window().size = Vector2i(1200, 630)
	await get_tree().create_timer(0.5).timeout
	hud.hide_sheet()
	hud.visible = false
	var pouf: Node = apartments["1"]["root"].find_child("pouf*", true, false)
	if pouf is Node3D:
		(pouf as Node3D).visible = false   # it would hide the father's feet
	var right := Vector3(1, 0, -1).normalized()   # screen-horizontal in the isometric view
	var front := Vector3(1, 0, 1).normalized()    # towards the camera
	# [character, metres to the right, metres to the front]: a small group, the dog in front
	var group := [[2, -0.8, -0.25], [0, 0.0, -0.45], [3, 0.75, -0.2], [1, 0.3, 0.45]]
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
	rig.zoom = 3.0
	rig.use_bounds = false
	rig.global_position = GameConfig.SELECT_POS + Vector3(0, GameConfig.SELECT_HEIGHT, 0)
	await get_tree().create_timer(0.3).timeout
	var f: Rect2 = screen_layout.frame
	var panel: float = 500.0 * screen_layout.screen.x / 1200.0
	rig.view = Rect2(f.position + Vector2(panel, 0), f.size - Vector2(panel, 0))
	rig._size = rig.zoom
	rig._apply_frame()
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("og shot ", path, " screen ", screen_layout.screen, " frame ", f, " panel ", panel)
	get_tree().quit()


func _run_stick_shots(dir: String) -> void:
	## The touch stick (run with --touch): the select screen (a push to the right = next character), then play:
	## pushes of different strength, the player's speed for each, a screenshot with the stick held.
	_auto_shots = dir
	await get_tree().create_timer(0.3).timeout   # the layout is made a frame after start
	var pad: Object = screen_layout.pad
	if not pad.visible:
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
	_on_name_submitted("Тест")
	await get_tree().create_timer(0.8).timeout
	var before := char_idx
	touch.call(true, c)
	for k in 10:   # a slow push to the right: one "next character", however many drag events
		drag.call(c + Vector2(travel * (k + 1) / 10.0, 0))
		await get_tree().process_frame
	await _shot("stick_1_select_right")
	touch.call(false, c + Vector2(travel, 0))
	print("stick: select ", before, " -> ", char_idx)
	await get_tree().create_timer(0.3).timeout
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


func _run_result_shots(dir: String) -> void:
	_auto_shots = dir
	# demo leaderboard (separate save file, the real one is untouched)
	save.entries = [
		{"name": "Ярина", "score": 48.6, "date": "1"}, {"name": "Max", "score": 41.2, "date": "2"},
		{"name": "Котик", "score": 35.9, "date": "3"}, {"name": "Дмитро", "score": 27.4, "date": "4"},
		{"name": "Ніна", "score": 19.8, "date": "5"}, {"name": "Bogdan", "score": 12.5, "date": "6"},
		{"name": "Олексій", "score": 9.1, "date": "7"}]
	player_name = "Олексій"
	enter_name()
	await get_tree().create_timer(1.0).timeout
	await _shot("name_1_input")
	_on_name_submitted("Олексій")
	char_idx = 0
	_refresh_select()
	await start_floor(6)   # floor 7: countdown announces the new appliance (heater)
	await get_tree().create_timer(0.6).timeout
	await _shot("play_0_countdown_new_appliance")
	await start_floor(0)
	var pos := Vector3(2.6, 0.0, -2.2)
	# 0) in-game HUD and the noise burst when an appliance switches on
	_prep_result(0, pos, ["tv", "floor_lamp"])
	state = State.BUSY
	t = 11.0
	spawned = 3; switched = 1; consumed_wh = 1.6; potential_wh = 3.3; fridge_wh = 0.5
	_update_hud(400.0, 2)
	_update_indicators()
	hud.prompt(Lang.t("Нажміть [color=#ffae00]%s[/color] щоб вимкнути: %s · %d Вт") % [hud.key_name("Пробіл"), Lang.t("Телевізор"), 150])
	await get_tree().create_timer(0.8).timeout
	await _shot("play_1_hud")
	fx.glitch(GameConfig.GLITCH_STRENGTH, 3.0)   # same strength as in game, held longer for the shot
	await get_tree().create_timer(0.15).timeout
	await _shot("play_2_glitch")
	hud.prompt("")
	await get_tree().create_timer(0.4).timeout
	# switching off the floor lamp: its power flies into the economy label
	for a in apps:
		if a.id == "floor_lamp":
			a.set_on(false, t)
			_fly_power(a)
	_update_indicators()
	var k := 0
	for dt in [0.15, 0.3, 0.3, 0.25]:   # rise, start of the flight, mid-flight, arrival
		await get_tree().create_timer(dt).timeout
		k += 1
		await _shot("play_3_power_fly_%d" % k)
	await get_tree().create_timer(0.6).timeout
	# 1) floor passed, 3 stars
	_prep_result(0, pos, [])
	spawned = 8; switched = 8; consumed_wh = 2.4; potential_wh = 9.1; fridge_wh = 2.5; overload_t = 0.0
	_update_hud(150.0, 0)
	_end_round()
	await get_tree().create_timer(1.2).timeout
	_freeze_pose(0.28)   # arms up
	await get_tree().create_timer(0.3).timeout
	await _shot("result_1_passed")
	player.anim.speed_scale = 1.0
	# 2) floor failed: appliances still on at the end
	_prep_result(1, pos, ["tv", "kettle"])
	spawned = 10; switched = 8; consumed_wh = 4.9; potential_wh = 9.6; fridge_wh = 2.5; overload_t = 0.0
	_update_hud(2300.0, 2)
	_end_round()
	await get_tree().create_timer(1.0).timeout
	_freeze_pose(0.42, "fail")   # torso twisted to one side
	await get_tree().create_timer(0.3).timeout
	await _shot("result_2_failed")
	player.anim.speed_scale = 1.0
	# 3) short circuit (fuses blown -> blackout)
	_prep_result(2, pos, ["kettle", "iron", "hair_dryer"])
	spawned = 9; switched = 5; consumed_wh = 6.3; potential_wh = 10.8; fridge_wh = 1.6
	t = 37.0
	_update_hud(5450.0, 3)
	_finish(false, "Коротке замикання! Вибило пробки.", true)
	await get_tree().create_timer(1.0).timeout
	_freeze_pose(1.25, "fail")   # twisted to the other side
	await get_tree().create_timer(0.3).timeout
	await _shot("result_3_short_circuit")
	player.anim.speed_scale = 1.0
	# 4) whole building completed
	_prep_result(GameConfig.FLOORS.size() - 1, pos, [])
	spawned = 26; switched = 26; consumed_wh = 7.9; potential_wh = 31.0; fridge_wh = 2.5
	_update_hud(150.0, 0)
	total_stars = 26
	player.celebrate()
	_show_complete()
	await get_tree().create_timer(1.2).timeout
	_freeze_pose(0.28)   # arms up
	await get_tree().create_timer(0.3).timeout
	await _shot("result_4_completed")
	player.anim.speed_scale = 1.0
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
	await _shot("01_select")
	for ci in GameConfig.CHARACTERS.size():
		char_idx = ci
		_refresh_select()
		await get_tree().process_frame
	char_idx = clampi(_bot_char, 0, GameConfig.CHARACTERS.size() - 1)
	_refresh_select()
	Engine.time_scale = 1.0 if _auto_shots != "" else 6.0
	if not _physical:
		player.collision_mask = 0   # the bot follows its route exactly (_bot_route keeps it off walls and furniture)
	var passed := 0
	var bot_target: Appliance = null
	var bot_path: Array[Vector3] = []
	for f in range(_floor_from, _floor_to if _floor_to > 0 else GameConfig.FLOORS.size()):
		start_floor(f)
		while state != State.PLAY:
			await get_tree().process_frame
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
			c["interval"], c["max_on"], c["limit_kw"], c["double"], _last_reason if not result_win else _new_appliances(f + 1)])
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
