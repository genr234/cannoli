class_name QuestPlayerEntityType
extends QuestEntityType
## The entity type that represents the player (the quester) in verb requirements and effects.

## The most recently created or loaded player entity type.
static var instance: QuestPlayerEntityType


func _init() -> void:
	instance = self
