@tool
@icon("res://addons/juice/icons/scene.svg")
class_name JuiceLoadScene
extends JuiceFeedback
## Changes the scene, or adds and removes a scene as a child.
##
## CHANGE_SCENE swaps the whole current scene. RELOAD_CURRENT restarts it. ADD_CHILD
## instances a scene under a node. REMOVE_CHILD frees a node, such as a scene added
## earlier. The scene comes from [member scene] or [member scene_file]. Nothing happens
## in the editor.
##
## With [member preload_threaded] the file starts loading in the background when the
## player initializes, so the change can be instant later. If it is not ready yet at
## play time, the play waits for it.

enum Action { CHANGE_SCENE, RELOAD_CURRENT, ADD_CHILD, REMOVE_CHILD }

@export_group("Scene")
## What to do.
@export var action: Action = Action.CHANGE_SCENE:
	set(value):
		action = value
		notify_property_list_changed()
## The scene to use. Takes priority over [member scene_file].
@export var scene: PackedScene
## The path of the scene to use when [member scene] is empty.
@export_file("*.tscn", "*.scn") var scene_file: String = ""
## Starts loading [member scene_file] in a background thread when the player initializes.
@export var preload_threaded: bool = false
## The node that receives the scene for ADD_CHILD. Empty uses the current scene.
@export var add_to: NodePath
## The node to free for REMOVE_CHILD. Path is relative to the player.
@export var node_to_remove: NodePath

var _requested := false


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name in ["scene", "scene_file", "preload_threaded"] and (action == Action.RELOAD_CURRENT or action == Action.REMOVE_CHILD):
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "add_to" and action != Action.ADD_CHILD:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "node_to_remove" and action != Action.REMOVE_CHILD:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _has_randomness() -> bool:
	return false


func _has_target() -> bool:
	return false


func _on_initialize() -> void:
	_requested = false
	if Engine.is_editor_hint() or not preload_threaded or scene != null or scene_file.is_empty():
		return
	if ResourceLoader.load_threaded_request(scene_file) == OK:
		_requested = true


func _on_play(_feedback_intensity: float) -> void:
	if Engine.is_editor_hint() or player == null or not player.is_inside_tree():
		return
	var tree := player.get_tree()
	match action:
		Action.RELOAD_CURRENT:
			var error := tree.reload_current_scene()
			if error != OK:
				push_warning("JuiceLoadScene: could not reload the scene (%s)." % error_string(error))
		Action.CHANGE_SCENE:
			var packed := _get_packed()
			if packed == null:
				return
			var error := tree.change_scene_to_packed(packed)
			if error != OK:
				push_warning("JuiceLoadScene: could not change the scene (%s)." % error_string(error))
		Action.ADD_CHILD:
			var packed := _get_packed()
			var parent := resolve(add_to) if not add_to.is_empty() else tree.current_scene
			if packed != null and parent != null:
				parent.add_child(packed.instantiate())
		Action.REMOVE_CHILD:
			var node := resolve(node_to_remove)
			if node != null and node != player:
				node.queue_free()


func _get_packed() -> PackedScene:
	if scene != null:
		return scene
	if scene_file.is_empty():
		push_warning("JuiceLoadScene: set a scene or a scene file.")
		return null
	var resource: Resource
	if _requested:
		resource = ResourceLoader.load_threaded_get(scene_file)
		_requested = false
	else:
		resource = load(scene_file)
	if resource is PackedScene:
		return resource
	push_warning("JuiceLoadScene: '%s' is not a scene." % scene_file)
	return null
