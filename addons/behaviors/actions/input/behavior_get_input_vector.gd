@tool
@icon("res://addons/behaviors/icons/input.svg")
class_name BehaviorGetInputVector
extends BehaviorAction
## Reads four input actions as a Vector2 and stores it. The length is at most 1, so
## diagonals are not faster. Fails when an action is not in the Input Map.

## The action that gives -x.
@export var negative_x: StringName = &"ui_left"
## The action that gives +x.
@export var positive_x: StringName = &"ui_right"
## The action that gives -y.
@export var negative_y: StringName = &"ui_up"
## The action that gives +y.
@export var positive_y: StringName = &"ui_down"
## Values below this count as zero. -1 uses the actions' own deadzones.
@export_range(-1.0, 1.0, 0.01) var deadzone: float = -1.0
## The variable that receives the Vector2.
@export var store_in: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	for action in [negative_x, positive_x, negative_y, positive_y]:
		if not InputMap.has_action(action):
			Targets.warn_once(self, "the Input Map has no action \"%s\"." % action)
			return Status.FAILURE
	if store_in.is_empty():
		return Status.FAILURE
	set_var(StringName(store_in), Input.get_vector(negative_x, positive_x, negative_y, positive_y, deadzone))
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if store_in.is_empty():
		warnings.append("Get Input Vector has no variable to store in.")
	return warnings


func _get_graph_text() -> String:
	return "%s ← input" % store_in
