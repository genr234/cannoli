@tool
@icon("res://addons/behaviors/icons/priority_selector.svg")
class_name BehaviorPrioritySelector
extends BehaviorComposite
## A selector that runs its children by priority instead of by position. Each child's
## [method BehaviorTask.get_priority] is read when the selector starts, and the
## highest runs first. Succeeds as soon as a child succeeds.

var _index: int = 0
var _execution_status: Status = Status.INACTIVE
var _order: Array[int] = []


func _on_start() -> void:
	_order.clear()
	for child_index in children.size():
		var child_priority := children[child_index].get_priority() if children[child_index] else -INF
		var insert_at := _order.size()
		for position in _order.size():
			var other := children[_order[position]]
			if other == null or other.get_priority() < child_priority:
				insert_at = position
				break
		_order.insert(insert_at, child_index)


func current_child_index() -> int:
	return _order[_index] if _index < _order.size() else -1


func can_execute() -> bool:
	return _index < _order.size() and _execution_status != Status.SUCCESS


func _on_child_executed(_child_index: int, child_status: Status) -> void:
	_index += 1
	_execution_status = child_status


func _on_conditional_abort(child_index: int) -> void:
	_index = maxi(_order.find(child_index), 0)
	_execution_status = Status.INACTIVE


func override_status(child_status: Status) -> Status:
	return Status.FAILURE if child_status == Status.INACTIVE else child_status


func _on_end() -> void:
	_execution_status = Status.INACTIVE
	_index = 0
