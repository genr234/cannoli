class_name QuestSetQuestStateAction
extends QuestAction
## Sets a quest's state.

## ID of the quest. Leave blank to set this quest's state.
@export var quest_id := ""
## New quest state.
@export var state := Quest.State.ACTIVE
## Also set all of the quest's nodes to the equivalent state.
@export var set_quest_nodes_to_same := false


func get_editor_name() -> String:
	var state_name := QuestSceneLookup.quest_state_name(state)
	if quest_id.is_empty():
		return "Set Quest State: " + state_name
	return "Set Quest State: Quest '%s' to %s" % [quest_id, state_name]


func execute() -> void:
	var use_this_quest := quest_id.is_empty() and quest != null
	var target: Quest = quest if use_this_quest else Quests.get_quest_instance(quest_id)
	if use_this_quest:
		quest.set_state(state)
	elif Quests.get_quest_state(quest_id) != state:
		Quests.set_quest_state(quest_id, state)
	if set_quest_nodes_to_same and target != null:
		var node_state := _get_equivalent_node_state(state)
		for node in target.node_list:
			node.set_state_raw(node_state)


func _get_equivalent_node_state(quest_state: Quest.State) -> QuestNode.State:
	match quest_state:
		Quest.State.ACTIVE:
			return QuestNode.State.ACTIVE
		Quest.State.SUCCESSFUL, Quest.State.FAILED:
			return QuestNode.State.TRUE
	return QuestNode.State.INACTIVE
