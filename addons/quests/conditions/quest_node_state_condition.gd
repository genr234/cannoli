class_name QuestNodeStateCondition
extends QuestCondition
## True when a quest node is (or is not) in a state.

## ID of the quest to monitor. If blank, uses this quest.
@export var required_quest_id := ""
## ID of the quest node to monitor. If blank, uses this node.
@export var required_node_id := ""
## The node must not be in the required state.
@export var is_not := false
## Required quest node state.
@export var required_state := QuestNode.State.INACTIVE


func get_quest_id_to_check() -> String:
	if required_quest_id.is_empty() and quest != null:
		return quest.id
	return required_quest_id


func get_node_id_to_check() -> String:
	if required_node_id.is_empty() and quest_node != null:
		return quest_node.id
	return required_node_id


func get_editor_name() -> String:
	var operator := "!= " if is_not else "== "
	var state_name := QuestSceneLookup.node_state_name(required_state)
	var node_text := "'" + required_node_id + "'" if not required_node_id.is_empty() else "(unspecified)"
	if not required_quest_id.is_empty():
		return "Quest Node State: Quest '" + required_quest_id + "' Node " + node_text + " " + operator + state_name
	return "Quest Node State: Quest Node " + node_text + " " + operator + state_name


func start_checking(true_callback: Callable) -> void:
	super.start_checking(true_callback)
	var quest_id := get_quest_id_to_check()
	if quest_id.is_empty():
		return
	if _is_condition_true(Quests.get_quest_node_state(quest_id, get_node_id_to_check())):
		set_true()
	else:
		QuestMessages.add_listener(self, QuestMessages.QUEST_STATE_CHANGED, quest_id, _on_message)


func stop_checking() -> void:
	super.stop_checking()
	QuestMessages.remove_listener(self)


func _on_message(args: QuestMessageArgs) -> void:
	if not is_checking or args.values.size() < 2:
		return
	if args.parameter != get_quest_id_to_check():
		return
	if str(args.values[0]) != get_node_id_to_check():
		return
	var state: int = args.values[1] if typeof(args.values[1]) == TYPE_INT else QuestNode.State.INACTIVE
	if _is_condition_true(state):
		set_true()


func _is_condition_true(state: int) -> bool:
	return state != required_state if is_not else state == required_state
