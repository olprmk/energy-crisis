class_name Player
extends CharacterBody3D
## Player character: camera-relative movement, facing, animations, switching appliances off.

signal switch_hit   # emitted in the middle of the switch_off animation

var speed := 3.0
var switch_time := 0.6
var bot_dir := Vector3.ZERO   # autotest --physical: direction to walk instead of the keys
var input_enabled := false
var locked := false
var cam: Camera3D

var model: Node3D
var anim: AnimationPlayer
var _col: CollisionShape3D
var _face := PI / 4.0
var _cur_anim := ""

## Animations every model must have. If the editor's import cache is older than the .glb
## (Godot did not re-import a model updated from outside), the model is read straight from the .glb.
const REQUIRED_ANIMS := ["idle", "walk", "switch_off", "celebrate", "fail"]
static var _fresh_models := {}   # .glb path -> Node3D loaded directly from the file (cached)


func _init() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_col = CollisionShape3D.new()
	add_child(_col)


func setup(cfg: Dictionary) -> void:
	speed = cfg["speed"]
	switch_time = cfg["switch_time"]
	if model:
		model.queue_free()
	model = _load_model(cfg["file"])
	add_child(model)
	_soften_metals(model)
	anim = _find_anim(model)
	if anim:
		for n in ["idle", "walk"]:
			if anim.has_animation(n):
				anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	var shape := CapsuleShape3D.new()
	shape.radius = cfg["radius"]
	shape.height = 1.0
	_col.shape = shape
	_col.position = Vector3(0, 0.55, 0)
	_cur_anim = ""
	locked = false
	face_camera()
	play("idle")


func face_camera() -> void:
	_face = PI / 4.0   # camera sits at +X/+Z
	if model:
		model.rotation.y = _face


func play(n: String, scale := 1.0, blend := 0.15) -> void:
	if anim == null or not anim.has_animation(n):
		return
	anim.speed_scale = scale
	if _cur_anim != n:
		anim.play(n, blend)
		_cur_anim = n


func do_switch(target: Vector3) -> void:
	if locked:
		return
	locked = true
	var to := target - global_position
	to.y = 0
	if to.length() > 0.01:
		_face = atan2(to.x, to.z)
	var length := 0.83
	if anim and anim.has_animation("switch_off"):
		length = anim.get_animation("switch_off").length
	_cur_anim = ""
	play("switch_off", length / switch_time)
	await get_tree().create_timer(switch_time * 0.55).timeout
	switch_hit.emit()
	await get_tree().create_timer(switch_time * 0.45).timeout
	locked = false


func celebrate() -> void:
	_cur_anim = ""
	face_camera()
	if anim and anim.has_animation("celebrate"):
		anim.get_animation("celebrate").loop_mode = Animation.LOOP_LINEAR   # keep cheering on the result screen
	play("celebrate")


## Floor failed: people clutch their head and twist the torso left and right;
## the dog hangs its head and turns it from side to side ("fail" animation, looped).
func despair() -> void:
	_cur_anim = ""
	face_camera()
	if anim and anim.has_animation("fail"):
		anim.get_animation("fail").loop_mode = Animation.LOOP_LINEAR
		play("fail", 1.0, 0.35)
	else:
		play("idle")   # old model without the animation (not re-imported yet)


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if bot_dir != Vector3.ZERO and not locked:
		dir = bot_dir   # autotest --physical: the bot walks like a player, with collisions
	elif input_enabled and not locked and cam:
		var v := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if v.length() > 0.05:
			var f := -cam.global_basis.z
			f.y = 0
			f = f.normalized()
			var r := cam.global_basis.x
			r.y = 0
			r = r.normalized()
			dir = (r * v.x - f * v.y)
			if dir.length() > 1.0:
				dir = dir.normalized()
	velocity = dir * speed
	move_and_slide()
	position.y = 0.0

	if dir.length() > 0.1:
		_face = atan2(dir.x, dir.z)
	if model:
		model.rotation.y = lerp_angle(model.rotation.y, _face, 1.0 - exp(-14.0 * delta))

	if locked or _cur_anim == "celebrate" or _cur_anim == "fail":
		return
	var spd := velocity.length()
	if spd > 0.2:
		play("walk", clampf(spd / 2.3, 0.6, 2.0))
	else:
		play("idle")


func _soften_metals(n: Node) -> void:
	## Fully metallic parts (stars, glasses, bracelet) look black without a sky to reflect.
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.get_surface_override_material_count():
			var mat := m.get_active_material(i) as BaseMaterial3D
			if mat and mat.metallic > 0.5:
				var copy := mat.duplicate() as BaseMaterial3D
				copy.metallic = 0.25
				copy.roughness = 0.35
				m.set_surface_override_material(i, copy)


func _load_model(path: String) -> Node3D:
	var scene: PackedScene = load(path)
	var inst: Node3D = scene.instantiate()
	var ap := _find_anim(inst)
	var missing := ap == null or REQUIRED_ANIMS.any(func(n): return not ap.has_animation(n))
	if not missing or not FileAccess.file_exists(path):
		return inst
	if not _fresh_models.has(path):
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		var root: Node = null
		if doc.append_from_file(path, state) == OK:
			root = doc.generate_scene(state)
		_fresh_models[path] = root
		if root:
			print("Player: %s re-read from the .glb (the editor has not re-imported it yet)" % path.get_file())
	var fresh: Node3D = _fresh_models[path]
	if fresh == null:
		return inst
	inst.free()
	return fresh.duplicate() as Node3D


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var a := _find_anim(c)
		if a:
			return a
	return null
