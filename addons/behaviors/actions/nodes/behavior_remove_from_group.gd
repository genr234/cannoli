@tool
@icon("res://addons/behaviors/icons/group.svg")
class_name BehaviorRemoveFromGroup
extends BehaviorAction
## Removes a node from a group. Succeeds even when the node was not in it.

## The node to remove, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the node to remove. Replaces [member target] when set.
@export var target_variable: String = ""
## The group.
@export var group: StringName = &""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var node := Targets.resolve(self, target, target_variable) as Node
	if node == null or String(group).is_empty():
		return Status.FAILURE
	node.remove_from_group(group)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(group).is_empty():
		warnings.append("Remove From Group has no group.")
	return warnings


func _get_graph_text() -> String:
	return "- %s" % group
