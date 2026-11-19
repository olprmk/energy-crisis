class_name Appliance
extends RefCounted
## Runtime state of one appliance from the floor model (APPL_<id> node + <id>_on glow part).
## While it is on: the "!" marker above it (pops up), the ring on the floor where to stand, a warm halo round it,
## sparks crackling off it, steam from the kettle / iron / stove (effects.gd). Switched off: the halo fades out.

var id: String
var label: String
var power: float
var min_floor: int
var never_off: bool

var root: Node3D
var on_node: Node3D
var pos: Vector3          # appliance position (Godot space)
var interact: Vector3     # where the player should stand
var top_y := 1.0
var box := AABB()         # its meshes' bounds (world)

var is_on := false
var t_on := 0.0
var marker: Node3D        # Sprite3D (assets/ui/marker_exclamation.png) or Label3D fallback
var ring: MeshInstance3D
var glow: MeshInstance3D
var sparks: CPUParticles3D
var steam: CPUParticles3D
var _blink := 0.0
var _glow_a := 0.0        # the halo's strength now (fades in / out)


func setup_markers(parent: Node3D) -> void:
	var mtex := Icons.png("marker_exclamation")
	if mtex:
		var sp := Sprite3D.new()
		sp.texture = mtex
		sp.pixel_size = 0.5 / mtex.get_height()   # 0.5 m tall whatever the PNG resolution
		sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sp.no_depth_test = true
		sp.shaded = false
		sp.render_priority = 10
		marker = sp
	else:
		var lb := Label3D.new()
		lb.text = "!"
		lb.font_size = 128
		lb.outline_size = 28
		lb.pixel_size = 0.004
		lb.modulate = Color(1.0, 0.35, 0.15)
		lb.outline_modulate = Color(0.1, 0.05, 0.05)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.no_depth_test = true
		lb.render_priority = 10
		marker = lb
	marker.position = Vector3(pos.x, top_y, pos.z)
	marker.visible = false
	parent.add_child(marker)

	ring = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var rtex := Icons.png("floor_ring")
	if rtex:
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.8, 0.8)
		ring.mesh = plane
		m.albedo_texture = rtex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	else:
		var torus := TorusMesh.new()
		torus.inner_radius = 0.28
		torus.outer_radius = 0.36
		torus.rings = 32
		ring.mesh = torus
		m.albedo_color = Color(1.0, 0.55, 0.15)
	ring.material_override = m
	ring.position = Vector3(interact.x, 0.03, interact.z)
	ring.scale = Vector3(1, 0.15, 1)
	ring.visible = false
	parent.add_child(ring)

	if never_off:
		return   # the fridge: always on, nothing to point at
	var c := box.get_center() if box.has_volume() else Vector3(pos.x, 0.6, pos.z)
	var span := maxf(maxf(box.size.x, box.size.z), box.size.y) if box.has_volume() else 0.8
	glow = Effects.glow(clampf(span * 1.9, 1.1, 2.6))
	glow.position = c
	parent.add_child(glow)
	sparks = Effects.sparks(clampf(span * 0.35, 0.12, 0.4))
	sparks.position = Vector3(c.x, box.end.y if box.has_volume() else 1.0, c.z)
	parent.add_child(sparks)
	if id in Effects.STEAM_IDS:
		steam = Effects.steam()
		steam.position = Vector3(c.x, (box.end.y if box.has_volume() else 1.0) + 0.02, c.z)
		parent.add_child(steam)


## The middle of the appliance's top (sparks come from here).
func top() -> Vector3:
	if box.has_volume():
		return Vector3(box.get_center().x, box.end.y, box.get_center().z)
	return Vector3(pos.x, 1.0, pos.z)


func set_on(v: bool, now: float) -> void:
	is_on = v
	t_on = now
	_blink = 0.0
	if on_node:
		on_node.visible = v
	if marker:
		marker.visible = v and not never_off
		ring.visible = v and not never_off
	if sparks:
		sparks.emitting = v
	if steam:
		steam.emitting = v
	if glow and v:
		glow.visible = true


func update(delta: float, time: float) -> void:
	if glow:   # the halo: in quickly when it switches on, out a little slower, pulsing while on
		var want := (0.5 + 0.2 * sin(time * 5.0)) if is_on else 0.0
		_glow_a = move_toward(_glow_a, want, delta * (4.0 if is_on else 2.5))
		(glow.material_override as StandardMaterial3D).albedo_color.a = _glow_a
		glow.visible = _glow_a > 0.01
	if not is_on or never_off:
		return
	_blink += delta
	if on_node:
		on_node.visible = fmod(_blink, 0.6) < 0.42   # blinking glow, like the original
	var s := 1.0 + 0.15 * sin(time * 8.0)
	if _blink < 0.35:   # the marker pops up: grows past its size and settles
		var k := _blink / 0.35
		s *= 1.0 + 2.70158 * pow(k - 1.0, 3) + 1.70158 * pow(k - 1.0, 2)   # ease out back
	marker.scale = Vector3.ONE * s
	marker.position.y = top_y + 0.08 * sin(time * 4.0)
	var r := 1.0 + 0.12 * sin(time * 6.0)
	ring.scale = Vector3(r, 0.15, r)
