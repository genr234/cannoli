class_name QuestMessageEvents
extends Node
## Turns messages into signals, and signals into messages, without code.
##
## List the messages to listen for in [member messages_to_listen_for]; the
## [signal message_received] signal is emitted for each one that arrives. Call
## [method send_to_message_system] with an index into [member messages_to_send]
## to send a message, for example from a button's pressed signal.

## Emitted when a message from [member messages_to_listen_for] is received.
## [param index] is the entry that matched.
signal message_received(args: QuestMessageArgs, index: int)

@export var messages_to_listen_for: Array[QuestMessageListenEntry]
@export var messages_to_send: Array[QuestMessageSendEntry]


func _enter_tree() -> void:
	for entry in messages_to_listen_for:
		if entry != null:
			QuestMessages.add_listener(self, entry.message, entry.parameter, _on_message)


func _exit_tree() -> void:
	QuestMessages.remove_listener(self)


func _on_message(args: QuestMessageArgs) -> void:
	for i in messages_to_listen_for.size():
		var entry := messages_to_listen_for[i]
		if entry == null:
			continue
		if _is_participant_ok(entry.required_sender_id, entry.required_sender_path, args.sender) \
				and _is_participant_ok(entry.required_target_id, entry.required_target_path, args.target) \
				and entry.message == args.message \
				and (entry.parameter.is_empty() or entry.parameter == args.parameter):
			message_received.emit(args, i)


func _is_participant_ok(required_id: String, required_path: NodePath, actual: Variant) -> bool:
	var required_node := get_node_or_null(required_path) if not required_path.is_empty() else null
	if required_node == null and required_id.is_empty():
		return true
	if actual == null:
		return false
	if not required_id.is_empty() and QuestMessages.get_id(actual) == required_id:
		return true
	if required_node != null:
		if actual == required_node:
			return true
		if actual is Node:
			if required_node.is_ancestor_of(actual):
				return true
			var actual_identity := QuestMessages.find_identifiable(actual)
			if actual_identity != null and actual_identity == QuestMessages.find_identifiable(required_node):
				return true
		if typeof(actual) == TYPE_STRING and actual == String(required_node.name):
			return true
	return false


## Sends the message at [param index] of [member messages_to_send].
func send_to_message_system(index: int) -> void:
	if index < 0 or index >= messages_to_send.size() or messages_to_send[index] == null:
		return
	var entry := messages_to_send[index]
	var target: Variant = entry.target_id
	if entry.target_id.is_empty():
		target = get_node_or_null(entry.target_path) if not entry.target_path.is_empty() else null
	QuestMessages.send(self, target, entry.message, entry.parameter)
