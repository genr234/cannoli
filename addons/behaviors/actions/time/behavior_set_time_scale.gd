@tool
@icon("res://addons/behaviors/icons/time.svg")
class_name BehaviorSetTimeScale
extends BehaviorAction
## Sets the speed of the whole game with [member Engine.time_scale].

## 1 is normal speed, 0.5 is half speed, 0 is a freeze.
@export_range(0.0, 4.0, 0.01, "or_greater") var time_scale: float = 1.0


func _on_update(_delta: float) -> Status:
	Engine.time_scale = time_scale
	return Status.SUCCESS


func _get_graph_text() -> String:
	return "×%s" % time_scale
