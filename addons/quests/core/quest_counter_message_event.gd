class_name QuestCounterMessageEvent
extends Resource
## Describes a message that changes a counter's value.

enum Operation { MODIFY_BY_MESSAGE_VALUE, SET_TO_MESSAGE_VALUE, MODIFY_BY_LITERAL_VALUE, SET_TO_LITERAL_VALUE }

@export var sender_specifier := QuestMessages.Participant.ANY
@export var sender_id := ""
@export var target_specifier := QuestMessages.Participant.ANY
@export var target_id := ""
@export var message := ""
## Only messages with this parameter count. Empty accepts any parameter.
@export var parameter := ""
@export var operation := Operation.MODIFY_BY_LITERAL_VALUE
@export var literal_value := 1


static func create(p_message: String, p_parameter := "", p_operation := Operation.MODIFY_BY_LITERAL_VALUE,
		p_literal_value := 1, p_target_id := "") -> QuestCounterMessageEvent:
	var result := QuestCounterMessageEvent.new()
	result.message = p_message
	result.parameter = p_parameter
	result.operation = p_operation
	result.literal_value = p_literal_value
	result.target_id = p_target_id
	if not p_target_id.is_empty():
		result.target_specifier = QuestMessages.Participant.OTHER
	return result


## The sender id that messages must come from, after resolving the specifier.
## Empty means any sender.
func get_sender_id() -> String:
	return QuestTags.get_id_by_specifier(sender_specifier, sender_id)


func get_target_id() -> String:
	return QuestTags.get_id_by_specifier(target_specifier, target_id)
