class_name QuestSetCounterAction
extends QuestAction
## Sets or modifies a quest counter.

enum Operation { SET_TO_VALUE, MODIFY_BY_VALUE, RANDOMIZE }

## Name of the counter to set.
@export var counter_name := ""
## Set an absolute value, modify the current value, or pick a random value.
@export var operation := Operation.SET_TO_VALUE
## Value to set the counter to, modify the counter by, or the minimum for RANDOMIZE.
@export var operation_value := 0
## Maximum value for RANDOMIZE.
@export var max_value := 0


func get_editor_name() -> String:
	if counter_name.is_empty():
		return "Set Counter"
	match operation:
		Operation.SET_TO_VALUE:
			return "Set Counter: %s = %d" % [counter_name, operation_value]
		Operation.MODIFY_BY_VALUE:
			return "Set Counter: %s += %d" % [counter_name, operation_value]
		Operation.RANDOMIZE:
			return "Set Counter: %s to random in [%d,%d]" % [counter_name, operation_value, max_value]
	return "Set Counter"


func execute() -> void:
	if quest == null:
		push_warning("Quests: QuestSetCounterAction was passed a null quest.")
		return
	var counter := quest.get_counter(counter_name)
	if counter == null:
		push_warning("Quests: QuestSetCounterAction can't find counter '%s' in quest '%s'." % [counter_name, quest.get_editor_name()])
		return
	match operation:
		Operation.SET_TO_VALUE:
			counter.set_value(operation_value)
		Operation.MODIFY_BY_VALUE:
			counter.set_value(counter.current_value + operation_value)
		Operation.RANDOMIZE:
			counter.set_value(randi_range(operation_value, maxi(operation_value, max_value)))
