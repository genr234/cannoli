class_name QuestCounterCondition
extends QuestCondition
## True when a quest counter reaches a value.

enum CounterValueMode {
	## The counter must be greater than or equal to the required value.
	AT_LEAST,
	## The counter must be less than or equal to the required value.
	AT_MOST,
}

## Name of a counter defined in the quest.
@export var counter_name := ""
## How the counter value applies to the condition.
@export var counter_value_mode := CounterValueMode.AT_LEAST
## The required value for the counter value mode.
@export var required_counter_value: QuestNumber

var _counter: QuestCounter


func set_runtime_references(p_quest: Quest, p_node: QuestNode) -> void:
	super.set_runtime_references(p_quest, p_node)
	_counter = null


func get_editor_name() -> String:
	if counter_name.is_empty() or required_counter_value == null:
		return "Counter"
	var operator := " >= " if counter_value_mode == CounterValueMode.AT_LEAST else " <= "
	return "Counter: " + counter_name + operator + required_counter_value.get_editor_name(quest)


## The counter being watched, or null.
func get_counter() -> QuestCounter:
	if _counter == null and quest != null:
		_counter = quest.get_counter(counter_name)
	return _counter


func start_checking(true_callback: Callable) -> void:
	super.start_checking(true_callback)
	if quest == null:
		push_warning("Quests: QuestCounterCondition was passed a null quest. Can't start checking.")
		return
	var counter := get_counter()
	if counter == null:
		push_warning("Quests: QuestCounterCondition can't find counter '%s' in quest '%s'. Can't start checking." % [counter_name, quest.get_editor_name()])
		return
	if _is_counter_condition_true(counter):
		set_true()
	elif not counter.value_changed.is_connected(_on_counter_changed):
		counter.value_changed.connect(_on_counter_changed)


func stop_checking() -> void:
	super.stop_checking()
	if _counter != null and _counter.value_changed.is_connected(_on_counter_changed):
		_counter.value_changed.disconnect(_on_counter_changed)


func _on_counter_changed(counter: QuestCounter) -> void:
	if is_checking and _is_counter_condition_true(counter):
		set_true()


func _is_counter_condition_true(counter: QuestCounter) -> bool:
	if counter == null:
		return false
	if required_counter_value == null:
		push_warning("Quests: QuestCounterCondition(%s): required_counter_value is null." % counter.name)
		return false
	var required := required_counter_value.get_value(quest)
	if Quests.debug:
		print("Quests: QuestCounterCondition %s = %d" % [counter.name, counter.current_value])
	match counter_value_mode:
		CounterValueMode.AT_LEAST:
			return counter.current_value >= required
		CounterValueMode.AT_MOST:
			return counter.current_value <= required
	return false
