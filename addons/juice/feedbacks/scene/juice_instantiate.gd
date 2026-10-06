@tool
@icon("res://addons/juice/icons/scene.svg")
class_name JuiceInstantiate
extends JuiceFeedback
## Spawns a scene, for example a particle burst or a floating number.
##
## The scene is placed at the play position, at a node or at a fixed point, with an
## optional offset and random spread. It can live for a fixed time and then be freed,
## and it can come from a pool so repeated plays do not create new nodes. Nothing is
## spawned in the editor.

## PLAY_POSITION uses the position the player was asked to play at (the parent
## when none was given). NODE uses [member position_node]. WORLD uses [member world_position].
enum PositionMode { PLAY_POSITION, NODE, WORLD }
## What happens when every pooled instance is still in use.
enum PoolFull { RECYCLE_OLDEST, GROW, SKIP }

@export_group("Instantiate")
## The scene to spawn.
@export var scene: PackedScene
## Where the scene appears.
@export var position_mode: PositionMode = PositionMode.PLAY_POSITION:
	set(value):
		position_mode = value
		notify_property_list_changed()
## The node to spawn at when the mode is NODE. Path is relative to the player. In the
## other modes it is only used for the rotation and scale to copy.
@export var position_node: NodePath
## The point to spawn at when the mode is WORLD. 2D uses x and y.
@export var world_position: Vector3 = Vector3.ZERO
## Added to the position.
@export var offset: Vector3 = Vector3.ZERO
## Copies the rotation of the reference node (the position node or the player's parent).
@export var also_apply_rotation: bool = false
## Copies the scale of the reference node.
@export var also_apply_scale: bool = false
## Adds a random value to the position.
@export var randomize_position: bool = false:
	set(value):
		randomize_position = value
		notify_property_list_changed()
## The lowest random value on each axis.
@export var random_offset_min: Vector3 = Vector3.ZERO
## The highest random value on each axis.
@export var random_offset_max: Vector3 = Vector3.ONE
@export_group("Lifetime")
## The node that receives the spawned scene. Empty adds it to the current scene.
@export var parent: NodePath
## Frees the instance after this many seconds. 0 keeps it. A pooled instance goes back
## to the pool instead of being freed.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var lifetime: float = 0.0
## Counts the lifetime in real time, ignoring the engine time scale.
@export var lifetime_unscaled: bool = false
@export_group("Pool")
## Keeps a set of ready made instances and reuses them.
@export var use_pool: bool = false:
	set(value):
		use_pool = value
		notify_property_list_changed()
## How many instances are created when the player initializes.
@export_range(1, 64, 1, "or_greater") var pool_size: int = 5
## What to do when all pooled instances are in use.
@export var when_pool_full: PoolFull = PoolFull.RECYCLE_OLDEST

var _pool: Array[Node] = []
var _in_use: Array[Node] = []
var _last: Node


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "position_node" and position_mode == PositionMode.WORLD:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "world_position" and position_mode != PositionMode.WORLD:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["random_offset_min", "random_offset_max"] and not randomize_position:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["pool_size", "when_pool_full"] and not use_pool:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _notification(what: int) -> void:
	# Pooled instances that never entered the tree would leak.
	if what == NOTIFICATION_PREDELETE:
		for instance in _pool:
			if is_instance_valid(instance) and not instance.is_inside_tree():
				instance.free()


func _has_randomness() -> bool:
	return false


func _has_target() -> bool:
	return false


## The scene spawned by the last play, or null.
func get_last_instance() -> Node:
	return _last if is_instance_valid(_last) else null


func _on_initialize() -> void:
	_pool.clear()
	_in_use.clear()
	_last = null
	if not use_pool or scene == null or Engine.is_editor_hint():
		return
	for i in pool_size:
		_pool.append(_create_pooled())


