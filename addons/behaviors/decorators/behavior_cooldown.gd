@tool
@icon("res://addons/behaviors/icons/cooldown.svg")
class_name BehaviorCooldown
extends BehaviorDecorator
## Spaces out runs of its child.

## What the cooldown does.
enum Mode {
	## Runs the child, then keeps running for [member duration] before returning the
	## child's status.
	WAIT_AFTER,
	## Runs the child, then fails at once on every start until [member duration] has
	## passed since the child ended.
	BLOCK_RESTART,
}

## What the cooldown does.
@export var mode: Mode = Mode.WAIT_AFTER
## Seconds of cooldown, in tree time.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var duration: float = 2.0

var _execution_status: Status = Status.INACTIVE
var _ended_at: float = -INF


func _execute(delta: float) -> Status:
	if _execution_status == Status.INACTIVE:
		if mode == Mode.BLOCK_RESTART and _now() - _ended_at < duration:
			return Status.FAILURE
		var child := get_child()
		if child == null:
			return Status.SUCCESS
		_running_child = 0
		var result := child.tick(delta)
		if result == Status.RUNNING:
			return result
		_running_child = -1
		_execution_status = result
		_ended_at = _now()
		if mode == Mode.BLOCK_RESTART:
			return result
	if _now() - _ended_at < duration:
		return Status.RUNNING
	return _execution_status


func _get_graph_text() -> String:
	return "%ss" % duration


func _on_end() -> void:
	_execution_status = Status.INACTIVE


func _now() -> float:
	return agent.get_time() if agent else Time.get_ticks_msec() / 1000.0
