@tool
class_name BehaviorSpace
extends RefCounted
## Math shared by the movement, navigation and perception tasks, so one task works
## for both 2D and 3D actors.
##
## Positions are a [Vector2] for a [Node2D] and a [Vector3] for a [Node3D]. Values of
## the other dimension are converted: a Vector2 becomes (x, 0, y) in 3D, and a
## Vector3 loses its y in 2D. 3D rotation here is yaw only, around the Y axis.

## Which way a 2D node looks when its rotation is zero.
enum Forward2D {
	RIGHT,
	UP,
	DOWN,
	LEFT,
}


#region Positions

## True when [param node] is a [Node3D].
static func is_3d(node: Node) -> bool:
	return node is Node3D


## The zero vector of the node's dimension.
static func zero(node: Node) -> Variant:
	return Vector3.ZERO if node is Node3D else Vector2.ZERO


## The global position of a [Node2D] or [Node3D], or null for other nodes.
static func get_position(node: Node) -> Variant:
	if node is Node2D:
		return (node as Node2D).global_position
	if node is Node3D:
		return (node as Node3D).global_position
	return null


## Moves a [Node2D] or [Node3D] to a global position.
static func set_position(node: Node, position: Variant) -> void:
	if node is Node2D:
		(node as Node2D).global_position = convert_dimension(position, false)
	elif node is Node3D:
		(node as Node3D).global_position = convert_dimension(position, true)


## Converts a Vector2 or Vector3 to the requested dimension. Anything else returns
## null.
static func convert_dimension(value: Variant, to_3d: bool) -> Variant:
	if value is Vector2:
		return Vector3(value.x, 0.0, value.y) if to_3d else value
	if value is Vector3:
		return value if to_3d else Vector2(value.x, value.z)
	return null


## Turns a node or a vector into a position in the dimension of [param like].
## Returns null when it is neither.
static func to_position(value: Variant, like: Node) -> Variant:
	if value is Node:
		var position: Variant = get_position(value)
		return null if position == null else convert_dimension(position, like is Node3D)
	if value is Vector2 or value is Vector3:
		return convert_dimension(value, like is Node3D)
	return null


## Distance between two positions of the same dimension. With [param flat], 3D
## distances ignore the height.
static func distance_between(from: Variant, to: Variant, flat: bool = false) -> float:
	if flat and from is Vector3 and to is Vector3:
		return Vector2(from.x, from.z).distance_to(Vector2(to.x, to.z))
	return from.distance_to(to)


## The unit direction from one position to another. Zero when they are the same.
## With [param flat], the 3D direction stays on the ground.
static func direction_between(from: Variant, to: Variant, flat: bool = false) -> Variant:
	var delta: Variant = to - from
	if flat and delta is Vector3:
		delta.y = 0.0
	return delta.normalized()


## The velocity of a body, or zero for other nodes.
static func get_velocity(node: Node) -> Variant:
	if node is CharacterBody2D:
		return (node as CharacterBody2D).velocity
	if node is CharacterBody3D:
		return (node as CharacterBody3D).velocity
	if node is RigidBody2D:
		return (node as RigidBody2D).linear_velocity
	if node is RigidBody3D:
		return (node as RigidBody3D).linear_velocity
	return zero(node)


## A random point inside a disc (2D) or on a flat disc (3D) around [param center].
static func random_point(center: Variant, radius: float) -> Variant:
	var offset := Vector2.from_angle(randf() * TAU) * radius * sqrt(randf())
	if center is Vector3:
		return center + Vector3(offset.x, 0.0, offset.y)
	return center + offset

#endregion

#region Facing

## The unit vector the node looks along.
static func get_forward(node: Node, forward_2d: Forward2D = Forward2D.RIGHT) -> Variant:
	if node is Node3D:
		return -(node as Node3D).global_transform.basis.z.normalized()
	if node is Node2D:
		return (node as Node2D).global_transform.basis_xform(_local_forward(forward_2d)).normalized()
	return Vector2.RIGHT


## The angle in radians between where the node looks and [param direction]. 3D angles
## are around the Y axis only. Positive turns one way, negative the other.
static func get_angle_to(node: Node, direction: Variant, forward_2d: Forward2D = Forward2D.RIGHT) -> float:
	var forward: Variant = get_forward(node, forward_2d)
	if forward is Vector3:
		var flat_direction: Vector3 = direction
		flat_direction.y = 0.0
		var flat_forward: Vector3 = forward
		flat_forward.y = 0.0
		if flat_direction.is_zero_approx() or flat_forward.is_zero_approx():
			return 0.0
		return flat_forward.signed_angle_to(flat_direction, Vector3.UP)
	if direction is Vector2 and not direction.is_zero_approx():
		return (forward as Vector2).angle_to(direction)
	return 0.0


## Turns the node toward [param direction] by at most [param turn_speed] degrees per
## second. A speed of 0 turns at once. Returns the angle left in radians.
static func rotate_toward(node: Node, direction: Variant, turn_speed: float, delta: float, forward_2d: Forward2D = Forward2D.RIGHT) -> float:
	var angle := get_angle_to(node, direction, forward_2d)
	var step := angle
	if turn_speed > 0.0:
		var limit := deg_to_rad(turn_speed) * delta
		step = clampf(angle, -limit, limit)
	if node is Node3D:
		(node as Node3D).global_rotate(Vector3.UP, step)
	elif node is Node2D:
		(node as Node2D).global_rotation += step
	return absf(angle - step)


