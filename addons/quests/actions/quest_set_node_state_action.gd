class_name QuestSetNodeStateAction
extends QuestAction
## Sets a quest node's state.

## ID of the quest. Leave blank to use this quest.
@export var quest_id := ""
## ID of the quest node. Leave blank to use this node.
@export var node_id := ""
## New quest node state.
@export var state := QuestNode.State.ACTIVE


func get_editor_name() -> String:
	var state_name := QuestSceneLookup.node_state_name(state)
	var node_text := "'" + node_id + "'" if not node_id.is_empty() else "(unspecified)"
	if not quest_id.is_empty():
		return "Set Quest Node State: Quest '%s' Node %s to %s" % [quest_id, node_text, state_name]
	if not node_id.is_empty():
		return "Set Quest Node State: '%s' to %s" % [node_id, state_name]
	return "Set Quest Node State: " + state_name


func execute() -> void:
	var target_quest_id := quest_id if not quest_id.is_empty() else (quest.id if quest != null else "")
	var target_node_id := node_id if not node_id.is_empty() else (quest_node.id if quest_node != null else "")
	if quest_id.is_empty() and quest != null:
		var node := quest.get_node(target_node_id)
		if node != null and node.get_state() != state:
			node.set_state(state)
		return
	if Quests.get_quest_node_state(target_quest_id, target_node_id) != state:
		Quests.set_quest_node_state(target_quest_id, target_node_id, state)
