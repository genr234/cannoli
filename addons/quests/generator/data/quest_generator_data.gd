class_name QuestGeneratorData
extends RefCounted
## Static state shared by the quest generator: runtime drive values, global
## generator settings, and save/load of the runtime values.
##
## Drive values on entity types are authored in [member QuestEntityType.original_drive_values].
## At runtime each entity type gets its own copy, which can change during play
## and is saved by [method record_generator_data].

## How facts are weighted when a generator's own selection mode is "same as global".
static var global_goal_selection: QuestUrgentFactSelectionMode = QuestUrgentFactSelectionMode.create(
		QuestUrgentFactSelectionMode.Criterion.WEIGHTED, 1)
## The domain type that represents the player's inventory. If null, one is created on demand.
static var default_player_domain_type: QuestDomainType

static var _runtime_drive_values: Dictionary = {}
static var _known_types: Dictionary = {}


## The name of an asset: its resource name, or its file name without extension.
static func asset_name_of(resource: Resource) -> String:
	if resource == null:
		return ""
	if not resource.resource_name.is_empty():
		return resource.resource_name
	if not resource.resource_path.is_empty():
		return resource.resource_path.get_file().get_basename()
	return ""


## Stable key for saving an asset: its path if it has one, otherwise its name.
static func key_of(resource: Resource) -> String:
	if resource == null:
		return ""
	if not resource.resource_path.is_empty() and not resource.resource_path.contains("::"):
		return resource.resource_path
	return "name:" + asset_name_of(resource)


## Registers [method record_generator_data] and [method apply_generator_data]
## with [Quests] so that [method QuestManager.record_data] and
## [method QuestManager.apply_data] save and load the generator's runtime data.
static func wire_save_callbacks() -> void:
	if not Quests.generator_record_callback.is_valid():
		Quests.generator_record_callback = Callable(QuestGeneratorData, "record_generator_data")
	if not Quests.generator_apply_callback.is_valid():
		Quests.generator_apply_callback = Callable(QuestGeneratorData, "apply_generator_data")


## Applies [member default_player_domain_type] to [method QuestDomainType.set_player_domain_instance].
static func apply_settings() -> void:
	wire_save_callbacks()
	QuestDomainType.set_player_domain_instance(default_player_domain_type)


## Returns the runtime drive values for an entity type, creating them from the originals.
static func get_runtime_drive_values(entity_type: QuestEntityType) -> Array[QuestDriveValue]:
	var result: Array[QuestDriveValue] = []
	if entity_type == null:
		return result
	if not _runtime_drive_values.has(entity_type):
		var list: Array[QuestDriveValue] = []
		for dv in entity_type.original_drive_values:
			if dv != null:
				list.append(dv.copy())
		_runtime_drive_values[entity_type] = list
		_known_types[key_of(entity_type)] = entity_type
		wire_save_callbacks()
	return _runtime_drive_values[entity_type]


static func set_runtime_drive_values(entity_type: QuestEntityType, values: Array[QuestDriveValue]) -> void:
	if entity_type == null:
		return
	_runtime_drive_values[entity_type] = values
	_known_types[key_of(entity_type)] = entity_type
	wire_save_callbacks()


## Discards all runtime drive values, restoring the authored ones.
static func reset_runtime_data() -> void:
	_runtime_drive_values.clear()


## Records the runtime drive values of every entity type that has them.
## Returns only bools, numbers, strings, arrays and dictionaries.
static func record_generator_data() -> Dictionary:
	var types := {}
	for entity_type: QuestEntityType in _runtime_drive_values:
		if not is_instance_valid(entity_type):
			continue
		var values := {}
		for dv: QuestDriveValue in _runtime_drive_values[entity_type]:
			if dv == null or dv.drive == null:
				continue
			values[key_of(dv.drive)] = dv.value
		types[key_of(entity_type)] = values
	return {"version": 1, "entity_types": types}


## Restores values saved by [method record_generator_data]. Entity types are
## found by path, or by name among entity types used so far.
static func apply_generator_data(data: Dictionary) -> void:
	if data.is_empty():
		return
	var types: Dictionary = data.get("entity_types", {})
	for key: String in types:
		var entity_type := _find_entity_type(key)
		if entity_type == null:
			continue
		var saved: Dictionary = types[key]
		for dv in get_runtime_drive_values(entity_type):
			if dv == null or dv.drive == null:
				continue
			var drive_key := key_of(dv.drive)
			if saved.has(drive_key):
				dv.value = float(saved[drive_key])


## Registers an entity type so [method apply_generator_data] can find it by name
## even if it has no file path.
static func register_entity_type(entity_type: QuestEntityType) -> void:
	if entity_type != null:
		_known_types[key_of(entity_type)] = entity_type


static func _find_entity_type(key: String) -> QuestEntityType:
	if _known_types.has(key) and is_instance_valid(_known_types[key]):
		return _known_types[key]
	if key.begins_with("res://") and ResourceLoader.exists(key):
		var loaded := load(key) as QuestEntityType
		if loaded != null:
			_known_types[key] = loaded
		return loaded
	return null
