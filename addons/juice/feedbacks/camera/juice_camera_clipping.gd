@tool
@icon("res://addons/juice/icons/camera.svg")
class_name JuiceCameraClipping
extends JuiceCameraFeedback
## Plays curves on the near and far clipping planes of a [Camera3D].
##
## Handled by [JuiceClippingPlanesShaker]. The planes return to their own values at the end.
##
## Broadcasts [code]juice_camera_clipping[/code]. Payload keys: [code]duration[/code],
## [code]animate_near[/code], [code]animate_far[/code], [code]near_curve[/code], [code]far_curve[/code],
## [code]near_zero[/code], [code]near_one[/code], [code]far_zero[/code], [code]far_one[/code],
## [code]relative[/code], [code]amount[/code].

@export_group("Clipping Planes")
## Seconds the change lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
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
## Adds the values to the camera's planes instead of replacing them.
@export var relative: bool = false


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _get_duration() -> float:
	return duration


func _get_event() -> StringName:
	return JuiceClippingPlanesShaker.EVENT


func _create_direct_shaker() -> JuiceShaker:
	return JuiceClippingPlanesShaker.new()


func _build_payload(feedback_intensity: float) -> Dictionary:
	return {
		"duration": get_feedback_duration(),
		"animate_near": animate_near,
		"animate_far": animate_far,
		"near_curve": near_curve,
		"far_curve": far_curve,
		"near_zero": near_zero,
		"near_one": near_one,
		"far_zero": far_zero,
		"far_one": far_one,
		"relative": relative,
		"amount": feedback_intensity,
	}
