@tool
@icon("res://addons/behaviors/icons/variable.svg")
class_name BehaviorToggleVariable
extends BehaviorAction
## Flips a boolean variable. A variable that is not a boolean counts as true when it is
## set.

## The variable to flip.
@export var variable: String = ""


func _on_update(_delta: float) -> Status:
	if variable.is_empty():
		return Status.FAILURE
	set_var(StringName(variable), not Behaviors.is_set(get_var(StringName(variable))))
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if variable.is_empty():
		warnings.append("Toggle Variable has no variable.")
	return warnings


func _get_graph_text() -> String:
	return "toggle %s" % variable
