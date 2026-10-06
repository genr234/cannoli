@tool
@icon("res://addons/juice/icons/camera.svg")
class_name JuiceCameraOrthoSize
extends JuiceCameraFeedback
## Plays a curve on the size of an orthographic [Camera3D].
##
## Over the duration the curve picks a size between two values, and the camera goes back to
## its own size at the end. Handled by [JuiceZoomShaker]. A [Camera2D] has no size, use
## [JuiceCameraZoom] for it.
##
## Broadcasts [code]juice_camera_ortho_size[/code]. Payload keys: [code]duration[/code],
## [code]curve[/code], [code]remap_zero[/code], [code]remap_one[/code], [code]relative[/code],
## [code]amount[/code].

@export_group("Orthographic Size")
## Seconds the change lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve over the duration. Empty is a bump that rises and falls.
@export var curve: Curve
## The size at curve value 0. With relative on, the amount added.
@export var remap_zero: float = 5.0
## The size at curve value 1. With relative on, the amount added.
@export var remap_one: float = 7.0
## Adds the values to the camera's size instead of replacing it.
@export var relative: bool = false


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _get_duration() -> float:
	return duration


func _get_event() -> StringName:
	return JuiceZoomShaker.EVENT_ORTHO_SIZE


func _create_direct_shaker() -> JuiceShaker:
	return JuiceZoomShaker.new()


func _build_payload(feedback_intensity: float) -> Dictionary:
	return {
		"duration": get_feedback_duration(),
		"curve": curve,
		"remap_zero": remap_zero,
		"remap_one": remap_one,
		"relative": relative,
		"amount": feedback_intensity,
	}
