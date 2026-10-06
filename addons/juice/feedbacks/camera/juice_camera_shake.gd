@tool
@icon("res://addons/juice/icons/camera.svg")
class_name JuiceCameraShake
extends JuiceCameraFeedback
## Shakes the camera, or adds trauma to it.
##
## SHAKE plays noise of a set size for a set time. ADD_TRAUMA adds to the trauma of the camera
## shaker (0 to 1, drains over time, and the shake grows with the square of it), so several
## quick hits build up. Both are handled by [JuiceCameraShaker].
##
## Broadcasts [code]juice_camera_shake[/code]. Payload keys: [code]duration[/code],
## [code]amplitude[/code] (Vector2), [code]amplitude_3d[/code] (Vector3), [code]roll[/code]
## (degrees), [code]frequency[/code], [code]infinite[/code], or [code]trauma[/code] alone for ADD_TRAUMA.

enum Action { SHAKE, ADD_TRAUMA }

@export_group("Camera Shake")
## SHAKE plays a timed shake. ADD_TRAUMA adds to the trauma of the shaker.
@export var action: Action = Action.SHAKE:
	set(value):
		action = value
		notify_property_list_changed()
## Seconds the shake lasts.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.3
## The largest offset of a 2D camera, in pixels.
@export var amplitude: Vector2 = Vector2(8.0, 8.0)
## The largest offset of a 3D camera, in units.
@export var amplitude_3d: Vector3 = Vector3(0.1, 0.1, 0.0)
## The largest roll of the camera, in degrees.
@export_range(0.0, 45.0, 0.1, "or_greater", "suffix:deg") var roll: float = 0.0
## How fast the noise changes, in changes per second.
@export_range(0.0, 120.0, 0.1, "or_greater", "suffix:Hz") var frequency: float = 40.0
## Keeps shaking at full strength until the player stops it.
@export var repeat_until_stopped: bool = false
## The trauma to add, from 0 to 1.
@export_range(0.0, 1.0, 0.01) var trauma: float = 0.4


func _get_duration() -> float:
	return duration if action == Action.SHAKE else 0.0


func _has_randomness() -> bool:
	return true


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	var timed := ["duration", "amplitude", "amplitude_3d", "roll", "frequency", "repeat_until_stopped"]
	if (prop_name in timed and action == Action.ADD_TRAUMA) or (prop_name == "trauma" and action == Action.SHAKE):
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_event() -> StringName:
	return JuiceCameraShaker.EVENT


func _create_direct_shaker() -> JuiceShaker:
	return JuiceCameraShaker.new()


func _build_payload(feedback_intensity: float) -> Dictionary:
	if action == Action.ADD_TRAUMA:
		return {"trauma": trauma * feedback_intensity}
	return {
		"duration": get_feedback_duration(),
		"amplitude": amplitude * feedback_intensity,
		"amplitude_3d": amplitude_3d * feedback_intensity,
		"roll": roll * feedback_intensity,
		"frequency": frequency,
		"infinite": repeat_until_stopped,
	}
