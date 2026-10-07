@tool
@icon("res://addons/behaviors/icons/node.svg")
class_name BehaviorFindNode
extends BehaviorAction
## Finds a node by path or by name and stores it in a variable. Fails when nothing is
## found.

## The node to search from, relative to the actor. Empty is the actor.
@export var root: NodePath = NodePath()
## A variable holding the node to search from. Replaces [member root] when set.
@export var root_variable: String = ""
## An exact path from the root. Used first when set.
@export var path: NodePath = NodePath()
## A name to look for among all descendants. It may use [code]*[/code] and
## [code]?[/code]. Used when [member path] is empty.
@export var node_name: String = ""
## The variable that receives the node.
@export var store_in: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	var start := Targets.resolve(self, root, root_variable) as Node
	if start == null or store_in.is_empty():
		return Status.FAILURE
	var found: Node = null
	if not path.is_empty():
		found = start.get_node_or_null(path)
	elif not node_name.is_empty():
		found = start.find_child(node_name, true, false)
	if found == null:
		return Status.FAILURE
	set_var(StringName(store_in), found)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if path.is_empty() and node_name.is_empty():
		warnings.append("Find Node needs a path or a name.")
	if store_in.is_empty():
		warnings.append("Find Node has no variable to store in.")
	return warnings


func _get_graph_text() -> String:
	return "%s ← %s" % [store_in, String(path) if not path.is_empty() else node_name]