static func _local_forward(forward_2d: Forward2D) -> Vector2:
	match forward_2d:
		Forward2D.UP:
			return Vector2.UP
		Forward2D.DOWN:
			return Vector2.DOWN
		Forward2D.LEFT:
			return Vector2.LEFT
	return Vector2.RIGHT

#endregion

#region Finding things

## Resolves a target node for a task. A bound [param value] that is a node wins, then
## [param path] relative to the actor. Null when there is no node.
static func resolve_node(task: BehaviorTask, value: Variant, path: NodePath) -> Node:
	if value is Object:
		return value as Node if is_instance_valid(value) else null
	if not path.is_empty():
		return task.get_node_from_actor(path)
	return null


## Resolves a target position for a task: a bound position or node, then the node at
## [param path]. Null when there is nothing.
static func resolve_position(task: BehaviorTask, value: Variant, path: NodePath) -> Variant:
	if value is Vector2 or value is Vector3:
		return convert_dimension(value, task.actor is Node3D)
	var node := resolve_node(task, value, path)
	return to_position(node, task.actor) if node else null


## The first [NavigationAgent2D] or [NavigationAgent3D] at [param path] relative to
## the actor, or the first one among the actor's children.
static func find_navigation_agent(task: BehaviorTask, path: NodePath) -> Node:
	if not path.is_empty():
		var node := task.get_node_from_actor(path)
		return node if node is NavigationAgent2D or node is NavigationAgent3D else null
	if task.actor == null:
		return null
	for child in task.actor.get_children():
		if child is NavigationAgent2D or child is NavigationAgent3D:
			return child
	return null


## The first [CollisionObject2D] or [CollisionObject3D] of the actor, which is the
## actor itself, a child, or null.
static func find_body(actor: Node) -> Node:
	if actor is CollisionObject2D or actor is CollisionObject3D:
		return actor
	if actor:
		for child in actor.get_children():
			if child is CollisionObject2D or child is CollisionObject3D:
				return child
	return null


## Collects nodes from a group, a path or a bound value (a node or an array of nodes).
## The actor itself is left out.
static func collect_nodes(task: BehaviorTask, group: StringName, path: NodePath, value: Variant) -> Array[Node]:
	var found: Array[Node] = []
	if not String(group).is_empty() and task.actor and task.actor.is_inside_tree():
		for node in task.actor.get_tree().get_nodes_in_group(group):
			found.append(node)
	if not path.is_empty():
		var node := task.get_node_from_actor(path)
		if node:
			found.append(node)
	if value is Array:
		for item in value:
			if item is Node and is_instance_valid(item):
				found.append(item)
	elif value is Node and is_instance_valid(value):
		found.append(value)
	found = found.filter(func(node: Node) -> bool: return node != task.actor)
	return found

#endregion

#region Physics queries

## The point a node sees from: its position plus [param offset] in its local space.
## The offset uses x and y in 2D.
static func get_eye(node: Node, offset: Vector3) -> Variant:
	if node is Node3D:
		return (node as Node3D).global_transform * offset
	if node is Node2D:
		return (node as Node2D).global_transform * Vector2(offset.x, offset.y)
	return null


## Casts a ray in the actor's world. [param exclude] holds RIDs to skip. Returns the
## engine's result dictionary: [code]position[/code], [code]normal[/code],
## [code]collider[/code] and more, or an empty dictionary when nothing was hit.
static func raycast(actor: Node, from: Variant, to: Variant, mask: int, exclude: Array[RID], hit_bodies: bool = true, hit_areas: bool = false) -> Dictionary:
	if actor is Node2D:
		var space := (actor as Node2D).get_world_2d().direct_space_state
		var query := PhysicsRayQueryParameters2D.create(from, to, mask, exclude)
		query.collide_with_bodies = hit_bodies
		query.collide_with_areas = hit_areas
		return space.intersect_ray(query)
	if actor is Node3D:
		var space := (actor as Node3D).get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(from, to, mask, exclude)
		query.collide_with_bodies = hit_bodies
		query.collide_with_areas = hit_areas
		return space.intersect_ray(query)
	return {}


## The RIDs of the actor's collision objects, so rays can skip the actor itself.
static func get_exclusions(actor: Node) -> Array[RID]:
	var rids: Array[RID] = []
	if actor == null:
		return rids
	var nodes: Array[Node] = [actor]
	nodes.append_array(actor.get_children())
	for node in nodes:
		if node is CollisionObject2D:
			rids.append((node as CollisionObject2D).get_rid())
		elif node is CollisionObject3D:
			rids.append((node as CollisionObject3D).get_rid())
	return rids


## The navigation map of the actor's world.
static func get_navigation_map(actor: Node) -> RID:
	if actor is Node2D:
		return (actor as Node2D).get_world_2d().get_navigation_map()
	if actor is Node3D:
		return (actor as Node3D).get_world_3d().get_navigation_map()
	return RID()


## True when a path on the actor's navigation map ends within [param tolerance] of
## [param target].
static func is_reachable(actor: Node, target: Variant, tolerance: float) -> bool:
	var map := get_navigation_map(actor)
	if not map.is_valid():
		return false
	var from: Variant = get_position(actor)
	if actor is Node3D:
		var path := NavigationServer3D.map_get_path(map, from, target, true)
		return not path.is_empty() and path[path.size() - 1].distance_to(target) <= tolerance
	var path2 := NavigationServer2D.map_get_path(map, from, target, true)
	return not path2.is_empty() and path2[path2.size() - 1].distance_to(target) <= tolerance

#endregion
