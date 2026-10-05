class_name QuestMessageArgs
extends RefCounted
## The data delivered to message listeners.

var sender: Variant
var target: Variant
var message := ""
var parameter := ""
var values: Array = []


func _init(p_sender: Variant = null, p_target: Variant = null, p_message := "", p_parameter := "", p_values: Array = []) -> void:
	sender = p_sender
	target = p_target
	message = p_message
	parameter = p_parameter
	values = p_values


func get_sender_id() -> String:
	return QuestMessages.get_id(sender)


func get_target_id() -> String:
	return QuestMessages.get_id(target)


func has_target() -> bool:
	return target != null and not get_target_id().is_empty()


func first_value() -> Variant:
	return values[0] if values.size() > 0 else null


## The first value as an int, or 0 if it isn't one.
func int_value() -> int:
	var v: Variant = first_value()
	return v if typeof(v) == TYPE_INT else 0


## True if this message is [param p_message], and [param p_parameter] is empty or matches.
func matches(p_message: String, p_parameter := "") -> bool:
	return p_message == message and (p_parameter.is_empty() or p_parameter == parameter)


## True if [param id] is empty or is the sender's id.
func is_sender(id: String) -> bool:
	return id.is_empty() or id == get_sender_id()


## True if [param id] is empty or is the target's id.
func is_target(id: String) -> bool:
	return id.is_empty() or id == get_target_id()
