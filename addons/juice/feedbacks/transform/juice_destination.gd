@tool
@icon("res://addons/juice/icons/transform.svg")
class_name JuiceDestination
extends JuiceFeedback
## Moves, turns and scales a node until it matches another node.
##
## The start is the node's current state (or [member origin_node]) and the end is the
## state of [member destination_node]. Position and rotation are global, scale is
## local. Works on Node2D, Node3D and Control. Intensity is the share of the way
## that is covered.

@export_group("Destination")
## The node to match. Path is relative to the player.
@export var destination_node: NodePath
## Starts from [member origin_node] instead of the current state of the target.
@export var force_origin: bool = false:
	set(value):
		force_origin = value
		notify_property_list_changed()
## The node to start from when [member force_origin] is on.
@export var origin_node: NodePath
## Seconds one play takes. 0 applies the final state at once.
@export_range(0.0, 10.0, 0.01, "or_greater", "suffix:s") var duration: float = 0.2
## Reads the destination every frame, so a moving destination is followed.
@export var update_destination_every_frame: bool = false
@export_subgroup("Curves")
## The curve used for everything that has no curve of its own.
@export var tween: JuiceTween = JuiceTween.make_ease_in_out()
## A separate curve for the position. Null uses the main curve.
@export var position_tween: JuiceTween
## A separate curve for the rotation. Null uses the main curve.
@export var rotation_tween: JuiceTween
## A separate curve for the scale. Null uses the main curve.
@export var scale_tween: JuiceTween
@export_subgroup("Axes")
## Moves along x.
@export var animate_position_x: bool = true
## Moves along y.
@export var animate_position_y: bool = true
## Moves along z (3D only).
@export var animate_position_z: bool = true
## Turns the node.
@export var animate_rotation: bool = true
## Scales along x.
@export var animate_scale_x: bool = true
## Scales along y.
@export var animate_scale_y: bool = true
## Scales along z (3D only).
@export var animate_scale_z: bool = true

var _initial := _Pose.new()
var _from := _Pose.new()
var _to := _Pose.new()


func _validate_property(property: Dictionary) -> void:
	super._validate_property(property)
	if property.name == "origin_node" and not force_origin:
		property.usage &= ~PROPERTY_USAGE_EDITOR


func _get_duration() -> float:
	return duration


func _get_category() -> StringName:
	return Juice.CATEGORY_MOTION


func _on_initialize() -> void:
	_initial = _Pose.new()
	_from = _Pose.new()
	_to = _Pose.new()
	var node := get_target()
	if _supported(node):
		_initial = _capture(node)
		_from = _initial


func _on_play(_feedback_intensity: float) -> void:
	var node := get_target()
	if not _supported(node):
		return
	if not is_retrigger():
		var source := resolve(origin_node) if force_origin else node
		_from = _capture(source if _supported(source) else node)
		# Locked axes stay where the node is.
		var current := _capture(node)
		_lock(_from, current)
	_cache_destination(node)
	if duration <= 0.0:
		_apply(node, 0.0 if is_reversed() else 1.0)


func _on_progress(progress: float) -> void:
	var node := get_target()
	if not _supported(node):
		return
	if update_destination_every_frame:
		_cache_destination(node)
	_apply(node, progress)


func _on_restore() -> void:
	var node := get_target()
	if _supported(node):
		_write(node, _initial)


func _cache_destination(node: Node) -> void:
	var destination := resolve(destination_node)
	if not _supported(destination):
		_to = _from
		return
	_to = _capture(destination)
	_lock(_to, _from)


# Copies the values of locked axes from [param keep] into [param pose].
func _lock(pose: _Pose, keep: _Pose) -> void:
	if not animate_position_x:
		pose.position.x = keep.position.x
	if not animate_position_y:
		pose.position.y = keep.position.y
	if not animate_position_z:
		pose.position.z = keep.position.z
	if not animate_scale_x:
		pose.scale.x = keep.scale.x
	if not animate_scale_y:
		pose.scale.y = keep.scale.y
	if not animate_scale_z:
		pose.scale.z = keep.scale.z
	if not animate_rotation:
		pose.basis = keep.basis
		pose.angle = keep.angle


func _apply(node: Node, progress: float) -> void:
	var share := get_intensity()
	var position_weight := JuiceTween.sample(position_tween if position_tween != null else tween, progress) * share
	var rotation_weight := JuiceTween.sample(rotation_tween if rotation_tween != null else tween, progress) * share
	var scale_weight := JuiceTween.sample(scale_tween if scale_tween != null else tween, progress) * share
	var pose := _Pose.new()
	pose.position = _from.position.lerp(_to.position, position_weight)
	pose.scale = _from.scale.lerp(_to.scale, scale_weight)
	pose.angle = lerp_angle(_from.angle, _to.angle, rotation_weight)
	var from_quat := _from.basis.get_rotation_quaternion()
	pose.basis = Basis(from_quat.slerp(_to.basis.get_rotation_quaternion(), clampf(rotation_weight, 0.0, 1.0)))
	_write(node, pose)


func _supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _capture(node: Node) -> _Pose:
	var pose := _Pose.new()
	if node is Node3D:
		var node_3d := node as Node3D
		pose.position = node_3d.global_position
		pose.basis = node_3d.global_basis.orthonormalized()
		pose.scale = node_3d.scale
	elif node is Node2D:
		var node_2d := node as Node2D
		pose.position = Vector3(node_2d.global_position.x, node_2d.global_position.y, 0.0)
		pose.angle = node_2d.global_rotation
		pose.scale = Vector3(node_2d.scale.x, node_2d.scale.y, 1.0)
	elif node is Control:
		var control := node as Control
		pose.position = Vector3(control.global_position.x, control.global_position.y, 0.0)
		pose.angle = control.get_global_transform().get_rotation()
		pose.scale = Vector3(control.scale.x, control.scale.y, 1.0)
	return pose


func _write(node: Node, pose: _Pose) -> void:
	if node is Node3D:
		var node_3d := node as Node3D
		node_3d.global_position = pose.position
		node_3d.global_basis = pose.basis
		node_3d.scale = pose.scale
	elif node is Node2D:
		var node_2d := node as Node2D
		node_2d.global_position = Vector2(pose.position.x, pose.position.y)
		node_2d.global_rotation = pose.angle
		node_2d.scale = Vector2(pose.scale.x, pose.scale.y)
	elif node is Control:
		var control := node as Control
		# Rotation and scale first: they move a control that is not pivoted at its corner.
		var parent := control.get_parent() as CanvasItem
		var parent_angle := parent.get_global_transform().get_rotation() if parent != null else 0.0
		control.rotation = pose.angle - parent_angle
		control.scale = Vector2(pose.scale.x, pose.scale.y)
		control.global_position = Vector2(pose.position.x, pose.position.y)


## Position, rotation and scale of a node. Rotation is a basis for 3D and an angle
## in radians for 2D and controls.
class _Pose:
	extends RefCounted

	var position := Vector3.ZERO
	var basis := Basis.IDENTITY
	var angle := 0.0
	var scale := Vector3.ONE
