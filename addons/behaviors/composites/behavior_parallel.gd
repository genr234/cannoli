@tool
@icon("res://addons/behaviors/icons/parallel.svg")
class_name BehaviorParallel
extends BehaviorComposite
## Runs every child at the same time. Fails as soon as a child fails, stopping the
## others, and succeeds when every child succeeded.

var _index: int = 0
var _statuses: Array[Status] = []


func _on_awake() -> void:
	_statuses.resize(children.size())
	_statuses.fill(Status.INACTIVE)


func can_run_parallel_children() -> bool:
	return true


func current_child_index() -> int:
	return _index


func can_execute() -> bool:
	return _index < children.size()


func _on_child_started(child_index: int) -> void:
	_index += 1
	_statuses[child_index] = Status.RUNNING


func _on_child_executed(child_index: int, child_status: Status) -> void:
	_statuses[child_index] = child_status


func override_status(_child_status: Status) -> Status:
	var complete := true
	for child_status in _statuses:
		if child_status == Status.RUNNING:
			complete = false
		elif child_status == Status.FAILURE:
			return Status.FAILURE
	return Status.SUCCESS if complete else Status.RUNNING


func _on_conditional_abort(_child_index: int) -> void:
	_index = 0
	_statuses.fill(Status.INACTIVE)


func _on_end() -> void:
	_statuses.fill(Status.INACTIVE)
	_index = 0
