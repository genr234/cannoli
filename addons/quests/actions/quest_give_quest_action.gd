class_name QuestGiveQuestAction
extends QuestAction
## Gives a quest to a quester and activates it. The quest's giver becomes the
## new quest's giver.

## ID of the quest to give.
@export var quest_id_to_give := ""
## ID of the quester. Leave blank to give to the default player journal.
@export var quester_id := ""


func get_editor_name() -> String:
	var quest_text := "'" + quest_id_to_give + "'" if not quest_id_to_give.is_empty() else "<none>"
	return "Give Quest %s to %s" % [quest_text, quester_id if not quester_id.is_empty() else "Player"]


func execute() -> void:
	if Quests.debug:
		print("Quests: " + get_editor_name())
	if quest_id_to_give.is_empty():
		return
	var runtime_quester := QuestTags.replace_tags(quester_id, quest)
	var instance: Quest
	if runtime_quester.is_empty():
		instance = Quests.give_quest(quest_id_to_give)
	else:
		instance = Quests.give_quest_to_quester(quest_id_to_give, runtime_quester)
	if instance == null or quest == null:
		return
	instance.quest_giver_id = quest.quest_giver_id
	if not quest.quest_giver_id.is_empty():
		instance.tag_dictionary[QuestTags.QUESTGIVERID] = quest.quest_giver_id
		instance.tag_dictionary[QuestTags.QUESTGIVER] = quest.tag_dictionary.get(QuestTags.QUESTGIVER, "")
