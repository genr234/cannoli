@tool
@icon("res://addons/juice/icons/visual.svg")
class_name JuiceParticles
extends JuiceFeedback
## Plays, stops or bursts particles, or spawns a particles scene where something happened.
##
## EXISTING works on a [GPUParticles2D], [GPUParticles3D], [CPUParticles2D] or
## [CPUParticles3D] (the target, or its particle children). SPAWN_SCENE creates an instance of
## a scene at the play position, restarts every particle node in it, and returns it to a pool
## when [member lifetime] is over. Spawning does nothing in the editor.

## What the feedback does.
enum Method {
	## Controls particles that are already in the scene.
	EXISTING,
	## Spawns a scene with particles in it.
	SPAWN_SCENE,
}
## What to do to existing particles.
enum Action {
	## Restarts the particles and emits.
	PLAY,
	## Stops emitting.
	STOP,
	## Emits a single burst (turns on one shot and restarts).
	BURST,
}
## Where a spawned scene is added.
enum SpawnParent {
	## The current scene.
	SCENE,
	## The target of this feedback.
	TARGET,
	## The root of the viewport, which keeps the particles alive when the target is freed.
	VIEWPORT,
}
## Where a spawned scene appears.
enum SpawnAt {
	## At the world position the player was asked to play at.
	PLAY_POSITION,
	## At the target node.
	TARGET,
}

@export_group("Particles")
## Control existing particles or spawn a scene.
@export var method: Method = Method.EXISTING:
	set(value):
		method = value
		notify_property_list_changed()
@export_group("Existing Particles")
## What to do.
@export var action: Action = Action.PLAY
## Also affects particle nodes below the target when the target is not a particle node.
@export var include_children: bool = true
## Seconds to keep emitting before stopping, for PLAY. 0 leaves them emitting.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var emit_time: float = 0.0
## Scales the amount of GPU particles by the intensity of the play.
@export var scale_amount_by_intensity: bool = false
@export_group("Spawn Scene")
## The scene to spawn.
@export var scene: PackedScene
## Seconds before the spawned scene is removed. 0 keeps it until the feedback is restored.
@export_range(0.0, 30.0, 0.01, "or_greater", "suffix:s") var lifetime: float = 2.0
## Where the scene appears.
@export var spawn_at: SpawnAt = SpawnAt.PLAY_POSITION
## Where the scene is added to the tree.
@export var spawn_parent: SpawnParent = SpawnParent.SCENE
## Moves the spawned scene by this much from its position. Only x and y apply in 2D.
@export var offset: Vector3 = Vector3.ZERO
## Copies the rotation of the target to the spawned scene.
@export var match_target_rotation: bool = false
## Reuses spawned scenes instead of creating a new one each time.
@export var use_pool: bool = true
## The most scenes kept in the pool.
@export_range(1, 64, 1, "or_greater") var pool_size: int = 8

var _initial: Dictionary = {}
var _spawned: Array[Node] = []
var _emit_left := 0.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	var hidden := false
	match prop_name:
		"Existing Particles", "action", "include_children", "emit_time", "scale_amount_by_intensity":
			hidden = method != Method.EXISTING
		"Spawn Scene", "scene", "lifetime", "spawn_at", "spawn_parent", "offset", "match_target_rotation", "use_pool", "pool_size":
			hidden = method != Method.SPAWN_SCENE
	if hidden:
		if property.usage & PROPERTY_USAGE_GROUP:
			property.usage = PROPERTY_USAGE_NONE
		else:
			property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	if method == Method.SPAWN_SCENE:
		return lifetime
	return emit_time if action == Action.PLAY else 0.0


func _on_initialize() -> void:
	_capture()


func _on_play(_feedback_intensity: float) -> void:
	if method == Method.SPAWN_SCENE:
		_spawn()
		return
	for node in _collect():
		match action:
			Action.PLAY:
				_set_burst(node, false)
				_scale_amount(node)
				node.set("emitting", true)
				if node.has_method("restart"):
					node.call("restart")
			Action.STOP:
				node.set("emitting", false)
			Action.BURST:
				_set_burst(node, true)
				_scale_amount(node)
				node.set("emitting", true)
				if node.has_method("restart"):
					node.call("restart")


