@tool
@icon("res://addons/behaviors/icons/interrupt.svg")
class_name BehaviorInterrupt
extends BehaviorDecorator
## Runs its child until something interrupts it, then stops the child and ends with
## the status given to [method interrupt]. Interrupt it with
## [BehaviorPerformInterruption] or from code.

var _interrupted: bool = false
var _interrupt_status: Status = Status.FAILURE


## Stops the child at once. The interrupt ends with [param with_status] on its next
## tick.
func interrupt(with_status: Status = Status.FAILURE) -> void:
	if not is_running:
		return
	_interrupted = true
	_interrupt_status = with_status
	_abort_children()


func _execute(delta: float) -> Status:
	if _interrupted:
		return _interrupt_status
	return super(delta)


func _on_end() -> void:
	_interrupted = false
	_interrupt_status = Status.FAILURE
