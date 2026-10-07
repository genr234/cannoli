@tool
@icon("res://addons/behaviors/icons/variable.svg")
class_name BehaviorVariable
extends Resource
## A named, typed value declared on a [BehaviorTree] or in the global variables.
##
## Tasks share data through variables: one task finds a target and writes it, another
## reads it and moves there. A variable can also be [b]mapped[/b] to a property of a
## node, so reading it reads the node and writing it writes the node.

## The name tasks bind to. Names are case sensitive.
@export var name: StringName = &"":
	set(new_name):
		name = new_name
		resource_name = String(new_name)
		emit_changed()
## The type of the value.
@export var type: Variant.Type = TYPE_FLOAT:
	set(new_type):
		if type == new_type:
			return
		type = new_type
		value = _convert(value, new_type)
		notify_property_list_changed()
		emit_changed()
## What the variable is for. Shown in the editor.
@export_multiline var description: String = ""
## When true, save integrations store this variable.
@export var persist: bool = true

@export_group("Mapping")
## A node, relative to the agent's actor. When set with [member mapped_property], the
## variable reads and writes that property instead of holding a value.
@export var mapped_node: NodePath = NodePath()
## The property to map, such as [code]position[/code] or [code]position:x[/code].
@export var mapped_property: StringName = &""

## The starting value.
var value: Variant = 0.0


func _get_property_list() -> Array[Dictionary]:
	return [{
		"name": "value",
		"type": type,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_RESOURCE_TYPE if type == TYPE_OBJECT else PROPERTY_HINT_NONE,
		"hint_string": "Resource" if type == TYPE_OBJECT else "",
	}]


func _property_can_revert(property: StringName) -> bool:
	return property == &"value"


func _property_get_revert(property: StringName) -> Variant:
	if property == &"value":
		return _convert(null, type)
	return null


## True when the variable reads and writes a node property.
func is_mapped() -> bool:
	return not mapped_node.is_empty() and not String(mapped_property).is_empty()


## A copy of the starting value. Arrays and dictionaries are duplicated so agents never
## share them.
func get_default_value() -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value


## Creates a variable in code.
static func create(variable_name: StringName, variable_type: Variant.Type, initial_value: Variant = null) -> BehaviorVariable:
	var variable := BehaviorVariable.new()
	variable.name = variable_name
	variable.type = variable_type
	variable.value = _convert(initial_value, variable_type)
	return variable


static func _convert(from: Variant, to_type: Variant.Type) -> Variant:
	if to_type == TYPE_NIL:
		return from
	if typeof(from) == to_type:
		return from
	if to_type == TYPE_OBJECT:
		return from if from is Object else null
	if from == null:
		return type_convert(null, to_type)
	return type_convert(from, to_type)
