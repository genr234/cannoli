@tool
@icon("res://addons/behaviors/icons/face.svg")
class_name BehaviorFace
extends BehaviorAction
## Turns the actor toward a target and succeeds when it looks at it.
##
## In 3D the actor turns around the Y axis only. Fails when there is no target.

## The node or position to look at. Bind it to a variable holding a node, a Vector2 or
## a Vector3.
@export var target: Variant = null
## A node to use when [member target] is empty, relative to the actor.
@export var target_path: NodePath = NodePath()
## How fast the actor turns. 0 turns at once.
@export_range(0.0, 1440.0, 1.0, "or_greater", "suffix:°/s") var turn_speed: float = 360.0
## How far off still counts as facing the target.
@export_range(0.0, 180.0, 0.1, "suffix:°") var angle_tolerance: float = 5.0
## Which way a 2D actor looks at rotation zero.
@export var forward_2d: BehaviorSpace.Forward2D = BehaviorSpace.Forward2D.RIGHT


func _on_update(delta: float) -> Status:
	var position: Variant = BehaviorSpace.resolve_position(self, target, target_path)
	if position == null:
		return Status.FAILURE
	var direction: Variant = BehaviorSpace.direction_between(BehaviorSpace.get_position(actor), position, actor is Node3D)
	if direction.is_zero_approx():
		return Status.SUCCESS
	var left := BehaviorSpace.rotate_toward(actor, direction, turn_speed, delta, forward_2d)
	return Status.SUCCESS if rad_to_deg(left) <= angle_tolerance else Status.RUNNING


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if target_path.is_empty() and not bindings.has(&"target") and target == null:
		warnings.append("Face needs a target: bind \"target\" or set a target path.")
	return warnings
