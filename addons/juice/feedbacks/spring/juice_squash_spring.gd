@tool
@icon("res://addons/juice/icons/spring.svg")
class_name JuiceSquashSpring
extends JuiceSpringTransformBase
## Squashes and stretches a Node2D, Node3D or Control with a spring.
##
## One spring drives a stretch factor, 1 at rest. The stretched axis is scaled by the factor
## and the squashed axes by one over its square root, so the volume stays the same. The
## result multiplies the scale the target had, so squashing a node that is already scaled
## works. The factor is kept above 0.05 and mirrored back when it would go below.
## 2D nodes and controls ignore the z axis, so pick x and y options for them.

## Which axis stretches and which ones squash.
enum Axis { X_TO_YZ, X_TO_Y, X_TO_Z, Y_TO_XZ, Y_TO_X, Y_TO_Z, Z_TO_XZ, Z_TO_X, Z_TO_Y }

@export_group("Squash Spring")
## The stretch axis and the axes that squash when it stretches.
@export var axis: Axis = Axis.Y_TO_XZ
## The lowest random factor for MOVE_TO and MOVE_TO_ADDITIVE. 1 is the normal size.
@export var move_min: float = 1.0
## The highest random factor for MOVE_TO and MOVE_TO_ADDITIVE.
@export var move_max: float = 2.0
## The lowest random speed for BUMP.
@export var bump_min: float = 20.0
## The highest random speed for BUMP.
@export var bump_max: float = 30.0

var _rest_scale := Vector3.ONE
var _captured := false


func _is_supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


# The spring holds a factor, so a play continues from the factor it ended on.
func _read(_node: Node) -> Variant:
	if _spring != null and _spring.get_value_type() != JuiceSpring.ValueType.NONE:
		return _spring.current
	return 1.0


# The scale is remembered once: the factor is always applied on top of it.
func _capture(node: Node) -> void:
	if not _captured:
		_rest_scale = _get_scale(node)
		_captured = true


func _configure_spring(clone: JuiceSpring) -> void:
	clone.clamp_min = true
	clone.clamp_min_value = Vector4(0.05, 0.05, 0.05, 0.05)
	clone.clamp_min_initial = false
	clone.clamp_min_bounce = true


func _write(node: Node, value: Variant) -> void:
	var factor := maxf(float(value), 0.0001)
	var inverse := 1.0 / sqrt(factor)
	var multipliers := Vector3.ONE
	match axis:
		Axis.X_TO_YZ:
			multipliers = Vector3(factor, inverse, inverse)
		Axis.X_TO_Y:
			multipliers = Vector3(factor, inverse, 1.0)
		Axis.X_TO_Z:
			multipliers = Vector3(factor, 1.0, inverse)
		Axis.Y_TO_XZ:
			multipliers = Vector3(inverse, factor, inverse)
		Axis.Y_TO_X:
			multipliers = Vector3(inverse, factor, 1.0)
		Axis.Y_TO_Z:
			multipliers = Vector3(1.0, factor, inverse)
		Axis.Z_TO_XZ:
			multipliers = Vector3(inverse, inverse, factor)
		Axis.Z_TO_X:
			multipliers = Vector3(inverse, 1.0, factor)
		Axis.Z_TO_Y:
			multipliers = Vector3(1.0, inverse, factor)
	var result := _rest_scale * multipliers
	if node is Node3D:
		(node as Node3D).scale = result
	elif node is Node2D:
		(node as Node2D).scale = Vector2(result.x, result.y)
	elif node is Control:
		(node as Control).scale = Vector2(result.x, result.y)


func _get_amount(which: Amount) -> Variant:
	match which:
		Amount.MOVE_MIN:
			return move_min
		Amount.MOVE_MAX:
			return move_max
		Amount.BUMP_MIN:
			return bump_min
	return bump_max


func _get_scale(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).scale
	if node is Node2D:
		var scale_2d := (node as Node2D).scale
		return Vector3(scale_2d.x, scale_2d.y, 1.0)
	if node is Control:
		var scale_ui := (node as Control).scale
		return Vector3(scale_ui.x, scale_ui.y, 1.0)
	return Vector3.ONE
