class_name QuestMessageCondition
extends QuestCondition
## True when a message is received.

## Required message sender.
@export var sender_specifier := QuestMessages.Participant.ANY
## Required message sender ID, or any sender if blank. Can also be {QUESTERID} or {QUESTGIVERID}.
@export var sender_id := ""
## Required message target.
@export var target_specifier := QuestMessages.Participant.ANY
## Required message target ID, or any target if blank. Can also be {QUESTERID} or {QUESTGIVERID}.
@export var target_id := ""
## Required message. The condition is true when this message is received with the parameter below.
@export var message := ""
## Required parameter. Leave blank to accept any parameter.
@export var parameter := ""
## Additional value expected with the message.
@export var value: QuestMessageValue

var _listen_generation := 0


func get_runtime_sender_id() -> String:
	return QuestTags.replace_tags(QuestSceneLookup.get_id_by_specifier(sender_specifier, sender_id), quest)


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
	for text in [sender_id, target_id, message, parameter]:
		QuestTags.add_tags_to_dictionary(quest.tag_dictionary, text)
	if value != null and value.value_type == QuestMessageValue.ValueType.STRING:
		QuestTags.add_tags_to_dictionary(quest.tag_dictionary, value.string_value)


func start_checking(true_callback: Callable) -> void:
	super.start_checking(true_callback)
	_listen_generation += 1
	_add_listener_next_frame(_listen_generation)


func stop_checking() -> void:
	super.stop_checking()
	_listen_generation += 1
	QuestMessages.remove_listener(self)


# Waits a frame so the condition doesn't respond to the message that activated
# its node, in case it listens for the same message.
func _add_listener_next_frame(generation: int) -> void:
	var tree := QuestSceneLookup.get_tree()
	if tree != null:
		await tree.process_frame
	if is_checking and generation == _listen_generation:
		QuestMessages.add_listener(self, get_runtime_message(), get_runtime_parameter(), _on_message)


func _on_message(args: QuestMessageArgs) -> void:
	if not is_checking:
		return
	if not (args.is_sender(get_runtime_sender_id()) and args.is_target(get_runtime_target_id()) and value_matches(args)):
		return
	if Quests.debug:
		print("Quests: QuestMessageCondition message '%s' parameter '%s'" % [args.message, args.parameter])
	set_true()


func value_matches(args: QuestMessageArgs) -> bool:
	return value == null or value.matches(args.first_value(), quest)
