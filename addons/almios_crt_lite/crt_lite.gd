@tool
@icon("res://addons/almios_crt_lite/icon.svg")
class_name CRTLite
extends CanvasLayer

## CRT Lite in one node: add it anywhere in your scene and the whole screen below
## its layer gets the CRT look. It makes the full-screen ColorRect and the shader
## material for you, and applies ready-made presets.
##
##     $CRTLite.preset = CRTLite.Preset.AMBER_MONITOR
##     $CRTLite.enabled = false        # an option in your settings menu
##     $CRTLite.set_crt("scanlines", 0.5)
##
## Put your interface on a higher CanvasLayer to keep it sharp, or below to have it
## on the tube too. CRT Lite by Dimension Almios, MIT licence.

enum Preset { LIVING_ROOM_TV, OLD_TV, ARCADE, GREEN_MONITOR, AMBER_MONITOR, SUBTLE }

const SHADER := preload("res://addons/almios_crt_lite/crt_lite.gdshader")

## Turns the effect on and off.
@export var enabled := true:
	set(v):
		enabled = v
		if _rect:
			_rect.visible = v
## Picking a preset sets every setting of the shader (change them afterwards with
## set_crt(); for the Inspector, use the shader alone on your own ColorRect).
@export var preset := Preset.LIVING_ROOM_TV:
	set(v):
		preset = v
		apply_preset(v)

const PRESETS := {
	Preset.LIVING_ROOM_TV: {},
	Preset.OLD_TV: {"curvature": 0.18, "corner_radius": 0.1, "scanlines": 0.45, "vignette": 0.55,
		"saturation": 0.8, "warmth": 0.5, "noise": 0.35, "flicker": 0.6, "rolling_bar": 0.6,
		"glass_reflection": 0.6, "brightness": 1.15},
	Preset.ARCADE: {"curvature": 0.08, "corner_radius": 0.04, "scanlines": 0.55, "scanline_size": 4.0,
		"vignette": 0.25, "saturation": 1.3, "contrast": 1.15, "rgb_mask": true, "mask_strength": 0.45,
		"mask_type": 0, "brightness": 1.25, "glass_reflection": 0.3},
	Preset.GREEN_MONITOR: {"curvature": 0.12, "scanlines": 0.5, "monochrome": 1.0,
		"phosphor_color": Color(0.35, 1.0, 0.45), "contrast": 1.3, "flicker": 0.3, "noise": 0.12,
		"glass_reflection": 0.45, "vignette": 0.45},
	Preset.AMBER_MONITOR: {"curvature": 0.12, "scanlines": 0.5, "monochrome": 1.0,
		"phosphor_color": Color(1.0, 0.68, 0.2), "contrast": 1.3, "flicker": 0.3, "noise": 0.12,
		"glass_reflection": 0.45, "vignette": 0.45},
	Preset.SUBTLE: {"curvature": 0.03, "corner_radius": 0.02, "scanlines": 0.18, "vignette": 0.2,
		"brightness": 1.05},
}
# every preset starts from these values, so nothing of the previous one stays
const _BASE := {"curvature": 0.1, "corner_radius": 0.06, "border_color": Color(0, 0, 0),
	"scanlines": 0.35, "scanline_size": 3.0, "vignette": 0.35, "brightness": 1.1, "rgb_mask": false,
	"mask_strength": 0.3, "mask_type": 0, "saturation": 1.0, "contrast": 1.0, "warmth": 0.0,
	"monochrome": 0.0, "phosphor_color": Color(0.35, 1.0, 0.45), "noise": 0.0, "flicker": 0.0,
	"rolling_bar": 0.0, "glass_reflection": 0.0}

var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	layer = 100
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect, false, INTERNAL_MODE_FRONT)
	apply_preset(preset)


## Applies one of the presets.
func apply_preset(which: Preset) -> void:
	if _mat == null:
		return
	for k in _BASE:
		_mat.set_shader_parameter(k, _BASE[k])
	for k in PRESETS[which]:
		_mat.set_shader_parameter(k, PRESETS[which][k])


## Sets one setting of the shader (see crt_lite.gdshader for the names).
func set_crt(setting: String, value) -> void:
	_mat.set_shader_parameter(setting, value)


## Reads one setting of the shader.
func get_crt(setting: String):
	return _mat.get_shader_parameter(setting)


## The shader material, to animate settings with a Tween.
func get_material() -> ShaderMaterial:
	return _mat
