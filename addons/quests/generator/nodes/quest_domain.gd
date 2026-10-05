@icon("../../icons/quest_domain.svg")
class_name QuestDomain
extends Node
## An area of the game world that quest generators observe for quest entities.
##
## Put it under (or next to) an [Area2D] or [Area3D] to track the entities that
## enter it, or list the entities yourself in [member entities]. A domain
## doesn't have to be a physical area: it can be anything that contains
## entities, such as an inventory.

## Emitted when an entity enters the domain.
signal entity_added(entity: QuestEntity)
## Emitted when an entity leaves the domain.
signal entity_removed(entity: QuestEntity)

## This domain's domain type.
@export var domain_type: QuestDomainType
## Entities currently in the domain.
@export var entities: Array[QuestEntity] = []
## Track bodies and areas that enter an [Area2D] or [Area3D] that is this node's
## parent or child.
@export var detect_areas := true


func _ready() -> void:
	if Engine.is_editor_hint() or not detect_areas:
		return
	var areas: Array[Node] = []
	var parent := get_parent()
	if parent is Area2D or parent is Area3D:
		areas.append(parent)
	for child in get_children():
		if child is Area2D or child is Area3D:
			areas.append(child)
	for area in areas:
		area.connect(&"body_entered", _on_node_entered)
		area.connect(&"body_exited", _on_node_exited)
		area.connect(&"area_entered", _on_node_entered)
		area.connect(&"area_exited", _on_node_exited)
	if not areas.is_empty():
		_scan_overlaps(areas)


# Physics isn't updated until a couple of frames after the scene loads.
func _scan_overlaps(areas: Array[Node]) -> void:
	var tree := get_tree()
	await tree.physics_frame
	await tree.physics_frame
	for area in areas:
		if not is_instance_valid(area):
			continue
		var overlapping: Array = area.get_overlapping_bodies()
		overlapping.append_array(area.get_overlapping_areas())
		for other in overlapping:
			_on_node_entered(other)


func _on_node_entered(node: Node) -> void:
	add_entity(find_entity(node))


func _on_node_exited(node: Node) -> void:
	remove_entity(find_entity(node))


## Finds the [QuestEntity] that is [param node] or is below it. A negative
## [param depth] searches all descendants.
static func find_entity(node: Node, depth := -1) -> QuestEntity:
	if node == null:
		return null
	if node is QuestEntity:
		return node
	if depth == 0:
		return null
	for child in node.get_children():
		var found := find_entity(child, depth - 1)
		if found != null:
			return found
	return null


## Adds an entity, if it isn't already in the domain. Emits [signal entity_added]
## every time it is called with an entity, as the original does.
func add_entity(entity: QuestEntity) -> void:
	if entity == null:
		return
	if not entities.has(entity):
		entities.append(entity)
		entity.despawned.connect(_on_despawned)
	entity_added.emit(entity)


func remove_entity(entity: QuestEntity) -> void:
	if entity == null:
		return
	entity_removed.emit(entity)
	_on_despawned(entity)


func _on_despawned(entity: QuestEntity) -> void:
	if entity == null:
		return
	entities.erase(entity)
	if entity.despawned.is_connected(_on_despawned):
		entity.despawned.disconnect(_on_despawned)


## Adds one fact to [param world_model] for each entity in the domain.
func add_entities_to_world_model(world_model: QuestWorldModel) -> void:
	if world_model == null:
		return
	for entity in entities:
		if is_instance_valid(entity):
			world_model.add_entity_type(domain_type, entity.entity_type, 1)
