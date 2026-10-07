@tool
@icon("res://addons/behaviors/icons/repeater.svg")
class_name BehaviorRepeater
extends BehaviorDecorator
## Runs its child a number of times, or forever. Ends with the child's last status.

## How many times to run the child.
@export_range(1, 100, 1, "or_greater") var count: int = 1
## Runs the child until the repeater is interrupted.
@export var repeat_forever: bool = false
## Stops repeating as soon as the child fails.
@export var end_on_failure: bool = false

var _executions: int = 0
var _execution_status: Status = Status.INACTIVE


func _execute(delta: float) -> Status:
	var child := get_child()
	if child == null:
		return Status.SUCCESS
	while _can_repeat():
		_running_child = 0
		var result := child.tick(delta)
		if result == Status.RUNNING:
			return result
		_running_child = -1
		_executions += 1
		_execution_status = result
		if not child.instant and _can_repeat():
			return Status.RUNNING
	return Status.SUCCESS if _execution_status == Status.INACTIVE else _execution_status


func _can_repeat() -> bool:
	if end_on_failure and _execution_status == Status.FAILURE:
		return false
	return repeat_forever or _executions < count


func _get_graph_text() -> String:
	return "Forever" if repeat_forever else "×%d" % count


func _on_end() -> void:
	_executions = 0
	_execution_status = Status.INACTIVE
