@tool
@icon("res://addons/behaviors/icons/selector.svg")
class_name BehaviorSelector
extends BehaviorComposite
## Runs its children from first to last, like an "or". Succeeds as soon as a child
## succeeds, and fails when every child failed.

var _index: int = 0
var _execution_status: Status = Status.INACTIVE


func current_child_index() -> int:
	return _index


func can_execute() -> bool:
	return _index < children.size() and _execution_status != Status.SUCCESS


func _on_child_executed(_child_index: int, child_status: Status) -> void:
	_index += 1
	_execution_status = child_status


func _on_conditional_abort(child_index: int) -> void:
	_index = child_index
	_execution_status = Status.INACTIVE


func override_status(child_status: Status) -> Status:
	return Status.FAILURE if child_status == Status.INACTIVE else child_status


func _on_end() -> void:
	_execution_status = Status.INACTIVE
	_index = 0
