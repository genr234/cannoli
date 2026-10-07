@tool
@icon("res://addons/behaviors/icons/input.svg")
class_name BehaviorIsActionPressed
extends BehaviorCondition
## Succeeds when an input action is pressed. Fails for an action that is not in the
## Input Map.

## What to check.
enum Mode {
	## The action is held down.
	PRESSED,
	## The action went down this frame.
	JUST_PRESSED,
	## The action was let go this frame.
	JUST_RELEASED,
}

## The input action.
@export var action: StringName = &""
## What to check.
@export var mode: Mode = Mode.PRESSED

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	if not InputMap.has_action(action):
		Targets.warn_once(self, "the Input Map has no action \"%s\"." % action)
		return Status.FAILURE
	var result := false
	match mode:
		Mode.PRESSED: result = Input.is_action_pressed(action)
		Mode.JUST_PRESSED: result = Input.is_action_just_pressed(action)
		Mode.JUST_RELEASED: result = Input.is_action_just_released(action)
	return Status.SUCCESS if result else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(action).is_empty():
		warnings.append("Is Action Pressed has no action.")
	return warnings


func _get_graph_text() -> String:
	return "%s %s" % [action, ["held", "pressed", "released"][mode]]
