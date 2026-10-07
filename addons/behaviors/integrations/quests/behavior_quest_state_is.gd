@tool
@icon("res://addons/behaviors/icons/quest.svg")
class_name BehaviorQuestStateIs
extends BehaviorCondition
## Succeeds when a quest is in a state.
##
## Needs the Quests package. Fails, with one warning, when it is missing.

## The states of a quest, as in the Quests package.
enum QuestState {
	WAITING_TO_START,
	ACTIVE,
	SUCCESSFUL,
	FAILED,
	ABANDONED,
	DISABLED,
}

## The ID of the quest.
@export var quest_id: String = ""
## The state to check for.
@export var state: QuestState = QuestState.ACTIVE
## The quester whose copy of the quest is checked. Empty uses the default.
@export var quester_id: String = ""

var _warned: bool = false


func _on_update(_delta: float) -> Status:
	if not BehaviorsQuests.is_available():
		if not _warned:
			_warned = true
			push_warning("%s: the Quests package is not available." % get_display_name())
		return Status.FAILURE
	return Status.SUCCESS if BehaviorsQuests.get_state(quest_id, quester_id) == int(state) else Status.FAILURE


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not BehaviorsQuests.is_available():
		warnings.append("Requires the Quests package.")
	if quest_id.is_empty():
		warnings.append("Quest State Is has no quest ID.")
	return warnings


func _get_graph_text() -> String:
	return "%s: %s" % [quest_id, QuestState.keys()[state].capitalize()]
