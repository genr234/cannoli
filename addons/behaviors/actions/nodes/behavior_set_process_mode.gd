@tool
@icon("res://addons/behaviors/icons/node.svg")
class_name BehaviorSetProcessMode
extends BehaviorAction
## Changes the process mode of a node, for example to pause or resume it.

## The node to change, relative to the actor. Empty is the actor.
@export var target: NodePath = NodePath()
## A variable holding the node to change. Replaces [member target] when set.
@export var target_variable: String = ""
## The new process mode.
@export var mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var node := Targets.resolve(self, target, target_variable) as Node
	if node == null:
		return Status.FAILURE
	node.process_mode = mode
	return Status.SUCCESS


func _get_graph_text() -> String:
	return ["inherit", "pausable", "when paused", "always", "disabled"][mode]
