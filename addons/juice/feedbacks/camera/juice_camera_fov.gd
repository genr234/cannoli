@tool
@icon("res://addons/juice/icons/camera.svg")
class_name JuiceCameraFov
extends JuiceCameraFeedback
## Plays a curve on the field of view of a perspective [Camera3D].
##
## Over the duration the curve picks a field of view between two values, and the camera
## goes back to its own value at the end. Handled by [JuiceZoomShaker]. For a zoom that
## works on any camera, use [JuiceCameraZoom].
##
## Broadcasts [code]juice_camera_fov[/code]. Payload keys: [code]duration[/code], [code]curve[/code],
## [code]remap_zero[/code], [code]remap_one[/code], [code]relative[/code], [code]amount[/code].

@export_group("Field of View")
## Seconds the change lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The curve over the duration. Empty is a bump that rises and falls.
@export var curve: Curve
## The field of view at curve value 0, in degrees. With relative on, the amount added.
@export_range(-179.0, 179.0, 0.1, "suffix:deg") var remap_zero: float = 60.0
## The field of view at curve value 1, in degrees. With relative on, the amount added.
@export_range(-179.0, 179.0, 0.1, "suffix:deg") var remap_one: float = 90.0
## Adds the values to the camera's field of view instead of replacing it.
@export var relative: bool = false


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _get_duration() -> float:
	return duration


func _get_event() -> StringName:
	return JuiceZoomShaker.EVENT_FOV


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
