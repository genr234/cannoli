@tool
@icon("res://addons/behaviors/icons/inverter.svg")
class_name BehaviorInverter
extends BehaviorDecorator
## Runs its child and swaps success and failure.


func _decorate(child_status: Status) -> Status:
	if child_status == Status.SUCCESS:
		return Status.FAILURE
	if child_status == Status.FAILURE:
		return Status.SUCCESS
	return child_status
