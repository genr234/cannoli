@tool
@icon("res://addons/behaviors/icons/reflection.svg")
class_name BehaviorGetProperty
extends BehaviorAction
## Reads a property of a node and stores it in a variable.

## The node to read, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the object to read. Replaces [member target] when set.
@export var target_variable: String = ""
## The property, such as [code]health[/code] or [code]position:x[/code].
@export var property: String = ""
## The variable that receives the value.
@export var store_in: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var object := Targets.resolve(self, target, target_variable)
	if object == null or property.is_empty() or store_in.is_empty():
		return Status.FAILURE
	if not Targets.has_property(object, property):
		Targets.warn_once(self, "%s has no property \"%s\"." % [object, property])
		return Status.FAILURE
	set_var(StringName(store_in), object.get_indexed(NodePath(property)))
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if property.is_empty():
		warnings.append("Get Property has no property.")
	if store_in.is_empty():
		warnings.append("Get Property has no variable to store in.")
	return warnings


func _get_graph_text() -> String:
	return "%s ← %s" % [store_in, property]
