@tool
@icon("res://addons/behaviors/icons/animation.svg")
class_name BehaviorSetAnimationTreeParameter
extends BehaviorAction
## Sets a parameter of an AnimationTree to a constant or to the value of a variable.

## The AnimationTree, relative to the actor.
@export var tree: NodePath = NodePath()
## A variable holding the AnimationTree. Replaces [member tree] when set.
@export var tree_variable: String = ""
## The parameter, such as [code]parameters/blend/blend_amount[/code].
@export var parameter: String = ""
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
	var animation_tree := Targets.resolve(self, tree, tree_variable) as AnimationTree
	if animation_tree == null or parameter.is_empty():
		return Status.FAILURE
	if not parameter in animation_tree:
		Targets.warn_once(self, "the AnimationTree has no parameter \"%s\"." % parameter)
		return Status.FAILURE
	var result: Variant = get_var(StringName(source_variable)) if not source_variable.is_empty() else value
	animation_tree.set(parameter, result)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if parameter.is_empty():
		warnings.append("Set Animation Tree Parameter has no parameter.")
	return warnings


func _get_graph_text() -> String:
	var source := source_variable if not source_variable.is_empty() else var_to_str(value)
	return "%s = %s" % [parameter.get_file(), source]
