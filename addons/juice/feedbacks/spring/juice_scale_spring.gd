@tool
@icon("res://addons/juice/icons/spring.svg")
class_name JuiceScaleSpring
extends JuiceSpringTransformBase
## Scales a Node2D, Node3D or Control with a spring.
##
## Scale is absolute: 1 is the normal size, so MOVE_TO between 1 and 2 goes to double size.
## Only x and y matter in 2D. Bump speeds are in scale per second.

@export_group("Scale Spring")
## The lowest random scale for MOVE_TO and MOVE_TO_ADDITIVE.
@export var move_min: Vector3 = Vector3(1.0, 1.0, 1.0)
## The highest random scale for MOVE_TO and MOVE_TO_ADDITIVE.
@export var move_max: Vector3 = Vector3(2.0, 2.0, 2.0)
## The lowest random speed for BUMP.
@export var bump_min: Vector3 = Vector3(20.0, 20.0, 20.0)
## The highest random speed for BUMP.
@export var bump_max: Vector3 = Vector3(30.0, 30.0, 30.0)


func _is_supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node) -> Variant:
	if node is Node3D:
		return (node as Node3D).scale
	var scale_2d: Vector2 = (node as Node2D).scale if node is Node2D else (node as Control).scale
	return Vector3(scale_2d.x, scale_2d.y, 1.0)


func _write(node: Node, value: Variant) -> void:
	var factor: Vector3 = value
	if node is Node3D:
		(node as Node3D).scale = factor
	elif node is Node2D:
		(node as Node2D).scale = Vector2(factor.x, factor.y)
	elif node is Control:
		(node as Control).scale = Vector2(factor.x, factor.y)


func _get_amount(which: Amount) -> Variant:
	match which:
		Amount.MOVE_MIN:
			return move_min
		Amount.MOVE_MAX:
			return move_max
		Amount.BUMP_MIN:
			return bump_min
	return bump_max
