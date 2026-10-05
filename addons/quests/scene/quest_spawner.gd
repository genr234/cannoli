class_name QuestSpawner
extends Node
## Spawns scenes in 2D or 3D, around the spawner or at spawn points.
##
## Put it under a Node2D or Node3D (or set [member origin]). Spawn points are
## [Marker2D]/[Marker3D] children, plus any nodes in [member spawnpoints]. Start,
## stop and despawn it with [QuestControlSpawnerAction] or the matching
## [QuestMessages] messages, using [member spawner_name].

enum PositionType { RADIUS, SPAWNPOINTS }
enum SpawnPlane { X_Z, X_Y }

## Name by which quests can reference this spawner.
@export var spawner_name := ""
## Scenes to spawn.
@export var prefabs: Array[PackedScene] = []
## Relative probability of each scene in [member prefabs]. Missing entries count as 1.
@export var prefab_weights: PackedFloat32Array = PackedFloat32Array()
@export_group("Position")
## Position in a radius around the origin or at spawn points.
@export var position_type := PositionType.RADIUS
## If radius, the maximum distance from the origin at which to spawn entities.
@export var radius := 10.0
## If radius in 3D, the X-Z plane (ground) or the X-Y plane. 2D always uses X-Y.
@export var plane := SpawnPlane.X_Z
## If spawn points, extra nodes (Node2D or Node3D) to place entities at, in addition to Marker children.
@export var spawnpoints: Array[NodePath] = []
## The node whose position is the spawner's. If empty, the nearest Node2D/Node3D ancestor.
@export var origin: Node
@export_group("")
## Make spawned entities children of the current scene instead of children of the spawner.
@export var spawn_as_root_objects := false
## Minimum number of entities to spawn.
@export var min_count := 1
## Maximum number of entities to spawn.
@export var max_count := 5
## Once above the minimum, spawn one entity at this frequency in seconds.
@export var spawn_rate := 5.0
## Start spawning as soon as this node is ready.
@export var auto_start := false
## If auto start is on, wait a few frames so saved game data can be applied first.
@export var auto_start_after_save_data_applied := false
## Stop spawning as soon as the minimum number of entities has been reached.
@export var stop_when_min_reached := true
## Despawn all spawned entities when this node is removed.
@export var despawn_on_destroy := false

## Entities that have been spawned. When using spawn points, an entry is null for an empty point.
var spawned_entities: Array[QuestSpawnedEntity] = []
## The number of entities spawned.
var spawn_count := 0

static var _spawners: Array[QuestSpawner] = []

var _run_id := 0
var _spawn_markers: Array[Node] = []


## Returns the spawner with the given name, or null.
static func find_spawner(name_to_find: String) -> QuestSpawner:
	for spawner in _spawners:
		if is_instance_valid(spawner) and spawner.spawner_name == name_to_find:
			return spawner
	return null


func _enter_tree() -> void:
	if not _spawners.has(self):
		_spawners.append(self)


func _ready() -> void:
	QuestMessages.add_listener(self, QuestMessages.START_SPAWNER, spawner_name, _on_message)
	QuestMessages.add_listener(self, QuestMessages.STOP_SPAWNER, spawner_name, _on_message)
	QuestMessages.add_listener(self, QuestMessages.DESPAWN_SPAWNER, spawner_name, _on_message)
	if auto_start:
		if auto_start_after_save_data_applied:
			_start_after_save_data_applied()
		else:
			start_spawning()


func _exit_tree() -> void:
	_spawners.erase(self)
	_run_id += 1
	QuestMessages.remove_listener(self)
	if despawn_on_destroy:
		despawn_all()


func _start_after_save_data_applied() -> void:
	for i in 3:
		await get_tree().process_frame
	start_spawning()


func _on_message(args: QuestMessageArgs) -> void:
	match args.message:
		QuestMessages.START_SPAWNER:
			start_spawning()
		QuestMessages.STOP_SPAWNER:
			stop_spawning()
		QuestMessages.DESPAWN_SPAWNER:
			despawn_all()


## Starts spawning. Spawns up to the minimum, then continues at the spawn rate
## unless [member stop_when_min_reached].
func start_spawning() -> void:
	_run_id += 1
	_spawn_loop(_run_id)


## Stops spawning. Existing entities stay.
func stop_spawning() -> void:
	_run_id += 1


