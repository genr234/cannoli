@tool
@icon("res://addons/behaviors/icons/node.svg")
class_name BehaviorIsVisible
extends BehaviorCondition
## Succeeds when a 2D, 3D or UI node is visible.

## The node to check, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the node to check. Replaces [member target] when set.
@export var target_variable: String = ""
## Also requires every parent to be visible.
@export var in_tree: bool = true

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var node := Targets.resolve(self, target, target_variable)
	if node is CanvasItem or node is Node3D:
		var shown: bool = node.is_visible_in_tree() if in_tree else node.visible
		return Status.SUCCESS if shown else Status.FAILURE
	return Status.FAILURE


func _get_graph_text() -> String:
	return "visible"