func _on_play(_feedback_intensity: float) -> void:
	if scene == null or Engine.is_editor_hint() or player == null or not player.is_inside_tree():
		return
	var instance := _acquire()
	if instance == null:
		return
	_last = instance
	var parent_node := _spawn_parent()
	if parent_node == null:
		return
	if instance.get_parent() != parent_node:
		if instance.get_parent() != null:
			instance.get_parent().remove_child(instance)
		parent_node.add_child(instance)
	_place(instance)
	if use_pool:
		_set_pooled_active(instance, true)
	if lifetime > 0.0:
		var timer := player.get_tree().create_timer(lifetime, true, false, lifetime_unscaled)
		timer.timeout.connect(_on_lifetime_over.bind(instance))


func _on_restore() -> void:
	# Only hand pooled instances back, spawned scenes are left alone.
	for instance in _in_use.duplicate():
		_release(instance)


func _spawn_parent() -> Node:
	if not parent.is_empty():
		return resolve(parent)
	var tree := player.get_tree()
	return tree.current_scene if tree.current_scene != null else tree.root


func _acquire() -> Node:
	if not use_pool:
		return scene.instantiate()
	for i in range(_in_use.size() - 1, -1, -1):
		if not is_instance_valid(_in_use[i]):
			_in_use.remove_at(i)
	for instance in _pool:
		if is_instance_valid(instance) and not _in_use.has(instance):
			_in_use.append(instance)
			return instance
	match when_pool_full:
		PoolFull.GROW:
			var created := _create_pooled()
			_pool.append(created)
			_in_use.append(created)
			return created
		PoolFull.RECYCLE_OLDEST:
			if not _in_use.is_empty():
				var oldest: Node = _in_use.pop_front()
				_in_use.append(oldest)
				return oldest
	return null


func _create_pooled() -> Node:
	var instance := scene.instantiate()
	instance.set_meta(&"juice_process_mode", instance.process_mode)
	_set_pooled_active(instance, false)
	return instance


# Hides a pooled instance and stops its processing, or brings it back.
func _set_pooled_active(instance: Node, active: bool) -> void:
	if "visible" in instance:
		instance.visible = active
	if active:
		instance.process_mode = instance.get_meta(&"juice_process_mode", Node.PROCESS_MODE_INHERIT)
	else:
		instance.process_mode = Node.PROCESS_MODE_DISABLED


func _release(instance: Node) -> void:
	_in_use.erase(instance)
	if is_instance_valid(instance):
		_set_pooled_active(instance, false)


func _on_lifetime_over(instance: Node) -> void:
	if not is_instance_valid(instance):
		return
	if use_pool and _pool.has(instance):
		_release(instance)
	else:
		instance.queue_free()


# Places the instance in the world according to the position mode.
func _place(instance: Node) -> void:
	var reference := _reference_node()
	var point := _spawn_point(reference) + offset
	if randomize_position:
		point += Vector3(
			randf_range(random_offset_min.x, random_offset_max.x),
			randf_range(random_offset_min.y, random_offset_max.y),
			randf_range(random_offset_min.z, random_offset_max.z))
	if instance is Node3D:
		var node_3d := instance as Node3D
		node_3d.global_position = point
		if also_apply_rotation and reference is Node3D:
			node_3d.global_basis = (reference as Node3D).global_basis.orthonormalized()
		if also_apply_scale and reference is Node3D:
			node_3d.scale = (reference as Node3D).scale
	elif instance is Node2D:
		var node_2d := instance as Node2D
		node_2d.global_position = Vector2(point.x, point.y)
		if also_apply_rotation and reference is Node2D:
			node_2d.global_rotation = (reference as Node2D).global_rotation
		if also_apply_scale and reference is Node2D:
			node_2d.scale = (reference as Node2D).scale
	elif instance is Control:
		var control := instance as Control
		control.global_position = Vector2(point.x, point.y)
		if also_apply_rotation and reference is CanvasItem:
			control.rotation = (reference as CanvasItem).get_global_transform().get_rotation()
		if also_apply_scale and reference is Control:
			control.scale = (reference as Control).scale


func _reference_node() -> Node:
	if position_mode == PositionMode.NODE:
		return resolve(position_node)
	if not position_node.is_empty():
		return resolve(position_node)
	return player.get_parent()


func _spawn_point(reference: Node) -> Vector3:
	match position_mode:
		PositionMode.NODE:
			return Juice.node_position(reference)
		PositionMode.WORLD:
			return world_position
	return get_play_position()
