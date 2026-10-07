@tool
@icon("res://addons/behaviors/icons/until_success.svg")
class_name BehaviorUntilSuccess
extends BehaviorDecorator
## Runs its child again and again until it succeeds.


func _execute(delta: float) -> Status:
	var child := get_child()
	if child == null:
		return Status.SUCCESS
	while true:
		_running_child = 0
		var result := child.tick(delta)
		if result == Status.RUNNING:
			return result
		_running_child = -1
		if result == Status.SUCCESS:
			return result
		if not child.instant:
			return Status.RUNNING
	return Status.SUCCESS
