@tool
@icon("res://addons/juice/icons/spring.svg")
class_name JuiceRotationSpring
extends JuiceSpringTransformBase
## Rotates a Node2D, Node3D or Control with a spring. Values are in degrees.
##
## 3D nodes use all three axes as Euler angles. 2D nodes and controls rotate around their
## only axis, which is the z value. Bump speeds are in degrees per second.

## Which rotation is animated. Controls only have a local rotation.
enum Space { LOCAL, GLOBAL }

@export_group("Rotation Spring")
## Local or global rotation.
@export var space: Space = Space.LOCAL
## The lowest random angle for MOVE_TO and MOVE_TO_ADDITIVE.
@export var move_min: Vector3 = Vector3(0.0, 0.0, 45.0)
## The highest random angle for MOVE_TO and MOVE_TO_ADDITIVE.
@export var move_max: Vector3 = Vector3(0.0, 0.0, 90.0)
## The lowest random speed for BUMP.
@export var bump_min: Vector3 = Vector3(0.0, 0.0, 1500.0)
## The highest random speed for BUMP.
@export var bump_max: Vector3 = Vector3(0.0, 0.0, 2500.0)


func _is_supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node) -> Variant:
	if node is Node3D:
		var node_3d := node as Node3D
		return node_3d.rotation_degrees if space == Space.LOCAL else node_3d.global_rotation_degrees
	if node is Node2D:
		var node_2d := node as Node2D
		return Vector3(0.0, 0.0, node_2d.rotation_degrees if space == Space.LOCAL else node_2d.global_rotation_degrees)
	return Vector3(0.0, 0.0, (node as Control).rotation_degrees)


func _write(node: Node, value: Variant) -> void:
	var angles: Vector3 = value
	if node is Node3D:
		if space == Space.LOCAL:
			(node as Node3D).rotation_degrees = angles
		else:
			(node as Node3D).global_rotation_degrees = angles
	elif node is Node2D:
		if space == Space.LOCAL:
			(node as Node2D).rotation_degrees = angles.z
		else:
			(node as Node2D).global_rotation_degrees = angles.z
	elif node is Control:
		(node as Control).rotation_degrees = angles.z


func _get_amount(which: Amount) -> Variant:
	match which:
		Amount.MOVE_MIN:
			return move_min
		Amount.MOVE_MAX:
			return move_max
		Amount.BUMP_MIN:
			return bump_min
	return bump_max
