class_name QuestSetTrackingAction
extends QuestAction
## Sets whether a quest is tracked in the HUD.

## ID of the quest, or blank for this quest.
@export var quest_id := ""
## ID of the entity (quester) that has the quest, or blank for any.
@export var entity_id := ""
## Track the quest in the HUD.
@export var show_in_track_hud := true


func get_runtime_entity_id() -> String:
	if entity_id.is_empty() and quest != null:
		return quest.quest_giver_id
	return QuestTags.replace_tags(entity_id, quest)


func get_editor_name() -> String:
	if entity_id.is_empty():
		return "Set Tracking"
	return "Set Tracking: %s %s %s" % [quest_id, entity_id, str(show_in_track_hud)]


func execute() -> void:
	var affected: Quest = quest
	if not quest_id.is_empty():
		affected = Quests.get_quest_instance(quest_id, entity_id)
		if affected == null:
			affected = Quests.get_quest_instance(quest_id)
	if affected == null:
		return
	affected.show_in_track_hud = show_in_track_hud
