@tool
@icon("res://addons/behaviors/icons/group.svg")
class_name BehaviorIsInGroup
extends BehaviorCondition
## Succeeds when a node is in a group.

## The node to check, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the node to check. Replaces [member target] when set.
@export var target_variable: String = ""
## The group.
@export var group: StringName = &""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var node := Targets.resolve(self, target, target_variable) as Node
	return Status.SUCCESS if node != null and node.is_in_group(group) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if String(group).is_empty():
		warnings.append("Is In Group has no group.")
	return warnings


func _get_graph_text() -> String:
	return String(group)
