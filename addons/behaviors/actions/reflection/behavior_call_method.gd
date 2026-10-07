@tool
@icon("res://addons/behaviors/icons/reflection.svg")
class_name BehaviorCallMethod
extends BehaviorAction
## Calls a method on a node, and can store what it returns. Fails when the method does
## not exist. The call runs right away, so a method that needs time cannot be awaited.

## The node to call, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the object to call. Replaces [member target] when set.
@export var target_variable: String = ""
## The method name.
@export var method: StringName = &""
## Values passed to the method.
@export var arguments: Array = []
## Variables whose values are passed after [member arguments].
@export var argument_variables: PackedStringArray = PackedStringArray()
## The variable that receives the return value. Empty drops it.
@export var store_in: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var object := Targets.resolve(self, target, target_variable)
	if object == null or String(method).is_empty():
		return Status.FAILURE
	if not object.has_method(method):
		Targets.warn_once(self, "%s has no method \"%s\"." % [object, method])
		return Status.FAILURE
	var args := arguments.duplicate()
	for variable in argument_variables:
		args.append(get_var(StringName(variable)))
	var returned: Variant = object.callv(method, args)
	if not store_in.is_empty():
		set_var(StringName(store_in), returned)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(method).is_empty():
		warnings.append("Call Method has no method.")
	return warnings


func _get_graph_text() -> String:
	return "%s()" % method
