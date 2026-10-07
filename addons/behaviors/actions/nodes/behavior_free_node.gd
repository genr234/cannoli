@tool
@icon("res://addons/behaviors/icons/node.svg")
class_name BehaviorFreeNode
extends BehaviorAction
## Frees a node at the end of the frame. Fails when the node is missing. An empty target
## frees the actor.

## The node to free, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the node to free. Replaces [member target] when set.
@export var target_variable: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var node := Targets.resolve(self, target, target_variable) as Node
	if node == null:
		return Status.FAILURE
	node.queue_free()
	return Status.SUCCESS


func _get_graph_text() -> String:
	return target_variable if not target_variable.is_empty() else (String(target) if not target.is_empty() else "actor")
