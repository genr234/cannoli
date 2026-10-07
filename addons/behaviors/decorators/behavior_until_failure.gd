@tool
@icon("res://addons/behaviors/icons/until_failure.svg")
class_name BehaviorUntilFailure
extends BehaviorDecorator
## Runs its child again and again until it fails.


func _execute(delta: float) -> Status:
	var child := get_child()
	if child == null:
		return Status.FAILURE
	while true:
		_running_child = 0
		var result := child.tick(delta)
		if result == Status.RUNNING:
			return result
		_running_child = -1
		if result == Status.FAILURE:
			return result
		if not child.instant:
			return Status.RUNNING
	return Status.FAILURE
