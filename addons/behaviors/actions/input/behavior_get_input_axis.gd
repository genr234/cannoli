@tool
@icon("res://addons/behaviors/icons/input.svg")
class_name BehaviorGetInputAxis
extends BehaviorAction
## Reads two input actions as one number from -1 to 1 and stores it. Fails when an
## action is not in the Input Map.

## The action that gives -1.
@export var negative_action: StringName = &""
## The action that gives 1.
@export var positive_action: StringName = &""
## The variable that receives the float.
@export var store_in: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	if store_in.is_empty() or not InputMap.has_action(negative_action) or not InputMap.has_action(positive_action):
		Targets.warn_once(self, "an action is missing from the Input Map.")
		return Status.FAILURE
	set_var(StringName(store_in), Input.get_axis(negative_action, positive_action))
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(negative_action).is_empty() or String(positive_action).is_empty():
		warnings.append("Get Input Axis needs both actions.")
	if store_in.is_empty():
		warnings.append("Get Input Axis has no variable to store in.")
	return warnings


func _get_graph_text() -> String:
	return "%s ← %s/%s" % [store_in, negative_action, positive_action]
