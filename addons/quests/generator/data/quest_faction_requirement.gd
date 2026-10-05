class_name QuestFactionRequirement
extends QuestRequirementFunction
## Requires that one entity type's affinity for another is within a range.

## The judging entity.
@export var judge: QuestEntitySpecifier
## The entity being judged.
@export var subject: QuestEntitySpecifier
@export_range(-100.0, 100.0) var min_faction := 0.0
@export_range(-100.0, 100.0) var max_faction := 50.0


func get_type_name() -> String:
	return "Faction %s->%s is [%s,%s]" % [
		judge.get_type_name() if judge != null else "Unspecified",
		subject.get_type_name() if subject != null else "Unspecified",
		min_faction, max_faction]


func is_true(world_model: QuestWorldModel) -> bool:
	if judge == null or subject == null:
		return false
	var judge_type := judge.get_entity_type(world_model)
	var subject_type := subject.get_entity_type(world_model)
	if judge_type == null or subject_type == null:
		return false
	var affinity := QuestAffinity.get_affinity(judge_type, subject_type, world_model)
	return min_faction <= affinity and affinity <= max_faction
