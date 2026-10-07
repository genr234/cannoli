@tool
@icon("res://addons/behaviors/icons/retry.svg")
class_name BehaviorRetry
extends BehaviorDecorator
## Runs its child again when it fails, up to a number of attempts. Succeeds as soon
## as the child succeeds, and fails when every attempt failed.

## The most times the child runs.
@export_range(1, 100, 1, "or_greater") var max_attempts: int = 3

var _attempts: int = 0


func _execute(delta: float) -> Status:
	var child := get_child()
	if child == null:
		return Status.SUCCESS
	while _attempts < max_attempts:
		_running_child = 0
		var result := child.tick(delta)
		if result == Status.RUNNING:
			return result
		_running_child = -1
		_attempts += 1
		if result == Status.SUCCESS:
			return result
		if not child.instant and _attempts < max_attempts:
			return Status.RUNNING
	return Status.FAILURE


func _get_graph_text() -> String:
	return "%d attempts" % max_attempts


func _on_end() -> void:
	_attempts = 0
