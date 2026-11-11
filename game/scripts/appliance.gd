class_name Appliance
extends RefCounted
## Runtime state of one appliance from the floor model (APPL_<id> node + <id>_on glow part).

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

var is_on := false
var t_on := 0.0
var marker: Node3D        # Sprite3D (assets/ui/marker_exclamation.png) or Label3D fallback
var ring: MeshInstance3D
var _blink := 0.0


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


func set_on(v: bool, now: float) -> void:
	is_on = v
	t_on = now
	_blink = 0.0
	if on_node:
		on_node.visible = v
	if marker:
		marker.visible = v and not never_off
		ring.visible = v and not never_off


func update(delta: float, time: float) -> void:
	if not is_on or never_off:
		return
	_blink += delta
	if on_node:
		on_node.visible = fmod(_blink, 0.6) < 0.42   # blinking glow, like the original
	var s := 1.0 + 0.15 * sin(time * 8.0)
	marker.scale = Vector3.ONE * s
	marker.position.y = top_y + 0.08 * sin(time * 4.0)
	var r := 1.0 + 0.12 * sin(time * 6.0)
	ring.scale = Vector3(r, 0.15, r)
