class_name QuestMessageAction
extends QuestAction
## Sends a message.

## Message sender. QUEST_GIVER sends from the quest's giver.
@export var sender_specifier := QuestMessages.Participant.QUEST_GIVER
## ID of the message sender. Can also be {QUESTERID} or {QUESTGIVERID}. If blank, uses the quest giver's ID.
@export var sender_id := ""
## Message target.
@export var target_specifier := QuestMessages.Participant.ANY
## ID of the message target. Can also be {QUESTERID} or {QUESTGIVERID}. Leave blank to broadcast.
@export var target_id := ""
## Message to send.
@export var message := ""
## Parameter to send with the message.
@export var parameter := ""
## Optional value to pass with the message.
@export var value: QuestMessageValue


func get_sender_id() -> String:
	if sender_specifier == QuestMessages.Participant.QUEST_GIVER or sender_id.is_empty() or sender_id == QuestTags.QUESTGIVER:
		return quest.quest_giver_id if quest != null else ""
	return QuestSceneLookup.get_id_by_specifier(sender_specifier, sender_id)


func get_runtime_sender_id() -> String:
	return QuestTags.replace_tags(get_sender_id(), quest)


func get_runtime_target_id() -> String:
	return QuestTags.replace_tags(QuestSceneLookup.get_id_by_specifier(target_specifier, target_id), quest)


func get_runtime_message() -> String:
	return QuestTags.replace_tags(message, quest)


func get_runtime_parameter() -> String:
	return QuestTags.replace_tags(parameter, quest)


func get_editor_name() -> String:
	if message.is_empty():
		return "Message"
	var text := "Message: " + message
	if not parameter.is_empty():
		text += " " + parameter
	if value != null and value.value_type == QuestMessageValue.ValueType.INT:
		text += " " + str(value.int_value)
	elif value != null and value.value_type == QuestMessageValue.ValueType.STRING:
		text += " " + value.string_value
	return text


func add_tags_to_dictionary() -> void:
	if quest == null:
		return
	for text in [get_sender_id(), QuestSceneLookup.get_id_by_specifier(target_specifier, target_id), message, parameter]:
		QuestTags.add_tags_to_dictionary(quest.tag_dictionary, text)
	if value != null and value.value_type == QuestMessageValue.ValueType.STRING:
		QuestTags.add_tags_to_dictionary(quest.tag_dictionary, value.string_value)


func execute() -> void:
	var sent_value: Variant = null
	if value != null:
		match value.value_type:
			QuestMessageValue.ValueType.INT:
				sent_value = value.int_value
			QuestMessageValue.ValueType.STRING:
				sent_value = QuestTags.replace_tags(value.string_value, quest)
	Quests.send_message(get_runtime_message(), get_runtime_parameter(), sent_value,
			get_runtime_sender_id(), get_runtime_target_id())