## Stops spawning and destroys every spawned entity.
func despawn_all() -> void:
	_run_id += 1
	for i in spawned_entities.size():
		var entity := spawned_entities[i]
		if entity == null or not is_instance_valid(entity):
			continue
		if entity.disabled.is_connected(_on_spawned_entity_disabled):
			entity.disabled.disconnect(_on_spawned_entity_disabled)
		_destroy_entity(entity)
	spawned_entities.clear()
	spawn_count = 0


## Registers an entity that was restored from saved data.
func add_restored_entity(entity: QuestSpawnedEntity) -> void:
	if entity == null:
		return
	spawned_entities.append(entity)
	_watch(entity)
	spawn_count += 1


## Returns the data to save: the scene path and position of every spawned entity.
func record_data() -> Dictionary:
	var entries: Array = []
	for i in spawned_entities.size():
		var entity := spawned_entities[i]
		if entity == null or not is_instance_valid(entity):
			continue
		var node := entity.get_spawned_node()
		var entry := {"scene": node.scene_file_path, "index": i}
		if node is Node3D:
			var p: Vector3 = node.global_position
			entry["position"] = [p.x, p.y, p.z]
		elif node is Node2D:
			var p2: Vector2 = node.global_position
			entry["position"] = [p2.x, p2.y]
		entries.append(entry)
	return {"entities": entries}


## Replaces the spawned entities with the saved ones.
func apply_data(data: Dictionary) -> void:
	despawn_all()
	_prepare_spawnpoints()
	for entry in data.get("entities", []):
		var scene := load(str(entry.get("scene", ""))) as PackedScene
		if scene == null:
			continue
		var entity := _spawn_scene(scene)
		if entity == null:
			continue
		var position: Array = entry.get("position", [])
		var node := entity.get_spawned_node()
		if node is Node3D and position.size() == 3:
			node.global_position = Vector3(position[0], position[1], position[2])
		elif node is Node2D and position.size() == 2:
			node.global_position = Vector2(position[0], position[1])
		spawn_count += 1
		if position_type == PositionType.RADIUS:
			spawned_entities.append(entity)
		else:
			var index := int(entry.get("index", -1))
			if index >= 0 and index < spawned_entities.size():
				spawned_entities[index] = entity
			else:
				spawned_entities.append(entity)


func _spawn_loop(run_id: int) -> void:
	_prepare_spawnpoints()
	while run_id == _run_id and is_inside_tree():
		for i in range(spawn_count, min_count):
			_spawn_and_place_entity()
		if stop_when_min_reached:
			return
		await get_tree().create_timer(spawn_rate).timeout
		if run_id != _run_id:
			return
		if spawn_count < max_count:
			_spawn_and_place_entity()


func _prepare_spawnpoints() -> void:
	if position_type == PositionType.RADIUS:
		spawn_count = 0
		for entity in spawned_entities:
			if entity != null and is_instance_valid(entity):
				spawn_count += 1
				_watch(entity)
		return
	_spawn_markers = _collect_spawnpoints()
	while spawned_entities.size() < _spawn_markers.size():
		spawned_entities.append(null)
	spawn_count = 0
	for i in _spawn_markers.size():
		var existing := _spawn_markers[i].get_node_or_null("QuestSpawnedEntity") as QuestSpawnedEntity
		if existing == null:
			existing = _find_entity_child(_spawn_markers[i])
		if existing != null:
			# A spawn point that already holds an entity: record the entity and
			# leave an empty marker at its position.
			spawned_entities[i] = existing
			_watch(existing)
			spawn_count += 1
			_spawn_markers[i] = _replace_with_marker(existing.get_spawned_node(), i)
		elif spawned_entities[i] != null and is_instance_valid(spawned_entities[i]):
			spawn_count += 1


func _find_entity_child(node: Node) -> QuestSpawnedEntity:
	for child in node.get_children():
		if child is QuestSpawnedEntity:
			return child
	return null


func _replace_with_marker(entity_node: Node, index: int) -> Node:
	var marker: Node
	if entity_node is Node3D:
		marker = Marker3D.new()
		add_child(marker)
		marker.global_transform = entity_node.global_transform
	elif entity_node is Node2D:
		marker = Marker2D.new()
		add_child(marker)
		marker.global_transform = entity_node.global_transform
	else:
		marker = Node.new()
		add_child(marker)
	marker.name = "Spawnpoint %d" % index
	return marker


