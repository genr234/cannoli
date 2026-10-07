@tool
@icon("res://addons/behaviors/icons/quest.svg")
class_name BehaviorSetQuestState
extends BehaviorAction
## Puts a quest in a state, such as active, successful or failed.
##
## Needs the Quests package. Fails, with one warning, when it is missing.

## The ID of the quest.
@export var quest_id: String = ""
## The state to set.
@export var state: BehaviorQuestStateIs.QuestState = BehaviorQuestStateIs.QuestState.ACTIVE
## The quester whose copy of the quest changes. Empty uses the default.
@export var quester_id: String = ""

var _warned: bool = false


func _on_update(_delta: float) -> Status:
	if not BehaviorsQuests.is_available():
		if not _warned:
			_warned = true
			push_warning("%s: the Quests package is not available." % get_display_name())
		return Status.FAILURE
	return Status.SUCCESS if BehaviorsQuests.set_state(quest_id, int(state), quester_id) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not BehaviorsQuests.is_available():
		warnings.append("Requires the Quests package.")
	if quest_id.is_empty():
		warnings.append("Set Quest State has no quest ID.")
	return warnings


func _get_graph_text() -> String:
	return "%s: %s" % [quest_id, BehaviorQuestStateIs.QuestState.keys()[state].capitalize()]
