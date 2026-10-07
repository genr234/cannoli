@tool
@icon("res://addons/behaviors/icons/has_received_event.svg")
class_name BehaviorHasReceivedEvent
extends BehaviorCondition
## Succeeds once the agent has received an event since this task last succeeded.
##
## The task starts listening when the tree is built, so events sent while other
## branches run are not missed. Put it under a composite with a conditional abort
## to react to the event while the tree is busy elsewhere.

## The event to wait for.
@export var event_name: StringName = &""
## Variables that receive the event's arguments, in order.
@export var store_arguments: PackedStringArray = PackedStringArray()

var _received: bool = false


func _on_awake() -> void:
	if agent and not String(event_name).is_empty():
		agent.register_event(event_name, _on_event)


func _on_update(_delta: float) -> Status:
	return Status.SUCCESS if _received else Status.FAILURE


func _on_end() -> void:
	if status == Status.SUCCESS:
		_received = false


func _on_tree_complete(_tree_status: Status) -> void:
	_received = false


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(event_name).is_empty():
		warnings.append("Has Received Event has no event name.")
	return warnings


func _get_graph_text() -> String:
	return String(event_name)


func _on_event(args: Array) -> void:
	_received = true
	for index in mini(args.size(), store_arguments.size()):
		if not store_arguments[index].is_empty():
			set_var(StringName(store_arguments[index]), args[index])
