@tool
@icon("res://addons/behaviors/icons/node.svg")
class_name BehaviorIsNodeValid
extends BehaviorCondition
## Succeeds when a variable holds a node that still exists and is inside the scene
## tree. Use it to check that a stored target was not freed.

## The variable that holds the node.
@export var variable: String = ""


func _on_update(_delta: float) -> Status:
	var held: Variant = get_var(StringName(variable))
	if typeof(held) != TYPE_OBJECT or not is_instance_valid(held):
		return Status.FAILURE
	var node := held as Node
	return Status.SUCCESS if node != null and node.is_inside_tree() and not node.is_queued_for_deletion() else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if variable.is_empty():
		warnings.append("Is Node Valid has no variable.")
	return warnings


func _get_graph_text() -> String:
	return variable
