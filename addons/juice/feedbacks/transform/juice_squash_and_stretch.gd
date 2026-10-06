@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceSquashAndStretch
extends JuiceFeedback
## Stretches a node along one axis while the other axes shrink to keep its volume.
##
## The curve value becomes a scale factor of the main axis. The other axes get one over
## the square root of that factor, so the node looks like it keeps its mass. It works on
## Node2D, Node3D and Control (2D nodes and controls have no z axis).

## ABSOLUTE uses the remapped curve as the factor. ADDITIVE adds it to a factor of 1.
## TO_DESTINATION moves the factor from 1 to [member destination_factor].
enum Mode { ABSOLUTE, ADDITIVE, TO_DESTINATION }
## The first letter is the main axis. The letters after "to" are the axes that
## compensate for it.
enum Axis { X_TO_YZ, X_TO_Y, X_TO_Z, Y_TO_XZ, Y_TO_X, Y_TO_Z, Z_TO_XY, Z_TO_X, Z_TO_Y }

@export_group("Squash and Stretch")
## How the curve value is used.
@export var mode: Mode = Mode.ABSOLUTE:
	set(value):
		mode = value
		notify_property_list_changed()
## The main axis and the axes that compensate.
@export var axis: Axis = Axis.Y_TO_XZ
## Seconds one play takes. 0 applies the final value at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.2
## The curve of the effect. Null is a straight line.
@export var tween: JuiceTween
## What a curve value of 0 maps to.
@export var remap_zero: float = 1.0
## What a curve value of 1 maps to.
@export var remap_one: float = 2.0
## Added to the curve value before it is remapped.
@export var offset: float = 0.0
## The factor reached at the end of a TO_DESTINATION play.
@export var destination_factor: float = 2.0
## Reads the scale again at the start of every play instead of using the one found
## when the player initialized.
@export var determine_scale_on_play: bool = true

var _initial := Vector3.ONE
var _origin := Vector3.ONE


func _init() -> void:
	var curve := Curve.new()
	curve.max_value = 2.0
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.3, 1.5))
	curve.add_point(Vector2(1.0, 0.0))
	tween = JuiceTween.make_curve(curve)


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "destination_factor" and mode != Mode.TO_DESTINATION:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name in ["remap_zero", "remap_one"] and mode == Mode.TO_DESTINATION:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _on_initialize() -> void:
	var node := get_target()
	if _supported(node):
		_initial = _read(node)
		_origin = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _supported(node):
		return
	if not is_retrigger():
		_origin = _read(node) if determine_scale_on_play else _initial
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if _supported(node):
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if _supported(node):
		_write(node, _initial)


func _apply(node: Node, progress: float) -> void:
	var curve_value := JuiceTween.sample(tween, progress) + offset
	var factor: float
	match mode:
		Mode.ADDITIVE:
			factor = 1.0 + lerpf(remap_zero, remap_one, curve_value)
		Mode.TO_DESTINATION:
			factor = lerpf(1.0, destination_factor, curve_value)
		_:
			factor = lerpf(remap_zero, remap_one, curve_value)
	# Intensity is the share of the squash that shows (a factor of 1 is no change).
	factor = maxf(absf(lerpf(1.0, factor, get_intensity())), 0.0001)
	var inverse := 1.0 / sqrt(factor)
	var main := _main_axis()
	var scaled := _origin
	scaled[main] = _origin[main] * factor
	for other in _compensating_axes():
		scaled[other] = _origin[other] * inverse
	_write(node, scaled)


func _main_axis() -> int:
	match axis:
		Axis.X_TO_YZ, Axis.X_TO_Y, Axis.X_TO_Z:
			return 0
		Axis.Y_TO_XZ, Axis.Y_TO_X, Axis.Y_TO_Z:
			return 1
	return 2


func _compensating_axes() -> Array[int]:
	match axis:
		Axis.X_TO_YZ:
			return [1, 2]
		Axis.X_TO_Y:
			return [1]
		Axis.X_TO_Z:
			return [2]
		Axis.Y_TO_XZ:
			return [0, 2]
		Axis.Y_TO_X:
			return [0]
		Axis.Y_TO_Z:
			return [2]
		Axis.Z_TO_XY:
			return [0, 1]
		Axis.Z_TO_X:
			return [0]
	return [1]


func _supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node) -> Vector3:
	if node is Node3D:
		return (node as Node3D).scale
	var scale_2d: Vector2 = node.scale
	return Vector3(scale_2d.x, scale_2d.y, 1.0)


func _write(node: Node, value: Vector3) -> void:
	if node is Node3D:
		(node as Node3D).scale = value
	else:
		node.scale = Vector2(value.x, value.y)
