@tool
@icon("res://addons/behaviors/icons/follow.svg")
class_name BehaviorFollow
extends BehaviorTargetMovementAction
## Keeps the actor within a distance of a target. Runs until interrupted.
##
## The actor walks toward the target when it is farther than the follow distance plus
## the tolerance, and stands still once it is within the follow distance. Fails when
## there is no target.

## The distance to keep, in world units.
@export_range(0.0, 1000.0, 0.01, "or_greater", "suffix:units") var follow_distance: float = 2.0
## How far past the follow distance the target can go before the actor starts
## moving again. Stops the actor from stuttering at the edge.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:units") var tolerance: float = 0.5

var _moving: bool = false


func _on_move_start() -> void:
	_moving = false


func _on_update(delta: float) -> Status:
	var position: Variant = _get_target_position()
	if position == null:
		return Status.FAILURE
	var distance := _distance_to(position)
	if distance > follow_distance + tolerance:
		_moving = true
	elif distance <= follow_distance:
		_moving = false
	if _moving:
		_move_to(position, delta)
	else:
		_stop_moving()
	return Status.RUNNING


func _get_graph_text() -> String:
	return "%s u" % follow_distance
