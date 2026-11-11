class_name ScreenFx
extends Node
## Screen effect: a short image-noise / glitch burst when an appliance switches on, over the game frame only
## (the rounded frame and the background round it are drawn by layout.gd).

const NOISE_SHADER := """
shader_type canvas_item;
uniform float intensity = 0.0;
uniform float seed = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;

float rand(vec2 co) { return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	// a few horizontal bands jump sideways
	float band = floor(uv.y * 90.0);
	float jump = step(0.82, rand(vec2(band, seed))) * (rand(vec2(seed, band)) - 0.5) * 0.03 * intensity;
	float split = 0.004 * intensity;
	vec3 col;
	col.r = texture(screen_tex, uv + vec2(jump + split, 0.0)).r;
	col.g = texture(screen_tex, uv + vec2(jump, 0.0)).g;
	col.b = texture(screen_tex, uv + vec2(jump - split, 0.0)).b;
	// grain (2x2 pixel blocks so it reads as pixel noise)
	float n = rand(floor(FRAGCOORD.xy / 2.0) + vec2(seed * 61.0, seed * 17.0)) - 0.5;
	col += n * 0.26 * intensity;
	// faint scanlines
	col *= 1.0 - 0.08 * intensity * step(0.5, fract(FRAGCOORD.y / 3.0));
	COLOR = vec4(col, 1.0);
}
"""

var _noise_rect: ColorRect
var _noise_mat: ShaderMaterial
var _t := 0.0
var _dur := 0.0
var _strength := 0.0


func _ready() -> void:
	var noise_layer := CanvasLayer.new()
	noise_layer.layer = 1          # above the 3D view, below the HUD (HUD stays readable)
	add_child(noise_layer)
	_noise_rect = _full_rect(NOISE_SHADER)
	_noise_mat = _noise_rect.material
	_noise_rect.visible = false
	noise_layer.add_child(_noise_rect)


## The game frame moved (layout.gd): the noise covers only it.
func set_frame(r: Rect2) -> void:
	_noise_rect.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_noise_rect.position = r.position
	_noise_rect.size = r.size


func _full_rect(code: String) -> ColorRect:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	r.material = m
	return r


## Short noise burst. strength 0..1, duration in seconds.
func glitch(strength := 1.0, duration := 0.35) -> void:
	_strength = maxf(_strength * (1.0 - _t / maxf(_dur, 0.001)), strength)
	_dur = duration
	_t = 0.0


func _process(delta: float) -> void:
	if _t >= _dur:
		_noise_rect.visible = false
		return
	_t += delta
	var k := 1.0 - clampf(_t / _dur, 0.0, 1.0)
	var flicker := 0.6 + 0.4 * randf()
	_noise_rect.visible = true
	_noise_mat.set_shader_parameter("intensity", _strength * k * k * flicker)
	_noise_mat.set_shader_parameter("seed", randf() * 100.0)
