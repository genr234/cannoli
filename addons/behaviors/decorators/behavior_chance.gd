@tool
@icon("res://addons/behaviors/icons/chance.svg")
class_name BehaviorChance
extends BehaviorDecorator
## Runs its child only some of the time. Otherwise fails without running it.

## The odds of running the child, from 0 to 1.
@export_range(0.0, 1.0, 0.01) var chance: float = 0.5

var _rolled: bool = false


func _execute(delta: float) -> Status:
	if not _rolled:
		_rolled = true
		if randf() >= chance:
			return Status.FAILURE
	return super(delta)


func _get_graph_text() -> String:
	return "%d%%" % roundi(chance * 100.0)


func _on_end() -> void:
	_rolled = false
