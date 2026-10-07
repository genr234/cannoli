@tool
@icon("res://addons/behaviors/icons/node.svg")
class_name BehaviorInstantiateScene
extends BehaviorAction
## Creates an instance of a scene, adds it to the tree, and can store it in a variable.

## The scene to create.
@export var scene: PackedScene
## The node that becomes the parent, relative to the actor. Empty uses the current
## scene.
@export var parent: NodePath = NodePath()
## A variable holding the parent node. Replaces [member parent] when set.
@export var parent_variable: String = ""
## Starts at the actor's position.
@export var at_actor: bool = false
## A variable holding the position to start at, a Vector2 or Vector3. Added to
## [member at_actor] when both are set.
@export var position_variable: String = ""
## Added to the position. A 2D scene uses x and y.
@export var offset: Vector3 = Vector3.ZERO
## The variable that receives the new node.
@export var store_in: String = ""

const Targets := preload("res://addons/behaviors/actions/nodes/behavior_target_util.gd")


func _on_update(_delta: float) -> Status:
	if scene == null or actor == null or not actor.is_inside_tree():
		return Status.FAILURE
	var parent_node: Node
	if parent.is_empty() and parent_variable.is_empty():
		parent_node = actor.get_tree().current_scene
		if parent_node == null:
			parent_node = actor.get_tree().root
	else:
		parent_node = Targets.resolve(self, parent, parent_variable) as Node
	if parent_node == null:
		return Status.FAILURE
	var instance := scene.instantiate()
	if instance == null:
		return Status.FAILURE
	parent_node.add_child(instance)
	_place(instance)
	if not store_in.is_empty():
		set_var(StringName(store_in), instance)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if scene == null:
		warnings.append("Instantiate Scene has no scene.")
	return warnings


func _get_graph_text() -> String:
	return scene.resource_path.get_file().get_basename() if scene else ""


func _place(instance: Node) -> void:
	var base := Vector3.ZERO
	var spot: Variant = Targets.get_position_of(actor) if at_actor else null
	if spot != null:
		base = Vector3(spot.x, spot.y, spot.z if spot is Vector3 else 0.0)
	if not position_variable.is_empty():
		var held: Variant = get_var(StringName(position_variable))
		if held is Vector2:
			base += Vector3(held.x, held.y, 0.0)
		elif held is Vector3:
			base += held
	base += offset
	if instance is Node2D:
		instance.global_position = Vector2(base.x, base.y)
	elif instance is Node3D:
		instance.global_position = base
