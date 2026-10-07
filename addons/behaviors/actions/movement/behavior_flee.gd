@tool
@icon("res://addons/behaviors/icons/flee.svg")
class_name BehaviorFlee
extends BehaviorTargetMovementAction
## Moves away from a target and succeeds when it is far enough.
##
## Fails when there is no target. With a navigation agent the actor runs to a reachable
## point away from the threat.

## The distance to reach, in world units. The task succeeds at this distance or more.
@export_range(0.0, 1000.0, 0.01, "or_greater", "suffix:units") var flee_distance: float = 10.0


func _on_update(delta: float) -> Status:
	var position: Variant = _get_target_position()
	if position == null:
		return Status.FAILURE
	var threat: Variant = _get_threat_position(position, delta)
	if _distance_to(position) >= flee_distance:
		_stop_moving()
		return Status.SUCCESS
	var own: Variant = BehaviorSpace.get_position(actor)
	var away: Variant = BehaviorSpace.direction_between(threat, own, _is_flat())
	if away.is_zero_approx():
		away = BehaviorSpace.random_point(BehaviorSpace.zero(actor), 1.0).normalized()
	_move_direction(away, delta, flee_distance)
	return Status.RUNNING


## The position to run from, given the target's. [BehaviorEvade] predicts it.
func _get_threat_position(target_position: Variant, _delta: float) -> Variant:
	return target_position


func _get_graph_text() -> String:
	return "%s u" % flee_distance
