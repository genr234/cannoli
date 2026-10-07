@tool
@icon("res://addons/behaviors/icons/wander.svg")
class_name BehaviorWander
extends BehaviorMovementAction
## Walks to random points around the actor. Never succeeds unless it has a duration.
##
## In 3D the points are on the ground plane at the actor's height.

## How far from the center a point can be, in world units.
@export_range(0.0, 1000.0, 0.01, "or_greater", "suffix:units") var radius: float = 10.0
## Picks points around the place the actor first started wandering, so it stays in one
## area. When off, points are around where the actor stands.
@export var around_start: bool = true
## How close counts as arrived, in world units.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:units") var arrive_distance: float = 0.5
## The shortest rest at each point.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var pause_min: float = 0.0
## The longest rest at each point.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var pause_max: float = 0.0
## Seconds before the task succeeds. 0 wanders forever.
@export_range(0.0, 3600.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.0

var _origin: Variant = null
var _destination: Variant = null
var _elapsed: float = 0.0
var _rest: float = 0.0


func _on_move_start() -> void:
	if _origin == null:
		_origin = BehaviorSpace.get_position(actor)
	_elapsed = 0.0
	_rest = 0.0
	_pick_destination()


func _on_update(delta: float) -> Status:
	_elapsed += delta
	if duration > 0.0 and _elapsed >= duration:
		return Status.SUCCESS
	if _rest > 0.0:
		_rest -= delta
		_stop_moving()
		if _rest <= 0.0:
			_pick_destination()
		return Status.RUNNING
	if _destination == null:
		return Status.RUNNING
	if _distance_to(_destination) <= arrive_distance or _is_navigation_finished():
		_stop_moving()
		_rest = randf_range(minf(pause_min, pause_max), maxf(pause_min, pause_max))
		if _rest <= 0.0:
			_pick_destination()
		return Status.RUNNING
	_move_to(_destination, delta)
	return Status.RUNNING


func _get_graph_text() -> String:
	return "%s u" % radius


func _pick_destination() -> void:
	var center: Variant = _origin if around_start else BehaviorSpace.get_position(actor)
	if center == null:
		return
	_destination = BehaviorSpace.random_point(center, radius)
	_goal = null
	_nav_age = 0
