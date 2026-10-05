class_name QuestSpawnedEntity
extends Node
## Marks a node that a [QuestSpawner] spawned. Added to the spawned node as a child.

## Emitted when the entity leaves the scene tree (destroyed, disabled by removal).
signal disabled(entity: QuestSpawnedEntity)

## Name of the spawner that spawned the entity.
@export var spawner_name := ""


## The spawned node.
func get_spawned_node() -> Node:
	return get_parent()


func _exit_tree() -> void:
	disabled.emit(self)


## Returns the data to save: the spawner's name.
func record_data() -> String:
	return spawner_name


## Restores the spawner name and registers with the spawner.
func apply_data(data: String) -> void:
	if data.is_empty():
		return
	spawner_name = data
	var spawner := QuestSpawner.find_spawner(spawner_name)
	if spawner != null:
		spawner.add_restored_entity(self)
