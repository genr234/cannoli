@tool
@icon("res://addons/behaviors/icons/variable.svg")
class_name BehaviorSetVariable
extends BehaviorAction
## Sets a variable to a constant, or copies it from another variable.

## The variable to write. Use [code]global/[/code] for global variables.
@export var variable: String = ""
## When set, the value is copied from this variable and [member value] is ignored.
@export var source_variable: String = ""
## The type of [member value].
@export var value_type: Variant.Type = TYPE_FLOAT:
	set(new_type):
		value_type = new_type
		value = BehaviorVariable._convert(value, new_type)
		notify_property_list_changed()

## The constant to write.
var value: Variant = 0.0


func _get_property_list() -> Array[Dictionary]:
	return [{"name": "value", "type": value_type, "usage": PROPERTY_USAGE_DEFAULT}]


func _on_update(_delta: float) -> Status:
	if variable.is_empty():
		return Status.FAILURE
	var result: Variant = get_var(StringName(source_variable)) if not source_variable.is_empty() else value
	if result is Array or result is Dictionary:
		result = result.duplicate(true)
	set_var(StringName(variable), result)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if variable.is_empty():
		warnings.append("Set Variable has no variable.")
	return warnings


func _get_graph_text() -> String:
	var source := source_variable if not source_variable.is_empty() else var_to_str(value)
	return "%s = %s" % [variable, source]
