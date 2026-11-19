class_name CameraRig
extends Node3D
## Isometric orthographic camera that slowly follows a target (dead zone + look-ahead + bounds).

@export var follow_speed := 3.0     # lower = slower, smoother
@export var dead_zone := 0.3        # metres the target can move before the camera reacts
@export var lookahead := 0.35       # seconds of velocity to look ahead
@export var zoom := 4.5             # orthographic size (vertical metres on screen)
@export var bounds := AABB(Vector3(0.6, 0, -7.4), Vector3(9.8, 0, 6.8))   # whole apartment

var target: Node3D
var scene_box := AABB()     # the whole apartment, walls included: in play the view keeps inside its outline on
                            # screen as far as it can, so it does not show the empty space around the building
var frame := Rect2()        # where the game is shown in the window (layout.gd); empty = the whole window
var screen := Vector2()     # the window's logical size
var view := Rect2()         # the part of the frame not covered by the menu sheet (hud.gd); empty = the frame
var use_bounds := true
var height_offset := 0.5   # aim at the character's chest, not its feet
var cam: Camera3D
var _focus := Vector3.ZERO
var _shake := 0.0          # shake strength now, metres (fades out over _shake_time)
var _shake_left := 0.0
var _shake_time := 0.0


func _ready() -> void:
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = zoom
	cam.near = 0.1
	cam.far = 120.0
	var offset := Vector3(1, 1, 1).normalized() * 30.0   # true isometric angle (35.26 deg)
	cam.transform = Transform3D(Basis.looking_at(-offset, Vector3.UP), offset)
	add_child(cam)
	cam.make_current()


var _size := 4.5           # orthographic size seen in the frame (eases towards `zoom`)


func snap() -> void:
	if target:
		_focus = _clamp(target.global_position)
		global_position = _focus
	_size = zoom
	_apply_frame()


func _apply_frame() -> void:
	## The camera renders the whole window, but only the frame is visible: zoom out by window / frame height
	## and shift the view so the focus sits in the middle of the frame. With the menu sheet on screen, the
	## same for the part of the frame the sheet leaves free (`zoom` metres fit its height).
	var v := view if view.has_area() else frame
	if v.size.y <= 0.0 or screen.y <= 0.0:
		cam.size = _size
		cam.h_offset = 0.0
		cam.v_offset = 0.0
		return
	cam.size = _size * screen.y / v.size.y   # keep_aspect = height: cam.size is the window's height
	var per_px := cam.size / screen.y
	var d := v.get_center() - screen / 2.0
	cam.h_offset = -d.x * per_px
	cam.v_offset = d.y * per_px
	if _shake_left > 0.0:
		var k := _shake * _shake_left / maxf(_shake_time, 0.001)
		cam.h_offset += randf_range(-k, k)
		cam.v_offset += randf_range(-k, k)


## Shake the view: `amount` metres at first, dying away over `time` seconds (a stronger shake replaces a weaker).
func shake(amount: float, time: float) -> void:
	var now := _shake * _shake_left / maxf(_shake_time, 0.001) if _shake_left > 0.0 else 0.0
	if amount >= now:
		_shake = amount
		_shake_left = time
		_shake_time = time


func _clamp(p: Vector3) -> Vector3:
	if not use_bounds:
		return Vector3(p.x, height_offset, p.z)
	var q := Vector3(clampf(p.x, bounds.position.x, bounds.end.x), height_offset,
			clampf(p.z, bounds.position.z, bounds.end.z))
	return _in_view(q) if scene_box.has_volume() else q


func _in_view(q: Vector3) -> Vector3:
	## Move the focus so the visible part of the frame stays within the apartment's outline on screen (its
	## bounding box in the camera's plane); an apartment smaller than the view is centred in it. The character
	## stays in view: it is inside that box.
	var v := view if view.has_area() else frame
	if v.size.y <= 0.0 or not cam.is_inside_tree():
		return q
	var b := cam.global_transform.basis
	var r := b.x          # screen right
	var u := b.y          # screen up
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for i in 8:
		var c := scene_box.get_endpoint(i)
		var s := Vector2(c.dot(r), c.dot(u))
		lo = lo.min(s)
		hi = hi.max(s)
	var half := Vector2(_size * 0.5 * v.size.x / v.size.y, _size * 0.5)   # half the view, metres
	var cur := Vector2(q.dot(r), q.dot(u))
	var want := cur
	for k in 2:
		if hi[k] - lo[k] <= 2.0 * half[k]:
			want[k] = (lo[k] + hi[k]) * 0.5
		else:
			want[k] = clampf(cur[k], lo[k] + half[k], hi[k] - half[k])
	var d := want - cur
	# the same shift as a move over the floor (y stays): d.x along r, d.y along u
	var det := r.x * u.z - r.z * u.x
	if absf(det) < 0.000001:
		return q
	return q + Vector3((d.x * u.z - r.z * d.y) / det, 0.0, (r.x * d.y - d.x * u.x) / det)


func _process(delta: float) -> void:
	if target:
		var want := target.global_position
		if target is CharacterBody3D:
			want += (target as CharacterBody3D).velocity * lookahead
		var d := want - _focus
		d.y = 0
		if d.length() > dead_zone:
			_focus += d.normalized() * (d.length() - dead_zone)
		global_position = global_position.lerp(_clamp(_focus), 1.0 - exp(-follow_speed * delta))
	_size = lerpf(_size, zoom, 1.0 - exp(-4.0 * delta))
	_shake_left = maxf(_shake_left - delta, 0.0)
	_apply_frame()
