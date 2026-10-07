@tool
@icon("res://addons/behaviors/icons/reflection.svg")
class_name BehaviorCompareProperty
extends BehaviorCondition
## Succeeds when a property of a node passes a comparison with a constant or a variable.
## Fails when the node or the property is missing.

## The node to read, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the object to read. Replaces [member target] when set.
@export var target_variable: String = ""
## The property, such as [code]health[/code] or [code]position:x[/code].
@export var property: String = ""
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

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _get_property_list() -> Array[Dictionary]:
	var usage := PROPERTY_USAGE_DEFAULT
	if _is_unary():
		usage = PROPERTY_USAGE_STORAGE
	return [{"name": "value", "type": value_type, "usage": usage}]


func _validate_property(property_info: Dictionary) -> void:
	if (property_info.name == "value_type" or property_info.name == "other_variable") and _is_unary():
		property_info.usage = PROPERTY_USAGE_STORAGE


func _on_update(_delta: float) -> Status:
	var object := Targets.resolve(self, target, target_variable)
	if object == null or property.is_empty() or not Targets.has_property(object, property):
		return Status.FAILURE
	var left: Variant = object.get_indexed(NodePath(property))
	var right: Variant = get_var(StringName(other_variable)) if not other_variable.is_empty() else value
	return Status.SUCCESS if Behaviors.compare(left, operator, right) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if property.is_empty():
		warnings.append("Compare Property has no property.")
	return warnings


func _get_graph_text() -> String:
	var symbol: String = ["==", "!=", "<", "<=", ">", ">=", "is set", "is not set"][operator]
	if _is_unary():
		return "%s %s" % [property, symbol]
	var right := other_variable if not other_variable.is_empty() else var_to_str(value)
	return "%s %s %s" % [property, symbol, right]


func _is_unary() -> bool:
	return operator == Behaviors.Operator.IS_SET or operator == Behaviors.Operator.IS_NOT_SET
