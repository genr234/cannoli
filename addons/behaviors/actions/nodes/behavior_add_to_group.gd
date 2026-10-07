@tool
@icon("res://addons/behaviors/icons/group.svg")
class_name BehaviorAddToGroup
extends BehaviorAction
## Adds a node to a group.

## The node to add, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the node to add. Replaces [member target] when set.
@export var target_variable: String = ""
## The group.
@export var group: StringName = &""
## Saves the group with the scene when the node is packed.
@export var persistent: bool = false

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var node := Targets.resolve(self, target, target_variable) as Node
	if node == null or String(group).is_empty():
		return Status.FAILURE
	node.add_to_group(group, persistent)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(group).is_empty():
		warnings.append("Add To Group has no group.")
	return warnings


func _get_graph_text() -> String:
	return "+ %s" % group
