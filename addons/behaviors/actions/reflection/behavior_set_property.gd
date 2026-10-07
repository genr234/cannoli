@tool
@icon("res://addons/behaviors/icons/reflection.svg")
class_name BehaviorSetProperty
extends BehaviorAction
## Sets a property of a node to a constant or to the value of a variable.

## The node to change, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the object to change. Replaces [member target] when set.
@export var target_variable: String = ""
## The property, such as [code]visible[/code] or [code]position:x[/code].
@export var property: String = ""
## When set, the value is copied from this variable and [member value] is ignored.
@export var source_variable: String = ""
## The type of [member value].
@export var value_type: Variant.Type = TYPE_FLOAT:
	set(new_type):
		value_type = new_type
		value = BehaviorVariable._convert(value, new_type)
		notify_property_list_changed()

## The constant to set.
var value: Variant = 0.0

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _get_property_list() -> Array[Dictionary]:
	return [{"name": "value", "type": value_type, "usage": PROPERTY_USAGE_DEFAULT}]


func _on_update(_delta: float) -> Status:
	var object := Targets.resolve(self, target, target_variable)
	if object == null or property.is_empty():
		return Status.FAILURE
	if not Targets.has_property(object, property):
		Targets.warn_once(self, "%s has no property \"%s\"." % [object, property])
		return Status.FAILURE
	var result: Variant = get_var(StringName(source_variable)) if not source_variable.is_empty() else value
	object.set_indexed(NodePath(property), result)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if property.is_empty():
		warnings.append("Set Property has no property.")
	return warnings


func _get_graph_text() -> String:
	var source := source_variable if not source_variable.is_empty() else var_to_str(value)
	return "%s = %s" % [property, source]
