class_name QuestSetIndicatorAction
extends QuestAction
## Sets a quest's indicator state on an entity.

## ID of the quest the indicator state applies to, or blank for this quest.
@export var quest_id := ""
## ID of the entity whose indicator to set, or blank to set the quest giver.
@export var entity_id := ""
## Indicator state to set on the entity.
@export var indicator_state := Quest.IndicatorState.NONE


func get_runtime_entity_id() -> String:
	if entity_id.is_empty() and quest != null:
		return quest.quest_giver_id
	return QuestTags.replace_tags(entity_id, quest)


func get_editor_name() -> String:
	if entity_id.is_empty():
		return "Set Indicator"
	return "Set Indicator: %s %s %s" % [quest_id, entity_id, String(Quest.IndicatorState.keys()[indicator_state]).capitalize()]


func execute() -> void:
	var affected: Quest = quest
	if not quest_id.is_empty():
		affected = Quests.get_quest_instance(quest_id, entity_id)
		if affected == null:
			affected = Quests.get_quest_instance(quest_id)
	if affected == null:
		return
	affected.set_indicator_state(get_runtime_entity_id(), indicator_state)
