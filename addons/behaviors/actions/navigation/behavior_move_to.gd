@tool
@icon("res://addons/behaviors/icons/navigation.svg")
class_name BehaviorMoveTo
extends BehaviorTargetMovementAction
## Walks to a position and succeeds when the actor gets there.
##
## With a navigation agent the actor follows its path, and the task fails when the
## path ends far from the target. Without one the actor walks in a straight line.

## How close counts as arrived, in world units.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:units") var arrive_distance: float = 0.5
## Fails when the navigation path ends before the target. When off, the task
## succeeds at the end of the path.
@export var fail_if_unreachable: bool = true


func _on_update(delta: float) -> Status:
	var position: Variant = _get_target_position()
	if position == null:
		return Status.FAILURE
	var distance := _distance_to(position)
	if distance <= arrive_distance:
		_stop_moving()
		return Status.SUCCESS
	_move_to(position, delta)
	if _is_navigation_finished():
		_stop_moving()
		if distance <= maxf(arrive_distance, _nav.target_desired_distance):
			return Status.SUCCESS
		return Status.FAILURE if fail_if_unreachable else Status.SUCCESS
	return Status.RUNNING
