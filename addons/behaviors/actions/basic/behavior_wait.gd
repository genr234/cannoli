@tool
@icon("res://addons/behaviors/icons/wait.svg")
class_name BehaviorWait
extends BehaviorAction
## Runs for a time, then succeeds. Pausing the agent pauses the wait.

## Seconds to wait.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var wait_time: float = 1.0
## Picks a random time between [member random_wait_min] and [member random_wait_max]
## instead.
@export var random_wait: bool = false
## The shortest random wait.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var random_wait_min: float = 1.0
## The longest random wait.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var random_wait_max: float = 1.0

var _remaining: float = 0.0


func _on_start() -> void:
	_remaining = randf_range(random_wait_min, random_wait_max) if random_wait else wait_time


func _on_update(delta: float) -> Status:
	_remaining -= delta
	return Status.SUCCESS if _remaining <= 0.0 else Status.RUNNING


func _get_graph_text() -> String:
	if random_wait:
		return "%s–%ss" % [random_wait_min, random_wait_max]
	return "%ss" % wait_time
