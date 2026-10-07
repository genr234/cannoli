@tool
@icon("res://addons/behaviors/icons/log.svg")
class_name BehaviorLog
extends BehaviorAction
## Prints a message and succeeds. [code]{name}[/code] in the text is replaced with
## the variable [code]name[/code].

## How the message is printed.
enum Level { INFO, WARNING, ERROR }

## The message.
@export_multiline var text: String = ""
## How the message is printed.
@export var level: Level = Level.INFO
## Starts the message with the agent's tree time.
@export var log_time: bool = false


func _on_update(_delta: float) -> Status:
	var message := _format(text)
	if log_time and agent:
		message = "%.3f: %s" % [agent.get_time(), message]
	match level:
		Level.WARNING:
			push_warning(message)
		Level.ERROR:
			push_error(message)
		_:
			print(message)
	return Status.SUCCESS


func _get_graph_text() -> String:
	return text.left(40)


func _format(source: String) -> String:
	if not source.contains("{") or blackboard == null:
		return source
	var values := {}
	var regex := RegEx.create_from_string("\\{([^{}]+)\\}")
	for found in regex.search_all(source):
		var variable := found.get_string(1)
		values[variable] = get_var(StringName(variable), "")
	return source.format(values)
