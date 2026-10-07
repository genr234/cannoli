@tool
@icon("res://addons/behaviors/icons/compare.svg")
class_name BehaviorIsVariableSet
extends BehaviorCondition
## Succeeds when a variable is set: not null, false, zero or empty.

## The variable to check.
@export var variable: String = ""
## Succeeds when the variable is [b]not[/b] set instead.
@export var inverted: bool = false


func _on_update(_delta: float) -> Status:
	var is_set := Behaviors.is_set(get_var(StringName(variable)))
	return Status.SUCCESS if is_set != inverted else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if variable.is_empty():
		warnings.append("Is Variable Set has no variable.")
	return warnings


func _get_graph_text() -> String:
	return "%s %s" % [variable, "is not set" if inverted else "is set"]
