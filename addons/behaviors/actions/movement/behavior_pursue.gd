@tool
@icon("res://addons/behaviors/icons/seek.svg")
class_name BehaviorPursue
extends BehaviorSeek
## Moves toward where the target is going to be, and succeeds when it gets close.
##
## The prediction uses the target's velocity: exact for bodies, measured for other
## nodes. A fixed position is the same as a seek.

## The longest time ahead to predict, in seconds. Far targets are not predicted
## further than this.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var max_prediction: float = 2.0


func _get_aim_position(target_position: Variant, delta: float) -> Variant:
	return _predict(target_position, delta, max_prediction)
