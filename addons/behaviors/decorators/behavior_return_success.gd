@tool
@icon("res://addons/behaviors/icons/return_success.svg")
class_name BehaviorReturnSuccess
extends BehaviorDecorator
## Runs its child and succeeds whatever the child returned.


func _decorate(_child_status: Status) -> Status:
	return Status.SUCCESS
