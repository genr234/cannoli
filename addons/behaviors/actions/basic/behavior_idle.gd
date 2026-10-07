@tool
@icon("res://addons/behaviors/icons/idle.svg")
class_name BehaviorIdle
extends BehaviorAction
## Runs forever. Use it to keep a branch alive until something interrupts it.


func _on_update(_delta: float) -> Status:
	return Status.RUNNING
