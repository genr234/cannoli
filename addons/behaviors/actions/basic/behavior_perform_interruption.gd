@tool
@icon("res://addons/behaviors/icons/perform_interruption.svg")
class_name BehaviorPerformInterruption
extends BehaviorAction
## Interrupts [BehaviorInterrupt] tasks, then succeeds. Each one stops its child at
## once and ends with the chosen status.

## The interrupt tasks to trigger. Pick them in the graph with the link button.
@export var interrupt_tasks: Array[BehaviorInterrupt] = []
## Makes the interrupted tasks succeed instead of fail.
@export var interrupt_success: bool = false


func _on_update(_delta: float) -> Status:
	for task in interrupt_tasks:
		if task:
			task.interrupt(Status.SUCCESS if interrupt_success else Status.FAILURE)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if interrupt_tasks.is_empty():
		warnings.append("Perform Interruption has no interrupt tasks.")
	return warnings
