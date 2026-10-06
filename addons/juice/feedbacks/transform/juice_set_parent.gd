@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceSetParent
extends JuiceFeedback
## Moves a node under another parent in the scene tree.
##
## Restoring puts the node back under its old parent at its old position in the
## child list. Nothing happens in the editor, so previews never change a scene.

@export_group("Set Parent")
## The node that becomes the new parent. Path is relative to the player.
@export var new_parent: NodePath
## Keeps the global transform of the node, so it does not jump when it changes parent.
@export var keep_global_transform: bool = true

var _initial_parent: Node
var _initial_index := 0


func _has_randomness() -> bool:
	return false


func _on_initialize() -> void:
	var node := get_target()
	if node != null:
		_initial_parent = node.get_parent()
		_initial_index = node.get_index()


func _on_play(_feedback_intensity: float) -> void:
	if Engine.is_editor_hint():
		return
	var node := get_target()
	var parent := resolve(new_parent)
	if node == null or parent == null:
		push_warning("JuiceSetParent: needs a target and a valid new parent path.")
		return
	if node == parent or parent == node.get_parent() or node.is_ancestor_of(parent):
		return
	node.reparent(parent, keep_global_transform)


func _on_restore() -> void:
	if Engine.is_editor_hint():
		return
	var node := get_target()
	if node == null or not is_instance_valid(_initial_parent) or not _initial_parent.is_inside_tree():
		return
	if node.get_parent() != _initial_parent:
		node.reparent(_initial_parent, keep_global_transform)
	_initial_parent.move_child(node, mini(_initial_index, _initial_parent.get_child_count() - 1))
