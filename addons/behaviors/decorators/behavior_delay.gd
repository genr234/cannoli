@tool
@icon("res://addons/behaviors/icons/delay.svg")
class_name BehaviorDelay
extends BehaviorDecorator
## Waits before running its child.

## Seconds to wait, in tree time.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var delay: float = 1.0
## Adds a random amount between 0 and this to each wait.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var random_extra: float = 0.0

var _remaining: float = 0.0
var _waited: bool = false


func _on_start() -> void:
	_remaining = delay + randf() * random_extra
	_waited = false


func _execute(delta: float) -> Status:
	if not _waited:
		_remaining -= delta
		if _remaining > 0.0:
			return Status.RUNNING
		_waited = true
	return super(delta)


func _get_graph_text() -> String:
	return "%ss" % delay
