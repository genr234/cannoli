@tool
@icon("res://addons/behaviors/icons/node.svg")
class_name BehaviorSetVisible
extends BehaviorAction
## Shows or hides a 2D, 3D or UI node. Fails when the node has no visibility.

## The node to change, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the node to change. Replaces [member target] when set.
@export var target_variable: String = ""
## True shows the node, false hides it.
@export var make_visible: bool = true

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var node := Targets.resolve(self, target, target_variable)
	if node == null or not (node is CanvasItem or node is Node3D):
		return Status.FAILURE
	node.visible = make_visible
	return Status.SUCCESS


func _get_graph_text() -> String:
	return "show" if make_visible else "hide"
