@tool
@icon("res://addons/juice/icons/environment.svg")
class_name JuiceDepthOfField
extends JuiceEnvironmentBase
## Animates the depth of field blur of the camera attributes, such as a focus pull.
##
## It needs [CameraAttributesPractical]. When the scene has no camera attributes, one is
## created and put back to nothing on restore (see [member create_attributes]).

## The depth of field value to animate.
enum Value {
	## How strong the blur is.
	BLUR_AMOUNT,
	## The distance where far blur starts.
	FAR_DISTANCE,
	## How wide the transition of the far blur is.
	FAR_TRANSITION,
	## The distance where near blur ends.
	NEAR_DISTANCE,
	## How wide the transition of the near blur is.
	NEAR_TRANSITION,
}

const _NAMES := {
	Value.BLUR_AMOUNT: &"dof_blur_amount",
	Value.FAR_DISTANCE: &"dof_blur_far_distance",
	Value.FAR_TRANSITION: &"dof_blur_far_transition",
	Value.NEAR_DISTANCE: &"dof_blur_near_distance",
	Value.NEAR_TRANSITION: &"dof_blur_near_transition",
}

@export_group("Depth Of Field")
## Which value to animate.
@export var value: Value = Value.BLUR_AMOUNT
## The value at curve position 0.
@export var from_value: float = 0.0
## The value at curve position 1.
@export var to_value: float = 0.2
## Turns far blur on when the feedback plays.
@export var enable_far_blur: bool = true
## Turns near blur on when the feedback plays.
@export var enable_near_blur: bool = false
## Creates camera attributes when none exist.
@export var create_attributes: bool = true


func _creates_missing_attributes() -> bool:
	return create_attributes


func _is_practical() -> bool:
	return _attributes is CameraAttributesPractical


func _get_changes() -> Array[Dictionary]:
	if _attributes != null and not _is_practical():
		return []
	return [{"holder": _ATTRIBUTES, "property": _NAMES[value], "from": from_value, "to": to_value}]


func _get_switches() -> Array[Dictionary]:
	var switches: Array[Dictionary] = []
	if _attributes != null and not _is_practical():
		return switches
	if enable_far_blur:
		switches.append({"holder": _ATTRIBUTES, "property": &"dof_blur_far_enabled", "value": true})
	if enable_near_blur:
		switches.append({"holder": _ATTRIBUTES, "property": &"dof_blur_near_enabled", "value": true})
	return switches
