@tool
@icon("res://addons/behaviors/icons/patrol.svg")
class_name BehaviorPatrol
extends BehaviorMovementAction
## Walks between waypoints.
##
## Waypoints come from [member waypoints], from the children of [member waypoints_node],
## or both. The task runs forever, or succeeds at the last waypoint with
## [constant Mode.ONCE]. By default it carries on from the waypoint it was heading to
## when it was interrupted.

## The order the waypoints are visited in.
enum Mode {
	## Last to first again.
	LOOP,
	## Forward, then backward, then forward again.
	PING_PONG,
	## Any other waypoint, at random.
	RANDOM,
	## Each once, then the task succeeds.
	ONCE,
}

## What to do at the end of the waypoints.
@export var mode: Mode = Mode.LOOP
## Waypoints as positions or nodes. Bind it to a variable holding an array of them.
@export var waypoints: Array = []
## A node whose children are the waypoints, relative to the actor.
@export var waypoints_node: NodePath = NodePath()
## How close counts as arrived, in world units.
@export_range(0.0, 100.0, 0.01, "or_greater", "suffix:units") var arrive_distance: float = 0.5
## Seconds to rest at each waypoint.
@export_range(0.0, 60.0, 0.01, "or_greater", "suffix:s") var wait_time: float = 0.0
## Starts from the waypoint nearest to the actor instead of the first.
@export var start_nearest: bool = false
## Starts from the beginning every time the task starts, instead of carrying on.
@export var reset_on_start: bool = false

var _points: Array[Variant] = []
var _index: int = -1
var _step: int = 1
var _wait: float = 0.0


func _on_move_start() -> void:
	_points = _gather()
	if reset_on_start:
		_index = -1
	if _points.is_empty():
		return
	if _index < 0 or _index >= _points.size():
		_index = _nearest() if start_nearest else 0
		_step = 1
	_wait = 0.0


func _on_update(delta: float) -> Status:
	if _points.is_empty():
		return Status.FAILURE
	if _wait > 0.0:
		_wait -= delta
		_stop_moving()
		return Status.RUNNING
	var point: Variant = _points[_index]
	if _distance_to(point) <= arrive_distance or _is_navigation_finished():
		_stop_moving()
		if mode == Mode.ONCE and _index == _points.size() - 1:
			_index = -1
			return Status.SUCCESS
		_advance()
		_wait = wait_time
		return Status.RUNNING
	_move_to(point, delta)
	return Status.RUNNING


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if waypoints.is_empty() and waypoints_node.is_empty() and not bindings.has(&"waypoints"):
		warnings.append("Patrol has no waypoints.")
	return warnings


func _get_graph_text() -> String:
	return Mode.keys()[mode].capitalize()


func _gather() -> Array[Variant]:
	var found: Array[Variant] = []
	for item in waypoints:
		var position: Variant = BehaviorSpace.to_position(item, actor)
		if position != null:
			found.append(position)
	if not waypoints_node.is_empty():
		var parent := get_node_from_actor(waypoints_node)
		if parent:
			for child in parent.get_children():
				var position: Variant = BehaviorSpace.to_position(child, actor)
				if position != null:
					found.append(position)
	return found


func _nearest() -> int:
	var best := 0
	var best_distance := INF
	for index in _points.size():
		var distance := _distance_to(_points[index])
		if distance < best_distance:
			best_distance = distance
			best = index
	return best


func _advance() -> void:
	var count := _points.size()
	if count <= 1:
		return
	_goal = null
	_nav_age = 0
	match mode:
		Mode.RANDOM:
			var next := randi() % (count - 1)
			_index = next if next < _index else next + 1
		Mode.PING_PONG:
			if _index + _step < 0 or _index + _step >= count:
				_step = -_step
			_index += _step
		_:
			_index = (_index + 1) % count
