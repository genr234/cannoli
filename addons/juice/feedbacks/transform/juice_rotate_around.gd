@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceRotateAround
extends JuiceFeedback
## Moves a node on an arc around another node, without turning the moving node.
##
## The curve value of each axis becomes an angle in degrees. A 3D node uses all three
## axes. A 2D node or a control uses the z angle only, so turn z on for those.
## Intensity multiplies the angle.

## EACH_PLAY starts the arc from where the node is. INITIAL always starts from where
## the node was when the player initialized.
enum Origin { EACH_PLAY, INITIAL }

@export_group("Rotate Around")
## The node to circle around. Path is relative to the player.
@export var center: NodePath
## Where the arc starts from.
@export var origin: Origin = Origin.EACH_PLAY
## Seconds one play takes. 0 applies the final angle at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.2
## The angle a curve value of 0 maps to, in degrees.
@export_range(-720.0, 720.0, 0.1, "or_greater", "or_less", "suffix:°") var remap_zero: float = 0.0
## The angle a curve value of 1 maps to, in degrees.
@export_range(-720.0, 720.0, 0.1, "or_greater", "or_less", "suffix:°") var remap_one: float = 180.0
@export_subgroup("Axes")
## Rotates around the x axis (3D only).
@export var animate_x: bool = false
## Rotates around the y axis (3D only).
@export var animate_y: bool = true
## Rotates around the z axis. This is the only axis of 2D nodes and controls.
@export var animate_z: bool = false
## The curve of the x angle. Null is a straight line.
@export var tween_x: JuiceTween
## The curve of the y angle. Null is a straight line.
@export var tween_y: JuiceTween
## The curve of the z angle. Null is a straight line.
@export var tween_z: JuiceTween

var _initial := Vector3.ZERO
var _start := Vector3.ZERO


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _on_initialize() -> void:
	var node := get_target()
	if _supported(node):
		_initial = _read(node)
		_start = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _supported(node):
		return
	if origin == Origin.INITIAL:
		_start = _initial
	elif not is_retrigger():
		_start = _read(node)
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
	var pivot_node := resolve(center)
	if pivot_node == null or pivot_node == node:
		return
	var pivot := Juice.node_position(pivot_node)
	var share := get_intensity()
	var angles := Vector3.ZERO
	if animate_x:
		angles.x = lerpf(remap_zero, remap_one, JuiceTween.sample(tween_x, progress)) * share
	if animate_y:
		angles.y = lerpf(remap_zero, remap_one, JuiceTween.sample(tween_y, progress)) * share
	if animate_z:
		angles.z = lerpf(remap_zero, remap_one, JuiceTween.sample(tween_z, progress)) * share
	if node is Node3D:
		var basis := Basis.from_euler(angles * (PI / 180.0), EULER_ORDER_YXZ)
		_write(node, pivot + basis * (_start - pivot))
	else:
		var turn := Vector2(_start.x - pivot.x, _start.y - pivot.y).rotated(deg_to_rad(angles.z))
		_write(node, Vector3(pivot.x + turn.x, pivot.y + turn.y, 0.0))


func _supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node) -> Vector3:
	return Juice.node_position(node)


func _write(node: Node, value: Vector3) -> void:
	if node is Node3D:
		(node as Node3D).global_position = value
	elif node is Node2D:
		(node as Node2D).global_position = Vector2(value.x, value.y)
	elif node is Control:
		(node as Control).global_position = Vector2(value.x, value.y)
