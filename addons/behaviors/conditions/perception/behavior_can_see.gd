@tool
@icon("res://addons/behaviors/icons/eye.svg")
class_name BehaviorCanSee
extends BehaviorCondition
## Succeeds when the actor sees one of its candidates.
##
## A candidate is seen when it is within [member max_distance], inside the field of view
## and, with [member line_of_sight], not hidden behind a collider. The nearest seen
## candidate is stored. When nothing is seen the stored variables keep their last value.
## [br][br]
## Candidates come from a group, a node path and a bound variable, all together. The
## actor looks along its +X axis in 2D (see [member forward_2d]) and its -Z axis in 3D.

## Every node of this group is a candidate.
@export var target_group: StringName = &""
## A node relative to the actor that is a candidate.
@export var target_path: NodePath = NodePath()
## A node or an array of nodes that are candidates. Bind it to a variable.
@export var targets: Variant = null
## The width of the field of view, in degrees. 360 sees all around.
@export_range(0.0, 360.0, 0.1, "suffix:°") var field_of_view: float = 90.0
## How far the actor sees, in world units. 0 has no limit.
@export_range(0.0, 10000.0, 0.01, "or_greater", "suffix:units") var max_distance: float = 10.0
## Candidates behind a collider are not seen.
@export var line_of_sight: bool = true
## The physics layers that block the view.
@export_flags_2d_physics var collision_mask: int = 1
## Where the actor looks from, in its local space. Uses x and y in 2D.
@export var eye_offset: Vector3 = Vector3.ZERO
## Where on a candidate the actor looks, added to its position. Uses x and y in 2D.
## Lift it in 3D so the view does not end in the floor.
@export var target_offset: Vector3 = Vector3.ZERO
## Which way a 2D actor looks at rotation zero.
@export var forward_2d: BehaviorSpace.Forward2D = BehaviorSpace.Forward2D.RIGHT

@export_group("Results")
## The variable that receives the nearest node seen.
@export var store_target: String = ""
## The variable that receives its position.
@export var store_position: String = ""
## The variable that receives its distance.
@export var store_distance: String = ""


func _on_update(_delta: float) -> Status:
	var eye: Variant = BehaviorSpace.get_eye(actor, eye_offset)
	if eye == null:
		return Status.FAILURE
	var forward: Variant = BehaviorSpace.get_forward(actor, forward_2d)
	var half_angle := deg_to_rad(field_of_view) * 0.5
	var exclusions: Array[RID] = []
	if line_of_sight:
		exclusions = BehaviorSpace.get_exclusions(actor)
	var best: Node = null
	var best_position: Variant = null
	var best_distance := INF
	for node in BehaviorSpace.collect_nodes(self, target_group, target_path, targets):
		var position: Variant = BehaviorSpace.to_position(node, actor)
		if position == null:
			continue
		position += _get_offset()
		var distance: float = eye.distance_to(position)
		if distance >= best_distance or (max_distance > 0.0 and distance > max_distance):
			continue
		if field_of_view < 360.0 and distance > 0.0 and forward.angle_to(position - eye) > half_angle:
			continue
		if line_of_sight and not _is_visible(eye, position, node, exclusions):
			continue
		best = node
		best_position = position
		best_distance = distance
	if best == null:
		return Status.FAILURE
	if not store_target.is_empty():
		set_var(StringName(store_target), best)
	if not store_position.is_empty():
		set_var(StringName(store_position), best_position)
	if not store_distance.is_empty():
		set_var(StringName(store_distance), best_distance)
	return Status.SUCCESS


func _get_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if String(target_group).is_empty() and target_path.is_empty() and not bindings.has(&"targets") and targets == null:
		warnings.append("Can See has no candidates: set a group or a path, or bind \"targets\".")
	return warnings


func _get_graph_text() -> String:
	return "%s° %s u" % [field_of_view, max_distance]


func _get_offset() -> Variant:
	return Vector3(target_offset.x, target_offset.y, target_offset.z) if actor is Node3D else Vector2(target_offset.x, target_offset.y)


func _is_visible(eye: Variant, position: Variant, node: Node, exclusions: Array[RID]) -> bool:
	var hit := BehaviorSpace.raycast(actor, eye, position, collision_mask, exclusions)
	if hit.is_empty():
		return true
	var collider := hit.collider as Node
	return collider != null and (collider == node or node.is_ancestor_of(collider) or collider.is_ancestor_of(node))
