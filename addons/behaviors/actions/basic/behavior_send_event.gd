@tool
@icon("res://addons/behaviors/icons/send_event.svg")
class_name BehaviorSendEvent
extends BehaviorAction
## Sends an event to agents, then succeeds. [BehaviorHasReceivedEvent] tasks and
## [method BehaviorAgent.register_event] listeners receive it.

## Who receives the event.
enum Target {
	## This agent.
	SELF,
	## The agents on the node at [member target].
	NODE,
	## The agents on every node in [member group].
	GROUP,
	## Every agent.
	ALL,
}

## The event to send.
@export var event_name: StringName = &""
## Who receives the event.
@export var send_to: Target = Target.SELF
## A node, relative to the actor, for [constant Target.NODE].
@export var target: NodePath = NodePath()
## A group for [constant Target.GROUP].
@export var group: StringName = &""
## Values sent with the event.
@export var arguments: Array = []
## Variables whose values are sent after [member arguments].
@export var argument_variables: PackedStringArray = PackedStringArray()


func _on_update(_delta: float) -> Status:
	var args := arguments.duplicate()
	for variable in argument_variables:
		args.append(get_var(StringName(variable)))
	match send_to:
		Target.SELF:
			if agent == null:
				return Status.FAILURE
			agent.send_event(event_name, args)
		Target.NODE:
			var node := get_node_from_actor(target)
			if node == null:
				return Status.FAILURE
			Behaviors.send_event(node, event_name, args)
		Target.GROUP:
			Behaviors.send_event_to_group(group, event_name, args)
		Target.ALL:
			Behaviors.send_event_to_all(event_name, args)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(event_name).is_empty():
		warnings.append("Send Event has no event name.")
	return warnings


func _get_graph_text() -> String:
	return String(event_name)