func _collect_spawnpoints() -> Array[Node]:
	var points: Array[Node] = []
	for child in get_children():
		if child is Marker2D or child is Marker3D:
			points.append(child)
	for path in spawnpoints:
		var node := get_node_or_null(path)
		if node != null and not points.has(node):
			points.append(node)
	return points


func _spawn_and_place_entity() -> void:
	if not _is_there_space_for_entity():
		return
	var scene := _choose_weighted_random_prefab()
	if scene == null:
		push_warning("Quests: A prefab entry is blank in spawner '%s'. Not spawning." % spawner_name)
		return
	var entity := _spawn_scene(scene)
	if entity == null:
		return
	spawn_count += 1
	_place_spawned_entity(entity)


func _spawn_scene(scene: PackedScene) -> QuestSpawnedEntity:
	var instance := scene.instantiate()
	var parent_node: Node = self
	if spawn_as_root_objects:
		parent_node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	parent_node.add_child(instance)
	var entity := _find_entity_child(instance)
	if entity == null:
		entity = QuestSpawnedEntity.new()
		entity.name = "QuestSpawnedEntity"
		instance.add_child(entity)
	entity.spawner_name = spawner_name
	_watch(entity)
	return entity


func _watch(entity: QuestSpawnedEntity) -> void:
	if not entity.disabled.is_connected(_on_spawned_entity_disabled):
		entity.disabled.connect(_on_spawned_entity_disabled)


func _is_there_space_for_entity() -> bool:
	if position_type == PositionType.RADIUS:
		return true
	return spawned_entities.any(func(e: QuestSpawnedEntity) -> bool: return e == null or not is_instance_valid(e))


func _place_spawned_entity(entity: QuestSpawnedEntity) -> void:
	if position_type == PositionType.RADIUS:
		_place_in_radius(entity)
	else:
		_place_in_spawnpoint(entity)


func _get_origin() -> Node:
	if origin != null:
		return origin
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Node2D or ancestor is Node3D:
			return ancestor
		ancestor = ancestor.get_parent()
	return null


func _place_in_radius(entity: QuestSpawnedEntity) -> void:
	var rand1 := randf_range(-radius, radius)
	var rand2 := randf_range(-radius, radius)
	var node := entity.get_spawned_node()
	var origin_node := _get_origin()
	if node is Node3D:
		var base: Vector3 = origin_node.global_position if origin_node is Node3D else Vector3.ZERO
		node.global_position = base + (Vector3(rand1, 0, rand2) if plane == SpawnPlane.X_Z else Vector3(rand1, rand2, 0))
	elif node is Node2D:
		var base2: Vector2 = origin_node.global_position if origin_node is Node2D else Vector2.ZERO
		node.global_position = base2 + Vector2(rand1, rand2)
	spawned_entities.append(entity)


func _place_in_spawnpoint(entity: QuestSpawnedEntity) -> void:
	var available: Array[int] = []
	for i in spawned_entities.size():
		if spawned_entities[i] == null or not is_instance_valid(spawned_entities[i]):
			available.append(i)
	if available.is_empty():
		return
	var index := available[randi() % available.size()]
	spawned_entities[index] = entity
	var point := _spawn_markers[mini(index, _spawn_markers.size() - 1)] if not _spawn_markers.is_empty() else null
	var node := entity.get_spawned_node()
	if point == null:
		return
	if node is Node3D and point is Node3D:
		node.global_transform = point.global_transform
	elif node is Node2D and point is Node2D:
		node.global_transform = point.global_transform


func _remove_entity(entity: QuestSpawnedEntity) -> void:
	if entity == null:
		return
	spawn_count -= 1
	if position_type == PositionType.RADIUS:
		spawned_entities.erase(entity)
	else:
		for i in spawned_entities.size():
			if spawned_entities[i] == entity:
				spawned_entities[i] = null


func _choose_weighted_random_prefab() -> PackedScene:
	if prefabs.is_empty():
		return null
	var total := 0.0
	for i in prefabs.size():
		total += _weight(i)
	var remaining := randf_range(0.0, total)
	for i in prefabs.size():
		remaining -= _weight(i)
		if remaining <= 0.0:
			return prefabs[i]
	return prefabs[0]


func _weight(index: int) -> float:
	return prefab_weights[index] if index < prefab_weights.size() else 1.0


func _destroy_entity(entity: QuestSpawnedEntity) -> void:
	var node := entity.get_spawned_node()
	if node != null:
		node.queue_free()


func _on_spawned_entity_disabled(entity: QuestSpawnedEntity) -> void:
	_remove_entity(entity)
