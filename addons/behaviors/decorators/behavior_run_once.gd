@tool
@icon("res://addons/behaviors/icons/run_once.svg")
class_name BehaviorRunOnce
extends BehaviorDecorator
## Runs its child the first time only. Later starts skip the child and return
## [member after_status]. The agent forgets when it rebuilds its tree.

## What later starts return.
enum AfterStatus {
	## The status the child ended with.
	CHILD_STATUS,
	SUCCESS,
	FAILURE,
}

## What later starts return.
@export var after_status: AfterStatus = AfterStatus.CHILD_STATUS

var _done: bool = false
var _child_status: Status = Status.SUCCESS


func _execute(delta: float) -> Status:
	if _done:
		match after_status:
			AfterStatus.SUCCESS:
				return Status.SUCCESS
			AfterStatus.FAILURE:
				return Status.FAILURE
		return _child_status
	var result := super(delta)
	if result != Status.RUNNING:
		_done = true
		_child_status = result
	return result


## Lets the child run again on the next start.
func reset() -> void:
	_done = false
