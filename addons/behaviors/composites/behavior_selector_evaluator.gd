@tool
@icon("res://addons/behaviors/icons/selector_evaluator.svg")
class_name BehaviorSelectorEvaluator
extends BehaviorComposite
## A selector that checks its children again every tick. Each tick it runs the
## children before the running one, first to last. If one of them runs or succeeds,
## it interrupts the running child and takes over. Works like a conditional abort,
## except the children do not have to be conditions.


func _execute(delta: float) -> Status:
	var limit := _running_child if _running_child >= 0 else children.size()
	for index in limit:
		var result := _try_child(index, delta)
		if result != Status.FAILURE:
			return result
	if _running_child < 0:
		return Status.FAILURE
	var running := _running_child
	var result := children[running].tick(delta)
	if result == Status.RUNNING:
		return result
	_running_child = -1
	if result == Status.SUCCESS:
		return result
	for index in range(running + 1, children.size()):
		result = _try_child(index, delta)
		if result != Status.FAILURE:
			return result
	return Status.FAILURE


# Runs a child that is not the running one. Returns FAILURE to try the next child.
func _try_child(index: int, delta: float) -> Status:
	var child := children[index]
	if child == null or (child.disabled and not child.is_running):
		return Status.FAILURE
	var result := child.tick(delta)
	if result == Status.FAILURE:
		return result
	if _running_child >= 0 and _running_child != index:
		var interrupted := children[_running_child]
		interrupted.abort()
		if agent:
			agent._task_aborted_by(child, interrupted)
	_running_child = index if result == Status.RUNNING else -1
	return result
