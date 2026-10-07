@tool
@icon("res://addons/behaviors/icons/seek.svg")
class_name BehaviorSeek
extends BehaviorTargetMovementAction
## Moves toward a target and succeeds when it gets close enough.
##
## Fails when there is no target. Follows a navigation agent when the actor has one.

## How close counts as arrived, in world units.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:units") var arrive_distance: float = 0.5


func _on_update(delta: float) -> Status:
	var position: Variant = _get_target_position()
	if position == null:
		return Status.FAILURE
	if _distance_to(position) <= arrive_distance:
		_stop_moving()
		return Status.SUCCESS
	_move_to(_get_aim_position(position, delta), delta)
	return Status.RUNNING


## The position to move to, given the target's. [BehaviorPursue] predicts it.
func _get_aim_position(target_position: Variant, _delta: float) -> Variant:
	return target_position


func _get_graph_text() -> String:
	return "%s u/s" % speed
