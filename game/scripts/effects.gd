class_name Effects
extends RefCounted
## Small 3D effects that make the game read at a glance (all generated in code, no image files):
##   * glow()   a soft warm halo round an appliance that is on, pulsing (seen from across the flat);
##   * sparks() electric sparks crackling off an appliance while it is on;
##   * steam()  steam rising from the kettle, the iron and the pot on the stove;
##   * burst()  a one-off shower of sparks (an appliance switches on / off, the fuses blow), with a puff of smoke.
## The particles are CPUParticles3D (they work in every renderer, browsers included). The materials and meshes are
## shared, so the browser compiles each shader once (main.gd draws everything once at the start: _warm_up).

const SPARK_COLOR := Color(1.0, 0.86, 0.35)
const GLOW_COLOR := Color(1.0, 0.66, 0.12)   # painted over the (bright, pastel) rooms: saturated orange
const STEAM_IDS := ["kettle", "iron", "stove"]

static var _dot: Texture2D           # round soft dot (sparks, glow)
static var _spark_mat: StandardMaterial3D
static var _puff_mat: StandardMaterial3D
static var _spark_mesh: QuadMesh
static var _puff_mesh: QuadMesh
static var _spark_ramp: Gradient
static var _puff_ramp: Gradient
static var _grow: Curve


static func _init_shared() -> void:
	if _dot:
		return
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.75))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	_dot = tex
	# sparks: unshaded, facing the camera, coloured per particle (painted, not added: the rooms are bright)
	_spark_mat = StandardMaterial3D.new()
	_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_spark_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_spark_mat.vertex_color_use_as_albedo = true
	_spark_mat.albedo_texture = _dot
	_spark_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_spark_mesh = QuadMesh.new()
	_spark_mesh.size = Vector2(0.08, 0.08)
	_spark_mesh.material = _spark_mat
	# steam / smoke: soft see-through puffs
	_puff_mat = StandardMaterial3D.new()
	_puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_puff_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	_puff_mat.vertex_color_use_as_albedo = true
	_puff_mat.albedo_texture = _dot
	_puff_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_puff_mesh = QuadMesh.new()
	_puff_mesh.size = Vector2(0.28, 0.28)
	_puff_mesh.material = _puff_mat
	_spark_ramp = Gradient.new()
	_spark_ramp.set_color(0, Color(1, 1, 0.85, 1))
	_spark_ramp.set_color(1, Color(1, 0.4, 0.05, 0))
	_spark_ramp.add_point(0.4, Color(1, 0.8, 0.2, 1))
	_puff_ramp = Gradient.new()
	_puff_ramp.set_color(0, Color(1, 1, 1, 0))
	_puff_ramp.set_color(1, Color(1, 1, 1, 0))
	_puff_ramp.add_point(0.2, Color(1, 1, 1, 0.55))
	_grow = Curve.new()
	_grow.add_point(Vector2(0, 0.5))
	_grow.add_point(Vector2(1, 1.6))


## A warm halo round an appliance (a camera-facing quad behind its front: it shows round the outline). `size` in m.
static func glow(size: float) -> MeshInstance3D:
	_init_shared()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()   # its own: each appliance pulses on its own
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_texture = _dot
	m.albedo_color = Color(GLOW_COLOR, 0.0)
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	return mi


static func _particles(mesh: Mesh, ramp: Gradient) -> CPUParticles3D:
	_init_shared()
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.local_coords = false
	p.emitting = false
	p.color_ramp = ramp
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


## Sparks crackling off an appliance while it is on (a few per second, from round its top).
static func sparks(radius: float) -> CPUParticles3D:
	var p := _particles(_spark_mesh, _spark_ramp)
	p.amount = 5
	p.lifetime = 0.5
	p.randomness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -7.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.1
	p.color = SPARK_COLOR
	return p


## Steam rising (kettle, iron, the pot on the stove).
static func steam() -> CPUParticles3D:
	var p := _particles(_puff_mesh, _puff_ramp)
	p.amount = 10
	p.lifetime = 1.4
	p.randomness = 0.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.06
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0.15, 0.25, -0.1)   # drifts a little
	p.damping_min = 0.1
	p.damping_max = 0.2
	p.scale_amount_curve = _grow
	p.color = Color(1, 1, 1, 1)
	return p


## A one-off shower of sparks (and a puff of smoke) at `pos`; the nodes free themselves.
## amount: number of sparks; strength: speed / size (1 = an appliance switching off, 2+ = the fuses blowing).
static func burst(parent: Node, pos: Vector3, amount := 18, strength := 1.0, smoke := true) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var s := _particles(_spark_mesh, _spark_ramp)
	s.one_shot = true
	s.explosiveness = 1.0
	s.amount = amount
	s.lifetime = 0.55
	s.randomness = 0.4
	s.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	s.emission_sphere_radius = 0.12
	s.direction = Vector3.UP
	s.spread = 95.0
	s.initial_velocity_min = 1.5 * strength
	s.initial_velocity_max = 3.2 * strength
	s.gravity = Vector3(0, -9.0, 0)
	s.scale_amount_min = 0.8
	s.scale_amount_max = 1.6 * minf(strength, 1.5)
	s.color = SPARK_COLOR
	parent.add_child(s)
	s.global_position = pos
	s.emitting = true
	var nodes: Array[Node] = [s]
	if smoke:
		var p := _particles(_puff_mesh, _puff_ramp)
		p.one_shot = true
		p.explosiveness = 0.9
		p.amount = 6
		p.lifetime = 0.9
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.15
		p.direction = Vector3.UP
		p.spread = 60.0
		p.initial_velocity_min = 0.3
		p.initial_velocity_max = 0.8
		p.gravity = Vector3(0, 0.4, 0)
		p.scale_amount_curve = _grow
		p.color = Color(0.85, 0.85, 0.85, 1)
		parent.add_child(p)
		p.global_position = pos
		p.emitting = true
		nodes.append(p)
	parent.get_tree().create_timer(1.6, false).timeout.connect(func() -> void:
		for n in nodes:
			if is_instance_valid(n):
				n.queue_free())
