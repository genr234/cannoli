class_name QuestParentCondition
extends QuestCondition
## True when enough of the node's parent nodes are true.

## How many parents must be true.
@export var parent_count_mode := QuestConditionSet.Mode.ALL
## If the mode is MIN, at least this many parents must be true.
@export var min_parent_count := 1


func get_editor_name() -> String:
	match parent_count_mode:
		QuestConditionSet.Mode.ALL:
			return "Parents: All True"
		QuestConditionSet.Mode.ANY:
			return "Parents: Any True"
		QuestConditionSet.Mode.MIN:
			return "Parents: At Least %d True" % min_parent_count
	return super.get_editor_name()


func start_checking(true_callback: Callable) -> void:
	super.start_checking(true_callback)
	_connect_to_parent_nodes(true)
	_check_true_parent_count()


func stop_checking() -> void:
	super.stop_checking()
	_connect_to_parent_nodes(false)


func _connect_to_parent_nodes(add: bool) -> void:
	if quest == null or quest_node == null:
		return
	for parent_node in quest_node.parent_list:
		if parent_node == null:
			continue
		if parent_node.state_changed.is_connected(_on_parent_state_changed):
			parent_node.state_changed.disconnect(_on_parent_state_changed)
		if add:
			parent_node.state_changed.connect(_on_parent_state_changed)


func _on_parent_state_changed(parent_node: QuestNode) -> void:
	if is_checking and parent_node != null and parent_node.get_state() == QuestNode.State.TRUE:
		_check_true_parent_count()


# Counts every time instead of keeping a counter that would have to be saved.
func _check_true_parent_count() -> void:
	var nonoptional_count := 0
	var optional_count := 0
	if quest_node != null:
		for parent_node in quest_node.parent_list:
			if parent_node == null or parent_node.get_state() != QuestNode.State.TRUE:
				continue
			if parent_node.is_optional:
				optional_count += 1
			else:
				nonoptional_count += 1
	var total_count := nonoptional_count + optional_count
	match parent_count_mode:
		QuestConditionSet.Mode.ANY:
			if total_count >= 1:
				set_true()
		QuestConditionSet.Mode.ALL:
			if quest_node != null and nonoptional_count >= quest_node.nonoptional_parent_list.size():
				set_true()
		QuestConditionSet.Mode.MIN:
			if total_count >= min_parent_count:
				set_true()
