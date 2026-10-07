@tool
@abstract
@icon("res://addons/behaviors/icons/movement.svg")
class_name BehaviorTargetMovementAction
extends BehaviorMovementAction
## Base of the movement tasks that move relative to a target: seek, flee, follow.
##
## The target is a node or a position. Bind [member target] to a variable that holds
## one, or set [member target_path] to a node relative to the actor.

## The node or position to move relative to. Bind it to a variable holding a node, a
## Vector2 or a Vector3.
@export var target: Variant = null
## A node to use when [member target] is empty, relative to the actor.
@export var target_path: NodePath = NodePath()

var _last_target_position: Variant = null


func _on_start() -> void:
	_last_target_position = null
	super()


func _get_warnings() -> PackedStringArray:
	var warnings := super()
	if target_path.is_empty() and not bindings.has(&"target") and target == null:
		warnings.append("%s needs a target: bind \"target\" or set a target path." % get_display_name())
	return warnings


## The target's position in the actor's dimension, or null when there is no target.
func _get_target_position() -> Variant:
	return BehaviorSpace.resolve_position(self, target, target_path)


## Where the target will be in about [param max_time] seconds or less, assuming it
## keeps its velocity. Bodies report their velocity. Other nodes are measured between
## calls, so call this every update.
func _predict(target_position: Variant, delta: float, max_time: float) -> Variant:
	var node := BehaviorSpace.resolve_node(self, target, target_path)
	var velocity: Variant = BehaviorSpace.zero(actor)
	if node:
		velocity = BehaviorSpace.convert_dimension(BehaviorSpace.get_velocity(node), actor is Node3D)
	if node and velocity.is_zero_approx() and _last_target_position != null and delta > 0.0:
		velocity = (target_position - _last_target_position) / delta
	_last_target_position = target_position
	if velocity.is_zero_approx():
		return target_position
	var distance := _distance_to(target_position)
	var time := minf(distance / maxf(speed, 0.001), max_time)
	return target_position + velocity * time
