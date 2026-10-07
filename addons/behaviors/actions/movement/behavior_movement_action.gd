@tool
@abstract
@icon("res://addons/behaviors/icons/movement.svg")
class_name BehaviorMovementAction
extends BehaviorAction
## Base of the movement tasks. Moves the actor in 2D or 3D, along a navigation path
## or in a straight line.
##
## A [CharacterBody2D] or [CharacterBody3D] actor gets its velocity set and
## [code]move_and_slide()[/code] called every physics frame. Any other [Node2D] or
## [Node3D] is moved directly. The actor stops when the task ends.
## [br][br]
## Subclasses override [method _on_move_start] and [method _on_update] and call
## [method _move_to] or [method _move_direction] from the update.

## Whether the task follows a [NavigationAgent2D] or [NavigationAgent3D].
enum NavigationMode {
	## Follow the agent when the actor has one.
	AUTO,
	## Follow the agent. Warns when there is none and moves in a straight line.
	ON,
	## Always move in a straight line.
	OFF,
}

## How fast the actor moves, in world units per second (pixels in 2D).
@export_range(0.0, 1000.0, 0.01, "or_greater", "suffix:units/s") var speed: float = 5.0
## Follows a navigation agent, or moves in a straight line.
@export var use_navigation: NavigationMode = NavigationMode.AUTO
## The navigation agent, relative to the actor. Empty uses the first navigation agent
## among the actor's children.
@export var navigation_agent: NodePath = NodePath()
## Turns the actor toward where it moves.
@export var face_movement: bool = false
## How fast the actor turns with [member face_movement]. 0 turns at once.
@export_range(0.0, 1440.0, 1.0, "or_greater", "suffix:°/s") var turn_speed: float = 360.0
## Which way a 2D actor looks at rotation zero. Used by [member face_movement].
@export var forward_2d: BehaviorSpace.Forward2D = BehaviorSpace.Forward2D.RIGHT
## Lets a 3D actor move up and down too. When off, movement stays on the ground
## plane and a body keeps its own vertical velocity, so gravity still works.
@export var move_vertically: bool = false

var _body: Node
var _nav: Node
var _velocity: Variant = Vector2.ZERO
var _goal: Variant = null
var _nav_age: int = 0
var _warned: bool = false


#region Virtual methods

## Called when the task starts, after the movement is set up.
func _on_move_start() -> void:
	pass

#endregion

func _on_start() -> void:
	_body = actor if actor is CharacterBody2D or actor is CharacterBody3D else null
	_nav = null
	if use_navigation != NavigationMode.OFF:
		var found := BehaviorSpace.find_navigation_agent(self, navigation_agent)
		if found and (found is NavigationAgent3D) == (actor is Node3D):
			_nav = found
		elif use_navigation == NavigationMode.ON and not _warned:
			_warned = true
			push_warning("%s: no navigation agent found for \"%s\", moving in a straight line." % [get_display_name(), actor.name if actor else ""])
	_velocity = BehaviorSpace.zero(actor)
	_goal = null
	_nav_age = 0
	_on_move_start()


func _on_physics_update(_delta: float) -> void:
	if _body == null or not is_running:
		return
	_apply_to_body(_velocity)
	if _body is CharacterBody2D:
		(_body as CharacterBody2D).move_and_slide()
	else:
		(_body as CharacterBody3D).move_and_slide()


func _on_end() -> void:
	_stop_moving()
	if _body:
		_apply_to_body(_velocity)
	_nav = null


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if speed <= 0.0:
		warnings.append("%s has no speed, so it will never move." % get_display_name())
	return warnings


#region Movement

## Moves toward a position. With a navigation agent the actor follows its path.
## With [param clamp_to_goal] the step never goes past the goal.
func _move_to(goal: Variant, delta: float, clamp_to_goal: bool = true) -> void:
	var position: Variant = BehaviorSpace.get_position(actor)
	if position == null:
		return
	var aim: Variant = goal
	if _nav:
		_refresh_navigation(goal)
		if _nav.is_navigation_finished():
			_stop_moving()
			return
		aim = _nav.get_next_path_position()
	var direction: Variant = BehaviorSpace.direction_between(position, aim, _is_flat())
	var limit := speed
	if clamp_to_goal and delta > 0.0:
		limit = minf(speed, BehaviorSpace.distance_between(position, aim, _is_flat()) / delta)
	_set_velocity(direction * limit, delta)


## Moves along a direction for this frame. With a navigation agent it aims at a point
## [param lookahead] units away instead.
func _move_direction(direction: Variant, delta: float, lookahead: float = 1.0) -> void:
	if _nav:
		var position: Variant = BehaviorSpace.get_position(actor)
		if position != null:
			_move_to(position + direction * lookahead, delta, false)
		return
	_set_velocity(direction * speed, delta)


## Stops moving. A body keeps its vertical velocity in 3D unless [member move_vertically]
## is on.
func _stop_moving() -> void:
	_velocity = BehaviorSpace.zero(actor)


## True when the navigation agent has no path left to follow. It stays false for the
## first frames after a new goal, while the path is still being found.
func _is_navigation_finished() -> bool:
	return _nav != null and _nav_age >= 2 and _nav.is_navigation_finished()


## True when the 3D movement ignores height.
func _is_flat() -> bool:
	return actor is Node3D and not move_vertically


## The distance between the actor and a position, ignoring height when the task is flat.
func _distance_to(position: Variant) -> float:
	return BehaviorSpace.distance_between(BehaviorSpace.get_position(actor), position, _is_flat())


func _refresh_navigation(goal: Variant) -> void:
	var threshold := maxf(_nav.target_desired_distance, 0.1)
	if _goal == null or _goal.distance_to(goal) > threshold:
		_goal = goal
		_nav.target_position = goal
		_nav_age = 0
	else:
		_nav_age += 1


func _set_velocity(velocity: Variant, delta: float) -> void:
	_velocity = velocity
	if face_movement and not velocity.is_zero_approx():
		BehaviorSpace.rotate_toward(actor, velocity, turn_speed, delta, forward_2d)
	if _body == null:
		BehaviorSpace.set_position(actor, BehaviorSpace.get_position(actor) + velocity * delta)


func _apply_to_body(velocity: Variant) -> void:
	if _body is CharacterBody3D:
		var body := _body as CharacterBody3D
		var value: Vector3 = velocity
		if _is_flat():
			value.y = body.velocity.y
		body.velocity = value
	elif _body is CharacterBody2D:
		(_body as CharacterBody2D).velocity = velocity

#endregion
