@tool
@abstract
@icon("res://addons/behaviors/icons/decorator.svg")
class_name BehaviorDecorator
extends BehaviorParent
## A parent with one child that changes how it runs or what it returns.
##
## The default run ticks the child and passes its result through [method _decorate].
## Decorators that repeat or wait override [method BehaviorTask._execute] instead.


func max_children() -> int:
	return 1


## Changes the child's final status.
func _decorate(child_status: Status) -> Status:
	return child_status


func _execute(delta: float) -> Status:
	var child := get_child()
	if child == null:
		return _decorate(Status.SUCCESS)
	_running_child = 0
	var result := child.tick(delta)
	if result == Status.RUNNING:
		return Status.RUNNING
	_running_child = -1
	return _decorate(result)
