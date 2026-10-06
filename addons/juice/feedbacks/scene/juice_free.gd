@tool
@icon("res://addons/juice/icons/scene.svg")
class_name JuiceFree
extends JuiceFeedback
## Removes a node from the game: frees it, or just hides it and switches it off.
##
## HIDE and DISABLE are undone by restoring. Freeing is final and does nothing in the
## editor.

## QUEUE_FREE frees the node at the end of the frame. HIDE hides it. DISABLE stops its
## processing. HIDE_AND_DISABLE does both.
enum Method { QUEUE_FREE, HIDE, DISABLE, HIDE_AND_DISABLE }

@export_group("Free")
## How the node is removed.
@export var method: Method = Method.QUEUE_FREE
## More nodes to remove besides the target. Paths are relative to the player.
@export var extra_targets: Array[NodePath] = []

# Each entry is [node, visible, process_mode].
var _saved: Array = []


func _has_randomness() -> bool:
	return false


func _on_initialize() -> void:
	_saved.clear()
	for node in _nodes():
		_saved.append([node, node.get("visible") if "visible" in node else true, node.process_mode])


func _on_play(_feedback_intensity: float) -> void:
	if Engine.is_editor_hint() and method == Method.QUEUE_FREE:
		return
	for node in _nodes():
		if method == Method.QUEUE_FREE:
			node.queue_free()
			continue
		if method == Method.HIDE or method == Method.HIDE_AND_DISABLE:
			if "visible" in node:
				node.visible = false
		if method == Method.DISABLE or method == Method.HIDE_AND_DISABLE:
			node.process_mode = Node.PROCESS_MODE_DISABLED


func _on_restore() -> void:
	if method == Method.QUEUE_FREE:
		return
	for entry: Array in _saved:
		var node: Node = entry[0]
		if not is_instance_valid(node):
			continue
		if "visible" in node:
			node.visible = entry[1]
		node.process_mode = entry[2]


func _nodes() -> Array[Node]:
	var list: Array[Node] = []
	var main := get_target()
	if main != null:
		list.append(main)
	for path in extra_targets:
		var extra := resolve(path)
		if extra != null and not list.has(extra):
			list.append(extra)
	return list
