class_name CameraRig
extends Node3D
## Isometric orthographic camera that slowly follows a target (dead zone + look-ahead + bounds).

@export var follow_speed := 3.0     # lower = slower, smoother
@export var dead_zone := 0.3        # metres the target can move before the camera reacts
@export var lookahead := 0.35       # seconds of velocity to look ahead
@export var zoom := 4.5             # orthographic size (vertical metres on screen)
@export var bounds := AABB(Vector3(0.6, 0, -7.4), Vector3(9.8, 0, 6.8))   # whole apartment

var target: Node3D
var frame := Rect2()        # where the game is shown in the window (layout.gd); empty = the whole window
var screen := Vector2()     # the window's logical size
var view := Rect2()         # the part of the frame not covered by the menu sheet (hud.gd); empty = the frame
var use_bounds := true
var height_offset := 0.5   # aim at the character's chest, not its feet
var cam: Camera3D
var _focus := Vector3.ZERO


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


func _clamp(p: Vector3) -> Vector3:
	if not use_bounds:
		return Vector3(p.x, height_offset, p.z)
	return Vector3(clampf(p.x, bounds.position.x, bounds.end.x), height_offset,
			clampf(p.z, bounds.position.z, bounds.end.z))


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
	_apply_frame()
