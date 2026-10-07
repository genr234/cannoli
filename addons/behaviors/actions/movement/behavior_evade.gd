@tool
@icon("res://addons/behaviors/icons/flee.svg")
class_name BehaviorEvade
extends BehaviorFlee
## Moves away from where the target is going to be, and succeeds when it is far
## enough.
##
## The prediction uses the target's velocity: exact for bodies, measured for other
## nodes.

## The longest time ahead to predict, in seconds.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var max_prediction: float = 2.0


func _get_threat_position(target_position: Variant, delta: float) -> Variant:
	return _predict(target_position, delta, max_prediction)
