@tool
@icon("res://addons/behaviors/icons/weighted_random.svg")
class_name BehaviorWeightedRandomSelector
extends BehaviorComposite
## A selector that picks children at random, with some children more likely than
## others. A child that fails is left out and another is drawn. Succeeds as soon as
## a child succeeds.

## The weight of each child, by position. Missing weights count as 1. A weight of 0
## never runs that child.
@export var weights: PackedFloat32Array = PackedFloat32Array()
## Uses [member random_seed] so the draws are the same every run.
@export var use_seed: bool = false
## The seed used with [member use_seed].
@export var random_seed: int = 0

var _remaining: Array[int] = []
var _current: int = -1
var _execution_status: Status = Status.INACTIVE
var _rng := RandomNumberGenerator.new()


func _on_awake() -> void:
	if use_seed:
		_rng.seed = random_seed
	else:
		_rng.randomize()


func _on_start() -> void:
	_refill()
	_draw()


func current_child_index() -> int:
	return _current


func can_execute() -> bool:
	return _current >= 0 and _execution_status != Status.SUCCESS


func _on_child_executed(child_index: int, child_status: Status) -> void:
	_execution_status = child_status
	_remaining.erase(child_index)
	_draw()


func _on_conditional_abort(_child_index: int) -> void:
	_execution_status = Status.INACTIVE
	_refill()
	_draw()


func override_status(child_status: Status) -> Status:
	return Status.FAILURE if child_status == Status.INACTIVE else child_status


func _on_end() -> void:
	_execution_status = Status.INACTIVE
	_current = -1


func _get_weight(index: int) -> float:
	return maxf(weights[index], 0.0) if index < weights.size() else 1.0


func _refill() -> void:
	_remaining.clear()
	for index in children.size():
		if children[index] and _get_weight(index) > 0.0:
			_remaining.append(index)


func _draw() -> void:
	_current = -1
	var total := 0.0
	for index in _remaining:
		total += _get_weight(index)
	if total <= 0.0:
		return
	var roll := _rng.randf() * total
	for index in _remaining:
		roll -= _get_weight(index)
		if roll <= 0.0:
			_current = index
			return
	_current = _remaining.back()
