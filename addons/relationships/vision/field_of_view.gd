@tool
class_name FieldOfView
extends Resource
## An area in front of a sensor, defined by horizontal and vertical arcs and a
## maximum distance. Used by [CanSeeAdvanced].

## Horizontal viewing angle in degrees. Ignored in 2D.
@export_range(0, 360, 0.1, "degrees") var horizontal_fov := 120.0
## Vertical viewing angle in degrees. In 2D, this is the viewing angle.
@export_range(0, 360, 0.1, "degrees") var vertical_fov := 120.0
## How far the field of view extends.
@export var max_distance := 10.0


static func create(horizontal: float, vertical: float, distance: float) -> FieldOfView:
	var fov := FieldOfView.new()
	fov.horizontal_fov = horizontal
	fov.vertical_fov = vertical
	fov.max_distance = distance
	return fov


## Whether [param target] is inside this field of view, seen from [param origin].
## 3D nodes look along -Z; 2D nodes look along +X.
func contains(origin: Node, target_position: Vector3) -> bool:
	if origin is Node2D:
		var from_2d: Vector2 = origin.global_position
		var to_2d := Vector2(target_position.x, target_position.y)
		if from_2d.distance_to(to_2d) > max_distance:
			return false
		var facing: Vector2 = (origin as Node2D).global_transform.x.normalized()
		return rad_to_deg(absf(facing.angle_to(to_2d - from_2d))) < vertical_fov * 0.5
	if origin is Node3D:
		var from: Vector3 = origin.global_position
		if from.distance_to(target_position) > max_distance:
			return false
		# Horizontal angle: between the facing and the target, both flattened.
		var forward: Vector3 = -(origin as Node3D).global_basis.z
		var level_forward := Vector3(forward.x, 0.0, forward.z)
		var level_target := Vector3(target_position.x - from.x, 0.0, target_position.z - from.z)
		if not level_forward.is_zero_approx() and not level_target.is_zero_approx():
			if rad_to_deg(level_forward.angle_to(level_target)) > horizontal_fov * 0.5:
				return false
		# Vertical angle: the target's elevation above or below the horizontal plane.
		var to_target := target_position - from
		if to_target.is_zero_approx():
			return true
		var elevation := rad_to_deg(absf(atan2(to_target.y, Vector2(to_target.x, to_target.z).length())))
		return elevation < vertical_fov * 0.5
	return false
