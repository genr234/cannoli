class_name QuestThreatUrgency
extends QuestUrgencyFunction
## Urgency based on the observer's negative affinity for the observed entity.

## Multiply the urgency by this curve, where x is the number of entities the observer is aware of.
@export var entity_count_multiplier: Curve = QuestCurves.default_entity_count_multiplier()


func get_type_name() -> String:
	return "By Threat"


func compute(world_model: QuestWorldModel) -> float:
	if not _validate(world_model):
		return 0.0
	var affinity := QuestAffinity.get_affinity(world_model.observer.entity_type, world_model.observed.entity_type, world_model)
	return QuestCurves.evaluate(entity_count_multiplier, world_model.observed.count) * maxf(0.0, -affinity)
