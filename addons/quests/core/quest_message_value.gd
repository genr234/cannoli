class_name QuestMessageValue
extends Resource
## A value that a message must carry, such as for a message condition.

enum ValueType { NONE, INT, STRING }

@export var value_type := ValueType.NONE
@export var int_value := 0
@export var string_value := ""


static func from_int(value: int) -> QuestMessageValue:
	var result := QuestMessageValue.new()
	result.value_type = ValueType.INT
	result.int_value = value
	return result


static func from_string(value: String) -> QuestMessageValue:
	var result := QuestMessageValue.new()
	result.value_type = ValueType.STRING
	result.string_value = value
	return result


## Returns null, an int, or a String, depending on [member value_type].
func get_value() -> Variant:
	match value_type:
		ValueType.INT:
			return int_value
		ValueType.STRING:
			return string_value
	return null


## Returns true if [param v] (the first value of a message) satisfies this value.
## A value type of NONE accepts anything, including no value.
func matches(v: Variant, quest: Quest = null) -> bool:
	if value_type == ValueType.NONE:
		return true
	if v == null:
		return false
	match value_type:
		ValueType.STRING:
			return QuestMessages.arg_to_string(v) == QuestTags.replace_tags(string_value, quest)
		ValueType.INT:
			return QuestMessages.arg_to_int(v) == int_value
	return false


## Text for editor lists.
func get_editor_name() -> String:
	match value_type:
		ValueType.INT:
			return str(int_value)
		ValueType.STRING:
			return string_value
	return ""
