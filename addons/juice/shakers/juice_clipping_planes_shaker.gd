@tool
@icon("res://addons/juice/icons/camera.svg")
class_name JuiceClippingPlanesShaker
extends JuiceCameraBase
## Animates the near and far clipping planes of a [Camera3D].
##
## Listens to [code]juice_camera_clipping[/code], sent by [JuiceCameraClipping]. Both planes
## follow a curve over the shake and return to their own values afterwards.
##
## Payload keys: [code]duration[/code], [code]animate_near[/code], [code]animate_far[/code],
## [code]near_curve[/code], [code]far_curve[/code] ([Curve] or null for a bump),
## [code]near_zero[/code], [code]near_one[/code], [code]far_zero[/code], [code]far_one[/code],
## [code]relative[/code], [code]amount[/code] (share of the effect).

const EVENT := &"juice_camera_clipping"

@export_group("Clipping Planes")
## Animates the near plane.
@export var animate_near: bool = true
## Animates the far plane.
@export var animate_far: bool = false
## The curve of the near plane. Empty is a bump that rises and falls.
@export var near_curve: Curve
## The curve of the far plane. Empty is a bump that rises and falls.
@export var far_curve: Curve
## The near plane at curve value 0.
@export var near_zero: float = 0.05
## The near plane at curve value 1.
@export var near_one: float = 1.0
## The far plane at curve value 0.
@export var far_zero: float = 100.0
## The far plane at curve value 1.
@export var far_one: float = 200.0
## Adds the remapped values to the camera's planes instead of replacing them.
@export var relative: bool = false

var _p_near: bool = false
var _p_far: bool = false
var _p_near_curve: Curve
var _p_far_curve: Curve
var _p_near_zero: float = 0.0
var _p_near_one: float = 0.0
var _p_far_zero: float = 0.0
var _p_far_one: float = 0.0
var _p_relative: bool = false
var _p_amount: float = 1.0
var _near_start: float = 0.0
var _far_start: float = 0.0


func _init() -> void:
	shake_duration = 0.3


func _get_events() -> Array[StringName]:
	return [EVENT]


func _is_target_supported(node: Node) -> bool:
	return node is Camera3D


func _on_begin(_event: StringName, payload: Dictionary, reach: float) -> bool:
	var node := get_target_node()
	_p_near = bool(payload.get("animate_near", animate_near))
	_p_far = bool(payload.get("animate_far", animate_far))
	_p_near_curve = payload.get("near_curve", near_curve)
	_p_far_curve = payload.get("far_curve", far_curve)
	_p_near_zero = float(payload.get("near_zero", near_zero))
	_p_near_one = float(payload.get("near_one", near_one))
	_p_far_zero = float(payload.get("far_zero", far_zero))
	_p_far_one = float(payload.get("far_one", far_one))
	_p_relative = bool(payload.get("relative", relative))
	_p_amount = float(payload.get("amount", 1.0)) * reach
	_near_start = float(get_base_value(node, "near"))
	_far_start = float(get_base_value(node, "far"))
	_run_permanent = false
	return true


func _shake(progress: float, _seconds: float) -> void:
	var node := get_target_node()
	if not node is Camera3D:
		return
	if _p_near:
		var value := sample_remap(_p_near_curve, progress, _p_near_zero, _p_near_one)
		set_offset(node, "near", value * _p_amount if _p_relative else (value - _near_start) * _p_amount)
	if _p_far:
		var value := sample_remap(_p_far_curve, progress, _p_far_zero, _p_far_one)
		set_offset(node, "far", value * _p_amount if _p_relative else (value - _far_start) * _p_amount)