func _on_finished() -> void:
	if method == Method.SPAWN_SCENE:
		if lifetime > 0.0:
			_release_spawned()
	elif action == Action.PLAY and emit_time > 0.0:
		for node in _collect():
			node.set("emitting", false)


func _on_stop() -> void:
	if method == Method.SPAWN_SCENE and lifetime > 0.0:
		_release_spawned()


func _on_restore() -> void:
	if method == Method.SPAWN_SCENE:
		_release_spawned()
		return
	for id: int in _initial:
		var node := instance_from_id(id) as Node
		if node == null:
			continue
		var saved: Dictionary = _initial[id]
		node.set("emitting", saved["emitting"])
		node.set("one_shot", saved["one_shot"])
		if saved.has("amount_ratio"):
			node.set("amount_ratio", saved["amount_ratio"])


func _is_particles(node: Node) -> bool:
	return node is GPUParticles2D or node is GPUParticles3D or node is CPUParticles2D or node is CPUParticles3D


func _collect_from(root: Node) -> Array[Node]:
	var found: Array[Node] = []
	if root == null:
		return found
	if _is_particles(root):
		found.append(root)
	elif include_children or method == Method.SPAWN_SCENE:
		for child in root.find_children("*", "", true, false):
			if _is_particles(child):
				found.append(child)
	return found


func _collect() -> Array[Node]:
	return _collect_from(get_target())


func _capture() -> void:
	_initial.clear()
	if method != Method.EXISTING:
		return
	for node in _collect():
		var saved := {"emitting": node.get("emitting"), "one_shot": node.get("one_shot")}
		if "amount_ratio" in node:
			saved["amount_ratio"] = node.get("amount_ratio")
		_initial[node.get_instance_id()] = saved


func _set_burst(node: Node, burst: bool) -> void:
	if burst:
		node.set("one_shot", true)
	elif _initial.has(node.get_instance_id()):
		node.set("one_shot", _initial[node.get_instance_id()]["one_shot"])


func _scale_amount(node: Node) -> void:
	if scale_amount_by_intensity and "amount_ratio" in node:
		node.set("amount_ratio", clampf(get_intensity(), 0.0, 1.0))


func _spawn() -> void:
	if scene == null or Engine.is_editor_hint() or player == null or not player.is_inside_tree():
		return
	var parent := _spawn_parent_node()
	if parent == null:
		return
	var instance: Node = JuiceNodePool.acquire(scene) if use_pool else scene.instantiate()
	if instance == null:
		return
	parent.add_child(instance)
	var target_node := get_target()
	var position := get_play_position() if spawn_at == SpawnAt.PLAY_POSITION or target_node == null else Juice.node_position(target_node)
	position += offset
	if instance is Node2D:
		(instance as Node2D).global_position = Vector2(position.x, position.y)
		if match_target_rotation and target_node is Node2D:
			(instance as Node2D).global_rotation = (target_node as Node2D).global_rotation
	elif instance is Node3D:
		(instance as Node3D).global_position = position
		if match_target_rotation and target_node is Node3D:
			(instance as Node3D).global_basis = (target_node as Node3D).global_basis
	for node in _collect_from(instance):
		node.set("emitting", true)
		if node.has_method("restart"):
			node.call("restart")
	_spawned.append(instance)


func _spawn_parent_node() -> Node:
	var tree := player.get_tree()
	match spawn_parent:
		SpawnParent.TARGET:
			var target_node := get_target()
			if target_node != null:
				return target_node
		SpawnParent.VIEWPORT:
			return player.get_viewport()
	return tree.current_scene if tree.current_scene != null else tree.root


func _release_spawned() -> void:
	for instance in _spawned:
		if not is_instance_valid(instance):
			continue
		if use_pool and scene != null:
			JuiceNodePool.release(scene, instance, pool_size)
		else:
			instance.queue_free()
	_spawned.clear()
