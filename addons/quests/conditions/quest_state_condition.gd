class_name QuestStateCondition
extends QuestCondition
## True when a quest is (or is not) in a state.

## ID of the quest to monitor. If blank, uses this quest.
@export var required_quest_id := ""
## The quest must not be in the required state.
@export var is_not := false
## Required quest state.
@export var required_state := Quest.State.WAITING_TO_START


## The ID of the quest to check: the configured ID, or this quest's.
func get_quest_id_to_check() -> String:
	if required_quest_id.is_empty() and quest != null:
		return quest.id
	return required_quest_id


func get_editor_name() -> String:
	var operator := " != " if is_not else " == "
	var state_name := QuestSceneLookup.quest_state_name(required_state)
	if required_quest_id.is_empty():
		return "Quest State:" + operator.rstrip(" ") + " " + state_name
	return "Quest State: " + required_quest_id + operator + state_name


func start_checking(true_callback: Callable) -> void:
	super.start_checking(true_callback)
	var quest_id := get_quest_id_to_check()
	if _is_condition_true(Quests.get_quest_state(quest_id)):
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
	if not str(args.values[0]).is_empty():
		return
	var state: int = args.values[1] if typeof(args.values[1]) == TYPE_INT else Quest.State.WAITING_TO_START
	if _is_condition_true(state):
		set_true()


func _is_condition_true(state: int) -> bool:
	return state != required_state if is_not else state == required_state
