@tool
@icon("res://addons/behaviors/icons/utility_selector.svg")
class_name BehaviorUtilitySelector
extends BehaviorComposite
## Runs the child with the highest utility, scored every tick. When another child
## scores higher, the running one is interrupted and the new one starts.
##
## Score children with [member BehaviorTask.considerations] in the inspector, or by
## overriding [method BehaviorTask._get_utility]. A child that fails is left out
## until the selector starts again. Succeeds when a child succeeds, and fails when
## every child failed.

## Keeps the running child unless another one beats it by more than this, so two
## close scores do not flip back and forth.
@export_range(0.0, 1.0, 0.01, "or_greater") var switch_margin: float = 0.0

var _available: Array[int] = []


func _on_start() -> void:
	_available.clear()
	for index in children.size():
		if children[index] and not children[index].disabled:
			_available.append(index)


func _execute(delta: float) -> Status:
	while not _available.is_empty():
		var best := _pick()
		if _running_child >= 0 and _running_child != best:
			var interrupted := children[_running_child]
			interrupted.abort()
			if agent:
				agent._task_aborted_by(self, interrupted)
		_running_child = best
		var child := children[best]
		var result := child.tick(delta)
		if result == Status.RUNNING:
			return result
		_running_child = -1
		if result == Status.SUCCESS:
			return result
		_available.erase(best)
		if not child.instant:
			return Status.RUNNING if not _available.is_empty() else Status.FAILURE
	return Status.FAILURE


func _pick() -> int:
	var best := _available[0]
	var best_utility := -INF
	var running_utility := -INF
	for index in _available:
		var utility := children[index].get_utility()
		if index == _running_child:
			running_utility = utility
		if utility > best_utility:
			best_utility = utility
			best = index
	if _running_child >= 0 and _available.has(_running_child) and best_utility - running_utility <= switch_margin:
		return _running_child
	return best


func _on_end() -> void:
	_available.clear()
