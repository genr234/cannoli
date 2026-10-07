@tool
@icon("res://addons/behaviors/icons/raycast.svg")
class_name BehaviorRaycast
extends BehaviorCondition
## Casts a ray from the actor and succeeds when it hits something.
##
## The ray starts at the actor, skips the actor's own colliders, and goes toward a target
## or along a direction. What it hit is stored in variables.

## Where the ray points.
enum Direction {
	## Toward the target.
	TARGET,
	## The way the actor looks: +X in 2D (see [member forward_2d]), -Z in 3D.
	FORWARD,
	## The opposite way.
	BACKWARD,
	## 90 degrees to the left of forward, seen from above in 3D.
	LEFT,
	## 90 degrees to the right of forward, seen from above in 3D.
	RIGHT,
	## Down in the world.
	DOWN,
	## Up in the world.
	UP,
}

## Where the ray points.
@export var direction: Direction = Direction.FORWARD
## The node or position to aim at with [constant Direction.TARGET]. Bind it to a
## variable holding a node, a Vector2 or a Vector3.
@export var target: Variant = null
## A node to use when [member target] is empty, relative to the actor.
@export var target_path: NodePath = NodePath()
## How far the ray goes, in world units. With [constant Direction.TARGET] the ray stops
## at the target when it is closer.
@export_range(0.0, 10000.0, 0.01, "or_greater", "suffix:units") var length: float = 10.0
## The physics layers the ray hits.
@export_flags_2d_physics var collision_mask: int = 1
## Hits physics bodies.
@export var hit_bodies: bool = true
## Hits areas.
@export var hit_areas: bool = false
## Where the ray starts, in the actor's local space. Uses x and y in 2D.
@export var origin_offset: Vector3 = Vector3.ZERO
## Which way a 2D actor looks at rotation zero.
@export var forward_2d: BehaviorSpace.Forward2D = BehaviorSpace.Forward2D.RIGHT

@export_group("Results")
## The variable that receives the node the ray hit.
@export var store_collider: String = ""
## The variable that receives the point where it hit.
@export var store_point: String = ""
## The variable that receives the surface normal at that point.
@export var store_normal: String = ""


func _on_update(_delta: float) -> Status:
	var from: Variant = BehaviorSpace.get_eye(actor, origin_offset)
	if from == null:
		return Status.FAILURE
	var aim: Variant = _get_direction(from)
	if aim == null:
		return Status.FAILURE
	var reach := length
	if direction == Direction.TARGET:
		var position: Variant = BehaviorSpace.resolve_position(self, target, target_path)
		reach = minf(length, from.distance_to(position)) if length > 0.0 else from.distance_to(position)
	var hit := BehaviorSpace.raycast(actor, from, from + aim * reach, collision_mask, BehaviorSpace.get_exclusions(actor), hit_bodies, hit_areas)
	if hit.is_empty():
		return Status.FAILURE
	if not store_collider.is_empty():
		set_var(StringName(store_collider), hit.collider)
	if not store_point.is_empty():
		set_var(StringName(store_point), hit.position)
	if not store_normal.is_empty():
		set_var(StringName(store_normal), hit.normal)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if direction == Direction.TARGET and target_path.is_empty() and not bindings.has(&"target") and target == null:
		warnings.append("Raycast aims at a target but has none: bind \"target\" or set a target path.")
	if not hit_bodies and not hit_areas:
		warnings.append("Raycast hits neither bodies nor areas.")
	return warnings


func _get_graph_text() -> String:
	return Direction.keys()[direction].capitalize()


# Null when there is nothing to aim at.
func _get_direction(from: Variant) -> Variant:
	var forward: Variant = BehaviorSpace.get_forward(actor, forward_2d)
	match direction:
		Direction.TARGET:
			var position: Variant = BehaviorSpace.resolve_position(self, target, target_path)
			if position == null:
				return null
			var aim: Variant = (position - from).normalized()
			return null if aim.is_zero_approx() else aim
		Direction.BACKWARD:
			return -forward
		Direction.LEFT:
			return forward.rotated(Vector3.UP, PI * 0.5) if forward is Vector3 else forward.rotated(-PI * 0.5)
		Direction.RIGHT:
			return forward.rotated(Vector3.UP, -PI * 0.5) if forward is Vector3 else forward.rotated(PI * 0.5)
		Direction.DOWN:
			return Vector3.DOWN if actor is Node3D else Vector2.DOWN
		Direction.UP:
			return Vector3.UP if actor is Node3D else Vector2.UP
	return forward
