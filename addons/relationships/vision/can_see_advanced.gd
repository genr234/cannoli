@tool
@icon("../icons/vision.svg")
class_name CanSeeAdvanced
extends Node
## Replaces a faction member's line-of-sight check with one that uses fields
## of view, several ray heights and see-through layers.
##
## Add it as a child of the character, next to its [FactionMember].

## The member whose [member FactionMember.can_see] is replaced. If empty, the
## nearest [FactionMember] is used.
@export var member: FactionMember
## The target must be in at least one of these. Defaults to a central, wide
## and peripheral field of view.
@export var fields_of_view: Array[FieldOfView] = [
	FieldOfView.create(45.0, 120.0, 20.0),
	FieldOfView.create(120.0, 120.0, 15.0),
	FieldOfView.create(180.0, 120.0, 5.0),
]
## Extra heights above the target's origin to cast rays to. A low wall might
## hide a character's feet and body, but not its head.
@export var extra_raycast_heights := PackedFloat32Array()
## Colliders on these layers don't block sight.
@export_flags_3d_physics var see_through_layers := 0

## The position checked most recently, for debugging.
var last_point_checked := Vector3.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if member == null:
		member = FactionMember.find_nearest(self)
	if member == null:
		push_warning("Relationships: %s can't find a FactionMember." % get_path())
		return
	member.can_see = can_see


## Whether the member can see [param actor].
func can_see(actor: FactionMember) -> bool:
	if member == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return false
	var target := actor.get_global_position_3d()
	last_point_checked = target
	return _is_in_fovs(target) and _is_in_line_of_sight(actor, target)


func _is_in_fovs(target: Vector3) -> bool:
	var eyes := member.get_eyes()
	for fov in fields_of_view:
		if fov != null and fov.contains(eyes, target):
			return true
	return false


func _is_in_line_of_sight(actor: FactionMember, target: Vector3) -> bool:
	if _ray_reaches(actor, target):
		return true
	# Up is +Y in 3D and -Y in 2D.
	var up := Vector3.DOWN if member.is_2d() else Vector3.UP
	for height in extra_raycast_heights:
		if _ray_reaches(actor, target + up * height):
			return true
	return false


# Casts a ray toward the target, skipping see-through colliders.
func _ray_reaches(actor: FactionMember, target: Vector3) -> bool:
	var excluded: Array[RID] = []
	var own_body := member.get_body()
	if own_body is CollisionObject2D or own_body is CollisionObject3D:
		excluded.append(own_body.get_rid())
	var eyes := member.get_eyes()
	for i in 20:
		var hit := _intersect(eyes, target, excluded)
		if hit.is_empty():
			return false
		var collider: Node = hit.get("collider")
		if collider != null and FactionMember.find_member(collider) == actor:
			return true
		var layer: int = collider.collision_layer if collider is CollisionObject2D or collider is CollisionObject3D else 0
		if layer & see_through_layers == 0:
			return false
		excluded.append(hit.rid)
	return false


func _intersect(eyes: Node, target: Vector3, excluded: Array[RID]) -> Dictionary:
	if eyes is Node2D:
		var query_2d := PhysicsRayQueryParameters2D.create(eyes.global_position, Vector2(target.x, target.y), member.sight_collision_mask, excluded)
		return (eyes as Node2D).get_world_2d().direct_space_state.intersect_ray(query_2d)
	if eyes is Node3D:
		var query_3d := PhysicsRayQueryParameters3D.create(eyes.global_position, target, member.sight_collision_mask, excluded)
		return (eyes as Node3D).get_world_3d().direct_space_state.intersect_ray(query_3d)
	return {}
