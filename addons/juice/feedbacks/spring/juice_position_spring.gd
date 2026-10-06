@tool
@icon("res://addons/juice/icons/spring.svg")
class_name JuicePositionSpring
extends JuiceSpringTransformBase
## Moves a Node2D, Node3D or Control with a spring.
##
## MOVE_TO uses absolute positions: pixels for 2D nodes and controls, units for 3D nodes.
## Bump and additive amounts are in units with y pointing up, like 3D. For 2D nodes and
## controls they are multiplied by [member pixels_per_unit] and y is flipped, so the same
## values feel alike in every kind of scene. Only x and y matter in 2D.
##
## With [member follow_node] set, MOVE_TO heads for that node and keeps following it, and
## MOVE_TO_ADDITIVE aims at that node plus the amount picked when the feedback started.
## The followed position is global, so use the GLOBAL space for this. The spring follows
## for as long as the feedback lasts.

## Which position is animated.
enum Space { LOCAL, GLOBAL }

@export_group("Position Spring")
## Local or global position.
@export var space: Space = Space.LOCAL
## Pixels per unit of a bump or additive amount, for 2D nodes and controls.
@export_range(1.0, 1000.0, 1.0, "or_greater") var pixels_per_unit: float = 64.0
## The lowest random value for MOVE_TO and MOVE_TO_ADDITIVE.
@export var move_min: Vector3 = Vector3(1.0, 1.0, 1.0)
## The highest random value for MOVE_TO and MOVE_TO_ADDITIVE.
@export var move_max: Vector3 = Vector3(2.0, 2.0, 2.0)
## The lowest random speed for BUMP.
@export var bump_min: Vector3 = Vector3(0.0, 20.0, 0.0)
## The highest random speed for BUMP.
@export var bump_max: Vector3 = Vector3(0.0, 30.0, 0.0)
## A node to follow in MOVE_TO and MOVE_TO_ADDITIVE.
@export var follow_node: NodePath
## Mirrors the spring around the initial position, so it never goes past it.
@export var force_absolute: bool = false

var _follow_offset := Vector3.ZERO


func _is_supported(node: Node) -> bool:
	return node is Node2D or node is Node3D or node is Control


func _read(node: Node) -> Variant:
	if node is Node3D:
		var node_3d := node as Node3D
		return node_3d.position if space == Space.LOCAL else node_3d.global_position
	var point := Vector2.ZERO
	if node is Node2D:
		var node_2d := node as Node2D
		point = node_2d.position if space == Space.LOCAL else node_2d.global_position
	else:
		var control := node as Control
		point = control.position if space == Space.LOCAL else control.global_position
	return Vector3(point.x, point.y, 0.0)


func _write(node: Node, value: Variant) -> void:
	var shown: Vector3 = value
	if force_absolute and typeof(_initial) == TYPE_VECTOR3:
		var origin: Vector3 = _initial
		shown = Vector3(absf(shown.x - origin.x) + origin.x, absf(shown.y - origin.y) + origin.y,
				absf(shown.z - origin.z) + origin.z)
	if node is Node3D:
		if space == Space.LOCAL:
			(node as Node3D).position = shown
		else:
			(node as Node3D).global_position = shown
	elif node is Node2D:
		if space == Space.LOCAL:
			(node as Node2D).position = Vector2(shown.x, shown.y)
		else:
			(node as Node2D).global_position = Vector2(shown.x, shown.y)
	elif node is Control:
		if space == Space.LOCAL:
			(node as Control).position = Vector2(shown.x, shown.y)
		else:
			(node as Control).global_position = Vector2(shown.x, shown.y)


func _get_amount(which: Amount) -> Variant:
	match which:
		Amount.MOVE_MIN:
			return move_min
		Amount.MOVE_MAX:
			return move_max
		Amount.BUMP_MIN:
			return bump_min
	return bump_max


func _convert_amount(amount: Variant, node: Node) -> Variant:
	var vector: Vector3 = amount
	if node is Node3D:
		return vector
	return Vector3(vector.x * pixels_per_unit, -vector.y * pixels_per_unit, 0.0)


func _on_play(feedback_intensity: float) -> void:
	super._on_play(feedback_intensity)
	if follow_node.is_empty() or mode != Mode.MOVE_TO_ADDITIVE or _spring == null or is_retrigger():
		return
	# The spring starts at rest on its old target, so the difference is the added amount.
	var aimed: Vector3 = _spring.target
	var resting: Vector3 = _spring.current
	_follow_offset = aimed - resting


func _on_spring_update(_node: Node) -> void:
	if follow_node.is_empty() or mode == Mode.BUMP:
		return
	var other := resolve(follow_node)
	if other == null:
		return
	var anchor := Juice.node_position(other)
	_spring.target = anchor if mode == Mode.MOVE_TO else anchor + _follow_offset
