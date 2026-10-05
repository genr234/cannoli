class_name QuestNumber
extends Resource
## An integer that is either a literal or read from one of a quest's counters.

enum ValueType { LITERAL, COUNTER_VALUE, COUNTER_MIN_VALUE, COUNTER_MAX_VALUE }

@export var value_type := ValueType.LITERAL
@export var literal_value := 0
## The counter to read, by name, for the counter value types.
@export var counter_name := ""


static func literal(v: int) -> QuestNumber:
	var result := QuestNumber.new()
	result.value_type = ValueType.LITERAL
	result.literal_value = v
	return result


static func from_counter(p_counter_name: String, p_value_type := ValueType.COUNTER_VALUE) -> QuestNumber:
	var result := QuestNumber.new()
	result.value_type = p_value_type
	result.counter_name = p_counter_name
	return result


func get_value(quest: Quest) -> int:
	if value_type == ValueType.LITERAL:
		return literal_value
	if quest == null:
		push_warning("Quests: Want to get value of counter '%s' but quest is null." % counter_name)
		return 0
	var counter := quest.get_counter(counter_name)
	if counter == null:
		push_warning("Quests: There is no counter '%s' in quest '%s'." % [counter_name, quest.get_editor_name()])
		return 0
	match value_type:
		ValueType.COUNTER_MIN_VALUE:
			return counter.min_value
		ValueType.COUNTER_MAX_VALUE:
			return counter.max_value
	return counter.current_value


func get_editor_name(quest: Quest = null) -> String:
	if value_type == ValueType.LITERAL:
		return str(literal_value)
	var label := counter_name if not counter_name.is_empty() else "counter"
	match value_type:
		ValueType.COUNTER_MIN_VALUE:
			return label + " Min Value"
		ValueType.COUNTER_MAX_VALUE:
			return label + " Max Value"
	return label
