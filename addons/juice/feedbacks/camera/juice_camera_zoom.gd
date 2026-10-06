@tool
@icon("res://addons/juice/icons/camera.svg")
class_name JuiceCameraZoom
extends JuiceCameraFeedback
## Zooms the camera in or out and, if you like, back.
##
## FOR zooms, holds, and returns. SET zooms and stays until a RESET (or a restore) brings the
## normal view back. A [Camera2D] changes its zoom, a perspective [Camera3D] its field of view
## and an orthographic one its size, so the same feedback works for all of them. A transition
## time of 0 makes the zoom instant. Handled by [JuiceZoomShaker].
##
## Broadcasts [code]juice_camera_zoom[/code]. Payload keys: [code]mode[/code], [code]factor[/code],
## [code]transition_duration[/code], [code]hold[/code], [code]tween[/code], [code]amount[/code].

@export_group("Camera Zoom")
## FOR zooms and returns, SET zooms and stays, RESET returns to the normal view.
@export var zoom_mode: JuiceZoomShaker.ZoomMode = JuiceZoomShaker.ZoomMode.FOR:
	set(value):
		zoom_mode = value
		notify_property_list_changed()
## How much to zoom in. 2 shows half the area, 0.5 shows twice the area.
@export_range(0.05, 10.0, 0.01, "or_greater") var zoom_factor: float = 1.5
## Reads the factor as an amount added to the normal zoom. 0.25 zooms in by a quarter.
@export var additive: bool = false
## Seconds to get to the zoom. 0 is instant.
@export_range(0.0, 5.0, 0.01, "or_greater", "suffix:s") var transition_duration: float = 0.1
## Seconds to stay zoomed. Only FOR holds.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var hold_duration: float = 0.1
## The easing of the transitions. Empty is linear.
@export var tween: JuiceTween


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _get_duration() -> float:
	if zoom_mode == JuiceZoomShaker.ZoomMode.FOR:
		return transition_duration * 2.0 + hold_duration
	return transition_duration


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "hold_duration" and zoom_mode != JuiceZoomShaker.ZoomMode.FOR:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["zoom_factor", "additive"] and zoom_mode == JuiceZoomShaker.ZoomMode.RESET:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_event() -> StringName:
	return JuiceZoomShaker.EVENT_ZOOM


func _create_direct_shaker() -> JuiceShaker:
	return JuiceZoomShaker.new()


func _build_payload(feedback_intensity: float) -> Dictionary:
	return {
		"mode": zoom_mode,
		"factor": 1.0 + zoom_factor if additive else zoom_factor,
		"transition_duration": apply_time_multiplier(transition_duration),
		"hold": apply_time_multiplier(hold_duration),
		"tween": tween,
		"amount": feedback_intensity,
		"duration": get_feedback_duration(),
	}
