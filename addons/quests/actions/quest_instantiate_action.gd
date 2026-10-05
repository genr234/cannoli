class_name QuestInstantiateAction
extends QuestAction
## Instantiates a scene. The original's InstantiatePrefab action.

## Scene to instantiate.
@export var scene: PackedScene
## Group name, [QuestIdentity] id or node name of a node (usually a Marker2D or
## Marker3D) whose position and rotation the instance copies.
@export var location := ""
## Group name, [QuestIdentity] id or node name of the node to add the instance
## to. Blank adds it to the current scene.
@export var parent := ""
## Give the instance its scene's own name instead of a unique one.
@export var use_original_name := false


func get_editor_name() -> String:
	if scene == null:
		return "Instantiate"
	var scene_name := scene.resource_path.get_file().get_basename()
	if location.is_empty():
		return "Instantiate: " + scene_name
	return "Instantiate: %s at %s" % [scene_name, location]


func execute() -> void:
	if scene == null:
		return
	var instance := scene.instantiate()
	var tree := QuestSceneLookup.get_tree()
	if tree == null:
		instance.free()
		return
	var parent_node := QuestSceneLookup.find_node(parent) if not parent.is_empty() else null
	if parent_node == null:
		parent_node = tree.current_scene if tree.current_scene != null else tree.root
	if use_original_name:
		instance.name = scene.get_state().get_node_name(0)
	parent_node.add_child(instance, use_original_name)
	var location_node := QuestSceneLookup.find_node(location) if not location.is_empty() else null
	if location_node != null:
		_copy_transform(location_node, instance)
	if Quests.debug:
		print("Quests: Instantiated '%s'." % instance.name)


func _copy_transform(from: Node, to: Node) -> void:
	if from is Node3D and to is Node3D:
		to.global_transform = Transform3D(from.global_transform.basis.orthonormalized(), from.global_position)
	elif from is Node2D and to is Node2D:
		to.global_position = from.global_position
		to.global_rotation = from.global_rotation
	elif from is Control and to is Control:
		to.global_position = from.global_position
	elif from is Node2D and to is Control:
		to.global_position = from.global_position
	elif from is Node3D and to is Node2D:
		to.global_position = Vector2(from.global_position.x, from.global_position.y)
