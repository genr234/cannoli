@tool
@icon("res://addons/behaviors/icons/return_failure.svg")
class_name BehaviorReturnFailure
extends BehaviorDecorator
## Runs its child and fails whatever the child returned.


func _decorate(_child_status: Status) -> Status:
	return Status.FAILURE
