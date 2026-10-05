class_name QuestPlayerEntityType
extends QuestEntityType
## The entity type that represents the player (the quester) in verb requirements and effects.

## The most recently created or loaded player entity type. Held weakly.
static var instance: QuestPlayerEntityType:
	get:
		return _instance_ref.get_ref() as QuestPlayerEntityType if _instance_ref != null else null
	set(value):
		_instance_ref = weakref(value) if value != null else null

static var _instance_ref: WeakRef


func _init() -> void:
	instance = self


## Forgets the player entity type.
static func reset_static_state() -> void:
	_instance_ref = null
