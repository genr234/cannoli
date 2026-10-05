class_name QuestRequirementFunction
extends Resource
## Base class for custom conditions that must be true for a generator to use a verb.


func get_type_name() -> String:
	return "Requirement Function"


func is_true(_world_model: QuestWorldModel) -> bool:
	return true
