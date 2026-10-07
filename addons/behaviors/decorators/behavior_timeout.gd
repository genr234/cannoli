@tool
@icon("res://addons/behaviors/icons/timeout.svg")
class_name BehaviorTimeout
extends BehaviorDecorator
## Stops its child when it runs longer than a time limit.

## Seconds the child may run, in tree time.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var time_limit: float = 5.0
## The status when time runs out.
@export_enum("Success:2", "Failure:3") var timeout_status: int = Status.FAILURE

var _elapsed: float = 0.0


func _on_start() -> void:
	_elapsed = 0.0


func _execute(delta: float) -> Status:
	if _running_child >= 0:
		_elapsed += delta
		if _elapsed >= time_limit:
			_abort_children()
			return timeout_status as Status
	return super(delta)


func _get_graph_text() -> String:
	return "%ss" % time_limit
