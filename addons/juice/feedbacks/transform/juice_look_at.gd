@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceLookAt
extends JuiceFeedback
## Turns a node to face a node, a world position or a direction over time.
##
## 3D nodes use their -Z axis as the front (unless [member use_model_front] is on). 2D
## nodes and controls rotate so that their +X axis points at the goal; use
## [member angle_offset] for art that faces another way. The goal is read every frame,
## so a moving target is followed. Intensity is the share of the turn that shows.

## NODE looks at [member look_at_node]. WORLD_POSITION looks at a fixed point.
## DIRECTION looks along a vector from the node.
enum Goal { NODE, WORLD_POSITION, DIRECTION }
## The up hint of a 3D node: world up, forward (-Z) or right (+X).
enum UpVector { UP, FORWARD, RIGHT }

@export_group("Look At")
## What the node turns toward.
@export var goal: Goal = Goal.NODE:
	set(value):
		goal = value
		notify_property_list_changed()
## Seconds one play takes. 0 turns at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 1.0
## The curve of the turn. Null is a straight line.
@export var tween: JuiceTween
## The node to face when the goal is NODE. Path is relative to the player.
@export var look_at_node: NodePath
## The point to face when the goal is WORLD_POSITION. 2D uses x and y.
@export var world_position: Vector3 = Vector3.FORWARD
## The direction to face when the goal is DIRECTION. 2D uses x and y.
@export var direction: Vector3 = Vector3.FORWARD
@export_subgroup("3D")
## The up hint used to roll the node.
@export var up_vector: UpVector = UpVector.UP
## Faces +Z instead of -Z, for models whose front is on the positive side.
@export var use_model_front: bool = false
## Keeps the x rotation (in degrees, global Euler angles) as it was.
@export var lock_x: bool = false
## Keeps the y rotation as it was.
@export var lock_y: bool = false
## Keeps the z rotation as it was.
@export var lock_z: bool = false
@export_subgroup("2D")
## Degrees added to the angle, for art that does not face right.
@export_range(-360.0, 360.0, 0.1, "suffix:°") var angle_offset: float = 0.0

var _initial := Basis.IDENTITY
var _initial_angle := 0.0
var _start := Basis.IDENTITY
var _start_angle := 0.0


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	var prop_name: String = property.name
	if prop_name == "look_at_node" and goal != Goal.NODE:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "world_position" and goal != Goal.WORLD_POSITION:
		property.usage &= ~PROPERTY_USAGE_EDITOR
	elif prop_name == "direction" and goal != Goal.DIRECTION:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _on_initialize() -> void:
	var node := get_target()
	if not _supported(node):
		return
	_initial = _basis_of(node)
	_initial_angle = _angle_of(node)
	_start = _initial
	_start_angle = _initial_angle


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _supported(node):
		return
	if not is_retrigger():
		_start = _basis_of(node)
		_start_angle = _angle_of(node)
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if _supported(node):
		_apply(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if not _supported(node):
		return
	if node is Node3D:
		var node_3d := node as Node3D
		node_3d.global_basis = _initial
	else:
		_set_angle(node, _initial_angle)


func _supported(node: Node) -> bool:
	return node is Node3D or node is Node2D or node is Control


func _apply(node: Node, progress: float) -> void:
	var weight := JuiceTween.sample(tween, progress) * get_intensity()
	if node is Node3D:
		_apply_3d(node as Node3D, weight)
	else:
		_apply_2d(node, weight)


func _goal_position(from: Vector3) -> Vector3:
	match goal:
		Goal.NODE:
			var other := resolve(look_at_node)
			return Juice.node_position(other) if other != null and other != get_target() else from
		Goal.WORLD_POSITION:
			return world_position
	return from + direction


func _apply_3d(node: Node3D, weight: float) -> void:
	var from := node.global_position
	var to := _goal_position(from)
	var facing := to - from
	if facing.length_squared() < 0.000001:
		return
	var up := Vector3.UP
	match up_vector:
		UpVector.FORWARD:
			up = Vector3.FORWARD
		UpVector.RIGHT:
			up = Vector3.RIGHT
	facing = facing.normalized()
	if absf(facing.dot(up)) > 0.9999:
		return
	var wanted := Basis.looking_at(facing, up, use_model_front).orthonormalized()
	if lock_x or lock_y or lock_z:
		var euler := wanted.get_euler()
		var current := _start.orthonormalized().get_euler()
		if lock_x:
			euler.x = current.x
		if lock_y:
			euler.y = current.y
		if lock_z:
			euler.z = current.z
		wanted = Basis.from_euler(euler)
	var start_quat := _start.orthonormalized().get_rotation_quaternion()
	var blended := start_quat.slerp(wanted.get_rotation_quaternion(), clampf(weight, 0.0, 1.0))
	var scale_before := node.global_basis.get_scale()
	node.global_basis = Basis(blended).scaled(scale_before)


func _apply_2d(node: Node, weight: float) -> void:
	var from := _position_2d(node)
	var to_3d := _goal_position(Vector3(from.x, from.y, 0.0))
	var facing := Vector2(to_3d.x, to_3d.y) - from
	if facing.length_squared() < 0.000001:
		return
	var wanted := facing.angle() + deg_to_rad(angle_offset)
	_set_angle(node, _start_angle + angle_difference(_start_angle, wanted) * weight)


func _position_2d(node: Node) -> Vector2:
	if node is Control:
		var control := node as Control
		return control.global_position + control.pivot_offset * control.get_global_transform().get_scale()
	return (node as Node2D).global_position


func _basis_of(node: Node) -> Basis:
	return (node as Node3D).global_basis if node is Node3D else Basis.IDENTITY


func _angle_of(node: Node) -> float:
	if node is Node2D:
		return (node as Node2D).global_rotation
	if node is Control:
		return (node as Control).get_global_transform().get_rotation()
	return 0.0


func _set_angle(node: Node, angle: float) -> void:
	if node is Node2D:
		(node as Node2D).global_rotation = angle
	elif node is Control:
		# Controls only know their own rotation, so remove the parent's share.
		var control := node as Control
		var parent := control.get_parent() as CanvasItem
		var parent_angle := parent.get_global_transform().get_rotation() if parent != null else 0.0
		control.rotation = angle - parent_angle
