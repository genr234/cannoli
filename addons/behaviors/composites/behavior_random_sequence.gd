@tool
@icon("res://addons/behaviors/icons/random_sequence.svg")
class_name BehaviorRandomSequence
extends BehaviorComposite
## A sequence that runs its children in a random order. Fails as soon as a child
## fails, and succeeds when every child succeeded.

## Uses [member random_seed] so the order is the same every run, which helps debugging.
@export var use_seed: bool = false
## The seed used with [member use_seed].
@export var random_seed: int = 0

var _order: Array[int] = []
var _execution_status: Status = Status.INACTIVE
var _rng := RandomNumberGenerator.new()


func _on_awake() -> void:
	if use_seed:
		_rng.seed = random_seed
	else:
		_rng.randomize()


func _on_start() -> void:
	_shuffle()


func current_child_index() -> int:
	return _order.back() if not _order.is_empty() else -1


func can_execute() -> bool:
	return not _order.is_empty() and _execution_status != Status.FAILURE


func _on_child_executed(_child_index: int, child_status: Status) -> void:
	if not _order.is_empty():
		_order.pop_back()
	_execution_status = child_status


func _on_conditional_abort(_child_index: int) -> void:
	_execution_status = Status.INACTIVE
	_shuffle()


func _on_end() -> void:
	_execution_status = Status.INACTIVE
	_order.clear()


func _shuffle() -> void:
	_order.clear()
	for child_index in children.size():
		_order.append(child_index)
	for i in range(_order.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := _order[i]
		_order[i] = _order[j]
		_order[j] = swap
