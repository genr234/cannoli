@tool
@icon("res://addons/behaviors/icons/compare.svg")
class_name BehaviorCompareVariable
extends BehaviorCondition
## Succeeds when a variable passes a comparison with a constant or another variable.

## The variable on the left side.
@export var variable: String = ""
## How to compare.
@export var operator: Behaviors.Operator = Behaviors.Operator.EQUAL:
	set(new_operator):
		operator = new_operator
		notify_property_list_changed()
## When set, compares with this variable and [member value] is ignored.
@export var other_variable: String = ""
## The type of [member value].
@export var value_type: Variant.Type = TYPE_FLOAT:
	set(new_type):
		value_type = new_type
		value = BehaviorVariable._convert(value, new_type)
		notify_property_list_changed()

## The constant to compare with.
var value: Variant = 0.0


func _get_property_list() -> Array[Dictionary]:
	var usage := PROPERTY_USAGE_DEFAULT
	if _is_unary():
		usage = PROPERTY_USAGE_STORAGE
	return [{"name": "value", "type": value_type, "usage": usage}]


func _validate_property(property: Dictionary) -> void:
	if (property.name == "value_type" or property.name == "other_variable") and _is_unary():
		property.usage = PROPERTY_USAGE_STORAGE


func _on_update(_delta: float) -> Status:
	var left: Variant = get_var(StringName(variable))
	var right: Variant = get_var(StringName(other_variable)) if not other_variable.is_empty() else value
	return Status.SUCCESS if Behaviors.compare(left, operator, right) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if variable.is_empty():
		warnings.append("Compare Variable has no variable.")
	return warnings


func _get_graph_text() -> String:
	var symbol: String = ["==", "!=", "<", "<=", ">", ">=", "is set", "is not set"][operator]
	if _is_unary():
		return "%s %s" % [variable, symbol]
	var right := other_variable if not other_variable.is_empty() else var_to_str(value)
	return "%s %s %s" % [variable, symbol, right]


func _is_unary() -> bool:
	return operator == Behaviors.Operator.IS_SET or operator == Behaviors.Operator.IS_NOT_SET
