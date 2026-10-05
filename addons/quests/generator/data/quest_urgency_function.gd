class_name QuestUrgencyFunction
extends Resource
## Base class for functions that tell a quest generator how urgent an entity
## is. Higher values are more urgent.

## Description of this urgency function, for your own reference.
@export_multiline var description := ""


## A short name for this function type.
func get_type_name() -> String:
	return "Urgency Function"


## Returns the urgency of [member QuestWorldModel.observed] to
## [member QuestWorldModel.observer].
func compute(_world_model: QuestWorldModel) -> float:
	return 0.0


## Validates a world model for use by urgency functions. Logs an error and
## returns false if the observer, the observed fact, or their entity types are missing.
func _validate(world_model: QuestWorldModel) -> bool:
	if world_model == null:
		push_error("Quests: Internal error - world model is null.")
	elif world_model.observer == null:
		push_error("Quests: Internal error - world model observer is null.")
	elif world_model.observer.entity_type == null:
		push_error("Quests: Observer's entity type is null. Do you need to assign an entity type to it?")
	elif world_model.observed == null:
		push_error("Quests: Internal error - world model observed entity is null.")
	elif world_model.observed.entity_type == null:
		push_error("Quests: Observed entity's entity type is null. Do you need to assign an entity type to it?")
	else:
		return true
	return false
